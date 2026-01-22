import 'package:flutter_test/flutter_test.dart';
import 'package:app/Providers/api_service.dart';

void main() {
  group('ApiService', () {
    late ApiService apiService;

    setUp(() {
      apiService = ApiService();
    });

    test('should have valid API base URL', () {
      expect(apiService.fastApiBaseUrl, isNotEmpty);
      expect(
        apiService.fastApiBaseUrl,
        anyOf(startsWith('http://'), startsWith('https://')),
      );
    });

    test('should have valid ESPN base URL', () {
      expect(apiService.espnBaseUrl, contains('espn.com'));
      expect(apiService.espnBaseUrl, startsWith('https://'));
    });
  });

  group('ApiException', () {
    test('should store all properties correctly', () {
      final exception = ApiException(
        'Test error',
        statusCode: 500,
        isTimeout: true,
        isRateLimited: false,
      );

      expect(exception.message, equals('Test error'));
      expect(exception.statusCode, equals(500));
      expect(exception.isTimeout, isTrue);
      expect(exception.isRateLimited, isFalse);
    });

    test('should have correct toString format', () {
      final exception = ApiException('Test', statusCode: 404);
      expect(exception.toString(), contains('Test'));
      expect(exception.toString(), contains('404'));
    });

    test('should return appropriate user message for timeout', () {
      final exception = ApiException('Timeout', isTimeout: true);
      expect(exception.userMessage, contains('timed out'));
    });

    test('should return appropriate user message for rate limit', () {
      final exception = ApiException('Rate limited', isRateLimited: true);
      expect(exception.userMessage, contains('Too many requests'));
    });

    test('should return appropriate user message for server error', () {
      final exception = ApiException('Server error', statusCode: 503);
      expect(exception.userMessage, contains('Server error'));
    });

    test('should return generic message for unknown errors', () {
      final exception = ApiException('Unknown');
      expect(exception.userMessage, contains('Something went wrong'));
    });
  });
}
