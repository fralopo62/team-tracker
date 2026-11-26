import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'activity_detail_header.dart';
import 'activity_detail_map.dart';
import 'activity_detail_photos.dart';
import 'activity_detail_metrics.dart';

IconData _sportIconForShare(String? rawSport) {
  final s = (rawSport ?? '')
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ä', 'a')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u');

  if (s.contains('cicl') ||
      s.contains('bici') ||
      s.contains('mtb') ||
      s.contains('bike') ||
      s.contains('cycling') ||
      s.contains('radfahr')) {
    return Icons.directions_bike;
  }
  if (s.contains('run') ||
      s.contains('corr') ||
      s.contains('trail') ||
      s.contains('lauf')) {
    return Icons.directions_run;
  }
  if (s.contains('sender') ||
      s.contains('trek') ||
      s.contains('hik') ||
      s.contains('wander')) {
    return Icons.terrain;
  }
  if (s.contains('camin') ||
      s.contains('andar') ||
      s.contains('walk') ||
      s.contains('spazier')) {
    return Icons.directions_walk;
  }
  if (s.contains('natac') || s.contains('swim') || s.contains('schwimm')) {
    return Icons.pool;
  }
  if (s.contains('windsurf') || s.contains('surf')) {
    return Icons.surfing;
  }
  if (s.contains('remo') || s.contains('row') || s.contains('ruder')) {
    return Icons.rowing;
  }
  if (s.contains('eliptic') || s.contains('cross')) {
    return Icons.fitness_center;
  }
  if (s.contains('gimnas') || s.contains('gym') || s.contains('fitness')) {
    return Icons.sports_gymnastics;
  }

  return Icons.directions_bike;
}

class ActivityDetailScreen extends StatefulWidget {
  final Map activity;
  final List routePoints;

  const ActivityDetailScreen({
    super.key,
    required this.activity,
    required this.routePoints,
  });

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  late String _currentTitle;
  String? _currentSport;
  final GlobalKey<ActivityDetailMapState> _mapKey =
      GlobalKey<ActivityDetailMapState>();

  @override
  void initState() {
    super.initState();
    _currentTitle = _cleanTitle(widget.activity['title'] ?? 'Detalle de Ruta');
    _currentSport = _resolveSportType();
  }

  String _cleanTitle(String rawTitle) {
    if (rawTitle.contains('[') && rawTitle.contains(']')) {
      final startIndex = rawTitle.indexOf('[');
      return rawTitle.substring(0, startIndex).trim();
    }
    return rawTitle.trim();
  }

  String? _resolveSportType() {
    final raw = widget.activity['sport'] ??
        widget.activity['sport_type'] ??
        widget.activity['activity_type'] ??
        widget.activity['type'] ??
        widget.activity['deporte'];
    return raw?.toString();
  }

  Future<File?> _generateShareCardImage() async {
    final snap = await _mapKey.currentState?.captureMapSnapshot();
    if (snap == null || snap.isEmpty) return null;

    final codec = await ui.instantiateImageCodec(
      snap,
      targetWidth: 1080,
    );
    final frame = await codec.getNextFrame();
    final ui.Image mapImage = frame.image;

    const double width = 1080;
    const double mapBoxHeight = 1180;
    const double footerHeight = 320;
    const double totalHeight = mapBoxHeight + footerHeight;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      const Rect.fromLTWH(0, 0, width, totalHeight),
    );

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, totalHeight),
      Paint()..color = const Color(0xFF1A1D24),
    );

    final double srcW = mapImage.width.toDouble();
    final double srcH = mapImage.height.toDouble();
    const double targetRatio = width / mapBoxHeight;
    final double srcRatio = srcW / srcH;

    late Rect srcRect;
    if (srcRatio > targetRatio) {
      final double cropW = srcH * targetRatio;
      final double offsetX = (srcW - cropW) / 2.0;
      srcRect = Rect.fromLTWH(offsetX, 0, cropW, srcH);
    } else {
      final double cropH = srcW / targetRatio;
      final double offsetY = (srcH - cropH) / 2.0;
      srcRect = Rect.fromLTWH(0, offsetY, srcW, cropH);
    }

    const dstRect = Rect.fromLTWH(0, 0, width, mapBoxHeight);
    canvas.drawImageRect(mapImage, srcRect, dstRect, Paint());

    canvas.drawRect(
      const Rect.fromLTWH(0, mapBoxHeight, width, 4),
      Paint()..color = const Color(0xFFFC5200),
    );

    // Icono del deporte junto al título
    final sportType = _currentSport ?? _resolveSportType();
    final IconData sportIcon = _sportIconForShare(sportType);
    const double iconSize = 54;
    const double iconGap = 16;

    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(sportIcon.codePoint),
        style: TextStyle(
          fontFamily: sportIcon.fontFamily,
          package: sportIcon.fontPackage,
          fontSize: iconSize,
          color: const Color(0xFFFC5200),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double titleMaxWidth = width - 72 - iconSize - iconGap;

    final titlePainter = TextPainter(
      text: TextSpan(
        text: _currentTitle,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 58,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: titleMaxWidth);

    final double headerTop = mapBoxHeight + 34;
    iconPainter.paint(
      canvas,
      Offset(36, headerTop + ((titlePainter.height - iconPainter.height) / 2)),
    );
    titlePainter.paint(
      canvas,
      Offset(36 + iconSize + iconGap, headerTop),
    );

    final double distanceKm = (widget.activity['distance_km'] ?? 0).toDouble();
    final double ascentM = (widget.activity['ascent_m'] ?? 0).toDouble();
    final double avgSpeed = (widget.activity['avg_speed_kmh'] ?? 0).toDouble();

    final stats = [
      (
        'Distancia',
        '${distanceKm.toStringAsFixed(2)} km',
        const Color(0xFFFFAB40),
      ),
      (
        'Desnivel',
        '${ascentM.toStringAsFixed(0)} m',
        const Color(0xFF64FFDA),
      ),
      (
        'Vel. Media',
        '${avgSpeed.toStringAsFixed(1)} km/h',
        const Color(0xFF69F0AE),
      ),
    ];

    final double colWidth = (width - 72) / 3;
    for (int i = 0; i < stats.length; i++) {
      final (label, value, color) = stats[i];
      final double x = 36 + (i * colWidth);
      const double y = mapBoxHeight + 124;

      final labelPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 34,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: colWidth - 10);
      labelPainter.paint(canvas, Offset(x, y));

      final valuePainter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            color: color,
            fontSize: 52,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: colWidth - 10);
      valuePainter.paint(canvas, Offset(x, y + 48));
    }

    final ui.Picture picture = recorder.endRecording();
    final ui.Image finalImage =
        await picture.toImage(width.toInt(), totalHeight.toInt());
    final ByteData? pngBytes =
        await finalImage.toByteData(format: ui.ImageByteFormat.png);
    if (pngBytes == null) return null;

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/teamtracker_share_ruta.png');
    await file.writeAsBytes(pngBytes.buffer.asUint8List());
    return file;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final String athleteName =
        widget.activity['athlete_name'] ?? strings.defaultAthleteName;
    final String? avatarUrl = widget.activity['avatar_url'];
    final String locationName =
        widget.activity['location'] ?? strings.defaultLocation;
    final storedPhotos = widget.activity['photos'];
    final List initialPhotos = storedPhotos is List ? storedPhotos : [];
    final String? activityId = widget.activity['id']?.toString();
    final String? sportType = _currentSport ?? _resolveSportType();

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, true);
        return false;
      },
      child: Scaffold(
        appBar: ActivityDetailAppBar(
          activity: widget.activity,
          currentTitle: _currentTitle,
          onTitleUpdated: (newTitle) {
            setState(() {
              _currentTitle = newTitle;
            });
          },
          onSportUpdated: (newSport) {
            setState(() {
              _currentSport = newSport;
            });
          },
          onDeleted: () {
            Navigator.of(context).pop(true);
          },
          onGenerateShareImage: _generateShareCardImage,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ActivityAthleteHeaderCard(
              athleteName: athleteName,
              avatarUrl: avatarUrl,
              locationName: locationName,
            ),
            ActivityDetailMap(
              key: _mapKey,
              routePoints: widget.routePoints,
            ),
            const SizedBox(height: 20),
            ActivityDetailPhotos(
              activityId: widget.activity['id'],
              initialPhotos: initialPhotos,
            ),
            const SizedBox(height: 20),
            ActivityDetailMetrics(activity: widget.activity),
            if (activityId != null) ...[
              const SizedBox(height: 20),
              _KmSplitsSection(
                key: ValueKey('$activityId-$sportType'),
                activityId: activityId,
                sportType: sportType,
                activity: widget.activity,
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

int _calculateStepsFromSpeed(double distanceKm, double speedKmh) {
  if (distanceKm <= 0 || speedKmh <= 0) return 0;
  final double stepsPerKm;
  if (speedKmh < 4.5) {
    stepsPerKm = 1450.0;
  } else if (speedKmh <= 6.0) {
    stepsPerKm = 1300.0;
  } else {
    stepsPerKm = 1150.0;
  }
  return (distanceKm * stepsPerKm).round();
}

String _formatPaceFromSecondsPerKm(double paceSecPerKm) {
  if (paceSecPerKm <= 0 || paceSecPerKm.isInfinite || paceSecPerKm.isNaN) {
    return '--:-- /km';
  }
  final totalSec = paceSecPerKm.round();
  final mins = totalSec ~/ 60;
  final secs = totalSec % 60;
  return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')} /km';
}

String _formatDurationSeconds(int totalSec) {
  if (totalSec <= 0) return '--:--';
  final hours = totalSec ~/ 3600;
  final mins = (totalSec % 3600) ~/ 60;
  final secs = totalSec % 60;
  if (hours > 0) {
    return '$hours:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
  return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
}

double _haversineMeters(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const double earthRadius = 6371000.0;
  final double dLat = (lat2 - lat1) * math.pi / 180.0;
  final double dLon = (lon2 - lon1) * math.pi / 180.0;
  final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180.0) *
          math.cos(lat2 * math.pi / 180.0) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadius * c;
}

class _KmSplit {
  final int kmNumber;
  final double distanceMeters;
  final Duration duration;
  final double? avgElevationMeters;

  const _KmSplit({
    required this.kmNumber,
    required this.distanceMeters,
    required this.duration,
    this.avgElevationMeters,
  });

  double get distanceKm => distanceMeters / 1000.0;

  double get speedKmh {
    final seconds = duration.inMilliseconds / 1000.0;
    if (seconds <= 0 || distanceKm <= 0) return 0;
    return distanceKm / (seconds / 3600.0);
  }

  int get steps => _calculateStepsFromSpeed(distanceKm, speedKmh);

  double get paceSecondsPerKm {
    if (distanceMeters <= 0) return 0;
    return duration.inMilliseconds / 1000.0 / (distanceMeters / 1000.0);
  }

  String get formattedPace => _formatPaceFromSecondsPerKm(paceSecondsPerKm);

  String get formattedDuration => _formatDurationSeconds(duration.inSeconds);
}

class _TrackSample {
  final double movingSec;
  final double distanceM;
  final double? elevationM;

  _TrackSample({
    required this.movingSec,
    required this.distanceM,
    this.elevationM,
  });
}

class _KmSplitsSection extends StatelessWidget {
  final String activityId;
  final String? sportType;
  final Map activity;

  const _KmSplitsSection({
    super.key,
    required this.activityId,
    required this.sportType,
    required this.activity,
  });

  static bool _isWalkingOrHiking(String? sportType) {
    if (sportType == null) return false;
    final normalized = sportType
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');

    return normalized.contains('camin') ||
        normalized.contains('sender') ||
        normalized.contains('trek') ||
        normalized.contains('andar') ||
        normalized.contains('pie') ||
        normalized.contains('walk') ||
        normalized.contains('hik') ||
        normalized.contains('wander');
  }

  static List<_KmSplit> _normalizeSplitsToActivity(
    List<_KmSplit> rawSplits,
    Map activity,
  ) {
    if (rawSplits.isEmpty) return const [];

    final double officialDistKm =
        ((activity['distance_km'] ?? activity['distance'] ?? 0) as num)
            .toDouble();
    final double officialDistM = officialDistKm > 0
        ? (officialDistKm > 100 ? officialDistKm : officialDistKm * 1000.0)
        : 0.0;
    final double officialMovingSec =
        ((activity['moving_seconds'] ?? 0) as num).toDouble();

    final trimmed = <_KmSplit>[];
    if (officialDistM > 0) {
      double remainingDist = officialDistM;
      for (int i = 0; i < rawSplits.length; i++) {
        if (remainingDist <= 5.0) break;
        final s = rawSplits[i];
        if (s.distanceMeters <= remainingDist + 5.0) {
          trimmed.add(
            _KmSplit(
              kmNumber: i + 1,
              distanceMeters: s.distanceMeters,
              duration: s.duration,
              avgElevationMeters: s.avgElevationMeters,
            ),
          );
          remainingDist -= s.distanceMeters;
        } else {
          final ratio = (remainingDist / s.distanceMeters).clamp(0.05, 1.0);
          final scaledMs = (s.duration.inMilliseconds * ratio).round();
          trimmed.add(
            _KmSplit(
              kmNumber: i + 1,
              distanceMeters: remainingDist,
              duration: Duration(milliseconds: scaledMs),
              avgElevationMeters: s.avgElevationMeters,
            ),
          );
          remainingDist = 0;
          break;
        }
      }
    } else {
      trimmed.addAll(rawSplits);
    }

    if (trimmed.isEmpty) return const [];

    final paces = trimmed
        .where((s) => s.paceSecondsPerKm > 0)
        .map((s) => s.paceSecondsPerKm)
        .toList()
      ..sort();

    if (paces.isEmpty) return trimmed;

    final double medianPace = paces[paces.length ~/ 2];
    final cleanedDurationsSec = <double>[];

    for (final s in trimmed) {
      double sec = s.duration.inMilliseconds / 1000.0;
      if (s.paceSecondsPerKm > medianPace * 1.6 && s.distanceKm > 0) {
        sec = medianPace * s.distanceKm;
      }
      cleanedDurationsSec.add(sec);
    }

    final double sumCleanedSec =
        cleanedDurationsSec.fold<double>(0.0, (a, b) => a + b);
    final double timeScale = (officialMovingSec > 0 && sumCleanedSec > 0)
        ? (officialMovingSec / sumCleanedSec)
        : 1.0;

    final result = <_KmSplit>[];
    for (int i = 0; i < trimmed.length; i++) {
      final s = trimmed[i];
      final adjustedMs = (cleanedDurationsSec[i] * timeScale * 1000.0).round();
      result.add(
        _KmSplit(
          kmNumber: s.kmNumber,
          distanceMeters: s.distanceMeters,
          duration: Duration(milliseconds: adjustedMs > 0 ? adjustedMs : 1000),
          avgElevationMeters: s.avgElevationMeters,
        ),
      );
    }

    return result;
  }

  static List<_KmSplit> _parseSplitsFromActivityColumn(Map activity) {
    final rawSplits = activity['splits'];
    if (rawSplits == null) return const [];

    dynamic decoded = rawSplits;
    if (rawSplits is String) {
      final trimmed = rawSplits.trim();
      if (trimmed.isEmpty || trimmed == '[]') return const [];
      try {
        decoded = jsonDecode(trimmed);
      } catch (_) {
        return const [];
      }
    }

    if (decoded is! List || decoded.isEmpty) return const [];

    final totalDistKm =
        ((activity['distance_km'] ?? activity['distance'] ?? 0) as num)
            .toDouble();
    final totalMovingSec =
        ((activity['moving_seconds'] ?? activity['total_seconds'] ?? 0) as num)
            .toInt();
    final avgSpeedKmh =
        ((activity['avg_speed_kmh'] ?? activity['avg_speed'] ?? 0) as num)
            .toDouble();

    final fallbackPaceSecPerKm = (totalDistKm > 0 && totalMovingSec > 0)
        ? totalMovingSec / totalDistKm
        : (avgSpeedKmh > 0 ? 3600.0 / avgSpeedKmh : 0.0);

    final result = <_KmSplit>[];
    for (int i = 0; i < decoded.length; i++) {
      final item = decoded[i];
      if (item is! Map) continue;

      final kmNum =
          ((item['km'] ?? item['km_number'] ?? (i + 1)) as num).toInt();
      final distKmItem =
          ((item['distance_km'] ?? item['km_distance'] ?? 1.0) as num)
              .toDouble();
      final distMeters = (distKmItem > 0 ? distKmItem : 1.0) * 1000.0;

      final secRaw =
          item['duration_seconds'] ?? item['moving_seconds'] ?? item['seconds'];
      int secs = secRaw is num ? secRaw.toInt() : 0;

      if (secs <= 0 && item['pace_seconds_per_km'] is num) {
        secs = ((item['pace_seconds_per_km'] as num).toDouble() *
                (distMeters / 1000.0))
            .round();
      }
      if (secs <= 0 && fallbackPaceSecPerKm > 0) {
        secs = (fallbackPaceSecPerKm * (distMeters / 1000.0)).round();
      }

      if (secs > 0) {
        result.add(
          _KmSplit(
            kmNumber: kmNum > 0 ? kmNum : i + 1,
            distanceMeters: distMeters,
            duration: Duration(seconds: secs),
          ),
        );
      }
    }

    return _normalizeSplitsToActivity(result, activity);
  }

  static Future<List<_KmSplit>> _fetchSplits({
    required String activityId,
    required String? sportType,
    required Map activity,
    bool includePartialLastKm = true,
  }) async {
    if (!_isWalkingOrHiking(sportType)) {
      return const [];
    }

    final rows = <dynamic>[];
    const int pageSize = 1000;
    int page = 0;

    while (true) {
      final int from = page * pageSize;
      final int to = from + pageSize - 1;

      final List<dynamic> batch = await Supabase.instance.client
          .from('activity_trackpoints')
          .select(
              'timestamp, distance_from_start, elevation, latitude, longitude')
          .eq('activity_id', activityId)
          .order('timestamp', ascending: true)
          .range(from, to);

      rows.addAll(batch);

      if (batch.length < pageSize) {
        break;
      }
      page++;
    }

    final parsedRows =<Map<String,dynamic>>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final rawTs = row['timestamp'];
      if (rawTs == null) continue;
      final parsedTime = DateTime.tryParse(rawTs.toString());
      if (parsedTime == null) continue;

      parsedRows.add({
        'time': parsedTime.toUtc(),
        'dist': (row['distance_from_start'] as num?)?.toDouble(),
        'elev': (row['elevation'] as num?)?.toDouble(),
        'lat': (row['latitude'] as num?)?.toDouble(),
        'lng': (row['longitude'] as num?)?.toDouble(),
      });
    }

    if (parsedRows.length >= 2) {
      parsedRows.sort(
        (a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime),
      );

      final bool hasStoredDist = parsedRows.any((r) {
        final d = r['dist'] as double?;
        return d != null && !d.isNaN && d > 0;
      });

      final rawDistances = <double>[];
      double cumulativeMeters = 0.0;
      double? prevLat;
      double? prevLng;

      for (final r in parsedRows) {
        final lat = r['lat'] as double?;
        final lng = r['lng'] as double?;
        double distM;
        if (hasStoredDist && r['dist'] != null && !(r['dist'] as double).isNaN) {
          distM = r['dist'] as double;
        } else {
          if (lat != null && lng != null && prevLat != null && prevLng != null) {
            cumulativeMeters += _haversineMeters(prevLat, prevLng, lat, lng);
          }
          distM = cumulativeMeters;
        }
        if (lat != null && lng != null) {
          prevLat = lat;
          prevLng = lng;
        }
        rawDistances.add(distM);
      }

      final double rawStartDist = rawDistances.first;
      final double rawTotalDist = rawDistances.last - rawStartDist;

      if (rawTotalDist > 0) {
        final rawMovingTimes = <double>[0.0];
        double accMovingSec = 0.0;

        for (int i = 1; i < parsedRows.length; i++) {
          final prevTime = parsedRows[i - 1]['time'] as DateTime;
          final currTime = parsedRows[i]['time'] as DateTime;
          final double dtSec =
              currTime.difference(prevTime).inMilliseconds / 1000.0;
          final double ddMeters = (rawDistances[i] - rawDistances[i - 1]).abs();

          if (dtSec > 0) {
            final double speedMs = ddMeters / dtSec;
            if (!(dtSec > 20.0 && speedMs < 0.35) &&
                !(speedMs < 0.25 && ddMeters < 1.5)) {
              accMovingSec += dtSec;
            }
          }
          rawMovingTimes.add(accMovingSec);
        }

        final samples = <_TrackSample>[];
        for (int i = 0; i < parsedRows.length; i++) {
          samples.add(
            _TrackSample(
              movingSec: rawMovingTimes[i],
              distanceM: rawDistances[i] - rawStartDist,
              elevationM: parsedRows[i]['elev'] as double?,
            ),
          );
        }

        final double totalMeters = samples.last.distanceM;
        if (totalMeters > 0) {
          final splits = <_KmSplit>[];
          int nextKmIndex = 1;
          double targetDist = 1000.0;
          double splitStartSec = 0.0;
          double splitStartDist = 0.0;

          for (int i = 1; i < samples.length; i++) {
            final prev = samples[i - 1];
            final curr = samples[i];

            while (curr.distanceM >= targetDist) {
              final spanDist = curr.distanceM - prev.distanceM;
              final ratio = spanDist > 0
                  ? ((targetDist - prev.distanceM) / spanDist).clamp(0.0, 1.0)
                  : 0.0;
              final spanSec = curr.movingSec - prev.movingSec;
              final crossingSec = prev.movingSec + (spanSec * ratio);

              splits.add(
                _KmSplit(
                  kmNumber: nextKmIndex,
                  distanceMeters: 1000.0,
                  duration: Duration(
                    milliseconds:
                        ((crossingSec - splitStartSec) * 1000).round(),
                  ),
                  avgElevationMeters:
                      _averageElevation(samples, splitStartDist, targetDist),
                ),
              );

              nextKmIndex++;
              targetDist = nextKmIndex * 1000.0;
              splitStartSec = crossingSec;
              splitStartDist = targetDist - 1000.0;
            }
          }

          final endSample = samples.last;
          final remainingMeters = endSample.distanceM - splitStartDist;
          if (includePartialLastKm && remainingMeters >= 20.0) {
            final remSec = endSample.movingSec - splitStartSec;
            if (remSec > 0) {
              splits.add(
                _KmSplit(
                  kmNumber: nextKmIndex,
                  distanceMeters: remainingMeters,
                  duration: Duration(milliseconds: (remSec * 1000).round()),
                  avgElevationMeters: _averageElevation(
                    samples,
                    splitStartDist,
                    endSample.distanceM,
                  ),
                ),
              );
            }
          }

          if (splits.isNotEmpty) {
            return _normalizeSplitsToActivity(splits, activity);
          }
        }
      }
    }

    return _parseSplitsFromActivityColumn(activity);
  }

  static double? _averageElevation(
    List<_TrackSample> samples,
    double fromDist,
    double toDist,
  ) {
    final values = samples
        .where((s) =>
            s.distanceM >= fromDist &&
            s.distanceM <= toDist &&
            s.elevationM != null)
        .map((s) => s.elevationM!)
        .toList();
    if (values.isEmpty) return null;
    final sum = values.reduce((a, b) => a + b);
    return sum / values.length;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isWalkingOrHiking(sportType)) {
      return const SizedBox.shrink();
    }

    final strings = AppStrings.of(context);

    return FutureBuilder<List<_KmSplit>>(
      future: _fetchSplits(
        activityId: activityId,
        sportType: sportType,
        activity: activity,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFFFC5200)),
            ),
          );
        }

        final splits = snapshot.data ?? const [];
        if (splits.isEmpty) {
          return const SizedBox.shrink();
        }

        final totalSteps =
            splits.fold<int>(0, (acc, split) => acc + split.steps);

        final sectionTitle =
            strings.isGerman ? 'Kilometer-Tempo' : 'Paso por kilómetro';
        final timeLabel = strings.isGerman ? 'Zeit' : 'Tiempo';
        final stepsLabel = strings.isGerman ? 'Schritte' : 'Pasos';

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D24),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sectionTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ...splits.map((split) {
                final isPartial = split.distanceMeters < 995.0;
                final kmPartLabel =
                    (split.distanceMeters / 1000).toStringAsFixed(2);
                final labelKm = isPartial
                    ? (strings.isGerman
                        ? 'Reststrecke ($kmPartLabel km)'
                        : 'Tramo final ($kmPartLabel km)')
                    : 'Km ${split.kmNumber}';

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.06),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              labelKm,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$timeLabel: ${split.formattedDuration} · $stepsLabel: ${split.steps}',
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        split.formattedPace,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFC5200),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    stepsLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '$totalSteps',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFC5200),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}