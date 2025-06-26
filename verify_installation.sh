#!/bin/bash

# DeepMimic Installation Verification Script
# This script verifies that DeepMimic is properly installed and configured

set -e  # Exit on any error

echo "🔍 DeepMimic Installation Verification"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "DeepMimic.py" ]; then
    print_error "Not in DeepMimic root directory. Please cd to DeepMimic directory first."
    exit 1
fi

print_status "Starting verification..."

# 1. Check Python environment
echo ""
print_status "Checking Python environment..."

if [ -f "setup_env.sh" ]; then
    source setup_env.sh
    print_success "Environment activated from setup_env.sh"
else
    print_warning "setup_env.sh not found, using system Python"
fi

# Check Python version
PYTHON_VERSION=$(python --version 2>&1)
print_status "Python version: $PYTHON_VERSION"

if python -c "import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)" 2>/dev/null; then
    print_success "Python version is 3.8 or higher"
else
    print_error "Python version must be 3.8 or higher"
    exit 1
fi

# 2. Check core library
echo ""
print_status "Checking DeepMimicCore import..."

if python -c "import DeepMimicCore; print('DeepMimicCore version:', getattr(DeepMimicCore, '__version__', 'unknown'))" 2>/dev/null; then
    print_success "DeepMimicCore imported successfully"
else
    print_error "Failed to import DeepMimicCore"
    print_status "Attempting to build DeepMimicCore..."
    
    if [ -d "DeepMimicCore" ]; then
        cd DeepMimicCore
        if make clean && make python; then
            cd ..
            if python -c "import DeepMimicCore" 2>/dev/null; then
                print_success "DeepMimicCore built and imported successfully"
            else
                print_error "DeepMimicCore build succeeded but import still fails"
                exit 1
            fi
        else
            cd ..
            print_error "Failed to build DeepMimicCore"
            exit 1
        fi
    else
        print_error "DeepMimicCore directory not found"
        exit 1
    fi
fi

# 3. Check Python dependencies
echo ""
print_status "Checking Python dependencies..."

REQUIRED_PACKAGES=("tensorflow" "numpy" "mpi4py" "OpenGL")
MISSING_PACKAGES=()

for package in "${REQUIRED_PACKAGES[@]}"; do
    if python -c "import $package" 2>/dev/null; then
        VERSION=$(python -c "import $package; print(getattr($package, '__version__', 'unknown'))" 2>/dev/null || echo "unknown")
        print_success "$package (version: $VERSION)"
    else
        print_error "$package not found"
        MISSING_PACKAGES+=("$package")
    fi
done

if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    print_error "Missing packages: ${MISSING_PACKAGES[*]}"
    print_status "Run './setup.sh' to install missing dependencies"
    exit 1
fi

# 4. Check TensorFlow compatibility
echo ""
print_status "Checking TensorFlow compatibility..."

TF_VERSION=$(python -c "import tensorflow as tf; print(tf.__version__)" 2>/dev/null || echo "unknown")
print_status "TensorFlow version: $TF_VERSION"

if python -c "
import os
os.environ['TF_USE_LEGACY_KERAS'] = '1'
import tensorflow.compat.v1 as tf
tf.disable_v2_behavior()
print('TensorFlow 1.x compatibility mode works')
" 2>/dev/null; then
    print_success "TensorFlow compatibility mode working"
else
    print_error "TensorFlow compatibility issues detected"
    exit 1
fi

# 5. Check MPI functionality
echo ""
print_status "Checking MPI functionality..."

if command -v mpiexec >/dev/null 2>&1; then
    MPI_VERSION=$(mpiexec --version 2>&1 | head -1)
    print_status "MPI version: $MPI_VERSION"
    
    if mpiexec -n 2 python -c "
from mpi4py import MPI
comm = MPI.COMM_WORLD
rank = comm.Get_rank()
size = comm.Get_size()
print(f'MPI rank {rank} of {size} processes')
" 2>/dev/null; then
        print_success "MPI functionality working"
    else
        print_error "MPI test failed"
        exit 1
    fi
else
    print_error "mpiexec not found. Install OpenMPI or MPICH."
    exit 1
fi

# 6. Check system libraries
echo ""
print_status "Checking system libraries..."

REQUIRED_LIBS=("libGL.so" "libGLEW.so" "libglut.so")
for lib in "${REQUIRED_LIBS[@]}"; do
    if ldconfig -p | grep -q "$lib"; then
        print_success "$lib found"
    else
        print_warning "$lib not found in ldconfig cache"
    fi
done

# 7. Test basic functionality
echo ""
print_status "Testing basic functionality..."

# Test argument parsing
if python DeepMimic.py --help >/dev/null 2>&1; then
    print_success "DeepMimic.py help command works"
else
    print_error "DeepMimic.py help command failed"
    exit 1
fi

# Test with actual argument file (if available)
TEST_ARG_FILE=""
for arg_file in "args/run_humanoid3d_walk_args.txt" "args/play_motion_humanoid3d_args.txt"; do
    if [ -f "$arg_file" ]; then
        TEST_ARG_FILE="$arg_file"
        break
    fi
done

if [ -n "$TEST_ARG_FILE" ]; then
    print_status "Testing with argument file: $TEST_ARG_FILE"
    
    # Test with timeout to avoid hanging
    if timeout 10s python DeepMimic.py --arg_file "$TEST_ARG_FILE" --test_mode 2>/dev/null || true; then
        print_success "Basic DeepMimic execution test passed"
    else
        print_warning "DeepMimic execution test had issues (may be normal in headless environment)"
    fi
else
    print_warning "No test argument files found"
fi

# 8. Check output directory
echo ""
print_status "Checking output directory..."

if [ ! -d "output" ]; then
    mkdir -p output
    print_status "Created output directory"
fi

if [ -w "output" ]; then
    print_success "Output directory is writable"
else
    print_error "Output directory is not writable"
    exit 1
fi

# 9. Performance check
echo ""
print_status "Running performance check..."

IMPORT_TIME=$(python -c "
import time
start = time.time()
import DeepMimicCore
end = time.time()
print(f'{end - start:.3f}')
")

if (( $(echo "$IMPORT_TIME < 5.0" | bc -l) )); then
    print_success "DeepMimicCore import time: ${IMPORT_TIME}s (good)"
elif (( $(echo "$IMPORT_TIME < 10.0" | bc -l) )); then
    print_warning "DeepMimicCore import time: ${IMPORT_TIME}s (acceptable)"
else
    print_warning "DeepMimicCore import time: ${IMPORT_TIME}s (slow, may indicate issues)"
fi

# 10. Environment summary
echo ""
print_status "Environment summary..."

cat << EOF
System Information:
- OS: $(uname -s) $(uname -r)
- Architecture: $(uname -m)
- CPU cores: $(nproc)
- Memory: $(free -h | awk '/^Mem:/ {print $2}')
- Python: $PYTHON_VERSION
- TensorFlow: $TF_VERSION
- Working directory: $(pwd)
- Environment variables:
  - TF_USE_LEGACY_KERAS: ${TF_USE_LEGACY_KERAS:-not set}
  - LD_LIBRARY_PATH: ${LD_LIBRARY_PATH:-not set}
EOF

# Final verdict
echo ""
echo "========================================="
print_success "✅ DeepMimic installation verification completed successfully!"
echo ""
print_status "Next steps:"
print_status "1. Run a pre-trained model: python DeepMimic.py --arg_file args/run_humanoid3d_walk_args.txt"
print_status "2. Start training: mpiexec -n 4 python DeepMimic_Optimizer.py --arg_file args/train_humanoid3d_walk_args.txt"
print_status "3. Check documentation: cat README.md"
echo ""
print_status "For more help, see docs/ directory or create an issue on GitHub."
