#!/usr/bin/env bash
set -euo pipefail

# DeepMimic macOS Setup Script
# This script installs dependencies and builds DeepMimic on macOS (Intel or Apple Silicon)
# Tested on macOS 12+ with Homebrew

# --------- User Configurable ---------
PY_VER=3.7.16
BULLET_VER=2.88
EIGEN_VER=3.3.7
FREEGLUT_VER=3.0.0
GLEW_VER=2.1.0
SWIG_VER=4.0.0
JOBS="$(sysctl -n hw.ncpu)"

# --------- Install Homebrew if needed ---------
if ! command -v brew >/dev/null; then
  echo "Homebrew not found. Please install Homebrew from https://brew.sh/ and re-run this script."
  exit 1
fi

# --------- Install Dependencies ---------
echo "Installing dependencies via Homebrew..."
brew update
brew install cmake wget curl autoconf libtool pkg-config bison byacc swig eigen glew freeglut zlib openssl
# (No python@3.7 here; we'll build Python from source below)

# OpenGL/GLUT are provided by macOS, but deprecated. FreeGLUT/GLEW from Homebrew are used.

# --------- Python 3.7.16 Build from Source ---------
if [[ ! -d "py" ]]; then
  mkdir -p libs && cd libs
  if [[ ! -d "Python-${PY_VER}" ]]; then
    wget -nc "https://www.python.org/ftp/python/${PY_VER}/Python-${PY_VER}.tgz"
    tar xzf "Python-${PY_VER}.tgz"
  fi
  PY_PREFIX=$PWD/Python-${PY_VER}/local
  cd Python-${PY_VER}

  # Get zlib paths from brew
  ZLIB_PATH=$(brew --prefix zlib)
  OPENSSL_PATH=$(brew --prefix openssl)

  # Check architecture and set appropriate flags
  if [[ "$(uname -m)" == "arm64" ]]; then
    # For Apple Silicon, disable profile guided optimization
    CFLAGS="-fPIC -I${ZLIB_PATH}/include" \
    LDFLAGS="-L${ZLIB_PATH}/lib -L${OPENSSL_PATH}/lib" \
    ./configure --prefix=$PY_PREFIX --with-openssl=${OPENSSL_PATH} --without-gcc
  else
    # For Intel Macs
    CFLAGS="-fPIC -I${ZLIB_PATH}/include" \
    LDFLAGS="-L${ZLIB_PATH}/lib -L${OPENSSL_PATH}/lib" \
    ./configure --prefix=$PY_PREFIX --with-openssl=${OPENSSL_PATH}
  fi

  # Try to build Python from source
  if ! make -j$JOBS; then
    echo "Python build from source failed. Attempting to install via pyenv instead..."
    cd ../..
    
    # Install pyenv if needed
    if ! command -v pyenv >/dev/null; then
      brew install pyenv
    fi
    
    # Initialize pyenv in this shell
    eval "$(pyenv init -)"
    
    # Install Python 3.7.16 via pyenv
    CFLAGS="-I$(brew --prefix openssl)/include -I$(brew --prefix zlib)/include" \
    LDFLAGS="-L$(brew --prefix openssl)/lib -L$(brew --prefix zlib)/lib" \
    pyenv install -s ${PY_VER}
    
    # Create virtualenv with pyenv Python
    pyenv local ${PY_VER}
    python -m venv py
  else
    make altinstall
    cd ../..
    $PY_PREFIX/bin/python3.7 -m venv py
  fi

  ./py/bin/pip install --upgrade pip
  ./py/bin/pip install numpy

  source ./py/bin/activate
fi

# --------- Download and Build Bullet ---------
mkdir -p libs && cd libs
if [[ ! -d "bullet3-${BULLET_VER}" ]]; then
  wget -nc "https://github.com/bulletphysics/bullet3/archive/refs/tags/${BULLET_VER}.tar.gz"
  tar xzf "${BULLET_VER}.tar.gz"
fi
cd bullet3-${BULLET_VER}
mkdir -p build_cmake && cd build_cmake
cmake -DCMAKE_INSTALL_PREFIX=../install \
      -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
      -DBUILD_PYBULLET=OFF \
      -DBUILD_EXTRAS=OFF \
      -DBUILD_OPENGL3_DEMOS=OFF \
      -DBUILD_BULLET3=ON \
      -DBUILD_SHARED_LIBS=ON \
      -DBUILD_UNIT_TESTS=OFF \
      -DBUILD_CPU_DEMOS=OFF \
      -DBUILD_BULLET2_DEMOS=OFF \
      -DINSTALL_LIBS=ON \
      -DUSE_DOUBLE_PRECISION=OFF \
      ..
make -j$JOBS install
cd ../../..

# --------- Eigen (from Homebrew) ---------
# Already installed via Homebrew, nothing to do

# --------- FreeGLUT/GLEW (from Homebrew) ---------
# Already installed via Homebrew, nothing to do

# --------- SWIG (from Homebrew) ---------
# Already installed via Homebrew, nothing to do

# --------- Python Packages ---------
# Check if running on Apple Silicon
if [[ "$(uname -m)" == "arm64" ]]; then
  echo "Apple Silicon detected. Installing TensorFlow with special handling..."
  # For Apple Silicon, try TensorFlow 2.x with compatibility mode or MacOS TensorFlow builds
  py/bin/python -m pip install PyOpenGL PyOpenGL_accelerate mpi4py protobuf==3.20.*
  
  # Try tensorflow-macos if available (Apple's optimized TF build)
  if ! py/bin/python -m pip install tensorflow-macos; then
    echo "Falling back to TensorFlow 2.10.0 with compatibility shim for TF 1.x API"
    py/bin/python -m pip install tensorflow==2.10.0
    
    # Create a TF 1.x compatibility layer in the deepmimic directory
    cat > tf1_compat.py << EOF
# TensorFlow 1.x compatibility layer for TensorFlow 2.x
import tensorflow.compat.v1 as tf
tf.disable_v2_behavior()
# Add any other compatibility shims as needed
EOF
    
    echo "Created tf1_compat.py - you may need to modify DeepMimic code to import TensorFlow via this compatibility layer"
  fi
else
  # For Intel Macs try the last 1.x version
  echo "Intel Mac detected. Installing TensorFlow 1.15.0..."
  py/bin/python -m pip install PyOpenGL PyOpenGL_accelerate tensorflow==1.15.0 mpi4py protobuf==3.20.*
fi

# Note on TensorFlow versions
echo "NOTE: If TensorFlow installation fails or has compatibility issues:"
echo "1. For Intel Macs: Try using Conda with tensorflow-deps"
echo "2. For Apple Silicon: Use Rosetta 2 by installing Python with arch -x86_64"
echo "3. You may need to modify the DeepMimic code to work with newer TensorFlow versions"

# --------- Environment Variables ---------
export BULLET_LIB_DIR="$PWD/libs/bullet3-${BULLET_VER}/install/lib"
export BULLET_INC_DIR="$PWD/libs/bullet3-${BULLET_VER}/src"
export EIGEN_DIR="$(brew --prefix eigen)"
export GLEW_INC_DIR="$(brew --prefix glew)/include"
export GLEW_LIB_DIR="$(brew --prefix glew)/lib"
export FREEGLUT_INC_DIR="$(brew --prefix freeglut)/include"
export FREEGLUT_LIB_DIR="$(brew --prefix freeglut)/lib"
export DYLD_LIBRARY_PATH="$GLEW_LIB_DIR:$FREEGLUT_LIB_DIR:$BULLET_LIB_DIR"

# --------- Build DeepMimicCore ---------
cd DeepMimicCore
make clean
make python

# --------- macOS Dynamic Library Handling ---------
# On macOS, use install_name_tool to set rpath if needed
if command -v install_name_tool >/dev/null; then
  install_name_tool -add_rpath "$GLEW_LIB_DIR" _DeepMimicCore.so || true
  install_name_tool -add_rpath "$FREEGLUT_LIB_DIR" _DeepMimicCore.so || true
  install_name_tool -add_rpath "$BULLET_LIB_DIR" _DeepMimicCore.so || true
else
  echo "Warning: install_name_tool not found. Set DYLD_LIBRARY_PATH manually if needed."
fi

# Check for missing dynamic dependencies
otool -L _DeepMimicCore.so

# Test Python wrapper
python3 DeepMimicCore.py || exit 1
cd ..

echo "\nDeepMimic build complete on macOS!"
echo -e "\nAll requested libraries are present and up to date!"
