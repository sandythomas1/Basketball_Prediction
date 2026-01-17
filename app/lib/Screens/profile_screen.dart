import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../Providers/auth_provider.dart';
import '../Providers/user_provider.dart';
import '../theme/app_theme.dart';

/// Enhanced profile screen with user info display, photo upload, and logout
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploading = false;
  bool _isLoggingOut = false;

  Future<void> _showImageSourceDialog() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ImageSourceSheet(),
    );

    if (source != null && mounted) {
      await _pickAndUploadImage(source);
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final userService = ref.read(userServiceProvider);

    setState(() => _isUploading = true);

    try {
      final imageFile = await userService.pickImage(source: source);
      if (imageFile == null) {
        setState(() => _isUploading = false);
        return;
      }

      final result = await userService.uploadProfilePhoto(imageFile);

      if (!mounted) return;

      if (!result.success) {
        _showErrorSnackBar(result.errorMessage ?? 'Failed to upload photo');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to upload photo');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _removePhoto() async {
    final userService = ref.read(userServiceProvider);

    setState(() => _isUploading = true);

    try {
      final result = await userService.removeProfilePhoto();

      if (!mounted) return;

      if (!result.success) {
        _showErrorSnackBar(result.errorMessage ?? 'Failed to remove photo');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _logOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _LogoutConfirmDialog(),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoggingOut = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
      
      // Pop all screens and let AuthGate handle navigation to login
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to log out: $e');
        setState(() => _isLoggingOut = false);
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
    final userProfileAsync = ref.watch(userProfileProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: userProfileAsync.when(
        data: (profile) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Profile Photo Section
                _buildProfilePhoto(context, profile?.photoUrl, profile?.initials ?? ''),
                const SizedBox(height: 32),

                // User Info Card
                _buildInfoCard(
                  context,
                  profile: profile,
                  email: currentUser?.email ?? profile?.email ?? '',
                ),
                const SizedBox(height: 24),

                // Account Actions Card
                _buildActionsCard(context),
                const SizedBox(height: 40),

                // Logout Button
                _buildLogoutButton(context),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accentOrange),
        ),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: context.textMuted,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load profile',
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => ref.invalidate(userProfileProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePhoto(BuildContext context, String? photoUrl, String initials) {
    return Column(
      children: [
        GestureDetector(
          onTap: _isUploading ? null : _showImageSourceDialog,
          child: Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.borderColor,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentOrange.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _isUploading
                      ? Container(
                          color: context.bgCard,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.accentOrange,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : photoUrl != null && photoUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: photoUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: context.bgCard,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.accentOrange,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  _buildInitialsAvatar(context, initials),
                            )
                          : _buildInitialsAvatar(context, initials),
                ),
              ),
              // Camera badge
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accentOrange, AppColors.accentYellow],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentOrange.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Tap to change photo',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: context.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildInitialsAvatar(BuildContext context, String initials) {
    return Container(
      color: context.bgCard,
      child: Center(
        child: Text(
          initials.isNotEmpty ? initials : '?',
          style: GoogleFonts.dmSans(
            fontSize: 40,
            fontWeight: FontWeight.w700,
            color: AppColors.accentOrange,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required dynamic profile,
    required String email,
  }) {
    return Container(
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
            'Account Information',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          
          // Display Name
          if (profile != null) ...[
            _buildInfoRow(
              context,
              icon: Icons.person_outline,
              label: 'Name',
              value: profile.displayName.isNotEmpty 
                  ? profile.displayName 
                  : 'Not set',
            ),
            const SizedBox(height: 16),
            
            // Username
            _buildInfoRow(
              context,
              icon: Icons.alternate_email,
              label: 'Username',
              value: '@${profile.username}',
              valueColor: AppColors.accentBlue,
            ),
            const SizedBox(height: 16),
          ],
          
          // Email
          _buildInfoRow(
            context,
            icon: Icons.email_outlined,
            label: 'Email',
            value: email,
          ),
          
          if (profile != null) ...[
            const SizedBox(height: 16),
            
            // Member since
            _buildInfoRow(
              context,
              icon: Icons.calendar_today_outlined,
              label: 'Member Since',
              value: _formatDate(profile.createdAt),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.bgSecondary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: context.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? context.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionsCard(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider).valueOrNull;
    final hasPhoto = userProfile?.photoUrl != null && userProfile!.photoUrl!.isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Photo Options',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1),
          _buildActionTile(
            context,
            icon: Icons.photo_library_outlined,
            label: 'Choose from Gallery',
            onTap: () => _pickAndUploadImage(ImageSource.gallery),
          ),
          const Divider(height: 1),
          _buildActionTile(
            context,
            icon: Icons.camera_alt_outlined,
            label: 'Take a Photo',
            onTap: () => _pickAndUploadImage(ImageSource.camera),
          ),
          if (hasPhoto) ...[
            const Divider(height: 1),
            _buildActionTile(
              context,
              icon: Icons.delete_outline,
              label: 'Remove Photo',
              onTap: _removePhoto,
              isDestructive: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? AppColors.errorRed : context.textPrimary;
    
    return InkWell(
      onTap: _isUploading ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  color: color,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: context.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _isLoggingOut ? null : _logOut,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.errorRed,
          side: const BorderSide(color: AppColors.errorRed, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: _isLoggingOut
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.errorRed,
                ),
              )
            : const Icon(Icons.logout),
        label: Text(
          _isLoggingOut ? 'Logging out...' : 'Log Out',
          style: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
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

/// Bottom sheet for selecting image source
class _ImageSourceSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Choose Photo',
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.bgSecondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.photo_library_outlined,
                color: context.textPrimary,
              ),
            ),
            title: Text(
              'Choose from Gallery',
              style: GoogleFonts.dmSans(color: context.textPrimary),
            ),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.bgSecondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.camera_alt_outlined,
                color: context.textPrimary,
              ),
            ),
            title: Text(
              'Take a Photo',
              style: GoogleFonts.dmSans(color: context.textPrimary),
            ),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Logout confirmation dialog
class _LogoutConfirmDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        'Log Out',
        style: GoogleFonts.dmSans(
          fontWeight: FontWeight.w600,
          color: context.textPrimary,
        ),
      ),
      content: Text(
        'Are you sure you want to log out of your account?',
        style: GoogleFonts.dmSans(
          color: context.textSecondary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.errorRed,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Log Out',
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
