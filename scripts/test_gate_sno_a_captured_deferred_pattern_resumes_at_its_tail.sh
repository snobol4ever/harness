#!/usr/bin/env bash
# test_gate_sno_a_captured_deferred_pattern_resumes_at_its_tail.sh -- *P . A (and *P $ A), where P holds a sequence the lowerer
# inlines, backs into the LAST element of P when the scanner retreats into the capture, exactly as P . A already did: the capture's
# omega is the body's resume tail, never its first box.
#
# ⛔ THE DEFECT: sno_capt_body resolved a captured TT_VAR to its stored pattern before lowering, so P . A took the sequence branch and
# got sno_seq_nary's true tail; a captured TT_DEFER of the same variable skipped that resolution, fell to the one-element branch, and
# took the FIRST node built as its tail -- for P = ARBNO(LEN(1)) LEN(1) the conditional capture's omega was the ARBNO, so a retreat
# skipped LEN(1)'s beta and the ARBNO extended with LEN(1) still consumed: 'abcd' POS(0) *P . A RPOS(0) failed where sbl matches
# 'abcd' (and 'ab', 'abc'/'abcde' passing by parity hid it). --dump-ir: MATCH_ASSIGN_COND omega 19 (ARBNO) where 20 (LEN) is right.
# NO MONITOR BRACKET: the divergence is inside one pattern match of one statement.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1-2  m3 / m4: the probe matrix -- captured deferred sequences, their P . A twins, and alternation/ARB controls   -- RED on base
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
NAME=sno_a_captured_deferred_pattern_resumes_at_its_tail
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
PROBES=(
"P = ARBNO(LEN(1)) LEN(1)|'ab' POS(0) *P . A RPOS(0)"
"P = ARBNO(LEN(1)) LEN(1)|'abc' POS(0) *P . A RPOS(0)"
"P = ARBNO(LEN(1)) LEN(1)|'abcd' POS(0) *P . A RPOS(0)"
"P = ARBNO(LEN(1)) LEN(1)|'abcdef' POS(0) *P . A RPOS(0)"
"P = ARBNO(LEN(1)) LEN(1)|'abcd' *P . A RPOS(0)"
"P = ARBNO(LEN(1)) LEN(1)|'abcd' POS(0) *P \$ A RPOS(0)"
"P = ARBNO(LEN(1)) LEN(1)|'abcd' POS(0) P . A RPOS(0)"
"P = ARBNO('a') 'a'|'aaaa' POS(0) *P . A RPOS(0)"
"P = ARB 'x'|'axbxc' POS(0) *P . A 'c'"
"P = LEN(1) ~ LEN(2)|'abc' POS(0) *P . A 'c'"
"P = ('a' ~ 'ab') ('c' ~ 'bc')|'abcd' POS(0) *P . A 'd'"
"P = ARBNO(LEN(1)) LEN(1) LEN(1)|'abcde' POS(0) *P . A RPOS(0)"
)
for i in "${!PROBES[@]}"; do
    pre="${PROBES[$i]%%|*}"; stmt="${PROBES[$i]#*|}"
    printf '%s\n' "          ${pre//\~/|}" "          ${stmt//\~/|}  :S(OK)F(NO)" "OK        OUTPUT = 'match ' A   :(END)" "NO        OUTPUT = 'nomatch'" END > "$T/p$i.sno"
    ( cd "$T" && timeout -k 5 20 "$SBL" -bf "p$i.sno" < /dev/null > "p$i.oracle" 2>&1 )
    grep -q 'match' "$T/p$i.oracle" || refuse "the oracle did not answer probe $i: [$(head -2 "$T/p$i.oracle" | tr '\n' '|')]"
done
grep -qx 'match abcd' "$T/p2.oracle" || refuse "the oracle's answer to the witness moved: [$(cat "$T/p2.oracle")]"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
run() { ( cd "$T" && if [ "$2" = m3 ]; then timeout -k 5 20 "$SCRIP" "$1.sno" < /dev/null; else timeout -k 5 30 "$SCRIP" --compile --out="$1.s" "$1.sno" < /dev/null > /dev/null 2>&1 && gcc "$1.s" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o "$1.bin" > /dev/null 2>&1 && timeout -k 5 20 "./$1.bin" < /dev/null; fi ) 2>&1; }
matrix() { local bad=""
    for i in "${!PROBES[@]}"; do
        run "p$i" "$1" > "$T/p$i.$1"
        cmp -s "$T/p$i.$1" "$T/p$i.oracle" || bad="$bad p$i ${PROBES[$i]} got [$(tr '\n' '|' < "$T/p$i.$1")] want [$(tr '\n' '|' < "$T/p$i.oracle")];"
    done; [ -z "$bad" ] && echo ok || echo "$bad"; }
arm "m3: the captured-deferred-pattern matrix (${#PROBES[@]} probes) answers as sbl -bf" "$(matrix m3)"
arm "m4: the captured-deferred-pattern matrix (${#PROBES[@]} probes) answers as sbl -bf" "$(matrix m4)"
[ "$fail" = 0 ] && { echo "GATE PASS [$NAME]: $n/$n arms"; exit 0; }
echo "GATE FAIL [$NAME]"; exit 1
