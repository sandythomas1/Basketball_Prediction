import 'package:firebase_ai/firebase_ai.dart';
import '../Models/game.dart';

/// Service for interacting with Firebase Vertex AI (Gemini)
class AIChatService {
  GenerativeModel? _model;
  ChatSession? _chatSession;
  
  /// Initialize the Vertex AI model
  Future<void> initialize() async {
    _model = FirebaseAI.vertexAI().generativeModel(
      model: 'gemini-2.0-flash',
      systemInstruction: Content.system(_systemPrompt),
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topP: 0.95,
        topK: 40,
        maxOutputTokens: 1024,
      ),
    );
  }
  
  /// Start a new chat session with game context
  Future<void> startGameChat(Game game) async {
    if (_model == null) {
      await initialize();
    }
    
    final gameContext = _buildGameContext(game);
    _chatSession = _model!.startChat(
      history: [
        Content.text(gameContext),
        Content.model([TextPart(_generateInitialAnalysis(game))]),
      ],
    );
  }
  
  /// Send a message and get a streaming response
  Stream<String> sendMessageStream(String message) async* {
    if (_chatSession == null) {
      throw Exception('Chat session not initialized. Call startGameChat first.');
    }
    
    final content = Content.text(message);
    final response = _chatSession!.sendMessageStream(content);
    
    await for (final chunk in response) {
      if (chunk.text != null) {
        yield chunk.text!;
      }
    }
  }
  
  /// Send a message and get a complete response
  Future<String> sendMessage(String message) async {
    if (_chatSession == null) {
      throw Exception('Chat session not initialized. Call startGameChat first.');
    }
    
    final content = Content.text(message);
    final response = await _chatSession!.sendMessage(content);
    return response.text ?? 'No response generated.';
  }
  
  /// Generate a quick game analysis without chat context
  Future<String> generateQuickAnalysis(Game game) async {
    if (_model == null) {
      await initialize();
    }
    
    final prompt = '''
Analyze this NBA game and provide a brief, engaging narrative:

${_buildGameContext(game)}

Write 2-3 sentences that capture the key storyline for this matchup. Focus on:
- The prediction confidence and what it means
- Key factors (Elo ratings, home court, etc.)
- What makes this game interesting

Keep it conversational and insightful, like an expert analyst sharing quick thoughts.
''';

    final content = [Content.text(prompt)];
    final response = await _model!.generateContent(content);
    return response.text ?? 'Unable to generate analysis.';
  }
  
  /// Clear the current chat session
  void clearChat() {
    _chatSession = null;
  }
  
  /// Build game context string for the AI
  String _buildGameContext(Game game) {
    final homeWinPct = game.homeWinProb != null 
        ? (game.homeWinProb! * 100).toStringAsFixed(1) 
        : '50.0';
    final awayWinPct = game.awayWinProb != null 
        ? (game.awayWinProb! * 100).toStringAsFixed(1) 
        : '50.0';
    
    return '''
GAME DATA:
- Home Team: ${game.homeTeam}
- Away Team: ${game.awayTeam}
- Game Time: ${game.date} at ${game.time}
- Status: ${game.status}

MODEL PREDICTIONS:
- Home Win Probability: $homeWinPct%
- Away Win Probability: $awayWinPct%
- Confidence Tier: ${game.confidenceTier ?? 'Not available'}
- Favored Team: ${game.favoredTeam ?? game.homeTeam}

ELO RATINGS:
- Home Elo: ${game.homeElo?.toInt() ?? 1500}
- Away Elo: ${game.awayElo?.toInt() ?? 1500}
- Elo Difference: ${((game.homeElo ?? 1500) - (game.awayElo ?? 1500)).toInt()} (positive favors home)

CURRENT SCORE (if applicable):
- Home: ${game.homeScore.isNotEmpty ? game.homeScore : 'N/A'}
- Away: ${game.awayScore.isNotEmpty ? game.awayScore : 'N/A'}
''';
  }
  
  /// Generate initial analysis based on game data
  String _generateInitialAnalysis(Game game) {
    final favored = game.favoredTeam ?? game.homeTeam;
    final prob = (game.favoredProb * 100).toStringAsFixed(1);
    final tier = game.confidenceTier ?? 'Moderate';
    
    return '''
I've analyzed this ${game.homeTeam} vs ${game.awayTeam} matchup. The model gives ${favored} a ${prob}% win probability, classified as a "$tier" prediction.

Feel free to ask me about:
• Why the model favors one team
• Historical context and trends
• Key factors affecting the outcome
• How the Elo ratings factor in

What would you like to know more about?
''';
  }
  
  /// System prompt defining the AI's behavior
  static const String _systemPrompt = '''
You are an expert NBA analyst assistant for a basketball prediction app. Your role is to provide insightful, data-driven analysis of NBA games based on the prediction model's outputs.

GUIDELINES:
1. Always reference the specific game data provided (teams, probabilities, Elo ratings)
2. Explain predictions in an accessible way - avoid overly technical jargon
3. Be conversational but professional, like a knowledgeable sports analyst
4. When discussing probabilities, help users understand what they mean practically
5. Acknowledge uncertainty - predictions are probabilities, not guarantees
6. Stay focused on the game analysis - don't discuss unrelated topics
7. Be concise - users want quick insights, not essays
8. Use the confidence tier (Strong Favorite, Moderate, Toss-Up, etc.) to frame discussions

ABOUT THE PREDICTION MODEL:
- Uses Elo ratings calibrated for NBA teams
- Considers home court advantage
- Confidence tiers range from "Strong Favorite" to "Toss-Up" to "Strong Underdog"
- Higher Elo indicates stronger recent performance

You can discuss:
- Why a team is favored
- What the Elo difference means
- Historical context (in general terms)
- What would need to happen for the underdog to win
- How confident users should be in the prediction
''';
}
