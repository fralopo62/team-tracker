import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; 
import 'package:flutter/foundation.dart';                     
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'team_tracker_location',
    'TeamTracker Servicio GPS',
    description: 'Canal para mantener el seguimiento GPS en segundo plano',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  
  const initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStartService,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'team_tracker_location',
      initialNotificationTitle: 'TeamTracker Activo',
      initialNotificationContent: 'Registrando tu ruta en segundo plano...',
      foregroundServiceTypes: [AndroidForegroundType.location],
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStartService,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
void onStartService(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  final LocationSettings locationSettings = AndroidSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    intervalDuration: const Duration(milliseconds: 1000),
    distanceFilter: 2,
    forceLocationManager: true,
  );

  Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
    if (position.accuracy <= 20.0) {
      service.invoke('updateLocation', {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'altitude': position.altitude,
        'speed': position.speed,
        'accuracy': position.accuracy,
      });
    }
  });
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}
