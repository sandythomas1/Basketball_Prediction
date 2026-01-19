import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../Models/notification.dart';
import '../Services/notification_service.dart';
import 'auth_provider.dart';

/// Provider for the NotificationService singleton
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Provider that streams the current user's notifications from Firebase
final notificationsStreamProvider = StreamProvider<List<AppNotification>>((ref) {
  final authState = ref.watch(authStateProvider);
  final notificationService = ref.watch(notificationServiceProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value([]);
      return notificationService.getUserNotificationsStream(user.uid);
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

/// Provider that streams the unread notification count
final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  final authState = ref.watch(authStateProvider);
  final notificationService = ref.watch(notificationServiceProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(0);
      return notificationService.getUnreadCountStream(user.uid);
    },
    loading: () => Stream.value(0),
    error: (_, __) => Stream.value(0),
  );
});

/// Provider for checking if there are unread notifications (for badge display)
final hasUnreadNotificationsProvider = Provider<bool>((ref) {
  final unreadCount = ref.watch(unreadNotificationCountProvider);
  return unreadCount.valueOrNull != null && unreadCount.valueOrNull! > 0;
});
