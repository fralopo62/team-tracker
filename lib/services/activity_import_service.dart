import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xml/xml.dart' as xml;

class TrackPoint {
  final double lat;
  final double lng;
  final double? altitude;
  final DateTime? time;
  final double? speedMs;
  final double? distanceM;

  TrackPoint({
    required this.lat,
    required this.lng,
    this.altitude,
    this.time,
    this.speedMs,
    this.distanceM,
  });
}

class ParsedActivity {
  final String title;
  final String sport;
  final DateTime startTime;
  final int movingSeconds;
  final int totalSeconds;
  final double distanceKm;
  final double ascentM;
  final double maxAltitudeM;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final double maxGradePercentage;
  final String encodedPolyline;
  final String fileHash;
  final String location;
  final List<TrackPoint> points;

  ParsedActivity({
    required this.title,
    required this.sport,
    required this.startTime,
    required this.movingSeconds,
    required this.totalSeconds,
    required this.distanceKm,
    required this.ascentM,
    required this.maxAltitudeM,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.maxGradePercentage,
    required this.encodedPolyline,
    required this.fileHash,
    required this.location,
    required this.points,
  });
}

class _FitFieldDef {
  final int fieldDefNum;
  final int size;
  final int baseType;

  _FitFieldDef({
    required this.fieldDefNum,
    required this.size,
    required this.baseType,
  });
}

class _FitMessageDef {
  final int globalMessageNum;
  final bool isBigEndian;
  final List<_FitFieldDef> fields;
  final int developerDataSize;

  _FitMessageDef({
    required this.globalMessageNum,
    required this.isBigEndian,
    required this.fields,
    required this.developerDataSize,
  });
}

class _FitSessionSummary {
  DateTime? startTime;
  double? totalElapsedSeconds;
  double? totalTimerSeconds;
  double? totalDistanceMeters;
  double? totalAscentMeters;
  double? avgSpeedMs;
  double? maxSpeedMs;
  double? maxAltitudeMeters;
}

class ActivityImportService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Epoch oficial del protocolo FIT: 1989-12-31T00:00:00Z
  static final DateTime _fitEpochUtc = DateTime.utc(1989, 12, 31, 0, 0, 0);

  // Valores inválidos estándar en el protocolo FIT
  static const int _invalidUint8 = 0xFF;
  static const int _invalidUint16 = 0xFFFF;
  static const int _invalidUint32 = 0xFFFFFFFF;
  static const int _invalidSint32 = 0x7FFFFFFF;

  Future<ParsedActivity?> parseFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint('El archivo no existe en: $filePath');
      return null;
    }

    final bytes = await file.readAsBytes();
    final fileHash = _computeSimpleHash(bytes);

    final lowerPath = filePath.toLowerCase();
    if (lowerPath.endsWith('.gpx')) {
      return _parseGpx(utf8.decode(bytes), file, fileHash);
    } else if (lowerPath.endsWith('.fit')) {
      return _parseFit(bytes, file, fileHash);
    } else {
      debugPrint('Formato de archivo no soportado: $filePath');
      return null;
    }
  }

  String _computeSimpleHash(Uint8List bytes) {
    int hash = 0xcbf29ce484222325;
    const int prime = 0x100000001b3;
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * prime) & 0x7fffffffffffffff;
    }
    return '${bytes.length}_${hash.toRadixString(16)}';
  }

  Future<ParsedActivity?> _parseGpx(
    String content,
    File file,
    String fileHash,
  ) async {
    final document = xml.XmlDocument.parse(content);

    final trackPoints = <TrackPoint>[];
    for (final trkpt in document.findAllElements('trkpt')) {
      final latStr = trkpt.getAttribute('lat');
      final lonStr = trkpt.getAttribute('lon');
      if (latStr == null || lonStr == null) continue;

      final lat = double.tryParse(latStr);
      final lng = double.tryParse(lonStr);
      if (lat == null || lng == null) continue;

      double? alt;
      final eleEl = trkpt.findElements('ele').firstOrNull;
      if (eleEl != null) {
        alt = double.tryParse(eleEl.innerText.trim());
      }

      DateTime? time;
      final timeEl = trkpt.findElements('time').firstOrNull;
      if (timeEl != null) {
        time = DateTime.tryParse(timeEl.innerText.trim());
      }

      trackPoints.add(
        TrackPoint(lat: lat, lng: lng, altitude: alt, time: time),
      );
    }

    if (trackPoints.isEmpty) return null;

    final nameEl = document.findAllElements('name').firstOrNull;
    final defaultTitle = file.uri.pathSegments.last
        .replaceAll(RegExp(r'\.gpx$', caseSensitive: false), '');
    final title = (nameEl != null && nameEl.innerText.trim().isNotEmpty)
        ? nameEl.innerText.trim()
        : defaultTitle;

    return _buildParsedActivity(
      title: title,
      sport: 'Ciclismo',
      fileHash: fileHash,
      points: trackPoints,
    );
  }

  Future<ParsedActivity?> _parseFit(
    Uint8List bytes,
    File file,
    String fileHash,
  ) async {
    final fileName = file.uri.pathSegments.last
        .replaceAll(RegExp(r'\.fit$', caseSensitive: false), '');
    final fallbackTitle = 'Coospo $fileName';

    if (bytes.length < 14) {
      debugPrint('Archivo FIT demasiado corto (${bytes.length} bytes).');
      return _fallbackFitActivity(fallbackTitle, fileHash);
    }

    final headerSize = bytes[0];
    if (bytes.length < headerSize) {
      debugPrint('Cabecera FIT incompleta: headerSize=$headerSize');
      return _fallbackFitActivity(fallbackTitle, fileHash);
    }

    final view = ByteData.sublistView(bytes);
    final dataSize = view.getUint32(4, Endian.little);

    if (headerSize >= 12) {
      final sig = String.fromCharCodes(bytes.sublist(8, 12));
      if (sig != '.FIT') {
        debugPrint('Firma FIT inesperada: "$sig"');
      }
    }

    final dataStart = headerSize;
    final dataEnd = min(bytes.length, dataStart + dataSize);

    final localDefs = <int, _FitMessageDef>{};
    final trackPoints = <TrackPoint>[];
    final sessionSummary = _FitSessionSummary();
    int? lastTimestampSec;

    int offset = dataStart;
    while (offset < dataEnd) {
      final recordHeader = bytes[offset];
      offset += 1;

      // Compressed Timestamp Header (bit 7 == 1)
      if ((recordHeader & 0x80) != 0) {
        final localMsgType = (recordHeader >> 5) & 0x03;
        final timeOffset = recordHeader & 0x1F;
        final def = localDefs[localMsgType];
        if (def == null) {
          debugPrint('Mensaje FIT comprimido sin definición previa (local=$localMsgType)');
          break;
        }

        int? resolvedTimestamp;
        final prevTs = lastTimestampSec;
        if (prevTs != null) {
          final prevOffset = prevTs & 0x1F;
          final delta = (timeOffset - prevOffset) & 0x1F;
          resolvedTimestamp = prevTs + delta;
          lastTimestampSec = resolvedTimestamp;
        }

        final parsedFields = _readFitDataFields(
          bytes: bytes,
          offset: offset,
          def: def,
          overrideTimestampSec: resolvedTimestamp,
        );
        offset += parsedFields.bytesConsumed;

        _consumeFitMessage(
          globalMsgNum: def.globalMessageNum,
          fields: parsedFields.values,
          points: trackPoints,
          session: sessionSummary,
          onTimestamp: (ts) => lastTimestampSec = ts,
        );
        continue;
      }

      final isDefinition = (recordHeader & 0x40) != 0;
      final hasDeveloperData = (recordHeader & 0x20) != 0;
      final localMsgType = recordHeader & 0x0F;

      if (isDefinition) {
        if (offset + 5 > dataEnd) break;

        offset += 1; // reserved byte
        final archByte = bytes[offset];
        offset += 1;
        final isBigEndian = archByte == 1;
        final endian = isBigEndian ? Endian.big : Endian.little;

        final globalMsgNum = view.getUint16(offset, endian);
        offset += 2;

        final numFields = bytes[offset];
        offset += 1;

        if (offset + (numFields * 3) > dataEnd) break;

        final fieldDefs = <_FitFieldDef>[];
        for (int i = 0; i < numFields; i++) {
          final fieldDefNum = bytes[offset];
          final size = bytes[offset + 1];
          final baseType = bytes[offset + 2];
          offset += 3;

          fieldDefs.add(
            _FitFieldDef(
              fieldDefNum: fieldDefNum,
              size: size,
              baseType: baseType,
            ),
          );
        }

        int devDataSize = 0;
        if (hasDeveloperData) {
          if (offset >= dataEnd) break;
          final numDevFields = bytes[offset];
          offset += 1;

          if (offset + (numDevFields * 3) > dataEnd) break;
          for (int i = 0; i < numDevFields; i++) {
            final devFieldSize = bytes[offset + 1];
            devDataSize += devFieldSize;
            offset += 3;
          }
        }

        localDefs[localMsgType] = _FitMessageDef(
          globalMessageNum: globalMsgNum,
          isBigEndian: isBigEndian,
          fields: fieldDefs,
          developerDataSize: devDataSize,
        );
      } else {
        final def = localDefs[localMsgType];
        if (def == null) {
          debugPrint('Mensaje de datos FIT sin definición previa (local=$localMsgType) en offset $offset');
          break;
        }

        final parsedFields = _readFitDataFields(
          bytes: bytes,
          offset: offset,
          def: def,
          overrideTimestampSec: null,
        );
        offset += parsedFields.bytesConsumed;

        if (offset > dataEnd) break;

        _consumeFitMessage(
          globalMsgNum: def.globalMessageNum,
          fields: parsedFields.values,
          points: trackPoints,
          session: sessionSummary,
          onTimestamp: (ts) => lastTimestampSec = ts,
        );
      }
    }

    debugPrint(
      'FIT decodificado ($fileName): ${trackPoints.length} puntos GPS/record, '
      'sessionDistance=${sessionSummary.totalDistanceMeters}, '
      'sessionAscent=${sessionSummary.totalAscentMeters}',
    );

    if (trackPoints.isEmpty) {
      return _buildFromSessionOrFallback(
        title: fallbackTitle,
        fileHash: fileHash,
        session: sessionSummary,
      );
    }

    return _buildParsedActivity(
      title: fallbackTitle,
      sport: 'Ciclismo',
      fileHash: fileHash,
      points: trackPoints,
      overrideStartTime: sessionSummary.startTime,
      overrideTotalSeconds: sessionSummary.totalElapsedSeconds?.round(),
      overrideMovingSeconds: sessionSummary.totalTimerSeconds?.round(),
      overrideDistanceKm: sessionSummary.totalDistanceMeters != null
          ? double.parse((sessionSummary.totalDistanceMeters! / 1000.0).toStringAsFixed(2))
          : null,
      overrideAscentM: sessionSummary.totalAscentMeters != null
          ? double.parse(sessionSummary.totalAscentMeters!.toStringAsFixed(1))
          : null,
      overrideAvgSpeedKmh: sessionSummary.avgSpeedMs != null
          ? double.parse((sessionSummary.avgSpeedMs! * 3.6).toStringAsFixed(1))
          : null,
      overrideMaxSpeedKmh: sessionSummary.maxSpeedMs != null
          ? double.parse((sessionSummary.maxSpeedMs! * 3.6).toStringAsFixed(1))
          : null,
      overrideMaxAltitudeM: sessionSummary.maxAltitudeMeters != null
          ? double.parse(sessionSummary.maxAltitudeMeters!.toStringAsFixed(1))
          : null,
    );
  }

  ({Map<int, List<int>> values, int bytesConsumed}) _readFitDataFields({
    required Uint8List bytes,
    required int offset,
    required _FitMessageDef def,
    required int? overrideTimestampSec,
  }) {
    final endian = def.isBigEndian ? Endian.big : Endian.little;
    final values = <int, List<int>>{};
    int cursor = offset;

    for (final f in def.fields) {
      if (cursor + f.size > bytes.length) {
        cursor = bytes.length;
        break;
      }

      final baseTypeNum = f.baseType & 0x1F;
      final typeSize = _fitBaseTypeSize(baseTypeNum);

      if (typeSize > 0 && f.size >= typeSize && f.size % typeSize == 0) {
        final count = f.size ~/ typeSize;
        final extracted = <int>[];
        for (int i = 0; i < count; i++) {
          final itemOffset = cursor + (i * typeSize);
          final raw = _readRawInt(bytes, itemOffset, typeSize, baseTypeNum, endian);
          if (raw != null) {
            extracted.add(raw);
          }
        }
        if (extracted.isNotEmpty) {
          values[f.fieldDefNum] = extracted;
        }
      }

      cursor += f.size;
    }

    if (overrideTimestampSec != null) {
      values[253] = [overrideTimestampSec];
    }

    cursor += def.developerDataSize;
    return (values: values, bytesConsumed: cursor - offset);
  }

  int _fitBaseTypeSize(int baseTypeNum) {
    switch (baseTypeNum) {
      case 0:
      case 1:
      case 2:
      case 7:
      case 10:
        return 1;
      case 3:
      case 4:
      case 11:
        return 2;
      case 5:
      case 6:
      case 8:
      case 12:
        return 4;
      case 9:
      case 14:
      case 15:
      case 16:
        return 8;
      default:
        return 0;
    }
  }

  int? _readRawInt(
    Uint8List bytes,
    int offset,
    int size,
    int baseTypeNum,
    Endian endian,
  ) {
    final view = ByteData.sublistView(bytes);
    switch (baseTypeNum) {
      case 0:
      case 2:
      case 10:
        final v = view.getUint8(offset);
        return v == _invalidUint8 ? null : v;
      case 1:
        final v = view.getInt8(offset);
        return v == 0x7F ? null : v;
      case 3:
        final v = view.getInt16(offset, endian);
        return v == 0x7FFF ? null : v;
      case 4:
      case 11:
        final v = view.getUint16(offset, endian);
        return v == _invalidUint16 ? null : v;
      case 5:
        final v = view.getInt32(offset, endian);
        return v == _invalidSint32 ? null : v;
      case 6:
      case 12:
        final v = view.getUint32(offset, endian);
        return v == _invalidUint32 ? null : v;
      case 8:
        final f = view.getFloat32(offset, endian);
        if (f.isNaN || f.isInfinite) return null;
        return (f * 1000).round();
      default:
        return null;
    }
  }

  void _consumeFitMessage({
    required int globalMsgNum,
    required Map<int, List<int>> fields,
    required List<TrackPoint> points,
    required _FitSessionSummary session,
    required void Function(int timestampSec) onTimestamp,
  }) {
    int? firstInt(int fieldNum) {
      final list = fields[fieldNum];
      if (list == null || list.isEmpty) return null;
      return list.first;
    }

    final tsRaw = firstInt(253);
    if (tsRaw != null && tsRaw > 0) {
      onTimestamp(tsRaw);
    }

    if (globalMsgNum == 20) {
      final latRaw = firstInt(0);
      final lonRaw = firstInt(1);
      final distRaw = firstInt(5);
      final altRaw = firstInt(2);
      final speedRaw = firstInt(6);

      final DateTime? pointTime =
          (tsRaw != null && tsRaw > 0) ? _fitEpochUtc.add(Duration(seconds: tsRaw)).toLocal() : null;

      final double? altitudeM =
          (altRaw != null && altRaw != _invalidUint16) ? (altRaw / 5.0) - 500.0 : null;

      final double? speedMs =
          (speedRaw != null && speedRaw != _invalidUint16) ? (speedRaw / 1000.0) : null;

      final double? distanceM =
          (distRaw != null && distRaw != _invalidUint32) ? (distRaw / 100.0) : null;

      if (latRaw != null && lonRaw != null && latRaw != _invalidSint32 && lonRaw != _invalidSint32) {
        final lat = latRaw * (180.0 / 2147483648.0);
        final lng = lonRaw * (180.0 / 2147483648.0);

        if (lat.abs() <= 90.0 && lng.abs() <= 180.0 && !(lat == 0.0 && lng == 0.0)) {
          points.add(
            TrackPoint(
              lat: lat,
              lng: lng,
              altitude: altitudeM,
              time: pointTime,
              speedMs: speedMs,
              distanceM: distanceM,
            ),
          );
        }
      }
    }

    if (globalMsgNum == 18) {
      final startTimeRaw = firstInt(2);
      final elapsedRaw = firstInt(7);
      final timerRaw = firstInt(8);
      final distRaw = firstInt(9);
      final ascentRaw = firstInt(22);
      final avgSpeedRaw = firstInt(14);
      final maxSpeedRaw = firstInt(15);
      final maxAltRaw = firstInt(71);

      if (startTimeRaw != null && startTimeRaw > 0) {
        session.startTime = _fitEpochUtc.add(Duration(seconds: startTimeRaw)).toLocal();
      }
      if (elapsedRaw != null && elapsedRaw > 0) {
        session.totalElapsedSeconds = elapsedRaw / 1000.0;
      }
      if (timerRaw != null && timerRaw > 0) {
        session.totalTimerSeconds = timerRaw / 1000.0;
      }
      if (distRaw != null && distRaw > 0) {
        session.totalDistanceMeters = distRaw / 100.0;
      }
      if (ascentRaw != null && ascentRaw >= 0 && ascentRaw != _invalidUint16) {
        session.totalAscentMeters = ascentRaw.toDouble();
      }
      if (avgSpeedRaw != null && avgSpeedRaw > 0) {
        session.avgSpeedMs = avgSpeedRaw / 1000.0;
      }
      if (maxSpeedRaw != null && maxSpeedRaw > 0) {
        session.maxSpeedMs = maxSpeedRaw / 1000.0;
      }
      if (maxAltRaw != null && maxAltRaw != _invalidUint16) {
        session.maxAltitudeMeters = (maxAltRaw / 5.0) - 500.0;
      }
    }
  }

  ParsedActivity _buildFromSessionOrFallback({
    required String title,
    required String fileHash,
    required _FitSessionSummary session,
  }) {
    final totalSecs = session.totalElapsedSeconds?.round() ?? 0;
    final movingSecs = session.totalTimerSeconds?.round() ?? totalSecs;
    final distKm = session.totalDistanceMeters != null
        ? double.parse((session.totalDistanceMeters! / 1000.0).toStringAsFixed(2))
        : 0.0;
    final ascentM = session.totalAscentMeters != null
        ? double.parse(session.totalAscentMeters!.toStringAsFixed(1))
        : 0.0;
    final avgSpeed = session.avgSpeedMs != null
        ? double.parse((session.avgSpeedMs! * 3.6).toStringAsFixed(1))
        : 0.0;
    final maxSpeed = session.maxSpeedMs != null
        ? double.parse((session.maxSpeedMs! * 3.6).toStringAsFixed(1))
        : 0.0;
    final maxAlt = session.maxAltitudeMeters != null
        ? double.parse(session.maxAltitudeMeters!.toStringAsFixed(1))
        : 0.0;

    return ParsedActivity(
      title: title,
      sport: 'Ciclismo',
      startTime: session.startTime ?? DateTime.now(),
      movingSeconds: movingSecs,
      totalSeconds: totalSecs,
      distanceKm: distKm,
      ascentM: ascentM,
      maxAltitudeM: maxAlt,
      avgSpeedKmh: avgSpeed,
      maxSpeedKmh: maxSpeed,
      maxGradePercentage: 0.0,
      encodedPolyline: '',
      fileHash: fileHash,
      location: 'Brenes, Sevilla',
      points: const [],
    );
  }

  ParsedActivity _fallbackFitActivity(String title, String fileHash) {
    return ParsedActivity(
      title: title,
      sport: 'Ciclismo',
      startTime: DateTime.now(),
      movingSeconds: 0,
      totalSeconds: 0,
      distanceKm: 0.0,
      ascentM: 0.0,
      maxAltitudeM: 0.0,
      avgSpeedKmh: 0.0,
      maxSpeedKmh: 0.0,
      maxGradePercentage: 0.0,
      encodedPolyline: '',
      fileHash: fileHash,
      location: 'Brenes, Sevilla',
      points: const [],
    );
  }

  ParsedActivity _buildParsedActivity({
    required String title,
    required String sport,
    required String fileHash,
    required List<TrackPoint> points,
    DateTime? overrideStartTime,
    int? overrideTotalSeconds,
    int? overrideMovingSeconds,
    double? overrideDistanceKm,
    double? overrideAscentM,
    double? overrideAvgSpeedKmh,
    double? overrideMaxSpeedKmh,
    double? overrideMaxAltitudeM,
  }) {
    double totalMeters = 0.0;
    double ascentMeters = 0.0;
    double maxAltitude = points.first.altitude ?? 0.0;
    double maxSpeed = 0.0;
    double maxGrade = 0.0;
    int movingSecs = 0;

    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];

      final segMeters = _haversineMeters(prev.lat, prev.lng, curr.lat, curr.lng);
      totalMeters += segMeters;

      if (curr.altitude != null && curr.altitude! > maxAltitude) {
        maxAltitude = curr.altitude!;
      }

      double? elevDiff;
      if (prev.altitude != null && curr.altitude != null) {
        elevDiff = curr.altitude! - prev.altitude!;
        if (elevDiff > 0) {
          ascentMeters += elevDiff;
        }
      }

      if (prev.time != null && curr.time != null) {
        final dt = curr.time!.difference(prev.time!).inSeconds;
        if (dt > 0) {
          final speedKmh = (segMeters / dt) * 3.6;
          if (speedKmh > 0.5) {
            movingSecs += dt;
          }
          if (speedKmh > maxSpeed && speedKmh < 120) {
            maxSpeed = speedKmh;
          }
        }
      }

      if (curr.speedMs != null) {
        final recordSpeedKmh = curr.speedMs! * 3.6;
        if (recordSpeedKmh > maxSpeed && recordSpeedKmh < 120) {
          maxSpeed = recordSpeedKmh;
        }
      }

      if (elevDiff != null && segMeters > 1.0) {
        final grade = (elevDiff / segMeters) * 100.0;
        if (grade > maxGrade && grade < 60) {
          maxGrade = grade;
        }
      }
    }

    final start = overrideStartTime ?? points.first.time ?? DateTime.now();
    final end = points.last.time ?? start;
    final computedTotalSecs = max(movingSecs, end.difference(start).inSeconds);
    final totalSecs = (overrideTotalSeconds != null && overrideTotalSeconds > 0)
        ? overrideTotalSeconds
        : computedTotalSecs;
    final computedMovingSecs = movingSecs > 0 ? movingSecs : totalSecs;
    final movingSecsFinal = (overrideMovingSeconds != null && overrideMovingSeconds > 0)
        ? overrideMovingSeconds
        : computedMovingSecs;

    final distanceKmFinal = (overrideDistanceKm != null && overrideDistanceKm > 0)
        ? overrideDistanceKm
        : double.parse((totalMeters / 1000.0).toStringAsFixed(2));

    final ascentMFinal = (overrideAscentM != null && overrideAscentM > 0)
        ? overrideAscentM
        : double.parse(ascentMeters.toStringAsFixed(1));

    final effectiveSecs = movingSecsFinal > 0 ? movingSecsFinal : totalSecs;
    final computedAvgSpeed =
        effectiveSecs > 0 ? ((distanceKmFinal * 1000.0) / effectiveSecs) * 3.6 : 0.0;
    final avgSpeedFinal = (overrideAvgSpeedKmh != null && overrideAvgSpeedKmh > 0)
        ? overrideAvgSpeedKmh
        : double.parse(computedAvgSpeed.toStringAsFixed(1));

    final maxSpeedFinal = (overrideMaxSpeedKmh != null && overrideMaxSpeedKmh > 0)
        ? overrideMaxSpeedKmh
        : double.parse(maxSpeed.toStringAsFixed(1));

    final maxAltitudeFinal = (overrideMaxAltitudeM != null && overrideMaxAltitudeM != 0)
        ? overrideMaxAltitudeM
        : double.parse(maxAltitude.toStringAsFixed(1));

    final polyline = _encodePolyline(points);

    return ParsedActivity(
      title: title,
      sport: sport,
      startTime: start,
      movingSeconds: movingSecsFinal,
      totalSeconds: totalSecs,
      distanceKm: distanceKmFinal,
      ascentM: ascentMFinal,
      maxAltitudeM: maxAltitudeFinal,
      avgSpeedKmh: avgSpeedFinal,
      maxSpeedKmh: maxSpeedFinal,
      maxGradePercentage: double.parse(maxGrade.toStringAsFixed(2)),
      encodedPolyline: polyline,
      fileHash: fileHash,
      location: 'Brenes, Sevilla',
      points: points,
    );
  }

  double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = pow(sin(dLat / 2), 2) +
        cos(_degToRad(lat1)) * cos(_degToRad(lat2)) * pow(sin(dLon / 2), 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degToRad(double deg) => deg * (pi / 180.0);

  String _encodePolyline(List<TrackPoint> points) {
    if (points.isEmpty) return '';
    final StringBuffer result = StringBuffer();
    int prevLat = 0;
    int prevLng = 0;

    for (final pt in points) {
      final int lat = (pt.lat * 1e5).round();
      final int lng = (pt.lng * 1e5).round();

      _encodeValue(lat - prevLat, result);
      _encodeValue(lng - prevLng, result);

      prevLat = lat;
      prevLng = lng;
    }
    return result.toString();
  }

  void _encodeValue(int value, StringBuffer result) {
    int num = value < 0 ? ~(value << 1) : (value << 1);
    while (num >= 0x20) {
      result.writeCharCode((0x20 | (num & 0x1f)) + 63);
      num >>= 5;
    }
    result.writeCharCode(num + 63);
  }

  Future<bool> uploadToSupabase(ParsedActivity activity) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      debugPrint('No hay usuario autenticado en Supabase para subir la actividad.');
      return false;
    }

    try {
      await _supabase.from('activities').insert({
        'user_id': user.id,
        'title': activity.title,
        'sport': activity.sport,
        'distance_km': activity.distanceKm,
        'ascent_m': activity.ascentM,
        'max_altitude_m': activity.maxAltitudeM,
        'avg_speed_kmh': activity.avgSpeedKmh,
        'max_speed_kmh': activity.maxSpeedKmh,
        'max_grade_percentage': activity.maxGradePercentage,
        'moving_seconds': activity.movingSeconds,
        'total_seconds': activity.totalSeconds,
        'route_polyline': activity.encodedPolyline,
        'start_time': activity.startTime.toIso8601String(),
        'location': activity.location,
        'photos': <String>[],
        'file_hash': activity.fileHash,
        'splits': [],
      });
      debugPrint('Actividad subida a Supabase: ${activity.title}');
      return true;
    } catch (e) {
      debugPrint('Error subiendo actividad a Supabase: $e');
      return false;
    }
  }
}