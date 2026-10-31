import io
import fitdecode
import polyline

def parse_fit_bytes(content_bytes: bytes):
    """
    Procesa un archivo .FIT y extrae resumen de datos:
    distancia, tiempo en movimiento, velocidad media/máxima, desnivel y altitud máxima.
    A prueba de tipos de tramas de fitdecode (FitHeader, FitDataMessage, etc.).
    """
    points = []
    total_ascent = 0.0
    last_altitude = None
    max_altitude = None
    max_speed_ms = 0.0
    avg_speed_kmh = 0.0
    distance_km = 0.0
    moving_seconds = 0
    start_time_str = None

    try:
        # fitdecode.FitReader acepta un stream de bytes en io.BytesIO
        with fitdecode.FitReader(io.BytesIO(content_bytes)) as fit:
            for frame in fit:
                # Verificar primero que sea un mensaje de datos
                if isinstance(frame, fitdecode.FitDataMessage):
                    
                    # 1. Tramas de Sesión (Resumen global)
                    if frame.name == 'session':
                        vals = {field.name: field.value for field in frame.fields if field.value is not None}
                        
                        if 'total_distance' in vals and isinstance(vals['total_distance'], (int, float)):
                            distance_km = round(vals['total_distance'] / 1000.0, 2)
                        if 'total_ascent' in vals and isinstance(vals['total_ascent'], (int, float)):
                            total_ascent = round(vals['total_ascent'], 1)
                        if 'avg_speed' in vals and isinstance(vals['avg_speed'], (int, float)):
                            avg_speed_kmh = round(vals['avg_speed'] * 3.6, 2)
                        if 'max_speed' in vals and isinstance(vals['max_speed'], (int, float)):
                            max_speed_kmh_session = vals['max_speed'] * 3.6
                            if max_speed_kmh_session < 120:
                                max_speed_ms = vals['max_speed']
                        if 'total_timer_time' in vals and isinstance(vals['total_timer_time'], (int, float)):
                            moving_seconds = int(vals['total_timer_time'])
                        if 'start_time' in vals:
                            start_time_str = str(vals['start_time'])

                    # 2. Tramas de Puntos GPS (Record)
                    elif frame.name == 'record':
                        vals = {field.name: field.value for field in frame.fields if field.value is not None}
                        
                        # Coordenadas GPS (Convertir Semicírculos a Grados decimales)
                        if 'position_lat' in vals and 'position_long' in vals:
                            lat_raw = vals['position_lat']
                            lon_raw = vals['position_long']
                            if isinstance(lat_raw, (int, float)) and isinstance(lon_raw, (int, float)):
                                lat = lat_raw * (180 / 2**31)
                                lon = lon_raw * (180 / 2**31)
                                if -90 <= lat <= 90 and -180 <= lon <= 180:
                                    points.append((lat, lon))

                        # Altitud Máxima y Desnivel
                        if 'altitude' in vals and isinstance(vals['altitude'], (int, float)):
                            alt = float(vals['altitude'])
                            if max_altitude is None or alt > max_altitude:
                                max_altitude = alt
                            
                            if total_ascent == 0.0 and last_altitude is not None:
                                if alt > last_altitude:
                                    total_ascent += (alt - last_altitude)
                            last_altitude = alt

                        # Velocidad máxima de respaldo punto a punto
                        if 'speed' in vals and isinstance(vals['speed'], (int, float)):
                            sp_ms = float(vals['speed'])
                            if sp_ms > max_speed_ms and (sp_ms * 3.6) < 120:
                                max_speed_ms = sp_ms

    except Exception as e:
        print(f"Error procesando archivo FIT: {e}")

    route_polyline = polyline.encode(points) if points else None
    max_speed_kmh = round(max_speed_ms * 3.6, 2)

    return {
        "polyline": route_polyline,
        "gps_points": len(points),
        "distance_km": distance_km,
        "moving_seconds": moving_seconds,
        "ascent_m": round(total_ascent, 1),
        "avg_speed_kmh": avg_speed_kmh,
        "max_speed_kmh": max_speed_kmh,
        "max_altitude_m": round(max_altitude, 1) if max_altitude is not None else None,
        "start_time": start_time_str
    }