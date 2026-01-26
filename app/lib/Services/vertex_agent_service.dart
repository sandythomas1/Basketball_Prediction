import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Models/game.dart';

/// Service for interacting with Vertex AI Agent Builder
/// 
/// This provides a more sophisticated agent experience with:
/// - Tool/function calling capabilities
/// - Grounded responses from your prediction API
/// - Conversation memory and context
class VertexAgentService {
  // Your GCP project configuration (from --dart-define or defaults)
  static const String _projectId = String.fromEnvironment(
    'GCP_PROJECT_ID',
    defaultValue: '', // No default - must be provided
  );
  static const String _location = String.fromEnvironment(
    'GCP_LOCATION',
    defaultValue: 'global',
  );
  static const String _agentId = String.fromEnvironment(
    'GCP_AGENT_ID',
    defaultValue: '', // No default - must be provided
  );
  
  // Agent endpoint
  static String get _agentEndpoint => 
    'https://$_location-dialogflow.googleapis.com/v3/projects/$_projectId/locations/$_location/agents/$_agentId/sessions';
  
  String? _sessionId;
  String? _accessToken;
  
  /// Check if the service is properly configured
  static bool get isConfigured => _projectId.isNotEmpty && _agentId.isNotEmpty;
  
  /// Initialize with authentication
  /// For production, use Firebase Auth token exchange or service account
  Future<void> initialize({required String accessToken}) async {
    if (!isConfigured) {
      throw Exception(
        'VertexAgentService not configured. '
        'Provide GCP_PROJECT_ID and GCP_AGENT_ID via --dart-define. '
        'Example: flutter run --dart-define=GCP_PROJECT_ID=your-project --dart-define=GCP_AGENT_ID=your-agent-id'
      );
    }
    _accessToken = accessToken;
    _sessionId = 'session-${DateTime.now().millisecondsSinceEpoch}';
  }
  
  /// Send a message to the agent with game context
  Future<AgentResponse> sendMessage({
    required String message,
    Game? gameContext,
  }) async {
    if (_accessToken == null || _sessionId == null) {
      throw Exception('Agent not initialized. Call initialize() first.');
    }
    
    // Build the request with optional game context
    final requestBody = {
      'queryInput': {
        'text': {
          'text': _buildContextualMessage(message, gameContext),
        },
        'languageCode': 'en',
      },
      'queryParams': {
        'parameters': gameContext != null ? _buildGameParameters(gameContext) : {},
      },
    };
    
    final response = await http.post(
      Uri.parse('$_agentEndpoint/$_sessionId:detectIntent'),
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Agent request failed: ${response.body}');
    }
    
    return AgentResponse.fromJson(jsonDecode(response.body));
  }
  
  /// Build a message with game context prepended
  String _buildContextualMessage(String message, Game? game) {
    if (game == null) return message;
    
    return '''
[GAME CONTEXT]
Home: ${game.homeTeam} (Elo: ${game.homeElo?.toInt() ?? 1500})
Away: ${game.awayTeam} (Elo: ${game.awayElo?.toInt() ?? 1500})
Home Win Prob: ${((game.homeWinProb ?? 0.5) * 100).toStringAsFixed(1)}%
Confidence: ${game.confidenceTier ?? 'Moderate'}
Status: ${game.status}

[USER QUESTION]
$message
''';
  }
  
  /// Build game parameters for the agent
  Map<String, dynamic> _buildGameParameters(Game game) {
    return {
      'home_team': game.homeTeam,
      'away_team': game.awayTeam,
      'home_win_prob': game.homeWinProb ?? 0.5,
      'away_win_prob': game.awayWinProb ?? 0.5,
      'home_elo': game.homeElo ?? 1500,
      'away_elo': game.awayElo ?? 1500,
      'confidence_tier': game.confidenceTier ?? 'Moderate',
      'game_status': game.status,
    };
  }
  
  /// Clear the current session
  void clearSession() {
    _sessionId = null;
  }
}

/// Response from the Vertex AI Agent
class AgentResponse {
  final String text;
  final List<String>? suggestions;
  final Map<String, dynamic>? toolResults;
  final double? confidence;
  
  AgentResponse({
    required this.text,
    this.suggestions,
    this.toolResults,
    this.confidence,
  });
  
  factory AgentResponse.fromJson(Map<String, dynamic> json) {
    final queryResult = json['queryResult'] ?? {};
    final responseMessages = queryResult['responseMessages'] as List? ?? [];
    
    String text = '';
    List<String>? suggestions;
    
    for (final msg in responseMessages) {
      if (msg['text'] != null) {
        final textParts = msg['text']['text'] as List? ?? [];
        text = textParts.isNotEmpty ? textParts.first : '';
      }
      if (msg['payload'] != null && msg['payload']['suggestions'] != null) {
        suggestions = (msg['payload']['suggestions'] as List)
            .map((s) => s['title'] as String)
            .toList();
      }
    }
    
    return AgentResponse(
      text: text,
      suggestions: suggestions,
      toolResults: queryResult['webhookPayloads']?.first,
      confidence: queryResult['intentDetectionConfidence']?.toDouble(),
    );
  }
}
