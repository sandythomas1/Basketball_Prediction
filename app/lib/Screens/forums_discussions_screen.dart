import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import '../Models/forum_message.dart';
import '../Models/user_profile.dart';
import '../Providers/user_provider.dart';
import '../theme/app_theme.dart';

class ForumsDiscussionScreen extends ConsumerStatefulWidget {
  final String? gameId;
  const ForumsDiscussionScreen({super.key, this.gameId});

  @override
  ConsumerState<ForumsDiscussionScreen> createState() => _ForumsDiscussionScreenState();
}

class _ForumsDiscussionScreenState extends ConsumerState<ForumsDiscussionScreen> {
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late DatabaseReference _dbRef;
  
  List<ForumMessage> _messages = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    final gameKey = _resolveGameKey(widget.gameId);
    final path = gameKey == 'general' ? 'forums/general' : 'forums/games/$gameKey';
    _dbRef = FirebaseDatabase.instance.ref().child('$path/messages');
    _setupMessageListener();
  }

  void _setupMessageListener() {
    // Listen to last 50 messages, ordered by timestamp
    _dbRef.orderByChild('timestamp').limitToLast(50).onValue.listen(
      (event) {
        if (!mounted) return;
        
        final data = event.snapshot.value;
        if (data == null) {
          setState(() {
            _messages = [];
            _isLoading = false;
            _errorMessage = null;
          });
          return;
        }

        final messagesMap = data as Map<dynamic, dynamic>;
        final messages = messagesMap.entries.map((entry) {
          return ForumMessage.fromMap(
            entry.key as String,
            entry.value as Map<dynamic, dynamic>,
          );
        }).toList();

        // Sort by timestamp ascending (oldest first, newest at bottom)
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        setState(() {
          _messages = messages;
          _isLoading = false;
          _errorMessage = null;
        });

        // Auto-scroll to bottom when new messages arrive
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = _parseFirebaseError(error);
        });
      },
    );
  }

  String _parseFirebaseError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('permission') || errorString.contains('denied')) {
      return 'You need to be logged in to view the game chat.';
    }
    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Network error. Please check your connection.';
    }
    return 'Unable to load messages. Please try again.';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(UserProfile profile) async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    final newMessage = ForumMessage(
      id: '',
      senderId: profile.uid,
      senderName: profile.username,
      senderPhoto: profile.photoUrl,
      text: messageText,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    try {
      await _dbRef.push().set(newMessage.toMap());
      _messageController.clear();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Failed to send message.'),
          backgroundColor: AppColors.liveRed,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString().toLowerCase().contains('permission')
          ? 'You don\'t have permission to send messages.'
          : 'Failed to send message.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.liveRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);
    final userProfile = userProfileAsync.asData?.value;
    final isLoggedIn = userProfile != null;

    return Scaffold(
      backgroundColor: context.bgPrimary,
      appBar: AppBar(
        backgroundColor: context.bgSecondary,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Icon(Icons.arrow_back, size: 20, color: AppColors.accentBlue),
                const SizedBox(width: 4),
                Text(
                  'Back',
                  style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.accentBlue),
                ),
              ],
            ),
          ),
        ),
        leadingWidth: 80,
        title: Text(
          widget.gameId != null ? 'Game Chat' : 'Global Forum',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Messages area
          Expanded(
            child: _buildMessageList(userProfile?.uid, isLoggedIn),
          ),
          // Input area
          _buildInputSection(userProfileAsync, userProfile),
        ],
      ),
    );
  }

  Widget _buildMessageList(String? currentUid, bool isLoggedIn) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.accentBlue),
            const SizedBox(height: 16),
            Text(
              'Loading messages...',
              style: GoogleFonts.dmSans(color: context.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.forum_outlined,
                size: 64,
                color: context.textMuted,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  color: context.textSecondary,
                ),
              ),
              if (!isLoggedIn) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.login),
                  label: const Text('Go Back to Login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: context.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to start the conversation!',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: context.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildMessageBubble(message, currentUid);
      },
    );
  }

  Widget _buildInputSection(AsyncValue<UserProfile?> userProfileAsync, UserProfile? profile) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.bgCard,
        border: Border(top: BorderSide(color: context.borderColor)),
      ),
      child: userProfileAsync.when(
        data: (profile) {
          if (profile == null) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                "Please log in to participate in the chat.",
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: context.textSecondary,
                ),
              ),
            );
          }
          return _buildMessageInput(profile);
        },
        loading: () => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "Loading...",
                style: GoogleFonts.dmSans(color: context.textSecondary),
              ),
            ],
          ),
        ),
        error: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            "Unable to load profile.",
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(color: context.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ForumMessage message, String? currentUid) {
    final isMe = message.senderId == currentUid;
    final time = DateTime.fromMillisecondsSinceEpoch(message.timestamp);
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            _buildAvatar(message),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.accentBlue : context.bgCard,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: isMe ? null : Border.all(color: context.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.senderName,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentGreen,
                        ),
                      ),
                    ),
                  Text(
                    message.text,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: isMe ? Colors.white : context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: GoogleFonts.spaceMono(
                      fontSize: 10,
                      color: isMe ? Colors.white70 : context.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            _buildAvatar(message),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(ForumMessage message) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: context.bgCard,
      backgroundImage: message.senderPhoto != null 
          ? NetworkImage(message.senderPhoto!) 
          : null,
      child: message.senderPhoto == null
          ? Text(
              message.senderName.isNotEmpty 
                  ? message.senderName[0].toUpperCase() 
                  : '?',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
              ),
            )
          : null,
    );
  }

  Widget _buildMessageInput(UserProfile profile) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: context.bgSecondary,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.borderColor),
            ),
            child: TextField(
              controller: _messageController,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: context.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: context.textMuted,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendMessage(profile),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.accentBlue,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: _isSending
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send, color: Colors.white, size: 20),
            onPressed: _isSending ? null : () => _sendMessage(profile),
          ),
        ),
      ],
    );
  }

  String _resolveGameKey(String? gameId) {
    final raw = gameId?.trim();
    if (raw == null || raw.isEmpty) return 'general';
    // Sanitize the gameId to be Firebase-safe (no . # $ [ ] /)
    final safe = raw.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
    return safe.isEmpty ? 'general' : safe;
  }
}
