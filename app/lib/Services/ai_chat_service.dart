import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../Models/game.dart';
import 'app_config.dart';

/// Message in the conversation history sent to the server.
class _HistoryMessage {
  final String role;    // "user" or "model"
  final String content;
  const _HistoryMessage({required this.role, required this.content});
  Map<String, String> toJson() => {'role': role, 'content': content};
}

/// Usage info returned by the server in the final SSE "done" event.
class ChatUsageInfo {
  final int chatsUsedToday;
  final int chatsRemaining;
  const ChatUsageInfo({required this.chatsUsedToday, required this.chatsRemaining});
}

/// Service for interacting with the Cloud Run AI chat endpoint.
///
/// Each call to [sendMessageStream] sends the full conversation history,
/// making the service stateless on the server side.
class AIChatService {
  final List<_HistoryMessage> _history = [];
  Game? _currentGame;

  /// The last usage info received from the server.
  ChatUsageInfo? lastUsageInfo;

  // ── Session management ─────────────────────────────────────────────────────

  /// Prepare a chat session for [game]. Clears history and stores game context.
  Future<void> startGameChat(Game game) async {
    _currentGame = game;
    _history.clear();
    lastUsageInfo = null;
  }

  /// Clear the current session.
  void clearChat() {
    _currentGame = null;
    _history.clear();
    lastUsageInfo = null;
  }

  // ── Messaging ──────────────────────────────────────────────────────────────

  /// Send [message] to the Cloud Run endpoint and stream the response.
  ///
  /// Yields text chunks as they arrive. After the stream ends, [lastUsageInfo]
  /// is populated with the server-reported usage counts.
  ///
  /// Throws an [Exception] on auth failure or rate limiting.
  Stream<String> sendMessageStream(String message) async* {
    // Get Firebase ID token for auth
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not signed in. Please sign in and try again.');
    }
    final idToken = await user.getIdToken();

    // Build request body
    final body = jsonEncode({
      'message': message,
      'conversation_history': _history.map((m) => m.toJson()).toList(),
      if (_currentGame != null) 'game_context': _buildGameContext(_currentGame!),
    });

    final url = Uri.parse('${AppConfig.instance.getApiBaseUrl()}/chat/message');

    // Use http.Client for streaming
    final client = http.Client();
    try {
      final request = http.Request('POST', url);
      request.headers['Content-Type'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $idToken';
      request.body = body;

      final streamedResponse = await client.send(request).timeout(
        Duration(seconds: AppConfig.apiLongTimeoutSeconds),
      );

      if (streamedResponse.statusCode == 401) {
        throw Exception('Authentication failed. Please sign in again.');
      }

      if (streamedResponse.statusCode == 429) {
        // Parse rate-limit detail from response body
        final errorBody = await streamedResponse.stream.bytesToString();
        Map<String, dynamic> detail = {};
        try {
          final parsed = jsonDecode(errorBody) as Map<String, dynamic>;
          detail = (parsed['detail'] as Map<String, dynamic>?) ?? {};
        } catch (_) {}
        throw Exception(
          detail['message'] as String? ??
              "You've used all $kFreeDailyLimit free AI chats for today. "
              "Come back tomorrow or upgrade to Pro for unlimited access. 🔓",
        );
      }

      if (streamedResponse.statusCode != 200) {
        throw Exception('Server error (${streamedResponse.statusCode}). Please try again.');
      }

      // Parse SSE stream
      String buffer = '';
      String fullResponse = '';
      await for (final bytes in streamedResponse.stream) {
        buffer += utf8.decode(bytes);

        // SSE events are separated by double newline
        while (buffer.contains('\n\n')) {
          final idx = buffer.indexOf('\n\n');
          final eventBlock = buffer.substring(0, idx);
          buffer = buffer.substring(idx + 2);

          for (final line in eventBlock.split('\n')) {
            if (!line.startsWith('data: ')) continue;
            final jsonStr = line.substring(6).trim();
            if (jsonStr.isEmpty) continue;

            Map<String, dynamic> event;
            try {
              event = jsonDecode(jsonStr) as Map<String, dynamic>;
            } catch (_) {
              continue;
            }

            if (event['done'] == true) {
              // Final event — capture usage and stop
              lastUsageInfo = ChatUsageInfo(
                chatsUsedToday: (event['chatsUsedToday'] as num?)?.toInt() ?? 0,
                chatsRemaining: (event['chatsRemaining'] as num?)?.toInt() ?? 0,
              );
            } else if (event.containsKey('error')) {
              throw Exception(event['error'] as String? ?? 'Unknown server error');
            } else if (event.containsKey('text')) {
              final chunk = event['text'] as String;
              fullResponse += chunk;
              yield chunk;
            }
          }
        }
      }

      // Append to history after successful response
      if (fullResponse.isNotEmpty) {
        _history.add(_HistoryMessage(role: 'user', content: message));
        _history.add(_HistoryMessage(role: 'model', content: fullResponse));
      }
    } finally {
      client.close();
    }
  }

  // ── Context builders ───────────────────────────────────────────────────────

  Map<String, dynamic> _buildGameContext(Game game) {
    return {
      'homeTeam': game.homeTeam,
      'awayTeam': game.awayTeam,
      'homeWinProb': game.homeWinProb,
      'awayWinProb': game.awayWinProb,
      'homeElo': game.homeElo,
      'awayElo': game.awayElo,
      'confidenceTier': game.confidenceTier,
      'homeInjuries': game.homeInjuries,
      'awayInjuries': game.awayInjuries,
      'injuryAdvantage': game.injuryAdvantage,
    };
  }

  /// Generate a quick game analysis (Pro-only feature).
  Future<String> generateQuickAnalysis(Game game) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in.');
    final idToken = await user.getIdToken();

    final prompt =
        'Analyze this NBA game and provide a brief, engaging narrative in 2-3 sentences. '
        'Focus on the prediction confidence, key factors (Elo ratings, home court, injuries), '
        'and what makes this game interesting. Keep it conversational.\n\n'
        '${_buildGameContextString(game)}';

    final body = jsonEncode({
      'message': prompt,
      'conversation_history': [],
      'game_context': _buildGameContext(game),
    });

    final url = Uri.parse('${AppConfig.instance.getApiBaseUrl()}/chat/message');
    final client = http.Client();
    try {
      final request = http.Request('POST', url);
      request.headers['Content-Type'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $idToken';
      request.body = body;

      final streamedResponse = await client.send(request).timeout(
        Duration(seconds: AppConfig.apiLongTimeoutSeconds),
      );

      if (streamedResponse.statusCode != 200) {
        throw Exception('Failed to generate analysis (${streamedResponse.statusCode}).');
      }

      // Collect full streamed response
      String result = '';
      String buffer = '';
      await for (final bytes in streamedResponse.stream) {
        buffer += utf8.decode(bytes);
        while (buffer.contains('\n\n')) {
          final idx = buffer.indexOf('\n\n');
          final block = buffer.substring(0, idx);
          buffer = buffer.substring(idx + 2);
          for (final line in block.split('\n')) {
            if (!line.startsWith('data: ')) continue;
            final jsonStr = line.substring(6).trim();
            if (jsonStr.isEmpty) continue;
            try {
              final event = jsonDecode(jsonStr) as Map<String, dynamic>;
              if (event.containsKey('text')) result += event['text'] as String;
            } catch (_) {}
          }
        }
      }
      return result.trim().isEmpty ? 'Unable to generate analysis.' : result.trim();
    } finally {
      client.close();
    }
  }

  String _buildGameContextString(Game game) {
    final homeWinPct = game.homeWinProb != null
        ? (game.homeWinProb! * 100).toStringAsFixed(1)
        : '50.0';
    final awayWinPct = game.awayWinProb != null
        ? (game.awayWinProb! * 100).toStringAsFixed(1)
        : '50.0';
    return 'Game: ${game.homeTeam} vs ${game.awayTeam} | '
        'Home win: $homeWinPct% | Away win: $awayWinPct% | '
        'Tier: ${game.confidenceTier ?? "Moderate"} | '
        'Home Elo: ${game.homeElo?.toInt() ?? 1500} | '
        'Away Elo: ${game.awayElo?.toInt() ?? 1500}';
  }
}

/// Free-tier daily chat limit (kept in sync with the server constant).
const int kFreeDailyLimit = 3;
