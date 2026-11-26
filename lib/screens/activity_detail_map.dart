import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import '../main.dart';

class ActivityDetailMap extends StatefulWidget {
  final List routePoints;

  const ActivityDetailMap({
    super.key,
    required this.routePoints,
  });

  @override
  State<ActivityDetailMap> createState() => ActivityDetailMapState();
}

class ActivityDetailMapState extends State<ActivityDetailMap> {
  gmaps.GoogleMapController? _mapController;
  Timer? _boundsTimer;

  List<gmaps.LatLng> get _typedPoints {
    return widget.routePoints.whereType<gmaps.LatLng>().toList();
  }

  Future<Uint8List?> captureMapSnapshot() async {
    final controller = _mapController;
    if (controller == null) return null;
    try {
      _fitRouteBounds();
      await Future.delayed(const Duration(milliseconds: 350));
      return await controller.takeSnapshot();
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _boundsTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _fitRouteBounds() {
    final controller = _mapController;
    final points = _typedPoints;
    if (controller == null || points.isEmpty) return;

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

    if ((maxLat - minLat).abs() < 1e-6 && (maxLng - minLng).abs() < 1e-6) {
      controller.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(points.first, 15.0),
      );
      return;
    }

    final bounds = gmaps.LatLngBounds(
      southwest: gmaps.LatLng(minLat, minLng),
      northeast: gmaps.LatLng(maxLat, maxLng),
    );

    controller.animateCamera(
      gmaps.CameraUpdate.newLatLngBounds(bounds, 80.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final points = _typedPoints;

    final gmaps.LatLng center =
        points.isNotEmpty ? points.first : const gmaps.LatLng(36.1750, -5.7167);

    final startLabel = strings.isGerman ? 'Start' : 'Inicio';
    final endLabel = strings.isGerman ? 'Ziel' : 'Fin';

    final Set<gmaps.Marker> markers = {
      if (points.isNotEmpty) ...[
        gmaps.Marker(
          markerId: const gmaps.MarkerId('start'),
          position: points.first,
          infoWindow: gmaps.InfoWindow(title: startLabel),
        ),
        gmaps.Marker(
          markerId: const gmaps.MarkerId('end'),
          position: points.last,
          infoWindow: gmaps.InfoWindow(title: endLabel),
        ),
      ]
    };

    final Set<gmaps.Polyline> polylines = {
      if (points.isNotEmpty)
        gmaps.Polyline(
          polylineId: const gmaps.PolylineId('detail_route'),
          points: points,
          color: const Color(0xFFFC5200),
          width: 5,
        ),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 560,
        width: double.infinity,
        child: gmaps.GoogleMap(
          initialCameraPosition: gmaps.CameraPosition(
            target: center,
            zoom: 14.0,
          ),
          mapType: gmaps.MapType.satellite,
          markers: markers,
          polylines: polylines,
          zoomControlsEnabled: true,
          myLocationButtonEnabled: false,
          scrollGesturesEnabled: true,
          zoomGesturesEnabled: true,
          tiltGesturesEnabled: true,
          rotateGesturesEnabled: true,
          gestureRecognizers: {
            Factory(() => EagerGestureRecognizer()),
          },
          onMapCreated: (gmaps.GoogleMapController controller) {
            _mapController = controller;
            _boundsTimer?.cancel();
            _boundsTimer = Timer(const Duration(milliseconds: 300), () {
              if (mounted) {
                _fitRouteBounds();
              }
            });
          },
        ),
      ),
    );
  }
}