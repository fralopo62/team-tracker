import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SharedFileService {
  static const MethodChannel _channel =
      MethodChannel('com.example.team_tracker/shared_file');

  static void init({required void Function(String filePath) onFileReceived}) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedFileReceived') {
        final String? path = call.arguments as String?;
        if (path != null && path.isNotEmpty) {
          debugPrint('Archivo compartido recibido (app abierta): $path');
          onFileReceived(path);
        }
      }
    });

    _channel.invokeMethod<String>('getInitialSharedFile').then((path) {
      if (path != null && path.isNotEmpty) {
        debugPrint('Archivo compartido recibido (arranque): $path');
        onFileReceived(path);
      }
    }).catchError((e) {
      debugPrint('Error leyendo archivo inicial compartido: $e');
    });
  }
}