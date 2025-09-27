#!/bin/bash

echo "🚀 Starting Stock Tracker Pro..."
echo "📈 Opening http://localhost:8000 in your browser"
echo "💡 Press Ctrl+C to stop the server"
echo ""

# Check if Python 3 is available
if command -v python3 &> /dev/null; then
    python3 -m http.server 8000
elif command -v python &> /dev/null; then
    python -m http.server 8000
else
    echo "❌ Python not found. Please install Python to run the server."
    exit 1
fi