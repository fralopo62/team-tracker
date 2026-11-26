import 'package:supabase_flutter/supabase_flutter.dart';

class DbService {
  static final DbService instance = DbService._init();
  DbService._init();

  // Aquí puedes mantener los métodos habituales de tu base de datos si los necesitas,
  // eliminando por completo el código de exportación de archivos GPX.
  
  Future<List> obtenerActividades() async {
    List actividades = [];
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user != null) {
        final response = await supabase
            .from('activities')
            .select()
            .order('created_at', ascending: false);

        if (response != null && (response as List).isNotEmpty) {
          actividades = response;
        }
      }
    } catch (e) {
      print("❌ Error al consultar actividades: $e");
    }
    return actividades;
  }
}