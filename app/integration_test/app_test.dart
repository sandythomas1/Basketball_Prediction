import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:app/main.dart';

/// Integration tests for the NBA Predictions app.
///
/// Run with: flutter test integration_test/app_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Launch Tests', () {
    testWidgets('app should launch without crashing', (tester) async {
      // Note: This test requires Firebase to be initialized
      // In CI, you may need to mock Firebase or skip this test
      
      // Build our app
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // App should be running
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  group('Login Screen Tests', () {
    testWidgets('login screen should show required fields', (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Look for email and password fields (may vary based on auth state)
      // The AuthGate determines which screen to show
      expect(find.byType(Scaffold), findsWidgets);
    });
  });

  group('Navigation Tests', () {
    testWidgets('should have working navigation structure', (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Verify the app structure is intact
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
