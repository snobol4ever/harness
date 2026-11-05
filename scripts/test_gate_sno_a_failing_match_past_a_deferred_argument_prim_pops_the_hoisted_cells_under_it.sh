#!/usr/bin/env bash
# test_gate_sno_a_failing_match_past_a_deferred_argument_prim_pops_the_hoisted_cells_under_it.sh -- A STORED PATTERN THAT FAILS AFTER A DEFERRED-ARGUMENT PRIM LEAVES ITS THUNK AT THE BASE DEPTH
# (hq_snobol4, 2026-11-05; the Flake red punctuation-counter, SIGSEGV in m3 and m4; first bad commit 7cda8c6a0, IR_MATCH_TRAP). THE DEFECT: a primitive whose argument is a deferred name (LEN(*N),
# POS(*N), ANY(*S)...) gets an IR_MATCH_TRAP hung on its omega edge. The planner collected that trap into its primitive's run only inside an alternation or FENCE arm. On the plain chain it was a run
# of its own (E=0 X=0) and its omega, which names the previous primitive's beta, was folded through that trivial beta to the thunk's omega with a pop of 0. POS(0) LEN(*N) BREAK(PUNCT) holds PUNCT's
# coerced set in two hoisted cells (32 bytes) under POS, so the fold left the thunk 32 bytes too deep: the thunk omega loaded r12 from a live cell and jumped into data when BREAK found no delimiter.
# THE CURE (src/planner/zeta_plan.cpp, the main run walk): a trap hung off a node's omega joins that node's run before it when the run already holds a node, as the arm walk always did.
# THE CELLS: each a stored pattern matched against a subject, its expectation CUT FROM sbl -bf AT RUN TIME, run in m3 (--run) and m4 (--compile, linked, run). FAIL_ONCE=1 corrupts the first
# expectation so the gate reads red once; on the cure's parent (a scratch worktree of <cure>^) the cells over POS(0) with a hoisted operand after the deferred prim read red. rc 0 green, 1 red, 2 could not measure.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; RT_DIR="${RT_DIR:-$ROOT/out}"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: lib_oracle_flags.sh unloadable"; exit 2; }
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no sbl oracle -- every expectation is cut from it"; exit 2; }
[ -x "$SCRIP" ] && [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip or runtime"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
CELLS=(
"pos_pos_break|1|'a'|AB,CD|POS(0) POS(*N) BREAK(PUNCT)"
"pos_rpos_span|1|'a'|abc|POS(0) RPOS(*N) SPAN(S2)"
"pos_tab_break|1|'a'|abc|POS(0) TAB(*N) BREAK(PUNCT)"
"pos_rtab_break|1|'a'|AB,CD|POS(0) RTAB(*N) BREAK(PUNCT)"
"pos_len_break|1|'a'|abc|POS(0) LEN(*N) BREAK(PUNCT)"
"pos_len_span|1|'a'|AB,CD|POS(0) LEN(*N) SPAN(S2)"
"pos_len_break_capture|0|'a'|abc|POS(0) LEN(*N) BREAK(PUNCT) LEN(1) @N"
"pos_any_break|0|'zz'|AB,CD|POS(0) ANY(*S) BREAK(PUNCT)"
"pos_notany_break|0|'zz'|abc|POS(0) NOTANY(*S) BREAK(PUNCT)"
"pos_span_span|0|','|abc|POS(0) SPAN(*S) SPAN(S2)"
"pos_break_break|0|'zz'|AB,CD|POS(0) BREAK(*S) BREAK(PUNCT)"
"pos_breakx_break|0|'zz'|abc|POS(0) BREAKX(*S) BREAK(PUNCT)"
"control_literal_operand|0|'a'|abc|POS(0) LEN(*N) BREAK(',')"
"control_head_of_the_chain|0|'a'|abc|LEN(*N) BREAK(PUNCT)"
"control_the_match_succeeds|0|'a'|A,B|POS(0) LEN(*N) BREAK(PUNCT)"
)
RC=0; N=0; A3=0; A4=0; BAD=""; FIRST=1
run_cell() { local n="$1" f="$2" pat="$3"
  want="$( cd "$T" && timeout -k 5 20s "$SBL" "$(sbl_lang_flags)" "$f" </dev/null 2>/dev/null )"
  [ -n "$want" ] || { echo "⛔ GATE REFUSE(2) [$G]: sbl printed nothing for cell $n ($pat)"; exit 2; }
  [ -n "${FAIL_ONCE:-}" ] && [ "$FIRST" = 1 ] && want="$want corrupted by FAIL_ONCE"; FIRST=0
  N=$((N + 1))
  g3="$( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" "$f" </dev/null 2>/dev/null )"
  g4=""; if ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 60s "$SCRIP" --compile --out="$T/$n.s" "$f" </dev/null >/dev/null 2>&1 ) \
      && gcc -m64 -no-pie "$T/$n.s" -L"$RT_DIR" -lscrip_rt -lm -lpthread -Wl,-rpath,"$RT_DIR" -o "$T/$n.bin" 2>/dev/null; then
    g4="$( cd "$T" && timeout -k 5 20s "$T/$n.bin" </dev/null 2>/dev/null )"; fi
  if [ "$g3" = "$want" ]; then A3=$((A3 + 1)); else RC=1; BAD="$BAD
      m3 $n: sbl [$(echo "$want" | tr '\n' ' ' | cut -c1-40)] scrip [$(echo "$g3" | tr '\n' ' ' | cut -c1-60)]   $pat"; fi
  if [ "$g4" = "$want" ]; then A4=$((A4 + 1)); else RC=1; BAD="$BAD
      m4 $n: sbl [$(echo "$want" | tr '\n' ' ' | cut -c1-40)] scrip [$(echo "$g4" | tr '\n' ' ' | cut -c1-60)]   $pat"; fi
}
for c in "${CELLS[@]}"; do IFS='|' read -r n nv sv subj pat <<< "$c"; f="$T/$n.sno"
  { printf "        N = %s\n        S = %s\n        S2 = 'ab'\n        PUNCT = ','\n        TEXT = '%s'\n        PK = %s\n" "$nv" "$sv" "$subj" "$pat"
    printf "        TEXT PK                      :F(NO)\n        OUTPUT = 'match'             :(END)\nNO      OUTPUT = 'no match'\nEND\n"; } > "$f"
  run_cell "$n" "$f" "$pat"; done
f="$T/flake_punctuation_counter_shape.sno"
cat > "$f" <<'EOF'
        COUNT = 0
        PUNCT = '.,:;?!()' "'" '"'
        PAT = POS(0) LEN(*N) BREAK(PUNCT) LEN(1) @N
        TEXT = 'HELLO, WORLD!'
        N = 0
C1      TEXT PAT                     :F(L2)
        COUNT = COUNT + 1            :(C1)
L2      TEXT = 'A(B); C? ' "'" 'D' "'" '.'
        N = 0
C2      TEXT PAT                     :F(PR)
        COUNT = COUNT + 1            :(C2)
PR      OUTPUT = 'THERE ARE ' COUNT ' PUNCTUATION MARKS.'
END
EOF
run_cell flake_punctuation_counter_shape "$f" "the Flake punctuation-counter loop"
echo "  blocking: m3 $A3 of $N cells and m4 $A4 of $N cells agree with sbl -bf"
[ -n "$BAD" ] && printf '  ⛔ failing cells:%s\n' "$BAD" | head -40
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N cells, a failing match past a deferred-argument primitive agrees with sbl -bf in m3 and m4"
else echo "GATE FAIL(1) [$G]: $((N - A3)) m3 and $((N - A4)) m4 cells disagree with sbl -bf"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY) oracle: $SBL measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
