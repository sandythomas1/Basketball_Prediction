import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Import individual components for testing
import 'package:app/Services/validators.dart';
import 'package:app/Services/app_config.dart';

void main() {
  group('App Core Components', () {
    test('Validators module should be importable', () {
      // Test that validators are accessible
      expect(Validators.minPasswordLength, equals(8));
      expect(Validators.maxMessageLength, equals(1000));
    });

    test('AppConfig should have valid configuration', () {
      expect(AppConfig.instance, isNotNull);
      expect(AppConfig.espnApiUrl, isNotEmpty);
    });
  });

  group('Widget Smoke Tests', () {
    testWidgets('MaterialApp widget renders correctly', (WidgetTester tester) async {
      // Build a minimal MaterialApp
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('NBA Predictions'),
            ),
          ),
        ),
      );

      // Verify the text appears
      expect(find.text('NBA Predictions'), findsOneWidget);
    });

    testWidgets('Form validation works with custom validators', (WidgetTester tester) async {
      final formKey = GlobalKey<FormState>();
      String? emailError;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: TextFormField(
                validator: (value) {
                  emailError = Validators.validateEmail(value);
                  return emailError;
                },
              ),
            ),
          ),
        ),
      );

      // Enter invalid email
      await tester.enterText(find.byType(TextFormField), 'invalid');
      formKey.currentState?.validate();
      await tester.pump();

      // Validation should fail
      expect(emailError, isNotNull);

      // Enter valid email
      await tester.enterText(find.byType(TextFormField), 'test@example.com');
      formKey.currentState?.validate();
      await tester.pump();

      // Validation should pass
      expect(emailError, isNull);
    });

    testWidgets('Password strength indicator concept', (WidgetTester tester) async {
      // Test password strength calculation
      expect(Validators.calculatePasswordStrength(''), equals(0));
      expect(Validators.calculatePasswordStrength('weak'), lessThan(2));
      expect(Validators.calculatePasswordStrength('MyStr0ng!Pass'), greaterThan(2));
    });
  });

  group('Security Tests', () {
    test('Message sanitization removes dangerous content', () {
      // Test XSS prevention
      final dangerous = '<script>alert("xss")</script>Hello\x00World';
      final sanitized = Validators.sanitizeMessage(dangerous);
      
      // Null bytes should be removed
      expect(sanitized.contains('\x00'), isFalse);
    });

    test('URL validation rejects non-HTTPS in production context', () {
      // FTP should not be allowed
      expect(Validators.validateUrl('ftp://example.com'), isNotNull);
      
      // HTTPS should be allowed
      expect(Validators.validateUrl('https://example.com'), isNull);
    });

    test('Username validation prevents reserved names', () {
      expect(Validators.validateUsername('admin'), isNotNull);
      expect(Validators.validateUsername('moderator'), isNotNull);
      expect(Validators.validateUsername('support'), isNotNull);
    });
  });
}
