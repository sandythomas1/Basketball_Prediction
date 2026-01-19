/// Model class for user notifications
class AppNotification {
  final String id;
  final String recipientUid;
  final String type; // 'follower', 'like', 'comment', etc.
  final String actorUid;
  final String actorUsername;
  final String? actorPhotoUrl;
  final String message;
  final bool isRead;
  final int timestamp;

  AppNotification({
    required this.id,
    required this.recipientUid,
    required this.type,
    required this.actorUid,
    required this.actorUsername,
    this.actorPhotoUrl,
    required this.message,
    required this.isRead,
    required this.timestamp,
  });

  /// Create from Firebase JSON
  factory AppNotification.fromJson(String id, Map<dynamic, dynamic> json) {
    return AppNotification(
      id: id,
      recipientUid: json['recipientUid'] as String? ?? '',
      type: json['type'] as String? ?? 'follower',
      actorUid: json['actorUid'] as String? ?? '',
      actorUsername: json['actorUsername'] as String? ?? 'Someone',
      actorPhotoUrl: json['actorPhotoUrl'] as String?,
      message: json['message'] as String? ?? '',
      isRead: json['isRead'] as bool? ?? false,
      timestamp: json['timestamp'] as int? ?? 0,
    );
  }

  /// Convert to Firebase JSON
  Map<String, dynamic> toJson() {
    return {
      'recipientUid': recipientUid,
      'type': type,
      'actorUid': actorUid,
      'actorUsername': actorUsername,
      'actorPhotoUrl': actorPhotoUrl,
      'message': message,
      'isRead': isRead,
      'timestamp': timestamp,
    };
  }

  /// Copy with modifications
  AppNotification copyWith({
    String? id,
    String? recipientUid,
    String? type,
    String? actorUid,
    String? actorUsername,
    String? actorPhotoUrl,
    String? message,
    bool? isRead,
    int? timestamp,
  }) {
    return AppNotification(
      id: id ?? this.id,
      recipientUid: recipientUid ?? this.recipientUid,
      type: type ?? this.type,
      actorUid: actorUid ?? this.actorUid,
      actorUsername: actorUsername ?? this.actorUsername,
      actorPhotoUrl: actorPhotoUrl ?? this.actorPhotoUrl,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Get formatted time ago string
  String getTimeAgo() {
    final now = DateTime.now();
    final notificationTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final difference = now.difference(notificationTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '${minutes}m ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '${hours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }

  /// Check if notification is from today
  bool get isToday {
    final now = DateTime.now();
    final notificationDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return now.year == notificationDate.year &&
        now.month == notificationDate.month &&
        now.day == notificationDate.day;
  }

  /// Check if notification is from yesterday
  bool get isYesterday {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final notificationDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return yesterday.year == notificationDate.year &&
        yesterday.month == notificationDate.month &&
        yesterday.day == notificationDate.day;
  }
}
