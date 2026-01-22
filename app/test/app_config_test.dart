import 'package:flutter_test/flutter_test.dart';
import 'package:app/Services/app_config.dart';

void main() {
  group('AppConfig', () {
    test('should be a singleton', () {
      final instance1 = AppConfig.instance;
      final instance2 = AppConfig.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('should have valid ESPN API URL', () {
      expect(AppConfig.espnApiUrl, contains('espn.com'));
      expect(AppConfig.espnApiUrl, startsWith('https://'));
    });

    test('should have reasonable timeout values', () {
      expect(AppConfig.apiTimeoutSeconds, greaterThan(0));
      expect(AppConfig.apiLongTimeoutSeconds, greaterThan(AppConfig.apiTimeoutSeconds));
      expect(AppConfig.espnTimeoutSeconds, greaterThan(0));
    });

    test('should have valid rate limiting values', () {
      expect(AppConfig.minRequestIntervalMs, greaterThan(0));
      expect(AppConfig.maxRequestsPerMinute, greaterThan(0));
    });

    test('should have valid security constraints', () {
      expect(AppConfig.minPasswordLength, greaterThanOrEqualTo(8));
      expect(AppConfig.maxPasswordLength, greaterThan(AppConfig.minPasswordLength));
      expect(AppConfig.maxMessageLength, greaterThan(0));
      expect(AppConfig.maxUsernameLength, greaterThan(0));
    });

    test('should have valid validation patterns', () {
      // Email pattern
      expect(AppConfig.emailPattern.hasMatch('test@example.com'), isTrue);
      expect(AppConfig.emailPattern.hasMatch('invalid'), isFalse);

      // Username pattern
      expect(AppConfig.usernamePattern.hasMatch('valid_user123'), isTrue);
      expect(AppConfig.usernamePattern.hasMatch('invalid@user'), isFalse);
    });
  });

  group('BuildConfig', () {
    test('should have default values', () {
      // In test environment, these should have their defaults
      expect(BuildConfig.isProduction, isFalse);
      expect(BuildConfig.buildFlavor, equals('development'));
      expect(BuildConfig.appVersion, isNotEmpty);
    });
  });

  group('API URL Generation', () {
    final config = AppConfig.instance;

    test('should return web URL for web platform', () {
      final url = config.getApiBaseUrl(isWeb: true);
      expect(url, contains('localhost'));
    });

    test('should return mobile URL for non-web platform', () {
      final url = config.getApiBaseUrl(isWeb: false);
      // In dev mode, should be local URL
      if (!AppConfig.isProduction) {
        expect(url, anyOf(contains('localhost'), contains('10.0.2.2')));
      }
    });
  });
}
