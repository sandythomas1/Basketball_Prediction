import 'package:cloud_functions/cloud_functions.dart';
import '../Models/game.dart';

/// Service for chatting with the AI Agent via Firebase Cloud Functions
/// 
/// This provides secure communication with your Dialogflow CX agent
/// without exposing credentials in the client app.
class AgentChatService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  String? _sessionId;
  
  /// Start a new chat session (optionally with game context)
  void startSession({String? sessionId}) {
    _sessionId = sessionId ?? 'session-${DateTime.now().millisecondsSinceEpoch}';
  }
  
  /// Get current session ID
  String? get sessionId => _sessionId;
  
  /// Send a message to the AI agent
  /// 
  /// Returns the agent's response text.
  /// Throws an exception if the request fails.
  Future<AgentChatResponse> sendMessage({
    required String message,
    Game? gameContext,
  }) async {
    // Ensure we have a session
    _sessionId ??= 'session-${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      final callable = _functions.httpsCallable('chatWithAgent');
      
      final result = await callable.call<Map<String, dynamic>>({
        'message': message,
        'sessionId': _sessionId,
        if (gameContext != null) 'gameContext': _buildGameContext(gameContext),
      });
      
      final data = result.data;
      
      // Update session ID if returned
      if (data['sessionId'] != null) {
        _sessionId = data['sessionId'] as String;
      }
      
      return AgentChatResponse(
        text: data['response'] as String? ?? 'No response received.',
        sessionId: _sessionId!,
        confidence: (data['confidence'] as num?)?.toDouble(),
        success: data['success'] as bool? ?? false,
      );
      
    } on FirebaseFunctionsException catch (e) {
      throw AgentChatException(
        message: e.message ?? 'Failed to communicate with AI assistant.',
        code: e.code,
      );
    } catch (e) {
      throw AgentChatException(
        message: 'An unexpected error occurred: $e',
        code: 'unknown',
      );
    }
  }
  
  /// Build game context map for the agent
  Map<String, dynamic> _buildGameContext(Game game) {
    return {
      'homeTeam': game.homeTeam,
      'awayTeam': game.awayTeam,
      'homeWinProb': game.homeWinProb ?? 0.5,
      'awayWinProb': game.awayWinProb ?? 0.5,
      'homeElo': game.homeElo ?? 1500,
      'awayElo': game.awayElo ?? 1500,
      'confidenceTier': game.confidenceTier ?? 'Moderate',
      'status': game.status,
      'date': game.date,
      'time': game.time,
    };
  }
  
  /// Clear the current session
  void clearSession() {
    _sessionId = null;
  }
}

/// Response from the AI agent
class AgentChatResponse {
  final String text;
  final String sessionId;
  final double? confidence;
  final bool success;
  
  AgentChatResponse({
    required this.text,
    required this.sessionId,
    this.confidence,
    required this.success,
  });
}

/// Exception for agent chat errors
class AgentChatException implements Exception {
  final String message;
  final String code;
  
  AgentChatException({
    required this.message,
    required this.code,
  });
  
  @override
  String toString() => message;
}
