import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'secure_storage_service.dart';

/// Result class for authentication operations
class AuthResult {
  final bool success;
  final String? errorMessage;
  final User? user;

  AuthResult({
    required this.success,
    this.errorMessage,
    this.user,
  });

  factory AuthResult.success(User user) => AuthResult(
        success: true,
        user: user,
      );

  factory AuthResult.failure(String message) => AuthResult(
        success: false,
        errorMessage: message,
      );
}

/// Service class for Firebase Authentication
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // The serverClientId is the OAuth 2.0 Web Client ID from Firebase Console.
  // It is a *public* identifier (not a secret) — visible in google-services.json
  // and in any decompiled APK. Security is enforced server-side via the registered
  // SHA-1 fingerprint, not by keeping this value private.
  static const String _googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '791769083784-25fia4a3ff7le5137846tn8c3ct5japi.apps.googleusercontent.com',
  );

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: _googleWebClientId,
  );
  final SecureStorageService _secureStorage = SecureStorageService.instance;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Get the current user
  User? get currentUser => _auth.currentUser;

  /// Sign in with email and password
  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _recordSuccessfulLogin(credential.user!);
      return AuthResult.success(credential.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred. Please try again.');
    }
  }

  /// Sign up with email and password
  Future<AuthResult> signUpWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return AuthResult.success(credential.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred. Please try again.');
    }
  }

  /// Sign in with Google
  Future<AuthResult> signInWithGoogle() async {
    try {
      // Disconnect any previous session so the user can pick an account
      try {
        await _googleSignIn.disconnect();
      } catch (_) {
        // Ignore – no previous session
      }

      // Trigger the Google Sign In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return AuthResult.failure('Google sign in was cancelled.');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);
      await _recordSuccessfulLogin(userCredential.user!);
      return AuthResult.success(userCredential.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e.code));
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      return AuthResult.failure('Google sign-in failed: ${e.toString()}');
    }
  }

  /// Send password reset email
  Future<AuthResult> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure('Failed to send reset email. Please try again.');
    }
  }

  /// Sign out and clear all secure storage
  Future<void> signOut() async {
    // Clear secure storage first
    await _secureStorage.clearAuthData();
    
    // Then sign out from Firebase and Google
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }
  
  /// Record successful login in secure storage
  Future<void> _recordSuccessfulLogin(User user) async {
    await _secureStorage.saveUserId(user.uid);
    await _secureStorage.recordLogin();
    
    // Set session expiry (e.g., 7 days)
    await _secureStorage.saveSessionExpiry(
      DateTime.now().add(const Duration(days: 7)),
    );
  }

  /// Convert Firebase error codes to user-friendly messages
  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-credential':
        return 'Invalid email or password. Please try again.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email but different sign-in credentials.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}

