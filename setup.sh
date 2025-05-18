#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PY_VER=3.7.16
BULLET_VER=2.88
EIGEN_VER=3.3.7
FREEGLUT_VER=3.0.0
GLEW_VER=2.1.0
SWIG_VER=4.0.0

JOBS="$(nproc)"     # number of parallel jobs for make


sudo apt-get update
sudo apt-get install -y libgl1-mesa-dev libx11-dev libxrandr-dev libxi-dev libopenmpi-dev mesa-utils clang cmake bison byacc build-essential cmake wget curl tar autoconf libtool pkg-config libssl-dev zlib1g-dev libglew-dev freeglut3-dev libglu1-mesa-dev libffi-dev

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

# ─────────────────────────────  Python $PY_VER  ─────────────────────────────
if [[ ! -d "../py" ]]; then
  PY_PREFIX=$PWD/Python-${PY_VER}/local

  download_and_extract "https://www.python.org/ftp/python/${PY_VER}/Python-${PY_VER}.tgz"

  cd "Python-${PY_VER}"
  CFLAGS="-fPIC" ./configure --prefix=$PY_PREFIX
  make -j$JOBS
  make altinstall
  cd ..

  $PY_PREFIX/bin/python3.7 -m venv ../py
  ../py/bin/python3 -m pip install numpy
fi

source ../py/bin/activate

# ─────────────────────────────  Bullet $BULLET_VER  ─────────────────────────
download_and_extract "https://github.com/bulletphysics/bullet3/archive/refs/tags/${BULLET_VER}.tar.gz"
cd bullet3-${BULLET_VER}
mkdir -p build_cmake
cd build_cmake
cmake -DCMAKE_INSTALL_PREFIX=../install -DUSE_DOUBLE_PRECISION=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON ..
make -j$JOBS
make install
cd ../..


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
  "cmake -DOpenGL_GL_PREFERENCE=GLVND . && make -j$JOBS"

# ──────────────────────────────  GLEW $GLEW_VER  ────────────────────────────
download_and_extract "https://downloads.sourceforge.net/project/glew/glew/${GLEW_VER}/glew-${GLEW_VER}.tgz"
build_once "glew-${GLEW_VER}" \
  "make -j$JOBS && make GLEW_DEST=$PWD/install install"

# ───────────────────────────────  SWIG $SWIG_VER  ───────────────────────────
download_and_extract "https://github.com/swig/swig/archive/refs/tags/v${SWIG_VER}.tar.gz"
build_once "swig-${SWIG_VER}" \
  "./autogen.sh && ./configure --without-pcre --prefix=$PWD/install && make -j$JOBS && make install"

# ─────────────────────────────  DeepMimicCore Build  ─────────────────────────────

# Ensure we are in the project root# Set Bullet lib dir to the install location
export BULLET_LIB_DIR="$PWD/libs/bullet3-${BULLET_VER}/install/lib"
cd "$SCRIPT_DIR"

pip install pip -U
pip install PyOpenGL PyOpenGL_accelerate tensorflow==1.13.1 mpi4py protobuf==3.20.*

# Set environment variables for DeepMimicCore Makefile
echo "\nSetting environment variables for DeepMimicCore build..."

export PATH="$PWD/libs/install/bin:$PATH"
export EIGEN_DIR="$PWD/libs/eigen-${EIGEN_VER}"
export BULLET_INC_DIR="$PWD/libs/bullet3-${BULLET_VER}/src"
export BULLET_LIB_DIR="$PWD/libs/bullet3-${BULLET_VER}/install/lib"
export GLEW_INC_DIR="$PWD/libs/glew-${GLEW_VER}/install/include"
export GLEW_LIB_DIR="$PWD/libs/glew-${GLEW_VER}/lib"
export FREEGLUT_INC_DIR="$PWD/libs/freeglut-${FREEGLUT_VER}/install/include"
export FREEGLUT_LIB_DIR="$PWD/libs/freeglut-${FREEGLUT_VER}/install/lib"
export LD_LIBRARY_PATH="$GLEW_LIB_DIR:$FREEGLUT_LIB_DIR:$BULLET_LIB_DIR"


cd DeepMimicCore

# Build DeepMimicCore and Python wrapper
make clean
make python

# Set rpath for _DeepMimicCore.so if patchelf is available
if command -v patchelf >/dev/null; then
  patchelf --set-rpath "$GLEW_LIB_DIR:$FREEGLUT_LIB_DIR:$BULLET_LIB_DIR" _DeepMimicCore.so
else
  echo "Warning: patchelf not found. Set LD_LIBRARY_PATH manually if needed."
  export LD_LIBRARY_PATH="$GLEW_LIB_DIR:$FREEGLUT_LIB_DIR:$BULLET_LIB_DIR"
  echo $LD_LIBRARY_PATH
fi

# Check for missing dynamic dependencies
ldd _DeepMimicCore.so | grep "not found" && { echo "Some dependencies not found"; exit 1; }

# Test Python wrapper
python3 DeepMimicCore.py || exit 1

cd ..

echo "\nDeepMimic build complete!"

echo -e "\nAll requested libraries are present and up to date!"