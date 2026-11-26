import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  int _totalActivities = 0;
  double _totalDistanceKm = 0;
  int _totalSeconds = 0;
  double _totalAscentM = 0;
  double _averageSpeedKmh = 0;
  double _maxDistanceKm = 0;
  String _maxDistanceTitle = '';
  String _favoriteSport = 'Bicicleta';
  String? _avatarUrl;

  static const String _forcedUserId = '059e1360-3927-4fd4-a481-9bd65f6a14db';

  @override
  void initState() {
    super.initState();
    _loadGlobalStatsAndProfile();
  }

  Future<void> _loadGlobalStatsAndProfile() async {
    final supabase = Supabase.instance.client;

    try {
      // Recuperamos el avatar guardado en los metadatos del usuario
      final metaAvatar = supabase.auth.currentUser?.userMetadata?['avatar_url'];
      if (metaAvatar != null && metaAvatar.toString().isNotEmpty) {
        _avatarUrl = metaAvatar.toString();
      }

      List<dynamic> allActivities = [];
      int offset = 0;
      const int limit = 1000;
      bool fetchMore = true;

      while (fetchMore) {
        final response = await supabase
            .from('activities')
            .select('*')
            .eq('user_id', _forcedUserId)
            .range(offset, offset + limit - 1);

        final List<dynamic> batch = response;
        allActivities.addAll(batch);

        if (batch.length < limit) {
          fetchMore = false;
        } else {
          offset += limit;
        }
      }

      int count = allActivities.length;
      double distanceSum = 0;
      int secondsSum = 0;
      double ascentSum = 0;
      double speedSum = 0;
      int speedCount = 0;
      double maxDist = 0;
      String maxDistName = '';
      Map<String, int> sportCounts = {};

      for (var act in allActivities) {
        final distVal = (act['distance_km'] ?? act['distance'] ?? 0) as num;
        final double distInKm =
            distVal > 100 ? distVal.toDouble() / 1000.0 : distVal.toDouble();
        distanceSum += distInKm;

        if (distInKm > maxDist) {
          maxDist = distInKm;
          maxDistName = act['title']?.toString() ?? '';
        }

        final durVal = (act['moving_seconds'] ??
            act['total_seconds'] ??
            act['duration'] ??
            0) as num;
        secondsSum += durVal.toInt();

        final ascentVal = (act['ascent_m'] ?? 0) as num;
        ascentSum += ascentVal.toDouble();

        final speedVal =
            (act['avg_speed_kmh'] ?? act['avg_speed'] ?? 0) as num;
        if (speedVal > 0) {
          speedSum += speedVal.toDouble();
          speedCount++;
        }

        final sport = act['sport']?.toString() ?? 'Ciclismo';
        sportCounts[sport] = (sportCounts[sport] ?? 0) + 1;
      }

      if (secondsSum <= 0 && distanceSum > 0) {
        secondsSum = ((distanceSum / 15.0) * 3600).round();
      }

      final double avgSpeed = speedCount > 0 ? (speedSum / speedCount) : 0.0;

      String favorite = 'Ciclismo';
      int maxCount = -1;
      sportCounts.forEach((sport, c) {
        if (c > maxCount) {
          maxCount = c;
          favorite = sport;
        }
      });

      if (mounted) {
        setState(() {
          _totalActivities = count;
          _totalDistanceKm = distanceSum;
          _totalSeconds = secondsSum;
          _totalAscentM = ascentSum;
          _averageSpeedKmh = avgSpeed;
          _maxDistanceKm = maxDist;
          _maxDistanceTitle = maxDistName;
          _favoriteSport = favorite;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar perfil y estadísticas: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _changeAvatarImage(AppStrings strings) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(strings.uploadingAvatar),
              backgroundColor: Colors.blueAccent,
            ),
          );
        }

        final supabase = Supabase.instance.client;
        final file = File(image.path);
        final fileExt = image.path.split('.').last;
        final fileName =
            'avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        await supabase.storage.from('activity_photos').upload(
              fileName,
              file,
              fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
            );

        final String signedUrl = await supabase.storage
            .from('activity_photos')
            .createSignedUrl(fileName, 60 * 60 * 24 * 365);

        await supabase.auth.updateUser(
          UserAttributes(
            data: {'avatar_url': signedUrl},
          ),
        );

        if (!mounted) return;

        setState(() {
          _avatarUrl = signedUrl;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.avatarUpdated),
            backgroundColor: const Color(0xFFFC5200),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.avatarError(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _setLanguage(String code) {
    appLocaleNotifier.value = Locale(code);
  }

  String _formatTotalTime(int seconds) {
    if (seconds <= 0) return '0m';
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color iconColor, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLanguageChip(String label, String code, bool isSelected) {
    return GestureDetector(
      onTap: () => _setLanguage(code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFC5200) : const Color(0xFF252A34),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFC5200)
                : Colors.white.withOpacity(0.12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade300,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    const userEmail = 'k2francisco@gmail.com';
    final recordSubtitle = _maxDistanceTitle.trim().isEmpty
        ? strings.noTitleRoute
        : _maxDistanceTitle.trim();

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        title: Text(
          strings.myProfile,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1A1D24),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFC5200)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _changeAvatarImage(strings),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: const Color(0xFF1A1D24),
                          backgroundImage:
                              (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                                  ? NetworkImage(_avatarUrl!)
                                  : null,
                          child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                              ? const Icon(Icons.person,
                                  size: 50, color: Color(0xFFFC5200))
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFC5200),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    userEmail,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Brenes, Sevilla',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1D24),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.language,
                                color: Color(0xFFFC5200), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              strings.languageLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            _buildLanguageChip('ES', 'es', !strings.isGerman),
                            const SizedBox(width: 8),
                            _buildLanguageChip('DE', 'de', strings.isGerman),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      strings.globalStats,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.25,
                    children: [
                      _buildStatCard(
                        strings.statActivities,
                        _totalActivities.toString(),
                        Icons.bolt,
                        Colors.orange,
                      ),
                      _buildStatCard(
                        strings.statTotalDistance,
                        '${_totalDistanceKm.toStringAsFixed(1)} km',
                        Icons.straighten,
                        Colors.blue,
                      ),
                      _buildStatCard(
                        strings.statMovingTime,
                        _formatTotalTime(_totalSeconds),
                        Icons.timer,
                        Colors.green,
                      ),
                      _buildStatCard(
                        strings.statElevationGain,
                        '${_totalAscentM.toStringAsFixed(0)} m',
                        Icons.terrain,
                        Colors.purpleAccent,
                      ),
                      _buildStatCard(
                        strings.statAvgSpeed,
                        '${_averageSpeedKmh.toStringAsFixed(1)} km/h',
                        Icons.speed,
                        Colors.redAccent,
                      ),
                      _buildStatCard(
                        strings.statMaxDistance,
                        '${_maxDistanceKm.toStringAsFixed(1)} km',
                        Icons.emoji_events,
                        Colors.amber,
                        subtitle: recordSubtitle,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Supabase.instance.client.auth.signOut();
                        SystemNavigator.pop();
                      },
                      icon: const Icon(Icons.exit_to_app, color: Colors.white),
                      label: Text(
                        strings.signOutAndExit,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}