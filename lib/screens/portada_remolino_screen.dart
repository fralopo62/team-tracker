import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'activities_screen.dart';

class PortadaRemolinoScreen extends StatefulWidget {
  final Widget nextScreen;

  const PortadaRemolinoScreen({
    super.key,
    required this.nextScreen,
  });

  @override
  State<PortadaRemolinoScreen> createState() => _PortadaRemolinoScreenState();
}

class _PortadaRemolinoScreenState extends State<PortadaRemolinoScreen>
    with TickerProviderStateMixin {
  static const String _bucketName = 'activity_photos';
  static const List<String> _assetPaths = [
    'assets/images/foto1.jpg',
    'assets/images/foto2.jpg',
    'assets/images/foto3.jpg',
  ];

  late final AnimationController _swirlController;
  late final AnimationController _bgController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _swirlAngleAnimation;
  late final Animation<double> _opacityAnimation;

  Timer? _exitTimer;
  bool _navigated = false;
  List<String?> _supabaseUrls = [null, null, null];

  @override
  void initState() {
    super.initState();

    _swirlController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.12, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 60,
      ),
    ]).animate(_swirlController);

    _swirlAngleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: -math.pi * 1.25, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 60,
      ),
    ]).animate(_swirlController);

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _swirlController,
        curve: const Interval(0.0, 0.18, curve: Curves.easeIn),
      ),
    );

    _swirlController.forward();
    _exitTimer = Timer(const Duration(seconds: 6), _goToNextScreen);

    // Precarga actividades en segundo plano durante los 6 segundos de portada
    ActivitiesFeedScreen.preloadActivities();
    _syncPhotosToSupabaseStorage();
  }

  Future<void> _syncPhotosToSupabaseStorage() async {
    try {
      final supabase = Supabase.instance.client;
      final tempDir = await getTemporaryDirectory();
      final List<String?> resolvedUrls =
          List<String?>.filled(_assetPaths.length, null);

      for (int i = 0; i < _assetPaths.length; i++) {
        final assetPath = _assetPaths[i];
        final fileName = 'portada/foto_${i + 1}.jpg';

        final byteData = await rootBundle.load(assetPath);
        final tempFile = File('${tempDir.path}/portada_foto_${i + 1}.jpg');
        await tempFile.writeAsBytes(
          byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          ),
          flush: true,
        );

        await supabase.storage.from(_bucketName).upload(
              fileName,
              tempFile,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: true,
              ),
            );

        final signedUrl = await supabase.storage
            .from(_bucketName)
            .createSignedUrl(fileName, 60 * 60 * 24 * 365);

        resolvedUrls[i] = signedUrl;
      }

      if (mounted) {
        setState(() {
          _supabaseUrls = resolvedUrls;
        });
      }
    } catch (_) {
      // Mantiene los assets locales si no hay red o falla el bucket
    }
  }

  Widget _buildPhotoWidget({
    required int index,
    required double width,
    required double height,
    required double radius,
  }) {
    final String assetPath = _assetPaths[index];
    final String? remoteUrl = _supabaseUrls[index];

    final Widget imageChild = remoteUrl != null
        ? Image.network(
            remoteUrl,
            width: width,
            height: height,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => Image.asset(
              assetPath,
              width: width,
              height: height,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          )
        : Image.asset(
            assetPath,
            width: width,
            height: height,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, __, ___) => Container(
              width: width,
              height: height,
              color: const Color(0xFF1A1D24),
              alignment: Alignment.center,
              child: Text(
                assetPath,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: imageChild,
    );
  }

  void _goToNextScreen() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _exitTimer?.cancel();
    _swirlController.stop();
    _bgController.stop();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => ColoredBox(
          color: const Color(0xFF0F1115),
          child: widget.nextScreen,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    _swirlController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final topPhotoWidth = screenWidth * 0.75;
    final bottomPhotoWidth = (topPhotoWidth - 12) / 2;

    return Scaffold(
      backgroundColor: const Color(0xFF090A0D),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _goToNextScreen,
        child: SizedBox.expand(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _bgController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _NeonSportsBackgroundPainter(
                        phase: _bgController.value,
                      ),
                    );
                  },
                ),
              ),
              Center(
                child: AnimatedBuilder(
                  animation: _swirlController,
                  builder: (context, child) {
                    final matrix = Matrix4.identity()
                      ..scale(_scaleAnimation.value, _scaleAnimation.value, 1.0)
                      ..rotateZ(_swirlAngleAnimation.value);

                    return Opacity(
                      opacity: _opacityAnimation.value,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: matrix,
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildPhotoWidget(
                        index: 0,
                        width: topPhotoWidth,
                        height: topPhotoWidth * 0.62,
                        radius: 16,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: topPhotoWidth,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildPhotoWidget(
                              index: 1,
                              width: bottomPhotoWidth,
                              height: bottomPhotoWidth * 1.05,
                              radius: 14,
                            ),
                            _buildPhotoWidget(
                              index: 2,
                              width: bottomPhotoWidth,
                              height: bottomPhotoWidth * 1.05,
                              radius: 14,
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _NeonSportsBackgroundPainter extends CustomPainter {
  final double phase;

  _NeonSportsBackgroundPainter({required this.phase});

  static const Color _neonOrange = Color(0xFFFF6A00);
  static const Color _neonAmber = Color(0xFFFF9E2C);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(404);

    const int dotCount = 52;
    for (int i = 0; i < dotCount; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      final radius = 1.5 + rng.nextDouble() * 2.3;
      final speed = 1.0 + rng.nextInt(3);
      final offset = rng.nextDouble() * math.pi * 2;

      final blink = 0.5 + 0.5 * math.sin(phase * math.pi * 2 * speed + offset);
      final alpha = (0.2 + blink * 0.75).clamp(0.0, 1.0);

      final glowPaint = Paint()
        ..color = _neonAmber.withOpacity((alpha * 0.55).clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

      final corePaint = Paint()
        ..color = (i.isEven ? _neonOrange : _neonAmber).withOpacity(alpha);

      canvas.drawCircle(Offset(dx, dy), radius * 2.2, glowPaint);
      canvas.drawCircle(Offset(dx, dy), radius, corePaint);
    }

    final List<Offset> placedCenters = [];
    const double minDistance = 88.0;
    const int targetIcons = 22;
    int attempts = 0;

    while (placedCenters.length < targetIcons && attempts < 400) {
      attempts++;
      final x = 24 + rng.nextDouble() * (size.width - 48);
      final y = 28 + rng.nextDouble() * (size.height - 56);
      final candidate = Offset(x, y);

      final tooClose = placedCenters.any(
        (existing) => (existing - candidate).distance < minDistance,
      );
      if (tooClose) continue;

      placedCenters.add(candidate);

      final idx = placedCenters.length - 1;
      final driftX = math.cos(phase * math.pi * 2 + idx * 1.3) * 3.5;
      final driftY = math.sin(phase * math.pi * 2 + idx * 1.9) * 3.5;
      final center = Offset(x + driftX, y + driftY);

      final tilt = (rng.nextDouble() - 0.5) * 1.2;
      final scale = 0.88 + rng.nextDouble() * 0.24;
      final isMtb = rng.nextBool();

      if (isMtb) {
        _drawSmallMtb(canvas, center, angle: tilt, scale: scale);
      } else {
        _drawSmallSneaker(canvas, center, angle: tilt, scale: scale);
      }
    }
  }

  void _drawSmallMtb(
    Canvas canvas,
    Offset center, {
    required double angle,
    required double scale,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.scale(scale);

    const double w = 34;
    const double wheelR = 7.2;
    const Offset rearWheel = Offset(-w * 0.34, 4.5);
    const Offset frontWheel = Offset(w * 0.34, 4.5);
    const Offset bb = Offset(-w * 0.04, 4.5);
    const Offset seatTop = Offset(-w * 0.16, -6.5);
    const Offset headTop = Offset(w * 0.22, -5.5);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = _neonOrange.withOpacity(0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = _neonOrange.withOpacity(0.68);

    for (final paint in [glow, stroke]) {
      canvas.drawCircle(rearWheel, wheelR, paint);
      canvas.drawCircle(frontWheel, wheelR, paint);

      final frame = Path()
        ..moveTo(rearWheel.dx, rearWheel.dy)
        ..lineTo(bb.dx, bb.dy)
        ..lineTo(headTop.dx, headTop.dy)
        ..lineTo(seatTop.dx, seatTop.dy)
        ..close();
      canvas.drawPath(frame, paint);

      canvas.drawLine(bb, Offset(-w * 0.19, -9.2), paint);
      canvas.drawLine(
        Offset(-w * 0.26, -9.5),
        Offset(-w * 0.11, -9.5),
        paint,
      );

      canvas.drawLine(headTop, frontWheel, paint);
      canvas.drawLine(
        Offset(w * 0.17, -8.8),
        Offset(w * 0.28, -8.5),
        paint,
      );
    }

    canvas.restore();
  }

  void _drawSmallSneaker(
    Canvas canvas,
    Offset center, {
    required double angle,
    required double scale,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.scale(scale);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = _neonAmber.withOpacity(0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = _neonAmber.withOpacity(0.68);

    final upperAndSole = Path()
      ..moveTo(-14, 5)
      ..lineTo(11, 5)
      ..quadraticBezierTo(15, 5, 15, 2)
      ..lineTo(13, 0)
      ..lineTo(4, -2)
      ..lineTo(-2, -8)
      ..lineTo(-11, -8)
      ..lineTo(-14, 1)
      ..close();

    for (final paint in [glow, stroke]) {
      canvas.drawPath(upperAndSole, paint);
      canvas.drawLine(const Offset(-14, 2.5), const Offset(13.5, 2.5), paint);
      canvas.drawLine(const Offset(-2, -5.5), const Offset(1, -2.5), paint);
      canvas.drawLine(const Offset(1.5, -4.2), const Offset(4.5, -1.5), paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NeonSportsBackgroundPainter oldDelegate) {
    return oldDelegate.phase != phase;
  }
}