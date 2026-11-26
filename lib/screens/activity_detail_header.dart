import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String _sportEmojiForShare(String? rawSport, String title) {
  final combined = '${rawSport ?? ''} $title'
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

  if (combined.contains('sender') ||
      combined.contains('trek') ||
      combined.contains('hik') ||
      combined.contains('wander')) {
    return '🥾';
  }
  if (combined.contains('camin') ||
      combined.contains('andar') ||
      combined.contains('walk') ||
      combined.contains('spazier')) {
    return '🚶‍♂️';
  }
  if (combined.contains('run') ||
      combined.contains('corr') ||
      combined.contains('trail') ||
      combined.contains('lauf')) {
    return '🏃‍♂️';
  }
  if (combined.contains('natac') ||
      combined.contains('swim') ||
      combined.contains('schwimm')) {
    return '🏊‍♂️';
  }
  if (combined.contains('windsurf') || combined.contains('surf')) {
    return '🏄‍♂️';
  }
  if (combined.contains('remo') ||
      combined.contains('row') ||
      combined.contains('ruder')) {
    return '🚣‍♂️';
  }
  if (combined.contains('gimnas') ||
      combined.contains('gym') ||
      combined.contains('eliptic') ||
      combined.contains('cross') ||
      combined.contains('fitness')) {
    return '🏋️‍♂️';
  }
  return '🚴‍♂️';
}

class ActivityDetailAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final Map activity;
  final String currentTitle;
  final Function(String) onTitleUpdated;
  final Function(String)? onSportUpdated;
  final VoidCallback onDeleted;
  final Future<File?> Function()? onGenerateShareImage;

  const ActivityDetailAppBar({
    super.key,
    required this.activity,
    required this.currentTitle,
    required this.onTitleUpdated,
    this.onSportUpdated,
    required this.onDeleted,
    this.onGenerateShareImage,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  static const List<String> _sportOptions = [
    'Ciclismo',
    'senderismo',
    'caminar',
    'Running',
    'Natación',
    'Windsurf',
    'Remo',
    'Gimnasio',
    'Elíptica',
  ];

  String _initialSportValue() {
    final raw = (activity['sport'] ??
            activity['sport_type'] ??
            activity['activity_type'] ??
            activity['type'] ??
            'Ciclismo')
        .toString()
        .trim();
    if (raw.isEmpty) return 'Ciclismo';

    for (final option in _sportOptions) {
      if (option.toLowerCase() == raw.toLowerCase()) {
        return option;
      }
    }
    return raw;
  }

  Future<void> _shareActivityWithImage(BuildContext context) async {
    try {
      final activityId = activity['id']?.toString() ?? '';
      final String appDeepLink =
          'https://fralopo62.github.io/team-tracker/activity?id=$activityId';

      final String currentSportValue = (activity['sport'] ??
              activity['sport_type'] ??
              activity['activity_type'] ??
              activity['type'] ??
              activity['deporte'] ??
              '')
          .toString();
      final String emoji = _sportEmojiForShare(currentSportValue, currentTitle);

      final String shareText = '''
$emoji *$currentTitle*
$appDeepLink
''';

      File? generatedCard;
      if (onGenerateShareImage != null) {
        generatedCard = await onGenerateShareImage!();
      }

      if (generatedCard != null && await generatedCard.exists()) {
        await Share.shareXFiles(
          [XFile(generatedCard.path)],
          text: shareText,
        );
        return;
      }

      final storedPhotos = activity['photos'];
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editActivityTitle(BuildContext context) async {
    final TextEditingController editController =
        TextEditingController(text: currentTitle);
    String selectedSport = _initialSportValue();

    final List<String> dropdownItems = _sportOptions.contains(selectedSport)
        ? _sportOptions
        : [selectedSport, ..._sportOptions];

    Map<String, String>? editedResult;

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1D24),
              title: const Text(
                'Editar Actividad',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: editController,
                      autofocus: true,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF252A34),
                        labelText: 'Nombre de la ruta',
                        labelStyle: const TextStyle(color: Colors.grey),
                        hintText: 'Escribe el nuevo nombre...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Deporte',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedSport,
                      dropdownColor: const Color(0xFF252A34),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF252A34),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: dropdownItems
                          .map(
                            (sport) => DropdownMenuItem<String>(
                              value: sport,
                              child: Text(sport),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedSport = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'CANCELAR',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFC5200),
                  ),
                  onPressed: () {
                    editedResult = {
                      'title': editController.text.trim(),
                      'sport': selectedSport,
                    };
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text(
                    'GUARDAR',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (editedResult == null) return;

    final String newTitle = (editedResult!['title'] ?? '').trim();
    final String newSport = (editedResult!['sport'] ?? selectedSport).trim();
    final String oldSport = _initialSportValue();

    final bool titleChanged = newTitle.isNotEmpty && newTitle != currentTitle;
    final bool sportChanged = newSport.isNotEmpty && newSport != oldSport;

    if (!titleChanged && !sportChanged) return;

    final Map<String, dynamic> updatePayload = {};
    if (titleChanged) {
      updatePayload['title'] = newTitle;
    }
    if (sportChanged) {
      updatePayload['sport'] = newSport;
    }

    try {
      final supabase = Supabase.instance.client;
      final activityId = activity['id'];

      if (activityId != null) {
        await supabase
            .from('activities')
            .update(updatePayload)
            .eq('id', activityId);

        if (titleChanged) {
          activity['title'] = newTitle;
          onTitleUpdated(newTitle);
        }
        if (sportChanged) {
          activity['sport'] = newSport;
          onSportUpdated?.call(newSport);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Actividad actualizada correctamente.'),
              backgroundColor: Color(0xFFFC5200),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar actividad: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmAndDeleteActivity(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1D24),
          title: const Text(
            'Eliminar Actividad',
            style: TextStyle(color: Colors.white),
          ),
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
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
        final activityId = activity['id'];

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
          onDeleted();
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

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        currentTitle,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      backgroundColor: const Color(0xFF1A1D24),
      actions: [
        IconButton(
          icon: const Icon(Icons.share, color: Color(0xFFFC5200)),
          tooltip: 'Compartir en WhatsApp',
          onPressed: () => _shareActivityWithImage(context),
        ),
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.grey),
          tooltip: 'Editar actividad',
          onPressed: () => _editActivityTitle(context),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          tooltip: 'Eliminar actividad',
          onPressed: () => _confirmAndDeleteActivity(context),
        ),
      ],
    );
  }
}

class ActivityAthleteHeaderCard extends StatelessWidget {
  final String athleteName;
  final String? avatarUrl;
  final String locationName;

  const ActivityAthleteHeaderCard({
    super.key,
    required this.athleteName,
    required this.avatarUrl,
    required this.locationName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                ? NetworkImage(avatarUrl!)
                : null,
            child: (avatarUrl == null || avatarUrl!.isEmpty)
                ? const Icon(Icons.person, color: Color(0xFFFC5200), size: 26)
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
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 12,
                      color: Color(0xFFFC5200),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      locationName,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}