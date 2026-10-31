import os

def buscar_en_archivos():
    # Buscamos en la carpeta actual y subcarpetas
    for root, dirs, files in os.walk("."):
        # Ignoramos carpetas pesadas
        if ".git" in root or "build" in root or ".dart_tool" in root:
            continue
        for file in files:
            if file.endswith((".dart", ".js", ".ts", ".py", ".json")):
                ruta_completa = os.path.join(root, file)
                try:
                    with open(ruta_completa, "r", encoding="utf-8", errors="ignore") as f:
                        contenido = f.read()
                        if "activities" in contenido or "gps_points" in contenido:
                            print(f"🎯 ¡Encontrado en: {ruta_completa}")
                except Exception:
                    pass

if __name__ == "__main__":
    print("Buscando dónde se guardan las actividades en el código...")
    buscar_en_archivos()
with open("subir_masivo.py", "r", encoding="utf-8") as f:
    print(f.read())