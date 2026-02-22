import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../Providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../Widgets/signal_logo.dart';

/// Forgot password screen with password reset functionality
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    final result = await authService.resetPassword(_emailController.text);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.success) {
        _emailSent = true;
      } else {
        _errorMessage = result.errorMessage;
      }
    });
  }

  Future<void> _resendEmail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    final result = await authService.resetPassword(_emailController.text);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (!result.success) {
        _errorMessage = result.errorMessage;
      }
    });

    if (result.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reset email sent again!',
            style: GoogleFonts.dmSans(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _emailSent
              ? _buildSuccessContent(context)
              : _buildFormContent(context),
        ),
      ),
    );
  }

  Widget _buildFormContent(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),

          // Back button
          _buildBackButton(context),
          const SizedBox(height: 24),

          // Logo
          _buildSmallLogo(context),
          const SizedBox(height: 32),

          // Title
          Text(
            'Reset Password',
            style: GoogleFonts.dmSans(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your email to receive a password reset link',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 32),

          // Info box
          _buildInfoBox(context),
          const SizedBox(height: 24),

          // Error message
          if (_errorMessage != null) ...[
            _buildErrorBanner(context),
            const SizedBox(height: 16),
          ],

          // Email field
          _buildLabel(context, 'EMAIL ADDRESS'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _sendResetEmail(),
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
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Send reset link button
          _buildPrimaryButton(
            context: context,
            onPressed: _isLoading ? null : _sendResetEmail,
            isLoading: _isLoading,
            label: 'Send Reset Link',
          ),
          const SizedBox(height: 32),

          // Back to sign in link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Remember your password? ',
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
    );
  }

  Widget _buildSuccessContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),

        // Back button
        _buildBackButton(context),
        const SizedBox(height: 24),

        // Logo
        _buildSmallLogo(context),
        const SizedBox(height: 32),

        // Success box
        _buildSuccessBox(context),
        const SizedBox(height: 24),

        // Didn't receive email info
        _buildMailInfoBox(context),
        const SizedBox(height: 24),

        // Resend button
        SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: _isLoading ? null : _resendEmail,
            style: OutlinedButton.styleFrom(
              backgroundColor: context.bgCard,
              side: BorderSide(color: context.borderColor, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.textPrimary,
                    ),
                  )
                : Text(
                    'Resend Email',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 32),

        // Back to sign in link
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Remember your password? ',
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
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_back,
              size: 20,
              color: AppColors.accentBlue,
            ),
            const SizedBox(width: 8),
            Text(
              'Back to Sign In',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.accentBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallLogo(BuildContext context) {
    return const Align(
      alignment: Alignment.center,
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

  Widget _buildInfoBox(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accentBlue.withOpacity(0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            color: AppColors.accentBlue,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "We'll send you an email with a link to reset your password. The link will expire in 24 hours.",
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: context.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessBox(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.accentGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accentGreen.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.accentGreen.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              size: 32,
              color: AppColors.accentGreen,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Check Your Email',
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.accentGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "We've sent a password reset link to",
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: context.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _emailController.text,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Check your inbox and click the link to reset your password.',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: context.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMailInfoBox(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.mail_outline,
            color: context.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Didn't receive the email? Check your spam folder or click below to resend.",
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: context.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
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
}
