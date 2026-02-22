import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../Models/game.dart';

/// Service for chatting with the AI Agent via Firebase Cloud Functions
///
/// This provides secure communication with your Dialogflow CX agent
/// without exposing credentials in the client app.
class AgentChatService {
  // Must match the REGION constant in functions/index.js
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-west1');
  String? _sessionId;

  static const int dailyLimit = 10;

  // ── Session management ────────────────────────────────────────────────────

  /// Start a new chat session (optionally with game context)
  void startSession({String? sessionId}) {
    _sessionId = sessionId ?? 'session-${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Get current session ID
  String? get sessionId => _sessionId;

  /// Clear the current session
  void clearSession() {
    _sessionId = null;
  }

  // ── Usage tracking ────────────────────────────────────────────────────────

  /// Fetch today's chat count directly from Realtime Database.
  /// Returns 0 if the user hasn't chatted yet today or is not signed in.
  Future<int> fetchTodayUsage() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;

    final today = _todayString();
    final ref = FirebaseDatabase.instance.ref('usage/$uid/$today');
    final snap = await ref.get();
    if (!snap.exists) return 0;
    return (snap.value as num?)?.toInt() ?? 0;
  }

  // ── Messaging ─────────────────────────────────────────────────────────────

  /// Send a message to the AI agent.
  ///
  /// Returns [AgentChatResponse] which includes updated usage counts.
  /// Throws [AgentChatException] with code `resource-exhausted` when the
  /// daily limit is hit.
  Future<AgentChatResponse> sendMessage({
    required String message,
    Game? gameContext,
  }) async {
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
        chatsUsedToday: (data['chatsUsedToday'] as num?)?.toInt(),
        chatsRemaining: (data['chatsRemaining'] as num?)?.toInt(),
        limit: (data['limit'] as num?)?.toInt() ?? dailyLimit,
      );
    } on FirebaseFunctionsException catch (e) {
      // Surface usage data embedded in the error details (rate-limit case)
      final details = e.details as Map?;
      throw AgentChatException(
        message: e.message ?? 'Failed to communicate with AI assistant.',
        code: e.code,
        chatsUsedToday: (details?['chatsUsedToday'] as num?)?.toInt(),
        chatsRemaining: (details?['chatsRemaining'] as num?)?.toInt(),
        limit: (details?['limit'] as num?)?.toInt() ?? dailyLimit,
      );
    } catch (e) {
      throw AgentChatException(
        message: 'An unexpected error occurred: $e',
        code: 'unknown',
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

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

  /// Returns today's date as YYYY-MM-DD without any extra packages.
  static String _todayString() {
    final now = DateTime.now();
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

// ── Response model ────────────────────────────────────────────────────────────

/// Response from the AI agent
class AgentChatResponse {
  final String text;
  final String sessionId;
  final double? confidence;
  final bool success;
  final int? chatsUsedToday;
  final int? chatsRemaining;
  final int limit;

  AgentChatResponse({
    required this.text,
    required this.sessionId,
    this.confidence,
    required this.success,
    this.chatsUsedToday,
    this.chatsRemaining,
    this.limit = AgentChatService.dailyLimit,
  });
}

// ── Exception model ───────────────────────────────────────────────────────────

/// Exception for agent chat errors
class AgentChatException implements Exception {
  final String message;
  final String code;
  final int? chatsUsedToday;
  final int? chatsRemaining;
  final int limit;

  AgentChatException({
    required this.message,
    required this.code,
    this.chatsUsedToday,
    this.chatsRemaining,
    this.limit = AgentChatService.dailyLimit,
  });

  bool get isRateLimited => code == 'resource-exhausted';

  @override
  String toString() => message;
}
