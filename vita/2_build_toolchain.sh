#!/bin/bash

# abort on errors
set -e

export WORKSPACE=$PWD

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPT_DIR/../shared/import.sh

# Number of CPU
nproc=$(nproc)

# Use ccache?
test_ccache

if [ ! -f .patches-applied ]; then
	echo "Patching libraries"

	patches_common

	# Fix mpg123
	(cd $MPG123_DIR
		patch -Np1 < $SCRIPT_DIR/../shared/extra/mpg123.patch
		autoreconf -fi
	)

	# Fix libsndfile
	(cd $LIBSNDFILE_DIR
		patch -Np1 < $SCRIPT_DIR/../shared/extra/libsndfile.patch
		autoreconf -fi
	)

	# Fix harfbuzz
	(cd $HARFBUZZ_DIR
		patch -Np1 < $SCRIPT_DIR/../shared/extra/harfbuzz-climits.patch
	)

	# Fix icu build
	cp -rup icu icu-native
	patch -Np0 < $SCRIPT_DIR/icu69-vita.patch

	# Disable vita2dlib jpeg dependency
	patch -Np0 < $SCRIPT_DIR/vita2dlib-no-jpeg.patch

	# Allow the cmake toolchain finding libfmt
	patch -Np0 < $SCRIPT_DIR/vitasdk-cmake.patch

	touch .patches-applied
fi

cd $WORKSPACE

echo "Preparing toolchain"

export VITASDK=$PWD/vitasdk
export PATH=$PWD/vitasdk/bin:$PATH

export TARGET_HOST=arm-vita-eabi
export PLATFORM_PREFIX=$VITASDK/$TARGET_HOST
export MAKEFLAGS="-j${nproc:-2}"

function set_build_flags {
	export CC="$TARGET_HOST-gcc"
	export CXX="$TARGET_HOST-g++"
	if [ "$ENABLE_CCACHE" ]; then
		export CC="ccache $CC"
		export CXX="ccache $CXX"
	fi
	export CFLAGS="-g0 -O2"
	export CXXFLAGS="$CFLAGS"
	export CPPFLAGS="-DPSP2"
	export CMAKE_SYSTEM_NAME="Generic"
}

function install_lib_vita2d() {
	msg "Building patched libvita2d"

	cd vita2dlib
	git checkout fbo
	cd libvita2d
	make clean
	make -j1
	make install
	cd ../..
}

function install_shaders() {
	msg "Copying precompiled shaders"

	(cd vitashaders
		cp -a ./lib/. $PLATFORM_PREFIX/lib/
		cp -a ./includes/. $PLATFORM_PREFIX/include/
	)
}

install_lib_icu_native

set_build_flags
install_lib_zlib
install_lib $LIBPNG_DIR $LIBPNG_ARGS
install_lib $FREETYPE_DIR $FREETYPE_ARGS --without-harfbuzz
install_lib $HARFBUZZ_DIR $HARFBUZZ_ARGS
install_lib $FREETYPE_DIR $FREETYPE_ARGS --with-harfbuzz
install_lib $PIXMAN_DIR $PIXMAN_ARGS
install_lib_cmake $EXPAT_DIR $EXPAT_ARGS
install_lib $LIBOGG_DIR $LIBOGG_ARGS
install_lib $LIBVORBIS_DIR $LIBVORBIS_ARGS
install_lib_mpg123
install_lib $LIBSNDFILE_DIR $LIBSNDFILE_ARGS
install_lib_cmake $LIBXMP_LITE_DIR $LIBXMP_LITE_ARGS
install_lib $SPEEXDSP_DIR $SPEEXDSP_ARGS
install_lib_cmake $WILDMIDI_DIR $WILDMIDI_ARGS
install_lib_cmake $FLUIDLITE_DIR $FLUIDLITE_ARGS -DENABLE_SF3=ON
install_lib $OPUS_DIR $OPUS_ARGS
install_lib $OPUSFILE_DIR $OPUSFILE_ARGS
install_lib_cmake $FMT_DIR $FMT_ARGS
install_lib_icu_cross
install_lib_liblcf

install_lib_vita2d
install_shaders
