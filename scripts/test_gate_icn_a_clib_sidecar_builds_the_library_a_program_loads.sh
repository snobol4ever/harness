#!/usr/bin/env bash
# test_gate_icn_a_clib_sidecar_builds_the_library_a_program_loads.sh -- A <stem>.clib SIDECAR BUILDS THE VENDORED C LIBRARY A PROGRAM
# LOADS, AND THE RUN FINDS IT ON FPATH IN BOTH MODES AS ICONX FINDS ITS OWN BUILD (hq_icon 2026-09-27, Arizona general/cfuncs under
# CEO-1336; clause 8 (f): the unit declares what its run needs, the runner types nothing of its own).
#
# iconx exports FPATH=". <its bin>" into every program, and pathload (ipl io.icn) searches FPATH for the library; the distribution's
# bin holds its build of ipl/cfuncs. declared_clib_beside (lib_declared_arena.sh, the one reader) reads "<libname>.so <dir>", builds
# every *.c in <dir> once per content hash, and echoes the directory the runner puts on FPATH. Arms: (1) no sidecar: nothing, rc 0;
# (2) a fixture library of one function, loaded by pathload, answers in m3, m4 and iconx alike under FPATH=". <dir>"; (3) a doctored
# reader that echoes nothing leaves pathload failing (the arm-2 answer is lost -- red); (4) seven malformed sidecars each refuse rc 2:
# two lines, a name not lib*.so, a name carrying a path, an absolute directory, a .. component, a directory with no *.c, a build error.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G=test_gate_icn_a_clib_sidecar_builds_the_library_a_program_loads
S="$HERE/../../SCRIP/scrip"; O="$HERE/../../SCRIP/out"
[ -x "$S" ] || { echo "⛔ GATE REFUSE(2) [$G]: scrip not built"; exit 2; }
IC=/home/resources/icon-master/bin/icont
[ -x "$IC" ] || { echo "⛔ GATE REFUSE(2) [$G]: icont not found at $IC -- the oracle is required"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/clib_gate.XXXXXX")" || { echo "⛔ GATE REFUSE(2) [$G]: mktemp failed"; exit 2; }
trap 'rm -rf "$T"' EXIT
export TMPDIR="$T"
. "$HERE/lib_declared_arena.sh"
P="$T/pkg"; mkdir -p "$P/general" "$P/clib/gt"
cat > "$P/clib/gt/gt.c" <<'EOF'
typedef long word;
typedef struct { word dword, vword; } descriptor;
int gtf(int argc, descriptor *argv) { argv[0].dword = (word)(0x8000000000000000UL | 0x2000000000000000UL | 1); argv[0].vword = 4242 + argc; return 0; }
EOF
printf 'link io\nprocedure main()\n   local f;\n   f := pathload("libgt.so", "gtf") | stop("no library");\n   write(f(1, 2));\nend\n' > "$P/general/w.icn"
red=0
out="$(declared_clib_beside "$P/general/w.icn" "$P")"; rc=$?
[ "$rc" = 0 ] && [ -z "$out" ] && echo "  arm 1 PASS: no sidecar, nothing echoed, rc 0" || { echo "  arm 1 RED: rc=$rc out=[$out]"; red=1; }
printf 'libgt.so clib/gt\n' > "$P/general/w.clib"
dir="$(declared_clib_beside "$P/general/w.icn" "$P")"; rc=$?
[ "$rc" = 0 ] && [ -f "$dir/libgt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: the fixture library did not build (rc=$rc, dir=[$dir])"; exit 2; }
( cd "$P/general" && "$IC" -s -o w.ox w.icn >/dev/null 2>&1 && FPATH=". $dir" ./w.ox > "$T/oracle.txt" 2>&1 )
[ "$(cat "$T/oracle.txt")" = 4244 ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle did not answer 4244 through the fixture library: $(head -c 200 "$T/oracle.txt")"; exit 2; }
( cd "$P/general" && FPATH=". $dir" "$S" w.icn < /dev/null > "$T/m3.txt" 2>&1 )
( cd "$P/general" && "$S" --compile -o "$T/w.s" w.icn < /dev/null >/dev/null 2>&1 ) && gcc -no-pie -o "$T/w.x" "$T/w.s" -Wl,-rpath,"$O" -L"$O" -lscrip_rt -lm -lpthread 2>/dev/null \
    || { echo "⛔ GATE REFUSE(2) [$G]: m4 did not build the witness"; exit 2; }
( cd "$P/general" && FPATH=". $dir" "$T/w.x" < /dev/null > "$T/m4.txt" 2>&1 )
for m in m3 m4; do cmp -s "$T/oracle.txt" "$T/$m.txt" && echo "  arm 2 PASS $m: 4244 through the built library, as iconx" || { echo "  arm 2 RED $m: $(head -c 200 "$T/$m.txt")"; red=1; }; done
doctored="$(declared_clib_beside() { return 0; }; declared_clib_beside "$P/general/w.icn" "$P")"
( cd "$P/general" && ${doctored:+FPATH=". $doctored"} "$S" w.icn < /dev/null > "$T/doc.txt" 2>&1 )
cmp -s "$T/oracle.txt" "$T/doc.txt" && { echo "  arm 3 RED: the answer survived a reader that echoes nothing -- the arm does not measure the sidecar"; red=1; } \
    || echo "  arm 3 PASS: with the reader doctored to echo nothing, pathload fails ($(head -c 60 "$T/doc.txt"))"
mkdir -p "$P/clib/empty" "$P/clib/bad"; printf 'int x = ;\n' > "$P/clib/bad/bad.c"
n=0
for bad in $'libgt.so clib/gt\nlibgt.so clib/gt' 'gt.so clib/gt' 'sub/libgt.so clib/gt' "libgt.so $P/clib/gt" 'libgt.so clib/../clib/gt' 'libgt.so clib/empty' 'libgt.so clib/bad'; do
    n=$((n+1)); printf '%s\n' "$bad" > "$P/general/w.clib"
    declared_clib_beside "$P/general/w.icn" "$P" >/dev/null 2>&1; rc=$?
    [ "$rc" = 2 ] || { echo "  arm 4 RED: malformed sidecar $n [$(printf '%s' "$bad" | tr '\n' '|')] read rc=$rc, want 2"; red=1; }
done
[ "$red" -eq 0 ] && echo "  arm 4 PASS: $n malformed sidecars each refuse rc 2"
[ "$red" -eq 0 ] && { echo "✅ GATE PASS [$G]: a .clib sidecar builds the library, and m3, m4 and iconx load it through FPATH alike"; exit 0; }
echo "⛔ GATE FAIL [$G]: the .clib sidecar does not build or reach the library the program loads"; exit 1
