import 'package:flutter/material.dart';

/// The asset path for the Signal Sports logo
const String signalLogoAsset = 'lib/Assets/Gemini_Generated_Image_40aqrz40aqrz40aq.png';

/// Color matrix that maps white → transparent while keeping colors opaque.
///
/// Formula for alpha channel:  A' = -R - G - B + 765
///   • Pure white  (255,255,255) → A' = 0   (transparent)
///   • Near-white  (250,250,250) → A' = 15  (nearly transparent)
///   • Teal        (0, 212, 204) → A' = 349 → clamped 255 (opaque)
///   • Black       (0, 0, 0)     → A' = 765 → clamped 255 (opaque)
const List<double> _whiteToTransparentMatrix = <double>[
  1,  0,  0,  0,   0,   // R' = R
  0,  1,  0,  0,   0,   // G' = G
  0,  0,  1,  0,   0,   // B' = B
 -1, -1, -1,  0, 765,   // A' = -R - G - B + 765
];

/// Reusable Signal Sports logo widget with transparent background.
class SignalLogo extends StatelessWidget {
  final double size;

  const SignalLogo({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(_whiteToTransparentMatrix),
      child: Image.asset(
        signalLogoAsset,
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}

/// Transparent watermark overlay showing the Signal Sports logo.
/// Place inside a [Stack] — it fills the parent and is non-interactive.
class SignalWatermark extends StatelessWidget {
  const SignalWatermark({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Opacity(
            opacity: 0.045,
            child: Image.asset(
              signalLogoAsset,
              width: 220,
              height: 220,
              fit: BoxFit.contain,
              color: Colors.grey,
              colorBlendMode: BlendMode.saturation,
            ),
          ),
        ),
      ),
    );
  }
}
