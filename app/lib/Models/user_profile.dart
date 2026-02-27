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

  // ── Subscription ──────────────────────────────────────────────────────────
  /// 'free' or 'pro'. Defaults to 'free' for all users.
  final String subscriptionTier;

  /// When the current subscription period expires. `null` for free users.
  final DateTime? subscriptionExpiry;

  UserProfile({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.username,
    this.photoUrl,
    required this.createdAt,
    this.followersCount = 0,
    this.subscriptionTier = 'free',
    this.subscriptionExpiry,
  });

  /// Create from Firebase Realtime Database JSON
  factory UserProfile.fromJson(String uid, Map<dynamic, dynamic> json) {
    // Subscription data lives at users/$uid/subscription in RTDB
    final sub = json['subscription'] as Map<dynamic, dynamic>?;

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
      subscriptionTier: sub?['tier'] as String? ?? 'free',
      subscriptionExpiry: sub?['expiry'] != null
          ? DateTime.fromMillisecondsSinceEpoch(sub!['expiry'] as int)
          : null,
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
      'subscription': {
        'tier': subscriptionTier,
        if (subscriptionExpiry != null)
          'expiry': subscriptionExpiry!.millisecondsSinceEpoch,
      },
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
    String? subscriptionTier,
    DateTime? subscriptionExpiry,
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
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
    );
  }

  // ── Subscription helpers ────────────────────────────────────────────────

  /// Whether the user is on the Pro plan **and** it hasn't expired.
  bool get isPro {
    if (subscriptionTier != 'pro') return false;
    if (subscriptionExpiry == null) return true; // lifetime / no expiry set
    return subscriptionExpiry!.isAfter(DateTime.now());
  }

  /// Convenience inverse of [isPro].
  bool get isFree => !isPro;

  /// Get display name (first + last name)
  String get displayName => '$firstName $lastName'.trim();

  /// Get initials for avatar fallback
  String get initials {
    final first = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final last = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$first$last';
  }
}
