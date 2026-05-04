from fastapi import APIRouter, HTTPException
import httpx
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/nba/offseason", tags=["Offseason"])

# Static mock data for Draft
MOCK_DRAFT_PROSPECTS = [
    {"id": 1, "name": "AJ Dybantsa", "position": "F", "school": "BYU", "projected_pick": "1st Overall", "strengths": "Scoring, Versatility, Size", "image_url": None},
    {"id": 2, "name": "Cameron Boozer", "position": "PF", "school": "Duke", "projected_pick": "Top 3", "strengths": "Rebounding, Interior Scoring", "image_url": None},
    {"id": 3, "name": "Cayden Boozer", "position": "PG", "school": "Duke", "projected_pick": "Top 5", "strengths": "Playmaking, Basketball IQ", "image_url": None},
    {"id": 4, "name": "Liam McNeeley", "position": "F", "school": "UConn", "projected_pick": "Top 5", "strengths": "Shooting, Off-Ball Movement", "image_url": None},
    {"id": 5, "name": "Carter Bryant", "position": "F", "school": "Arizona", "projected_pick": "Top 10", "strengths": "Length, Two-Way Potential", "image_url": None},
    {"id": 6, "name": "Darryn Peterson", "position": "G", "school": "Kansas", "projected_pick": "Top 10", "strengths": "Creation, Athleticism", "image_url": None},
    {"id": 7, "name": "Noa Essengue", "position": "F", "school": "France", "projected_pick": "Lottery", "strengths": "Upside, Defensive Tools", "image_url": None},
    {"id": 8, "name": "Isaiah Evans", "position": "G", "school": "Duke", "projected_pick": "Lottery", "strengths": "Shooting, Off-Ball Scoring", "image_url": None},
    {"id": 9, "name": "Nikolas Khamenia", "position": "F", "school": "Arizona", "projected_pick": "Lottery", "strengths": "Motor, High IQ", "image_url": None},
    {"id": 10, "name": "Egor Demin", "position": "G", "school": "BYU", "projected_pick": "Mid 1st Round", "strengths": "Passing, Court Vision", "image_url": None},
]

# Static mock data for Free Agents
MOCK_FREE_AGENTS = [
    {"id": 1, "name": "Luka Doncic", "position": "PG", "previous_team": "Dallas Mavericks", "status": "Player Option", "projected_contract": "$346M / 5 yrs"},
    {"id": 2, "name": "Shai Gilgeous-Alexander", "position": "PG", "previous_team": "Oklahoma City Thunder", "status": "Extension Eligible", "projected_contract": "$294M / 4 yrs"},
    {"id": 3, "name": "Giannis Antetokounmpo", "position": "PF", "previous_team": "Milwaukee Bucks", "status": "Player Option", "projected_contract": "$300M / 5 yrs"},
    {"id": 4, "name": "De'Aaron Fox", "position": "PG", "previous_team": "Sacramento Kings", "status": "Unrestricted", "projected_contract": "$180M / 4 yrs"},
    {"id": 5, "name": "Donovan Mitchell", "position": "SG", "previous_team": "Cleveland Cavaliers", "status": "Player Option", "projected_contract": "$200M / 4 yrs"},
    {"id": 6, "name": "Jimmy Butler", "position": "SF", "previous_team": "Miami Heat", "status": "Unrestricted", "projected_contract": "$100M / 2 yrs"},
    {"id": 7, "name": "Brandon Ingram", "position": "SF", "previous_team": "New Orleans Pelicans", "status": "Unrestricted", "projected_contract": "$160M / 4 yrs"},
    {"id": 8, "name": "Kyrie Irving", "position": "PG", "previous_team": "Dallas Mavericks", "status": "Player Option", "projected_contract": "$120M / 3 yrs"},
    {"id": 9, "name": "Jaren Jackson Jr.", "position": "PF", "previous_team": "Memphis Grizzlies", "status": "Unrestricted", "projected_contract": "$150M / 4 yrs"},
    {"id": 10, "name": "Mikal Bridges", "position": "SF", "previous_team": "New York Knicks", "status": "Unrestricted", "projected_contract": "$140M / 4 yrs"},
]

@router.get("/news")
async def get_offseason_news():
    """Fetch the latest NBA news from the ESPN API."""
    url = "https://site.api.espn.com/apis/site/v2/sports/basketball/nba/news"
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(url, timeout=10.0)
            if response.status_code == 200:
                data = response.json()
                articles = data.get("articles", [])
                
                # Format to a cleaner payload
                clean_articles = []
                for article in articles:
                    images = article.get("images", [])
                    image_url = images[0].get("url") if images else None
                    
                    clean_articles.append({
                        "headline": article.get("headline"),
                        "description": article.get("description"),
                        "published": article.get("published"),
                        "link": article.get("links", {}).get("web", {}).get("href"),
                        "image_url": image_url
                    })
                    
                return {"status": "success", "news": clean_articles}
            else:
                raise HTTPException(status_code=response.status_code, detail="Failed to fetch ESPN news")
    except Exception as e:
        logger.error(f"Error fetching news: {e}")
        raise HTTPException(status_code=500, detail=str(e))

_DRAFT_KEYWORDS = {"draft", "prospect", "combine", "lottery", "flagg", "bailey", "harper", "edgecombe"}

@router.get("/draft/news")
async def get_draft_news():
    """Fetch draft-related NBA news from ESPN, filtered by draft keywords."""
    url = "https://site.api.espn.com/apis/site/v2/sports/basketball/nba/news"
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(url, timeout=10.0)
            if response.status_code == 200:
                data = response.json()
                articles = data.get("articles", [])

                draft_articles = []
                for article in articles:
                    text = (
                        (article.get("headline") or "") + " " +
                        (article.get("description") or "")
                    ).lower()
                    if any(kw in text for kw in _DRAFT_KEYWORDS):
                        images = article.get("images", [])
                        image_url = images[0].get("url") if images else None
                        draft_articles.append({
                            "headline": article.get("headline"),
                            "description": article.get("description"),
                            "published_at": article.get("published"),
                            "source": article.get("source", "ESPN"),
                            "link": article.get("links", {}).get("web", {}).get("href"),
                            "image_url": image_url,
                        })

                return {"status": "success", "news": draft_articles}
            else:
                raise HTTPException(status_code=response.status_code, detail="Failed to fetch ESPN news")
    except Exception as e:
        logger.error(f"Error fetching draft news: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/draft")
async def get_draft_prospects():
    """Returns a curated list of top draft prospects."""
    return {"status": "success", "prospects": MOCK_DRAFT_PROSPECTS}

@router.get("/free-agents")
async def get_free_agents():
    """Returns a curated list of top free agents."""
    return {"status": "success", "free_agents": MOCK_FREE_AGENTS}
