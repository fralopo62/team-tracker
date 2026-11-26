import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'activity_detail_screen.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  String _selectedSport = 'Todos';
  late Future<List<dynamic>> _routesFuture;

  final List<String> _sportFilters = [
    'Todos',
    'Ciclismo',
    'Running',
    'Caminata',
    'Senderismo',
    'Windsurf',
    'Natación',
    'Remo',
    'Elíptica',
    'Gimnasio',
  ];

  @override
  void initState() {
    super.initState();
    _fetchRoutes();
  }

  void _fetchRoutes() {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;

    if (currentUser != null) {
      setState(() {
        _routesFuture = supabase
            .from('activities')
            .select('*')
            .eq('user_id', currentUser.id)
            .order('start_time', ascending: false);
      });
    } else {
      setState(() {
        _routesFuture = Future.value([]);
      });
    }
  }

  String _normalizeText(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
  }

  bool _matchesSportFilter(String rawSport, String selectedFilter) {
    if (selectedFilter == 'Todos') return true;

    final String sport = _normalizeText(rawSport);
    final String filter = _normalizeText(selectedFilter);

    if (filter == 'caminata' || filter == 'caminar') {
      return sport.contains('camin') ||
          sport.contains('andar') ||
          sport.contains('walk');
    }
    if (filter == 'senderismo') {
      return sport.contains('sender') ||
          sport.contains('trek') ||
          sport.contains('hik');
    }
    if (filter == 'ciclismo') {
      return sport.contains('cicl') ||
          sport.contains('bici') ||
          sport.contains('mtb') ||
          sport.contains('bike') ||
          sport.contains('cycling');
    }
    if (filter == 'running') {
      return sport.contains('run') ||
          sport.contains('corr') ||
          sport.contains('trail');
    }
    if (filter == 'natacion') {
      return sport.contains('natac') || sport.contains('swim');
    }

    return sport.contains(filter);
  }

  String _filterDisplayLabel(String filterKey, AppStrings strings) {
    if (filterKey == 'Todos') return strings.filterAll;
    return strings.sportLabel(filterKey);
  }

  List<gmaps.LatLng> _decodePolyline(String encoded) {
    final List<gmaps.LatLng> points = <gmaps.LatLng>[];
    int index = 0;
    final int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(gmaps.LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  String _cleanTitle(String rawTitle, String fallbackTitle) {
    final cleaned = rawTitle.contains('[') && rawTitle.contains(']')
        ? rawTitle.substring(0, rawTitle.indexOf('[')).trim()
        : rawTitle.trim();
    return cleaned.isEmpty ? fallbackTitle : cleaned;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        title: Text(
          strings.routesAndMapsTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1A1D24),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 10),
            color: const Color(0xFF1A1D24),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _sportFilters.length,
              itemBuilder: (context, index) {
                final sportKey = _sportFilters[index];
                final isSelected = sportKey == _selectedSport;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_filterDisplayLabel(sportKey, strings)),
                    selected: isSelected,
                    selectedColor: const Color(0xFFFC5200),
                    backgroundColor: const Color(0xFF252A34),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFFFC5200)
                            : Colors.white10,
                      ),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _selectedSport = sportKey;
                      });
                    },
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _routesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFC5200)),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      strings.routesLoadError(snapshot.error!),
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final allRoutes = snapshot.data ?? [];

                final filteredRoutes = allRoutes.where((route) {
                  final String sport =
                      (route['sport'] ?? 'Ciclismo').toString();
                  return _matchesSportFilter(sport, _selectedSport);
                }).toList();

                if (filteredRoutes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.map_outlined,
                          size: 60,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          strings.noRoutesForSport(
                            _filterDisplayLabel(_selectedSport, strings),
                          ),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredRoutes.length,
                  itemBuilder: (context, index) {
                    final route = filteredRoutes[index] as Map<String, dynamic>;
                    final String title = _cleanTitle(
                      (route['title'] ?? '').toString(),
                      strings.noTitleRoute,
                    );
                    final double distance =
                        (route['distance_km'] ?? 0).toDouble();
                    final double ascent = (route['ascent_m'] ?? 0).toDouble();
                    final String sportKey =
                        (route['sport'] ?? 'Ciclismo').toString();

                    final String? encodedPolyline = route['route_polyline'];
                    List<gmaps.LatLng> routePoints = [];
                    if (encodedPolyline != null && encodedPolyline.isNotEmpty) {
                      routePoints = _decodePolyline(encodedPolyline);
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1D24),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () async {
                          final bool? refreshNeeded =
                              await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ActivityDetailScreen(
                                activity: route,
                                routePoints: routePoints,
                              ),
                            ),
                          );
                          if (refreshNeeded == true) {
                            _fetchRoutes();
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.route,
                                          color: Color(0xFFFC5200),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFC5200)
                                          .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      strings.sportLabel(sportKey),
                                      style: const TextStyle(
                                        color: Color(0xFFFC5200),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _RouteThumbnailCard(routePoints: routePoints),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  Text(
                                    strings.routeDistanceLabel(
                                      distance.toStringAsFixed(1),
                                    ),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    strings.routeAscentLabel(
                                      ascent.toStringAsFixed(0),
                                    ),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Miniatura ligera de la ruta sin cargar GoogleMap en la lista
class _RouteThumbnailCard extends StatelessWidget {
  final List<gmaps.LatLng> routePoints;

  const _RouteThumbnailCard({
    required this.routePoints,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Container(
      height: 170,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF12151B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RouteThumbnailPainter(
                points: routePoints,
                emptyLabel: strings.noGpsTrack,
              ),
            ),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.open_in_full,
                    size: 13,
                    color: Color(0xFFFC5200),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    strings.viewMap,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteThumbnailPainter extends CustomPainter {
  final List<gmaps.LatLng> points;
  final String emptyLabel;

  _RouteThumbnailPainter({
    required this.points,
    required this.emptyLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.035)
      ..strokeWidth = 1;

    const double step = 28.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (points.length < 2) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: emptyLabel,
          style: const TextStyle(color: Colors.white38, fontSize: 13),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(
          (size.width - textPainter.width) / 2,
          (size.height - textPainter.height) / 2,
        ),
      );
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final double midLatRad = ((minLat + maxLat) * 0.5) * math.pi / 180.0;
    final double lngScale = math.cos(midLatRad).abs().clamp(0.2, 1.0);

    final double spanX = math.max((maxLng - minLng) * lngScale, 1e-6);
    final double spanY = math.max(maxLat - minLat, 1e-6);

    const double padX = 24.0;
    const double padY = 20.0;
    final double drawW = math.max(size.width - padX * 2, 10.0);
    final double drawH = math.max(size.height - padY * 2, 10.0);

    final double scale = math.min(drawW / spanX, drawH / spanY);
    final double usedW = spanX * scale;
    final double usedH = spanY * scale;
    final double offsetX = padX + (drawW - usedW) * 0.5;
    final double offsetY = padY + (drawH - usedH) * 0.5;

    Offset toOffset(gmaps.LatLng p) {
      final double dx = offsetX + ((p.longitude - minLng) * lngScale) * scale;
      final double dy = offsetY + (maxLat - p.latitude) * scale;
      return Offset(dx, dy);
    }

    final path = Path();
    final firstOffset = toOffset(points.first);
    path.moveTo(firstOffset.dx, firstOffset.dy);
    for (int i = 1; i < points.length; i++) {
      final pt = toOffset(points[i]);
      path.lineTo(pt.dx, pt.dy);
    }

    final glowPaint = Paint()
      ..color = const Color(0xFFFC5200).withOpacity(0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, glowPaint);

    final linePaint = Paint()
      ..color = const Color(0xFFFC5200)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    final startOffset = toOffset(points.first);
    canvas.drawCircle(
      startOffset,
      6.0,
      Paint()..color = const Color(0xFF12151B),
    );
    canvas.drawCircle(
      startOffset,
      4.2,
      Paint()..color = const Color(0xFF22C55E),
    );

    final endOffset = toOffset(points.last);
    canvas.drawCircle(
      endOffset,
      6.0,
      Paint()..color = const Color(0xFF12151B),
    );
    canvas.drawCircle(
      endOffset,
      4.2,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _RouteThumbnailPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.emptyLabel != emptyLabel;
  }
}