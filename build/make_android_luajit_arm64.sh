set -euo pipefail

#if [ -z "$ANDROID_NDK" ]; then
    export ANDROID_NDK=~/android-ndk-r15c
#fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SRCDIR=$DIR/luajit-2.1.0b3
# ANDROID_NDK=~/android-ndk-r10e

# LuaJIT buildvm parser compares directives with "\n" literally.
# Normalize CRLF to LF first to avoid wrong generated headers (e.g. lj_recdef.h).
python3 - <<PY
from pathlib import Path
root = Path(r"${SRCDIR}")
text_suffix = {".c", ".h", ".dasc", ".lua", ".s", ".S", ".in"}
for p in root.rglob("*"):
    if not p.is_file():
        continue
    if p.suffix not in text_suffix and p.name not in {"Makefile", "Makefile.dep"}:
        continue
    data = p.read_bytes()
    if b"\r\n" in data:
        p.write_bytes(data.replace(b"\r\n", b"\n"))
PY

OS=`uname -s`
PREBUILT_PLATFORM=linux-x86_64
if [[ "$OS" == "Darwin" ]]; then
    PREBUILT_PLATFORM=darwin-x86_64
fi

NDKABI=21


echo "Building arm64-v8a lib"
NDKVER=$ANDROID_NDK/toolchains/aarch64-linux-android-4.9
NDKP=$NDKVER/prebuilt/$PREBUILT_PLATFORM/bin/aarch64-linux-android-
NDKARCH="-DLJ_ABI_SOFTFP=0 -DLJ_ARCH_HASFPU=1 -DLUAJIT_ENABLE_GC64=1"  
NDKF="--sysroot $ANDROID_NDK/platforms/android-$NDKABI/arch-arm64"
cd "$SRCDIR"
make clean
make HOST_CC="gcc -m64" CROSS=$NDKP TARGET_SYS=Linux TARGET_FLAGS="$NDKF $NDKARCH" BUILDMODE=static
test -f "$SRCDIR/src/libluajit.a" || { echo "libluajit.a not generated for arm64-v8a"; exit 1; }

cd "$DIR"
mkdir -p build_lj_v8a && cd build_lj_v8a
cmake -DUSING_LUAJIT=ON -DANDROID_ABI=arm64-v8a -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake -DANDROID_TOOLCHAIN_NAME=arm-linux-androideabi-clang -DANDROID_NATIVE_API_LEVEL=android-21 ../
cd "$DIR"
cmake --build build_lj_v8a --config Release
mkdir -p plugin_luajit/Plugins/Android/libs/arm64-v8a/
cp build_lj_v8a/libxlua.so plugin_luajit/Plugins/Android/libs/arm64-v8a/libxlua.so


echo "Building armv7 lib"
NDKVER=$ANDROID_NDK/toolchains/arm-linux-androideabi-4.9
NDKP=$NDKVER/prebuilt/$PREBUILT_PLATFORM/bin/arm-linux-androideabi-
NDKARCH="-march=armv7-a -mfloat-abi=softfp -Wl,--fix-cortex-a8"
NDKF="--sysroot $ANDROID_NDK/platforms/android-$NDKABI/arch-arm"
cd "$SRCDIR"
make clean
make HOST_CC="gcc -m32" CROSS=$NDKP TARGET_SYS=Linux TARGET_FLAGS="$NDKF $NDKARCH" BUILDMODE=static
test -f "$SRCDIR/src/libluajit.a" || { echo "libluajit.a not generated for armeabi-v7a"; exit 1; }

cd "$DIR"
mkdir -p build_lj_v7a && cd build_lj_v7a
cmake -DUSING_LUAJIT=ON -DANDROID_ABI=armeabi-v7a -DCMAKE_TOOLCHAIN_FILE=../cmake/android.toolchain.cmake -DANDROID_TOOLCHAIN_NAME=arm-linux-androideabi-4.9 -DANDROID_NATIVE_API_LEVEL=android-21 ../
cd "$DIR"
cmake --build build_lj_v7a --config Release
mkdir -p plugin_luajit/Plugins/Android/libs/armeabi-v7a/
cp build_lj_v7a/libxlua.so plugin_luajit/Plugins/Android/libs/armeabi-v7a/libxlua.so

echo "Building x86 lib"
NDKVER=$ANDROID_NDK/toolchains/x86-4.9
NDKP=$NDKVER/prebuilt/$PREBUILT_PLATFORM/bin/i686-linux-android-
NDKF="--sysroot $ANDROID_NDK/platforms/android-$NDKABI/arch-x86"
cd "$SRCDIR"
make clean
make HOST_CC="gcc -m32" CROSS=$NDKP TARGET_SYS=Linux TARGET_FLAGS="$NDKF" BUILDMODE=static
test -f "$SRCDIR/src/libluajit.a" || { echo "libluajit.a not generated for x86"; exit 1; }

cd "$DIR"
mkdir -p build_lj_x86 && cd build_lj_x86
cmake -DUSING_LUAJIT=ON -DANDROID_ABI=x86 -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake -DANDROID_TOOLCHAIN_NAME=x86-clang -DANDROID_NATIVE_API_LEVEL=android-21 ../
cd "$DIR"
cmake --build build_lj_x86 --config Release
mkdir -p plugin_luajit/Plugins/Android/libs/x86/
cp build_lj_x86/libxlua.so plugin_luajit/Plugins/Android/libs/x86/libxlua.so

