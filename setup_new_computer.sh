#!/bin/bash

# Caption5 Setup Script for New Computers
# Run this script on a new computer to set up Caption5

echo "🚀 Setting up Caption5 on this computer..."

# Check if Git is installed
if ! command -v git &> /dev/null; then
    echo "❌ Git is not installed. Please install Git first:"
    echo "   macOS: brew install git (or download from git-scm.com)"
    echo "   Windows: Download from git-scm.com"
    echo "   Linux: sudo apt-get install git (Ubuntu/Debian) or sudo yum install git (CentOS/RHEL)"
    exit 1
fi

echo "✅ Git is installed"

# Check if Python is installed
if ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
    echo "❌ Python is not installed. Please install Python 3.8+ first:"
    echo "   macOS: brew install python3 (or download from python.org)"
    echo "   Windows: Download from python.org"
    echo "   Linux: sudo apt-get install python3 python3-pip (Ubuntu/Debian)"
    exit 1
fi

echo "✅ Python is installed"

# Determine Python command
PYTHON_CMD=""
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
fi

echo "📋 Using Python command: $PYTHON_CMD"

# Check if we're already in the caption directory
if [ -f "captionStable.py" ]; then
    echo "✅ Already in Caption5 directory"
else
    echo "📥 Cloning Caption5 repository..."
    
    # Clone the repository
    if git clone https://github.com/joyfuladam/caption.git; then
        echo "✅ Repository cloned successfully"
        cd caption
    else
        echo "❌ Failed to clone repository"
        exit 1
    fi
fi

# Check if requirements.txt exists
if [ ! -f "requirements.txt" ]; then
    echo "❌ requirements.txt not found. Please check the repository."
    exit 1
fi

echo "📦 Installing Python dependencies..."
if $PYTHON_CMD -m pip install -r requirements.txt; then
    echo "✅ Dependencies installed successfully"
else
    echo "⚠️  Some dependencies may have failed to install. You can try:"
    echo "   $PYTHON_CMD -m pip install --user -r requirements.txt"
fi

echo ""
echo "🎉 Caption5 setup complete!"
echo ""
echo "📋 Next steps:"
echo "   1. Run the application: $PYTHON_CMD captionStable.py"
echo "   2. For updates, use: ./update_app.sh"
echo "   3. Check README.md for more information"
echo ""
echo "🚀 Ready to start captioning!"
