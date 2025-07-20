#!/bin/bash

echo "Setting up DeepMimic ONNX conversion environment..."

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip

# Install requirements
echo "Installing Python dependencies..."
pip install -r requirements.txt

echo "Environment setup complete!"
echo ""
echo "To run the ONNX conversion:"
echo "1. source venv/bin/activate"
echo "2. python convert_to_onnx.py"
echo ""
echo "Or run the conversion directly:"
echo "./run_conversion.sh"
