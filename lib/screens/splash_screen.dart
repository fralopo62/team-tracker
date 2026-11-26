import 'dart:async';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({
    super.key,
    required this.nextScreen,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Temporizador exacto de 4 segundos antes de pasar al Dashboard
    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => widget.nextScreen),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Título principal elevado en la parte superior
                const Text(
                  'TEAMTRACKER',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                    color: Color(0xFFFC5200),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tu registro deportivo inteligente',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 35),

                // Contenedor principal con ancho fijo simétrico para alinear todo perfectamente
                SizedBox(
                  width: 300,
                  child: Column(
                    children: [
                      // Foto 1 (Arriba, grande)
                      _buildPhoto('assets/images/foto1.jpg', width: 300, height: 160),
                      const SizedBox(height: 10), // Pequeño espacio de separación vertical
                      // Fotos 2 y 3 (Abajo, una al lado de la otra ocupando el mismo ancho total de 300)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildPhoto('assets/images/foto2.jpg', width: 145, height: 110),
                          _buildPhoto('assets/images/foto3.jpg', width: 145, height: 110),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Indicador de carga sutil
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFC5200)),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget auxiliar para dar formato unificado, bordes redondeados y sombras
  Widget _buildPhoto(String assetPath, {required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: const Color(0xFF1A1D24),
              child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 30),
            );
          },
        ),
      ),
    );
  }
}