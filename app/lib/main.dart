import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
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

    // Crashlytics: catch all Flutter framework errors
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    // Crashlytics: catch uncaught async errors (Dart zone errors)
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    // Disable Crashlytics data collection in debug builds
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);

    // Analytics: enable collection in release builds only
    await FirebaseAnalytics.instance
        .setAnalyticsCollectionEnabled(!kDebugMode);

    // Remote Config: fetch latest feature flags from Firebase console
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(minutes: 1),
      minimumFetchInterval:
          kDebugMode ? const Duration(minutes: 5) : const Duration(hours: 12),
    ));
    await remoteConfig.fetchAndActivate();
  } catch (e) {
    // Firebase already initialized or a service failed, continue
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
