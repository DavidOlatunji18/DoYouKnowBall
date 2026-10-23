import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../auth/session.dart';
import '../theme.dart';
import 'welcome_screen.dart';

/// Takes over from the native launch screen with the same bulb and "Do You Know Ball?"
/// in the same places, plus a spinning loader in between, while the saved login is
/// checked. The router leaves this screen once the session is ready.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// Keep the splash up at least this long so the loader never just flickers.
  static const minimumDuration = Duration(milliseconds: 900);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Release the native launch screen now: it holds back Flutter's first frame, so
    // waiting for a frame before releasing it would deadlock. This screen matches it,
    // so the swap is invisible.
    FlutterNativeSplash.remove();
    // Start after the first frame: decoding images needs this screen's MediaQuery.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    // Not awaited: a few small PNGs decode well within the splash's minimum time.
    _precacheImages();

    final session = context.read<Session>();
    final api = context.read<ApiClient>();
    await Future.wait([
      session.start(api),
      Future<void>.delayed(SplashScreen.minimumDuration),
    ]);
    session.markReady();
  }

  /// Decodes the images the next screens animate, while the splash is up anyway.
  /// Otherwise a slow device (or a debug build) can finish an animation before the
  /// image has loaded, and the ball just pops in at the end.
  void _precacheImages() {
    for (final name in WelcomeScreen.balls) {
      precacheImage(AssetImage('assets/balls/$name.png'), context);
    }
    precacheImage(
      const AssetImage('assets/branding/logo-transparent.png'),
      context,
    );
  }

  @override
  Widget build(BuildContext context) {
    final native = _NativeSplash.current;
    final height = MediaQuery.sizeOf(context).height;
    // Centre the loader between the bottom of the bulb drawing and the top of the wordmark.
    final gapTop = height / 2 + native.logoSize * (native.bulbBottom - 0.5);
    final gapBottom =
        height -
        native.wordmarkBottom -
        native.wordmarkSize.height * native.wordmarkTextTop;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.green,
        body: Semantics(
          label: 'Do You Know Ball? Loading',
          excludeSemantics: true,
          child: Stack(
            children: [
              Center(
                child: Image.asset(
                  native.logoAsset,
                  width: native.logoSize,
                  height: native.logoSize,
                ),
              ),
              Positioned(
                top: gapTop,
                height: math.max(0, gapBottom - gapTop),
                left: 0,
                right: 0,
                child: const Center(child: SpiralLoader()),
              ),
              Positioned(
                bottom: native.wordmarkBottom,
                left: 0,
                right: 0,
                child: Center(
                  child: Image.asset(
                    native.wordmarkAsset,
                    width: native.wordmarkSize.width,
                    height: native.wordmarkSize.height,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How each platform's native launch screen is laid out (see
/// mobile/flutter_native_splash.yaml), so this screen can draw the same artwork in
/// exactly the same places. Images are drawn at 4x.
class _NativeSplash {
  const _NativeSplash({
    required this.logoAsset,
    required this.logoSize,
    required this.bulbBottom,
    required this.wordmarkAsset,
    required this.wordmarkSize,
    required this.wordmarkBottom,
    required this.wordmarkTextTop,
  });

  /// iOS: 1024px bulb image, 1000x160 wordmark 140pt from the bottom.
  static const ios = _NativeSplash(
    logoAsset: 'assets/branding/splash-logo.png',
    logoSize: 256,
    bulbBottom: 0.80,
    wordmarkAsset: 'assets/branding/splash-wordmark.png',
    wordmarkSize: Size(250, 40),
    wordmarkBottom: 140,
    wordmarkTextTop: 0.30,
  );

  /// Android: the bulb at 288dp (the size Android 12+ shows its launch icon) and an
  /// 800x320 wordmark (Android 12's required shape), 60dp from the bottom.
  static const android = _NativeSplash(
    logoAsset: 'assets/branding/splash-android.png',
    logoSize: 288,
    bulbBottom: 0.73,
    wordmarkAsset: 'assets/branding/splash-wordmark-android.png',
    wordmarkSize: Size(200, 80),
    wordmarkBottom: 60,
    wordmarkTextTop: 0.40,
  );

  static _NativeSplash get current =>
      defaultTargetPlatform == TargetPlatform.android ? android : ios;

  final String logoAsset;
  final double logoSize;

  /// Where the bulb drawing ends, as a fraction of its image's height.
  final double bulbBottom;

  final String wordmarkAsset;
  final Size wordmarkSize;

  /// Distance from the bottom of the screen to the bottom of the wordmark image.
  final double wordmarkBottom;

  /// Where the text starts inside the wordmark image, as a fraction of its height.
  final double wordmarkTextTop;
}

/// A comet-style spinner: an ink arc that fades into a tail, rotating around a
/// pulsing centre dot. Fades in so very quick loads don't flash it.
class SpiralLoader extends StatefulWidget {
  const SpiralLoader({super.key, this.size = 46});

  final double size;

  @override
  State<SpiralLoader> createState() => _SpiralLoaderState();
}

class _SpiralLoaderState extends State<SpiralLoader>
    with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _fadeIn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_spin.isAnimating || _fadeIn.value > 0) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      // Reduce Motion: a still ring instead of a spinner.
      _fadeIn.value = 1;
    } else {
      _spin.repeat();
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (mounted) _fadeIn.forward();
      });
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    _fadeIn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeIn,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _spin,
          builder: (context, _) => CustomPaint(
            size: Size.square(widget.size),
            painter: _CometPainter(_spin.value),
          ),
        ),
      ),
    );
  }
}

class _CometPainter extends CustomPainter {
  _CometPainter(this.t);

  /// Animation progress, 0..1 per revolution.
  final double t;

  static const _sweep = math.pi * 1.5; // length of arc plus tail

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final stroke = size.width * 0.12;
    final radius = size.width / 2 - stroke / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Faint full track so the shape reads even at the tail's thin end.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = AppColors.ink.withValues(alpha: 0.12),
    );

    // The comet: transparent at the tail, solid ink at the head.
    final start = t * 2 * math.pi;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(start);
    canvas.translate(-center.dx, -center.dy);
    final comet = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      // Flat ends: a round cap at the tail would wrap into the gradient's solid end.
      ..strokeCap = StrokeCap.butt
      ..shader = SweepGradient(
        endAngle: _sweep,
        colors: [AppColors.ink.withValues(alpha: 0), AppColors.ink],
      ).createShader(rect);
    canvas.drawArc(rect, 0, _sweep, false, comet);
    // Rounded head of the comet.
    canvas.drawCircle(
      Offset(
        center.dx + radius * math.cos(_sweep),
        center.dy + radius * math.sin(_sweep),
      ),
      stroke / 2,
      Paint()..color = AppColors.ink,
    );
    canvas.restore();

    // Centre dot that breathes twice per revolution.
    final pulse = 0.5 + 0.5 * math.sin(t * 4 * math.pi);
    canvas.drawCircle(
      center,
      stroke * (0.55 + 0.3 * pulse),
      Paint()..color = AppColors.ink,
    );
  }

  @override
  bool shouldRepaint(_CometPainter old) => old.t != t;
}
