import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Required for user data
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import '../Models/forum_message.dart';
import '../Models/user_profile.dart';
import '../Providers/user_provider.dart'; // Import your existing provider

class ForumsDiscussionScreen extends ConsumerStatefulWidget { // Changed to ConsumerStatefulWidget
  final String? gameId;
  const ForumsDiscussionScreen({super.key, this.gameId});

  @override
  ConsumerState<ForumsDiscussionScreen> createState() => _ForumsDiscussionScreenState();
}

class _ForumsDiscussionScreenState extends ConsumerState<ForumsDiscussionScreen> {
  final _messageController = TextEditingController();
  late DatabaseReference _dbRef;

  @override
  void initState() {
    super.initState();
    // Path: forums/games/{id} OR forums/general
    final gameKey = _resolveGameKey(widget.gameId);
    final path = gameKey == 'general' ? 'forums/general' : 'forums/games/$gameKey';
    _dbRef = FirebaseDatabase.instance.ref().child('$path/messages');
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(UserProfile profile) async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

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
        SnackBar(content: Text(e.message ?? 'Failed to send message.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access your actual user profile from your provider
    final userProfileAsync = ref.watch(userProfileProvider);
    final userProfile = userProfileAsync.asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.gameId != null ? 'Game Chat' : 'Global Forum'),
      ),
      body: Column(
        children: [
          Expanded(
            child: FirebaseAnimatedList(
              query: _dbRef.limitToLast(50),
              itemBuilder: (context, snapshot, animation, index) {
                if (snapshot.value == null) return const SizedBox.shrink();
                
                final data = snapshot.value as Map<dynamic, dynamic>;
                final message = ForumMessage.fromMap(snapshot.key!, data);
                return _buildMessageBubble(message, userProfile?.uid);
              },
            ),
          ),
          userProfileAsync.when(
            data: (profile) {
              if (profile == null) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("Please log in to participate in the chat."),
                );
              }
              return _buildMessageInput(profile);
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Loading profile..."),
            ),
            error: (_, __) => const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("Unable to load profile."),
            ),
          ),
        ],
      ),
    );
  }

  // Moved inside the State class
  Widget _buildMessageBubble(ForumMessage message, String? currentUid) {
    final isMe = message.senderId == currentUid;
    return ListTile(
      leading: isMe ? null : CircleAvatar(
        backgroundImage: message.senderPhoto != null ? NetworkImage(message.senderPhoto!) : null,
        child: message.senderPhoto == null ? Text(message.senderName.isNotEmpty ? message.senderName[0] : '?') : null,
      ),
      trailing: isMe ? CircleAvatar(
        backgroundImage: message.senderPhoto != null ? NetworkImage(message.senderPhoto!) : null,
        child: message.senderPhoto == null ? Text(message.senderName.isNotEmpty ? message.senderName[0] : '?') : null,
      ) : null,
      title: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isMe ? Theme.of(context).primaryColor : Colors.grey[300],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            message.text,
            style: TextStyle(color: isMe ? Colors.white : Colors.black),
          ),
        ),
      ),
      subtitle: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          message.senderName,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  // Moved inside the State class
  Widget _buildMessageInput(UserProfile profile) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _sendMessage(profile),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () => _sendMessage(profile),
          ),
        ],
      ),
    );
  }

  String _resolveGameKey(String? gameId) {
    final raw = gameId?.trim();
    if (raw == null || raw.isEmpty) return 'general';
    final safe = raw.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
    return safe.isEmpty ? 'general' : safe;
  }
}
