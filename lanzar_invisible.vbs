Set WshShell = CreateObject("WScript.Shell")
WshShell.CurrentDirectory = "C:\Users\fralo\Downloads\Mi_Ciclismo_BC107_A1"
WshShell.Run "cmd /c python -m uvicorn main:app --host 0.0.0.0 --port 8085", 0, False