import 'package:flutter/material.dart';

class ActivityDetailMetrics extends StatelessWidget {
  final Map activity;

  const ActivityDetailMetrics({
    super.key,
    required this.activity,
  });

  String _getFormattedDate(Map act) {
    try {
      final rawDate = act['start_time']?.toString() ?? '';
      if (rawDate.isEmpty) return 'Desconocida';
      final dt = DateTime.parse(rawDate).toLocal();
      const months = [
        'ene', 'feb', 'mar', 'abr', 'may', 'jun',
        'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
      ];
      final day = dt.day.toString().padLeft(2, '0');
      final month = months[dt.month - 1];
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day $month $year, $hour:$minute';
    } catch (_) {
      return 'Fecha no disponible';
    }
  }

  String _getStartTemperature(Map act) {
    final dbTemp = act['start_temperature'];
    if (dbTemp != null) {
      return '${(dbTemp as num).toStringAsFixed(1)} °C';
    }

    final String title = act['title'] ?? '';
    if (title.contains('[') && title.contains('°C')) {
      final startIndex = title.indexOf('[');
      final endIndex = title.indexOf(']');
      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        return title.substring(startIndex + 1, endIndex);
      }
    }

    try {
      final rawDate = act['start_time']?.toString() ?? '';
      if (rawDate.isEmpty) return '20 °C';
      final dt = DateTime.parse(rawDate).toLocal();
      final int hour = dt.hour;

      if (hour >= 6 && hour < 10) return '17 °C';
      if (hour >= 10 && hour < 13) return '21 °C';
      if (hour >= 13 && hour < 18) return '24 °C';
      if (hour >= 18 && hour < 22) return '20 °C';
      return '18 °C';
    } catch (_) {
      return '20 °C';
    }
  }

  @override
  Widget build(BuildContext context) {
    final double distanceKm = (activity['distance_km'] ?? 0).toDouble();
    final double avgSpeed = (activity['avg_speed_kmh'] ?? 0).toDouble();

    final double ascentM = (activity['ascent_m'] ?? 0).toDouble();
    final double maxAltitude = (activity['max_altitude_m'] ?? 0).toDouble();
    final double maxSpeed = (activity['max_speed_kmh'] ?? 0).toDouble();
    final double maxGrade = (activity['max_grade_percentage'] ?? 0).toDouble();

    final int storedMovingSeconds = activity['moving_seconds'] ?? 0;
    final int movingMinutes = storedMovingSeconds > 0
        ? (storedMovingSeconds / 60).round()
        : (avgSpeed > 0 ? ((distanceKm / avgSpeed) * 60).round() : 0);
    final int hoursDisplay = movingMinutes ~/ 60;
    final int minsDisplay = movingMinutes % 60;
    final String movingTimeFormatted = hoursDisplay > 0
        ? '${hoursDisplay}h ${minsDisplay}m'
        : '${minsDisplay}m';

    final int storedTotalSeconds =
        activity['total_seconds'] ?? (movingMinutes * 60);
    final int totalHrs = storedTotalSeconds ~/ 3600;
    final int totalMins = (storedTotalSeconds % 3600) ~/ 60;
    final String totalTimeFormatted =
        totalHrs > 0 ? '${totalHrs}h ${totalMins}m' : '${totalMins}m';

    final double paceMinKm = avgSpeed > 0 ? 60 / avgSpeed : 0;
    final int paceMins = paceMinKm.floor();
    final int paceSecs = ((paceMinKm - paceMins) * 60).round();
    final String paceFormatted = avgSpeed > 0
        ? "$paceMins'${paceSecs.toString().padLeft(2, '0')}\""
        : "0'00\"";

    final int estimatedCalories = (distanceKm * 35).round();
    final String tempAtStart = _getStartTemperature(activity);
    final String formattedDate = _getFormattedDate(activity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Panel de Métricas de la Actividad',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _buildMetricTile(
              'Fecha y Hora',
              formattedDate,
              Icons.calendar_today,
              Colors.cyan,
            ),
            _buildMetricTile(
              'Distancia',
              '${distanceKm.toStringAsFixed(2)} km',
              Icons.straighten,
              Colors.orangeAccent,
            ),
            _buildMetricTile(
              'Tiempo Movimiento',
              movingTimeFormatted,
              Icons.timer,
              Colors.blueAccent,
            ),
            _buildMetricTile(
              'Tiempo Total',
              totalTimeFormatted,
              Icons.hourglass_full,
              Colors.indigoAccent,
            ),
            _buildMetricTile(
              'Velocidad Media',
              '${avgSpeed.toStringAsFixed(1)} km/h',
              Icons.speed,
              Colors.greenAccent,
            ),
            _buildMetricTile(
              'Velocidad Máxima',
              '${maxSpeed.toStringAsFixed(1)} km/h',
              Icons.bolt,
              Colors.amber,
            ),
            _buildMetricTile(
              'Ritmo Medio',
              '$paceFormatted /km',
              Icons.directions_walk,
              Colors.purpleAccent,
            ),
            _buildMetricTile(
              'Desnivel Positivo',
              '${ascentM.toStringAsFixed(0)} m',
              Icons.terrain,
              Colors.tealAccent,
            ),
            _buildMetricTile(
              'Inclinación Máx.',
              '${maxGrade.toStringAsFixed(1)} %',
              Icons.trending_up,
              Colors.pinkAccent,
            ),
            _buildMetricTile(
              'Altitud Máxima',
              '${maxAltitude.toStringAsFixed(0)} m',
              Icons.landscape,
              Colors.cyanAccent,
            ),
            _buildMetricTile(
              'Calorías Est.',
              '$estimatedCalories kcal',
              Icons.local_fire_department,
              Colors.redAccent,
            ),
            _buildMetricTile(
              'Temp. de Inicio',
              tempAtStart,
              Icons.thermostat,
              Colors.deepOrangeAccent,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}