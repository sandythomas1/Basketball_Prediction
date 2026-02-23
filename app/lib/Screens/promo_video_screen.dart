import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';

/// Full-screen promotional video that plays after login/signup.
/// The user can skip the video at any time, or it auto-advances when done.
class PromoVideoScreen extends StatefulWidget {
  /// Called when the video ends or the user taps "Skip".
  final VoidCallback onComplete;

  const PromoVideoScreen({super.key, required this.onComplete});

  @override
  State<PromoVideoScreen> createState() => _PromoVideoScreenState();
}

class _PromoVideoScreenState extends State<PromoVideoScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    _controller = VideoPlayerController.asset(
      'lib/Assets/Video_Generation_and_Correction.mp4',
    );

    try {
      await _controller.initialize();
      if (!mounted) return;

      _controller.addListener(_onVideoProgress);
      _controller.play();

      setState(() {
        _initialized = true;
      });
    } catch (e) {
      debugPrint('Promo video init error: $e');
      if (!mounted) return;
      setState(() {
        _hasError = true;
      });
      // If the video can't load, just proceed to the main screen.
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) widget.onComplete();
      });
    }
  }

  void _onVideoProgress() {
    if (!mounted) return;
    // Auto-advance when the video finishes playing.
    if (_controller.value.position >= _controller.value.duration &&
        _controller.value.duration > Duration.zero) {
      _controller.removeListener(_onVideoProgress);
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onVideoProgress);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Video (or loading indicator)
          if (_initialized)
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            )
          else if (!_hasError)
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.accentOrange,
              ),
            ),

          // Skip button — always visible
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: GestureDetector(
              onTap: widget.onComplete,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white24,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Skip',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
