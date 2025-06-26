#!/bin/bash
# Source this script to set up the DeepMimic environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Activate Python virtual environment
source "$SCRIPT_DIR/py/bin/activate"

# Set library paths for DeepMimic
export GLEW_LIB_DIR="$SCRIPT_DIR/libs/glew-2.1.0/lib"
export FREEGLUT_LIB_DIR="$SCRIPT_DIR/libs/freeglut-3.0.0/install/lib"
export BULLET_LIB_DIR="$SCRIPT_DIR/libs/bullet3-2.88/install/lib"
export LD_LIBRARY_PATH="$GLEW_LIB_DIR:$FREEGLUT_LIB_DIR:$BULLET_LIB_DIR:${LD_LIBRARY_PATH:-}"

# Enable legacy Keras for TensorFlow compatibility with DeepMimic
export TF_USE_LEGACY_KERAS=1

echo "✓ DeepMimic environment activated"
echo "  - Python virtual environment: $(which python3)"
echo "  - LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
echo "  - Legacy Keras enabled for TensorFlow compatibility"
echo ""
echo "You can now run DeepMimic commands, for example:"
echo "  python3 DeepMimic.py --arg_file args/run_humanoid3d_backflip_args.txt"
echo "  mpiexec -n 16 python3 DeepMimic_Optimizer.py --arg_file args/train_navi_idle_waiting1_fixed_args.txt"
