import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'Widgets/auth_gate.dart';
import 'theme/app_theme.dart';
// git tutorial feature
// try again// test
// MC
//pr request
//DG test

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
      // For web, use reCAPTCHA Enterprise (requires setup in Firebase Console)
      webProvider: ReCaptchaEnterpriseProvider('YOUR_RECAPTCHA_SITE_KEY'),
    );
  } catch (e) {
    // Firebase already initialized or App Check failed, continue
    debugPrint('Firebase init warning: $e');
  }
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NBA Predictions',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}
