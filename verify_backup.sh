#!/bin/bash

# Caption3B Backup Verification Script
# This script verifies that all necessary files are present in the backup

set -e

echo "🔍 Caption3B Backup Verification"
echo "================================"
echo ""

BACKUP_DIR="$(pwd)"
echo "Verifying backup in: $BACKUP_DIR"
echo ""

# Define required files
REQUIRED_FILES=(
    "captionStable_docker.py"
    "requirements.txt"
    "config.json"
    "dictionary.json"
    "user_settings.json"
    "Dockerfile"
    "docker-compose.yml"
    "docker-audio-setup.sh"
    "asound.conf"
    "root.html"
    "user.html"
    "dashboard.html"
    "setup.html"
    "dictionary_page.html"
    "test_audio_simple.py"
    "test_audio_levels.py"
    "README.md"
    "README_DOCKER.md"
    "BACKUP_README.md"
    "restore_backup.sh"
)

# Define optional files
OPTIONAL_FILES=(
    "captionStable.py"
    "schedule.json"
    "launch.sh"
    "launch.bat"
    "docker-run.sh"
    "CHANGELOG_SESSION.md"
    "captioning.code-workspace"
)

echo "📋 Checking required files..."
echo ""

MISSING_FILES=()
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file (MISSING)"
        MISSING_FILES+=("$file")
    fi
done

echo ""
echo "📋 Checking optional files..."
echo ""

for file in "${OPTIONAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "⚠️  $file (not present)"
    fi
done

echo ""
echo "🔍 Checking file integrity..."

# Check if main Python file is valid
if [ -f "captionStable_docker.py" ]; then
    if python3 -m py_compile "captionStable_docker.py" 2>/dev/null; then
        echo "✅ captionStable_docker.py syntax is valid"
    else
        echo "❌ captionStable_docker.py has syntax errors"
    fi
fi

# Check if Docker Compose file is valid
if [ -f "docker-compose.yml" ]; then
    if docker-compose config >/dev/null 2>&1; then
        echo "✅ docker-compose.yml is valid"
    else
        echo "❌ docker-compose.yml has errors"
    fi
fi

# Check if JSON files are valid
for json_file in config.json dictionary.json user_settings.json; do
    if [ -f "$json_file" ]; then
        if python3 -c "import json; json.load(open('$json_file'))" 2>/dev/null; then
            echo "✅ $json_file is valid JSON"
        else
            echo "❌ $json_file has invalid JSON"
        fi
    fi
done

echo ""
echo "📊 Backup Summary"
echo "================="

if [ ${#MISSING_FILES[@]} -eq 0 ]; then
    echo "✅ All required files are present"
    echo "✅ Backup is complete and ready for restoration"
    echo ""
    echo "🚀 To restore this backup:"
    echo "   ./restore_backup.sh"
    echo ""
    echo "📖 For detailed instructions:"
    echo "   cat BACKUP_README.md"
else
    echo "❌ Missing required files:"
    for file in "${MISSING_FILES[@]}"; do
        echo "   - $file"
    done
    echo ""
    echo "⚠️  Backup is incomplete. Please ensure all required files are present."
fi

echo ""
echo "📁 Backup directory size:"
du -sh . 2>/dev/null || echo "Unable to determine size"

echo ""
echo "🔍 Verification complete!" 