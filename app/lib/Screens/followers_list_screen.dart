import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../Models/user_profile.dart';
import '../Providers/user_provider.dart';
import '../theme/app_theme.dart';
import 'other_user_profile_screen.dart';

/// Screen displaying the list of followers for a user
class FollowersListScreen extends ConsumerStatefulWidget {
  final String userId;
  final String? userName;

  const FollowersListScreen({
    super.key,
    required this.userId,
    this.userName,
  });

  @override
  ConsumerState<FollowersListScreen> createState() => _FollowersListScreenState();
}

class _FollowersListScreenState extends ConsumerState<FollowersListScreen> {
  List<UserProfile> _followers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFollowers();
  }

  Future<void> _loadFollowers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userService = ref.read(userServiceProvider);
      final followers = await userService.getFollowers(widget.userId);
      
      if (mounted) {
        setState(() {
          _followers = followers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load followers';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Followers',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.accentBlue),
            const SizedBox(height: 16),
            Text(
              'Loading followers...',
              style: GoogleFonts.dmSans(color: context.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: context.textMuted),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFollowers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_followers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: context.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'No followers yet',
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When people follow you, they\'ll appear here',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: context.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFollowers,
      color: AppColors.accentBlue,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _followers.length,
        itemBuilder: (context, index) {
          final follower = _followers[index];
          return _FollowerItem(
            profile: follower,
            onTap: () => _navigateToProfile(follower),
          );
        },
      ),
    );
  }

  void _navigateToProfile(UserProfile profile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtherUserProfileScreen(userId: profile.uid),
      ),
    );
  }
}

class _FollowerItem extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onTap;

  const _FollowerItem({
    required this.profile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.borderColor,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: profile.photoUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _buildInitials(context),
                        errorWidget: (_, __, ___) => _buildInitials(context),
                      )
                    : _buildInitials(context),
              ),
            ),
            const SizedBox(width: 12),
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName.isNotEmpty 
                        ? profile.displayName 
                        : profile.username,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${profile.username}',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: AppColors.accentBlue,
                    ),
                  ),
                ],
              ),
            ),
            // Arrow
            Icon(
              Icons.chevron_right,
              color: context.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitials(BuildContext context) {
    return Container(
      color: context.bgCard,
      child: Center(
        child: Text(
          profile.initials.isNotEmpty ? profile.initials : '?',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.accentPurple,
          ),
        ),
      ),
    );
  }
}
