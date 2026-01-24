/// Application configuration for different environments.
///
/// Handles API endpoint configuration for development vs production.
class AppConfig {
  // Private constructor - singleton
  AppConfig._();

  // Singleton instance
  static final AppConfig instance = AppConfig._();

  // Environment flag - set this based on build configuration
  // In production builds, this should be set to true
  static const bool isProduction = bool.fromEnvironment(
    'PRODUCTION',
    defaultValue: true,
  );

  // ============================================================================
  // API ENDPOINTS
  // ============================================================================

  /// Production API base URL (Render hosting)
  static const String _productionApiUrl =
      'https://nba-prediction-api-nq5b.onrender.com';

  /// Development API base URL (local)
  /// Note: Android emulator uses 10.0.2.2 to reach host machine's localhost
  static const String _developmentApiUrl = 'http://10.0.2.2:8000';

  /// Web development URL
  static const String _webDevelopmentApiUrl = 'http://localhost:8000';

  /// ESPN API base URL
  static const String espnApiUrl =
      'https://site.api.espn.com/apis/site/v2/sports/basketball/nba';

  /// Get the appropriate API base URL based on environment and platform.
  String getApiBaseUrl({bool isWeb = false}) {
    if (isProduction) {
      return _productionApiUrl;
    }

    // Development mode - use local API
    if (isWeb) {
      return _webDevelopmentApiUrl;
    }

    return _developmentApiUrl;
  }

  // ============================================================================
  // TIMEOUTS
  // ============================================================================

  /// API request timeout in seconds
  static const int apiTimeoutSeconds = 30;

  /// Long-running request timeout (for cold starts on Render)
  static const int apiLongTimeoutSeconds = 90;

  /// ESPN API timeout
  static const int espnTimeoutSeconds = 10;

  // ============================================================================
  // FEATURE FLAGS
  // ============================================================================

  /// Enable debug logging
  static bool get enableDebugLogging => !isProduction;

  /// Enable detailed error messages (never in production)
  static bool get showDetailedErrors => !isProduction;

  /// Enable offline mode (cache data for offline access)
  static const bool enableOfflineMode = false;

  // ============================================================================
  // RATE LIMITING (client-side protection)
  // ============================================================================

  /// Minimum time between API requests (milliseconds)
  static const int minRequestIntervalMs = 100;

  /// Maximum requests per minute (client-side throttle)
  static const int maxRequestsPerMinute = 60;

  // ============================================================================
  // CACHE CONFIGURATION
  // ============================================================================

  /// How long to cache prediction data (minutes)
  static const int predictionCacheMinutes = 5;

  /// How long to cache team data (hours)
  static const int teamCacheHours = 24;

  // ============================================================================
  // SECURITY SETTINGS
  // ============================================================================

  /// Minimum password length
  static const int minPasswordLength = 8;

  /// Maximum password length
  static const int maxPasswordLength = 128;

  /// Maximum message length for forums
  static const int maxMessageLength = 1000;

  /// Maximum username length
  static const int maxUsernameLength = 20;

  /// Session timeout (minutes)
  static const int sessionTimeoutMinutes = 60;

  // ============================================================================
  // VALIDATION PATTERNS
  // ============================================================================

  /// Email validation regex
  static final RegExp emailPattern = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$",
  );

  /// Username validation regex (alphanumeric + underscore)
  static final RegExp usernamePattern = RegExp(r'^[a-zA-Z0-9_]+$');
}

/// Build configuration passed at compile time.
///
/// Usage in build:
/// flutter build apk --dart-define=PRODUCTION=true
/// flutter build ios --dart-define=PRODUCTION=true
class BuildConfig {
  static const bool isProduction = bool.fromEnvironment(
    'PRODUCTION',
    defaultValue: false,
  );

  static const String buildFlavor = String.fromEnvironment(
    'BUILD_FLAVOR',
    defaultValue: 'development',
  );

  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );
}
