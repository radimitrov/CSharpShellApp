#!/bin/bash
#
# Drives green-green-avk/build-proot-android to produce the three binaries the APK needs, aligned for
# 16 KB pages. Runs inside the image built by the Dockerfile beside this file; writes to /out.
#
# Three deliberate departures from the upstream recipe, each of which matters:
#
#   1. build.sh upstream runs make-proot.sh, which installs to root/bin/proot and
#      root/libexec/proot/loader. That is the *tarball* layout. make-proot-for-apk.sh is the one that
#      produces libproot.so, libproot-loader.so and libproot-loader32.so — the lib*.so naming that
#      makes Android's package manager extract them into NativeLibraryDir with the execute bit, which
#      since Android 10 is the only directory an app may execve() from at all. So this runs the
#      -for-apk variant, and never calls pack.sh.
#
#   2. config hardcodes NDK=$HOME/Android/Sdk/ndk/23.2.8568313. r23 predates 16 KB alignment being the
#      default and is the entire reason the published prebuilts are unusable. Repointed at the r29 in
#      the image.
#
#   3. ARCHS is cut to the two this app ships. The other four are 32-bit or pre-API-21 variants that
#      would roughly triple the build for binaries that are never packaged. libproot-loader32.so still
#      appears, because PRoot builds its 32-bit loader as part of a 64-bit target.
#
#   4. API is raised from 21 to 23, and this one is the difference between a working terminal and a
#      broken one on every arm64 handset. PRoot reads and writes the tracee's memory either with
#      process_vm_readv/writev or, when those are unavailable, with ptrace(PEEKDATA/POKEDATA). bionic
#      only declares process_vm_readv from API 23, so at API 21 PRoot's own feature probe fails, it
#      reports `process_vm = no` under -V, and it falls back to ptrace. Since Android 11 every 64-bit
#      heap pointer carries a 0xb4 tag in its top byte (Top-Byte-Ignore), and ptrace PEEK/POKE will
#      not accept a tagged address — so the fallback fails on exactly the pointers PRoot has to read.
#      The first execve out of the container returns EFAULT and the session dies before the shell.
#      x86_64 has no TBI, which is why an emulator never showed it. API 23 is the app's own
#      minSdk (SupportedOSPlatformVersion), so this excludes no device that could install the APK.

set -euo pipefail

OUT=/out
mkdir -p "$OUT"

echo "=== Configuring the recipe ==="

# The NDK path and the arch list. Anchored replacements rather than sed over the whole file, so a
# recipe that has moved on fails here rather than silently building with the wrong toolchain.
grep -q '^NDK=' config || { echo "config no longer declares NDK; the recipe has changed." >&2; exit 1; }
grep -q '^ARCHS=' config || { echo "config no longer declares ARCHS; the recipe has changed." >&2; exit 1; }
grep -q '^	else API=21$' config || { echo "config no longer sets API=21 for the 64-bit archs; the recipe has changed." >&2; exit 1; }

sed -i "s|^NDK=.*|NDK=\"$NDK_HOME\"|" config
sed -i "s|^ARCHS=.*|ARCHS='aarch64 x86_64'|" config
sed -i 's|^	else API=21$|	else API=23|' config

# Alignment, stated explicitly rather than relied on. r29 defaults to 16 KB, but make-proot-for-apk.sh
# *exports* LDFLAGS itself, so anything set in the environment is discarded — the flag has to go into
# the script. Being explicit also means this recipe stays correct if someone rebuilds it on an older
# NDK, which is exactly the mistake that produced the binaries this file exists to replace.
grep -q 'export LDFLAGS="-L\$STATIC_ROOT/lib"' make-proot-for-apk.sh \
  || { echo "make-proot-for-apk.sh no longer sets LDFLAGS as expected." >&2; exit 1; }

sed -i 's|export LDFLAGS="-L\$STATIC_ROOT/lib"|export LDFLAGS="-L$STATIC_ROOT/lib -Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384"|' \
  make-proot-for-apk.sh

echo "--- config ---"
grep -E '^(NDK|ARCHS)=' config
grep -E 'API=[0-9]+' config
grep -n 'LDFLAGS' make-proot-for-apk.sh

echo "=== Fetching sources ==="
./get-talloc.sh
./get-proot.sh

# Pin the loader's image base to its text address.
#
# PRoot links its loader with `-Ttext=<LOADER_ADDRESS>` and nothing else: 0x2000000000 on arm64,
# 0x600000000000 on x86_64. That sets where .text goes, but every other section keeps the default
# image base (0x200000), so the ELF spans from there to the text address — 128 GB on arm64, 105 TB
# on x86_64. Older binutils tolerated that; LLVM 21 in NDK r29 does not, and it fails in two
# different places that look unrelated:
#
#   x86_64: ld.lld: error: failed to open loader/loader: File too large
#   arm64:  the link succeeds, then llvm-strip is SIGKILLed trying to rewrite the sparse result
#
# Replacing -Ttext with --image-base collapses the span, so the loader is a few KB again — which is
# what the 5,560-byte upstream prebuilt shows it is supposed to be. Setting BOTH does not work:
# lld then puts the ELF headers and .text at the same address and emits something llvm-strip
# rejects as "not recognized as a valid object file".
#
# Dropping -Ttext is safe, and this is the part worth checking rather than assuming. LOADER_ADDRESS
# exists only to park the loader somewhere the guest binary will not be; nothing requires .text to
# land on it exactly. PRoot maps the loader by reading its program headers, and the one thing it
# derives from the symbols — loader-info.awk — computes `pokedata_workaround - _start`, a relative
# offset that is identical whatever the base. With --image-base the headers sit at LOADER_ADDRESS
# and .text a few bytes after, which serves the same purpose.
GNUMAKEFILE="build/proot-0.15_release/src/GNUmakefile"
grep -q -- "-Ttext=\$(LOADER_ADDRESS\$1),-z,noexecstack" "$GNUMAKEFILE" \
  || { echo "PRoot GNUmakefile no longer links the loader as expected." >&2; exit 1; }

sed -i 's|-Ttext=$(LOADER_ADDRESS$1),-z,noexecstack|--image-base=$(LOADER_ADDRESS$1),-z,noexecstack|' "$GNUMAKEFILE"
grep -n "LOADER_LDFLAGS\$1 +=" "$GNUMAKEFILE"

echo "=== Building libtalloc (static) ==="

# talloc's lib/replace builds a test, os2_delete.c, that calls telldir() and seekdir(). Bionic has
# neither, so on Android they are implicit declarations — and where clang 12 (NDK r23, what upstream
# built with) merely warned, clang 18 in r29 makes that a hard error and the whole build stops at
# `cc os2_delete.c -> os2_delete_3.o`. Restoring the older behaviour is the minimal fix: the object
# is a test that nothing this recipe produces links against, and it is exactly what upstream got.
#
# make-talloc-static.sh captures CFLAGS into DEF_CFLAGS at the top and re-exports it per arch, so
# setting it here reaches every target. Deliberately NOT applied to PRoot: make-proot-for-apk.sh
# sets -Werror=implicit-function-declaration on purpose, and PRoot compiling clean under that rule
# is a property worth keeping rather than papering over.
export CFLAGS="-Wno-implicit-function-declaration"
./make-talloc-static.sh
unset CFLAGS

# Stripping is made non-fatal, and told to say what it is working on.
#
# make-proot-for-apk.sh strips every file in bin/ in a loop, and under NDK r29 that loop dies with
# a bare "Killed" — SIGKILL, deterministically, at the same point on every run. It is not host
# memory pressure (44 GB free) and llvm-strip runs fine standalone; the suspect is llvm-objcopy 21
# meeting a `-nostdlib` loader linked at -Ttext=0x2000000000 and trying to lay the file out by
# virtual address. NDK r23, which upstream used, had no such trouble.
#
# The loop runs under `set -e`, so one SIGKILL took the whole build down after everything had
# already compiled and linked. `|| echo` keeps it going, and the echo names the file so the log
# says which one rather than leaving it to be guessed. An unstripped binary is functionally
# identical — it is only larger — so this costs size, not correctness.
sed -i 's#^"$STRIP" "$FN"$#echo "STRIP: $FN"; "$STRIP" "$FN" || echo "STRIP FAILED (kept unstripped): $FN"#' make-proot-for-apk.sh
grep -n 'STRIP' make-proot-for-apk.sh

echo "=== Building PRoot ==="
./make-proot-for-apk.sh

echo "=== Collecting ==="
# make-proot-for-apk.sh installs to "$INSTALL_ROOT-apk", i.e. build/root-<arch>/root-apk/bin.
declare -A ABI=( [aarch64]=arm64-v8a [x86_64]=x86_64 )

for ARCH in aarch64 x86_64; do
    SRC="build/root-$ARCH/root-apk/bin"
    DST="$OUT/${ABI[$ARCH]}"
    mkdir -p "$DST"

    for NAME in libproot.so libproot-loader.so libproot-loader32.so; do
        if [ ! -f "$SRC/$NAME" ]; then
            echo "MISSING: $SRC/$NAME" >&2
            ls -la "$SRC" >&2 || true
            exit 1
        fi
        cp -a "$SRC/$NAME" "$DST/$NAME"
    done

    echo "--- ${ABI[$ARCH]} ---"
    ls -la "$DST"
done

cp /recipe-commit.txt "$OUT/recipe-commit.txt"

echo "=== Alignment ==="
# Reported here as well as verified by the caller, so a failed build says why in its own log rather
# than only through an exit code.
python3 - "$OUT" <<'PY'
import struct, sys, pathlib

bad = 0
for p in sorted(pathlib.Path(sys.argv[1]).rglob('*.so')):
    d = p.read_bytes()
    if d[:4] != b'\x7fELF':
        print(f'{p}: not an ELF'); bad += 1; continue
    if d[4] != 2:
        print(f'{p}: 32-bit, exempt'); continue
    phoff, = struct.unpack_from('<Q', d, 0x20)
    phes, phn = struct.unpack_from('<HH', d, 0x36)
    aligns = [struct.unpack_from('<Q', d, phoff + i*phes + 48)[0]
              for i in range(phn)
              if struct.unpack_from('<I', d, phoff + i*phes)[0] == 1]
    ok = all(a >= 0x4000 for a in aligns)
    print(f'{p}: {[hex(a) for a in aligns]} {"OK" if ok else "*** 4 KB ***"}')
    if not ok:
        bad += 1

sys.exit(1 if bad else 0)
PY

echo "=== Done ==="
