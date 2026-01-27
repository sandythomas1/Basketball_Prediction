import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../Models/game.dart';
import '../Services/ai_chat_service.dart';

/// Chat message model
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

/// State for the AI chat
class AIChatState {
  final List<ChatMessage> messages;
  final bool isInitialized;
  final bool isLoading;
  final String? error;
  final Game? currentGame;
  
  const AIChatState({
    this.messages = const [],
    this.isInitialized = false,
    this.isLoading = false,
    this.error,
    this.currentGame,
  });
  
  AIChatState copyWith({
    List<ChatMessage>? messages,
    bool? isInitialized,
    bool? isLoading,
    String? error,
    Game? currentGame,
  }) {
    return AIChatState(
      messages: messages ?? this.messages,
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentGame: currentGame ?? this.currentGame,
    );
  }
}

/// Notifier for managing AI chat state
class AIChatNotifier extends StateNotifier<AIChatState> {
  final AIChatService _service;
  
  AIChatNotifier(this._service) : super(const AIChatState());
  
  /// Initialize chat for a specific game
  Future<void> initializeForGame(Game game) async {
    // Skip if already initialized for this game
    if (state.currentGame?.id == game.id && state.isInitialized) {
      return;
    }
    
    state = state.copyWith(
      isLoading: true,
      error: null,
      currentGame: game,
      messages: [],
    );
    
    try {
      await _service.startGameChat(game);
      
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
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to initialize AI: ${e.toString()}',
      );
    }
  }
  
  /// Send a message and get streaming response
  Future<void> sendMessage(String text) async {
    // Allow sending if initialized, even if previous message is still loading
    if (!state.isInitialized) {
      state = state.copyWith(error: 'Chat not initialized. Please try again.');
      return;
    }
    
    // Prevent double-sending while loading
    if (state.isLoading) return;
    
    // Add user message
    final userMessage = ChatMessage(text: text, isUser: true);
    
    // Add placeholder for AI response
    final aiPlaceholder = ChatMessage(
      text: '...',
      isUser: false,
      isLoading: true,
    );
    
    state = state.copyWith(
      messages: [...state.messages, userMessage, aiPlaceholder],
      isLoading: true,
      error: null, // Clear any previous error
    );
    
    try {
      String fullResponse = '';
      
      await for (final chunk in _service.sendMessageStream(text)) {
        fullResponse += chunk;
        
        // Update the AI message with streamed content
        final updatedMessages = [...state.messages];
        updatedMessages[updatedMessages.length - 1] = ChatMessage(
          text: fullResponse,
          isUser: false,
          isLoading: true,
        );
        state = state.copyWith(messages: updatedMessages);
      }
      
      // Handle empty response
      if (fullResponse.trim().isEmpty) {
        fullResponse = 'I apologize, but I could not generate a response. Please try asking your question differently.';
      }
      
      // Mark as complete
      final updatedMessages = [...state.messages];
      updatedMessages[updatedMessages.length - 1] = ChatMessage(
        text: fullResponse,
        isUser: false,
        isLoading: false,
      );
      state = state.copyWith(
        messages: updatedMessages,
        isLoading: false,
      );
    } catch (e) {
      // Update the placeholder with error message instead of removing it
      final updatedMessages = [...state.messages];
      updatedMessages[updatedMessages.length - 1] = ChatMessage(
        text: 'Sorry, I encountered an error. Please try again.\n\nError: ${e.toString().replaceAll('Exception:', '').trim()}',
        isUser: false,
        isLoading: false,
      );
      state = state.copyWith(
        messages: updatedMessages,
        isLoading: false,
        error: null, // Don't set error state, message shows the error
      );
    }
  }
  
  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }
  
  /// Reset chat for a new game
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
• "Why is ${favored} favored?"
• "What do the Elo ratings tell us?"
• "How confident should I be?"''';
  }
}

/// Provider for the AI chat service
final aiChatServiceProvider = Provider<AIChatService>((ref) {
  return AIChatService();
});

/// Provider for AI chat state
final aiChatProvider = StateNotifierProvider<AIChatNotifier, AIChatState>((ref) {
  final service = ref.watch(aiChatServiceProvider);
  return AIChatNotifier(service);
});

/// Provider for quick game analysis (one-shot, no chat)
final gameAnalysisProvider = FutureProvider.family<String, Game>((ref, game) async {
  final service = ref.watch(aiChatServiceProvider);
  return service.generateQuickAnalysis(game);
});
