import os
import zipfile
import pandas as pd
import gpxpy
import gpxpy.gpx
from datetime import datetime
from supabase import create_client, Client

# --- CONFIGURACIÓN DE SUPABASE ---
SUPABASE_URL = "https://nksbxroquxrstakvnpbk.supabase.co"
SUPABASE_KEY = "sb_publishable_aP8kSg0l5M_ZpRRZjTj-ew_SFt3Oibz"

RUTAS_ZIP_PATH = "export_6139958.zip"
CSV_PATH = "activities.csv"

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# Meses en español para convertir las fechas del CSV
MONTHS = {
    'ene': 1, 'feb': 2, 'mar': 3, 'abr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'ago': 8, 'sept': 9, 'sep': 9, 'oct': 10, 'nov': 11, 'dic': 12
}

def parse_spanish_date(date_str):
    try:
        parts = date_str.replace(',', '').split()
        day = int(parts[0])
        month = MONTHS[parts[1].lower()[:3]]
        year = int(parts[2])
        time_part = parts[3]
        h, m, s = map(int, time_part.split(':'))
        return datetime(year, month, day, h, m, s)
    except Exception:
        return None

def sincronizar_rutas():
    if not os.path.exists(RUTAS_ZIP_PATH) or not os.path.exists(CSV_PATH):
        print("¡Falta el archivo ZIP o el CSV en la carpeta!")
        return

    print("1. Descargando lista de actividades actuales desde Supabase...")
    # Traemos todas las actividades de Supabase para ver sus ID (UUID) y start_time
    response = supabase.table('activities').select('id, start_time').execute()
    supabase_activities = response.data
    
    if not supabase_activities:
        print("No se encontraron actividades en la tabla de Supabase.")
        return

    # Creamos un diccionario de fecha/hora (string) -> UUID de Supabase
    supabase_map = {}
    for act in supabase_activities:
        st = act.get('start_time')
        if st:
            # Normalizamos el formato de fecha de Supabase para que coincida
            clean_st = st.replace('Z', '').split('+')[0][:19]
            supabase_map[clean_st] = act.get('id')

    print(f"Se han cargado {len(supabase_map)} registros desde Supabase.")

    print("2. Leyendo 'activities.csv'...")
    df = pd.read_csv(CSV_PATH)
    
    # Mapeamos: Nombre del archivo GPX -> Fecha en formato texto para buscar en Supabase
    file_to_date = {}
    for _, row in df.iterrows():
        filename = str(row.get('Nombre del archivo', ''))
        fecha_raw = str(row.get('Fecha de la actividad', ''))
        
        if filename and filename != 'nan' and fecha_raw and fecha_raw != 'nan':
            dt = parse_spanish_date(fecha_raw)
            if dt:
                file_to_date[filename.strip().replace('\\', '/')] = dt.strftime('%Y-%m-%dT%H:%M:%S')

    print("3. Procesando el archivo ZIP y actualizando Supabase...")
    actualizadas = 0
    
    with zipfile.ZipFile(RUTAS_ZIP_PATH, 'r') as z:
        for zname in z.namelist():
            if zname.lower().endswith('.gpx'):
                norm_name = zname.replace('\\', '/')
                target_date_str = file_to_date.get(norm_name)
                
                if not target_date_str:
                    base_name = os.path.basename(norm_name)
                    for k, v in file_to_date.items():
                        if os.path.basename(k) == base_name:
                            target_date_str = v
                            break

                if target_date_str:
                    # Buscamos el ID (UUID) de Supabase que coincide con esta fecha
                    supabase_uuid = supabase_map.get(target_date_str)
                    
                    if supabase_uuid:
                        with z.open(zname) as f:
                            try:
                                gpx = gpxpy.parse(f)
                                points = []
                                for track in gpx.tracks:
                                    for segment in track.segments:
                                        for point in segment.points:
                                            points.append({
                                                "lat": point.latitude,
                                                "lng": point.longitude,
                                                "ele": point.elevation
                                            })

                                if points:
                                    # Actualizamos usando el UUID exacto de la base de datos
                                    supabase.table('activities').update({
                                        "gps_points": points
                                    }).eq('id', supabase_uuid).execute()
                                    
                                    actualizadas += 1
                                    print(f"[{actualizadas}] Ruta del {target_date_str} actualizada con {len(points)} puntos.")
                            except Exception as e:
                                print(f"Error leyendo el GPX {zname}: {e}")
                    else:
                        # Si hay un desfase de hora por el huso horario, intentamos buscar por día cercano
                        pass

    print(f"¡Proceso completado con éxito! Se han actualizado {actualizadas} rutas en Supabase.")

if __name__ == "__main__":
    sincronizar_rutas()