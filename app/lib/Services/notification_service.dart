import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../Models/notification.dart';

/// Service class for managing user notifications
class NotificationService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Reference to notifications node
  DatabaseReference get _notificationsRef => _database.ref('notifications');

  /// Get current user's UID
  String? get currentUid => _auth.currentUser?.uid;

  /// Create a follower notification
  Future<void> createFollowerNotification(
    String targetUid,
    String followerUid,
    String followerUsername,
    String? followerPhotoUrl,
  ) async {
    try {
      final notification = AppNotification(
        id: '', // Will be set by Firebase push
        recipientUid: targetUid,
        type: 'follower',
        actorUid: followerUid,
        actorUsername: followerUsername,
        actorPhotoUrl: followerPhotoUrl,
        message: '@$followerUsername started following you',
        isRead: false,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      await _notificationsRef.child(targetUid).push().set(notification.toJson());
    } catch (e) {
      // Fail silently - don't break the follow action if notification fails
      print('Failed to create notification: $e');
    }
  }

  /// Stream of notifications for a specific user
  Stream<List<AppNotification>> getUserNotificationsStream(String uid) {
    return _notificationsRef
        .child(uid)
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null) return <AppNotification>[];

      final notificationsMap = data as Map<dynamic, dynamic>;
      final notifications = <AppNotification>[];

      for (final entry in notificationsMap.entries) {
        try {
          final notification = AppNotification.fromJson(
            entry.key as String,
            entry.value as Map<dynamic, dynamic>,
          );
          notifications.add(notification);
        } catch (e) {
          print('Error parsing notification: $e');
        }
      }

      // Sort by timestamp descending (newest first)
      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return notifications;
    });
  }

  /// Get unread notification count for a user
  Future<int> getUnreadCount(String uid) async {
    try {
      final snapshot = await _notificationsRef.child(uid).get();
      if (!snapshot.exists || snapshot.value == null) return 0;

      final notificationsMap = snapshot.value as Map<dynamic, dynamic>;
      int count = 0;

      for (final entry in notificationsMap.values) {
        final data = entry as Map<dynamic, dynamic>?;
        if (data != null && !(data['isRead'] as bool? ?? false)) {
          count++;
        }
      }

      return count;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  /// Stream of unread notification count
  Stream<int> getUnreadCountStream(String uid) {
    return _notificationsRef.child(uid).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return 0;

      final notificationsMap = data as Map<dynamic, dynamic>;
      int count = 0;

      for (final entry in notificationsMap.values) {
        final notificationData = entry as Map<dynamic, dynamic>?;
        if (notificationData != null &&
            !(notificationData['isRead'] as bool? ?? false)) {
          count++;
        }
      }

      return count;
    });
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String notificationId, String uid) async {
    try {
      await _notificationsRef
          .child(uid)
          .child(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read for a user
  Future<void> markAllAsRead(String uid) async {
    try {
      final snapshot = await _notificationsRef.child(uid).get();
      if (!snapshot.exists || snapshot.value == null) return;

      final notificationsMap = snapshot.value as Map<dynamic, dynamic>;
      final updates = <String, dynamic>{};

      for (final notificationId in notificationsMap.keys) {
        updates['notifications/$uid/$notificationId/isRead'] = true;
      }

      if (updates.isNotEmpty) {
        await _database.ref().update(updates);
      }
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId, String uid) async {
    try {
      await _notificationsRef.child(uid).child(notificationId).remove();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  /// Delete all notifications for a user
  Future<void> deleteAllNotifications(String uid) async {
    try {
      await _notificationsRef.child(uid).remove();
    } catch (e) {
      print('Error deleting all notifications: $e');
    }
  }
}
