#!/usr/bin/env bash
# test_gate_sno_set_positions_a_file_as_spitbol_does.sh -- SET(channel, offset, whence), the manual's "part of standard SPITBOL"
# file-position function (v3.7, SET: whence 0 from the beginning, 1 from the current position, 2 from the end; SET(ch,0,1) returns
# the position without moving it), answers every measured case as SPITBOL answers it, in both modes: the value, the next read after
# the seek, and the error code (292 null channel, 293 an offset or whence that is not an integer, 295 no such channel or a name,
# 297 a whence outside 0..2, 248 a DEFINE of SET), the target clamped at 0 and an input file's target at its end; on an output file it overwrites in
# place and may extend it.
#
# ⛔ THE DEFECT: SCRIP had no SET (error 22, undefined function) -- and neither did the grading oracle until x64 fork 012d00e
# (swap 20260927T212829Z, Lon in-chat to hq_snobol4: "So we should add the SET function to x64 SPITBOL to make our lives
# easier."), whose build left SET compiled out (.cust undefined, the entry renamed ZET, and sysst declared with no error exits).
# aisnobol BUILDLIB.sno, the package's eighth program, calls SET(1,0,1) to record each library function's file offset.
# NO MONITOR BRACKET: the program stops at its first SET call, before any event could diverge.
#
# THE CURE: _SET_ in src/runtime/core/core.c over the channel's FILE* (fflush, ftell, fseek), registered as SET.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1-2  m3 / m4: the case matrix, one program per case (an error is fatal), stdout and error code         -- RED on base
#   3    m3: SET on an output file -- overwrite in place, the position at the end, the file's bytes          -- RED on base
#   4-5  m3 / m4: aisnobol BUILDLIB.sno writes spitlib.idx byte-identical to the oracle's                    -- RED on base
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, an oracle without SET, no aisnobol package).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
PKG="$S4E/corpus/packages/snobol4/aisnobol"
NAME=sno_set_positions_a_file_as_spitbol_does
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
[ -f "$PKG/BUILDLIB.sno" ] && [ -f "$PKG/BUILDLIB.IN" ] && [ -f "$PKG/spitlib.spt" ] || refuse "no aisnobol BUILDLIB under $PKG -- pull corpus"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
printf 'hello\nworld\nthird\n' > "$T/x.txt"
printf '%s\n' "        INPUT(.IN,1,'x.txt')" "        OUTPUT = SET(1,0,1)" END > "$T/probe.sno"
( cd "$T" && timeout -k 5 20 "$SBL" -bf probe.sno < /dev/null > probe.out 2>&1 )
[ "$(head -1 "$T/probe.out")" = 0 ] || refuse "the oracle $SBL has no SET (x64 fork 012d00e or later, swap 20260927T212829Z): [$(grep -m1 ERROR "$T/probe.out")]"
CASES=("SET(1,0,1)" "SET(1,'2',1)" "SET(1,'x',1)" "SET('1',0,1)" "SET(1,0,'1')" "SET(2,0,1)" "SET(1,0,2)" "SET(1,0,7)" "SET(1,1.5,0)" "SET(,0,0)"
       "SET(1,0,'P')" "SET(1,-100,0)" "SET(1,100,0)" "SET(.IN,0,1)" "SET(1,-6,2)" "SET(1,3,0)" "SET(1)" "SET(1,'-2',2)" "DEFINE('SET(X)')")
for i in "${!CASES[@]}"; do
    printf '%s\n' "        INPUT(.IN,1,'x.txt')" "        L = IN" "        OUTPUT = ${CASES[$i]}" "        OUTPUT = 'next ' IN" "        OUTPUT = 'next ' IN" END > "$T/c$i.sno"
    ( cd "$T" && timeout -k 5 20 "$SBL" -bf "c$i.sno" < /dev/null > "c$i.raw" 2>/dev/null )
    { sed '/^$/,$d' "$T/c$i.raw"; echo "error=$(grep -o 'ERROR [0-9]*' "$T/c$i.raw" | head -1 | tr -dc 0-9)"; } > "$T/c$i.oracle"
done
grep -qx 'error=295' "$T/c5.oracle" && grep -qx '12' "$T/c14.oracle" && grep -qx 'error=293' "$T/c2.oracle" || refuse "the oracle's SET answers moved: [$(tr '\n' '|' < "$T/c14.oracle")]"
printf '%s\n' "        OUTPUT(.O,3,'w.txt')" "        O = 'abcdef'" "        OUTPUT = SET(3,0,1)" "        OUTPUT = SET(3,2,0)" "        O = 'XY'" "        OUTPUT = SET(3,0,2)" \
    "        ENDFILE(3)" "        INPUT(.I,4,'w.txt')" "        OUTPUT = I" "        OUTPUT = I" END > "$T/w.sno"
( cd "$T" && timeout -k 5 20 "$SBL" -bf w.sno < /dev/null > w.oracle 2>&1 && cat w.txt >> w.oracle && rm -f w.txt ) || refuse "sbl did not run the output-file witness"
mkdir "$T/bo" && cp "$PKG/BUILDLIB.sno" "$PKG/BUILDLIB.IN" "$PKG/spitlib.spt" "$T/bo/" || refuse "could not stage BUILDLIB"
( cd "$T/bo" && timeout -k 5 20 "$SBL" -bf BUILDLIB.sno < BUILDLIB.IN > out 2>&1 ) && [ -s "$T/bo/spitlib.idx" ] || refuse "sbl did not write spitlib.idx from BUILDLIB"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
run() { ( cd "$1" && if [ "$3" = m3 ]; then timeout -k 5 20 "$SCRIP" "$2.sno"; else timeout -k 5 30 "$SCRIP" --compile -o "$2.s" "$2.sno" < /dev/null > /dev/null 2>&1 && gcc "$2.s" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o "$2.bin" > /dev/null 2>&1 && timeout -k 5 20 "./$2.bin"; fi ) }
matrix() { local bad=""
    for i in "${!CASES[@]}"; do
        run "$T" "c$i" "$1" < /dev/null > "$T/c$i.$1.out" 2> "$T/c$i.$1.err"
        { cat "$T/c$i.$1.out"; echo "error=$(grep -o 'error [0-9]*' "$T/c$i.$1.err" | head -1 | tr -dc 0-9)"; } > "$T/c$i.$1"
        cmp -s "$T/c$i.$1" "$T/c$i.oracle" || bad="$bad ${CASES[$i]} got [$(tr '\n' '|' < "$T/c$i.$1")] want [$(tr '\n' '|' < "$T/c$i.oracle")];"
    done; [ -z "$bad" ] && echo ok || echo "$bad"; }
arm "m3: the SET case matrix (${#CASES[@]} cases), stdout and error code" "$(matrix m3)"
arm "m4: the SET case matrix (${#CASES[@]} cases), stdout and error code" "$(matrix m4)"
( cd "$T" && timeout -k 5 20 "$SCRIP" w.sno < /dev/null > w.m3 2>&1 && cat w.txt >> w.m3 )
arm "m3: SET on an output file overwrites in place and reads back" "$(cmp -s "$T/w.m3" "$T/w.oracle" && echo ok || echo "got [$(tr '\n' '|' < "$T/w.m3")] want [$(tr '\n' '|' < "$T/w.oracle")]")"
for m in m3 m4; do
    mkdir -p "$T/b$m" && cp "$PKG/BUILDLIB.sno" "$PKG/BUILDLIB.IN" "$PKG/spitlib.spt" "$T/b$m/"
    run "$T/b$m" BUILDLIB "$m" < "$T/b$m/BUILDLIB.IN" > "$T/b$m/out" 2>&1; rc=$?
    arm "$m: aisnobol BUILDLIB.sno writes spitlib.idx as sbl does" "$([ "$rc" = 0 ] && cmp -s "$T/b$m/spitlib.idx" "$T/bo/spitlib.idx" && echo ok || echo "rc=$rc $(head -c 120 "$T/b$m/out" | tr '\n' '|') idx $(wc -l < "$T/b$m/spitlib.idx" 2>/dev/null || echo none) lines vs $(wc -l < "$T/bo/spitlib.idx")")"
done
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
