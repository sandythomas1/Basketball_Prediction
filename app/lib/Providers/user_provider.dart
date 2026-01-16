import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../Models/user_profile.dart';
import '../Services/user_service.dart';
import 'auth_provider.dart';

/// Provider for the UserService singleton
final userServiceProvider = Provider<UserService>((ref) {
  return UserService();
});

/// Provider that streams the current user's profile from Firebase Realtime Database
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final authState = ref.watch(authStateProvider);
  final userService = ref.watch(userServiceProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return userService.profileStream;
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

/// Provider to check username availability
/// Usage: ref.watch(usernameAvailableProvider('desired_username'))
final usernameAvailableProvider = FutureProvider.family<bool, String>((ref, username) async {
  if (username.isEmpty) return false;
  
  final userService = ref.watch(userServiceProvider);
  return await userService.isUsernameAvailable(username);
});

/// Provider for username validation state
final usernameValidationProvider = StateProvider<UsernameValidationState>((ref) {
  return UsernameValidationState.initial();
});

/// State class for username validation
class UsernameValidationState {
  final bool isChecking;
  final bool isAvailable;
  final String? errorMessage;

  UsernameValidationState({
    required this.isChecking,
    required this.isAvailable,
    this.errorMessage,
  });

  factory UsernameValidationState.initial() => UsernameValidationState(
        isChecking: false,
        isAvailable: false,
      );

  factory UsernameValidationState.checking() => UsernameValidationState(
        isChecking: true,
        isAvailable: false,
      );

  factory UsernameValidationState.available() => UsernameValidationState(
        isChecking: false,
        isAvailable: true,
      );

  factory UsernameValidationState.unavailable() => UsernameValidationState(
        isChecking: false,
        isAvailable: false,
        errorMessage: 'Username is already taken',
      );

  factory UsernameValidationState.invalid(String message) => UsernameValidationState(
        isChecking: false,
        isAvailable: false,
        errorMessage: message,
      );
}

/// Provider for profile loading state during updates
final profileLoadingProvider = StateProvider<bool>((ref) => false);

/// Provider for profile error messages
final profileErrorProvider = StateProvider<String?>((ref) => null);
