#!/usr/bin/env bash
# test_gate_sno_backtracking_into_fence_of_p_retreats_to_its_left.sh -- FENCE(P) (v3.7: "the pattern FENCE(P) matches P, and if
# the scanner backs into it, it fails WITHOUT trying the alternatives of P") fails ONLY ITSELF: the scanner goes on backing into the
# element on its left. Bare FENCE is the other animal -- backing into it aborts the whole match. Every arm below answers as sbl -bf
# answers, in both modes, for FENCE(P) reached through a stored pattern, a deferred *P, and an ARBNO body.
#
# ⛔ THE DEFECT, FOUR SITES, ONE CLASS (every site treated FENCE(P) as if it were bare FENCE, or lost the element left of it):
#   (a) sno_pat_right_sealed: a pattern ENDING in FENCE(P) was "right sealed", so a *P holding it got seal=1 and the element after
#       *P failed PAST it (RPOS ω -> the match head);
#   (b) the thunk's resume surface: a fenced PAT$ blob published body_root only for a tier-1 root, and the emitter refused a FENCE1
#       root outright -- PAT$0_β was `jmp PAT$0_ω`, so resuming *P conceded instead of retreating through the fence;
#   (c) the fence-segmenting TT_SEQ took a one-element left segment's resume tail as the FIRST node built, so an inlined stored
#       sequence (P = 'a' ARB; P FENCE('') 'b') wired FENCE1's ω to the 'a' and skipped the ARB;
#   (d) inside ARBNO, FENCE(P) sealed its segment (right_sealed) and the body carried the "never resume an iteration" marker, so
#       ARBNO((LEN(1) | LEN(2)) FENCE(...)) never retried the alternation left of the fence.
# Anchoring exposes it: unanchored, the scanner's retry at the next cursor position often lands on the same answer.
# NO MONITOR BRACKET: the divergence is inside one pattern match of one statement (the monitor's grain is the statement); the
# method was ablation to a minimal witness, then --dump-ir wiring (FENCE1 ω) and the emitted PAT$0_β.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME):
#   1-2  m3 / m4: the probe matrix -- the cured shapes and the bare-FENCE controls (which must stay nomatch)   -- RED on base
#   3-4  m3 / m4: the SNOBOL4 rungs' three xfails of this class answer their .ref                           -- RED on base
# NOT HERE: P = ARBNO(LEN(1)) LEN(1) resumed through *P fails on alternating extension counts with no FENCE at all -- a separate
# defect, left visibly red in the rungs and named in the baton.
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, no rungs).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
RUNGS="$S4E/corpus/tests/snobol4"
NAME=sno_backtracking_into_fence_of_p_retreats_to_its_left
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
[ -f "$RUNGS/ALL.sno" ] && [ -f "$RUNGS/ALL.ref" ] || refuse "no SNOBOL4 rungs under $RUNGS -- pull corpus"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
PROBES=(
"P = 'a' ARB|'axb' P FENCE('') 'b'"
"P = 'a' ARB FENCE('')|'axb' P 'b'"
"P = ARB FENCE('')|'ab' POS(0) *P 'b'"
"P = ARB FENCE('')|'ab' TAB(0) *P 'b'"
"&ANCHOR = 1; P = ARB FENCE('')|'ab' *P 'b'"
"P = ARB FENCE('') 'a'|'xaxab' POS(0) *P 'b'"
"P = ARB FENCE('a')|'xaxab' POS(0) *P 'b'"
"P = ARB FENCE('a') LEN(0)|'xaxab' POS(0) *P 'b'"
"P = ARBNO('a') FENCE('b' ~ epsilon)|'aab' POS(0) *P RPOS(0)"
"P = ARBNO('a') FENCE('b' ~ epsilon)|'aaa' POS(0) *P . A RPOS(0)"
"P = ARBNO('a') FENCE('b' ~ epsilon)|'aaac' POS(0) *P . A 'c' RPOS(0)"
"P = ARBNO('a') FENCE(LEN(1))|'aab' POS(0) *P . A RPOS(0)"
"P = ARB FENCE(LEN(1)) 'x'|'abxcdx' POS(0) *P . A RPOS(0)"
"P = (ARB . A) FENCE('x')|'abxcdxy' POS(0) *P 'y' RPOS(0)"
"P = ARB FENCE(ARB 'b')|'abcbd' POS(0) *P . A 'd' RPOS(0)"
"C = 'a' ~ 'ab'; CS = *C FENCE(*CS ~ '')|'abaa' POS(0) *CS . A RPOS(0)"
"G = ARBNO((LEN(1) ~ LEN(2)) FENCE(LEN(1) ~ ''))|'abcdef' POS(0) *G . A LEN(1) RPOS(0)"
"G = ARBNO((LEN(1) ~ LEN(2)) FENCE(LEN(1) ~ ''))|'abcdefgh' POS(0) *G . A 'h' RPOS(0)"
"G = ARBNO(('a' ~ 'ab') FENCE('c' ~ 'bc'))|'abcabbcac' POS(0) *G . A RPOS(0)"
"&ANCHOR = 1|'abcde' ARBNO((LEN(1) ~ LEN(2)) FENCE(LEN(1))) . A 'e' RPOS(0)"
"P = ARB FENCE|'ab' POS(0) *P 'b'"
"P = LEN(1) FENCE|'abc' POS(0) *P 'c'"
"G = ARBNO(('a' ~ 'ab') FENCE)|'abab' POS(0) *G . A RPOS(0)"
"P = 'a' ARB|'axb' P FENCE 'b'"
)
for i in "${!PROBES[@]}"; do
    pre="${PROBES[$i]%%|*}"; stmt="${PROBES[$i]#*|}"
    printf '%s\n' "          ${pre//\~/|}" "          ${stmt//\~/|}  :S(OK)F(NO)" "OK        OUTPUT = 'match ' A   :(END)" "NO        OUTPUT = 'nomatch'" END > "$T/p$i.sno"
    ( cd "$T" && timeout -k 5 20 "$SBL" -bf "p$i.sno" < /dev/null > "p$i.oracle" 2>&1 )
    grep -q 'match' "$T/p$i.oracle" || refuse "the oracle did not answer probe $i: [$(head -2 "$T/p$i.oracle" | tr '\n' '|')]"
done
grep -qx 'nomatch' "$T/p20.oracle" && grep -qx 'match ' "$T/p2.oracle" || refuse "the oracle's FENCE answers moved: p2 [$(cat "$T/p2.oracle")] p20 [$(cat "$T/p20.oracle")]"
ENTRIES=(arbno_fence_pos_branch_22 arbno_fence_pos_replace_branch_3 fence_pos_rpos_replace_branch_3)
for e in "${ENTRIES[@]}"; do
    python3 "$HERE/corpus_suite_harness.py" extract "$RUNGS/ALL.sno" "$RUNGS/ALL.ref" "$e" "$T/$e.sno" --out-ref "$T/$e.ref" > /dev/null 2>&1 || refuse "could not extract rungs entry $e"
done
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
run() { ( cd "$T" && if [ "$2" = m3 ]; then timeout -k 5 20 "$SCRIP" "$1.sno" < /dev/null; else timeout -k 5 30 "$SCRIP" --compile -o "$1.s" "$1.sno" < /dev/null > /dev/null 2>&1 && gcc "$1.s" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o "$1.bin" > /dev/null 2>&1 && timeout -k 5 20 "./$1.bin" < /dev/null; fi ) 2>&1; }
matrix() { local bad=""
    for i in "${!PROBES[@]}"; do
        run "p$i" "$1" > "$T/p$i.$1"
        cmp -s "$T/p$i.$1" "$T/p$i.oracle" || bad="$bad p$i ${PROBES[$i]} got [$(tr '\n' '|' < "$T/p$i.$1")] want [$(tr '\n' '|' < "$T/p$i.oracle")];"
    done; [ -z "$bad" ] && echo ok || echo "$bad"; }
entries() { local bad=""
    for e in "${ENTRIES[@]}"; do
        run "$e" "$1" > "$T/$e.$1"
        cmp -s "$T/$e.$1" "$T/$e.ref" || bad="$bad $e got [$(tr '\n' '|' < "$T/$e.$1")] want [$(tr '\n' '|' < "$T/$e.ref")];"
    done; [ -z "$bad" ] && echo ok || echo "$bad"; }
arm "m3: the FENCE(P) probe matrix (${#PROBES[@]} probes, bare-FENCE controls included) answers as sbl -bf" "$(matrix m3)"
arm "m4: the FENCE(P) probe matrix (${#PROBES[@]} probes, bare-FENCE controls included) answers as sbl -bf" "$(matrix m4)"
arm "m3: the rungs' ${#ENTRIES[@]} entries of this class answer their .ref" "$(entries m3)"
arm "m4: the rungs' ${#ENTRIES[@]} entries of this class answer their .ref" "$(entries m4)"
[ "$fail" = 0 ] && { echo "GATE PASS [$NAME]: $n/$n arms"; exit 0; }
echo "GATE FAIL [$NAME]"; exit 1
