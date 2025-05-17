#!/usr/bin/env bash
set -euo pipefail


PY_VER=3.7.16
BULLET_VER=2.88
EIGEN_VER=3.3.7
FREEGLUT_VER=3.0.0
GLEW_VER=2.1.0
SWIG_VER=4.0.0

JOBS="$(nproc)"     # number of parallel jobs for make


sudo apt-get update
sudo apt-get install -y libgl1-mesa-dev libx11-dev libxrandr-dev libxi-dev libopenmpi-dev mesa-utils clang cmake bison byacc build-essential cmake wget curl tar autoconf libtool pkg-config

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
build_once "bullet3-${BULLET_VER}" "bash -c 'USE_DOUBLE_PRECISION=OFF ./build_cmake_pybullet_double.sh && cd build_cmake && sudo make install'"

# ─────────────────────────────  Eigen $EIGEN_VER  ───────────────────────────
download_and_extract "https://gitlab.com/libeigen/eigen/-/archive/${EIGEN_VER}/eigen-${EIGEN_VER}.tar.gz"
build_once "eigen-${EIGEN_VER}" \
  "mkdir -p build && cd build && cmake .. && sudo make -j$JOBS install"

# ────────────────────────────  FreeGLUT $FREEGLUT_VER  ──────────────────────
download_and_extract "https://github.com/freeglut/freeglut/releases/download/v${FREEGLUT_VER}/freeglut-${FREEGLUT_VER}.tar.gz"

cp -fv ../patches/* freeglut-$FREEGLUT_VER/src/

build_once "freeglut-${FREEGLUT_VER}" \
  "cmake -DOpenGL_GL_PREFERENCE=GLVND . && make -j$JOBS"

# ──────────────────────────────  GLEW $GLEW_VER  ────────────────────────────
download_and_extract "https://downloads.sourceforge.net/project/glew/glew/${GLEW_VER}/glew-${GLEW_VER}.tgz"
build_once "glew-${GLEW_VER}" \
  "make -j$JOBS && sudo make install && make clean"

# ───────────────────────────────  SWIG $SWIG_VER  ───────────────────────────
download_and_extract "https://github.com/swig/swig/archive/refs/tags/v${SWIG_VER}.tar.gz"
build_once "swig-${SWIG_VER}" \
  "./autogen.sh && ./configure --without-pcre && make -j$JOBS"



echo -e "\nAll requested libraries are present and up to date!"