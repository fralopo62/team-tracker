@echo off
cd /d "C:\Users\fralo\Downloads\Mi_Ciclismo_BC107_A1"
timeout /t 5 /nobreak > nul
start /b python -m uvicorn main:app --host 0.0.0.0 --port 8085