from core_parser import process_file
from supabase_client import supabase

print("1. Cliente Supabase inicializado correctamente:", supabase is not None)
print("2. Motor de parseo listo para procesar rutas.")