@echo off
echo 🚀 Starting Stock Tracker Pro...
echo 📈 Opening http://localhost:8000 in your browser
echo 💡 Press Ctrl+C to stop the server
echo.

REM Check if Python is available
python --version >nul 2>&1
if %ERRORLEVEL% == 0 (
    python -m http.server 8000
) else (
    echo ❌ Python not found. Please install Python to run the server.
    pause
)