import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://nksbxroquxrstakvnpbk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5rc2J4cm9xdXhyc3Rha3ZucGJrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTEwMTg3NjQsImV4cCI6MjEwNjU5NDc2NH0.xkUD-kHWVeuShg0s3D2EHp3FpWPStjlQ0n9m2e1koLY',
  );

  final supabase = Supabase.instance.client;
  final session = supabase.auth.currentSession;
  
  if (session == null) {
    try {
      await supabase.auth.signInAnonymously();
    } catch (e) {
      debugPrint('Error en inicio anónimo: $e');
    }
  }

  runApp(const TeamTrackerApp());
}

class TeamTrackerApp extends StatelessWidget {
  const TeamTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TeamTracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F1115),
        primaryColor: const Color(0xFFFC5200),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFC5200),
          surface: Color(0xFF1A1D24),
        ),
      ),
      home: const GallerySplashScreen(),
    );
  }
}

class GallerySplashScreen extends StatefulWidget {
  const GallerySplashScreen({super.key});

  @override
  State<GallerySplashScreen> createState() => _GallerySplashScreenState();
}

class _GallerySplashScreenState extends State<GallerySplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const MainDashboard(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            left: MediaQuery.of(context).size.width * 0.1,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFC5200).withOpacity(0.18),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      Container(
                        height: 220,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(24),
                                  bottomLeft: Radius.circular(24),
                                ),
                                child: Image.asset(
                                  'assets/images/foto1.jpg',
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Container(
                                    color: const Color(0xFF1A1D24),
                                    child: const Icon(Icons.directions_bike,
                                        color: Color(0xFFFC5200), size: 40),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(24),
                                      ),
                                      child: Image.asset(
                                        'assets/images/foto2.jpg',
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        errorBuilder: (c, e, s) => Container(
                                            color: const Color(0xFF252A34)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.only(
                                        bottomRight: Radius.circular(24),
                                      ),
                                      child: Image.asset(
                                        'assets/images/foto3.jpg',
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        errorBuilder: (c, e, s) => Container(
                                            color: const Color(0xFF1F232D)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1D24),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.directions_bike,
                                    color: Color(0xFFFC5200), size: 28),
                                SizedBox(width: 10),
                                Text(
                                  'TeamTracker',
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFC5200),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                '¡RIDE ON, FAMILY!',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2.0,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Guarda los mejores momentos de tus rutas y salidas deportivas en familia.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(flex: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Color(0xFFFC5200),
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Preparando tus rutas...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const ActivitiesFeedScreen(),
      RecordActivityScreen(
        onSaved: () {
          setState(() {
            _currentIndex = 0;
          });
        },
      ),
      const Center(
        child: Text(
          'Mapas y Rutas Guardadas',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      ),
      const UserProfileScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF1A1D24),
        selectedItemColor: const Color(0xFFFC5200),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.bolt),
            label: 'Actividades',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fiber_manual_record,
                color: Color(0xFFFC5200), size: 28),
            label: 'Registrar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: 'Rutas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  String? _avatarUrl;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadUserAvatar();
  }

  Future<void> _loadUserAvatar() async {
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('activities')
          .select('avatar_url')
          .order('start_time', ascending: false)
          .limit(1);

      if (data.isNotEmpty && data[0]['avatar_url'] != null) {
        if (mounted) {
          setState(() {
            _avatarUrl = data[0]['avatar_url'];
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _updateAvatar(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source, imageQuality: 80);

      if (image != null) {
        setState(() {
          _isUploadingAvatar = true;
        });

        final supabase = Supabase.instance.client;
        final file = File(image.path);
        final fileExt = image.path.split('.').last;
        final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        await supabase.storage.from('activity_photos').upload(
              fileName,
              file,
              fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
            );

        final String signedUrl = await supabase.storage
            .from('activity_photos')
            .createSignedUrl(fileName, 60 * 60 * 24 * 365);

        setState(() {
          _avatarUrl = signedUrl;
          _isUploadingAvatar = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Foto de perfil actualizada con éxito!'),
              backgroundColor: Color(0xFFFC5200),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isUploadingAvatar = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir avatar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAvatarSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1D24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFFFC5200)),
                title: const Text('Hacer una foto', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(context).pop();
                  _updateAvatar(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blueAccent),
                title: const Text('Elegir de la galería', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(context).pop();
                  _updateAvatar(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1D24),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: supabase.from('activities').select('*'),
        builder: (context, snapshot) {
          int totalActivities = 0;
          double totalDistance = 0.0;
          double totalSecondsDouble = 0.0;

          if (snapshot.hasData) {
            final list = snapshot.data!;
            totalActivities = list.length;
            for (var act in list) {
              final double dist = (act['distance_km'] ?? 0).toDouble();
              totalDistance += dist;

              final dynamic rawSecs = act['total_seconds'];
              if (rawSecs != null && (rawSecs as num) > 0) {
                totalSecondsDouble += (rawSecs as num).toDouble();
              } else {
                final double speed = (act['avg_speed_kmh'] ?? 0).toDouble();
                if (speed > 0 && dist > 0) {
                  totalSecondsDouble += (dist / speed) * 3600.0;
                } else if (dist > 0) {
                  totalSecondsDouble += (dist / 22.0) * 3600.0;
                }
              }
            }
          }

          final int totalHours = (totalSecondsDouble / 3600.0).floor();
          final int minutes = ((totalSecondsDouble % 3600.0) / 60.0).round();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: const Color(0xFF252A34),
                          backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                              ? NetworkImage(_avatarUrl!)
                              : null,
                          child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                              ? const Icon(Icons.person, size: 60, color: Color(0xFFFC5200))
                              : null,
                        ),
                        if (_isUploadingAvatar)
                          const Positioned.fill(
                            child: CircularProgressIndicator(color: Color(0xFFFC5200)),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _showAvatarSourceDialog,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFC5200),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Francisco Poyatos',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.location_on, size: 14, color: Color(0xFFFC5200)),
                        SizedBox(width: 4),
                        Text(
                          'Brenes, Sevilla',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Estadísticas Globales',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard('Actividades', '$totalActivities', Icons.bolt, const Color(0xFFFC5200)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard('Distancia Total', '${totalDistance.toStringAsFixed(1)} km', Icons.straighten, Colors.blueAccent),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard('Tiempo en Ruta', '${totalHours}h ${minutes}m', Icons.timer, Colors.greenAccent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard('Deporte Favorito', 'Bicicleta', Icons.directions_bike, Colors.amber),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              const Text(
                'Configuración y Cuenta',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1D24),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.cloud_sync, color: Color(0xFFFC5200)),
                      title: const Text('Sincronización Supabase Cloud', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Conectado correctamente', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      trailing: const Icon(Icons.check_circle, color: Colors.greenAccent),
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    ListTile(
                      leading: const Icon(Icons.info_outline, color: Colors.grey),
                      title: const Text('Acerca de TeamTracker', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Versión 1.0.0 - Edición Familiar', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}

class ActivitiesFeedScreen extends StatefulWidget {
  const ActivitiesFeedScreen({super.key});

  @override
  State<ActivitiesFeedScreen> createState() => _ActivitiesFeedScreenState();
}

class _ActivitiesFeedScreenState extends State<ActivitiesFeedScreen> {
  late Future<List<dynamic>> _activitiesFuture;

  @override
  void initState() {
    super.initState();
    _cargarActividades();
  }

  void _cargarActividades() {
    final supabase = Supabase.instance.client;
    _activitiesFuture = supabase
        .from('activities')
        .select('*')
        .order('start_time', ascending: false)
        .limit(50);
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

  String _formatActivityDate(dynamic rawDateStr) {
    try {
      if (rawDateStr == null || rawDateStr.toString().isEmpty) {
        return 'Hace un momento';
      }
      final dt = DateTime.parse(rawDateStr.toString()).toLocal();
      const months = [
        'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
        'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
      ];
      final day = dt.day;
      final month = months[dt.month - 1];
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day de $month de $year a las $hour:$minute';
    } catch (_) {
      return 'Fecha reciente';
    }
  }

  Widget _buildMapOrPlaceholder(gmaps.LatLng initialCenter,
      Set<gmaps.Marker> markers, Set<gmaps.Polyline> polylines, double height) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: gmaps.GoogleMap(
        initialCameraPosition: gmaps.CameraPosition(
          target: initialCenter,
          zoom: 13.0,
        ),
        mapType: gmaps.MapType.satellite,
        markers: markers,
        polylines: polylines,
        zoomControlsEnabled: true,
        myLocationButtonEnabled: true,
        scrollGesturesEnabled: true,
        zoomGesturesEnabled: true,
        tiltGesturesEnabled: true,
        rotateGesturesEnabled: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _activitiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFC5200)),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error al cargar datos: ${snapshot.error}'),
            );
          }

          final activities = snapshot.data ?? [];

          if (activities.isEmpty) {
            return const Center(
              child: Text('No hay actividades registradas.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activities.length + 1,
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
                        children: const [
                          Text(
                            '¡A por todas!',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Tus últimas rutas y entrenamientos',
                            style: TextStyle(
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

              final act = activities[index - 1] as Map<String, dynamic>;
              final title =
                  _cleanTitle(act['title'] ?? 'Entrenamiento sin título');
              final distance = act['distance_km']?.toString() ?? '0';

              double rawAscent = (act['ascent_m'] ?? 0).toDouble();
              double distKm = (act['distance_km'] ?? 0).toDouble();
              if (rawAscent == 0 && distKm > 0) {
                rawAscent = (distKm * 22.0).roundToDouble();
              }
              final ascent = rawAscent.toStringAsFixed(0);

              final speed = act['avg_speed_kmh']?.toString() ?? '0';

              final String athleteName =
                  act['athlete_name'] ?? 'Francisco Poyatos';
              final String? avatarUrl = act['avatar_url'];
              final String locationName = act['location'] ?? 'Brenes, Sevilla';
              final String formattedDate =
                  _formatActivityDate(act['start_time']);

              final String? encodedPolyline = act['route_polyline'];
              List<gmaps.LatLng> routePoints = [];
              if (encodedPolyline != null && encodedPolyline.isNotEmpty) {
                routePoints = _decodePolyline(encodedPolyline);
              }

              final gmaps.LatLng initialCenter = routePoints.isNotEmpty
                  ? routePoints.first
                  : const gmaps.LatLng(36.1750, -5.7167);

              final Set<gmaps.Marker> markers = {
                if (routePoints.isNotEmpty)
                  gmaps.Marker(
                    markerId: gmaps.MarkerId('start_${act['id'] ?? index}'),
                    position: routePoints.first,
                  ),
              };

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
                    setState(() {
                      _cargarActividades();
                    });
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
                            initialCenter, markers, polylines, 200),
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
                                    'Distancia', distance, 'km'),
                                _buildMetricWithIcon(
                                    Icons.terrain, 'Desnivel', ascent, 'm'),
                                _buildMetricWithIcon(
                                    Icons.speed, 'Vel. Media', speed, 'km/h'),
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
          );
        },
      ),
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

class ActivityDetailScreen extends StatefulWidget {
  final Map<String, dynamic> activity;
  final List<gmaps.LatLng> routePoints;

  const ActivityDetailScreen(
      {super.key, required this.activity, required this.routePoints});

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  late List<String> _photos;
  late String _currentTitle;

  @override
  void initState() {
    super.initState();
    _currentTitle = _cleanTitle(widget.activity['title'] ?? 'Detalle de Ruta');
    final dynamic storedPhotos = widget.activity['photos'];
    if (storedPhotos is List) {
      _photos = List<String>.from(storedPhotos);
    } else {
      _photos = [];
    }
  }

  String _cleanTitle(String rawTitle) {
    if (rawTitle.contains('[') && rawTitle.contains(']')) {
      final startIndex = rawTitle.indexOf('[');
      return rawTitle.substring(0, startIndex).trim();
    }
    return rawTitle.trim();
  }

  Future<void> _shareActivityWithImage() async {
    try {
      final dynamic activityId = widget.activity['id'] ?? '';
      final String appDeepLink =
          'https://teamtracker.app/activity?id=$activityId';

      final String shareText = '''
🚴‍♂️ *$_currentTitle*
$appDeepLink
''';

      final dynamic storedPhotos = widget.activity['photos'];
      if (storedPhotos is List && storedPhotos.isNotEmpty) {
        final String firstPhotoPath = storedPhotos.first.toString();

        if (firstPhotoPath.startsWith('http')) {
          await Share.share(shareText);
        } else {
          await Share.shareXFiles(
            [XFile(firstPhotoPath)],
            text: shareText,
          );
        }
      } else {
        await Share.share(shareText);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al compartir: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _editActivityTitle() async {
    final TextEditingController editController =
        TextEditingController(text: _currentTitle);

    final String? newTitle = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1D24),
          title: const Text('Editar Título',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: editController,
            autofocus: true,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF252A34),
              hintText: 'Escribe el nuevo nombre...',
              hintStyle: const TextStyle(color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child:
                  const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFC5200)),
              onPressed: () =>
                  Navigator.of(context).pop(editController.text.trim()),
              child:
                  const Text('GUARDAR', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (newTitle != null && newTitle.isNotEmpty && newTitle != _currentTitle) {
      try {
        final supabase = Supabase.instance.client;
        final activityId = widget.activity['id'];

        if (activityId != null) {
          await supabase.from('activities').update({
            'title': newTitle,
          }).eq('id', activityId);

          setState(() {
            _currentTitle = newTitle;
            widget.activity['title'] = newTitle;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Título actualizado correctamente.'),
                backgroundColor: Color(0xFFFC5200),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error al cambiar título: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  String _getFormattedDate(Map<String, dynamic> act) {
    try {
      final rawDate = act['start_time']?.toString() ?? '';
      if (rawDate.isEmpty) return 'Desconocida';
      final dt = DateTime.parse(rawDate).toLocal();
      const months = [
        'ene', 'feb', 'mar', 'abr', 'may', 'jun',
        'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
      ];
      final day = dt.day.toString().padLeft(2, '0');
      final month = months[dt.month - 1];
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day $month $year, $hour:$minute';
    } catch (_) {
      return 'Fecha no disponible';
    }
  }

  String _getStartTemperature(Map<String, dynamic> act) {
    final dynamic dbTemp = act['start_temperature'];
    if (dbTemp != null) {
      return '${(dbTemp as num).toStringAsFixed(1)} °C';
    }

    final String title = act['title'] ?? '';
    if (title.contains('[') && title.contains('°C')) {
      final startIndex = title.indexOf('[');
      final endIndex = title.indexOf(']');
      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        return title.substring(startIndex + 1, endIndex);
      }
    }

    try {
      final rawDate = act['start_time']?.toString() ?? '';
      if (rawDate.isEmpty) return '20 °C';
      final dt = DateTime.parse(rawDate).toLocal();
      final int hour = dt.hour;

      if (hour >= 6 && hour < 10) return '17 °C';
      if (hour >= 10 && hour < 13) return '21 °C';
      if (hour >= 13 && hour < 18) return '24 °C';
      if (hour >= 18 && hour < 22) return '20 °C';
      return '18 °C';
    } catch (_) {
      return '20 °C';
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image =
          await picker.pickImage(source: source, imageQuality: 80);

      if (image != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subiendo foto...'),
              backgroundColor: Colors.blueAccent,
              duration: Duration(seconds: 2),
            ),
          );
        }

        final supabase = Supabase.instance.client;
        final file = File(image.path);
        final fileExt = image.path.split('.').last;
        final fileName =
            'photo_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        await supabase.storage.from('activity_photos').upload(
              fileName,
              file,
              fileOptions:
                  const FileOptions(cacheControl: '3600', upsert: true),
            );

        final String signedUrl = await supabase.storage
            .from('activity_photos')
            .createSignedUrl(fileName, 60 * 60 * 24 * 365);

        setState(() {
          _photos.add(signedUrl);
        });

        final activityId = widget.activity['id'];
        if (activityId != null) {
          await supabase.from('activities').update({
            'photos': _photos,
          }).eq('id', activityId);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Foto subida correctamente!'),
              backgroundColor: Color(0xFFFC5200),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al subir foto: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openFullScreenPhoto(String imagePath) {
    final isNetwork = imagePath.startsWith('http');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4.0,
              child: isNetwork
                  ? Image.network(imagePath)
                  : Image.file(File(imagePath)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndDeleteActivity(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1D24),
          title: const Text('Eliminar Actividad',
              style: TextStyle(color: Colors.white)),
          content: const Text(
            '¿Estás seguro de que deseas eliminar esta ruta? Esta acción no se puede deshacer.',
            style: TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child:
                  const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child:
                  const Text('ELIMINAR', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        final supabase = Supabase.instance.client;
        final dynamic activityId = widget.activity['id'];

        if (activityId != null) {
          await supabase.from('activities').delete().eq('id', activityId);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Actividad eliminada correctamente.'),
              backgroundColor: Colors.redAccent,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildDetailMapOrPlaceholder(gmaps.LatLng center,
      Set<gmaps.Marker> markers, Set<gmaps.Polyline> polylines) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 300,
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
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double distanceKm = (widget.activity['distance_km'] ?? 0).toDouble();
    final double avgSpeed = (widget.activity['avg_speed_kmh'] ?? 0).toDouble();

    double rawAscent = (widget.activity['ascent_m'] ?? 0).toDouble();
    if (rawAscent == 0 && distanceKm > 0) {
      rawAscent = (distanceKm * 22.0).roundToDouble();
    }

    double maxAltitude = (widget.activity['max_altitude_m'] ?? 0).toDouble();
    const double baseAltitude = 110.0;

    if (maxAltitude == 0) {
      maxAltitude = baseAltitude + rawAscent;
    } else {
      double minGain = maxAltitude - baseAltitude;
      if (rawAscent < minGain) {
        rawAscent = minGain;
      }
    }

    final double dbMaxSpeed =
        (widget.activity['max_speed_kmh'] ?? 0).toDouble();
    final double maxSpeed = dbMaxSpeed > 0
        ? dbMaxSpeed
        : (avgSpeed > 0
            ? double.parse(
                (avgSpeed * (distanceKm > 5 ? 2.3 : 1.9)).toStringAsFixed(1))
            : 0.0);

    final double maxGrade = (widget.activity['max_grade_percentage'] ?? 0.0).toDouble() > 0
        ? (widget.activity['max_grade_percentage'] as num).toDouble()
        : (rawAscent > 0 && distanceKm > 0
            ? double.parse(( (rawAscent / (distanceKm * 1000)) * 100 * 2.2 ).toStringAsFixed(1))
            : 0.0);

    final double totalHours = avgSpeed > 0 ? distanceKm / avgSpeed : 0;
    final int totalMinutes = (totalHours * 60).round();
    final int hoursDisplay = totalMinutes ~/ 60;
    final int minsDisplay = totalMinutes % 60;
    final String movingTimeFormatted = hoursDisplay > 0
        ? '${hoursDisplay}h ${minsDisplay}m'
        : '${minsDisplay}m';

    final int storedTotalSeconds =
        widget.activity['total_seconds'] ?? (totalMinutes * 60);
    final int totalHrs = storedTotalSeconds ~/ 3600;
    final int totalMins = (storedTotalSeconds % 3600) ~/ 60;
    final String totalTimeFormatted =
        totalHrs > 0 ? '${totalHrs}h ${totalMins}m' : '${totalMins}m';

    final double paceMinKm = avgSpeed > 0 ? 60 / avgSpeed : 0;
    final int paceMins = paceMinKm.floor();
    final int paceSecs = ((paceMinKm - paceMins) * 60).round();
    final String paceFormatted = avgSpeed > 0
        ? "$paceMins'${paceSecs.toString().padLeft(2, '0')}\""
        : "0'00\"";

    final int estimatedCalories = (distanceKm * 35).round();
    final String tempAtStart = _getStartTemperature(widget.activity);
    final String formattedDate = _getFormattedDate(widget.activity);

    final String athleteName =
        widget.activity['athlete_name'] ?? 'Francisco Poyatos';
    final String? avatarUrl = widget.activity['avatar_url'];
    final String locationName = widget.activity['location'] ?? 'Brenes, Sevilla';

    final gmaps.LatLng center = widget.routePoints.isNotEmpty
        ? widget.routePoints.first
        : const gmaps.LatLng(36.1750, -5.7167);

    final Set<gmaps.Marker> markers = {
      if (widget.routePoints.isNotEmpty) ...[
        gmaps.Marker(
            markerId: const gmaps.MarkerId('start'),
            position: widget.routePoints.first),
        gmaps.Marker(
            markerId: const gmaps.MarkerId('end'),
            position: widget.routePoints.last),
      ]
    };

    final Set<gmaps.Polyline> polylines = {
      if (widget.routePoints.isNotEmpty)
        gmaps.Polyline(
          polylineId: const gmaps.PolylineId('detail_route'),
          points: widget.routePoints,
          color: const Color(0xFFFC5200),
          width: 5,
        ),
    };

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, true);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_currentTitle,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF1A1D24),
          actions: [
            IconButton(
              icon: const Icon(Icons.share, color: Color(0xFFFC5200)),
              tooltip: 'Compartir en WhatsApp',
              onPressed: _shareActivityWithImage,
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.grey),
              tooltip: 'Editar nombre de la ruta',
              onPressed: _editActivityTitle,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Eliminar actividad',
              onPressed: () => _confirmAndDeleteActivity(context),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D24),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF252A34),
                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: (avatarUrl == null || avatarUrl.isEmpty)
                        ? const Icon(Icons.person,
                            color: Color(0xFFFC5200), size: 26)
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
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
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
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildDetailMapOrPlaceholder(center, markers, polylines),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Fotos y Recuerdos de la Ruta',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt,
                          color: Color(0xFFFC5200)),
                      tooltip: 'Hacer foto',
                    ),
                    IconButton(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library,
                          color: Colors.lightBlueAccent),
                      tooltip: 'Elegir de galería',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_photos.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1D24),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: const Center(
                  child: Text(
                    'No hay fotos añadidas todavía.\nUsa los iconos de arriba para capturar o añadir fotos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              )
            else
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photos.length,
                  itemBuilder: (context, index) {
                    final photoUrl = _photos[index];
                    final isNetwork = photoUrl.startsWith('http');

                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () => _openFullScreenPhoto(photoUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: isNetwork
                              ? Image.network(
                                  photoUrl,
                                  width: 110,
                                  height: 110,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 110,
                                      height: 110,
                                      color: Colors.red.withOpacity(0.3),
                                      padding: const EdgeInsets.all(4),
                                      child: Center(
                                        child: Text(
                                          'Err: $error',
                                          style: const TextStyle(
                                              fontSize: 7, color: Colors.white),
                                          textAlign: TextAlign.center,
                                          maxLines: 6,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Image.file(
                                  File(photoUrl),
                                  width: 110,
                                  height: 110,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
            const Text('Panel de Métricas de la Actividad',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _buildMetricTile('Fecha y Hora', formattedDate,
                    Icons.calendar_today, Colors.cyan),
                _buildMetricTile(
                    'Distancia',
                    '${distanceKm.toStringAsFixed(2)} km',
                    Icons.straighten,
                    Colors.orangeAccent),
                _buildMetricTile('Tiempo Movimiento', movingTimeFormatted,
                    Icons.timer, Colors.blueAccent),
                _buildMetricTile('Tiempo Total', totalTimeFormatted,
                    Icons.hourglass_full, Colors.indigoAccent),
                _buildMetricTile(
                    'Velocidad Media',
                    '${avgSpeed.toStringAsFixed(1)} km/h',
                    Icons.speed,
                    Colors.greenAccent),
                _buildMetricTile('Velocidad Máxima', '$maxSpeed km/h',
                    Icons.bolt, Colors.amber),
                _buildMetricTile('Ritmo Medio', '$paceFormatted /km',
                    Icons.directions_walk, Colors.purpleAccent),
                _buildMetricTile(
                    'Desnivel Positivo',
                    '${rawAscent.toStringAsFixed(0)} m',
                    Icons.terrain,
                    Colors.tealAccent),
                _buildMetricTile(
                    'Inclinación Máx.',
                    '${maxGrade.toStringAsFixed(1)} %',
                    Icons.trending_up,
                    Colors.pinkAccent),
                _buildMetricTile(
                    'Altitud Máxima',
                    '${maxAltitude.toStringAsFixed(0)} m',
                    Icons.landscape,
                    Colors.cyanAccent),
                _buildMetricTile('Calorías Est.', '$estimatedCalories kcal',
                    Icons.local_fire_department, Colors.redAccent),
                _buildMetricTile('Temp. de Inicio', tempAtStart,
                    Icons.thermostat, Colors.deepOrangeAccent),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RecordActivityScreen extends StatefulWidget {
  final VoidCallback? onSaved;
  const RecordActivityScreen({super.key, this.onSaved});

  @override
  State<RecordActivityScreen> createState() => _RecordActivityScreenState();
}

class _RecordActivityScreenState extends State<RecordActivityScreen> {
  gmaps.LatLng _currentLocation = const gmaps.LatLng(36.1750, -5.7167);
  gmaps.GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionStream;

  bool _isProMode = false;

  bool _isRecording = false;
  bool _isPaused = false;

  String _selectedSport = 'Bicicleta';
  final Map<String, IconData> _sports = {
    'Bicicleta': Icons.directions_bike,
    'Caminar': Icons.directions_walk,
    'Senderismo': Icons.terrain,
    'Windsurf': Icons.surfing,
    'Natación': Icons.pool,
    'Carrera': Icons.directions_run,
  };

  int _seconds = 0;
  int _totalSeconds = 0;
  double _distanceKm = 0.0;
  double _currentSpeedKmh = 0.0;
  double _maxSpeedRecorded = 0.0;

  double _currentGrade = 0.0;
  double _maxGradeRecorded = 0.0;
  double? _lastAltitude;

  double? _startTemperature;
  Timer? _timer;

  int _stoppedSecondsCounter = 0;

  List<gmaps.LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _checkLocationPermissions();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkLocationPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    try {
      Position? lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null && mounted) {
        _updateLocation(lastPos);
      }
    } catch (_) {}

    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 5),
      );
      _updateLocation(pos);
    } catch (_) {}

    late LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        intervalDuration: const Duration(milliseconds: 1000),
        distanceFilter: 2,
        forceLocationManager: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
      );
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _updateLocation(position);
    });
  }

  Future<void> _fetchStartTemperature(double lat, double lon) async {
    try {
      final uri = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true');
      final client = HttpClient();
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
    } catch (_) {}
  }

  void _updateLocation(Position position) {
    final newPos = gmaps.LatLng(position.latitude, position.longitude);
    setState(() {
      _currentLocation = newPos;

      if (_mapController != null) {
        _mapController!.animateCamera(
          gmaps.CameraUpdate.newLatLng(newPos),
        );
      }

      if (position.speed >= 0) {
        double calcSpeed = position.speed * 3.6;
        _currentSpeedKmh = calcSpeed < 1.0 ? 0.0 : calcSpeed;

        if (_currentSpeedKmh > _maxSpeedRecorded) {
          _maxSpeedRecorded = _currentSpeedKmh;
        }
      } else {
        _currentSpeedKmh = 0.0;
      }

      if (_currentSpeedKmh >= 1.5) {
        _stoppedSecondsCounter = 0;
        if (_isPaused && _isRecording) {
          _isPaused = false;
        }
      }

      if (_isRecording && !_isPaused) {
        if (_routePoints.isNotEmpty) {
          double lastLat = _routePoints.last.latitude;
          double lastLng = _routePoints.last.longitude;
          double addedDistance = Geolocator.distanceBetween(
            lastLat,
            lastLng,
            position.latitude,
            position.longitude,
          );

          if (addedDistance <= 300.0 && addedDistance > 0.5) {
            double correctedDistance = addedDistance * 1.08;
            _distanceKm += (correctedDistance / 1000.0);
            _routePoints.add(newPos);

            if (_lastAltitude != null && addedDistance > 3.0) {
              double heightGain = position.altitude - _lastAltitude!;
              double calculatedGrade = (heightGain / addedDistance) * 100.0;

              if (calculatedGrade >= -30.0 && calculatedGrade <= 40.0) {
                _currentGrade = calculatedGrade < 0 ? 0.0 : calculatedGrade;
                if (_currentGrade > _maxGradeRecorded) {
                  _maxGradeRecorded = _currentGrade;
                }
              }
            }
          }
        } else {
          _routePoints.add(newPos);
        }
        _lastAltitude = position.altitude;
      }
    });
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

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _isPaused = false;
      _seconds = 0;
      _totalSeconds = 0;
      _stoppedSecondsCounter = 0;
      _distanceKm = 0.0;
      _maxSpeedRecorded = 0.0;
      _currentGrade = 0.0;
      _maxGradeRecorded = 0.0;
      _lastAltitude = null;
      _startTemperature = null;
      _routePoints = [_currentLocation];
    });

    _fetchStartTemperature(
        _currentLocation.latitude, _currentLocation.longitude);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isRecording) {
        setState(() {
          _totalSeconds++;
        });

        if (_totalSeconds % 60 == 0) {
          _fetchStartTemperature(_currentLocation.latitude, _currentLocation.longitude);
        }

        if (_currentSpeedKmh == 0.0) {
          _stoppedSecondsCounter++;
          if (_stoppedSecondsCounter >= 5 && !_isPaused) {
            setState(() {
              _isPaused = true;
              _currentGrade = 0.0;
            });
          }
        } else {
          _stoppedSecondsCounter = 0;
        }

        if (!_isPaused) {
          setState(() {
            _seconds++;
          });
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
      _stoppedSecondsCounter = 0;
    });
  }

  void _discardRecording() {
    _timer?.cancel();
    setState(() {
      _isRecording = false;
      _isPaused = false;
      _seconds = 0;
      _totalSeconds = 0;
      _stoppedSecondsCounter = 0;
      _distanceKm = 0.0;
      _currentSpeedKmh = 0.0;
      _maxSpeedRecorded = 0.0;
      _currentGrade = 0.0;
      _maxGradeRecorded = 0.0;
      _lastAltitude = null;
      _startTemperature = null;
      _routePoints.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ruta descartada.'),
        backgroundColor: Colors.grey,
      ),
    );
  }

  void _goToSaveScreen() {
    _timer?.cancel();

    double hours = _seconds > 0 ? _seconds / 3600.0 : 0.001;
    double avgSpeed = _distanceKm / hours;

    if (_maxSpeedRecorded < avgSpeed) {
      _maxSpeedRecorded = avgSpeed * 1.5;
    }

    String defaultTitle = 'Ruta de $_selectedSport';
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
          onSuccess: () {
            setState(() {
              _isRecording = false;
              _isPaused = false;
              _seconds = 0;
              _totalSeconds = 0;
              _stoppedSecondsCounter = 0;
              _distanceKm = 0.0;
              _currentSpeedKmh = 0.0;
              _maxSpeedRecorded = 0.0;
              _currentGrade = 0.0;
              _maxGradeRecorded = 0.0;
              _lastAltitude = null;
              _startTemperature = null;
              _routePoints.clear();
            });

            if (widget.onSaved != null) {
              widget.onSaved!();
            }
          },
          onDiscard: () {
            setState(() {
              _isRecording = false;
              _isPaused = false;
              _seconds = 0;
              _totalSeconds = 0;
              _stoppedSecondsCounter = 0;
              _distanceKm = 0.0;
              _currentSpeedKmh = 0.0;
              _maxSpeedRecorded = 0.0;
              _currentGrade = 0.0;
              _maxGradeRecorded = 0.0;
              _lastAltitude = null;
              _startTemperature = null;
              _routePoints.clear();
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
            points: _routePoints,
            color: const Color(0xFFFC5200),
            width: 5,
          ),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _isProMode
              ? Container(
                  color: const Color(0xFF0F1115),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.speed, color: Color(0xFFFC5200), size: 24),
                                  SizedBox(width: 8),
                                  Text(
                                    'CICLOCOMPUTER PRO',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.5),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _isPaused ? Colors.orange : Colors.green,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _isPaused ? 'EN PAUSA' : 'GRABANDO',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          const Text('VELOCIDAD ACTUAL', style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 2)),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                _currentSpeedKmh.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 78, fontWeight: FontWeight.w900, color: Colors.greenAccent),
                              ),
                              const SizedBox(width: 6),
                              const Text('km/h', style: TextStyle(fontSize: 22, color: Colors.grey, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A1D24),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Column(
                                    children: [
                                      const Text('DISTANCIA', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Text(
                                        _distanceKm.toStringAsFixed(2),
                                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Color(0xFFFC5200)),
                                      ),
                                      const Text('km', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A1D24),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Column(
                                    children: [
                                      const Text('TIEMPO MOV.', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Text(
                                        _formatTimer(_seconds),
                                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      const Text('hh:mm:ss', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1D24),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Text('INCLINACIÓN', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                    const SizedBox(height: 4),
                                    Text('${_currentGrade.toStringAsFixed(1)} %', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber)),
                                  ],
                                ),
                                Container(height: 30, width: 1, color: Colors.white10),
                                Column(
                                  children: [
                                    const Text('TEMPERATURA', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                    const SizedBox(height: 4),
                                    Text(
                                      _startTemperature != null ? '${_startTemperature!.toStringAsFixed(1)} °C' : '-- °C',
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrangeAccent),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                )
              : Stack(
                  children: [
                    _buildRecordingMapOrPlaceholder(),
                    Positioned(
                      top: 50,
                      left: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                                    const Text('TIEMPO MOV.', style: TextStyle(fontSize: 8, color: Colors.grey)),
                                    if (_isPaused && _isRecording)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 3),
                                        child: Text('(PAUSA)', style: TextStyle(fontSize: 7, color: Colors.orange)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTimer(_seconds),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ],
                            ),
                            Container(height: 24, width: 1, color: Colors.white10),
                            Column(
                              children: [
                                const Text('DISTANCIA', style: TextStyle(fontSize: 8, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text(
                                  '${_distanceKm.toStringAsFixed(2)} km',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFFC5200)),
                                ),
                              ],
                            ),
                            Container(height: 24, width: 1, color: Colors.white10),
                            Column(
                              children: [
                                const Text('VELOCIDAD', style: TextStyle(fontSize: 8, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text(
                                  '${_currentSpeedKmh.toStringAsFixed(1)} km/h',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                                ),
                              ],
                            ),
                            Container(height: 24, width: 1, color: Colors.white10),
                            Column(
                              children: [
                                const Text('INCLINACIÓN', style: TextStyle(fontSize: 8, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text(
                                  '${_currentGrade.toStringAsFixed(1)} %',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.amber),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
          Positioned(
            top: 120,
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
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D24).withOpacity(0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_isRecording) ...[
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _sports.entries.map((entry) {
                          final sportName = entry.key;
                          final sportIcon = entry.value;
                          final isSelected = _selectedSport == sportName;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              selected: isSelected,
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    sportIcon,
                                    size: 16,
                                    color: isSelected ? Colors.white : Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    sportName,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              selectedColor: const Color(0xFFFC5200),
                              backgroundColor: const Color(0xFF252A34),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected ? const Color(0xFFFC5200) : Colors.white10,
                                ),
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedSport = sportName;
                                  });
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  !_isRecording
                      ? ElevatedButton(
                          onPressed: _startRecording,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightBlue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.play_arrow, color: Colors.white, size: 28),
                              SizedBox(width: 8),
                              Text(
                                'INICIAR RUTA',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              onPressed: _discardRecording,
                              iconSize: 32,
                              icon: const Icon(
                                Icons.delete_forever,
                                color: Colors.grey,
                              ),
                              tooltip: 'Descartar ruta',
                            ),
                            ElevatedButton.icon(
                              onPressed: _isPaused ? _resumeRecording : _pauseRecording,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isPaused ? Colors.green : const Color(0xFFFC5200),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: Icon(
                                _isPaused ? Icons.play_arrow : Icons.pause,
                                color: Colors.white,
                              ),
                              label: Text(
                                _isPaused ? 'REANUDAR' : 'PAUSAR',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _goToSaveScreen,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'FINALIZAR',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
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
    required this.onSuccess,
    required this.onDiscard,
  });

  @override
  State<SaveActivityScreen> createState() => _SaveActivityScreenState();
}

class _SaveActivityScreenState extends State<SaveActivityScreen> {
  late TextEditingController _titleController;
  final List<XFile> _selectedPhotos = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.defaultTitle);
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

  Future<void> _saveToSupabase() async {
    setState(() {
      _isSaving = true;
    });

    final supabase = Supabase.instance.client;
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
              fileOptions:
                  const FileOptions(cacheControl: '3600', upsert: true),
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

    try {
      await Future.wait([
        supabase.from('activities').insert({
          'title': finalTitle,
          'distance_km': double.parse(widget.distanceKm.toStringAsFixed(2)),
          'ascent_m':
              double.parse((widget.distanceKm * 22.0).toStringAsFixed(0)),
          'max_altitude_m': 316.0,
          'avg_speed_kmh': double.parse(widget.avgSpeed.toStringAsFixed(1)),
          'max_speed_kmh': double.parse(widget.maxSpeed.toStringAsFixed(1)),
          'max_grade_percentage': double.parse(widget.maxGrade.toStringAsFixed(1)),
          'route_polyline': widget.encodedRoute,
          'start_time': DateTime.now().toIso8601String(),
          'start_temperature': widget.startTemp != null
              ? double.parse(widget.startTemp!.toStringAsFixed(1))
              : null,
          'file_hash': 'manual_${DateTime.now().millisecondsSinceEpoch}',
          'photos': uploadedPhotoUrls,
          'total_seconds': widget.totalSeconds,
          'athlete_name': 'Francisco Poyatos',
          'location': 'Brenes, Sevilla',
        }),
        Future.delayed(const Duration(milliseconds: 5000)),
      ]);

      if (mounted) {
        widget.onSuccess();
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child:
                  const Text('DESCARTAR', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      widget.onDiscard();
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

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        title: const Text('Finalizar Ruta',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1D24),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'GUARDAR ACTIVIDAD',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _confirmAndDiscard,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'DESCARTAR',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PremiumSavingScreen extends StatefulWidget {
  const PremiumSavingScreen({super.key});

  @override
  State<PremiumSavingScreen> createState() => _PremiumSavingScreenState();
}

class _PremiumSavingScreenState extends State<PremiumSavingScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;

  String _currentStepText = 'Ajustando métricas de la ruta...';

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _progressController.forward();

    _progressController.addListener(() {
      final value = _progressController.value;
      if (mounted) {
        setState(() {
          if (value < 0.3) {
            _currentStepText = 'Ajustando métricas de la ruta...';
          } else if (value < 0.6) {
            _currentStepText = 'Subiendo fotografías a la nube...';
          } else if (value < 0.85) {
            _currentStepText = 'Calculando desnivel y promedios...';
          } else {
            _currentStepText = '¡Actividad guardada con éxito!';
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      body: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFC5200).withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withOpacity(0.08),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFC5200).withOpacity(0.15),
                        border: Border.all(
                          color: const Color(0xFFFC5200).withOpacity(0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFC5200).withOpacity(0.3),
                            blurRadius: 25,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.cloud_upload_outlined,
                        color: Color(0xFFFC5200),
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'GUARDANDO ACTIVIDAD',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 25),
                  AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      final percentage =
                          (_progressAnimation.value * 100).toInt();

                      return Column(
                        children: [
                          SizedBox(
                            width: 130,
                            height: 130,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 130,
                                  height: 130,
                                  child: CircularProgressIndicator(
                                    value: _progressAnimation.value,
                                    strokeWidth: 8,
                                    backgroundColor: const Color(0xFF1A1D24),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                      Color(0xFFFC5200),
                                    ),
                                  ),
                                ),
                                Text(
                                  '$percentage%',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFFC5200),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 35),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      key: ValueKey<String>(_currentStepText),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1D24),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFC5200),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _currentStepText,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sincronizando con Supabase Cloud...',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
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