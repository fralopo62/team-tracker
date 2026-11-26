import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/activities_screen.dart';
import 'screens/activity_detail_screen.dart';
import 'screens/login_screen.dart';
import 'screens/portada_remolino_screen.dart';
import 'screens/record_screen.dart';
import 'screens/routes_screen.dart';
import 'screens/profile_screen.dart';
import 'services/activity_import_service.dart';
import 'services/shared_file_service.dart';

/// Notificador global para refrescar el feed de actividades cuando se guarda
/// o importa una ruta.
final ValueNotifier<int> activitiesRefreshNotifier = ValueNotifier<int>(0);

/// Idioma forzado manualmente desde el perfil (`null` = usar idioma del teléfono).
final ValueNotifier<Locale?> appLocaleNotifier = ValueNotifier<Locale?>(null);

/// ID de actividad pendiente de abrir desde un enlace entrante.
final ValueNotifier<String?> pendingActivityIdNotifier = ValueNotifier<String?>(null);

const MethodChannel _deepLinkChannel = MethodChannel('com.teamtracker/deep_links');

class AppStrings {
  final String languageCode;

  const AppStrings(this.languageCode);

  factory AppStrings.of(BuildContext context) {
    final forcedCode = appLocaleNotifier.value?.languageCode.toLowerCase();
    final systemCode = Localizations.localeOf(context).languageCode.toLowerCase();
    final effectiveCode = forcedCode ?? systemCode;
    return AppStrings(effectiveCode.startsWith('de') ? 'de' : 'es');
  }

  bool get isGerman => languageCode == 'de';

  // Navegación inferior
  String get navActivities => isGerman ? 'Aktivitäten' : 'Actividades';
  String get navRecord => isGerman ? 'Aufnehmen' : 'Grabar';
  String get navRoutes => isGerman ? 'Strecken' : 'Rutas';
  String get navProfile => isGerman ? 'Profil' : 'Perfil';

  // Compartir / Importar archivos
  String importingFile(String fileName) =>
      isGerman ? 'Importiere $fileName...' : 'Importando $fileName...';
  String couldNotReadFile(String fileName) => isGerman
      ? 'Datei konnte nicht gelesen werden: $fileName'
      : 'No se pudo leer el archivo: $fileName';
  String uploadedActivity(String title) => isGerman
      ? 'Aktivität "$title" auf Supabase hochgeladen'
      : 'Actividad "$title" subida a Supabase';
  String uploadActivityError(String title) => isGerman
      ? 'Fehler beim Hochladen von "$title" auf Supabase'
      : 'Error al subir "$title" a Supabase';

  // Feed de actividades
  String get loadingErrorPrefix =>
      isGerman ? 'Fehler beim Laden der Daten: ' : 'Error al cargar datos: ';
  String get noActivities =>
      isGerman ? 'Keine Aktivitäten vorhanden.' : 'No hay actividades registradas.';
  String get heroGreeting => isGerman ? 'Auf geht’s!' : '¡A por todas!';
  String get heroSubtitle => isGerman
      ? 'Deine letzten Strecken und Trainings'
      : 'Tus últimas rutas y entrenamientos';
  String get defaultActivityTitle =>
      isGerman ? 'Training ohne Titel' : 'Entrenamiento sin título';
  String get defaultAthleteName => 'Francisco Poyatos';
  String get defaultLocation => 'Brenes, Sevilla';
  String get justNow => isGerman ? 'Gerade eben' : 'Hace un momento';
  String get recentDate => isGerman ? 'Aktuelles Datum' : 'Fecha reciente';

  // Métricas y tooltips
  String get distance => isGerman ? 'Distanz' : 'Distancia';
  String get ascent => isGerman ? 'Anstieg' : 'Desnivel';
  String get avgSpeed => isGerman ? 'Ø Tempo' : 'Vel. Media';
  String get openCoospoRide =>
      isGerman ? 'CoospoRide öffnen' : 'Abrir CoospoRide';
  String get coospoRideNotOpened => isGerman
      ? 'CoospoRide konnte auf diesem Gerät nicht geöffnet werden.'
      : 'No se pudo abrir CoospoRide en este dispositivo.';
  String coospoRideError(Object error) => isGerman
      ? 'Fehler beim Öffnen von CoospoRide: $error'
      : 'Error al abrir CoospoRide: $error';
  String get importGpxFit =>
      isGerman ? 'GPX / FIT importieren' : 'Importar GPX / FIT';

  // Grabación y Ciclocomputador Pro
  String get timeUpper => isGerman ? 'ZEIT' : 'TIEMPO';
  String get distanceUpper => isGerman ? 'DISTANZ' : 'DISTANCIA';
  String get speedUpper => isGerman ? 'GESCHWINDIGKEIT' : 'VELOCIDAD';
  String get altitudeUpper => isGerman ? 'HÖHE' : 'ALTITUD';
  String get movingTimeUpper => isGerman ? 'BEWEGUNGSZEIT' : 'TIEMPO MOV.';
  String get gradeUpper => isGerman ? 'STEIGUNG' : 'INCLINACIÓN';
  String get temperatureUpper => isGerman ? 'TEMPERATUR' : 'TEMPERATURA';
  String get currentSpeedUpper =>
      isGerman ? 'AKTUELLE GESCHWINDIGKEIT' : 'VELOCIDAD ACTUAL';
  String get cycleComputerPro =>
      isGerman ? 'FAHRRADCOMPUTER PRO' : 'CICLOCOMPUTER PRO';
  String get recordingUpper => isGerman ? 'AUFNAHME' : 'GRABANDO';
  String get pausedUpper => isGerman ? 'PAUSIERT' : 'EN PAUSA';
  String get autoPauseTag => isGerman ? '(AUTO-PAUSE)' : '(AUTO-PAUSA)';
  String get pauseTag => isGerman ? '(PAUSE)' : '(PAUSA)';

  String get startRoute => isGerman ? 'STRECKE STARTEN' : 'INICIAR RUTA';
  String get pause => isGerman ? 'PAUSE' : 'PAUSAR';
  String get resume => isGerman ? 'FORTSETZEN' : 'REANUDAR';
  String get finish => isGerman ? 'BEENDEN' : 'FINALIZAR';
  String get discardRoute =>
      isGerman ? 'Strecke verwerfen' : 'Descartar ruta';
  String get routeDiscarded =>
      isGerman ? 'Strecke verworfen.' : 'Ruta descartada.';

  String gpsExcellent(int meters) => isGerman
      ? 'GPS Hervorragend (${meters}m)'
      : 'GPS Excelente (${meters}m)';
  String gpsGood(int meters) =>
      isGerman ? 'GPS Gut (${meters}m)' : 'GPS Bueno (${meters}m)';
  String gpsWeak(int meters) =>
      isGerman ? 'GPS Schwach (${meters}m)' : 'GPS Débil (${meters}m)';
  String get searchingGps =>
      isGerman ? 'Suche GPS-Signal...' : 'Buscando señal GPS...';

  String sportLabel(String sportKey) {
    switch (sportKey) {
      case 'Ciclismo':
        return isGerman ? 'Radfahren' : 'Ciclismo';
      case 'Running':
        return isGerman ? 'Laufen' : 'Running';
      case 'Caminata':
        return isGerman ? 'Spaziergang' : 'Caminata';
      case 'Senderismo':
        return isGerman ? 'Wandern' : 'Senderismo';
      case 'Windsurf':
        return isGerman ? 'Windsurfen' : 'Windsurf';
      case 'Natación':
        return isGerman ? 'Schwimmen' : 'Natación';
      case 'Remo':
        return isGerman ? 'Rudern' : 'Remo';
      case 'Elíptica':
        return isGerman ? 'Crosstrainer' : 'Elíptica';
      case 'Gimnasio':
        return isGerman ? 'Fitnessstudio' : 'Gimnasio';
      default:
        return sportKey;
    }
  }

  String defaultRouteTitleForSport(String sportKey) {
    final label = sportLabel(sportKey);
    return isGerman ? '$label-Strecke' : 'Ruta de $label';
  }

  // Pantalla de rutas y mapas
  String get routesAndMapsTitle =>
      isGerman ? 'Strecken und Karten' : 'Rutas y Mapas';
  String get filterAll => isGerman ? 'Alle' : 'Todos';
  String routesLoadError(Object error) => isGerman
      ? 'Fehler beim Laden der Strecken: $error'
      : 'Error al cargar rutas: $error';
  String noRoutesForSport(String sportLabel) => isGerman
      ? 'Keine gespeicherten Strecken für $sportLabel.'
      : 'No hay rutas de $sportLabel guardadas.';
  String routeDistanceLabel(String formattedKm) =>
      isGerman ? 'Distanz: $formattedKm km' : 'Distancia: $formattedKm km';
  String routeAscentLabel(String formattedMeters) =>
      isGerman ? 'Höhenmeter: $formattedMeters m' : 'Desnivel: $formattedMeters m';
  String get viewMap => isGerman ? 'Karte ansehen' : 'Ver mapa';
  String get noGpsTrack => isGerman ? 'Keine GPS-Route' : 'Sin trazado GPS';

  // Pantalla de perfil
  String get myProfile => isGerman ? 'Mein Profil' : 'Mi Perfil';
  String get languageLabel => isGerman ? 'Sprache' : 'Idioma';
  String get globalStats =>
      isGerman ? 'Globale Statistiken' : 'Estadísticas Globales';
  String get statActivities => isGerman ? 'Aktivitäten' : 'Actividades';
  String get statTotalDistance =>
      isGerman ? 'Gesamtdistanz' : 'Distancia Total';
  String get statMovingTime => isGerman ? 'Zeit unterwegs' : 'Tiempo en Ruta';
  String get statElevationGain =>
      isGerman ? 'Höhenmeter gesamt' : 'Desnivel Acumulado';
  String get statAvgSpeed => isGerman ? 'Durchschnittstempo' : 'Velocidad Media';
  String get statMaxDistance =>
      isGerman ? 'Distanzrekord' : 'Récord Distancia';
  String get noTitleRoute =>
      isGerman ? 'Strecke ohne Titel' : 'Ruta sin título';
  String get signOutAndExit =>
      isGerman ? 'Abmelden und beenden' : 'Cerrar Sesión y Salir';
  String get uploadingAvatar => isGerman
      ? 'Neues Profilbild wird hochgeladen...'
      : 'Subiendo nueva foto de perfil...';
  String get avatarUpdated => isGerman
      ? 'Profilbild erfolgreich aktualisiert!'
      : '¡Foto de perfil actualizada y guardada con éxito!';
  String avatarError(Object error) => isGerman
      ? 'Fehler beim Ändern des Profilbilds: $error'
      : 'Error al cambiar foto de perfil: $error';

  String formatActivityDate(dynamic rawDateStr) {
    try {
      if (rawDateStr == null || rawDateStr.toString().isEmpty) {
        return justNow;
      }
      final dt = DateTime.parse(rawDateStr.toString()).toLocal();
      const esMonths = [
        'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
        'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
      ];
      const deMonths = [
        'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
        'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'
      ];
      final day = dt.day;
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');

      if (isGerman) {
        final month = deMonths[dt.month - 1];
        return '$day. $month ${dt.year} um $hour:$minute';
      } else {
        final month = esMonths[dt.month - 1];
        return '$day de $month de ${dt.year} a las $hour:$minute';
      }
    } catch (_) {
      return recentDate;
    }
  }
}

String? _extractActivityIdFromLink(String? rawUri) {
  if (rawUri == null || rawUri.trim().isEmpty) return null;
  final uri = Uri.tryParse(rawUri.trim());
  if (uri == null) return null;
  final id = uri.queryParameters['id'];
  if (id != null && id.trim().isNotEmpty) {
    return id.trim();
  }
  return null;
}

Future<void> _initDeepLinks() async {
  try {
    final String? initialLink =
        await _deepLinkChannel.invokeMethod<String>('getInitialDeepLink');
    final initialId = _extractActivityIdFromLink(initialLink);
    if (initialId != null) {
      pendingActivityIdNotifier.value = initialId;
    }
  } catch (_) {}

  _deepLinkChannel.setMethodCallHandler((call) async {
    if (call.method == 'onDeepLinkReceived') {
      final newId = _extractActivityIdFromLink(call.arguments as String?);
      if (newId != null) {
        pendingActivityIdNotifier.value = newId;
      }
    }
  });
}

List<gmaps.LatLng> _decodePolylineForDetail(String encoded) {
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Forzar Hybrid Composition en Android para evitar pantalla en blanco con Impeller/Vulkan
  final GoogleMapsFlutterPlatform mapsImplementation =
      GoogleMapsFlutterPlatform.instance;
  if (mapsImplementation is GoogleMapsFlutterAndroid) {
    mapsImplementation.useAndroidViewSurface = true;
  }

  // Inicialización de Supabase con tus credenciales
  await Supabase.initialize(
    url: 'https://nksbxroquxrstakvnpbk.supabase.co',
    anonKey: 'sb_publishable_aP8kSg0l5M_ZpRRZjTj-ew_SFt3Oibz',
  );

  await _initDeepLinks();

  runApp(const TeamTrackerApp());
}

class TeamTrackerApp extends StatelessWidget {
  const TeamTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Comprobamos si ya hay una sesión activa en Supabase
    final session = Supabase.instance.client.auth.currentSession;

    return ValueListenableBuilder<Locale?>(
      valueListenable: appLocaleNotifier,
      builder: (context, forcedLocale, _) {
        return MaterialApp(
          title: 'TeamTracker',
          debugShowCheckedModeBanner: false,
          locale: forcedLocale,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('es'),
            Locale('de'),
          ],
          localeResolutionCallback: (locale, supportedLocales) {
            if (forcedLocale != null) {
              return forcedLocale;
            }
            if (locale != null && locale.languageCode.toLowerCase() == 'de') {
              return const Locale('de');
            }
            return const Locale('es');
          },
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0F1115),
            primaryColor: const Color(0xFFFC5200),
            colorScheme: ColorScheme.dark(
              primary: const Color(0xFFFC5200),
              secondary: const Color(0xFFFC5200),
              surface: const Color(0xFF1A1D24),
            ),
          ),
          // Si hay sesión va primero a la portada de 6s y luego a MainNavigationScreen;
          // si no hay sesión, va al login.
          home: session == null
              ? const LoginScreen()
              : const PortadaRemolinoScreen(nextScreen: MainNavigationScreen()),
        );
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  late final List<Widget> _screens;
  bool _isOpeningActivityLink = false;

  @override
  void initState() {
    super.initState();

    _screens = [
      const ActivitiesFeedScreen(),
      RecordActivityScreen(
        onSaved: () {
          if (!mounted) return;
          setState(() {
            _currentIndex = 0;
          });
        },
      ),
      const RoutesScreen(),
      const ProfileScreen(),
    ];

    pendingActivityIdNotifier.addListener(_handlePendingActivityLink);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePendingActivityLink();
    });

    SharedFileService.init(
      onFileReceived: (String filePath) async {
        if (!mounted) return;
        final strings = AppStrings.of(context);
        final fileName = filePath.split('/').last;
        debugPrint('Archivo compartido listo para importar: $filePath');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.importingFile(fileName)),
            backgroundColor: const Color(0xFF1A1D24),
          ),
        );

        final importer = ActivityImportService();
        final parsed = await importer.parseFile(filePath);
        if (!mounted) return;

        if (parsed == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(strings.couldNotReadFile(fileName)),
              backgroundColor: Colors.red.shade900,
            ),
          );
          return;
        }

        final ok = await importer.uploadToSupabase(parsed);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? strings.uploadedActivity(parsed.title)
                  : strings.uploadActivityError(parsed.title),
            ),
            backgroundColor: ok ? const Color(0xFF1A1D24) : Colors.red.shade900,
          ),
        );

        if (ok) {
          activitiesRefreshNotifier.value++;
          setState(() {
            _currentIndex = 0;
          });
        }
      },
    );
  }

  Future<void> _handlePendingActivityLink() async {
    final activityId = pendingActivityIdNotifier.value;
    if (activityId == null || activityId.isEmpty || _isOpeningActivityLink || !mounted) {
      return;
    }

    _isOpeningActivityLink = true;
    try {
      final response = await Supabase.instance.client
          .from('activities')
          .select('*')
          .eq('id', activityId)
          .maybeSingle();

      pendingActivityIdNotifier.value = null;

      if (!mounted || response == null) return;

      final Map<String, dynamic> activityMap = Map<String, dynamic>.from(response);
      final String? encodedPolyline = activityMap['route_polyline'] as String?;
      final List<gmaps.LatLng> decodedPoints =
          (encodedPolyline != null && encodedPolyline.isNotEmpty)
              ? _decodePolylineForDetail(encodedPolyline)
              : <gmaps.LatLng>[];

      final bool? refreshNeeded = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => ActivityDetailScreen(
            activity: activityMap,
            routePoints: decodedPoints,
          ),
        ),
      );

      if (refreshNeeded == true && mounted) {
        activitiesRefreshNotifier.value++;
      }
    } catch (e) {
      pendingActivityIdNotifier.value = null;
      debugPrint('Error abriendo actividad desde enlace: $e');
    } finally {
      _isOpeningActivityLink = false;
    }
  }

  @override
  void dispose() {
    pendingActivityIdNotifier.removeListener(_handlePendingActivityLink);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1A1D24),
        selectedItemColor: const Color(0xFFFC5200),
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: strings.navActivities,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.fiber_manual_record, color: Colors.red),
            label: strings.navRecord,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.map),
            label: strings.navRoutes,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: strings.navProfile,
          ),
        ],
      ),
    );
  }
}