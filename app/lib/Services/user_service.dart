import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../Models/user_profile.dart';

/// Service class for user profile management with Firebase
class UserService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _imagePicker = ImagePicker();

  /// Reference to users node
  DatabaseReference get _usersRef => _database.ref('users');

  /// Reference to usernames index node
  DatabaseReference get _usernamesRef => _database.ref('usernames');

  /// Reference to followers node
  DatabaseReference get _followersRef => _database.ref('followers');

  /// Reference to following node
  DatabaseReference get _followingRef => _database.ref('following');

  /// Get current user's UID
  String? get currentUid => _auth.currentUser?.uid;

  /// Stream of current user's profile
  Stream<UserProfile?> get profileStream {
    final uid = currentUid;
    if (uid == null) return Stream.value(null);

    return _usersRef.child(uid).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return null;
      return UserProfile.fromJson(uid, data as Map<dynamic, dynamic>);
    });
  }

  /// Get user profile by UID
  Future<UserProfile?> getProfile(String uid) async {
    final snapshot = await _usersRef.child(uid).get();
    if (!snapshot.exists || snapshot.value == null) return null;
    return UserProfile.fromJson(uid, snapshot.value as Map<dynamic, dynamic>);
  }

  /// Check if username is available
  Future<bool> isUsernameAvailable(String username) async {
    final normalizedUsername = username.toLowerCase().trim();
    if (normalizedUsername.isEmpty) return false;

    final snapshot = await _usernamesRef.child(normalizedUsername).get();
    if (!snapshot.exists) return true;

    // Check if it belongs to current user (for editing)
    final data = snapshot.value as Map<dynamic, dynamic>?;
    return data?['uid'] == currentUid;
  }

  /// Validate username format
  String? validateUsername(String? username) {
    if (username == null || username.isEmpty) {
      return 'Please enter a username';
    }
    if (username.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (username.length > 20) {
      return 'Username must be 20 characters or less';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    return null;
  }

  /// Create a new user profile after signup
  Future<UserServiceResult> createProfile({
    required String uid,
    required String email,
    required String firstName,
    required String lastName,
    required String username,
  }) async {
    try {
      final normalizedUsername = username.toLowerCase().trim();

      // Check username availability
      final isAvailable = await isUsernameAvailable(normalizedUsername);
      if (!isAvailable) {
        return UserServiceResult.failure('Username is already taken');
      }

      final profile = UserProfile(
        uid: uid,
        email: email,
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        username: normalizedUsername,
        createdAt: DateTime.now(),
      );

      // Use transaction-like approach: write both atomically
      final updates = <String, dynamic>{
        'users/$uid': profile.toJson(),
        'usernames/$normalizedUsername': {'uid': uid},
      };

      await _database.ref().update(updates);

      return UserServiceResult.success(profile);
    } catch (e) {
      return UserServiceResult.failure('Failed to create profile: $e');
    }
  }

  /// Update user profile
  Future<UserServiceResult> updateProfile({
    required String firstName,
    required String lastName,
    String? newUsername,
  }) async {
    try {
      final uid = currentUid;
      if (uid == null) {
        return UserServiceResult.failure('Not authenticated');
      }

      // Get current profile to check username change
      final currentProfile = await getProfile(uid);
      if (currentProfile == null) {
        return UserServiceResult.failure('Profile not found');
      }

      final updates = <String, dynamic>{};

      // Update user data
      updates['users/$uid/firstName'] = firstName.trim();
      updates['users/$uid/lastName'] = lastName.trim();

      // Handle username change if provided
      if (newUsername != null) {
        final normalizedNewUsername = newUsername.toLowerCase().trim();
        final normalizedOldUsername = currentProfile.username.toLowerCase();

        if (normalizedNewUsername != normalizedOldUsername) {
          // Check if new username is available
          final isAvailable = await isUsernameAvailable(normalizedNewUsername);
          if (!isAvailable) {
            return UserServiceResult.failure('Username is already taken');
          }

          // Update username index
          updates['usernames/$normalizedOldUsername'] = null; // Remove old
          updates['usernames/$normalizedNewUsername'] = {'uid': uid}; // Add new
          updates['users/$uid/username'] = normalizedNewUsername;
        }
      }

      await _database.ref().update(updates);

      // Return updated profile
      final updatedProfile = await getProfile(uid);
      return UserServiceResult.success(updatedProfile);
    } catch (e) {
      return UserServiceResult.failure('Failed to update profile: $e');
    }
  }

  /// Pick image from gallery or camera
  Future<XFile?> pickImage({required ImageSource source}) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      return image;
    } catch (e) {
      return null;
    }
  }

  /// Upload profile photo to Firebase Storage
  Future<UserServiceResult> uploadProfilePhoto(XFile imageFile) async {
    try {
      final uid = currentUid;
      if (uid == null) {
        return UserServiceResult.failure('Not authenticated');
      }

      // Create storage reference
      final storageRef = _storage.ref().child('profile_photos').child('$uid.jpg');

      // Upload file
      final file = File(imageFile.path);
      final uploadTask = await storageRef.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Get download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Update profile with new photo URL
      await _usersRef.child(uid).update({'photoUrl': downloadUrl});

      // Return updated profile
      final updatedProfile = await getProfile(uid);
      return UserServiceResult.success(updatedProfile);
    } catch (e) {
      return UserServiceResult.failure('Failed to upload photo: $e');
    }
  }

  /// Remove profile photo
  Future<UserServiceResult> removeProfilePhoto() async {
    try {
      final uid = currentUid;
      if (uid == null) {
        return UserServiceResult.failure('Not authenticated');
      }

      // Try to delete from storage (may not exist)
      try {
        final storageRef = _storage.ref().child('profile_photos').child('$uid.jpg');
        await storageRef.delete();
      } catch (_) {
        // Ignore if file doesn't exist
      }

      // Update profile to remove photo URL
      await _usersRef.child(uid).update({'photoUrl': null});

      // Return updated profile
      final updatedProfile = await getProfile(uid);
      return UserServiceResult.success(updatedProfile);
    } catch (e) {
      return UserServiceResult.failure('Failed to remove photo: $e');
    }
  }

  // ============================================================================
  // SOCIAL FEATURES - Follow/Unfollow/Search
  // ============================================================================

  /// Search users by username (case-insensitive prefix match)
  Future<List<UserProfile>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];

    final normalizedQuery = query.toLowerCase().trim();
    
    try {
      // Query usernames that start with the search query
      final snapshot = await _usernamesRef
          .orderByKey()
          .startAt(normalizedQuery)
          .endAt('$normalizedQuery\uf8ff')
          .limitToFirst(20)
          .get();

      if (!snapshot.exists || snapshot.value == null) return [];

      final usernamesMap = snapshot.value as Map<dynamic, dynamic>;
      final results = <UserProfile>[];

      for (final entry in usernamesMap.entries) {
        final data = entry.value as Map<dynamic, dynamic>?;
        final uid = data?['uid'] as String?;
        
        if (uid != null && uid != currentUid) {
          final profile = await getProfile(uid);
          if (profile != null) {
            results.add(profile);
          }
        }
      }

      return results;
    } catch (e) {
      return [];
    }
  }

  /// Follow a user
  Future<UserServiceResult> followUser(String targetUid) async {
    try {
      final uid = currentUid;
      if (uid == null) {
        return UserServiceResult.failure('Not authenticated');
      }

      if (uid == targetUid) {
        return UserServiceResult.failure('Cannot follow yourself');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Update both followers and following atomically
      final updates = <String, dynamic>{
        'followers/$targetUid/$uid': {'timestamp': timestamp},
        'following/$uid/$targetUid': {'timestamp': timestamp},
      };

      await _database.ref().update(updates);

      // Update followers count on target user
      await _updateFollowersCount(targetUid, 1);

      return UserServiceResult(success: true);
    } catch (e) {
      return UserServiceResult.failure('Failed to follow user: $e');
    }
  }

  /// Unfollow a user
  Future<UserServiceResult> unfollowUser(String targetUid) async {
    try {
      final uid = currentUid;
      if (uid == null) {
        return UserServiceResult.failure('Not authenticated');
      }

      // Remove from both followers and following atomically
      final updates = <String, dynamic>{
        'followers/$targetUid/$uid': null,
        'following/$uid/$targetUid': null,
      };

      await _database.ref().update(updates);

      // Update followers count on target user
      await _updateFollowersCount(targetUid, -1);

      return UserServiceResult(success: true);
    } catch (e) {
      return UserServiceResult.failure('Failed to unfollow user: $e');
    }
  }

  /// Check if current user is following a specific user
  Future<bool> isFollowing(String targetUid) async {
    final uid = currentUid;
    if (uid == null) return false;

    try {
      final snapshot = await _followingRef.child(uid).child(targetUid).get();
      return snapshot.exists;
    } catch (e) {
      return false;
    }
  }

  /// Get list of users who follow the specified user
  Future<List<UserProfile>> getFollowers(String targetUid) async {
    try {
      final snapshot = await _followersRef.child(targetUid).get();
      if (!snapshot.exists || snapshot.value == null) return [];

      final followersMap = snapshot.value as Map<dynamic, dynamic>;
      final followers = <UserProfile>[];

      for (final followerUid in followersMap.keys) {
        final profile = await getProfile(followerUid as String);
        if (profile != null) {
          followers.add(profile);
        }
      }

      return followers;
    } catch (e) {
      return [];
    }
  }

  /// Get followers count for a user
  Future<int> getFollowersCount(String targetUid) async {
    try {
      final snapshot = await _usersRef.child(targetUid).child('followersCount').get();
      if (!snapshot.exists || snapshot.value == null) return 0;
      return snapshot.value as int;
    } catch (e) {
      return 0;
    }
  }

  /// Update followers count (internal helper)
  Future<void> _updateFollowersCount(String targetUid, int delta) async {
    final countRef = _usersRef.child(targetUid).child('followersCount');
    
    await countRef.runTransaction((currentValue) {
      final currentCount = (currentValue as int?) ?? 0;
      final newCount = currentCount + delta;
      return Transaction.success(newCount < 0 ? 0 : newCount);
    });
  }

  /// Stream of followers for current user
  Stream<List<UserProfile>> get followersStream {
    final uid = currentUid;
    if (uid == null) return Stream.value([]);

    return _followersRef.child(uid).onValue.asyncMap((event) async {
      if (event.snapshot.value == null) return <UserProfile>[];
      
      final followersMap = event.snapshot.value as Map<dynamic, dynamic>;
      final followers = <UserProfile>[];

      for (final followerUid in followersMap.keys) {
        final profile = await getProfile(followerUid as String);
        if (profile != null) {
          followers.add(profile);
        }
      }

      return followers;
    });
  }

  // ============================================================================
  // ACCOUNT MANAGEMENT
  // ============================================================================

  /// Delete user profile (for account deletion)
  Future<UserServiceResult> deleteProfile() async {
    try {
      final uid = currentUid;
      if (uid == null) {
        return UserServiceResult.failure('Not authenticated');
      }

      // Get current profile to get username
      final profile = await getProfile(uid);
      if (profile == null) {
        return UserServiceResult.failure('Profile not found');
      }

      // Delete profile photo from storage
      try {
        final storageRef = _storage.ref().child('profile_photos').child('$uid.jpg');
        await storageRef.delete();
      } catch (_) {
        // Ignore if file doesn't exist
      }

      // Delete both user data and username index
      final updates = <String, dynamic>{
        'users/$uid': null,
        'usernames/${profile.username.toLowerCase()}': null,
      };

      await _database.ref().update(updates);

      return UserServiceResult(success: true);
    } catch (e) {
      return UserServiceResult.failure('Failed to delete profile: $e');
    }
  }
}

/// Result class for user service operations
class UserServiceResult {
  final bool success;
  final String? errorMessage;
  final UserProfile? profile;

  UserServiceResult({
    required this.success,
    this.errorMessage,
    this.profile,
  });

  factory UserServiceResult.success(UserProfile? profile) => UserServiceResult(
        success: true,
        profile: profile,
      );

  factory UserServiceResult.failure(String message) => UserServiceResult(
        success: false,
        errorMessage: message,
      );
}
