/// Input validation utilities for production-grade security.
///
/// Provides consistent validation across the app with clear error messages.
class Validators {
  // Private constructor - utility class
  Validators._();

  // ============================================================================
  // EMAIL VALIDATION
  // ============================================================================

  /// RFC 5322 compliant email regex pattern
  static final RegExp _emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
    caseSensitive: false,
  );

  /// Validates email address format.
  ///
  /// Returns null if valid, error message if invalid.
  static String? validateEmail(String? email) {
    if (email == null || email.trim().isEmpty) {
      return 'Please enter your email address';
    }

    final trimmed = email.trim();

    if (trimmed.length > 254) {
      return 'Email address is too long';
    }

    if (!_emailRegex.hasMatch(trimmed)) {
      return 'Please enter a valid email address';
    }

    // Check for common typos
    final lowerEmail = trimmed.toLowerCase();
    if (lowerEmail.endsWith('.con')) {
      return 'Did you mean .com?';
    }
    if (lowerEmail.contains('@gmail') && !lowerEmail.contains('@gmail.')) {
      return 'Did you mean @gmail.com?';
    }

    return null;
  }

  // ============================================================================
  // PASSWORD VALIDATION
  // ============================================================================

  /// Minimum password length
  static const int minPasswordLength = 8;

  /// Maximum password length (prevent DoS attacks)
  static const int maxPasswordLength = 128;

  /// Password strength levels
  static const List<String> strengthLabels = [
    'Very Weak',
    'Weak',
    'Fair',
    'Strong',
    'Very Strong',
  ];

  /// Validates password meets security requirements.
  ///
  /// Requirements:
  /// - At least 8 characters
  /// - Contains at least one uppercase letter
  /// - Contains at least one lowercase letter
  /// - Contains at least one number
  ///
  /// Returns null if valid, error message if invalid.
  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Please enter a password';
    }

    if (password.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters';
    }

    if (password.length > maxPasswordLength) {
      return 'Password is too long';
    }

    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }

    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }

    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }

    // Check for common weak passwords
    final lowerPassword = password.toLowerCase();
    const weakPasswords = [
      'password',
      '12345678',
      'qwerty12',
      'letmein1',
      'welcome1',
    ];
    if (weakPasswords.any((weak) => lowerPassword.contains(weak))) {
      return 'This password is too common. Please choose a stronger one.';
    }

    return null;
  }

  /// Validates password for login (less strict - just check not empty).
  ///
  /// Login doesn't enforce strength rules since existing passwords may not meet them.
  static String? validateLoginPassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Please enter your password';
    }
    return null;
  }

  /// Calculate password strength score (0-4).
  ///
  /// Returns a score based on:
  /// - Length (1 point for 8+, 1 point for 12+)
  /// - Character variety (1 point each for: uppercase, lowercase, numbers, symbols)
  static int calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0;

    int score = 0;

    // Length bonuses
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;

    // Character variety
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[a-z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score++;

    // Normalize to 0-4 scale
    return (score / 6 * 4).round().clamp(0, 4);
  }

  /// Get password strength label.
  static String getPasswordStrengthLabel(String password) {
    return strengthLabels[calculatePasswordStrength(password)];
  }

  // ============================================================================
  // USERNAME VALIDATION
  // ============================================================================

  /// Valid username characters
  static final RegExp _usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');

  /// Validates username format.
  ///
  /// Requirements:
  /// - 3-20 characters
  /// - Only letters, numbers, and underscores
  /// - Cannot start with a number
  ///
  /// Returns null if valid, error message if invalid.
  static String? validateUsername(String? username) {
    if (username == null || username.trim().isEmpty) {
      return 'Please enter a username';
    }

    final trimmed = username.trim();

    if (trimmed.length < 3) {
      return 'Username must be at least 3 characters';
    }

    if (trimmed.length > 20) {
      return 'Username must be 20 characters or less';
    }

    if (!_usernameRegex.hasMatch(trimmed)) {
      return 'Username can only contain letters, numbers, and underscores';
    }

    if (trimmed.startsWith(RegExp(r'[0-9]'))) {
      return 'Username cannot start with a number';
    }

    // Check for reserved/inappropriate usernames
    final lowerUsername = trimmed.toLowerCase();
    const reservedUsernames = [
      'admin',
      'administrator',
      'mod',
      'moderator',
      'system',
      'support',
      'help',
      'nba',
      'official',
    ];
    if (reservedUsernames.contains(lowerUsername)) {
      return 'This username is reserved';
    }

    return null;
  }

  // ============================================================================
  // NAME VALIDATION
  // ============================================================================

  /// Validates a person's name (first or last).
  ///
  /// Requirements:
  /// - Not empty
  /// - 1-50 characters
  /// - Only letters, spaces, hyphens, and apostrophes
  static String? validateName(String? name, {String field = 'Name'}) {
    if (name == null || name.trim().isEmpty) {
      return 'Please enter your $field';
    }

    final trimmed = name.trim();

    if (trimmed.length > 50) {
      return '$field is too long';
    }

    // Allow letters (including unicode), spaces, hyphens, apostrophes
    if (!RegExp(r"^[\p{L}\s\-']+$", unicode: true).hasMatch(trimmed)) {
      return '$field contains invalid characters';
    }

    return null;
  }

  // ============================================================================
  // MESSAGE VALIDATION (for forums)
  // ============================================================================

  /// Maximum message length
  static const int maxMessageLength = 1000;

  /// Validates and sanitizes a forum message.
  ///
  /// Returns null if valid, error message if invalid.
  static String? validateMessage(String? message) {
    if (message == null || message.trim().isEmpty) {
      return 'Please enter a message';
    }

    if (message.length > maxMessageLength) {
      return 'Message is too long (max $maxMessageLength characters)';
    }

    return null;
  }

  /// Sanitizes message text to prevent XSS.
  ///
  /// Removes or escapes potentially dangerous content.
  static String sanitizeMessage(String message) {
    // Trim whitespace
    var sanitized = message.trim();

    // Remove null bytes
    sanitized = sanitized.replaceAll('\x00', '');

    // Remove control characters except newlines and tabs
    sanitized = sanitized.replaceAll(RegExp(r'[\x01-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

    // Limit consecutive newlines
    sanitized = sanitized.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // Limit consecutive spaces
    sanitized = sanitized.replaceAll(RegExp(r' {3,}'), '  ');

    return sanitized;
  }

  // ============================================================================
  // URL VALIDATION
  // ============================================================================

  /// Validates a URL (for profile photos, etc.)
  static String? validateUrl(String? url) {
    if (url == null || url.isEmpty) {
      return null; // URL is optional
    }

    if (url.length > 2048) {
      return 'URL is too long';
    }

    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme || (!uri.isScheme('http') && !uri.isScheme('https'))) {
        return 'Invalid URL format';
      }
    } catch (_) {
      return 'Invalid URL format';
    }

    return null;
  }
}

/// Extension methods for String validation.
extension StringValidation on String {
  /// Check if string is a valid email.
  bool get isValidEmail => Validators.validateEmail(this) == null;

  /// Check if string is a valid username.
  bool get isValidUsername => Validators.validateUsername(this) == null;

  /// Get sanitized version of the string for messages.
  String get sanitized => Validators.sanitizeMessage(this);
}
