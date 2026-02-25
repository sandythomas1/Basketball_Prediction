import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../Models/game.dart';
import '../Services/ai_chat_service.dart';

// ── Chat message model ────────────────────────────────────────────────────────

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isLoading;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.isLoading = false,
  }) : timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({
    String? text,
    bool? isUser,
    DateTime? timestamp,
    bool? isLoading,
  }) {
    return ChatMessage(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ── State model ───────────────────────────────────────────────────────────────

class AIChatState {
  final List<ChatMessage> messages;
  final bool isInitialized;
  final bool isLoading;
  final String? error;
  final Game? currentGame;

  // ── Usage / rate-limit ────────────────────────────────────────────────────
  final int chatsUsedToday;
  final int chatsRemaining;
  final bool isRateLimited;

  static const int dailyLimit = 3;

  const AIChatState({
    this.messages = const [],
    this.isInitialized = false,
    this.isLoading = false,
    this.error,
    this.currentGame,
    this.chatsUsedToday = 0,
    this.chatsRemaining = dailyLimit,
    this.isRateLimited = false,
  });

  AIChatState copyWith({
    List<ChatMessage>? messages,
    bool? isInitialized,
    bool? isLoading,
    String? error,
    Game? currentGame,
    int? chatsUsedToday,
    int? chatsRemaining,
    bool? isRateLimited,
  }) {
    return AIChatState(
      messages: messages ?? this.messages,
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentGame: currentGame ?? this.currentGame,
      chatsUsedToday: chatsUsedToday ?? this.chatsUsedToday,
      chatsRemaining: chatsRemaining ?? this.chatsRemaining,
      isRateLimited: isRateLimited ?? this.isRateLimited,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AIChatNotifier extends StateNotifier<AIChatState> {
  final AIChatService _service;

  AIChatNotifier(this._service) : super(const AIChatState());

  // ── RTDB usage helpers ─────────────────────────────────────────────────

  static String _todayString() {
    final now = DateTime.now();
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DatabaseReference? _usageRef() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseDatabase.instance.ref('usage/$uid/${_todayString()}');
  }

  // ── Initialization ──────────────────────────────────────────────────────

  /// Initialize chat for a specific game and fetch today's usage from Firebase.
  Future<void> initializeForGame(Game game) async {
    // Skip if already initialized for this game
    if (state.currentGame?.id == game.id && state.isInitialized) return;

    state = state.copyWith(
      isLoading: true,
      error: null,
      currentGame: game,
      messages: [],
    );

    // Load today's usage in parallel with chat init
    await Future.wait([
      _fetchAndApplyUsage(),
      _service.startGameChat(game),
    ]);

    // Add initial AI message
    final initialMessage = ChatMessage(
      text: _getInitialMessage(game),
      isUser: false,
    );

    state = state.copyWith(
      isInitialized: true,
      isLoading: false,
      messages: [initialMessage],
    );
  }

  /// Fetch today's chat count from Firebase Realtime Database and update state.
  Future<void> _fetchAndApplyUsage() async {
    try {
      final ref = _usageRef();
      if (ref == null) return;
      final snap = await ref.get();
      final used = (snap.value as num?)?.toInt() ?? 0;
      final remaining = max(0, AIChatState.dailyLimit - used);
      state = state.copyWith(
        chatsUsedToday: used,
        chatsRemaining: remaining,
        isRateLimited: used >= AIChatState.dailyLimit,
      );
    } catch (_) {
      // Non-fatal — usage display will just show defaults
    }
  }

  /// Atomically increment today's usage in RTDB and return the new count.
  Future<int> _incrementUsage() async {
    final ref = _usageRef();
    if (ref == null) return state.chatsUsedToday + 1;
    await ref.set(ServerValue.increment(1));
    final snap = await ref.get();
    return (snap.value as num?)?.toInt() ?? (state.chatsUsedToday + 1);
  }

  // ── Messaging ───────────────────────────────────────────────────────────

  /// Send a message and get a streaming response.
  Future<void> sendMessage(String text) async {
    if (!state.isInitialized) {
      state = state.copyWith(error: 'Chat not initialized. Please try again.');
      return;
    }

    if (state.isLoading) return;

    // Optimistic check — block at the UI layer before even calling the API
    if (state.isRateLimited) {
      _appendSystemMessage(
        "You've used all ${AIChatState.dailyLimit} free AI chats for today. "
        "Come back tomorrow or upgrade to Pro for unlimited access. 🔓",
      );
      return;
    }

    // Add user message + AI placeholder
    final userMsg = ChatMessage(text: text, isUser: true);
    final aiPlaceholder = ChatMessage(text: '', isUser: false, isLoading: true);

    state = state.copyWith(
      messages: [...state.messages, userMsg, aiPlaceholder],
      isLoading: true,
      error: null,
    );

    try {
      String fullResponse = '';

      await for (final chunk in _service.sendMessageStream(text)) {
        fullResponse += chunk;

        final updated = [...state.messages];
        updated[updated.length - 1] = ChatMessage(
          text: fullResponse,
          isUser: false,
          isLoading: true,
        );
        state = state.copyWith(messages: updated);
      }

      if (fullResponse.trim().isEmpty) {
        fullResponse =
            'I apologize, but I could not generate a response. Please try asking differently.';
      }

      // Mark message complete
      final updated = [...state.messages];
      updated[updated.length - 1] =
          ChatMessage(text: fullResponse, isUser: false, isLoading: false);

      // Persist the usage increment to RTDB and read back the authoritative count
      final newUsed = await _incrementUsage();
      final newRemaining = max(0, AIChatState.dailyLimit - newUsed);

      state = state.copyWith(
        messages: updated,
        isLoading: false,
        chatsUsedToday: newUsed,
        chatsRemaining: newRemaining,
        isRateLimited: newRemaining == 0,
      );
    } catch (e) {
      _replaceLastMessageWithError(
        'Sorry, I encountered an error. Please try again.\n\n'
        '${e.toString().replaceAll('Exception:', '').trim()}',
      );
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  void _replaceLastMessageWithError(String errorText) {
    final updated = [...state.messages];
    if (updated.isNotEmpty) {
      updated[updated.length - 1] =
          ChatMessage(text: errorText, isUser: false, isLoading: false);
    }
    state = state.copyWith(messages: updated, isLoading: false, error: null);
  }

  void _appendSystemMessage(String text) {
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(text: text, isUser: false, isLoading: false),
      ],
    );
  }

  void clearError() => state = state.copyWith(error: null);

  void reset() {
    _service.clearChat();
    state = const AIChatState();
  }

  String _getInitialMessage(Game game) {
    final favored = game.favoredTeam ?? game.homeTeam;
    final prob = (game.favoredProb * 100).toStringAsFixed(0);
    final tier = game.confidenceTier ?? 'Moderate';

    return '''👋 Hey! I've analyzed this **${game.homeTeam}** vs **${game.awayTeam}** matchup.

📊 **Quick Take:** The model gives **$favored** a **$prob%** win probability — that's a "$tier" prediction.

Ask me anything about this game! For example:
• "Why is $favored favored?"
• "What do the Elo ratings tell us?"
• "How confident should I be?"''';
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final aiChatServiceProvider = Provider<AIChatService>((ref) {
  return AIChatService();
});

final aiChatProvider =
    StateNotifierProvider<AIChatNotifier, AIChatState>((ref) {
  final service = ref.watch(aiChatServiceProvider);
  return AIChatNotifier(service);
});

/// One-shot quick analysis (no chat, no usage tracking)
final gameAnalysisProvider =
    FutureProvider.family<String, Game>((ref, game) async {
  final service = ref.watch(aiChatServiceProvider);
  return service.generateQuickAnalysis(game);
});
