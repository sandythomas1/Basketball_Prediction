import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../Models/user_profile.dart';
import '../Providers/user_provider.dart';
import '../theme/app_theme.dart';

import 'followers_list_screen.dart';

/// Screen to view another user's profile
class OtherUserProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const OtherUserProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  ConsumerState<OtherUserProfileScreen> createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends ConsumerState<OtherUserProfileScreen> {
  UserProfile? _profile;
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userService = ref.read(userServiceProvider);
      final profile = await userService.getProfile(widget.userId);
      final isFollowing = await userService.isFollowing(widget.userId);
      
      if (mounted) {
        setState(() {
          _profile = profile;
          _isFollowing = isFollowing;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load profile';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_isFollowLoading || _profile == null) return;

    setState(() => _isFollowLoading = true);

    try {
      final userService = ref.read(userServiceProvider);
      
      if (_isFollowing) {
        final result = await userService.unfollowUser(widget.userId);
        if (result.success && mounted) {
          setState(() {
            _isFollowing = false;
            // Update local followers count
            _profile = _profile!.copyWith(
              followersCount: (_profile!.followersCount - 1).clamp(0, 999999),
            );
          });
        } else if (!result.success && mounted) {
          _showErrorSnackBar(result.errorMessage ?? 'Failed to unfollow');
        }
      } else {
        final result = await userService.followUser(widget.userId);
        if (result.success && mounted) {
          setState(() {
            _isFollowing = true;
            // Update local followers count
            _profile = _profile!.copyWith(
              followersCount: _profile!.followersCount + 1,
            );
          });
        } else if (!result.success && mounted) {
          _showErrorSnackBar(result.errorMessage ?? 'Failed to follow');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isFollowLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorRed,
      ),
    );
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
          'Profile',
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
              'Loading profile...',
              style: GoogleFonts.dmSans(color: context.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_error != null || _profile == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: context.textMuted),
            const SizedBox(height: 16),
            Text(
              _error ?? 'User not found',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProfile,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Profile Header
          _buildProfileHeader(),
          const SizedBox(height: 24),
          // Member Info Card
          _buildInfoCard(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final profile = _profile!;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.accentBlue.withOpacity(0.1),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        children: [
          // Profile Photo
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: context.borderColor,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentBlue.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipOval(
              child: profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: profile.photoUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _buildInitialsAvatar(),
                      errorWidget: (_, __, ___) => _buildInitialsAvatar(),
                    )
                  : _buildInitialsAvatar(),
            ),
          ),
          const SizedBox(height: 16),
          // Name
          Text(
            profile.displayName.isNotEmpty 
                ? profile.displayName 
                : profile.username,
            style: GoogleFonts.dmSans(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          // Username
          Text(
            '@${profile.username}',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              color: AppColors.accentBlue,
            ),
          ),
          const SizedBox(height: 12),
          // Followers Count (Tappable)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FollowersListScreen(
                    userId: profile.uid,
                    userName: profile.displayName,
                  ),
                ),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 16,
                  color: context.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  '${profile.followersCount}',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Followers',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Follow Button
          _buildFollowButton(),
        ],
      ),
    );
  }

  Widget _buildFollowButton() {
    if (_isFollowing) {
      return OutlinedButton.icon(
        onPressed: _isFollowLoading ? null : _toggleFollow,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentGreen,
          side: BorderSide(color: AppColors.accentGreen, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: _isFollowLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accentGreen,
                ),
              )
            : const Icon(Icons.check, size: 18),
        label: Text(
          'Following',
          style: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: _isFollowLoading ? null : _toggleFollow,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accentBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      icon: _isFollowLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.person_add, size: 18),
      label: Text(
        'Follow',
        style: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInitialsAvatar() {
    final profile = _profile!;
    return Container(
      color: context.bgCard,
      child: Center(
        child: Text(
          profile.initials.isNotEmpty ? profile.initials : '?',
          style: GoogleFonts.dmSans(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: AppColors.accentPurple,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final profile = _profile!;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MEMBER INFO',
              style: GoogleFonts.spaceMono(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: context.textMuted,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatRow('Member Since', _formatDate(profile.createdAt)),
            Divider(height: 24, color: context.borderColor),
            _buildStatRow('Followers', profile.followersCount.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            color: context.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.spaceMono(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: context.textPrimary,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
