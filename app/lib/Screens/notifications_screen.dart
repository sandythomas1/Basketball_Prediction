import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../Models/notification.dart';
import '../Providers/notification_provider.dart';
import '../theme/app_theme.dart';

import 'other_user_profile_screen.dart';

/// Screen displaying user notifications
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);

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
          'Notifications',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          notificationsAsync.when(
            data: (notifications) {
              final hasUnread = notifications.any((n) => !n.isRead);
              if (!hasUnread) return const SizedBox.shrink();
              
              return TextButton(
                onPressed: () => _markAllAsRead(),
                child: Text(
                  'Mark all read',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.accentBlue,
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) => _buildNotificationsList(notifications),
        loading: () => _buildLoading(),
        error: (error, stack) => _buildError(),
      ),
    );
  }

  Widget _buildNotificationsList(List<AppNotification> notifications) {
    if (notifications.isEmpty) {
      return _buildEmptyState();
    }

    // Group notifications by date
    final today = <AppNotification>[];
    final yesterday = <AppNotification>[];
    final earlier = <AppNotification>[];

    for (final notification in notifications) {
      if (notification.isToday) {
        today.add(notification);
      } else if (notification.isYesterday) {
        yesterday.add(notification);
      } else {
        earlier.add(notification);
      }
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(notificationsStreamProvider);
      },
      color: AppColors.accentOrange,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (today.isNotEmpty) ...[
            _buildSectionHeader('Today'),
            ...today.map((n) => _buildNotificationItem(n)),
          ],
          if (yesterday.isNotEmpty) ...[
            _buildSectionHeader('Yesterday'),
            ...yesterday.map((n) => _buildNotificationItem(n)),
          ],
          if (earlier.isNotEmpty) ...[
            _buildSectionHeader('Earlier'),
            ...earlier.map((n) => _buildNotificationItem(n)),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.textMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildNotificationItem(AppNotification notification) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.errorRed.withOpacity(0.1),
        child: Icon(
          Icons.delete_outline,
          color: AppColors.errorRed,
          size: 24,
        ),
      ),
      onDismissed: (direction) {
        _deleteNotification(notification);
      },
      child: InkWell(
        onTap: () => _handleNotificationTap(notification),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: notification.isRead
                ? Colors.transparent
                : AppColors.accentBlue.withOpacity(0.05),
            border: Border(
              bottom: BorderSide(
                color: context.borderColor,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile photo or initials
              _buildAvatar(notification),
              const SizedBox(width: 12),
              // Notification content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: context.textPrimary,
                          height: 1.4,
                        ),
                        children: [
                          TextSpan(
                            text: '@${notification.actorUsername}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const TextSpan(text: ' started following you'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.getTimeAgo(),
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: context.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Unread indicator
              if (!notification.isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6, left: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(AppNotification notification) {
    if (notification.actorPhotoUrl != null &&
        notification.actorPhotoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CachedNetworkImage(
          imageUrl: notification.actorPhotoUrl!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 40,
            height: 40,
            color: context.bgCard,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.textMuted,
                ),
              ),
            ),
          ),
          errorWidget: (context, url, error) => _buildInitialsAvatar(notification),
        ),
      );
    }
    return _buildInitialsAvatar(notification);
  }

  Widget _buildInitialsAvatar(AppNotification notification) {
    final initials = notification.actorUsername.isNotEmpty
        ? notification.actorUsername[0].toUpperCase()
        : '?';

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.accentBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 80,
            color: context.textMuted.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When someone follows you,\nyou\'ll see it here',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: context.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: CircularProgressIndicator(
        color: AppColors.accentOrange,
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 60,
            color: AppColors.errorRed.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load notifications',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              ref.invalidate(notificationsStreamProvider);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Retry',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(AppNotification notification) {
    // Mark as read
    if (!notification.isRead) {
      final notificationService = ref.read(notificationServiceProvider);
      notificationService.markAsRead(notification.id, notification.recipientUid);
    }

    // Navigate to the actor's profile
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtherUserProfileScreen(userId: notification.actorUid),
      ),
    );
  }

  void _markAllAsRead() {
    final notificationService = ref.read(notificationServiceProvider);
    final currentUid = notificationService.currentUid;
    if (currentUid != null) {
      notificationService.markAllAsRead(currentUid);
    }
  }

  void _deleteNotification(AppNotification notification) {
    final notificationService = ref.read(notificationServiceProvider);
    notificationService.deleteNotification(
      notification.id,
      notification.recipientUid,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Notification deleted',
          style: GoogleFonts.dmSans(),
        ),
        backgroundColor: context.bgCard,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
