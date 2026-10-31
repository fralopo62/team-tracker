import os
import math
import hashlib
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from supabase import create_client, Client
import polyline

# Intenta importar gpxpy para procesar archivos GPX
try:
    import gpxpy
    import gpxpy.gpx
    HAS_GPXPY = True
except ImportError:
    HAS_GPXPY = False

# Importa tu parser de archivos FIT desde core_parser.py
try:
    from core_parser import parse_fit_bytes
except ImportError:
    parse_fit_bytes = None

app = FastAPI(
    title="TeamTracker API",
    description="Backend para gestión de actividades deportivas familiares",
    version="1.0.0"
)

# -----------------------------------------------------------------------------
# 1. Configuración de CORS
# -----------------------------------------------------------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# -----------------------------------------------------------------------------
# 2. Configuración de Supabase
# -----------------------------------------------------------------------------
SUPABASE_URL = os.getenv("SUPABASE_URL", "https://nksbxroquxrstakvnpbk.supabase.co")
SUPABASE_KEY = os.getenv("SUPABASE_KEY", "sb_publishable_aP8kSg0l5M_ZpRRZjTj-ew_SFt3Oibz")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)


def normalize_sport(sport_input: str) -> str:
    """
    Normaliza el deporte a los valores estándar de Supabase:
    'cycling', 'running', 'walking', 'windsurfing', 'other'
    """
    if not sport_input:
        return "cycling"
    
    s = str(sport_input).lower()
    
    if any(w in s for w in ["windsurf", "sailing", "water", "surf"]):
        return "windsurfing"
    elif any(w in s for w in ["andando", "caminata", "senderismo", "walk", "hiking", "paseo"]):
        return "walking"
    elif any(w in s for w in ["running", "carrera", "run", "correr"]):
        return "running"
    elif any(w in s for w in ["bici", "ciclismo", "cycling", "bike"]):
        return "cycling"
    
    return "other"


def haversine_distance(lat1, lon1, lat2, lon2):
    """Calcula la distancia precisa en metros entre dos coordenadas GPS"""
    R = 6371000  # Radio de la Tierra en metros
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)

    a = math.sin(dphi / 2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2)**2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def parse_gpx_content(content_bytes: bytes):
    """ Extrae coordenadas, desnivel, vel. media, vel. máxima y altitud máxima desde un GPX """
    if not HAS_GPXPY:
        raise HTTPException(
            status_code=400, 
            detail="La librería 'gpxpy' no está instalada en el servidor. Instálala con 'pip install gpxpy'."
        )
    
    gpx = gpxpy.parse(content_bytes.decode('utf-8', errors='ignore'))
    points = []
    total_ascent = 0.0
    last_elevation = None
    max_altitude = None
    start_time_dt = None
    end_time_dt = None
    
    max_speed_kmh = 0.0
    prev_point = None

    for track in gpx.tracks:
        for segment in track.segments:
            for p in segment.points:
                points.append((p.latitude, p.longitude))
                
                # 1. Altitud máxima y Desnivel positivo acumulado
                if p.elevation is not None:
                    if max_altitude is None or p.elevation > max_altitude:
                        max_altitude = p.elevation

                    if last_elevation is not None and p.elevation > last_elevation:
                        total_ascent += (p.elevation - last_elevation)
                    last_elevation = p.elevation

                # 2. Tiempos y velocidad máxima instantánea punto a punto
                if p.time:
                    if start_time_dt is None:
                        start_time_dt = p.time
                    end_time_dt = p.time

                    if prev_point and prev_point.time:
                        dt = (p.time - prev_point.time).total_seconds()
                        if dt > 0:
                            dist = haversine_distance(prev_point.latitude, prev_point.longitude, p.latitude, p.longitude)
                            inst_speed_kmh = (dist / dt) * 3.6
                            # Filtro para ignorar picos erróneos de cobertura GPS (>120 km/h)
                            if inst_speed_kmh > max_speed_kmh and inst_speed_kmh < 120:
                                max_speed_kmh = inst_speed_kmh
                    
                    prev_point = p
                
    if not points:
        raise HTTPException(status_code=400, detail="El archivo GPX no contiene puntos GPS válidos.")
    
    route_polyline = polyline.encode(points)
    length_m = gpx.length_2d() or 0.0
    distance_km = round(length_m / 1000.0, 2)
    
    # Velocidad media global
    avg_speed_kmh = 0.0
    moving_seconds = 0
    if start_time_dt and end_time_dt:
        duration_seconds = (end_time_dt - start_time_dt).total_seconds()
        if duration_seconds > 0:
            moving_seconds = int(duration_seconds)
            avg_speed_kmh = round((distance_km / (duration_seconds / 3600.0)), 2)

    start_time_str = start_time_dt.isoformat() if start_time_dt else (gpx.time.isoformat() if gpx.time else None)
        
    return {
        "polyline": route_polyline,
        "gps_points": len(points),
        "distance_km": distance_km,
        "moving_seconds": moving_seconds,
        "ascent_m": round(total_ascent, 1),
        "avg_speed_kmh": avg_speed_kmh,
        "max_speed_kmh": round(max_speed_kmh, 2),
        "max_altitude_m": round(max_altitude, 1) if max_altitude else None,
        "start_time": start_time_str
    }


# -----------------------------------------------------------------------------
# 3. Endpoints
# -----------------------------------------------------------------------------

@app.get("/")
async def serve_index():
    """ Sirve la interfaz web directamente desde el servidor local """
    if os.path.exists("index.html"):
        return FileResponse("index.html")
    return {"message": "TeamTracker API running. Place index.html in the root folder."}


@app.get("/api/v1/activities")
async def get_activities():
    """ Devuelve el listado de todas las actividades guardadas en Supabase """
    try:
        response = supabase.table("activities").select("*").order("start_time", desc=True).execute()
        return {"success": True, "data": response.data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error consultando Supabase: {str(e)}")


@app.post("/api/v1/process-activity")
async def process_activity(file: UploadFile = File(...)):
    """ Procesa un archivo .FIT o .GPX y lo guarda/actualiza en Supabase """
    filename = file.filename
    filename_lower = filename.lower()
    content = await file.read()
    
    # Calcular el hash MD5 del contenido del archivo
    file_hash = hashlib.md5(content).hexdigest()
    
    # Detección automática del deporte por el nombre del archivo
    detected_sport = "cycling"
    if any(k in filename_lower for k in ["caminata", "andando", "paseo", "senderismo", "walk"]):
        detected_sport = "walking"
    elif any(k in filename_lower for k in ["windsurf", "sailing", "surf"]):
        detected_sport = "windsurfing"
    elif any(k in filename_lower for k in ["carrera", "run", "correr"]):
        detected_sport = "running"
        
    sport_normalized = normalize_sport(detected_sport)
    
    parsed_data = None
    
    # Procesar según la extensión del archivo
    if filename_lower.endswith(".fit"):
        if parse_fit_bytes is None:
            raise HTTPException(
                status_code=500, 
                detail="Parser de archivos FIT no configurado. Asegúrate de instalar 'fitdecode' y tener 'core_parser.py'."
            )
        parsed_data = parse_fit_bytes(content)
    elif filename_lower.endswith(".gpx"):
        parsed_data = parse_gpx_content(content)
    else:
        raise HTTPException(status_code=400, detail="Formato de archivo no soportado. Usa .fit o .gpx")

    # Construir objeto completo para Supabase
    activity_record = {
        "title": filename,
        "sport": sport_normalized,
        "file_hash": file_hash,
        "distance_km": parsed_data.get("distance_km", 0.0),
        "moving_seconds": parsed_data.get("moving_seconds", 0),
        "avg_speed_kmh": parsed_data.get("avg_speed_kmh", 0.0),
        "max_speed_kmh": parsed_data.get("max_speed_kmh", 0.0),
        "max_altitude_m": parsed_data.get("max_altitude_m"),
        "ascent_m": parsed_data.get("ascent_m", 0.0),
        "gps_points": parsed_data.get("gps_points", 0),
        "route_polyline": parsed_data.get("polyline"),
        "start_time": parsed_data.get("start_time"),
        "family_id": None,
        "user_id": None
    }

    # Guardar o actualizar (upsert) en la tabla 'activities' de Supabase
    try:
        res = supabase.table("activities").upsert(activity_record, on_conflict="file_hash").execute()
        return {"success": True, "inserted": res.data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error guardando en Supabase: {str(e)}")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="127.0.0.1", port=8085, reload=True)