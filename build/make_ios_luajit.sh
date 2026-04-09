set -euo pipefail

cd "$( dirname "${BASH_SOURCE[0]}" )"
LIPO="xcrun -sdk iphoneos lipo"
STRIP="xcrun -sdk iphoneos strip"
export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-12.0}"

IXCODE=`xcode-select -print-path`
ISDK=$IXCODE/Platforms/iPhoneOS.platform/Developer
ISDKVER=iPhoneOS.sdk
ISDKP=$IXCODE/usr/bin/

if [ ! -e $ISDKP/ar ]; then 
  sudo cp /usr/bin/ar $ISDKP
fi

if [ ! -e $ISDKP/ranlib ]; then
  sudo cp /usr/bin/ranlib $ISDKP
fi

if [ ! -e $ISDKP/strip ]; then
  sudo cp /usr/bin/strip $ISDKP
fi

cd luajit-2.1.0b3

# LuaJIT buildvm parser compares directives with "\n" literally.
# Normalize CRLF to LF first to avoid wrong generated headers (lj_libdef.h/lj_recdef.h).
python3 - <<PY
from pathlib import Path
root = Path("src")
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

XCODEVER=$(xcodebuild -version | sed -n '1s/^Xcode \([0-9]*\).*/\1/p')
ISOLD_XCODEVER=`echo "$XCODEVER < 10" | bc`
if [ "$ISOLD_XCODEVER" = "1" ]
then
    make clean TARGET_SYS=iOS
    ISDKF="-arch armv7 -isysroot $ISDK/SDKs/$ISDKVER -miphoneos-version-min=7.0"
    make HOST_CC="gcc -m32 -std=c99" TARGET_FLAGS="$ISDKF" TARGET=armv7 TARGET_SYS=iOS LUAJIT_A=libxluav7.a BUILDMODE=static
    
    
    make clean TARGET_SYS=iOS
    ISDKF="-arch armv7s -isysroot $ISDK/SDKs/$ISDKVER -miphoneos-version-min=7.0"
    make HOST_CC="gcc -m32 -std=c99" TARGET_FLAGS="$ISDKF" TARGET=armv7s TARGET_SYS=iOS LUAJIT_A=libxluav7s.a BUILDMODE=static
fi

make clean TARGET_SYS=iOS
ISDKF="-arch arm64 -isysroot $ISDK/SDKs/$ISDKVER -miphoneos-version-min=7.0"
make HOST_CC="gcc -std=c99" TARGET_FLAGS="$ISDKF" TARGET=arm64 TARGET_SYS=iOS LUAJIT_A=libxlua64.a BUILDMODE=static

cd src
if [ "$ISOLD_XCODEVER" = "1" ]
then
    lipo libxluav7.a -create libxluav7s.a libxlua64.a -output libluajit.a
else
    mv libxlua64.a libluajit.a
fi
test -f libluajit.a || { echo "libluajit.a not generated for iOS"; exit 1; }
cd ../..

mkdir -p build_lj_ios && cd build_lj_ios
cmake -DUSING_LUAJIT=ON  -DCMAKE_TOOLCHAIN_FILE=../cmake/ios.toolchain.cmake -DPLATFORM=OS64  -GXcode ../
cd ..
cmake --build build_lj_ios --config Release

mkdir -p plugin_luajit/Plugins/iOS/
libtool -static -o plugin_luajit/Plugins/iOS/libxlua.a build_lj_ios/Release-iphoneos/libxlua.a luajit-2.1.0b3/src/libluajit.a
