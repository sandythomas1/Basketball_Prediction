import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../Providers/auth_provider.dart';
import '../Providers/user_provider.dart';
import '../theme/app_theme.dart';

import 'followers_list_screen.dart';

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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.accentGreen,
      ),
    );
  }

  Future<void> _showChangeUsernameSheet(String currentUsername, String firstName, String lastName) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ChangeUsernameSheet(
        currentUsername: currentUsername,
        onSave: (newUsername) async {
          final userService = ref.read(userServiceProvider);
          final result = await userService.updateProfile(
            firstName: firstName,
            lastName: lastName,
            newUsername: newUsername,
          );
          if (mounted) {
            if (result.success) {
              _showSuccessSnackBar('Username updated to @$newUsername');
              ref.invalidate(userProfileProvider);
            } else {
              _showErrorSnackBar(result.errorMessage ?? 'Failed to update username');
            }
          }
        },
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
                
                // Followers Badge
                if (profile != null)
                  _buildFollowersBadge(context, profile.uid, profile.followersCount),
                
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

  Widget _buildFollowersBadge(BuildContext context, String userId, int followersCount) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FollowersListScreen(userId: userId),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: context.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people_outline,
                size: 18,
                color: AppColors.accentBlue,
              ),
              const SizedBox(width: 8),
              Text(
                '$followersCount',
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
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
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: context.textMuted,
              ),
            ],
          ),
        ),
      ),
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
            
            // Username (with edit button)
            _buildInfoRow(
              context,
              icon: Icons.alternate_email,
              label: 'Username',
              value: '@${profile.username}',
              valueColor: AppColors.accentBlue,
              onEdit: () => _showChangeUsernameSheet(
                profile.username,
                profile.firstName,
                profile.lastName,
              ),
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
    VoidCallback? onEdit,
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
        if (onEdit != null)
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.bgSecondary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.borderColor),
              ),
              child: Icon(
                Icons.edit_outlined,
                size: 16,
                color: AppColors.accentBlue,
              ),
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

/// Bottom sheet for changing username with real-time availability checking
class _ChangeUsernameSheet extends ConsumerStatefulWidget {
  final String currentUsername;
  final Future<void> Function(String newUsername) onSave;

  const _ChangeUsernameSheet({
    required this.currentUsername,
    required this.onSave,
  });

  @override
  ConsumerState<_ChangeUsernameSheet> createState() => _ChangeUsernameSheetState();
}

class _ChangeUsernameSheetState extends ConsumerState<_ChangeUsernameSheet> {
  late final TextEditingController _controller;
  bool _isChecking = false;
  bool _isSaving = false;
  bool? _isAvailable; // null = not checked, true = available, false = taken
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentUsername);
    _controller.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onUsernameChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    final value = _controller.text;

    // Reset state
    setState(() {
      _isAvailable = null;
      _validationError = null;
    });

    // If same as current, no need to check
    if (value.toLowerCase().trim() == widget.currentUsername.toLowerCase()) {
      return;
    }

    // Validate format first
    final userService = ref.read(userServiceProvider);
    final error = userService.validateUsername(value);
    if (error != null) {
      setState(() => _validationError = error);
      return;
    }

    // Debounced availability check
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (!mounted || _controller.text != value) return;
      setState(() => _isChecking = true);
      final available = await userService.isUsernameAvailable(value.toLowerCase().trim());
      if (!mounted || _controller.text != value) return;
      setState(() {
        _isChecking = false;
        _isAvailable = available;
      });
    });
  }

  bool get _canSave {
    final value = _controller.text;
    if (_isSaving || _isChecking) return false;
    if (value.toLowerCase().trim() == widget.currentUsername.toLowerCase()) return false;
    if (_validationError != null) return false;
    return _isAvailable == true;
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await widget.onSave(_controller.text.toLowerCase().trim());
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.text;
    final isUnchanged = value.toLowerCase().trim() == widget.currentUsername.toLowerCase();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.bgCard,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Change Username',
              style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose a unique username. Others can search for you by it.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Input field
            TextFormField(
              controller: _controller,
              autofocus: true,
              style: GoogleFonts.dmSans(fontSize: 16, color: context.textPrimary),
              decoration: InputDecoration(
                prefixText: '@',
                prefixStyle: GoogleFonts.dmSans(
                  fontSize: 16,
                  color: context.textSecondary,
                ),
                hintText: 'username',
                hintStyle: GoogleFonts.dmSans(color: context.textMuted),
                suffixIcon: _buildSuffixIcon(),
              ),
            ),

            // Status message
            const SizedBox(height: 8),
            _buildStatusMessage(isUnchanged),

            const SizedBox(height: 24),

            // Buttons row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: context.borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: _canSave
                          ? const LinearGradient(
                              colors: [AppColors.accentOrange, AppColors.accentYellow],
                            )
                          : null,
                      color: _canSave ? null : context.bgSecondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      onPressed: _canSave ? _save : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Save',
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w600,
                                color: _canSave ? Colors.white : context.textMuted,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget? _buildSuffixIcon() {
    if (_controller.text.isEmpty) return null;
    if (_isChecking) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentOrange),
        ),
      );
    }
    if (_isAvailable == true) {
      return const Icon(Icons.check_circle, color: AppColors.accentGreen);
    }
    if (_isAvailable == false) {
      return const Icon(Icons.cancel, color: AppColors.errorRed);
    }
    if (_validationError != null) {
      return const Icon(Icons.error_outline, color: AppColors.errorRed);
    }
    return null;
  }

  Widget _buildStatusMessage(bool isUnchanged) {
    if (isUnchanged) {
      return Text(
        'This is your current username',
        style: GoogleFonts.dmSans(fontSize: 13, color: context.textMuted),
      );
    }
    if (_validationError != null) {
      return Text(
        _validationError!,
        style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.errorRed),
      );
    }
    if (_isChecking) {
      return Text(
        'Checking availability...',
        style: GoogleFonts.dmSans(fontSize: 13, color: context.textMuted),
      );
    }
    if (_isAvailable == true) {
      return Text(
        'Username is available!',
        style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.accentGreen),
      );
    }
    if (_isAvailable == false) {
      return Text(
        'Username is already taken',
        style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.errorRed),
      );
    }
    return const SizedBox.shrink();
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
