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

  void _sendQuickMessage(String message) {
    ref.read(aiChatProvider.notifier).sendMessage(message);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatProvider);

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
          _buildHeader(context, chatState),
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

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, AIChatState chatState) {
    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // AI icon
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
                chatState.isRateLimited
                    ? Icons.lock_outline
                    : Icons.auto_awesome,
                color: chatState.isRateLimited
                    ? context.textMuted
                    : AppColors.accentPurple,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Title + subtitle
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
                    chatState.isRateLimited
                        ? 'Daily limit reached'
                        : 'Ask questions about this matchup',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Usage pill
            if (chatState.isInitialized) ...[
              _ChatUsagePill(chatState: chatState),
              const SizedBox(width: 8),
            ],

            // Loading / expand indicator
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
                child: Icon(Icons.keyboard_arrow_down, color: context.textMuted),
              ),
          ],
        ),
      ),
    );
  }

  // ── Chat content ────────────────────────────────────────────────────────

  Widget _buildChatContent(BuildContext context, AIChatState chatState) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 440),
      child: Column(
        children: [
          Divider(height: 1, color: context.borderColor),

          // Messages list
          Expanded(
            child: chatState.messages.isEmpty
                ? _buildLoadingState(context)
                : _buildMessagesList(context, chatState),
          ),

          // Input area OR locked upgrade CTA
          chatState.isRateLimited
              ? _buildLockedState(context)
              : _buildInputArea(context, chatState),
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
            style: GoogleFonts.dmSans(fontSize: 14, color: context.textMuted),
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

  // ── Locked / rate-limit CTA ─────────────────────────────────────────────

  Widget _buildLockedState(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accentPurple.withOpacity(0.08),
            AppColors.accentBlue.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.accentPurple.withOpacity(0.25),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline,
                  size: 18, color: AppColors.accentPurple),
              const SizedBox(width: 8),
              Text(
                "You've used all ${ref.read(aiChatProvider).dailyLimit} free chats today",
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Resets at midnight  •  Upgrade for unlimited AI access',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: context.textMuted,
            ),
          ),
          const SizedBox(height: 12),

          // Upgrade button (placeholder — wire to your paywall later)
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.accentPurple, AppColors.accentBlue],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextButton(
                onPressed: () {
                  // TODO: navigate to paywall / subscription screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pro upgrade coming soon!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Upgrade to Pro',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Input area ──────────────────────────────────────────────────────────

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
          // Suggestion chips or text field
          if (_messageController.text.isEmpty) ...[
            _SuggestionChip(
              label: 'Why favored?',
              onTap: () => _sendQuickMessage(
                  'Why is the favored team expected to win?'),
            ),
            const SizedBox(width: 8),
            _SuggestionChip(
              label: 'Key factors',
              onTap: () =>
                  _sendQuickMessage('What are the key factors in this game?'),
            ),
            const Spacer(),
          ] else ...[
            Expanded(
              child: TextField(
                controller: _messageController,
                style: GoogleFonts.dmSans(
                    fontSize: 14, color: context.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Ask about this game...',
                  hintStyle: GoogleFonts.dmSans(
                      fontSize: 14, color: context.textMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                ),
                onSubmitted: (_) => _sendMessage(),
                textInputAction: TextInputAction.send,
              ),
            ),
          ],

          // Send / open-keyboard button
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.accentPurple, AppColors.accentBlue],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              onPressed: chatState.isLoading
                  ? null
                  : () {
                      if (_messageController.text.isEmpty) {
                        setState(() {
                          _messageController.text = ' ';
                          _messageController.selection =
                              const TextSelection.collapsed(offset: 0);
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
              constraints:
                  const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Usage pill ────────────────────────────────────────────────────────────────

/// Small pill showing "3/10" or "0 left" with colour coding.
class _ChatUsagePill extends StatelessWidget {
  final AIChatState chatState;

  const _ChatUsagePill({required this.chatState});

  @override
  Widget build(BuildContext context) {
    final used = chatState.chatsUsedToday;
    final limit = chatState.dailyLimit;
    final remaining = chatState.chatsRemaining;
    final isOut = chatState.isRateLimited;

    Color pillColor;
    Color textColor;

    if (isOut) {
      pillColor = Colors.red.withOpacity(0.12);
      textColor = Colors.red.shade400;
    } else if (remaining <= 3) {
      pillColor = Colors.orange.withOpacity(0.12);
      textColor = Colors.orange.shade600;
    } else {
      pillColor = AppColors.accentPurple.withOpacity(0.10);
      textColor = AppColors.accentPurple;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: pillColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOut ? Icons.lock_outline : Icons.chat_bubble_outline,
            size: 11,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            isOut ? '0 left' : '$used/$limit',
            style: GoogleFonts.spaceMono(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showAvatar;

  const _MessageBubble({required this.message, required this.showAvatar});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: EdgeInsets.only(top: showAvatar ? 12 : 4, bottom: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              child: Icon(Icons.auto_awesome,
                  color: AppColors.accentPurple, size: 14),
            )
          else if (!isUser)
            const SizedBox(width: 36),

          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.accentBlue.withOpacity(0.15)
                    : context.bgSecondary,
                borderRadius: BorderRadius.circular(16).copyWith(
                  topLeft:
                      isUser ? null : const Radius.circular(4),
                  topRight:
                      isUser ? const Radius.circular(4) : null,
                ),
                border: Border.all(
                  color: isUser
                      ? AppColors.accentBlue.withOpacity(0.2)
                      : context.borderColor,
                ),
              ),
              child: message.isLoading && message.text.isEmpty
                  ? const _TypingIndicator()
                  : _FormattedText(text: message.text, isUser: isUser),
            ),
          ),

          if (isUser) const SizedBox(width: 36),
        ],
      ),
    );
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

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
              final offset =
                  (_controller.value * 3 - index).clamp(0.0, 1.0);
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

// ── Formatted text ────────────────────────────────────────────────────────────

class _FormattedText extends StatelessWidget {
  final String text;
  final bool isUser;

  const _FormattedText({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.dmSans(
          fontSize: 14,
          color: context.textPrimary,
          height: 1.5,
        ),
        children: _parseText(text),
      ),
    );
  }

  List<InlineSpan> _parseText(String text) {
    final spans = <InlineSpan>[];
    final boldPattern = RegExp(r'\*\*(.+?)\*\*');
    int lastEnd = 0;

    for (final match in boldPattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return spans;
  }
}

// ── Suggestion chip ───────────────────────────────────────────────────────────

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
