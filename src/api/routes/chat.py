"""
AI Chat endpoint with SSE streaming, Firebase auth, and per-user daily rate limiting.

POST /chat/message
  - Requires: Authorization: Bearer <firebase-id-token>
  - Body: { message, conversation_history, game_context }
  - Returns: text/event-stream SSE chunks, final done event with usage counts
"""

import json
import os
from datetime import datetime, timezone
from typing import Any, AsyncGenerator, List, Optional

from google import genai
from google.genai import types as genai_types
from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import StreamingResponse
from firebase_admin import db as rtdb
from pydantic import BaseModel, Field

from ..middleware import FirebaseUser, verify_firebase_token
from ..middleware.firebase_auth import _ensure_firebase

# ── Configuration ─────────────────────────────────────────────────────────────

DAILY_FREE_CHAT_LIMIT = 3
GEMINI_MODEL = "gemini-2.0-flash"
MAX_MESSAGE_LENGTH = 2000
MAX_CONVERSATION_HISTORY = 20
MAX_HISTORY_CONTENT_LENGTH = 5000

router = APIRouter(prefix="/chat", tags=["chat"])


# ── Request schema ─────────────────────────────────────────────────────────────

class ConversationMessage(BaseModel):
    role: str   # "user" or "model"
    content: str = Field(..., max_length=MAX_HISTORY_CONTENT_LENGTH)


class GameContext(BaseModel):
    homeTeam: Optional[str] = None
    awayTeam: Optional[str] = None
    homeWinProb: Optional[float] = None
    awayWinProb: Optional[float] = None
    homeElo: Optional[float] = None
    awayElo: Optional[float] = None
    confidenceTier: Optional[str] = None
    homeInjuries: Optional[List[str]] = None
    awayInjuries: Optional[List[str]] = None
    injuryAdvantage: Optional[str] = None
    homeRestDays: Optional[int] = None
    awayRestDays: Optional[int] = None
    homeB2b: Optional[bool] = None
    awayB2b: Optional[bool] = None
    marketProbHome: Optional[float] = None
    homeRecentWins: Optional[float] = None
    awayRecentWins: Optional[float] = None


class ChatMessageRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=MAX_MESSAGE_LENGTH)
    conversation_history: List[ConversationMessage] = Field(
        default=[], max_length=MAX_CONVERSATION_HISTORY
    )
    game_context: Optional[GameContext] = None


# ── Helpers ───────────────────────────────────────────────────────────────────

def _today_utc() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def _get_daily_limit(uid: str) -> int:
    """Return the effective chat limit for a user (pro = unlimited)."""
    try:
        _ensure_firebase()
        snap = rtdb.reference(f"users/{uid}/subscription/tier").get()
        if snap == "pro":
            return 9999
    except Exception:
        pass
    return DAILY_FREE_CHAT_LIMIT


def _check_and_increment_usage(uid: str, limit: int) -> tuple[int, int]:
    """
    Atomically check and increment today's usage in Firebase RTDB.
    Returns (new_count, remaining).
    Raises HTTPException 429 if already at limit.
    """
    _ensure_firebase()
    today = _today_utc()
    ref = rtdb.reference(f"usage/{uid}/{today}")

    # Use a single transaction for atomic check-and-increment (no TOCTOU race)
    exceeded = False

    def _check_and_inc(current_val: Any) -> Any:
        nonlocal exceeded
        current = current_val or 0
        if current >= limit:
            exceeded = True
            return current  # abort: return unchanged value
        return current + 1

    ref.transaction(_check_and_inc)

    if exceeded:
        current = ref.get() or 0
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail={
                "error": "rate_limited",
                "message": f"You've used all {limit} free AI chats for today. Upgrade to Pro for unlimited access.",
                "chatsUsedToday": current,
                "chatsRemaining": 0,
                "limit": limit,
            },
        )

    new_count = ref.get() or 1
    remaining = max(0, limit - new_count)
    return new_count, remaining


def _build_full_message(message: str, ctx: Optional[GameContext]) -> str:
    """Prepend structured game context to the user message (mirrors chatWithAgent logic)."""
    if ctx is None:
        return message

    home = ctx.homeTeam or "Home"
    away = ctx.awayTeam or "Away"
    home_pct = f"{(ctx.homeWinProb or 0.5) * 100:.1f}"
    away_pct = f"{100 - float(home_pct):.1f}"

    home_inj = ", ".join(ctx.homeInjuries) if ctx.homeInjuries else "None reported"
    away_inj = ", ".join(ctx.awayInjuries) if ctx.awayInjuries else "None reported"

    if ctx.injuryAdvantage == "home":
        inj_adv = f"{home} (away team more injured)"
    elif ctx.injuryAdvantage == "away":
        inj_adv = f"{away} (home team more injured)"
    else:
        inj_adv = "Even (both teams similarly healthy)"

    home_rest = f"{ctx.homeRestDays} days" if ctx.homeRestDays is not None else "?"
    away_rest = f"{ctx.awayRestDays} days" if ctx.awayRestDays is not None else "?"
    home_b2b = " (BACK-TO-BACK)" if ctx.homeB2b else ""
    away_b2b = " (BACK-TO-BACK)" if ctx.awayB2b else ""

    market_note = ""
    if ctx.marketProbHome is not None and ctx.homeWinProb is not None:
        diff = abs(ctx.homeWinProb - ctx.marketProbHome)
        if diff > 0.04:
            direction = "HIGHER" if ctx.homeWinProb > ctx.marketProbHome else "LOWER"
            market_note = (
                f"\n- Market implies {ctx.marketProbHome * 100:.1f}% for {home} — "
                f"model is {direction} by {diff * 100:.1f}% (possible late injury news or sharp-money signal)"
            )
        else:
            market_note = f"\n- Market implies {ctx.marketProbHome * 100:.1f}% — model and market roughly agree"

    home_wins = round((ctx.homeRecentWins or 0.5) * 10)
    away_wins = round((ctx.awayRecentWins or 0.5) * 10)

    return f"""[GAME CONTEXT]
Home: {home} | Away: {away}

MODEL PREDICTION:
- {home} win probability: {home_pct}%
- {away} win probability: {away_pct}%
- Confidence tier: {ctx.confidenceTier or 'Moderate'}{market_note}

ELO RATINGS:
- {home}: {int(ctx.homeElo or 1500)} Elo
- {away}: {int(ctx.awayElo or 1500)} Elo

RECENT FORM (last 10 games):
- {home}: {home_wins}/10 wins
- {away}: {away_wins}/10 wins

REST / FATIGUE:
- {home}: {home_rest}{home_b2b}
- {away}: {away_rest}{away_b2b}

INJURY REPORT:
- {home}: {home_inj}
- {away}: {away_inj}
- Health advantage: {inj_adv}

[USER QUESTION]
{message}"""


_SYSTEM_PROMPT = """You are an expert NBA analyst assistant for the Signal Sports app. Your role is to provide insightful, data-driven analysis of NBA games based on the prediction model's outputs.

GUIDELINES:
1. Always reference the specific game data provided (teams, probabilities, Elo ratings, injuries)
2. Explain predictions in an accessible way - avoid overly technical jargon
3. Be conversational but professional, like a knowledgeable sports analyst
4. When discussing probabilities, help users understand what they mean practically
5. Acknowledge uncertainty - predictions are probabilities, not guarantees
6. Stay focused on the game analysis - don't discuss unrelated topics
7. Be concise - users want quick insights, not essays
8. Use the confidence tier (Strong Favorite, Moderate, Toss-Up, etc.) to frame discussions
9. IMPORTANT: Always consider injury data in your analysis - this is critical context the model doesn't account for yet

ABOUT THE PREDICTION MODEL:
- Uses Elo ratings calibrated for NBA teams
- Considers home court advantage, rest days, and recent performance
- Confidence tiers range from "Strong Favorite" to "Toss-Up" to "Strong Underdog"
- Higher Elo indicates stronger recent performance
- NOTE: The model does NOT yet account for injuries - you must factor this in your explanations

INJURY CONTEXT:
- You will receive current injury reports for both teams
- Injuries are NOT factored into the model's prediction yet
- When key players are out or questionable, adjust your analysis accordingly"""


async def _stream_gemini(
    message: str,
    history: List[ConversationMessage],
    new_count: int,
    remaining: int,
) -> AsyncGenerator[str, None]:
    """Configure Gemini and yield SSE-formatted chunks."""
    api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
    if api_key:
        client = genai.Client(api_key=api_key)
    else:
        # Use Vertex AI with Application Default Credentials (no key needed on Cloud Run)
        project = os.getenv("GOOGLE_CLOUD_PROJECT") or os.getenv("GCP_PROJECT")
        location = os.getenv("VERTEX_LOCATION", "us-central1")
        client = genai.Client(vertexai=True, project=project, location=location)

    # Build content list: history + new message
    contents: List[genai_types.Content] = []
    for msg in history:
        role = "user" if msg.role == "user" else "model"
        contents.append(genai_types.Content(
            role=role,
            parts=[genai_types.Part(text=msg.content)],
        ))
    contents.append(genai_types.Content(
        role="user",
        parts=[genai_types.Part(text=message)],
    ))

    config = genai_types.GenerateContentConfig(
        system_instruction=_SYSTEM_PROMPT,
        temperature=0.7,
        top_p=0.95,
        top_k=40,
        max_output_tokens=1024,
    )

    try:
        for chunk in client.models.generate_content_stream(
            model=GEMINI_MODEL,
            contents=contents,
            config=config,
        ):
            if chunk.text:
                payload = json.dumps({"text": chunk.text})
                yield f"data: {payload}\n\n"
    except Exception as e:
        print(f"Gemini streaming error: {e}")
        error_payload = json.dumps({"error": "An error occurred generating the response. Please try again."})
        yield f"data: {error_payload}\n\n"

    # Final done event with usage counts
    done_payload = json.dumps({
        "done": True,
        "chatsUsedToday": new_count,
        "chatsRemaining": remaining,
    })
    yield f"data: {done_payload}\n\n"


# ── Endpoint ──────────────────────────────────────────────────────────────────

@router.post("/message")
async def chat_message(
    request: ChatMessageRequest,
    user: Optional[FirebaseUser] = Depends(verify_firebase_token),
) -> StreamingResponse:
    """
    Send a chat message and receive a streaming Gemini response.

    Rate-limited to 3 messages/day for free users. Pro users are unlimited.
    Usage is tracked in Firebase RTDB at usage/{uid}/{YYYY-MM-DD}.
    """
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not request.message.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="message is required",
        )

    limit = _get_daily_limit(user.uid)
    new_count, remaining = _check_and_increment_usage(user.uid, limit)

    full_message = _build_full_message(request.message, request.game_context)

    return StreamingResponse(
        _stream_gemini(full_message, request.conversation_history, new_count, remaining),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
    )
