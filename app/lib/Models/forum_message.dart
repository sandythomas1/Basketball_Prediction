class ForumMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderPhoto;
  final String text;
  final int timestamp;

  ForumMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderPhoto,
    required this.text,
    required this.timestamp,
  });

  factory ForumMessage.fromMap(String id, Map<dynamic, dynamic> map) {
    return ForumMessage(
      id: id,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? 'Anonymous',
      senderPhoto: map['senderPhoto'],
      text: map['text'] ?? '',
      timestamp: map['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderPhoto': senderPhoto,
      'text': text,
      'timestamp': timestamp,
    };
  }
}