import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../Models/user_profile.dart';
import '../Providers/user_provider.dart';
import '../theme/app_theme.dart';
import 'other_user_profile_screen.dart';

/// Widget for searching users - can be used inline or as standalone
class UserSearchWidget extends ConsumerStatefulWidget {
  final bool showAsDrawerSection;
  final VoidCallback? onUserSelected;

  const UserSearchWidget({
    super.key,
    this.showAsDrawerSection = false,
    this.onUserSelected,
  });

  @override
  ConsumerState<UserSearchWidget> createState() => _UserSearchWidgetState();
}

class _UserSearchWidgetState extends ConsumerState<UserSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  List<UserProfile> _searchResults = [];
  Map<String, bool> _followingStatus = {};
  Map<String, bool> _loadingStatus = {};
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final userService = ref.read(userServiceProvider);
      final results = await userService.searchUsers(query);
      
      // Check following status for each result
      final followingMap = <String, bool>{};
      for (final profile in results) {
        followingMap[profile.uid] = await userService.isFollowing(profile.uid);
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
          _followingStatus = followingMap;
          _isSearching = false;
          _hasSearched = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _hasSearched = true;
        });
      }
    }
  }

  Future<void> _toggleFollow(UserProfile profile) async {
    if (_loadingStatus[profile.uid] == true) return;

    setState(() => _loadingStatus[profile.uid] = true);

    try {
      final userService = ref.read(userServiceProvider);
      final isCurrentlyFollowing = _followingStatus[profile.uid] ?? false;

      if (isCurrentlyFollowing) {
        final result = await userService.unfollowUser(profile.uid);
        if (result.success && mounted) {
          setState(() {
            _followingStatus[profile.uid] = false;
          });
        }
      } else {
        final result = await userService.followUser(profile.uid);
        if (result.success && mounted) {
          setState(() {
            _followingStatus[profile.uid] = true;
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() => _loadingStatus[profile.uid] = false);
      }
    }
  }

  void _navigateToProfile(UserProfile profile) {
    widget.onUserSelected?.call();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtherUserProfileScreen(userId: profile.uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showAsDrawerSection) {
      return _buildDrawerSection();
    }
    return _buildFullScreen();
  }

  Widget _buildDrawerSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: context.borderColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FIND USERS',
            style: GoogleFonts.spaceMono(
              fontSize: 11,
              color: context.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildSearchInput(),
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accentBlue,
                  ),
                ),
              ),
            )
          else if (_searchResults.isNotEmpty)
            _buildSearchResults()
          else if (_hasSearched && _searchController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'No users found',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: context.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFullScreen() {
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
          'Find Users',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildSearchInput(),
          ),
          Expanded(
            child: _isSearching
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.accentBlue),
                  )
                : _searchResults.isNotEmpty
                    ? ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          return _buildSearchResultItem(_searchResults[index]);
                        },
                      )
                    : _hasSearched && _searchController.text.isNotEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 48,
                                  color: context.textMuted,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No users found',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 16,
                                    color: context.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search,
                                  size: 48,
                                  color: context.textMuted,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Search by username',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 16,
                                    color: context.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchInput() {
    return Container(
      decoration: BoxDecoration(
        color: context.bgPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor, width: 2),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          color: context.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Search by username...',
          hintStyle: GoogleFonts.dmSans(
            fontSize: 14,
            color: context.textMuted,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: context.textMuted,
            size: 20,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: context.textMuted, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchResults = [];
                      _hasSearched = false;
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      constraints: const BoxConstraints(maxHeight: 250),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          return _buildCompactSearchResultItem(_searchResults[index]);
        },
      ),
    );
  }

  Widget _buildCompactSearchResultItem(UserProfile profile) {
    final isFollowing = _followingStatus[profile.uid] ?? false;
    final isLoading = _loadingStatus[profile.uid] ?? false;

    return InkWell(
      onTap: () => _navigateToProfile(profile),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: context.borderColor),
              ),
              child: ClipOval(
                child: profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: profile.photoUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _buildSmallInitials(profile),
                        errorWidget: (_, __, ___) => _buildSmallInitials(profile),
                      )
                    : _buildSmallInitials(profile),
              ),
            ),
            const SizedBox(width: 10),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName.isNotEmpty 
                        ? profile.displayName 
                        : profile.username,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '@${profile.username}',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.accentBlue,
                    ),
                  ),
                ],
              ),
            ),
            // Follow button
            _buildSmallFollowButton(profile, isFollowing, isLoading),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultItem(UserProfile profile) {
    final isFollowing = _followingStatus[profile.uid] ?? false;
    final isLoading = _loadingStatus[profile.uid] ?? false;

    return InkWell(
      onTap: () => _navigateToProfile(profile),
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
                border: Border.all(color: context.borderColor, width: 2),
              ),
              child: ClipOval(
                child: profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: profile.photoUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _buildInitials(profile),
                        errorWidget: (_, __, ___) => _buildInitials(profile),
                      )
                    : _buildInitials(profile),
              ),
            ),
            const SizedBox(width: 12),
            // Info
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
            // Follow button
            _buildFollowButton(profile, isFollowing, isLoading),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallFollowButton(UserProfile profile, bool isFollowing, bool isLoading) {
    if (isLoading) {
      return SizedBox(
        width: 60,
        height: 28,
        child: Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: isFollowing ? AppColors.accentGreen : AppColors.accentBlue,
            ),
          ),
        ),
      );
    }

    if (isFollowing) {
      return GestureDetector(
        onTap: () => _toggleFollow(profile),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: context.borderColor),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Following',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _toggleFollow(profile),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.accentBlue,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Follow',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildFollowButton(UserProfile profile, bool isFollowing, bool isLoading) {
    if (isLoading) {
      return SizedBox(
        width: 80,
        height: 32,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: isFollowing ? AppColors.accentGreen : AppColors.accentBlue,
            ),
          ),
        ),
      );
    }

    if (isFollowing) {
      return OutlinedButton(
        onPressed: () => _toggleFollow(profile),
        style: OutlinedButton.styleFrom(
          foregroundColor: context.textSecondary,
          side: BorderSide(color: context.borderColor),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          minimumSize: const Size(80, 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          'Following',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return ElevatedButton(
      onPressed: () => _toggleFollow(profile),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accentBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        minimumSize: const Size(80, 32),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        'Follow',
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInitials(UserProfile profile) {
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

  Widget _buildSmallInitials(UserProfile profile) {
    return Container(
      color: context.bgCard,
      child: Center(
        child: Text(
          profile.initials.isNotEmpty ? profile.initials : '?',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.accentPurple,
          ),
        ),
      ),
    );
  }
}
