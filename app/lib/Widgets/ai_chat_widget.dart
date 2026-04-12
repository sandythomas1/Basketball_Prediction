import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../Models/game.dart';
import '../Providers/ai_chat_provider.dart';
import '../Providers/subscription_provider.dart';
import '../Screens/pro_upgrade_screen.dart';
import '../theme/app_theme.dart';

/// AI Chat Widget for game analysis conversations.
///
/// Tapping the collapsed card opens a **full-screen** Signal chat experience.
class AIChatWidget extends ConsumerStatefulWidget {
  final Game game;

  const AIChatWidget({super.key, required this.game});

  @override
  ConsumerState<AIChatWidget> createState() => _AIChatWidgetState();
}

class _AIChatWidgetState extends ConsumerState<AIChatWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(aiChatProvider.notifier).initializeForGame(widget.game);
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatProvider);
    final isPro = ref.watch(isProProvider);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _SignalFullScreenChat(game: widget.game),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: context.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.borderColor),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentPurple.withOpacity(0.06),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Signal avatar
              _SignalAvatar(isOnline: !chatState.isRateLimited, size: 44),
              const SizedBox(width: 14),

              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Signal',
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            foreground: Paint()
                              ..shader = const LinearGradient(
                                colors: [
                                  AppColors.accentPurple,
                                  AppColors.accentBlue,
                                ],
                              ).createShader(
                                  const Rect.fromLTWH(0, 0, 80, 20)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isPro) const _ProBadge(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chatState.isRateLimited
                          ? 'Chat limit reached'
                          : 'Tap to chat about this matchup',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
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

              // Arrow indicator
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: context.textMuted,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ══  FULL-SCREEN SIGNAL CHAT  ══════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════════

class _SignalFullScreenChat extends ConsumerStatefulWidget {
  final Game game;
  const _SignalFullScreenChat({required this.game});

  @override
  ConsumerState<_SignalFullScreenChat> createState() =>
      _SignalFullScreenChatState();
}

class _SignalFullScreenChatState extends ConsumerState<_SignalFullScreenChat> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(aiChatProvider);
      if (!state.isInitialized ||
          state.currentGame?.id != widget.game.id) {
        ref.read(aiChatProvider.notifier).initializeForGame(widget.game);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
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
    final isPro = ref.watch(isProProvider);

    ref.listen<AIChatState>(aiChatProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
      if (previous?.isRateLimited == false && next.isRateLimited) {
        ProUpgradeScreen.show(context);
      }
    });

    return Scaffold(
      backgroundColor: context.bgPrimary,
      appBar: _buildAppBar(context, chatState, isPro),
      body: SafeArea(
        child: Column(
          children: [
            // Messages
            Expanded(
              child: chatState.messages.isEmpty
                  ? _buildLoadingState(context)
                  : _buildMessagesList(context, chatState),
            ),

            // Quick-action chips
            if (!chatState.isRateLimited && chatState.messages.isNotEmpty)
              _buildChipsBar(context, chatState),

            // Input area OR locked upgrade CTA
            chatState.isRateLimited
                ? _buildLockedState(context)
                : _buildInputArea(context, chatState),
          ],
        ),
      ),
    );
  }

  // ── App Bar ──────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(
      BuildContext context, AIChatState chatState, bool isPro) {
    return AppBar(
      backgroundColor: context.bgSecondary,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            color: AppColors.accentBlue, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          _SignalAvatar(isOnline: !chatState.isRateLimited, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Signal',
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        foreground: Paint()
                          ..shader = const LinearGradient(
                            colors: [
                              AppColors.accentPurple,
                              AppColors.accentBlue,
                            ],
                          ).createShader(const Rect.fromLTWH(0, 0, 80, 20)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isPro) const _ProBadge(),
                  ],
                ),
                Text(
                  '${widget.game.homeTeam.split(' ').last} vs ${widget.game.awayTeam.split(' ').last} · ${widget.game.time}',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: context.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (chatState.isInitialized)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: _ChatUsagePill(chatState: chatState)),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: context.borderColor),
      ),
    );
  }

  // ── Loading state ──────────────────────────────────────────────────────

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SignalAvatar(isOnline: true, size: 56),
          const SizedBox(height: 16),
          Text(
            'Signal is analyzing...',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.game.homeTeam} vs ${widget.game.awayTeam}',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: context.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.accentPurple,
            ),
          ),
        ],
      ),
    );
  }

  // ── Messages list ──────────────────────────────────────────────────────

  Widget _buildMessagesList(BuildContext context, AIChatState chatState) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: chatState.messages.length,
      itemBuilder: (context, index) {
        final message = chatState.messages[index];
        final showAvatar = index == 0 ||
            chatState.messages[index - 1].isUser != message.isUser;
        return _MessageBubble(
          message: message,
          showAvatar: showAvatar,
        );
      },
    );
  }

  // ── Quick-action chips ─────────────────────────────────────────────────

  Widget _buildChipsBar(BuildContext context, AIChatState chatState) {
    final game = widget.game;
    final favored = game.favoredTeam ?? game.homeTeam;

    final chips = <_ChipData>[
      _ChipData(
        icon: '🔍',
        label: 'Injury impact?',
        message: 'How do current injuries affect this game?',
        isPurple: true,
      ),
      _ChipData(
        icon: '📈',
        label: 'Key factors',
        message: 'What are the key factors in this game?',
        isPurple: false,
      ),
      _ChipData(
        icon: '🏀',
        label: 'Underdog path?',
        message:
            'What would need to happen for the underdog to win?',
        isPurple: true,
      ),
      _ChipData(
        icon: '⭐',
        label: 'Why $favored?',
        message: 'Why is $favored favored to win?',
        isPurple: false,
      ),
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = chips[index];
          return _QuickActionChip(
            icon: chip.icon,
            label: chip.label,
            isPurple: chip.isPurple,
            onTap: chatState.isLoading
                ? null
                : () => _sendQuickMessage(chip.message),
          );
        },
      ),
    );
  }

  // ── Locked / rate-limit CTA ────────────────────────────────────────────

  Widget _buildLockedState(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accentPurple.withOpacity(0.08),
            AppColors.accentBlue.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accentPurple.withOpacity(0.25),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline,
                  size: 18, color: AppColors.accentPurple),
              const SizedBox(width: 8),
              Text(
                "You've used all 3 free chats",
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
            'Resets at midnight  •  Upgrade for unlimited Signal access',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: context.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.accentPurple, AppColors.accentBlue],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: () => ProUpgradeScreen.show(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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

  // ── Input area ─────────────────────────────────────────────────────────

  Widget _buildInputArea(BuildContext context, AIChatState chatState) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: context.bgSecondary,
        border: Border(top: BorderSide(color: context.borderColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Context awareness tag
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accentPurple.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🏀 ', style: TextStyle(fontSize: 12)),
                Text(
                  'Analyzing: ${widget.game.homeTeam.split(' ').last} @ ${widget.game.awayTeam.split(' ').last}',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.accentPurple,
                  ),
                ),
              ],
            ),
          ),

          // Input row
          Container(
            decoration: BoxDecoration(
              color: context.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor),
            ),
            padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: context.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ask Signal about this game...',
                      hintStyle: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: context.textMuted,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    textInputAction: TextInputAction.send,
                    maxLines: 4,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 4),

                // Attachment icon
                _InputIconButton(
                  icon: Icons.attach_file_rounded,
                  tooltip: 'Attach context',
                  onPressed: () {
                    // Placeholder for attaching game context
                  },
                ),

                // Stats shortcut icon
                _InputIconButton(
                  icon: Icons.bar_chart_rounded,
                  tooltip: 'Game stats',
                  onPressed: () {
                    _sendQuickMessage(
                        'Show me the key stats for this matchup');
                  },
                ),

                const SizedBox(width: 4),

                // Send button
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.accentPurple, AppColors.accentBlue],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: chatState.isLoading ? null : _sendMessage,
                    icon: Icon(
                      Icons.send_rounded,
                      color: chatState.isLoading
                          ? Colors.white54
                          : Colors.white,
                      size: 20,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 40, minHeight: 40),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ══  SIGNAL AVATAR  ═════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════════

class _SignalAvatar extends StatelessWidget {
  final bool isOnline;
  final double size;

  const _SignalAvatar({required this.isOnline, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.accentPurple.withOpacity(0.25),
                  AppColors.accentBlue.withOpacity(0.25),
                ],
              ),
              borderRadius: BorderRadius.circular(size * 0.3),
              border: Border.all(
                color: AppColors.accentPurple.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                '⚡',
                style: TextStyle(fontSize: size * 0.45),
              ),
            ),
          ),
          if (isOnline)
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  color: AppColors.accentGreen,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.bgSecondary,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ══  PRO BADGE  ═════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════════

class _ProBadge extends StatelessWidget {
  const _ProBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.accentPurple, AppColors.accentBlue],
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'PRO',
        style: GoogleFonts.spaceMono(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ══  USAGE PILL  ════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════════

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
    } else if (remaining <= 1) {
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

// ═══════════════════════════════════════════════════════════════════════════════
// ══  MESSAGE BUBBLE (with timestamp, read indicator, markdown)  ═════════════
// ═══════════════════════════════════════════════════════════════════════════════

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showAvatar;

  const _MessageBubble({required this.message, required this.showAvatar});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: EdgeInsets.only(top: showAvatar ? 14 : 4, bottom: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI avatar
          if (!isUser && showAvatar)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _SignalAvatar(isOnline: true, size: 30),
            )
          else if (!isUser)
            const SizedBox(width: 38),

          // Bubble
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
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
                      : isUser
                          ? _PlainText(text: message.text)
                          : _MarkdownBody(text: message.text),
                ),

                // Timestamp + read indicator
                Padding(
                  padding:
                      const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          color: context.textMuted,
                        ),
                      ),
                      if (isUser) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all_rounded,
                          size: 13,
                          color: AppColors.accentBlue,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (isUser) const SizedBox(width: 38),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ══  MARKDOWN BODY (for AI responses)  ══════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════════

class _MarkdownBody extends StatelessWidget {
  final String text;
  const _MarkdownBody({required this.text});

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: text,
      styleSheet: MarkdownStyleSheet(
        p: GoogleFonts.dmSans(
          fontSize: 14,
          color: context.textPrimary,
          height: 1.55,
        ),
        strong: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: context.textPrimary,
        ),
        h1: GoogleFonts.dmSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: context.textPrimary,
        ),
        h2: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: context.textPrimary,
        ),
        h3: GoogleFonts.dmSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.accentPurple,
        ),
        h4: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.accentPurple,
        ),
        listBullet: GoogleFonts.dmSans(
          fontSize: 14,
          color: AppColors.accentPurple,
        ),
        listIndent: 16,
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: AppColors.accentPurple.withOpacity(0.4),
              width: 3,
            ),
          ),
        ),
        blockquotePadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        codeblockDecoration: BoxDecoration(
          color: context.bgCard,
          borderRadius: BorderRadius.circular(8),
        ),
        code: GoogleFonts.spaceMono(
          fontSize: 12,
          color: AppColors.accentPurple,
          backgroundColor: context.bgCard,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ══  PLAIN TEXT (for user messages)  ════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════════

class _PlainText extends StatelessWidget {
  final String text;
  const _PlainText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        fontSize: 14,
        color: context.textPrimary,
        height: 1.55,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ══  TYPING INDICATOR (smooth wave animation)  ═════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════════

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
      duration: const Duration(milliseconds: 1500),
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
      height: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Signal is thinking',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: context.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 8),
          ...List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                // Stagger each dot with a sine-wave for a smooth wave effect
                final progress =
                    (_controller.value + index * 0.2) % 1.0;
                final bounce =
                    (1 - (progress * 2 - 1).abs()) * 5;
                final opacity = 0.3 + 0.7 * (1 - (progress * 2 - 1).abs());
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  child: Transform.translate(
                    offset: Offset(0, -bounce),
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.accentPurple,
                              AppColors.accentBlue,
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ══  QUICK-ACTION CHIP  ════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════════

class _ChipData {
  final String icon;
  final String label;
  final String message;
  final bool isPurple;

  const _ChipData({
    required this.icon,
    required this.label,
    required this.message,
    required this.isPurple,
  });
}

class _QuickActionChip extends StatelessWidget {
  final String icon;
  final String label;
  final bool isPurple;
  final VoidCallback? onTap;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.isPurple,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor =
        isPurple ? AppColors.accentPurple : AppColors.accentBlue;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: baseColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: baseColor.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: baseColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ══  INPUT ICON BUTTON  ═════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════════

class _InputIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _InputIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: context.textMuted),
        ),
      ),
    );
  }
}
