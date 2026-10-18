#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_gc_the_parser_module_and_the_user_program_each_adopt_their_own_program_top.sh -- THE PARSE-STAGE MODULE (SCRIP_PARSE_STAGE=sc,
# CEO-1566/1749) RUNS INSIDE THE COMPILER AND COLLECTS THERE, AND THE USER PROGRAM RUNS AFTER IT IN THE SAME PROCESS (mode 3); EACH ADOPTS ITS
# OWN PROGRAM TOP, SO NO WALK FINDS ITS ROOT FRAME AWAY FROM THE ADOPTED TOP (cto 2026-10-15, after 3b2a97fe9 made that a refusal).
# Two defects 3b2a97fe9's refusal exposed on this road, both silently relearned by every walk before it:
#   (1) rt_sc_outer_call (rt_sc_module.c) handed rt_program_top_adopt the stack pointer from before its two scratch pushes, 16 bytes above the
#       module main's entry rsp; rt_outer_call (scrip.c) hands the entry rsp itself. Every collection inside the module read -16 bytes.
#   (2) gc_root_map returned the FIRST registered map with GC_FRAME_MAP_ROOT. The module installs its maps at its first entry and keeps them,
#       so the user program registered after it adopted its top from the MODULE's root map and its first walk read top-above-segment.
#       The newest root map is the running program's (every gc witness registers exactly one, measured over 119); gc_root_block follows it.
# ARMS, on a 12-line witness at a 64 KB window (sbl is the oracle): (a) --compile under the module stage collects (GC-EXERCISE collections>0,
# else the arm proves nothing and the gate refuses) and exits 0; (b) mode 3 under the module stage equals sbl; (c) (b) under SCRIP_GC_STRESS=1
# SCRIP_GC_CHAIN_CHECK=1. Two-part proof: on 68afc1b19 arm (a) aborts rc 134; with (1) alone arm (b) refuses top-above-segment; green here.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; G="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: cannot load lib_oracle_flags.sh"; exit 2; }
SBL="$(sbl_correctness_bin)" || { echo "⛔ GATE REFUSE(2) [$G]: no SPITBOL correctness oracle"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/w.sno" <<'SNO'
         DEFINE('M(L)')                                           :(ME)
M        M = .DUMMY
         N = N + SIZE(TX)                                         :(NRETURN)
ME       DIGITS = '0123456789'
         FN = SPAN('.' DIGITS &UCASE '_' &LCASE) $ TX $ *M(1)
         I = 0
AGAIN    S = 'ALPHA beta.1 GAMMA_2 delta ' DUPL('x', I)
LOOP     S POS(0) FN =                                            :F(NEXT)
         S POS(0) ' ' =                                           :S(LOOP)
NEXT     I = LT(I, 400) I + 1                                     :S(AGAIN)
         OUTPUT = 'TX=' SIZE(TX) ' DUMMY=' SIZE(DUMMY) ' N=' N
END
SNO
(cd "$T" && timeout 30 "$SBL" $(sbl_lang_flags) w.sno < /dev/null > ref 2>&1); [ -s "$T/ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle printed nothing for the witness"; exit 2; }
RC=0
(cd "$T" && env -u SCRIP_HEAP_MB SCRIP_PARSE_STAGE=sc SCRIP_HEAP_KB=64 SCRIP_GC_EXERCISE=1 timeout 60 "$SCRIP" --compile -o w.s w.sno < /dev/null > cc.out 2> cc.err); r=$?
col=$(grep -o 'collections=[0-9]*' "$T/cc.err" | head -1 | cut -d= -f2)
[ "$r" = 0 ] || [ -n "$col" ] || grep -q 'GC-CHAIN' "$T/cc.err" || { echo "⛔ GATE REFUSE(2) [$G]: the module-stage compile neither ran nor collected (rc $r): $(head -1 "$T/cc.err" | cut -c1-120)"; exit 2; }
if [ "$r" != 0 ]; then echo "  arm a FAIL: the module-stage compile exits rc $r -- $(grep -m1 'REFUSED' "$T/cc.err" | cut -c1-200)"; RC=1
elif [ "${col:-0}" -le 0 ]; then echo "⛔ GATE REFUSE(2) [$G]: the module-stage compile collected 0 times at a 64 KB window -- arm a measures nothing"; exit 2
else echo "  arm a PASS: the module-stage compile collected $col time(s) inside the module and exits 0"; fi
for arm in b c; do
    E="env -u SCRIP_HEAP_MB SCRIP_PARSE_STAGE=sc SCRIP_HEAP_KB=64"; W=""; [ "$arm" = c ] && { E="$E SCRIP_GC_STRESS=1 SCRIP_GC_CHAIN_CHECK=1"; W=" (stress, chain check)"; }
    (cd "$T" && $E timeout 120 "$SCRIP" --run w.sno < /dev/null > "m3.$arm" 2> "m3.$arm.err"); r=$?
    grep -v '^\[GC-' "$T/m3.$arm" > "$T/m3.$arm.out"
    if [ "$r" = 0 ] && cmp -s "$T/ref" "$T/m3.$arm.out"; then echo "  arm $arm PASS: mode 3 under the module stage equals sbl$W"
    else echo "  arm $arm FAIL: rc $r, $(cmp -s "$T/ref" "$T/m3.$arm.out" && echo output equal || echo output differs) -- $(grep -m1 'REFUSED' "$T/m3.$arm.err" | cut -c1-200)"; RC=1; fi
done
[ "$RC" = 0 ] && echo "GATE PASS(0) [$G]: the parser module and the user program each adopt their own program top" || echo "GATE FAIL(1) [$G]: a walk on the module road found its root frame away from the adopted top"
exit "$RC"
