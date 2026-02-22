import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../Providers/auth_provider.dart';
import '../Providers/user_provider.dart';
import '../Services/validators.dart';
import '../theme/app_theme.dart';
import '../Widgets/signal_logo.dart';

/// Sign up screen with email/password registration and profile creation
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Username validation state
  Timer? _usernameDebounce;
  bool _isCheckingUsername = false;
  bool _isUsernameAvailable = false;
  String? _usernameError;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameDebounce?.cancel();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    
    final userService = ref.read(userServiceProvider);
    final validationError = userService.validateUsername(value);
    
    if (validationError != null) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = false;
        _usernameError = validationError;
      });
      return;
    }
    
    setState(() {
      _isCheckingUsername = true;
      _isUsernameAvailable = false;
      _usernameError = null;
    });
    
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () async {
      final isAvailable = await userService.isUsernameAvailable(value);
      if (mounted && _usernameController.text == value) {
        setState(() {
          _isCheckingUsername = false;
          _isUsernameAvailable = isAvailable;
          _usernameError = isAvailable ? null : 'Username is already taken';
        });
      }
    });
  }

  Future<void> _signUpWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Check username one more time
    if (!_isUsernameAvailable) {
      setState(() {
        _errorMessage = 'Please choose a valid username';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    final userService = ref.read(userServiceProvider);
    
    // First create the Firebase Auth account
    final authResult = await authService.signUpWithEmail(
      _emailController.text,
      _passwordController.text,
    );

    if (!mounted) return;

    if (authResult.success && authResult.user != null) {
      // Create user profile in database
      final profileResult = await userService.createProfile(
        uid: authResult.user!.uid,
        email: _emailController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        username: _usernameController.text.trim(),
      );
      
      if (!mounted) return;
      
      if (profileResult.success) {
        // Pop back to login - AuthGate will handle navigation
      Navigator.of(context).pop();
      } else {
        // Profile creation failed - sign out and show error
        await authService.signOut();
        setState(() {
          _isLoading = false;
          _errorMessage = profileResult.errorMessage;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = authResult.errorMessage;
      });
    }
  }

  Future<void> _signUpWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    final userService = ref.read(userServiceProvider);
    final result = await authService.signInWithGoogle();

    if (!mounted) return;

    if (result.success && result.user != null) {
      // Check if profile already exists
      final existingProfile = await userService.getProfile(result.user!.uid);
      
      if (existingProfile == null) {
        // New Google user - need to collect additional info
        // For now, create with default values from Google account
        final displayName = result.user!.displayName ?? '';
        final nameParts = displayName.split(' ');
        final firstName = nameParts.isNotEmpty ? nameParts.first : '';
        final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
        
        // Generate a unique username from email
        final emailPrefix = result.user!.email?.split('@').first ?? 'user';
        var username = emailPrefix.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '').toLowerCase();
        if (username.length < 3) username = '${username}user';
        if (username.length > 20) username = username.substring(0, 20);
        
        // Check if username is available, if not add random suffix
        var isAvailable = await userService.isUsernameAvailable(username);
        var attempts = 0;
        while (!isAvailable && attempts < 10) {
          username = '${username.substring(0, (username.length > 15 ? 15 : username.length))}${DateTime.now().millisecondsSinceEpoch % 10000}';
          isAvailable = await userService.isUsernameAvailable(username);
          attempts++;
        }
        
        final profileResult = await userService.createProfile(
          uid: result.user!.uid,
          email: result.user!.email ?? '',
          firstName: firstName,
          lastName: lastName,
          username: username,
        );
        
        if (!mounted) return;
        
        if (!profileResult.success) {
          await authService.signOut();
          setState(() {
            _isLoading = false;
            _errorMessage = profileResult.errorMessage;
          });
          return;
        }
      }
      
      Navigator.of(context).pop();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result.errorMessage;
      });
    }
  }

  PasswordStrength _getPasswordStrength(String password) {
    if (password.isEmpty) return PasswordStrength.none;
    
    final strength = Validators.calculatePasswordStrength(password);
    if (strength >= 3) return PasswordStrength.strong;
    if (strength >= 2) return PasswordStrength.medium;
    if (strength >= 1) return PasswordStrength.weak;
    return PasswordStrength.weak;
  }

  bool _passwordsMatch() {
    return _confirmPasswordController.text.isNotEmpty &&
        _confirmPasswordController.text == _passwordController.text;
  }

  @override
  Widget build(BuildContext context) {
    final passwordStrength = _getPasswordStrength(_passwordController.text);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // Logo (small version)
                _buildSmallLogo(context),
                const SizedBox(height: 32),

                // Title
                Text(
                  'Create Account',
                  style: GoogleFonts.dmSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Join Signal Sports today',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),

                // Error message
                if (_errorMessage != null) ...[
                  _buildErrorBanner(context),
                  const SizedBox(height: 16),
                ],

                // First Name field
                _buildLabel(context, 'FIRST NAME'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _firstNameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    color: context.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter your first name',
                    hintStyle: GoogleFonts.dmSans(
                      color: context.textMuted,
                    ),
                  ),
                  validator: (value) => Validators.validateName(value, field: 'first name'),
                ),
                const SizedBox(height: 20),

                // Last Name field
                _buildLabel(context, 'LAST NAME'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _lastNameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    color: context.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter your last name',
                    hintStyle: GoogleFonts.dmSans(
                      color: context.textMuted,
                    ),
                  ),
                  validator: (value) => Validators.validateName(value, field: 'last name'),
                ),
                const SizedBox(height: 20),

                // Username field
                _buildLabel(context, 'USERNAME'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.next,
                  onChanged: _onUsernameChanged,
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    color: context.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Choose a unique username',
                    hintStyle: GoogleFonts.dmSans(
                      color: context.textMuted,
                    ),
                    prefixText: '@',
                    prefixStyle: GoogleFonts.dmSans(
                      fontSize: 16,
                      color: context.textSecondary,
                    ),
                    suffixIcon: _buildUsernameSuffix(),
                  ),
                  validator: (value) {
                    final userService = ref.read(userServiceProvider);
                    return userService.validateUsername(value);
                  },
                ),
                if (_usernameError != null && _usernameController.text.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _usernameError!,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.errorRed,
                    ),
                  ),
                ] else if (_isUsernameAvailable) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Username is available',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.accentGreen,
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Email field
                _buildLabel(context, 'EMAIL'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    color: context.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter your email',
                    hintStyle: GoogleFonts.dmSans(
                      color: context.textMuted,
                    ),
                  ),
                  validator: Validators.validateEmail,
                ),
                const SizedBox(height: 20),

                // Password field
                _buildLabel(context, 'PASSWORD'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    color: context.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Create a password',
                    hintStyle: GoogleFonts.dmSans(
                      color: context.textMuted,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: context.textMuted,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: Validators.validatePassword,
                ),
                const SizedBox(height: 8),

                // Password strength indicator
                if (_passwordController.text.isNotEmpty) ...[
                  _buildPasswordStrengthIndicator(passwordStrength, context),
                  const SizedBox(height: 20),
                ] else
                  const SizedBox(height: 12),

                // Confirm password field
                _buildLabel(context, 'CONFIRM PASSWORD'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _signUpWithEmail(),
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    color: context.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Confirm your password',
                    hintStyle: GoogleFonts.dmSans(
                      color: context.textMuted,
                    ),
                    suffixIcon: _confirmPasswordController.text.isNotEmpty
                        ? Icon(
                            _passwordsMatch()
                                ? Icons.check
                                : Icons.visibility_outlined,
                            color: _passwordsMatch()
                                ? AppColors.accentGreen
                                : context.textMuted,
                          )
                        : IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: context.textMuted,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Create account button
                _buildPrimaryButton(
                  context: context,
                  onPressed: _isLoading ? null : _signUpWithEmail,
                  isLoading: _isLoading,
                  label: 'Create Account',
                ),
                const SizedBox(height: 24),

                // Divider
                _buildDivider(context),
                const SizedBox(height: 24),

                // Google sign up button
                _buildGoogleButton(
                  context: context,
                  onPressed: _isLoading ? null : _signUpWithGoogle,
                  label: 'Continue with Google',
                ),
                const SizedBox(height: 32),

                // Sign in link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: context.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Text(
                        'Sign in',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildUsernameSuffix() {
    if (_usernameController.text.isEmpty) return null;
    
    if (_isCheckingUsername) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    
    if (_isUsernameAvailable) {
      return const Icon(Icons.check_circle, color: AppColors.accentGreen);
    }
    
    if (_usernameError != null) {
      return const Icon(Icons.error, color: AppColors.errorRed);
    }
    
    return null;
  }

  Widget _buildSmallLogo(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: SignalLogo(size: 56),
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: context.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator(
    PasswordStrength strength,
    BuildContext context,
  ) {
    Color getColor(int index) {
      if (strength == PasswordStrength.none) {
        return context.borderColor;
      }
      if (strength == PasswordStrength.weak) {
        return index == 0 ? AppColors.errorRed : context.borderColor;
      }
      if (strength == PasswordStrength.medium) {
        return index <= 1 ? AppColors.accentYellow : context.borderColor;
      }
      return AppColors.accentGreen;
    }

    String getLabel() {
      switch (strength) {
        case PasswordStrength.none:
          return '';
        case PasswordStrength.weak:
          return 'Weak password';
        case PasswordStrength.medium:
          return 'Medium strength';
        case PasswordStrength.strong:
          return 'Strong password';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(
            4,
            (index) => Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: index < 3 ? 6 : 0),
                decoration: BoxDecoration(
                  color: getColor(index),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          getLabel(),
          style: GoogleFonts.dmSans(
            fontSize: 11,
            color: context.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.errorRed.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.errorRed,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: AppColors.errorRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required BuildContext context,
    required VoidCallback? onPressed,
    required bool isLoading,
    required String label,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.accentOrange, AppColors.accentYellow],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentOrange.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: context.borderColor,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR CONTINUE WITH',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: context.textMuted,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: context.borderColor,
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton({
    required BuildContext context,
    required VoidCallback? onPressed,
    required String label,
  }) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: context.bgCard,
          side: BorderSide(color: context.borderColor, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
              height: 20,
              width: 20,
              errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum PasswordStrength { none, weak, medium, strong }
