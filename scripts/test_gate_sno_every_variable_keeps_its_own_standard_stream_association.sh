#!/usr/bin/env bash
# test_gate_sno_every_variable_keeps_its_own_standard_stream_association.sh -- every variable INPUT() or OUTPUT() associates
# with a standard stream keeps ITS OWN association, as under sbl -bf (ceo CEO-1401, 2026-10-02).
#
# ⛔⭐ FOUND BY MODERNIZING spitbol_testpgms/test8.spt ON LON'S WORD ("fix the I/O associations to be modern"): its three
# OUTPUT('TITLE',6,'(14H1...)') associations became OUTPUT(.TITLE), OUTPUT(.DEALER), OUTPUT(.SKIP), and SCRIP printed only
# SKIP. THE CAUSE: a one-argument OUTPUT(.X) always took channel 6, closed it and stored the one name the channel table
# holds, so every new association EVICTED the previous one (INPUT(.X) the same on channel 5); an empty channel and file
# argument, OUTPUT(.X,,''), made no association at all where sbl associates the standard stream; a variable moved from a
# file to standard output kept writing to the file (the lookup found its older channel first); and associating another
# variable with standard input moved the INPUT variable's own stream off its file. THE CURE (core.c _io_assoc_std): the
# variable is detached from every channel it held, then given its own slot on the shared standard stream -- channel 5 or
# 6 when free, else a free slot from the top of the table -- and the INPUT variable's stream is never touched for another
# variable. The expectation of every arm is cut from sbl -bf at run time; nothing is pinned.
#
# THE ARMS, each in m3 and m4, each byte-identical to sbl -bf on the same witness and stdin:
#   1 two OUTPUT(.X) associations both write        2 three in a row (test8's shape)
#   3 OUTPUT(.A,,'') is standard output             4 two INPUT(.X) associations read in turn
#   5 INPUT(.A,,'') is standard input               6 a variable moved from a file to standard output
#   7 DETACH(.A) leaves B associated                8 re-associating the same variable keeps one association
#   9 another variable on standard input leaves INPUT on its file
#  10 DETECTOR -- OUTPUT(.OUTPUT) stays a no-op and plain OUTPUT writes once, so a cure that double-wrote fails here
# EXIT: 0 every arm passes · 1 an arm failed · 2 REFUSED (no binary, no oracle, a toolchain failure).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"; RT_DIR="$ROOT/out"; NAME=sno_every_variable_keeps_its_own_standard_stream_association
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
printf 'one\ntwo\nthree\nfour\n' > "$T/in.txt"; printf 'file1\nfile2\nfile3\n' > "$T/data.txt"
graded=0; fail=0
case_arm() {
    local name="$1" src="$2" ora m3 m4
    printf '%b' "$src" > "$T/w.sno"
    rm -f "$T/f3.txt"; ora="$(cd "$T" && timeout -k 5 10 "$SBL" -bf w.sno < in.txt 2>&1 | grep -v '^$' | tr '\n' '|')"
    [ -n "$ora" ] || refuse "sbl printed nothing for arm '$name' -- the witness or the oracle moved"
    rm -f "$T/f3.txt"; m3="$(cd "$T" && timeout -k 5 10 "$SCRIP" w.sno < in.txt 2>&1 | grep -v '^$' | tr '\n' '|')"
    ( cd "$T" && timeout -k 5 30 "$SCRIP" --compile w.sno -o w.s > /dev/null 2>&1 && gcc -no-pie w.s -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o w.bin > /dev/null 2>&1 ) || refuse "mode-4 build of arm '$name' failed -- a toolchain failure, not a verdict"
    rm -f "$T/f3.txt"; m4="$(cd "$T" && timeout -k 5 10 ./w.bin < in.txt 2>&1 | grep -v '^$' | tr '\n' '|')"
    for mode in m3 m4; do
        graded=$((graded+1)); got="$m3"; [ "$mode" = m4 ] && got="$m4"
        if [ "$got" = "$ora" ]; then echo "  PASS $name $mode  [$got]"; else echo "  FAIL $name $mode  want[$ora] got[$got]"; fail=$((fail+1)); fi
    done
}
case_arm "two-output-associations"        "         OUTPUT(.A)\n         OUTPUT(.B)\n         A = 'a'\n         B = 'b'\nEND\n"
case_arm "three-in-a-row-test8s-shape"    "         OUTPUT(.T)\n         OUTPUT(.D)\n         OUTPUT(.K)\n         T = 'x'\n         D = 'y'\n         K = 'z'\nEND\n"
case_arm "empty-file-argument-is-stdout"  "         OUTPUT(.A,,'')\n         OUTPUT(.B)\n         A = 'a'\n         B = 'b'\nEND\n"
case_arm "two-input-associations"         "         INPUT(.A)\n         INPUT(.B)\n         OUTPUT = A ',' B ',' A\nEND\n"
case_arm "empty-file-argument-is-stdin"   "         INPUT(.A,,'')\n         OUTPUT = A\nEND\n"
case_arm "moved-from-file-to-stdout"      "         OUTPUT(.A,3,'f3.txt')\n         OUTPUT(.A)\n         A = 'to-stdout'\nEND\n"
case_arm "detach-leaves-the-other"        "         OUTPUT(.A)\n         OUTPUT(.B)\n         DETACH(.A)\n         A = 'a'\n         B = 'b'\nEND\n"
case_arm "re-association-keeps-one"       "         OUTPUT(.A)\n         A = 'a1'\n         OUTPUT(.A)\n         A = 'a2'\nEND\n"
case_arm "input-stays-on-its-file"        "         INPUT(.INPUT,3,'data.txt')\n         INPUT(.B)\n         OUTPUT = INPUT ',' B ',' INPUT\nEND\n"
case_arm "detector-output-of-output"      "         OUTPUT(.OUTPUT)\n         OUTPUT = 'plain'\nEND\n"
echo "graded=$graded FAIL=$fail  (every expectation cut from $SBL -bf at run time, same witness, same stdin)"
[ "$graded" = 20 ] || refuse "expected 20 arms, graded $graded"
if [ "$fail" -ne 0 ]; then echo "GATE FAIL(1) [$NAME]: $fail/$graded"; exit 1; fi
echo "GATE PASS(0) [$NAME]: $graded/$graded"
exit 0
