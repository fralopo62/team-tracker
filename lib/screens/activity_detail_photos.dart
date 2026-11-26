import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActivityDetailPhotos extends StatefulWidget {
  final dynamic activityId;
  final List initialPhotos;

  const ActivityDetailPhotos({
    super.key,
    required this.activityId,
    required this.initialPhotos,
  });

  @override
  State<ActivityDetailPhotos> createState() => _ActivityDetailPhotosState();
}

class _ActivityDetailPhotosState extends State<ActivityDetailPhotos> {
  late List _photos;

  @override
  void initState() {
    super.initState();
    _photos = List.from(widget.initialPhotos);
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

        if (widget.activityId != null) {
          await supabase.from('activities').update({
            'photos': _photos,
          }).eq('id', widget.activityId);
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
            backgroundColor: Colors.red,
          ),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Fotos y Recuerdos de la Ruta',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt, color: Color(0xFFFC5200)),
                  tooltip: 'Hacer foto',
                ),
                IconButton(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(
                    Icons.photo_library,
                    color: Colors.lightBlueAccent,
                  ),
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
                final photoUrl = _photos[index].toString();
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
                                        fontSize: 7,
                                        color: Colors.white,
                                      ),
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
      ],
    );
  }
}