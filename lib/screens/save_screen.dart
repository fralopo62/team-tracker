import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart';

/// Modelo opcional para los puntos detallados (trackpoints)
class TrackpointData {
  final double latitude;
  final double longitude;
  final double? elevation;
  final DateTime? timestamp;
  final double? distanceFromStart;

  TrackpointData({
    required this.latitude,
    required this.longitude,
    this.elevation,
    this.timestamp,
    this.distanceFromStart,
  });
}

class SaveActivityScreen extends StatefulWidget {
  final String defaultTitle;
  final String selectedSport;
  final double distanceKm;
  final int movingSeconds;
  final int totalSeconds;
  final double avgSpeed;
  final double maxSpeed;
  final double maxGrade;
  final String encodedRoute;
  final double? startTemp;
  final List<TrackpointData>? trackpoints;
  final VoidCallback onSuccess;
  final VoidCallback onDiscard;

  const SaveActivityScreen({
    super.key,
    required this.defaultTitle,
    required this.selectedSport,
    required this.distanceKm,
    required this.movingSeconds,
    required this.totalSeconds,
    required this.avgSpeed,
    required this.maxSpeed,
    required this.maxGrade,
    required this.encodedRoute,
    this.startTemp,
    this.trackpoints,
    required this.onSuccess,
    required this.onDiscard,
  });

  @override
  State<SaveActivityScreen> createState() => _SaveActivityScreenState();
}

class _SaveActivityScreenState extends State<SaveActivityScreen> {
  late TextEditingController _titleController;
  late String _selectedSport;
  final List<XFile> _selectedPhotos = [];
  bool _isSaving = false;

  final List<String> _availableSports = [
    'Ciclismo',
    'Running',
    'Senderismo',
    'Caminar',
    'Remo',
    'Gimnasio',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.defaultTitle);
    _selectedSport = _availableSports.contains(widget.selectedSport)
        ? widget.selectedSport
        : _availableSports.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image =
        await picker.pickImage(source: source, imageQuality: 80);
    if (image != null) {
      setState(() {
        _selectedPhotos.add(image);
      });
    }
  }

  ({double ascentM, double maxAltitudeM}) _calculateElevationMetrics() {
    final points = widget.trackpoints;
    if (points == null || points.isEmpty) {
      return (ascentM: 0.0, maxAltitudeM: 0.0);
    }

    const double bucketSizeMeters = 20.0;
    const double minSegmentGainMeters = 4.0;
    const double maxSegmentGainMeters = 30.0;

    double maxAlt = 0.0;
    final List<double> bucketMeans = [];

    double currentBucketSum = 0.0;
    int currentBucketCount = 0;
    double bucketStartDistance = points.first.distanceFromStart ?? 0.0;

    for (int i = 0; i < points.length; i++) {
      final tp = points[i];
      final double? elev = tp.elevation;
      if (elev == null) continue;

      if (elev > maxAlt) {
        maxAlt = elev;
      }

      final double dist = tp.distanceFromStart ?? (i * 5.0);
      if (currentBucketCount > 0 &&
          (dist - bucketStartDistance) >= bucketSizeMeters) {
        bucketMeans.add(currentBucketSum / currentBucketCount);
        currentBucketSum = 0.0;
        currentBucketCount = 0;
        bucketStartDistance = dist;
      }

      currentBucketSum += elev;
      currentBucketCount++;
    }

    if (currentBucketCount > 0) {
      bucketMeans.add(currentBucketSum / currentBucketCount);
    }

    if (bucketMeans.length < 2) {
      return (
        ascentM: 0.0,
        maxAltitudeM: double.parse(maxAlt.toStringAsFixed(0)),
      );
    }

    double ascent = 0.0;
    double prevMean = bucketMeans.first;

    for (int i = 1; i < bucketMeans.length; i++) {
      final double currMean = bucketMeans[i];
      final double diff = currMean - prevMean;

      if (diff >= minSegmentGainMeters && diff <= maxSegmentGainMeters) {
        ascent += diff;
        prevMean = currMean;
      } else if (diff < -minSegmentGainMeters) {
        prevMean = currMean;
      }
    }

    return (
      ascentM: double.parse(ascent.toStringAsFixed(0)),
      maxAltitudeM: double.parse(maxAlt.toStringAsFixed(0)),
    );
  }

  Future<void> _saveToSupabase() async {
    setState(() {
      _isSaving = true;
    });

    final supabase = Supabase.instance.client;
    final messenger = ScaffoldMessenger.of(context);
    List<String> uploadedPhotoUrls = [];

    for (var imageFile in _selectedPhotos) {
      try {
        final file = File(imageFile.path);
        final fileExt = imageFile.path.split('.').last;
        final fileName =
            'photo_${DateTime.now().millisecondsSinceEpoch}_${uploadedPhotoUrls.length}.$fileExt';

        await supabase.storage.from('activity_photos').upload(
              fileName,
              file,
              fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
            );

        final String signedUrl = await supabase.storage
            .from('activity_photos')
            .createSignedUrl(fileName, 60 * 60 * 24 * 365);

        uploadedPhotoUrls.add(signedUrl);
      } catch (_) {}
    }

    String finalTitle = _titleController.text.trim().isEmpty
        ? widget.defaultTitle
        : _titleController.text.trim();

    final String? currentUserId = supabase.auth.currentUser?.id;
    final elevationMetrics = _calculateElevationMetrics();

    try {
      final response = await supabase.from('activities').insert({
        if (currentUserId != null) 'user_id': currentUserId,
        'title': finalTitle,
        'sport': _selectedSport,
        'distance_km': double.parse(widget.distanceKm.toStringAsFixed(2)),
        'ascent_m': elevationMetrics.ascentM,
        'max_altitude_m': elevationMetrics.maxAltitudeM,
        'avg_speed_kmh': double.parse(widget.avgSpeed.toStringAsFixed(1)),
        'max_speed_kmh': double.parse(widget.maxSpeed.toStringAsFixed(1)),
        'max_grade_percentage':
            double.parse(widget.maxGrade.toStringAsFixed(1)),
        'route_polyline': widget.encodedRoute,
        'start_time': DateTime.now().toIso8601String(),
        'start_temperature': widget.startTemp != null
            ? double.parse(widget.startTemp!.toStringAsFixed(1))
            : null,
        'file_hash': 'manual_${DateTime.now().millisecondsSinceEpoch}',
        'photos': uploadedPhotoUrls,
        'moving_seconds': widget.movingSeconds,
        'total_seconds': widget.totalSeconds,
        'athlete_name': 'Francisco Poyatos',
        'location': 'Brenes, Sevilla',
      }).select().single();

      final String activityId = response['id'];

      if (widget.trackpoints != null && widget.trackpoints!.isNotEmpty) {
        var trackpointsData = widget.trackpoints!.map((tp) {
          return {
            'activity_id': activityId,
            'latitude': tp.latitude,
            'longitude': tp.longitude,
            'elevation': tp.elevation,
            'timestamp': tp.timestamp?.toIso8601String(),
            'distance_from_start': tp.distanceFromStart,
          };
        }).toList();

        await supabase.from('activity_trackpoints').insert(trackpointsData);
      }

      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        activitiesRefreshNotifier.value++;
        widget.onSuccess();
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Ruta guardada'),
            backgroundColor: Color(0xFFFC5200),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
              content: Text('Error al guardar: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _confirmAndDiscard() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1D24),
          title: const Text('Descartar Actividad',
              style: TextStyle(color: Colors.white)),
          content: const Text(
            '¿Estás seguro de que deseas descartar esta ruta? Se perderán todos los datos registrados.',
            style: TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child:
                  const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('DESCARTAR',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      widget.onDiscard();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ruta descartada correctamente.'),
          backgroundColor: Colors.grey,
        ),
      );
    }
  }

  String _formatTimer(int seconds) {
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    final int s = seconds % 60;
    if (h > 0) {
      return '${h}h ${m}m';
    }
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    if (_isSaving) {
      return const PremiumSavingScreen();
    }

    final double bottomSystemInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        title: const Text('Finalizar Ruta',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1D24),
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 28 + bottomSystemInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tipo de Deporte',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedSport,
                dropdownColor: const Color(0xFF1A1D24),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1A1D24),
                  prefixIcon:
                      const Icon(Icons.sports_score, color: Color(0xFFFC5200)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: _availableSports.map((String sport) {
                  return DropdownMenuItem<String>(
                    value: sport,
                    child: Text(sport),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedSport = newValue;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Título / Nombre de la Ruta',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1A1D24),
                  hintText: 'Ej. Vuelta por el parque, Entrenamiento...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.edit, color: Color(0xFFFC5200)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Fotos de la Ruta',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1D24),
                      foregroundColor: const Color(0xFFFC5200),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Cámara'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1D24),
                      foregroundColor: Colors.lightBlueAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galería'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_selectedPhotos.isNotEmpty)
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedPhotos.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(_selectedPhotos[index].path),
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedPhotos.removeAt(index);
                                  });
                                },
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      size: 18, color: Colors.redAccent),
                                ),
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),
              const Text(
                'Resumen de Métricas',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1D24),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Distancia:',
                            style: TextStyle(color: Colors.grey)),
                        Text('${widget.distanceKm.toStringAsFixed(2)} km',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tiempo Movimiento:',
                            style: TextStyle(color: Colors.grey)),
                        Text(_formatTimer(widget.movingSeconds),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tiempo Total:',
                            style: TextStyle(color: Colors.grey)),
                        Text(_formatTimer(widget.totalSeconds),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Velocidad Media:',
                            style: TextStyle(color: Colors.grey)),
                        Text('${widget.avgSpeed.toStringAsFixed(1)} km/h',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Inclinación Máxima:',
                            style: TextStyle(color: Colors.grey)),
                        Text('${widget.maxGrade.toStringAsFixed(1)} %',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveToSupabase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFC5200),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'GUARDAR ACTIVIDAD',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: Colors.white),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: _confirmAndDiscard,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'DESCARTAR',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PremiumSavingScreen extends StatelessWidget {
  const PremiumSavingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0F1115),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFFC5200)),
            SizedBox(height: 20),
            Text(
              'Guardando actividad y trackpoints...',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}