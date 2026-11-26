import 'package:flutter/material.dart';
import '../../main.dart';

class ProModeView extends StatelessWidget {
  final double currentSpeedKmh;
  final double distanceKm;
  final int seconds;
  final double currentGrade;
  final double? startTemperature;
  final double currentAltitudeMeters;
  final bool isPaused;

  const ProModeView({
    super.key,
    required this.currentSpeedKmh,
    required this.distanceKm,
    required this.seconds,
    required this.currentGrade,
    required this.startTemperature,
    required this.currentAltitudeMeters,
    required this.isPaused,
  });

  String _formatTimer(int seconds) {
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    final int s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Container(
      color: const Color(0xFF0F1115),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 130),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.speed, color: Color(0xFFFC5200), size: 24),
                      const SizedBox(width: 8),
                      Text(
                        strings.cycleComputerPro,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 1.5),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPaused ? Colors.orange : Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isPaused ? strings.pausedUpper : strings.recordingUpper,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(strings.currentSpeedUpper,
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 12, letterSpacing: 2)),
              const SizedBox(height: 4),
              Text(
                currentSpeedKmh.toStringAsFixed(1),
                style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                    color: Colors.greenAccent),
              ),
              const Text(
                'km/h',
                style: TextStyle(
                    fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1D24),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          Text(strings.distanceUpper,
                              style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(
                            distanceKm.toStringAsFixed(2),
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFC5200)),
                          ),
                          const Text('km',
                              style: TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1D24),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          Text(strings.movingTimeUpper,
                              style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(
                            _formatTimer(seconds),
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          const Text('hh:mm:ss',
                              style: TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1D24),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.terrain,
                                size: 12, color: Colors.lightGreenAccent),
                            const SizedBox(width: 3),
                            Text(strings.altitudeUpper,
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 10)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${currentAltitudeMeters.toInt()}m',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.lightGreenAccent),
                        ),
                      ],
                    ),
                    Container(height: 25, width: 1, color: Colors.white10),
                    Column(
                      children: [
                        Text(strings.gradeUpper,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 10)),
                        const SizedBox(height: 4),
                        Text(
                          '${currentGrade.toStringAsFixed(1)} %',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber),
                        ),
                      ],
                    ),
                    Container(height: 25, width: 1, color: Colors.white10),
                    Column(
                      children: [
                        Text(strings.temperatureUpper,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 10)),
                        const SizedBox(height: 4),
                        Text(
                          startTemperature != null
                              ? '${startTemperature!.toStringAsFixed(1)} °C'
                              : '-- °C',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrangeAccent),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}