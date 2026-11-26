import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

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
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;
  Timer? _exitTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // Duración total de 6 segundos: el remolino se despliega durante los primeros ~2.5s
    // y las fotos quedan visibles hasta completar los 6 segundos.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.02, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 45, // primeros ~2.7s desplegándose desde el centro
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 55, // resto hasta los 6s estable en su posición
      ),
    ]).animate(_controller);

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.15, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    _exitTimer = Timer(const Duration(seconds: 6), _goToNextScreen);
  }

  void _goToNextScreen() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _exitTimer?.cancel();
    _controller.stop();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => widget.nextScreen),
    );
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final topPhotoWidth = screenWidth * 0.75;
    final bottomPhotoWidth = (topPhotoWidth - 12) / 2;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      body: GestureDetector(
        onTap: _goToNextScreen,
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // Giro en remolino que va frenando suavemente hasta 0 radianes
              final double progress = (_controller.value / 0.45).clamp(0.0, 1.0);
              final double spinAngle =
                  (1.0 - Curves.easeOutCubic.transform(progress)) * (math.pi * 4);

              return Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.rotate(
                  angle: spinAngle,
                  alignment: Alignment.center,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    alignment: Alignment.center,
                    child: child,
                  ),
                ),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/foto1.jpg',
                    width: topPhotoWidth,
                    height: topPhotoWidth * 0.68,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: topPhotoWidth,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          'assets/images/foto2.jpg',
                          width: bottomPhotoWidth,
                          height: bottomPhotoWidth * 0.95,
                          fit: BoxFit.cover,
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          'assets/images/foto3.jpg',
                          width: bottomPhotoWidth,
                          height: bottomPhotoWidth * 0.95,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}