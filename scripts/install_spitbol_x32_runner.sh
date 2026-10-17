#!/usr/bin/env bash
# install_spitbol_x32_runner.sh — install SPITBOL x32 so it runs under
#                                 qemu-user in sandboxes that block native
#                                 32-bit execution (e.g. gVisor/runsc).
#
# Idempotent.  Safe to run multiple times.
#
# Produces:
#   /home/claude/x32/            — clone of spitbol/x32
#   /home/claude/sbl32           — patched copy of x32/bin/spitbol, runnable
#                                  via `qemu-i386-static /home/claude/sbl32 ...`
#
# Invocation from any script:
#   SBL32="/home/claude/sbl32"
#   [ -x "$SBL32" ] || { echo "⛔ REFUSED-TO-GRADE sbl32 not installed"; exit 2; }
#   qemu-i386-static "$SBL32" -b file.sno
#
# Why the patch is needed: SPITBOL's MINIMAL architecture CALLs into its
# data segment (symbol `minimal:` lives inside .data, not .text).  Real
# Linux historically didn't enforce NX on segments flagged RW; qemu-user
# does.  One-byte patch flips segment 02's p_flags from 0x6 (RW) to
# 0x7 (RWX) so the dispatch runs.
#
# SN-25.x32 origin: session 2026-04-21 discovered this recipe while
# probing whether spitbol/x32 -bf works (it doesn't; same bug as x64).
# The recipe is kept because x32 is still useful as a secondary -b
# oracle and as a cross-check for SN-27 (uppercase DATATYPE).
#
# Per RULES.md:
#  - paths derived from $0, no env-var deps beyond PATH
#  - SKIP cleanly (exit 0, clear message) when prerequisites absent
#  - idempotent: re-running is a no-op if sbl32 already installed
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"         # $S4E/SCRIP
HOME_ROOT="$(cd "$ROOT/.." && pwd)"    # $S4E

X32_DIR="$HOME_ROOT/x32"
SBL32="$HOME_ROOT/sbl32"

# 1. Prerequisite: qemu-i386-static.  If absent, instruct how to install
#    and SKIP.  We don't apt-get from inside the script (container may be
#    locked down, or running without sudo).
if ! command -v qemu-i386-static >/dev/null 2>&1; then
    echo "SKIP qemu-i386-static not installed"
    echo "     To install: apt-get install -y qemu-user-static"
    exit 0
fi

# 2. libc6-i386 (32-bit loader) — confirm /lib/ld-linux.so.2 is present.
#    Not strictly needed when qemu supplies its own loader, but some
#    qemu configurations defer to the native loader.  Warn, don't fail.
if [ ! -e /lib/ld-linux.so.2 ]; then
    echo "WARN /lib/ld-linux.so.2 missing — if qemu-i386-static fails,"
    echo "     install libc6-i386:  apt-get install -y libc6-i386"
fi

# 3. Clone snobol4ever/x32 if not present.  (Public fork of spitbol/x32;
#    identical source, convenience clone.  Fall back to spitbol/x32 if
#    snobol4ever/x32 is unreachable.)
if [ -d "$X32_DIR/.git" ]; then
    echo "SKIP x32 already cloned at $X32_DIR"
else
    echo "CLONE spitbol/x32 -> $X32_DIR"
    if ! git clone --depth=1 https://github.com/snobol4ever/x32 "$X32_DIR" 2>/dev/null; then
        git clone --depth=1 https://github.com/spitbol/x32 "$X32_DIR"
    fi
fi

# 4. Verify the prebuilt binary is where we expect it.
SRC_BIN="$X32_DIR/bin/spitbol"
if [ ! -f "$SRC_BIN" ]; then
    echo "FAIL expected $SRC_BIN not found after clone"
    exit 1
fi

# 5. If the patched copy already exists and matches source timestamp, skip.
if [ -x "$SBL32" ] && [ "$SBL32" -nt "$SRC_BIN" ]; then
    echo "SKIP sbl32 already patched at $SBL32 (newer than source)"
    exit 0
fi

# 6. Copy and patch: segment 02 p_flags 0x6 (RW) -> 0x7 (RWX).
#    Offsets: ehdr=52, phent=32, p_flags within phent=24.
#    So index 2 is at 52 + 2*32 + 24 = 116 bytes from start of file.
echo "PATCH $SRC_BIN -> $SBL32 (segment 02 p_flags RW -> RWX)"
cp "$SRC_BIN" "$SBL32"
python3 - "$SBL32" << 'PY'
import struct, sys, os
path = sys.argv[1]
# Sanity check: ELF32 magic and e_phoff
with open(path, 'r+b') as f:
    magic = f.read(4)
    if magic != b'\x7fELF':
        print("FAIL not an ELF file", file=sys.stderr); sys.exit(1)
    f.seek(4)
    if f.read(1) != b'\x01':
        print("FAIL not ELF32", file=sys.stderr); sys.exit(1)
    # e_phoff (4 bytes) at offset 28 in ELF32 ehdr
    f.seek(28)
    phoff = struct.unpack('<I', f.read(4))[0]
    # e_phentsize (2 bytes) at offset 42
    f.seek(42)
    phentsize = struct.unpack('<H', f.read(2))[0]
    # Index 2, p_flags at offset 24 within the 32-byte phent
    target = phoff + 2 * phentsize + 24
    f.seek(target)
    old = struct.unpack('<I', f.read(4))[0]
    if old not in (0x6, 0x7):
        print(f"FAIL unexpected p_flags at PH[2]: 0x{old:x}", file=sys.stderr)
        sys.exit(1)
    if old == 0x7:
        print("  PH[2].p_flags already 0x7 (RWX); no change")
    else:
        f.seek(target)
        f.write(struct.pack('<I', 0x7))
        print(f"  PH[2].p_flags 0x{old:x} -> 0x7")
PY
chmod +x "$SBL32"

# 7. Verify: run the trivial program and confirm it exits 0.
TMP=$(mktemp /tmp/x32_verify.XXXXXX.sno)
trap "rm -f $TMP" EXIT
printf '\toutput = %ca%c\nend\n' "'" "'" > "$TMP"

if OUT=$(timeout -k 5 8 qemu-i386-static "$SBL32" -b "$TMP" 2>&1) && [ "$OUT" = "a" ]; then
    echo "PASS sbl32 installed at $SBL32 (output=$OUT)"
else
    echo "FAIL sbl32 verification failed"
    echo "     output: $OUT"
    exit 1
fi
