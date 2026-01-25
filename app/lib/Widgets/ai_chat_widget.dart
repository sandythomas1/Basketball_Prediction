import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../Models/game.dart';
import '../Providers/ai_chat_provider.dart';
import '../theme/app_theme.dart';

/// AI Chat Widget for game analysis conversations
class AIChatWidget extends ConsumerStatefulWidget {
  final Game game;
  
  const AIChatWidget({super.key, required this.game});
  
  @override
  ConsumerState<AIChatWidget> createState() => _AIChatWidgetState();
}

class _AIChatWidgetState extends ConsumerState<AIChatWidget> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isExpanded = false;
  
  @override
  void initState() {
    super.initState();
    // Initialize chat when widget loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(aiChatProvider.notifier).initializeForGame(widget.game);
    });
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    _messageController.clear();
    ref.read(aiChatProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }
  
  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatProvider);
    
    // Scroll when messages update
    ref.listen<AIChatState>(aiChatProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });
    
    return Container(
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentPurple.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(context, chatState),
          
          // Content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildChatContent(context, chatState),
            crossFadeState: _isExpanded 
                ? CrossFadeState.showSecond 
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeader(BuildContext context, AIChatState chatState) {
    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // AI Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentPurple.withOpacity(0.2),
                    AppColors.accentBlue.withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.accentPurple.withOpacity(0.3),
                ),
              ),
              child: Icon(
                Icons.auto_awesome,
                color: AppColors.accentPurple,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            
            // Title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI INSIGHTS',
                    style: GoogleFonts.spaceMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: context.textMuted,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ask questions about this matchup',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            
            // Status / Expand indicator
            if (chatState.isLoading && !_isExpanded)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accentPurple,
                ),
              )
            else
              AnimatedRotation(
                turns: _isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  color: context.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildChatContent(BuildContext context, AIChatState chatState) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      child: Column(
        children: [
          // Divider
          Divider(height: 1, color: context.borderColor),
          
          // Messages
          Expanded(
            child: chatState.messages.isEmpty
                ? _buildLoadingState(context)
                : _buildMessagesList(context, chatState),
          ),
          
          // Input
          _buildInputArea(context, chatState),
        ],
      ),
    );
  }
  
  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accentPurple,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Analyzing matchup...',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: context.textMuted,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMessagesList(BuildContext context, AIChatState chatState) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: chatState.messages.length,
      itemBuilder: (context, index) {
        final message = chatState.messages[index];
        return _MessageBubble(
          message: message,
          showAvatar: index == 0 || 
              chatState.messages[index - 1].isUser != message.isUser,
        );
      },
    );
  }
  
  Widget _buildInputArea(BuildContext context, AIChatState chatState) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.bgSecondary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          // Suggestion chips
          if (_messageController.text.isEmpty) ...[
            _SuggestionChip(
              label: 'Why favored?',
              onTap: () => _sendQuickMessage('Why is the favored team expected to win?'),
            ),
            const SizedBox(width: 8),
            _SuggestionChip(
              label: 'Key factors',
              onTap: () => _sendQuickMessage('What are the key factors in this game?'),
            ),
            const Spacer(),
          ] else ...[
            Expanded(
              child: TextField(
                controller: _messageController,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: context.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Ask about this game...',
                  hintStyle: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: context.textMuted,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
                textInputAction: TextInputAction.send,
              ),
            ),
          ],
          
          // Send button
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.accentPurple, AppColors.accentBlue],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              onPressed: chatState.isLoading ? null : () {
                if (_messageController.text.isEmpty) {
                  // Show input field
                  setState(() {
                    _messageController.text = ' ';
                    _messageController.selection = TextSelection.collapsed(
                      offset: 0,
                    );
                  });
                } else {
                  _sendMessage();
                }
              },
              icon: Icon(
                _messageController.text.isEmpty 
                    ? Icons.chat_bubble_outline 
                    : Icons.send,
                color: Colors.white,
                size: 20,
              ),
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _sendQuickMessage(String message) {
    ref.read(aiChatProvider.notifier).sendMessage(message);
    _scrollToBottom();
  }
}

/// Individual message bubble
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showAvatar;
  
  const _MessageBubble({
    required this.message,
    required this.showAvatar,
  });
  
  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    
    return Padding(
      padding: EdgeInsets.only(
        top: showAvatar ? 12 : 4,
        bottom: 4,
      ),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Avatar
          if (!isUser && showAvatar)
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentPurple.withOpacity(0.3),
                    AppColors.accentBlue.withOpacity(0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.auto_awesome,
                color: AppColors.accentPurple,
                size: 14,
              ),
            )
          else if (!isUser)
            const SizedBox(width: 36),
          
          // Message content
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser 
                    ? AppColors.accentBlue.withOpacity(0.15)
                    : context.bgSecondary,
                borderRadius: BorderRadius.circular(16).copyWith(
                  topLeft: isUser ? null : const Radius.circular(4),
                  topRight: isUser ? const Radius.circular(4) : null,
                ),
                border: Border.all(
                  color: isUser 
                      ? AppColors.accentBlue.withOpacity(0.2)
                      : context.borderColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.isLoading && message.text.isEmpty)
                    _TypingIndicator()
                  else
                    _FormattedText(
                      text: message.text,
                      isUser: isUser,
                    ),
                ],
              ),
            ),
          ),
          
          // User avatar placeholder
          if (isUser)
            const SizedBox(width: 36),
        ],
      ),
    );
  }
}

/// Typing indicator animation
class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final offset = (_controller.value * 3 - index).clamp(0.0, 1.0);
              final bounce = (1 - (offset * 2 - 1).abs()) * 4;
              
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                child: Transform.translate(
                  offset: Offset(0, -bounce),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.accentPurple.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

/// Formatted text with basic markdown support
class _FormattedText extends StatelessWidget {
  final String text;
  final bool isUser;
  
  const _FormattedText({
    required this.text,
    required this.isUser,
  });
  
  @override
  Widget build(BuildContext context) {
    // Simple markdown-like formatting
    final spans = _parseText(context, text);
    
    return RichText(
      text: TextSpan(
        style: GoogleFonts.dmSans(
          fontSize: 14,
          color: isUser ? context.textPrimary : context.textPrimary,
          height: 1.5,
        ),
        children: spans,
      ),
    );
  }
  
  List<InlineSpan> _parseText(BuildContext context, String text) {
    final spans = <InlineSpan>[];
    final boldPattern = RegExp(r'\*\*(.+?)\*\*');
    
    int lastEnd = 0;
    for (final match in boldPattern.allMatches(text)) {
      // Add text before the match
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      
      // Add bold text
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(fontWeight: FontWeight.w700),
      ));
      
      lastEnd = match.end;
    }
    
    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }
    
    return spans;
  }
}

/// Quick suggestion chip
class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  
  const _SuggestionChip({
    required this.label,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.accentPurple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.accentPurple.withOpacity(0.2),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.accentPurple,
          ),
        ),
      ),
    );
  }
}
