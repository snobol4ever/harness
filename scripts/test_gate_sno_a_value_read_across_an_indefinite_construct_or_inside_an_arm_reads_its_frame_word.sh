#!/usr/bin/env bash
# test_gate_sno_a_value_read_across_an_indefinite_construct_or_inside_an_arm_reads_its_frame_word.sh -- A STORED PATTERN'S HOISTED OPERAND (ANY(B)'s coerced set, computed at the
# thunk's entry) IS READ THROUGH ITS ACTIVATION-FRAME WORD WHENEVER THE SPINE DEPTH BETWEEN ITS PRODUCER AND ITS READER IS NOT ONE NUMBER (hq_snobol4, 2026-10-25; the Gimpel red peel_driver,
# first bad commit 8eb445d88, D1). THE DEFECT, TWO HALVES OF ONE WALK: planner_act_build grants a VALUE cell its frame word when act_walk_crosses finds an unbounded box on the gamma path from
# producer to reader. (1) An ALTERNATE whose exit is indefinite (an arm holds an ARBNO, so planner_alt_exit refuses and the template takes the op_alt_cell road) was not a hazard: on the ARBNO
# arm the join sits 16 bytes deeper than the plan's 32 + 16 and ANY read its set 8 bytes into the alternation's record -- ('(' | ARBNO(NOTANY(','))) @K2 ANY(B) answered k2=0 in m3 and
# failed in m4. (2) The walk followed the producer's top-level gamma chain only, so a reader inside an alternation's arm or a FENCE's body was never reached, the walk answered "not found" and
# no word was granted -- R (ANY(B) | '#') @K2 after a stored ARBNO R died in rt_sg_member on a garbage set, and PEEL's BALX(...) (@K2 ANY(BEFORE) | RPOS(0) @K2) peeled a word in two.
# THE CURE (src/planner/act_words.cpp act_chain_crosses): the walk descends into the arm or body that holds the reader and counts an indefinite-exit ALTERNATE as a hazard.
# THE CELLS: each a stored pattern matched against 'alpha, beta', its expectation CUT FROM sbl -bf AT RUN TIME, run in m3 (--run) and m4 (--compile, linked, run). FAIL_ONCE=1 corrupts the first
# expectation so the gate reads red once; on the cure's parent (a scratch worktree of <cure>^) cells 1-8 read red. rc 0 green, 1 red, 2 could not measure.
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
"indefinite_alternation_then_any|('(' | ARBNO(NOTANY(','))) @K2 ANY(B)"
"indefinite_alternation_after_pos|POS(0) (ANY(A) | GBAL ARBNO(GBAL)) @K2 ANY(B)"
"reader_in_an_arm_after_a_deferred_arbno|R (ANY(B) | '#') @K2"
"reader_in_a_nested_arm|('(' | R (@K2 ANY(B) | RPOS(0) @K2))"
"reader_in_an_arm_after_capture|('(' | R @K2 ANY(B))"
"reader_in_a_fence_body|R FENCE(ANY(B) | '#') @K2"
"reader_in_a_fence_around_the_deferred|FENCE(R ANY(B)) @K2"
"peel_shape|POS(0) TAB(*K1) (ANY(A) @K2 | GBAL ARBNO(GBAL) (@K2 ANY(B) | ANY(A) @K2 | RPOS(0) @K2))"
"control_reader_on_the_main_path|R ANY(B) @K2"
"control_literal_set|('(' | ARBNO(NOTANY(','))) @K2 ANY(',')"
)
RC=0; N=0; A3=0; A4=0; BAD=""; FIRST=1
for c in "${CELLS[@]}"; do n="${c%%|*}"; pat="${c#*|}"; f="$T/$n.sno"
  { printf "        A = '( ,<'\n        B = ') ,>'\n        GBAL = \"'\" BREAK(\"'\") \"'\" | NOTANY(\"'\")\n        R = ARBNO(NOTANY(','))\n        K1 = 0\n"
    printf "        S = 'alpha, beta'\n        PK = %s\n        S PK                         :F(NO)\n        OUTPUT = 'k2=' K2            :(END)\nNO      OUTPUT = 'no match'\nEND\n" "$pat"; } > "$f"
  want="$( cd "$T" && timeout -k 5 20s "$SBL" "$(sbl_lang_flags)" "$f" </dev/null 2>/dev/null )"
  [ -n "$want" ] || { echo "⛔ GATE REFUSE(2) [$G]: sbl printed nothing for cell $n ($pat)"; exit 2; }
  [ -n "${FAIL_ONCE:-}" ] && [ "$FIRST" = 1 ] && want="$want corrupted by FAIL_ONCE"; FIRST=0
  N=$((N + 1))
  g3="$( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" "$f" </dev/null 2>/dev/null )"
  g4=""; if ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 60s "$SCRIP" --compile --out="$T/$n.s" "$f" </dev/null >/dev/null 2>&1 ) \
      && gcc -m64 -no-pie "$T/$n.s" -L"$RT_DIR" -lscrip_rt -lm -lpthread -Wl,-rpath,"$RT_DIR" -o "$T/$n.bin" 2>/dev/null; then
    g4="$( cd "$T" && timeout -k 5 20s "$T/$n.bin" </dev/null 2>/dev/null )"; fi
  if [ "$g3" = "$want" ]; then A3=$((A3 + 1)); else RC=1; BAD="$BAD
      m3 $n: sbl [$want] scrip [$(echo "$g3" | tr '\n' ' ' | cut -c1-60)]   $pat"; fi
  if [ "$g4" = "$want" ]; then A4=$((A4 + 1)); else RC=1; BAD="$BAD
      m4 $n: sbl [$want] scrip [$(echo "$g4" | tr '\n' ' ' | cut -c1-60)]   $pat"; fi
done
echo "  blocking: m3 $A3 of $N cells and m4 $A4 of $N cells agree with sbl -bf"
[ -n "$BAD" ] && printf '  ⛔ failing cells:%s\n' "$BAD" | head -30
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N cells, every hoisted operand read across an indefinite construct or inside an arm agrees with sbl -bf in m3 and m4"
else echo "GATE FAIL(1) [$G]: $((N - A3)) m3 and $((N - A4)) m4 cells disagree with sbl -bf"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY) oracle: $SBL measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
