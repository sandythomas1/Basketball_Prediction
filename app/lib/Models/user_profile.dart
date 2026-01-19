/// User profile model for Firebase Realtime Database
class UserProfile {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String username;
  final String? photoUrl;
  final DateTime createdAt;
  final int followersCount;

  UserProfile({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.username,
    this.photoUrl,
    required this.createdAt,
    this.followersCount = 0,
  });

  /// Create from Firebase Realtime Database JSON
  factory UserProfile.fromJson(String uid, Map<dynamic, dynamic> json) {
    return UserProfile(
      uid: uid,
      email: json['email'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      username: json['username'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int)
          : DateTime.now(),
      followersCount: json['followersCount'] as int? ?? 0,
    );
  }

  /// Convert to JSON for Firebase Realtime Database
  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'username': username,
      'photoUrl': photoUrl,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'followersCount': followersCount,
    };
  }

  /// Create a copy with updated fields
  UserProfile copyWith({
    String? uid,
    String? email,
    String? firstName,
    String? lastName,
    String? username,
    String? photoUrl,
    DateTime? createdAt,
    int? followersCount,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      followersCount: followersCount ?? this.followersCount,
    );
  }

  /// Get display name (first + last name)
  String get displayName => '$firstName $lastName'.trim();

  /// Get initials for avatar fallback
  String get initials {
    final first = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final last = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$first$last';
  }
}
