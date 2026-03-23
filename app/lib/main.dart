import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'Services/subscription_service.dart';
import 'Widgets/auth_gate.dart';
import 'Providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'Screens/playoff_series_detail_screen.dart';
import 'Screens/playoff_bracket_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  // This must happen before any code tries to access AppConfig.revenueCatAndroidApiKey
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Warning: Could not load .env file: $e');
    debugPrint('Using default RevenueCat test key.');
  }

  // Initialize Firebase (handle duplicate initialization gracefully)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Initialize Firebase App Check for security
    // This ensures only your app can call Firebase services (including Vertex AI)
    await FirebaseAppCheck.instance.activate(
      // Use debug provider for development/testing
      // In production, use platform-specific providers
      androidProvider: kDebugMode 
          ? AndroidProvider.debug 
          : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode 
          ? AppleProvider.debug 
          : AppleProvider.deviceCheck,
      webProvider: ReCaptchaEnterpriseProvider(
        dotenv.env['RECAPTCHA_SITE_KEY'] ?? '',
      ),
    );
  } catch (e) {
    // Firebase already initialized or App Check failed, continue
    debugPrint('Firebase init warning: $e');
  }

  // Initialize RevenueCat after Firebase so SubscriptionService can identify
  // the Firebase user immediately on startup.
  await SubscriptionService.instance.initialize();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Signal Sports',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const AuthGate(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/playoff/series':
            final seriesId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => PlayoffSeriesDetailScreen(seriesId: seriesId),
            );
          case '/playoff/bracket':
            return MaterialPageRoute(
              builder: (_) => const PlayoffBracketScreen(),
            );
        }
        return null;
      },
    );
  }
}
