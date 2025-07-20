#!/bin/bash

echo "🔬 DeepMimic ONNX Validation Workflow"
echo "====================================="
echo ""

# Set paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICIES_DIR="/home/barberb/motion/DeepMimic/data/policies/humanoid3d"
ONNX_DIR="/home/barberb/motion/DeepMimic/data/policies_onnx"
VALIDATION_DIR="$ONNX_DIR/validation_results"

cd "$ONNX_DIR"

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "❌ Virtual environment not found. Please run setup first:"
    echo "   ./setup_environment.sh"
    exit 1
fi

# Activate virtual environment
echo "🐍 Activating Python environment..."
source venv/bin/activate

# Check if we have the required Python packages for validation
echo "📦 Checking Python dependencies..."
pip install -q onnxruntime

# Create validation results directory
mkdir -p "$VALIDATION_DIR"

echo ""
echo "📋 Available options:"
echo "1. Convert models to ONNX (if not done already)"
echo "2. Validate single model"
echo "3. Validate all models"
echo "4. Generate test data for JavaScript"
echo "5. Run complete workflow (convert + validate)"
echo ""

read -p "Select option (1-5): " choice

case $choice in
    1)
        echo "🔄 Converting TensorFlow models to ONNX..."
        python convert_to_onnx.py
        ;;
    2)
        echo "Available models:"
        ls -1 "$POLICIES_DIR"/*.ckpt.index | sed 's/.*\///' | sed 's/\.ckpt\.index$//' | nl -v1
        echo ""
        read -p "Enter model name (e.g., humanoid3d_walk): " model_name
        
        if [ -f "$POLICIES_DIR/${model_name}.ckpt.index" ]; then
            echo "🧪 Validating model: $model_name"
            python validate_models.py --model "$model_name"
        else
            echo "❌ Model not found: $model_name"
        fi
        ;;
    3)
        echo "🧪 Validating all models..."
        python validate_models.py
        ;;
    4)
        echo "📊 Generating JavaScript test data..."
        python validate_models.py
        echo ""
        echo "Test data generated in: $VALIDATION_DIR"
        echo "Files:"
        ls -la "$VALIDATION_DIR"/*.json | head -5
        ;;
    5)
        echo "🚀 Running complete workflow..."
        echo ""
        echo "Step 1: Converting models to ONNX..."
        python convert_to_onnx.py
        
        echo ""
        echo "Step 2: Validating all models..."
        python validate_models.py
        
        echo ""
        echo "✅ Complete workflow finished!"
        ;;
    *)
        echo "❌ Invalid option"
        exit 1
        ;;
esac

echo ""
echo "📁 Results saved to: $VALIDATION_DIR"

# Show summary if validation was run
if [ "$choice" = "3" ] || [ "$choice" = "5" ]; then
    echo ""
    echo "📊 Validation Summary:"
    if [ -f "$VALIDATION_DIR/validation_summary.json" ]; then
        python3 -c "
import json
with open('$VALIDATION_DIR/validation_summary.json', 'r') as f:
    data = json.load(f)
    
print(f\"Timestamp: {data['timestamp']}\")
print(f\"Total models: {len(data['models'])}\")

passed = sum(1 for status in data['models'].values() if status == 'PASS')
failed = sum(1 for status in data['models'].values() if status == 'FAIL')
errors = sum(1 for status in data['models'].values() if 'ERROR' in status)

print(f\"Passed: {passed}\")
print(f\"Failed: {failed}\")
print(f\"Errors: {errors}\")
print(f\"Success rate: {passed/len(data['models'])*100:.1f}%\")
print()
print(\"Individual results:\")
for model, status in data['models'].items():
    symbol = '✅' if status == 'PASS' else '❌' if status == 'FAIL' else '🚫'
    print(f\"  {symbol} {model}: {status}\")
"
    fi
fi

echo ""
echo "🌐 Next steps:"
echo "1. Start a web server to test JavaScript validation:"
echo "   cd /home/barberb/motion/dev/web_viewer/web_porting_poc/deepmimic"
echo "   python3 -m http.server 8080"
echo ""
echo "2. Open validation demo in browser:"
echo "   http://localhost:8080/validation_demo.html"
echo ""
echo "3. Load the generated ONNX models and validation data to test"
echo "   JavaScript inference against Python reference outputs"
