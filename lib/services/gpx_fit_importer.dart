import 'dart:convert';
import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xml/xml.dart' as xml;

class TrackPointData {
  final double lat;
  final double lon;
  final double? altitude;
  final double? distanceM;
  final double? speedMs;
  final int? heartRate;
  final int? cadence;
  final DateTime? timestamp;

  TrackPointData({
    required this.lat,
    required this.lon,
    this.altitude,
    this.distanceM,
    this.speedMs,
    this.heartRate,
    this.cadence,
    this.timestamp,
  });
}

class FitLapData {
  final double distanceKm;
  final int movingSeconds;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final double ascentM;
  final DateTime? startTime;

  FitLapData({
    required this.distanceKm,
    required this.movingSeconds,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.ascentM,
    this.startTime,
  });
}

class KmSplitData {
  final int km;
  final int movingSeconds;
  final double avgSpeedKmh;
  final double ascentM;
  final double descentM;

  KmSplitData({
    required this.km,
    required this.movingSeconds,
    required this.avgSpeedKmh,
    required this.ascentM,
    required this.descentM,
  });

  Map<String, dynamic> toJson() => {
        'km': km,
        'moving_seconds': movingSeconds,
        'avg_speed_kmh': double.parse(avgSpeedKmh.toStringAsFixed(1)),
        'ascent_m': ascentM.round(),
        'descent_m': descentM.round(),
      };
}

class ParsedActivity {
  final String sport;
  final DateTime startTime;
  final double distanceKm;
  final double ascentM;
  final double maxAltitudeM;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final double maxGradePercentage;
  final int movingSeconds;
  final int totalSeconds;
  final int? avgHeartRate;
  final int? maxHeartRate;
  final String routePolyline;
  final List<TrackPointData> points;
  final List<FitLapData> laps;
  final List<KmSplitData> splits;

  ParsedActivity({
    required this.sport,
    required this.startTime,
    required this.distanceKm,
    required this.ascentM,
    required this.maxAltitudeM,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.maxGradePercentage,
    required this.movingSeconds,
    required this.totalSeconds,
    this.avgHeartRate,
    this.maxHeartRate,
    required this.routePolyline,
    required this.points,
    required this.laps,
    required this.splits,
  });
}

class PolylineEncoder {
  static String encode(List<TrackPointData> points) {
    if (points.isEmpty) return '';
    final step = points.length > 1500 ? (points.length / 1500).ceil() : 1;
    final sb = StringBuffer();
    int lastLat = 0;
    int lastLng = 0;

    for (int i = 0; i < points.length; i += step) {
      final p = points[i];
      final lat = (p.lat * 1e5).round();
      final lng = (p.lon * 1e5).round();
      _encodeValue(lat - lastLat, sb);
      _encodeValue(lng - lastLng, sb);
      lastLat = lat;
      lastLng = lng;
    }
    return sb.toString();
  }

  static void _encodeValue(int value, StringBuffer sb) {
    int v = value < 0 ? ~(value << 1) : (value << 1);
    while (v >= 0x20) {
      sb.writeCharCode((0x20 | (v & 0x1f)) + 63);
      v >>= 5;
    }
    sb.writeCharCode(v + 63);
  }
}

class _FitFieldDef {
  final int fieldDefNum;
  final int size;
  final int baseType;
  _FitFieldDef(this.fieldDefNum, this.size, this.baseType);
}

class _FitMsgDef {
  final int globalMsgNum;
  final bool isBigEndian;
  final List<_FitFieldDef> fields;
  final int totalSize;
  _FitMsgDef(this.globalMsgNum, this.isBigEndian, this.fields, this.totalSize);
}

class RealFitParser {
  static const int _fitEpochOffsetSeconds = 631065600;

  static ParsedActivity parse(Uint8List bytes) {
    if (bytes.length < 14) {
      throw Exception('Archivo FIT demasiado pequeño o corrupto.');
    }

    final headerSize = bytes[0];
    final dataSize = ByteData.sublistView(bytes, 4, 8).getUint32(0, Endian.little);
    final endOffset = math.min(bytes.length, headerSize + dataSize);

    final definitions = <int, _FitMsgDef>{};
    final rawPoints = <TrackPointData>[];
    final laps = <FitLapData>[];

    double? sessionDistanceM;
    double? sessionAscentM;
    double? sessionAvgSpeedMs;
    double? sessionMaxSpeedMs;
    double? sessionMaxAltM;
    int? sessionTotalTimerTimeSec;
    int? sessionTotalElapsedTimeSec;
    int? sessionAvgHr;
    int? sessionMaxHr;
    int? sessionSportId;
    DateTime? sessionStartTime;

    int offset = headerSize;
    int lastTimestamp = 0;

    while (offset < endOffset) {
      final header = bytes[offset++];
      final isCompressedTimestamp = (header & 0x80) != 0;

      if (isCompressedTimestamp) {
        final localMsgType = (header >> 5) & 0x03;
        final timeOffset = header & 0x1F;
        lastTimestamp += (timeOffset - (lastTimestamp & 0x1F)) & 0x1F;

        final def = definitions[localMsgType];
        if (def == null || offset + def.totalSize > endOffset) break;

        final values = _readFields(bytes, offset, def);
        offset += def.totalSize;
        if (def.globalMsgNum == 20) {
          values[253] ??= lastTimestamp;
          _processRecord(values, rawPoints);
        }
        continue;
      }

      final isDefinition = (header & 0x40) != 0;
      final hasDevData = (header & 0x20) != 0;
      final localMsgType = header & 0x0F;

      if (isDefinition) {
        if (offset + 5 > endOffset) break;
        offset++;
        final arch = bytes[offset++];
        final isBigEndian = arch == 1;
        final globalMsgNum = ByteData.sublistView(bytes, offset, offset + 2)
            .getUint16(0, isBigEndian ? Endian.big : Endian.little);
        offset += 2;
        final numFields = bytes[offset++];

        final fields = <_FitFieldDef>[];
        int totalSize = 0;
        for (int i = 0; i < numFields; i++) {
          if (offset + 3 > endOffset) break;
          final fNum = bytes[offset++];
          final fSize = bytes[offset++];
          final fType = bytes[offset++];
          fields.add(_FitFieldDef(fNum, fSize, fType));
          totalSize += fSize;
        }

        if (hasDevData && offset < endOffset) {
          final numDevFields = bytes[offset++];
          for (int i = 0; i < numDevFields; i++) {
            if (offset + 3 > endOffset) break;
            offset++;
            final devSize = bytes[offset++];
            offset++;
            totalSize += devSize;
          }
        }

        definitions[localMsgType] =
            _FitMsgDef(globalMsgNum, isBigEndian, fields, totalSize);
      } else {
        final def = definitions[localMsgType];
        if (def == null || offset + def.totalSize > endOffset) break;

        final values = _readFields(bytes, offset, def);
        offset += def.totalSize;

        if (values.containsKey(253) && values[253] is int) {
          lastTimestamp = values[253] as int;
        }

        if (def.globalMsgNum == 20) {
          _processRecord(values, rawPoints);
        } else if (def.globalMsgNum == 19) {
          double lapDistM = 0;
          if (values[9] is num) lapDistM = (values[9] as num).toDouble();
          if (lapDistM > 10000) lapDistM = lapDistM / 100.0;

          int lapTimeSec = 0;
          if (values[7] is num) lapTimeSec = ((values[7] as num) / 1000.0).round();

          double lapAvgSpeed = 0;
          if (values[14] is num) lapAvgSpeed = ((values[14] as num) / 1000.0) * 3.6;

          double lapMaxSpeed = 0;
          if (values[15] is num) lapMaxSpeed = ((values[15] as num) / 1000.0) * 3.6;

          double lapAscent = 0;
          if (values[22] is num) lapAscent = (values[22] as num).toDouble();

          DateTime? lapStartTime;
          if (values[2] is int) {
            lapStartTime = DateTime.fromMillisecondsSinceEpoch(
              ((values[2] as int) + _fitEpochOffsetSeconds) * 1000,
              isUtc: true,
            ).toLocal();
          }

          if (lapDistM > 10) {
            laps.add(FitLapData(
              distanceKm: lapDistM / 1000.0,
              movingSeconds: lapTimeSec,
              avgSpeedKmh: lapAvgSpeed,
              maxSpeedKmh: lapMaxSpeed,
              ascentM: lapAscent,
              startTime: lapStartTime,
            ));
          }
        } else if (def.globalMsgNum == 18) {
          if (values[2] is int) {
            sessionStartTime = DateTime.fromMillisecondsSinceEpoch(
              ((values[2] as int) + _fitEpochOffsetSeconds) * 1000,
              isUtc: true,
            ).toLocal();
          }
          if (values[5] is int) sessionSportId = values[5] as int;
          if (values[7] is num) {
            sessionTotalElapsedTimeSec = ((values[7] as num) / 1000.0).round();
          }
          if (values[8] is num) {
            sessionTotalTimerTimeSec = ((values[8] as num) / 1000.0).round();
          }
          if (values[9] is num) {
            sessionDistanceM = (values[9] as num) / 100.0;
          }
          if (values[14] is num) {
            sessionAvgSpeedMs = (values[14] as num) / 1000.0;
          }
          if (values[15] is num) {
            sessionMaxSpeedMs = (values[15] as num) / 1000.0;
          }
          if (values[16] is int) sessionAvgHr = values[16] as int;
          if (values[17] is int) sessionMaxHr = values[17] as int;
          if (values[22] is num) {
            sessionAscentM = (values[22] as num).toDouble();
          }
          if (values[50] is num) {
            sessionMaxAltM = ((values[50] as num) / 5.0) - 500.0;
          }
          if (values[124] is num) {
            sessionAvgSpeedMs = (values[124] as num) / 1000.0;
          }
          if (values[125] is num) {
            sessionMaxSpeedMs = (values[125] as num) / 1000.0;
          }
          if (values[128] is num) {
            sessionMaxAltM = ((values[128] as num) / 5.0) - 500.0;
          }
        }
      }
    }

    rawPoints.sort((a, b) {
      if (a.timestamp == null || b.timestamp == null) return 0;
      return a.timestamp!.compareTo(b.timestamp!);
    });

    double accumDist = 0.0;
    final points = <TrackPointData>[];
    for (int i = 0; i < rawPoints.length; i++) {
      final p = rawPoints[i];
      if (i > 0) {
        final prev = points[i - 1];
        accumDist += _haversineMeters(prev.lat, prev.lon, p.lat, p.lon);
      }
      points.add(TrackPointData(
        lat: p.lat,
        lon: p.lon,
        altitude: p.altitude,
        distanceM: accumDist,
        speedMs: p.speedMs,
        heartRate: p.heartRate,
        cadence: p.cadence,
        timestamp: p.timestamp,
      ));
    }

    return _buildMetricsFromPointsAndSession(
      points: points,
      sport: _mapSport(sessionSportId),
      sessionStartTime: sessionStartTime,
      sessionDistanceM: sessionDistanceM,
      sessionAscentM: sessionAscentM,
      sessionAvgSpeedMs: sessionAvgSpeedMs,
      sessionMaxSpeedMs: sessionMaxSpeedMs,
      sessionMaxAltM: sessionMaxAltM,
      sessionMovingSec: sessionTotalTimerTimeSec,
      sessionTotalSec: sessionTotalElapsedTimeSec,
      sessionAvgHr: sessionAvgHr,
      sessionMaxHr: sessionMaxHr,
      parsedLaps: laps,
    );
  }

  static Map<int, dynamic> _readFields(
      Uint8List bytes, int startOffset, _FitMsgDef def) {
    final result = <int, dynamic>{};
    int pos = startOffset;
    final endian = def.isBigEndian ? Endian.big : Endian.little;

    for (final f in def.fields) {
      if (pos + f.size > bytes.length) break;
      final base = f.baseType & 0x1F;
      final view = ByteData.sublistView(bytes, pos, pos + f.size);

      dynamic val;
      if (base == 0 || base == 2 || base == 10 || base == 13) {
        if (f.size == 1) {
          final v = view.getUint8(0);
          if (v != 0xFF && !(base == 10 && v == 0)) val = v;
        }
      } else if (base == 1) {
        if (f.size == 1) {
          final v = view.getInt8(0);
          if (v != 0x7F) val = v;
        }
      } else if (base == 3) {
        if (f.size >= 2) {
          final v = view.getInt16(0, endian);
          if (v != 0x7FFF) val = v;
        }
      } else if (base == 4 || base == 11) {
        if (f.size >= 2) {
          final v = view.getUint16(0, endian);
          if (v != 0xFFFF && !(base == 11 && v == 0)) val = v;
        }
      } else if (base == 5) {
        if (f.size >= 4) {
          final v = view.getInt32(0, endian);
          if (v != 0x7FFFFFFF) val = v;
        }
      } else if (base == 6 || base == 12) {
        if (f.size >= 4) {
          final v = view.getUint32(0, endian);
          if (v != 0xFFFFFFFF && !(base == 12 && v == 0)) val = v;
        }
      } else if (base == 8) {
        if (f.size >= 4) {
          val = view.getFloat32(0, endian);
        }
      } else if (base == 9) {
        if (f.size >= 8) {
          val = view.getFloat64(0, endian);
        }
      }

      if (val != null) {
        result[f.fieldDefNum] = val;
      }
      pos += f.size;
    }
    return result;
  }

  static void _processRecord(
      Map<int, dynamic> values, List<TrackPointData> points) {
    final rawLat = values[0];
    final rawLon = values[1];
    if (rawLat is! int || rawLon is! int) return;

    final lat = rawLat * (180.0 / 2147483648.0);
    final lon = rawLon * (180.0 / 2147483648.0);
    if (lat < -90.0 || lat > 90.0 || lon < -180.0 || lon > 180.0) return;
    if (lat == 0.0 && lon == 0.0) return;

    double? alt;
    if (values[78] is num) {
      alt = ((values[78] as num) / 5.0) - 500.0;
    } else if (values[2] is num) {
      alt = ((values[2] as num) / 5.0) - 500.0;
    }

    double? speedMs;
    if (values[73] is num) {
      speedMs = (values[73] as num) / 1000.0;
    } else if (values[6] is num) {
      speedMs = (values[6] as num) / 1000.0;
    }

    int? hr = values[3] is int ? values[3] as int : null;
    int? cad = values[4] is int ? values[4] as int : null;

    DateTime? ts;
    if (values[253] is int) {
      ts = DateTime.fromMillisecondsSinceEpoch(
        ((values[253] as int) + _fitEpochOffsetSeconds) * 1000,
        isUtc: true,
      ).toLocal();
    }

    points.add(TrackPointData(
      lat: lat,
      lon: lon,
      altitude: alt,
      distanceM: 0.0,
      speedMs: speedMs,
      heartRate: hr,
      cadence: cad,
      timestamp: ts,
    ));
  }

  static String _mapSport(int? sportId) {
    switch (sportId) {
      case 1:
        return 'running';
      case 2:
        return 'ciclismo';
      case 11:
        return 'senderismo';
      default:
        return 'ciclismo';
    }
  }
}

class GpxParser {
  static ParsedActivity parse(String gpxString) {
    final document = xml.XmlDocument.parse(gpxString);
    final points = <TrackPointData>[];
    final trkpts = document.findAllElements('trkpt');

    double accumDist = 0.0;
    TrackPointData? prev;

    for (var node in trkpts) {
      final lat = double.tryParse(node.getAttribute('lat') ?? '');
      final lon = double.tryParse(node.getAttribute('lon') ?? '');
      if (lat == null || lon == null) continue;

      double? ele;
      final eleNode = node.findElements('ele').firstOrNull;
      if (eleNode != null) {
        ele = double.tryParse(eleNode.text.trim());
      }

      DateTime? time;
      final timeNode = node.findElements('time').firstOrNull;
      if (timeNode != null) {
        time = DateTime.tryParse(timeNode.text.trim())?.toLocal();
      }

      double? speedMs;
      if (prev != null) {
        final d = _haversineMeters(prev.lat, prev.lon, lat, lon);
        accumDist += d;
        if (time != null && prev.timestamp != null) {
          final dt = time.difference(prev.timestamp!).inMilliseconds / 1000.0;
          if (dt > 0) speedMs = d / dt;
        }
      }

      final pt = TrackPointData(
        lat: lat,
        lon: lon,
        altitude: ele,
        distanceM: accumDist,
        speedMs: speedMs,
        timestamp: time,
      );
      points.add(pt);
      prev = pt;
    }

    return _buildMetricsFromPointsAndSession(
      points: points,
      sport: 'ciclismo',
      parsedLaps: [],
    );
  }
}

double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180.0;
  final dLon = (lon2 - lon1) * math.pi / 180.0;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180.0) *
          math.cos(lat2 * math.pi / 180.0) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}

List<KmSplitData> _computePerKmSplits(List<TrackPointData> points) {
  if (points.length < 2) return [];

  final splits = <KmSplitData>[];
  int targetKm = 1;
  double splitStartDist = 0.0;
  DateTime? splitStartTime = points.first.timestamp;
  double splitAscent = 0.0;
  double splitDescent = 0.0;

  for (int i = 1; i < points.length; i++) {
    final prev = points[i - 1];
    final curr = points[i];
    final dPrev = prev.distanceM ?? 0.0;
    final dCurr = curr.distanceM ?? dPrev;

    if (prev.altitude != null && curr.altitude != null) {
      final diffAlt = curr.altitude! - prev.altitude!;
      if (diffAlt > 0.5) splitAscent += diffAlt;
      if (diffAlt < -0.5) splitDescent += diffAlt.abs();
    }

    while (dCurr >= targetKm * 1000.0) {
      final targetDist = targetKm * 1000.0;
      final segDist = dCurr - dPrev;
      final ratio = segDist > 0 ? (targetDist - dPrev) / segDist : 1.0;

      DateTime? crossTime = curr.timestamp;
      if (prev.timestamp != null && curr.timestamp != null) {
        final segMs = curr.timestamp!.difference(prev.timestamp!).inMilliseconds;
        crossTime = prev.timestamp!.add(Duration(milliseconds: (segMs * ratio).round()));
      }

      int sec = 0;
      if (splitStartTime != null && crossTime != null) {
        sec = crossTime.difference(splitStartTime).inSeconds;
      }
      final distKm = (targetDist - splitStartDist) / 1000.0;
      final speedKmh = sec > 0 ? (distKm / (sec / 3600.0)) : 0.0;

      splits.add(KmSplitData(
        km: targetKm,
        movingSeconds: sec,
        avgSpeedKmh: speedKmh,
        ascentM: splitAscent,
        descentM: splitDescent,
      ));

      splitStartDist = targetDist;
      splitStartTime = crossTime;
      splitAscent = 0.0;
      splitDescent = 0.0;
      targetKm++;
    }
  }

  final lastPt = points.last;
  final remDistM = (lastPt.distanceM ?? 0.0) - splitStartDist;
  if (remDistM > 50.0 && splitStartTime != null && lastPt.timestamp != null) {
    final sec = lastPt.timestamp!.difference(splitStartTime).inSeconds;
    final distKm = remDistM / 1000.0;
    final speedKmh = sec > 0 ? (distKm / (sec / 3600.0)) : 0.0;

    splits.add(KmSplitData(
      km: targetKm,
      movingSeconds: sec,
      avgSpeedKmh: speedKmh,
      ascentM: splitAscent,
      descentM: splitDescent,
    ));
  }

  return splits;
}

ParsedActivity _buildMetricsFromPointsAndSession({
  required List<TrackPointData> points,
  required String sport,
  required List<FitLapData> parsedLaps,
  DateTime? sessionStartTime,
  double? sessionDistanceM,
  double? sessionAscentM,
  double? sessionAvgSpeedMs,
  double? sessionMaxSpeedMs,
  double? sessionMaxAltM,
  int? sessionMovingSec,
  int? sessionTotalSec,
  int? sessionAvgHr,
  int? sessionMaxHr,
}) {
  double calcDistM = 0.0;
  double calcAscentM = 0.0;
  double maxAlt = -9999.0;
  double maxSpeedKmh = 0.0;
  double maxGrade = 0.0;
  int movingSeconds = 0;

  int hrSum = 0;
  int hrCount = 0;
  int maxHr = 0;

  double? lastSmoothedAlt;
  double lastAltDistM = 0.0;

  for (int i = 0; i < points.length; i++) {
    final p = points[i];

    if (p.altitude != null && p.altitude! > maxAlt) {
      maxAlt = p.altitude!;
    }

    if (p.speedMs != null) {
      final kmh = p.speedMs! * 3.6;
      if (kmh > maxSpeedKmh && kmh < 120.0) {
        maxSpeedKmh = kmh;
      }
    }

    if (p.heartRate != null && p.heartRate! > 0) {
      hrSum += p.heartRate!;
      hrCount++;
      if (p.heartRate! > maxHr) maxHr = p.heartRate!;
    }

    if (i > 0) {
      final prev = points[i - 1];
      final segDist = (p.distanceM != null && prev.distanceM != null && p.distanceM! >= prev.distanceM!)
          ? (p.distanceM! - prev.distanceM!)
          : _haversineMeters(prev.lat, prev.lon, p.lat, p.lon);

      calcDistM += segDist;

      if (p.timestamp != null && prev.timestamp != null) {
        final dt = p.timestamp!.difference(prev.timestamp!).inSeconds;
        if (dt > 0 && dt < 300) {
          final segSpeedKmh = (segDist / dt) * 3.6;
          if (segSpeedKmh > 1.5) {
            movingSeconds += dt;
          }
          if (p.speedMs == null && segSpeedKmh > maxSpeedKmh && segSpeedKmh < 120.0) {
            maxSpeedKmh = segSpeedKmh;
          }
        }
      }

      if (p.altitude != null) {
        if (lastSmoothedAlt == null) {
          lastSmoothedAlt = p.altitude!;
          lastAltDistM = calcDistM;
        } else {
          final distDelta = calcDistM - lastAltDistM;
          if (distDelta >= 15.0) {
            final altDelta = p.altitude! - lastSmoothedAlt;
            if (altDelta > 0.8) {
              calcAscentM += altDelta;
            }
            final grade = (altDelta / distDelta) * 100.0;
            if (grade > maxGrade && grade < 45.0) {
              maxGrade = grade;
            }
            lastSmoothedAlt = p.altitude!;
            lastAltDistM = calcDistM;
          }
        }
      }
    } else if (p.altitude != null) {
      lastSmoothedAlt = p.altitude!;
      lastAltDistM = 0.0;
    }
  }

  if (points.isNotEmpty && points.last.distanceM != null && points.last.distanceM! > 0) {
    calcDistM = points.last.distanceM!;
  }

  final double finalDistM;
  if (calcDistM > 10.0 && (sessionDistanceM == null || (calcDistM - sessionDistanceM).abs() > 500)) {
    finalDistM = calcDistM;
  } else {
    finalDistM = (sessionDistanceM != null && sessionDistanceM > 0) ? sessionDistanceM : calcDistM;
  }

  final finalDistKm = finalDistM / 1000.0;

  final finalAscentM = (sessionAscentM != null && sessionAscentM > 0) ? sessionAscentM : calcAscentM;
  final finalMaxAlt = (sessionMaxAltM != null && sessionMaxAltM > -500)
      ? sessionMaxAltM
      : (maxAlt > -9999.0 ? maxAlt : 0.0);

  DateTime startTime = sessionStartTime ??
      (points.isNotEmpty && points.first.timestamp != null ? points.first.timestamp! : DateTime.now());

  int totalSeconds = sessionTotalSec ?? 0;
  if (totalSeconds <= 0 &&
      points.length >= 2 &&
      points.first.timestamp != null &&
      points.last.timestamp != null) {
    totalSeconds = points.last.timestamp!.difference(points.first.timestamp!).inSeconds;
  }
  if (totalSeconds <= 0) totalSeconds = movingSeconds;

  final finalMovingSec = (sessionMovingSec != null && sessionMovingSec > 0)
      ? sessionMovingSec
      : (movingSeconds > 0 ? movingSeconds : totalSeconds);

  double avgSpeedKmh = 0.0;
  if (sessionAvgSpeedMs != null && sessionAvgSpeedMs > 0) {
    avgSpeedKmh = sessionAvgSpeedMs * 3.6;
  } else if (finalMovingSec > 0 && finalDistKm > 0) {
    avgSpeedKmh = finalDistKm / (finalMovingSec / 3600.0);
  }

  final finalMaxSpeedKmh = (sessionMaxSpeedMs != null && sessionMaxSpeedMs > 0)
      ? sessionMaxSpeedMs * 3.6
      : maxSpeedKmh;

  final finalAvgHr = sessionAvgHr ?? (hrCount > 0 ? (hrSum / hrCount).round() : null);
  final finalMaxHr = sessionMaxHr ?? (maxHr > 0 ? maxHr : null);

  final computedSplits = _computePerKmSplits(points);

  return ParsedActivity(
    sport: sport,
    startTime: startTime,
    distanceKm: finalDistKm,
    ascentM: finalAscentM,
    maxAltitudeM: finalMaxAlt,
    avgSpeedKmh: avgSpeedKmh,
    maxSpeedKmh: finalMaxSpeedKmh,
    maxGradePercentage: maxGrade,
    movingSeconds: finalMovingSec,
    totalSeconds: totalSeconds,
    avgHeartRate: finalAvgHr,
    maxHeartRate: finalMaxHr,
    routePolyline: PolylineEncoder.encode(points),
    points: points,
    laps: parsedLaps,
    splits: computedSplits,
  );
}

class GpxFitImporter {
  static String _computeFileHash(Uint8List bytes) {
    int hash = 2166136261;
    for (int i = 0; i < bytes.length; i++) {
      hash ^= bytes[i];
      hash = (hash * 16777619) & 0xFFFFFFFF;
    }
    return '${bytes.length}_${hash.toRadixString(16)}';
  }

  static Future<bool> importFile(BuildContext context) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gpx', 'fit'],
      );

      if (files == null || files.isEmpty) return false;

      final pickedFile = files.single;
      final String fileName = pickedFile.name;
      Uint8List? fileBytes;

      if (pickedFile.path != null) {
        fileBytes = await io.File(pickedFile.path!).readAsBytes();
      } else {
        fileBytes = await pickedFile.xFile.readAsBytes();
      }

      if (fileBytes == null) return false;

      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;
      final fileHash = _computeFileHash(fileBytes);

      try {
        final existingByHash = await supabase
            .from('activities')
            .select('id, title')
            .eq('user_id', userId)
            .eq('file_hash', fileHash)
            .limit(1);

        if (existingByHash.isNotEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Este archivo ya estaba importado ("${existingByHash.first['title']}").',
                ),
                backgroundColor: Colors.orange.shade800,
              ),
            );
          }
          return false;
        }
      } catch (_) {}

      ParsedActivity parsed;
      final lowerName = fileName.toLowerCase();

      if (lowerName.endsWith('.gpx')) {
        final content = utf8.decode(fileBytes, allowMalformed: true);
        parsed = GpxParser.parse(content);
      } else if (lowerName.endsWith('.fit')) {
        parsed = RealFitParser.parse(fileBytes);
      } else {
        return false;
      }

      if (parsed.points.isEmpty && parsed.distanceKm <= 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se encontraron puntos GPS ni métricas válidas en el archivo.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return false;
      }

      final roundedDist = double.parse(parsed.distanceKm.toStringAsFixed(2));
      
      try {
        final existingBySession = await supabase
            .from('activities')
            .select('id, title')
            .eq('user_id', userId)
            .eq('start_time', parsed.startTime.toIso8601String())
            .eq('distance_km', roundedDist)
            .limit(1);

        if (existingBySession.isNotEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Actividad duplicada: ya existe "${existingBySession.first['title']}" con la misma fecha y distancia.',
                ),
                backgroundColor: Colors.orange.shade800,
              ),
            );
          }
          return false;
        }
      } catch (_) {}

      final activityData = {
        'user_id': userId,
        'title': fileName.replaceAll(RegExp(r'\.(fit|gpx)$', caseSensitive: false), ''),
        'sport': parsed.sport,
        'distance_km': roundedDist,
        'ascent_m': double.parse(parsed.ascentM.toStringAsFixed(0)),
        'max_altitude_m': double.parse(parsed.maxAltitudeM.toStringAsFixed(1)),
        'avg_speed_kmh': double.parse(parsed.avgSpeedKmh.toStringAsFixed(1)),
        'max_speed_kmh': double.parse(parsed.maxSpeedKmh.toStringAsFixed(1)),
        'max_grade_percentage': double.parse(parsed.maxGradePercentage.toStringAsFixed(1)),
        'moving_seconds': parsed.movingSeconds,
        'total_seconds': parsed.totalSeconds,
        'route_polyline': parsed.routePolyline,
        'start_time': parsed.startTime.toIso8601String(),
        'file_hash': fileHash,
        'splits': parsed.splits.map((s) => s.toJson()).toList(), // <-- Parciales precalculados por kilómetro
        if (parsed.avgHeartRate != null) 'avg_heart_rate': parsed.avgHeartRate,
        if (parsed.maxHeartRate != null) 'max_heart_rate': parsed.maxHeartRate,
      };

      final inserted = await supabase
          .from('activities')
          .insert(activityData)
          .select('id')
          .single();

      final activityId = inserted['id'];

      // Opcional: Ya no necesitamos saturar 'activity_trackpoints' con miles de filas. 
      // Puedes omitir la inserción de trackpoints o dejarla solo si usas el mapa interactivo avanzado.

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Ruta importada! ${parsed.distanceKm.toStringAsFixed(2)} km • ${parsed.ascentM.toStringAsFixed(0)} m+',
            ),
            backgroundColor: const Color(0xFFFC5200),
          ),
        );
      }

      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al importar archivo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }
}