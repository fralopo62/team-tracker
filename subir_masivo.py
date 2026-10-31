import os
import glob
import hashlib
import gpxpy
import fitparse
import xml.etree.ElementTree as ET
from datetime import datetime
from supabase import create_client, Client

SUPABASE_URL = "https://nksbxroquxrstakvnpbk.supabase.co"
SUPABASE_KEY = "sb_publishable_aP8kSg0l5M_ZpRRZjTj-ew_SFt3Oibz"

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
CARPETA_GPX = "rutas_gpx"

def calcular_hash(filepath):
    hasher = hashlib.md5()
    with open(filepath, 'rb') as f:
        buf = f.read()
        hasher.update(buf)
    return hasher.hexdigest()

def encode_polyline(coordinates):
    """Codifica correctamente una lista de coordenadas (lat, lon) al estándar de polilíneas de Google/Leaflet."""
    result = []
    last_lat = 0
    last_lng = 0
    
    for lat, lng in coordinates:
        round_lat = int(round(lat * 1e5))
        round_lng = int(round(lng * 1e5))
        
        d_lat = round_lat - last_lat
        d_lng = round_lng - last_lng
        
        last_lat = round_lat
        last_lng = round_lng
        
        for val in (d_lat, d_lng):
            num = ~(val << 1) if val < 0 else (val << 1)
            while num >= 0x20:
                result.append(chr((0x20 | (num & 0x1f)) + 63))
                num >>= 5
            result.append(chr(num + 63))
            
    return "".join(result)

def formatear_titulo_por_defecto(start_time_str):
    """Genera un título elegante basado en la fecha si el archivo no trae nombre."""
    try:
        dt = datetime.fromisoformat(start_time_str.replace('Z', '+00:00'))
        meses = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
        return f"Salida en bici - {dt.day} {meses[dt.month - 1]} {dt.year}"
    except:
        return "Salida de Ciclismo"

def parsear_gpx(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
            if '<gpx' not in content.lower():
                raise ValueError("El archivo no contiene etiquetas GPX válidas")
        gpx = gpxpy.parse(content)
    except Exception as e:
        raise ValueError(f"GPX corrupto o inválido: {e}")
    
    route_title = None
    for track in gpx.tracks:
        if track.name:
            route_title = track.name.strip()
            break
    if not route_title and gpx.name:
        route_title = gpx.name.strip()

    start_time = None
    points = []
    for track in gpx.tracks:
        for segment in track.segments:
            for point in segment.points:
                if point.time and not start_time:
                    start_time = point.time.isoformat()
                if point.latitude is not None and point.longitude is not None:
                    points.append((point.latitude, point.longitude))

    distance = 0.0
    try:
        dist_3d = gpx.length_3d()
        dist_2d = gpx.length_2d()
        if dist_3d is not None and dist_3d > 0:
            distance = dist_3d / 1000.0
        elif dist_2d is not None:
            distance = dist_2d / 1000.0
    except:
        pass

    uphill, _ = gpx.get_uphill_downhill()
    elevation = uphill if uphill else 0.0
    
    duration = 0
    max_speed = 0.0
    try:
        moving_data = gpx.get_moving_data()
        if moving_data and moving_data.moving_time:
            duration = moving_data.moving_time
            if moving_data.max_speed:
                max_speed = moving_data.max_speed * 3.6
    except:
        pass

    all_elev = [p.elevation for t in gpx.tracks for s in t.segments for p in s.points if p.elevation is not None]
    max_elev = max(all_elev) if all_elev else 0.0
    avg_speed = (distance / (duration / 3600.0)) if duration > 0 else 0.0

    polyline_str = encode_polyline(points) if points else ""

    return {
        "title": route_title,
        "start_time": start_time or datetime.now().isoformat(),
        "distance": round(distance, 2),
        "elevation": round(elevation, 1),
        "duration": int(duration),
        "max_speed": round(max_speed, 1),
        "avg_speed": round(avg_speed, 1),
        "max_elevation": round(max_elev, 1),
        "route_polyline": polyline_str,
        "start_temperature": 0.0
    }

def parsear_fit(filepath):
    fitfile = fitparse.FitFile(filepath)
    distance = 0.0
    duration = 0
    elevation = 0.0
    max_speed = 0.0
    max_elev = 0.0
    start_time = None
    route_title = None
    
    distances = []
    altitudes = []
    speeds = []
    timestamps = []
    points = []

    try:
        for session in fitfile.get_messages('session'):
            s_data = session.get_values()
            if 'name' in s_data and s_data['name']:
                route_title = str(s_data['name']).strip()
            
            tot_dist = s_data.get('total_distance')
            if tot_dist is not None:
                try: distance = max(distance, float(tot_dist))
                except: pass

            tot_time = s_data.get('total_elapsed_time') or s_data.get('total_timer_time')
            if tot_time is not None:
                try: duration = max(duration, int(tot_time))
                except: pass

            tot_ascent = s_data.get('total_ascent')
            if tot_ascent is not None:
                try: elevation = max(elevation, float(tot_ascent))
                except: pass
    except Exception:
        pass

    try:
        for record in fitfile.get_messages('record'):
            data = record.get_values()
            ts = data.get('timestamp')
            if not start_time and ts:
                start_time = ts if isinstance(ts, str) else ts.isoformat()
            if ts:
                timestamps.append(ts)

            lat = data.get('position_lat')
            lon = data.get('position_long')
            if lat is not None and lon is not None:
                lat_deg = lat * (180 / 2**31)
                lon_deg = lon * (180 / 2**31)
                points.append((lat_deg, lon_deg))

            d = data.get('distance') or data.get('enhanced_distance')
            if d is not None:
                try: distances.append(float(d))
                except: pass

            alt = data.get('altitude') or data.get('enhanced_altitude')
            if alt is not None:
                try: altitudes.append(float(alt))
                except: pass

            spd = data.get('speed') or data.get('enhanced_speed')
            if spd is not None:
                try: speeds.append(float(spd))
                except: pass
    except Exception:
        pass

    if distance == 0.0 and distances:
        distance = max(distances)

    distance = distance / 1000.0

    if duration == 0 and len(timestamps) >= 2:
        try:
            diff = (timestamps[-1] - timestamps[0]).total_seconds()
            if diff > 0: duration = int(diff)
        except: pass

    if altitudes:
        max_elev = max(altitudes)
        if elevation == 0.0:
            uphill = 0.0
            for i in range(1, len(altitudes)):
                diff = altitudes[i] - altitudes[i-1]
                if diff > 0: uphill += diff
            elevation = uphill

    if speeds:
        max_speed = max(speeds) * 3.6

    avg_speed = (distance / (duration / 3600.0)) if duration > 0 else 0.0
    polyline_str = encode_polyline(points) if points else ""

    return {
        "title": route_title,
        "start_time": start_time or datetime.now().isoformat(),
        "distance": round(distance, 2),
        "elevation": round(elevation, 1),
        "duration": int(duration),
        "max_speed": round(max_speed, 1),
        "avg_speed": round(avg_speed, 1),
        "max_elevation": round(max_elev, 1),
        "route_polyline": polyline_str,
        "start_temperature": 0.0
    }

def parsear_tcx(filepath):
    try:
        with open(filepath, 'rb') as f:
            content = f.read()
        
        content = content.lstrip(b' \t\r\n\xef\xbb\xbf')
        idx = content.find(b'<')
        if idx > 0:
            content = content[idx:]
            
        root = ET.fromstring(content)
    except Exception as e:
        raise ValueError(f"Error al leer XML: {e}")
    
    start_time = None
    distance = 0.0
    duration = 0.0
    altitudes = []
    points = []
    route_title = None

    for elem in root.iter():
        tag = elem.tag.split('}')[-1] if '}' in elem.tag else elem.tag
        
        if tag == 'Name' and elem.text and not route_title:
            route_title = elem.text.strip()
        elif tag == 'Time' and not start_time and elem.text:
            start_time = elem.text
        elif tag == 'DistanceMeters' and elem.text:
            try:
                val = float(elem.text)
                if val > distance: distance = val
            except: pass
        elif tag == 'TotalTimeSeconds' and elem.text:
            try: duration = float(elem.text)
            except: pass
        elif tag == 'AltitudeMeters' and elem.text:
            try: altitudes.append(float(elem.text))
            except: pass
        elif tag == 'Position':
            lat_elem, lon_elem = None, None
            for child in elem:
                child_tag = child.tag.split('}')[-1] if '}' in child.tag else child.tag
                if child_tag == 'LatitudeDegrees': 
                    lat_elem = child.text
                elif child_tag == 'LongitudeDegrees': 
                    lon_elem = child.text
            if lat_elem and lon_elem:
                try: 
                    points.append((float(lat_elem), float(lon_elem)))
                except: pass

    distance = distance / 1000.0
    max_elev = max(altitudes) if altitudes else 0.0
    
    uphill = 0.0
    for i in range(1, len(altitudes)):
        diff = altitudes[i] - altitudes[i-1]
        if diff > 0: uphill += diff

    avg_speed = (distance / (duration / 3600.0)) if duration > 0 else 0.0
    polyline_str = encode_polyline(points) if points else ""

    return {
        "title": route_title,
        "start_time": start_time or datetime.now().isoformat(),
        "distance": round(distance, 2),
        "elevation": round(uphill, 1),
        "duration": int(duration),
        "max_speed": 0.0,
        "avg_speed": round(avg_speed, 1),
        "max_elevation": round(max_elev, 1),
        "route_polyline": polyline_str,
        "start_temperature": 0.0
    }

def subir_masivo():
    archivos = []
    for ext in ("*.gpx", "*.fit", "*.tcx", "*.GPX", "*.FIT", "*.TCX"):
        archivos.extend(glob.glob(os.path.join(CARPETA_GPX, ext)))

    total = len(archivos)
    if total == 0:
        print(f"No se encontraron archivos compatibles en '{CARPETA_GPX}'.")
        return

    print(f"\nProcesando los {total} archivos para actualizar sus títulos en Supabase...")

    exitosos = 0
    errores = 0

    for i, filepath in enumerate(archivos, 1):
        nombre_archivo = os.path.basename(filepath)
        ext = os.path.splitext(nombre_archivo)[1].lower()
        try:
            file_hash = hashlib.md5(nombre_archivo.encode('utf-8')).hexdigest()

            if ext == '.gpx': datos_ruta = parsear_gpx(filepath)
            elif ext == '.fit': datos_ruta = parsear_fit(filepath)
            elif ext == '.tcx': datos_ruta = parsear_tcx(filepath)
            else: continue

            # Comprobamos si el título interno existe y NO es puramente un número de ID
            titulo_interno = datos_ruta.get("title")
            if titulo_interno and not titulo_interno.isdigit():
                titulo_final = titulo_interno
            else:
                # Si el archivo no tiene nombre o el nombre es solo un número, ponemos la fecha elegante
                titulo_final = formatear_titulo_por_defecto(datos_ruta["start_time"])

            data = {
                "title": titulo_final,
                "sport": "Ciclismo",
                "file_hash": file_hash,
                "distance_km": datos_ruta["distance"],
                "moving_seconds": datos_ruta["duration"],
                "ascent_m": datos_ruta["elevation"],
                "avg_speed_kmh": datos_ruta["avg_speed"],
                "max_speed_kmh": datos_ruta["max_speed"],
                "max_elevation": datos_ruta["max_elevation"],
                "max_altitude_m": datos_ruta["max_elevation"],
                "route_polyline": datos_ruta["route_polyline"],
                "start_time": datos_ruta["start_time"],
                "start_temperature": datos_ruta["start_temperature"]
            }

            supabase.table('activities').upsert(data, on_conflict='file_hash').execute()
            exitosos += 1
            print(f"[{i}/{total}] ✅ Actualizado -> {nombre_archivo} | Título: {titulo_final}")

        except Exception as e:
            errores += 1
            error_msg = str(e).replace('\n', ' ')[:100]
            print(f"[{i}/{total}] ❌ Omitido por error en {nombre_archivo}: {error_msg}")

    print("\n--- RESUMEN FINAL ---")
    print(f"Total procesados/actualizados con éxito: {exitosos}")
    print(f"Total con errores/corruptos omitidos: {errores}")

if __name__ == "__main__":
    subir_masivo()