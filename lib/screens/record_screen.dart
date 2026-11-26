import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:geolocator/geolocator.dart';
import '../main.dart';
import 'save_screen.dart';

import 'widgets/pro_mode_view.dart';
import 'widgets/recording_controls_panel.dart';

class RecordActivityScreen extends StatefulWidget {
  final VoidCallback? onSaved;
  const RecordActivityScreen({super.key, this.onSaved});

  @override
  State<RecordActivityScreen> createState() => _RecordActivityScreenState();
}

class _RecordActivityScreenState extends State<RecordActivityScreen>
    with WidgetsBindingObserver {
  gmaps.LatLng _currentLocation = const gmaps.LatLng(36.1750, -5.7167);
  gmaps.GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionStream;

  bool _isProMode = false;
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isAutoPaused = false;

  // Estado de señal / conexión GPS estilo Strava
  bool _gpsSignalLost = false;
  int _secondsWithoutGps = 0;

  double _gpsAccuracy = 999.0;
  DateTime? _lastPositionTime;
  bool _hasRecentMovement = false;

  String _selectedSport = 'Ciclismo';
  final Map<String, IconData> _sports = {
    'Ciclismo': Icons.directions_bike,
    'Running': Icons.directions_run,
    'Caminata': Icons.directions_walk,
    'Senderismo': Icons.terrain,
    'Windsurf': Icons.surfing,
    'Natación': Icons.pool,
    'Remo': Icons.rowing,
    'Elíptica': Icons.fitness_center,
    'Gimnasio': Icons.sports_gymnastics,
  };

  int _seconds = 0;
  int _totalSeconds = 0;
  double _distanceKm = 0.0;
  double _currentSpeedKmh = 0.0;
  double _maxSpeedRecorded = 0.0;

  double _currentGrade = 0.0;
  double _maxGradeRecorded = 0.0;
  double? _gradeAnchorAltitude;
  double _gradeAnchorDistanceMeters = 0.0;
  double _currentAltitudeMeters = 0.0;

  double? _startTemperature;
  Timer? _timer;
  int _stoppedSecondsCounter = 0;

  List<gmaps.LatLng> _routePoints = [];
  final List<TrackpointData> _recordedTrackpoints = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initGpsStream();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Al volver a la app, aseguramos que el stream GPS sigue vivo
      if (_positionStream == null || _positionStream!.isPaused) {
        _initGpsStream(forceRestart: true);
      }
      if (_mapController != null && _routePoints.isNotEmpty) {
        _mapController!.animateCamera(
          gmaps.CameraUpdate.newLatLng(_currentLocation),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionStream?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  void _showConnectionResumedBanner() {
    if (!mounted) return;
    final isGerman = AppStrings.of(context).isGerman;
    final msg = isGerman
        ? 'Verbindung wiederhergestellt – Aufnahme läuft weiter'
        : 'Conexión reanudada – seguimos grabando';

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.gps_fixed, color: Colors.greenAccent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  msg,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1A1D24),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  Future<void> _initGpsStream({bool forceRestart = false}) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      if (!forceRestart) {
        try {
          Position initialPosition = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.bestForNavigation,
          );
          _updateLocation(initialPosition);
        } catch (_) {}
      }

      late LocationSettings locationSettings;
      if (defaultTargetPlatform == TargetPlatform.android) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          intervalDuration: const Duration(milliseconds: 500),
          distanceFilter: 0,
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'TeamTracker grabando ruta',
            notificationText: 'Seguimiento GPS activo en segundo plano',
            notificationChannelName: 'Seguimiento GPS',
            enableWakeLock: true,
          ),
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
        );
      }

      await _positionStream?.cancel();
      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _updateLocation(position);
        },
        cancelOnError: false,
        onError: (_) {
          if (mounted) {
            setState(() {
              _gpsSignalLost = true;
            });
          }
          // Reintento suave si el proveedor GPS lanza un error temporal
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && _isRecording) {
              _initGpsStream(forceRestart: true);
            }
          });
        },
      );
    } catch (_) {}
  }

  Future<void> _fetchStartTemperature(double lat, double lon) async {
    try {
      final uri = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true');
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode == 200) {
        final jsonString = await response.transform(utf8.decoder).join();
        final data = jsonDecode(jsonString);
        final currentWeather = data['current_weather'];
        if (currentWeather != null && mounted) {
          setState(() {
            _startTemperature =
                (currentWeather['temperature'] as num).toDouble();
          });
        }
      }
      client.close();
    } catch (_) {
      // Sin conexión a internet no se corta la grabación
    }
  }

  void _updateLocation(Position position) {
    final newPos = gmaps.LatLng(position.latitude, position.longitude);
    if (!mounted) return;

    final DateTime now = DateTime.now();
    final bool hadSignalDrop = _gpsSignalLost && _isRecording;

    setState(() {
      final prevPos = _currentLocation;
      final prevTime = _lastPositionTime;

      _gpsSignalLost = false;
      _secondsWithoutGps = 0;
      _currentLocation = newPos;
      _gpsAccuracy = position.accuracy;
      _lastPositionTime = now;

      double rawAltitude = position.altitude;
      double correctedAltitude =
          rawAltitude > 50 ? rawAltitude - 60 : rawAltitude;
      double clampedAltitude = correctedAltitude < 0 ? 0 : correctedAltitude;

      if (_currentAltitudeMeters == 0.0 && clampedAltitude > 0.0) {
        _currentAltitudeMeters = clampedAltitude;
      } else {
        _currentAltitudeMeters =
            (_currentAltitudeMeters * 0.7) + (clampedAltitude * 0.3);
      }

      if (_mapController != null && !_isProMode) {
        _mapController!.animateCamera(
          gmaps.CameraUpdate.newLatLng(newPos),
        );
      }

      // Velocidad del sensor GPS (m/s -> km/h)
      double sensorSpeedKmh = position.speed >= 0 ? position.speed * 3.6 : 0.0;

      // Velocidad calculada entre puntos como respaldo fiable
      double deltaMeters = Geolocator.distanceBetween(
        prevPos.latitude,
        prevPos.longitude,
        newPos.latitude,
        newPos.longitude,
      );
      double computedSpeedKmh = 0.0;
      if (prevTime != null) {
        final int elapsedMs = now.difference(prevTime).inMilliseconds;
        if (elapsedMs > 250 && deltaMeters > 0.8 && deltaMeters <= 120.0) {
          final double speedMps = deltaMeters / (elapsedMs / 1000.0);
          computedSpeedKmh = speedMps * 3.6;
        }
      }

      // Si hay movimiento real calculado y el sensor reporta 0 o un valor bajo pegado, usamos el calculado
      double effectiveSpeedKmh;
      if (computedSpeedKmh >= 1.5 && sensorSpeedKmh < 1.5) {
        effectiveSpeedKmh = computedSpeedKmh;
      } else if (sensorSpeedKmh >= 1.5) {
        effectiveSpeedKmh = sensorSpeedKmh;
      } else {
        effectiveSpeedKmh = computedSpeedKmh;
      }

      if (effectiveSpeedKmh < 1.2) {
        effectiveSpeedKmh = 0.0;
      }

      if (_isPaused) {
        _currentSpeedKmh = 0.0;
        _currentGrade = 0.0;
      } else {
        _currentSpeedKmh = effectiveSpeedKmh;
        if (_currentSpeedKmh > _maxSpeedRecorded && _currentSpeedKmh < 120.0) {
          _maxSpeedRecorded = _currentSpeedKmh;
        }
      }

      // --- LÓGICA DE AUTO-PAUSA (solo tras haber empezado a moverse y con margen de 6s) ---
      if (_isRecording && !_isPaused) {
        if (_currentSpeedKmh >= 1.8 || deltaMeters >= 1.5) {
          _hasRecentMovement = true;
          _stoppedSecondsCounter = 0;
          _isAutoPaused = false;
        } else if (_hasRecentMovement) {
          _stoppedSecondsCounter++;
          if (_stoppedSecondsCounter >= 6) {
            _isAutoPaused = true;
          }
        } else {
          _isAutoPaused = false;
        }
      }

      if (_isRecording && !_isPaused && !_isAutoPaused) {
        if (_routePoints.isNotEmpty) {
          double lastLat = _routePoints.last.latitude;
          double lastLng = _routePoints.last.longitude;
          double addedDistance = Geolocator.distanceBetween(
            lastLat,
            lastLng,
            position.latitude,
            position.longitude,
          );

          final double minStepMeters =
              position.accuracy > 0 && position.accuracy < 25.0
                  ? (position.accuracy * 0.25).clamp(0.8, 3.0)
                  : 1.0;

          if (addedDistance >= minStepMeters && addedDistance <= 300.0) {
            _distanceKm += (addedDistance / 1000.0);
            _routePoints.add(newPos);

            final double totalDistanceMeters = _distanceKm * 1000.0;

            _recordedTrackpoints.add(
              TrackpointData(
                latitude: position.latitude,
                longitude: position.longitude,
                elevation: _currentAltitudeMeters,
                timestamp: now,
                distanceFromStart: totalDistanceMeters,
              ),
            );

            if (_gradeAnchorAltitude == null) {
              _gradeAnchorAltitude = _currentAltitudeMeters;
              _gradeAnchorDistanceMeters = totalDistanceMeters;
            } else {
              final double spanMeters =
                  totalDistanceMeters - _gradeAnchorDistanceMeters;
              if (spanMeters >= 35.0) {
                final double heightGain =
                    _currentAltitudeMeters - _gradeAnchorAltitude!;
                if (heightGain.abs() >= 3.0) {
                  final double calculatedGrade =
                      (heightGain / spanMeters) * 100.0;
                  if (calculatedGrade >= -30.0 && calculatedGrade <= 35.0) {
                    _currentGrade =
                        calculatedGrade < 0 ? 0.0 : calculatedGrade;
                    if (_currentGrade > _maxGradeRecorded) {
                      _maxGradeRecorded = _currentGrade;
                    }
                  }
                } else {
                  _currentGrade = 0.0;
                }
                _gradeAnchorAltitude = _currentAltitudeMeters;
                _gradeAnchorDistanceMeters = totalDistanceMeters;
              }
            }
          }
        } else {
          _routePoints.add(newPos);
          _recordedTrackpoints.add(
            TrackpointData(
              latitude: position.latitude,
              longitude: position.longitude,
              elevation: _currentAltitudeMeters,
              timestamp: now,
              distanceFromStart: 0.0,
            ),
          );
          _gradeAnchorAltitude = _currentAltitudeMeters;
          _gradeAnchorDistanceMeters = 0.0;
        }
      }
    });

    if (hadSignalDrop) {
      _showConnectionResumedBanner();
    }
  }

  String _encodePolyline(List<gmaps.LatLng> points) {
    int encodeSigned(int val) {
      int sgn = val < 0 ? ~(val << 1) : (val << 1);
      return sgn;
    }

    String encodeNumber(int val) {
      String encode = '';
      while (val >= 0x20) {
        encode += String.fromCharCode((0x20 | (val & 0x1f)) + 63);
        val >>= 5;
      }
      encode += String.fromCharCode(val + 63);
      return encode;
    }

    String result = '';
    int lastLat = 0;
    int lastLng = 0;

    for (var point in points) {
      int lat = (point.latitude * 1E5).round();
      int lng = (point.longitude * 1E5).round();

      int dLat = lat - lastLat;
      int dLng = lng - lastLng;

      lastLat = lat;
      lastLng = lng;

      result += encodeNumber(encodeSigned(dLat));
      result += encodeNumber(encodeSigned(dLng));
    }

    return result;
  }

  void _startRecording() async {
    await _initGpsStream(forceRestart: true);

    try {
      Position? currentPos = await Geolocator.getLastKnownPosition();
      if (currentPos != null) {
        _updateLocation(currentPos);
      } else {
        Position freshPos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
        );
        _updateLocation(freshPos);
      }
    } catch (_) {}

    setState(() {
      _isRecording = true;
      _isPaused = false;
      _isAutoPaused = false;
      _gpsSignalLost = false;
      _secondsWithoutGps = 0;
      _hasRecentMovement = false;
      _seconds = 0;
      _totalSeconds = 0;
      _stoppedSecondsCounter = 0;
      _distanceKm = 0.0;
      _currentSpeedKmh = 0.0;
      _maxSpeedRecorded = 0.0;
      _currentGrade = 0.0;
      _maxGradeRecorded = 0.0;
      _gradeAnchorAltitude = null;
      _gradeAnchorDistanceMeters = 0.0;
      _startTemperature = null;
      _routePoints = [_currentLocation];
      _recordedTrackpoints.clear();
    });

    if (_mapController != null) {
      _mapController!.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(_currentLocation, 16.0),
      );
    }

    _fetchStartTemperature(_currentLocation.latitude, _currentLocation.longitude);

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isRecording && mounted) {
        final int msSinceLastPos = _lastPositionTime != null
            ? DateTime.now().difference(_lastPositionTime!).inMilliseconds
            : 999999;

        setState(() {
          _totalSeconds++;
          if (!_isPaused && !_isAutoPaused) {
            _seconds++;
          }

          if (msSinceLastPos > 3000) {
            _secondsWithoutGps++;
            if (_currentSpeedKmh > 0) {
              _currentSpeedKmh = 0.0;
            }
            if (_secondsWithoutGps >= 5) {
              _gpsSignalLost = true;
            }
          }
        });

        // Si llevamos 6s sin recibir datos GPS mientras grabamos, reenganchamos el stream
        if (_secondsWithoutGps > 0 && _secondsWithoutGps % 6 == 0) {
          _initGpsStream(forceRestart: true);
        }

        if (_totalSeconds % 60 == 0) {
          _fetchStartTemperature(
              _currentLocation.latitude, _currentLocation.longitude);
        }
      }
    });
  }

  void _pauseRecording() {
    setState(() {
      _isPaused = true;
      _currentSpeedKmh = 0.0;
      _currentGrade = 0.0;
    });
  }

  void _resumeRecording() {
    setState(() {
      _isPaused = false;
      _isAutoPaused = false;
      _stoppedSecondsCounter = 0;
    });
  }

  void _discardRecording() {
    _timer?.cancel();
    final strings = AppStrings.of(context);
    setState(() {
      _isRecording = false;
      _isPaused = false;
      _isAutoPaused = false;
      _gpsSignalLost = false;
      _secondsWithoutGps = 0;
      _hasRecentMovement = false;
      _seconds = 0;
      _totalSeconds = 0;
      _stoppedSecondsCounter = 0;
      _distanceKm = 0.0;
      _currentSpeedKmh = 0.0;
      _maxSpeedRecorded = 0.0;
      _currentGrade = 0.0;
      _maxGradeRecorded = 0.0;
      _gradeAnchorAltitude = null;
      _gradeAnchorDistanceMeters = 0.0;
      _startTemperature = null;
      _routePoints.clear();
      _recordedTrackpoints.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings.routeDiscarded),
        backgroundColor: Colors.grey,
      ),
    );
  }

  void _goToSaveScreen() {
    _timer?.cancel();
    final strings = AppStrings.of(context);

    double hours = _seconds > 0 ? _seconds / 3600.0 : 0.001;
    double avgSpeed = _distanceKm / hours;

    if (_maxSpeedRecorded < avgSpeed) {
      _maxSpeedRecorded = avgSpeed * 1.5;
    }

    String defaultTitle = strings.defaultRouteTitleForSport(_selectedSport);
    final encodedRoute = _encodePolyline(_routePoints);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SaveActivityScreen(
          defaultTitle: defaultTitle,
          selectedSport: _selectedSport,
          distanceKm: _distanceKm,
          movingSeconds: _seconds,
          totalSeconds: _totalSeconds,
          avgSpeed: avgSpeed,
          maxSpeed: _maxSpeedRecorded,
          maxGrade: _maxGradeRecorded,
          encodedRoute: encodedRoute,
          startTemp: _startTemperature,
          trackpoints: _recordedTrackpoints,
          onSuccess: () {
            setState(() {
              _isRecording = false;
              _isPaused = false;
              _isAutoPaused = false;
              _gpsSignalLost = false;
              _secondsWithoutGps = 0;
              _hasRecentMovement = false;
              _seconds = 0;
              _totalSeconds = 0;
              _stoppedSecondsCounter = 0;
              _distanceKm = 0.0;
              _currentSpeedKmh = 0.0;
              _maxSpeedRecorded = 0.0;
              _currentGrade = 0.0;
              _maxGradeRecorded = 0.0;
              _gradeAnchorAltitude = null;
              _gradeAnchorDistanceMeters = 0.0;
              _startTemperature = null;
              _routePoints.clear();
              _recordedTrackpoints.clear();
            });

            if (widget.onSaved != null) {
              widget.onSaved!();
            }
          },
          onDiscard: () {
            setState(() {
              _isRecording = false;
              _isPaused = false;
              _isAutoPaused = false;
              _gpsSignalLost = false;
              _secondsWithoutGps = 0;
              _hasRecentMovement = false;
              _seconds = 0;
              _totalSeconds = 0;
              _stoppedSecondsCounter = 0;
              _distanceKm = 0.0;
              _currentSpeedKmh = 0.0;
              _maxSpeedRecorded = 0.0;
              _currentGrade = 0.0;
              _maxGradeRecorded = 0.0;
              _gradeAnchorAltitude = null;
              _gradeAnchorDistanceMeters = 0.0;
              _startTemperature = null;
              _routePoints.clear();
              _recordedTrackpoints.clear();
            });

            if (widget.onSaved != null) {
              widget.onSaved!();
            }
          },
        ),
      ),
    );
  }

  String _formatTimer(int seconds) {
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    final int s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildGpsIndicator(AppStrings strings) {
    final int meters = _gpsAccuracy.toInt();
    String text;
    Color color;
    IconData icon;

    if (_gpsSignalLost && _isRecording) {
      text = strings.isGerman
          ? 'GPS-Signal unterbrochen – Suche...'
          : 'Señal perdida – reanudando...';
      color = Colors.amberAccent;
      icon = Icons.sync_problem;
    } else if (_gpsAccuracy <= 5.0) {
      text = strings.gpsExcellent(meters);
      color = Colors.greenAccent;
      icon = Icons.gps_fixed;
    } else if (_gpsAccuracy <= 15.0) {
      text = strings.gpsGood(meters);
      color = Colors.lightBlueAccent;
      icon = Icons.gps_not_fixed;
    } else if (_gpsAccuracy <= 30.0) {
      text = strings.gpsWeak(meters);
      color = Colors.orangeAccent;
      icon = Icons.gps_off;
    } else {
      text = strings.searchingGps;
      color = Colors.redAccent;
      icon = Icons.satellite_alt;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D24).withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingMapOrPlaceholder() {
    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(
        target: _currentLocation,
        zoom: 16.0,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
      },
      mapType: gmaps.MapType.satellite,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: true,
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      tiltGesturesEnabled: true,
      rotateGesturesEnabled: true,
      polylines: {
        if (_routePoints.isNotEmpty)
          gmaps.Polyline(
            polylineId: const gmaps.PolylineId('live_route'),
            points: List.from(_routePoints),
            color: const Color(0xFFFC5200),
            width: 5,
          ),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    final double controlsBottom = bottomInset + 64.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      body: Stack(
        children: [
          _isProMode
              ? SafeArea(
                  top: true,
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: controlsBottom + 148.0),
                    child: Center(
                      child: ProModeView(
                        currentSpeedKmh: _currentSpeedKmh,
                        distanceKm: _distanceKm,
                        seconds: _seconds,
                        currentGrade: _currentGrade,
                        startTemperature: _startTemperature,
                        currentAltitudeMeters: _currentAltitudeMeters,
                        isPaused: _isPaused || _isAutoPaused,
                      ),
                    ),
                  ),
                )
              : Stack(
                  children: [
                    Positioned.fill(
                      child: _buildRecordingMapOrPlaceholder(),
                    ),
                    Positioned(
                      top: 50,
                      left: 12,
                      right: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1D24).withOpacity(0.95),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Row(
                                      children: [
                                        Text(strings.timeUpper,
                                            style: const TextStyle(
                                                fontSize: 8, color: Colors.grey)),
                                        if ((_isPaused || _isAutoPaused) &&
                                            _isRecording)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 3),
                                            child: Text(
                                              _isAutoPaused
                                                  ? strings.autoPauseTag
                                                  : strings.pauseTag,
                                              style: TextStyle(
                                                  fontSize: 7,
                                                  color: _isAutoPaused
                                                      ? Colors.amber
                                                      : Colors.orange),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTimer(_seconds),
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                    ),
                                  ],
                                ),
                                Container(
                                    height: 24, width: 1, color: Colors.white10),
                                Column(
                                  children: [
                                    Text(strings.distanceUpper,
                                        style: const TextStyle(
                                            fontSize: 8, color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_distanceKm.toStringAsFixed(2)} km',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFFC5200)),
                                    ),
                                  ],
                                ),
                                Container(
                                    height: 24, width: 1, color: Colors.white10),
                                Column(
                                  children: [
                                    Text(strings.speedUpper,
                                        style: const TextStyle(
                                            fontSize: 8, color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_currentSpeedKmh.toStringAsFixed(1)}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.greenAccent),
                                    ),
                                  ],
                                ),
                                Container(
                                    height: 24, width: 1, color: Colors.white10),
                                Column(
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.terrain,
                                            size: 9,
                                            color: Colors.lightGreenAccent),
                                        const SizedBox(width: 2),
                                        Text(strings.altitudeUpper,
                                            style: const TextStyle(
                                                fontSize: 8, color: Colors.grey)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_currentAltitudeMeters.toInt()}m',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.lightGreenAccent),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _buildGpsIndicator(strings),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

          Positioned(
            top: _isProMode ? 52 : 145,
            right: 20,
            child: FloatingActionButton.small(
              heroTag: 'toggle_pro_mode',
              backgroundColor: const Color(0xFF1A1D24),
              foregroundColor: const Color(0xFFFC5200),
              elevation: 4,
              child: Icon(_isProMode ? Icons.map : Icons.speed),
              onPressed: () {
                setState(() {
                  _isProMode = !_isProMode;
                });
              },
            ),
          ),

          Positioned(
            bottom: controlsBottom,
            left: 20,
            right: 20,
            child: RecordingControlsPanel(
              isRecording: _isRecording,
              isPaused: _isPaused || _isAutoPaused,
              selectedSport: _selectedSport,
              sports: _sports,
              onSportSelected: (sport) {
                setState(() {
                  _selectedSport = sport;
                });
              },
              onStart: _startRecording,
              onPauseResume: () {
                if (_isPaused || _isAutoPaused) {
                  _resumeRecording();
                } else {
                  _pauseRecording();
                }
              },
              onDiscard: _discardRecording,
              onFinish: _goToSaveScreen,
            ),
          ),
        ],
      ),
    );
  }
}