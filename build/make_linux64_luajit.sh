set -euo pipefail

cd luajit-2.1.0b3

# LuaJIT buildvm parser compares directives with "\n" literally.
# Normalize CRLF to LF first to avoid wrong generated headers.
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

make clean
make CFLAGS=-fPIC BUILDMODE=static
test -f src/libluajit.a || { echo "libluajit.a not generated for linux x86_64"; exit 1; }
cd ..
rm -rf build_linux64_lj
mkdir -p build_linux64_lj && cd build_linux64_lj
cmake -DUSING_LUAJIT=ON ../
cd ..
cmake --build build_linux64_lj --config Release
mkdir -p plugin_luajit/Plugins/x86_64/
cp build_linux64_lj/libxlua.so plugin_luajit/Plugins/x86_64/libxlua.so 

