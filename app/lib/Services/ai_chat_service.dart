import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:http/http.dart' as http;
import '../Models/game.dart';
import 'app_config.dart';

/// Service for interacting with Firebase Vertex AI (Gemini)
/// 
/// Enhanced with function calling for real-time game data queries
class AIChatService {
  GenerativeModel? _model;
  ChatSession? _chatSession;
  
  // API configuration for function calling
  final String _apiBaseUrl = AppConfig.instance.getApiBaseUrl();
  
  /// Initialize the Vertex AI model with function calling tools
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
      tools: [
        Tool.functionDeclarations([
          _getPredictionTool,
          _getTodaysGamesTool,
          _getTeamStatsTool,
        ]),
      ],
    );
  }
  
  /// Tool: Get prediction for a specific matchup
  static FunctionDeclaration get _getPredictionTool => FunctionDeclaration(
    'get_game_prediction',
    'Get the AI model prediction for a specific NBA game matchup. Returns win probabilities, Elo ratings, and confidence level.',
    parameters: {
      'home_team': Schema.string(
        description: 'The home team name (e.g., "Lakers", "Celtics", "Warriors")',
      ),
      'away_team': Schema.string(
        description: 'The away team name (e.g., "Lakers", "Celtics", "Warriors")',
      ),
    },
  );
  
  /// Tool: Get today's games with predictions
  static FunctionDeclaration get _getTodaysGamesTool => FunctionDeclaration(
    'get_todays_games',
    'Get all NBA games scheduled for today along with their predictions',
    parameters: {},
  );
  
  /// Tool: Get team Elo and recent performance
  static FunctionDeclaration get _getTeamStatsTool => FunctionDeclaration(
    'get_team_stats',
    'Get the current Elo rating and recent performance for an NBA team',
    parameters: {
      'team_name': Schema.string(
        description: 'The team name (e.g., "Lakers", "Celtics")',
      ),
    },
  );
  
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
  
  /// Execute a function call from the model
  Future<Map<String, dynamic>> _executeFunctionCall(FunctionCall call) async {
    switch (call.name) {
      case 'get_game_prediction':
        return await _fetchPrediction(
          homeTeam: call.args['home_team'] as String,
          awayTeam: call.args['away_team'] as String,
        );
      case 'get_todays_games':
        return await _fetchTodaysGames();
      case 'get_team_stats':
        return await _fetchTeamStats(call.args['team_name'] as String);
      default:
        return {'error': 'Unknown function: ${call.name}'};
    }
  }
  
  /// Fetch prediction from API
  Future<Map<String, dynamic>> _fetchPrediction({
    required String homeTeam,
    required String awayTeam,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/predict/game'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'home_team': homeTeam,
          'away_team': awayTeam,
        }),
      ).timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'error': 'Failed to fetch prediction: ${response.statusCode}'};
    } catch (e) {
      return {'error': 'API error: $e'};
    }
  }
  
  /// Fetch today's games from API
  Future<Map<String, dynamic>> _fetchTodaysGames() async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/games/today/with-predictions'),
      ).timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'error': 'Failed to fetch games: ${response.statusCode}'};
    } catch (e) {
      return {'error': 'API error: $e'};
    }
  }
  
  /// Fetch team stats from API
  Future<Map<String, dynamic>> _fetchTeamStats(String teamName) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/teams'),
      ).timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final teams = data['teams'] as List? ?? [];
        final team = teams.firstWhere(
          (t) => (t['name'] as String).toLowerCase().contains(teamName.toLowerCase()),
          orElse: () => null,
        );
        
        if (team != null) {
          return team as Map<String, dynamic>;
        }
        return {'error': 'Team not found: $teamName'};
      }
      return {'error': 'Failed to fetch teams: ${response.statusCode}'};
    } catch (e) {
      return {'error': 'API error: $e'};
    }
  }
  
  /// Send a message and get a streaming response with function calling support
  Stream<String> sendMessageStream(String message) async* {
    if (_chatSession == null) {
      throw Exception('Chat session not initialized. Call startGameChat first.');
    }
    
    try {
      final content = Content.text(message);
      final response = _chatSession!.sendMessageStream(content);
      
      bool hasYieldedContent = false;
      
      await for (final chunk in response) {
        // Check if the model wants to call a function
        if (chunk.functionCalls.isNotEmpty) {
          for (final call in chunk.functionCalls) {
            yield '\n🔍 Looking up ${_getFriendlyFunctionName(call.name)}...\n';
            hasYieldedContent = true;
            
            try {
              // Execute the function
              final result = await _executeFunctionCall(call);
              
              // Send the function result back to the model
              final functionResponse = Content.functionResponse(call.name, result);
              final followUp = _chatSession!.sendMessageStream(functionResponse);
              
              await for (final followUpChunk in followUp) {
                if (followUpChunk.text != null && followUpChunk.text!.isNotEmpty) {
                  yield followUpChunk.text!;
                  hasYieldedContent = true;
                }
              }
            } catch (funcError) {
              yield '\n⚠️ Could not fetch data: $funcError\n';
              yield 'Let me answer based on what I know about the game.\n\n';
              hasYieldedContent = true;
            }
          }
        } else if (chunk.text != null && chunk.text!.isNotEmpty) {
          yield chunk.text!;
          hasYieldedContent = true;
        }
      }
      
      // If nothing was yielded, provide a fallback response
      if (!hasYieldedContent) {
        yield 'I apologize, but I could not generate a response. Please try rephrasing your question.';
      }
    } catch (e) {
      yield 'Sorry, I encountered an error: ${e.toString().replaceAll('Exception:', '').trim()}';
    }
  }
  
  /// Send a message and get a complete response with function calling support
  Future<String> sendMessage(String message) async {
    if (_chatSession == null) {
      throw Exception('Chat session not initialized. Call startGameChat first.');
    }
    
    final content = Content.text(message);
    var response = await _chatSession!.sendMessage(content);
    
    // Handle function calls (may need multiple rounds)
    int maxIterations = 5; // Prevent infinite loops
    int iteration = 0;
    
    while (response.functionCalls.isNotEmpty && iteration < maxIterations) {
      iteration++;
      
      for (final call in response.functionCalls) {
        final result = await _executeFunctionCall(call);
        final functionResponse = Content.functionResponse(call.name, result);
        response = await _chatSession!.sendMessage(functionResponse);
      }
    }
    
    return response.text ?? 'No response generated.';
  }
  
  /// Get user-friendly name for function
  String _getFriendlyFunctionName(String name) {
    switch (name) {
      case 'get_game_prediction':
        return 'game prediction';
      case 'get_todays_games':
        return "today's games";
      case 'get_team_stats':
        return 'team statistics';
      default:
        return name;
    }
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

INJURY REPORT:
- Home Team Injuries: ${_formatInjuries(game.homeInjuries)}
- Away Team Injuries: ${_formatInjuries(game.awayInjuries)}
- Health Advantage: ${_formatAdvantage(game.injuryAdvantage)}

CURRENT SCORE (if applicable):
- Home: ${game.homeScore.isNotEmpty ? game.homeScore : 'N/A'}
- Away: ${game.awayScore.isNotEmpty ? game.awayScore : 'N/A'}
''';
  }
  
  /// Format injury list for display
  String _formatInjuries(List<String>? injuries) {
    if (injuries == null || injuries.isEmpty) {
      return 'None reported';
    }
    return injuries.join(', ');
  }
  
  /// Format injury advantage
  String _formatAdvantage(String? advantage) {
    switch (advantage) {
      case 'home':
        return 'Home team (away has more injuries)';
      case 'away':
        return 'Away team (home has more injuries)';
      default:
        return 'Even (both teams relatively healthy)';
    }
  }
  
  /// Generate initial analysis based on game data
  String _generateInitialAnalysis(Game game) {
    final favored = game.favoredTeam ?? game.homeTeam;
    final prob = (game.favoredProb * 100).toStringAsFixed(1);
    final tier = game.confidenceTier ?? 'Moderate';
    
    // Check if there are injuries to mention
    final hasInjuries = game.hasInjuries;
    final injuryNote = hasInjuries 
        ? '\n\nNote: There are injury concerns in this matchup that may impact the outcome.' 
        : '';
    
    return '''
I've analyzed this ${game.homeTeam} vs ${game.awayTeam} matchup. The model gives ${favored} a ${prob}% win probability, classified as a "$tier" prediction.$injuryNote

Feel free to ask me about:
• Why the model favors one team
• How injuries might affect this game
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
- When key players are out or questionable, adjust your analysis accordingly
- Example: "The model gives Lakers 65%, but LeBron is questionable - if he sits, this becomes much closer"

You can discuss:
- Why a team is favored
- What the Elo difference means
- How injuries might change the prediction
- What would need to happen for the underdog to win
- How confident users should be given the injury situation
- Historical context (in general terms)
''';
}
