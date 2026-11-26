import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'activity_detail_screen.dart';
import '../services/gpx_fit_importer.dart';

class ActivitiesFeedScreen extends StatefulWidget {
  const ActivitiesFeedScreen({super.key});

  // Caché en memoria precargada durante la portada
  static List<dynamic>? cachedActivities;

  static Future<List<dynamic>?> preloadActivities() async {
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('activities')
          .select('*')
          .order('start_time', ascending: false)
          .limit(50);
      cachedActivities = List<dynamic>.from(data);
      return cachedActivities;
    } catch (_) {
      return cachedActivities;
    }
  }

  @override
  State<ActivitiesFeedScreen> createState() => _ActivitiesFeedScreenState();
}

class _ActivitiesFeedScreenState extends State<ActivitiesFeedScreen> {
  static const MethodChannel _appLauncherChannel =
      MethodChannel('com.teamtracker/app_launcher');
  static const String _coospoRidePackage = 'com.onecoder.coosporide';

  List<dynamic> _activities = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _mapsReady = false;
  Timer? _mapMountTimer;

  @override
  void initState() {
    super.initState();
    final preloaded = ActivitiesFeedScreen.cachedActivities;
    if (preloaded != null && preloaded.isNotEmpty) {
      _activities = List<dynamic>.from(preloaded);
      _isLoading = false;
      _cargarActividades(showSpinnerIfEmpty: false, clearCacheFirst: false);
    } else {
      _cargarActividades(showSpinnerIfEmpty: true, clearCacheFirst: false);
    }
    activitiesRefreshNotifier.addListener(_onExternalRefresh);

    // Monta los GoogleMap tras el primer frame para evitar el corte al salir de la portada
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapMountTimer = Timer(const Duration(milliseconds: 140), () {
        if (mounted) {
          setState(() {
            _mapsReady = true;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _mapMountTimer?.cancel();
    activitiesRefreshNotifier.removeListener(_onExternalRefresh);
    super.dispose();
  }

  void _onExternalRefresh() {
    if (!mounted) return;
    _cargarActividades(showSpinnerIfEmpty: false, clearCacheFirst: true);
  }

  Future<void> _cargarActividades({
    bool showSpinnerIfEmpty = true,
    bool clearCacheFirst = false,
  }) async {
    if (clearCacheFirst) {
      ActivitiesFeedScreen.cachedActivities = null;
    }

    if (showSpinnerIfEmpty && _activities.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('activities')
          .select('*')
          .order('start_time', ascending: false)
          .limit(50);

      final list = List<dynamic>.from(data);
      ActivitiesFeedScreen.cachedActivities = list;

      if (!mounted) return;
      setState(() {
        _activities = list;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      final strings = AppStrings.of(context);
      setState(() {
        _isLoading = false;
        if (_activities.isEmpty) {
          _errorMessage = '${strings.loadingErrorPrefix}$e';
        }
      });
    }
  }

  Future<void> _abrirCoospoRide(AppStrings strings) async {
    try {
      final bool opened = await _appLauncherChannel.invokeMethod<bool>(
            'openApp',
            {'packageName': _coospoRidePackage},
          ) ??
          false;

      if (!mounted) return;
      if (!opened) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.coospoRideNotOpened),
            backgroundColor: const Color(0xFF1A1D24),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.coospoRideError(e)),
          backgroundColor: Colors.red.shade900,
        ),
      );
    }
  }

  List<gmaps.LatLng> _decodePolyline(String encoded) {
    List<gmaps.LatLng> points = <gmaps.LatLng>[];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(gmaps.LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  String _cleanTitle(String rawTitle) {
    if (rawTitle.contains('[') && rawTitle.contains(']')) {
      final startIndex = rawTitle.indexOf('[');
      return rawTitle.substring(0, startIndex).trim();
    }
    return rawTitle.trim();
  }

  Widget _buildMapOrPlaceholder(
      List<gmaps.LatLng> routePoints, Set<gmaps.Polyline> polylines, double height) {
    const gmaps.LatLng defaultCenter = gmaps.LatLng(36.1750, -5.7167);
    gmaps.LatLng initialCenter =
        routePoints.isNotEmpty ? routePoints.first : defaultCenter;

    if (!_mapsReady) {
      return Container(
        height: height,
        width: double.infinity,
        color: const Color(0xFF252A34),
      );
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: gmaps.GoogleMap(
        initialCameraPosition: gmaps.CameraPosition(
          target: initialCenter,
          zoom: 13.0,
        ),
        mapType: gmaps.MapType.normal,
        markers: const {},
        polylines: polylines,
        zoomControlsEnabled: false,
        myLocationButtonEnabled: false,
        scrollGesturesEnabled: false,
        zoomGesturesEnabled: false,
        tiltGesturesEnabled: false,
        rotateGesturesEnabled: false,
        onMapCreated: (gmaps.GoogleMapController controller) {
          if (routePoints.isNotEmpty) {
            Future.delayed(const Duration(milliseconds: 300), () {
              double minLat = routePoints.first.latitude;
              double maxLat = routePoints.first.latitude;
              double minLng = routePoints.first.longitude;
              double maxLng = routePoints.first.longitude;

              for (var p in routePoints) {
                if (p.latitude < minLat) minLat = p.latitude;
                if (p.latitude > maxLat) maxLat = p.latitude;
                if (p.longitude < minLng) minLng = p.longitude;
                if (p.longitude > maxLng) maxLng = p.longitude;
              }

              gmaps.LatLngBounds bounds = gmaps.LatLngBounds(
                southwest: gmaps.LatLng(minLat, minLng),
                northeast: gmaps.LatLng(maxLat, maxLng),
              );

              controller.animateCamera(
                gmaps.CameraUpdate.newLatLngBounds(bounds, 110.0),
              );
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    Widget bodyContent;

    if (_isLoading && _activities.isEmpty) {
      bodyContent = const ColoredBox(
        color: Color(0xFF0F1115),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFFC5200)),
        ),
      );
    } else if (_errorMessage != null && _activities.isEmpty) {
      bodyContent = ColoredBox(
        color: const Color(0xFF0F1115),
        child: Center(
          child: Text(_errorMessage!),
        ),
      );
    } else if (_activities.isEmpty) {
      bodyContent = ColoredBox(
        color: const Color(0xFF0F1115),
        child: Center(
          child: Text(strings.noActivities),
        ),
      );
    } else {
      bodyContent = ColoredBox(
        color: const Color(0xFF0F1115),
        child: RefreshIndicator(
          color: const Color(0xFFFC5200),
          onRefresh: () =>
              _cargarActividades(showSpinnerIfEmpty: false, clearCacheFirst: true),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _activities.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFC5200), Color(0xFFFF8C00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.heroGreeting,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            strings.heroSubtitle,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      const Icon(
                        Icons.local_fire_department,
                        color: Colors.white,
                        size: 38,
                      ),
                    ],
                  ),
                );
              }

              final act = _activities[index - 1] as Map<String, dynamic>;
              final title = _cleanTitle(
                act['title'] ?? strings.defaultActivityTitle,
              );
              final distance = act['distance_km']?.toString() ?? '0';

              final double rawAscent = (act['ascent_m'] ?? 0).toDouble();
              final ascent = rawAscent.toStringAsFixed(0);

              final speed = act['avg_speed_kmh']?.toString() ?? '0';

              final String athleteName =
                  act['athlete_name'] ?? strings.defaultAthleteName;
              final String? avatarUrl = act['avatar_url'];
              final String locationName =
                  act['location'] ?? strings.defaultLocation;
              final String formattedDate =
                  strings.formatActivityDate(act['start_time']);

              final String? encodedPolyline = act['route_polyline'];
              List<gmaps.LatLng> routePoints = [];
              if (encodedPolyline != null && encodedPolyline.isNotEmpty) {
                routePoints = _decodePolyline(encodedPolyline);
              }

              final Set<gmaps.Polyline> polylines = {
                if (routePoints.isNotEmpty)
                  gmaps.Polyline(
                    polylineId: gmaps.PolylineId('route_${act['id'] ?? index}'),
                    points: routePoints,
                    color: const Color(0xFFFC5200),
                    width: 4,
                  ),
              };

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  final bool? refreshNeeded = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ActivityDetailScreen(
                          activity: act, routePoints: routePoints),
                    ),
                  );

                  if (refreshNeeded == true) {
                    _cargarActividades(
                        showSpinnerIfEmpty: true, clearCacheFirst: true);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1D24),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: const Color(0xFF252A34),
                              backgroundImage:
                                  avatarUrl != null && avatarUrl.isNotEmpty
                                      ? NetworkImage(avatarUrl)
                                      : null,
                              child: (avatarUrl == null || avatarUrl.isEmpty)
                                  ? const Icon(Icons.person,
                                      color: Color(0xFFFC5200), size: 24)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    athleteName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    formattedDate,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on,
                                          size: 12, color: Color(0xFFFC5200)),
                                      const SizedBox(width: 3),
                                      Text(
                                        locationName,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios,
                                size: 14, color: Colors.grey),
                          ],
                        ),
                      ),
                      AbsorbPointer(
                        child: _buildMapOrPlaceholder(
                            routePoints, polylines, 340),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildMetricWithIcon(Icons.straighten,
                                    strings.distance, distance, 'km'),
                                _buildMetricWithIcon(
                                    Icons.terrain, strings.ascent, ascent, 'm'),
                                _buildMetricWithIcon(Icons.speed,
                                    strings.avgSpeed, speed, 'km/h'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.directions_bike, color: Color(0xFFFC5200)),
            SizedBox(width: 10),
            Text(
              'TeamTracker',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A1D24),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.directions_bike,
              color: Color(0xFFFC5200),
              size: 26,
            ),
            tooltip: strings.openCoospoRide,
            onPressed: () => _abrirCoospoRide(strings),
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined,
                color: Color(0xFFFC5200), size: 26),
            tooltip: strings.importGpxFit,
            onPressed: () async {
              final bool imported = await GpxFitImporter.importFile(context);
              if (imported) {
                _cargarActividades(
                    showSpinnerIfEmpty: true, clearCacheFirst: true);
              }
            },
          ),
        ],
      ),
      body: bodyContent,
    );
  }

  Widget _buildMetricWithIcon(
      IconData icon, String label, String value, String unit) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFFC5200)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}