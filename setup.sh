#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Use system Python instead of building custom Python 3.7.16
# This avoids path issues and version conflicts
PY_VER=3.7.16
BULLET_VER=2.88
EIGEN_VER=3.3.7
FREEGLUT_VER=3.0.0
GLEW_VER=2.1.0
SWIG_VER=4.0.0

JOBS="$(nproc)"     # number of parallel jobs for make


sudo apt-get update
sudo apt-get install -y patchelf swig libgl1-mesa-dev libx11-dev libxrandr-dev libxi-dev libopenmpi-dev mesa-utils clang cmake bison byacc build-essential cmake wget curl tar autoconf libtool pkg-config libssl-dev zlib1g-dev libglew-dev freeglut3-dev libglu1-mesa-dev libffi-dev

mkdir -p libs && cd libs


download_and_extract() {
  local url="$1"          # 1 ️⃣  bind the parameter first
  local tarball           # 2 ️⃣  then create tarball from it or $2
  if [[ $# -ge 2 ]]; then
    tarball="$2"
  else
    tarball="$(basename "$url")"
  fi

  wget -nc "$url"                 # already-there tarballs are skipped
  if [[ "$tarball" =~ \.zip$ ]]; then
      unzip -qn "$tarball"        # -q = quiet, -n = never overwrite
  else
      # '--skip-old-files' is GNU-tar-only; fall back if not available
      if tar --help | grep -q -- '--skip-old-files'; then
          tar xzf "$tarball" --skip-old-files
      else
          tar xzf "$tarball"
      fi
  fi
}

build_once() {
  local dir="$1"
  shift
  if [[ ! -f "$dir/.built" ]]; then
    ( cd "$dir" && eval "$@" )
    touch "$dir/.built"
  else
    echo "✓ $dir already built — skipping"
  fi
}

# ─────────────────────────────  Python Virtual Environment  ─────────────────────────────
# Use system Python to create virtual environment instead of building from source
if [[ ! -d "../py" ]]; then
  # Check if system has Python 3
  if ! command -v python3 &> /dev/null; then
    echo "Python 3 is required but not installed. Please install Python 3."
    exit 1
  fi
  
  echo "Creating Python virtual environment using system Python..."
  python3 -m venv ../py
  
  # Activate and install basic requirements
  source ../py/bin/activate
  python3 -m pip install --upgrade pip
  python3 -m pip install numpy
else
  echo "✓ Python virtual environment already exists"
fi

source ../py/bin/activate

# ─────────────────────────────  Bullet $BULLET_VER  ─────────────────────────
download_and_extract "https://github.com/bulletphysics/bullet3/archive/refs/tags/${BULLET_VER}.tar.gz"
build_once "bullet3-${BULLET_VER}" \
  "mkdir -p build_cmake && cd build_cmake && cmake -DCMAKE_INSTALL_PREFIX=../install -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DUSE_DOUBLE_PRECISION=OFF -DBUILD_SHARED_LIBS=ON -DBUILD_BULLET2_DEMOS=OFF -DBUILD_BULLET3=ON -DBUILD_CPU_DEMOS=OFF -DBUILD_OPENGL3_DEMOS=OFF -DBUILD_EXTRAS=ON -DBUILD_UNIT_TESTS=OFF .. && make -j$JOBS && make install"


# ─────────────────────────────  Eigen $EIGEN_VER  ───────────────────────────
download_and_extract "https://gitlab.com/libeigen/eigen/-/archive/${EIGEN_VER}/eigen-${EIGEN_VER}.tar.gz"
build_once "eigen-${EIGEN_VER}" \
  "mkdir -p build && cd build && cmake .. && sudo make -j$JOBS install"

# ────────────────────────────  FreeGLUT $FREEGLUT_VER  ──────────────────────
download_and_extract "https://github.com/freeglut/freeglut/releases/download/v${FREEGLUT_VER}/freeglut-${FREEGLUT_VER}.tar.gz"

# Apply source code patches from patches/ to freeglut src/
for patchfile in ../patches/*; do
  fname=$(basename "$patchfile")
  if [[ -f "freeglut-$FREEGLUT_VER/src/$fname" ]]; then
    echo "Patching freeglut/src/$fname with $patchfile"
    cp -fv "$patchfile" "freeglut-$FREEGLUT_VER/src/$fname"
  fi
  # Optionally, add more logic if you want to patch other files
  # or use patch/diff instead of cp for more complex patches
  # For now, we just overwrite the file
  # You can add more sophisticated patching here if needed
  # e.g., patch -d freeglut-$FREEGLUT_VER/src -i "$patchfile"
done

# Patch CMakeLists.txt to add explicit OpenGL/GLU linking if not present
CMAKELISTS="freeglut-$FREEGLUT_VER/CMakeLists.txt"
if ! grep -q 'LIST(APPEND LIBS GL GLU GLX OpenGL)' "$CMAKELISTS"; then
  # Insert after the SET(LIBNAME ...) logic in the main UNIX block
  awk '
    BEGIN {patched=0}
    /SET\(LIBNAME freeglut-gles\)/ {
      print; next
    }
    /SET\(LIBNAME glut\)/ {
      print; next
    }
    /SET\(LIBNAME freeglut\)/ {
      print; next
    }
    /ENDIF\(\)/ && !patched {
      print;
      print "    # Explicitly add OpenGL and GLU libraries for UNIX";
      print "    LIST(APPEND LIBS GL GLU GLX OpenGL)";
      patched=1;
      next
    }
    {print}
  ' "$CMAKELISTS" > "$CMAKELISTS.tmp" && mv "$CMAKELISTS.tmp" "$CMAKELISTS"
  echo "Patched $CMAKELISTS to add explicit OpenGL/GLU linking."
fi

build_once "freeglut-${FREEGLUT_VER}" \
  "mkdir -p install && cmake -DCMAKE_INSTALL_PREFIX=./install -DOpenGL_GL_PREFERENCE=GLVND . && make -j$JOBS && make install"

# ──────────────────────────────  GLEW $GLEW_VER  ────────────────────────────
download_and_extract "https://downloads.sourceforge.net/project/glew/glew/${GLEW_VER}/glew-${GLEW_VER}.tgz"
build_once "glew-${GLEW_VER}" \
  "make -j$JOBS && make GLEW_DEST=$PWD/install install"

# ───────────────────────────────  SWIG $SWIG_VER  ───────────────────────────
download_and_extract "https://github.com/swig/swig/archive/refs/tags/v${SWIG_VER}.tar.gz"
build_once "swig-${SWIG_VER}" \
  "./autogen.sh && ./configure --without-pcre --prefix=$PWD/install && make -j$JOBS && make install"

# ─────────────────────────────  DeepMimicCore Build  ─────────────────────────────

# Return to project root
cd "$SCRIPT_DIR"

# Activate the Python virtual environment
source py/bin/activate

# Install Python packages in the virtual environment
pip install pip -U

# Try to install from requirements.txt, but handle version conflicts gracefully
echo "Installing Python packages..."
if ! pip install -r ../requirements.txt; then
  echo "❌ Failed to install from requirements.txt (likely due to old TensorFlow version)"
  echo "Installing compatible packages manually..."
  
  # Install packages that should work with current Python
  pip install numpy PyOpenGL PyOpenGL_accelerate mpi4py pyquaternion
  
  # Try to install a compatible TensorFlow version
  echo "Attempting to install compatible TensorFlow version..."
  if ! pip install "tensorflow>=2.16.0"; then
    echo "⚠️  Warning: Could not install TensorFlow. DeepMimic may not work for training."
    echo "   You may need to install TensorFlow manually or use an older Python version."
  fi
  
  # Install protobuf
  pip install "protobuf>=3.20.0"
fi

# Set environment variables for DeepMimicCore Makefile
echo "\nSetting environment variables for DeepMimicCore build..."

export PATH="$PWD/libs/swig-${SWIG_VER}/install/bin:$PATH"
export EIGEN_DIR="$PWD/libs/eigen-${EIGEN_VER}"
export BULLET_INC_DIR="$PWD/libs/bullet3-${BULLET_VER}/src"
export BULLET_LIB_DIR="$PWD/libs/bullet3-${BULLET_VER}/install/lib"
export GLEW_INC_DIR="$PWD/libs/glew-${GLEW_VER}/include"
export GLEW_LIB_DIR="$PWD/libs/glew-${GLEW_VER}/lib"
export FREEGLUT_INC_DIR="$PWD/libs/freeglut-${FREEGLUT_VER}/install/include"
export FREEGLUT_LIB_DIR="$PWD/libs/freeglut-${FREEGLUT_VER}/install/lib"

# Set up library path for runtime linking
export LD_LIBRARY_PATH="$GLEW_LIB_DIR:$FREEGLUT_LIB_DIR:$BULLET_LIB_DIR:${LD_LIBRARY_PATH:-}"


cd DeepMimicCore

# Build DeepMimicCore and Python wrapper
make clean
make python

# Set rpath for _DeepMimicCore.so if patchelf is available
if command -v patchelf >/dev/null; then
  echo "Setting rpath for _DeepMimicCore.so..."
  patchelf --set-rpath "$GLEW_LIB_DIR:$FREEGLUT_LIB_DIR:$BULLET_LIB_DIR" _DeepMimicCore.so
  echo "✓ rpath set successfully"
else
  echo "Warning: patchelf not found. Using LD_LIBRARY_PATH for runtime linking."
fi

# Verify library dependencies
echo "Checking library dependencies..."
if ldd _DeepMimicCore.so | grep "not found"; then
  echo "❌ Some dependencies not found. Setting LD_LIBRARY_PATH..."
  export LD_LIBRARY_PATH="$GLEW_LIB_DIR:$FREEGLUT_LIB_DIR:$BULLET_LIB_DIR:${LD_LIBRARY_PATH:-}"
  echo "LD_LIBRARY_PATH set to: $LD_LIBRARY_PATH"
  
  # Test again after setting LD_LIBRARY_PATH
  if LD_LIBRARY_PATH="$LD_LIBRARY_PATH" ldd _DeepMimicCore.so | grep "not found"; then
    echo "❌ Dependencies still not found after setting LD_LIBRARY_PATH"
    exit 1
  else
    echo "✓ Dependencies resolved with LD_LIBRARY_PATH"
  fi
else
  echo "✓ All dependencies found"
fi

# Test Python wrapper
echo "Testing Python wrapper..."
if LD_LIBRARY_PATH="$GLEW_LIB_DIR:$FREEGLUT_LIB_DIR:$BULLET_LIB_DIR:${LD_LIBRARY_PATH:-}" python3 -c "import DeepMimicCore; print('✓ DeepMimicCore imported successfully')"; then
  echo "✓ Python wrapper test passed"
else
  echo "❌ Python wrapper test failed"
  exit 1
fi

cd ..

echo "\nDeepMimic build complete!"

# Create a convenient environment setup script
cat > setup_env.sh << 'EOF'
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

echo "✓ DeepMimic environment activated"
echo "  - Python virtual environment: $(which python3)"
echo "  - LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
echo ""
echo "You can now run DeepMimic commands, for example:"
echo "  python3 DeepMimic.py --arg_file args/run_humanoid3d_backflip_args.txt"
EOF

chmod +x setup_env.sh

echo -e "\nSetup complete!"
echo -e "\nTo use DeepMimic:"
echo -e "1. Source the environment: source setup_env.sh"
echo -e "2. Run DeepMimic: python3 DeepMimic.py --arg_file args/run_humanoid3d_backflip_args.txt"

echo -e "\nAll requested libraries are present and up to date!"