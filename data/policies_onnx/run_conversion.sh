#!/bin/bash

cd "$(dirname "$0")"

echo "Running DeepMimic to ONNX conversion..."

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Virtual environment not found. Running setup..."
    ./setup_environment.sh
fi

# Activate virtual environment
source venv/bin/activate

# Run the conversion
echo "Starting conversion process..."
python convert_to_onnx.py

echo "Conversion complete! ONNX models saved in current directory."
