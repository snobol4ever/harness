#!/usr/bin/env bash
# test_gate_pl_meta_wrapper_does_not_break_m4_declarations.sh -- the landing gate of row
# prolog-meta-call-wrapper-registration-broke-two-m4-witnesses (hq_C 2026-09-06).
#
# WHAT IT GUARDS. a4bbdb554 ("the meta-call bridge now reaches BUILTINS, seeded from the tree's own table")
# synthesises name(A..) :- name(A..) for every entry of pl_det_leaves[] plus a five-name early table and
# registers each through pl_bb_register/pl_new_proc. Bisected on adjacent commits with one variable, that
# registration turned TWO ladder witnesses m4-red while leaving m3 correct:
#     ladder__rung06_declarations_dynamic            m3=PASS m4=FAIL(rc=0)  -- :- dynamic(foo/1) does not take
#                                                                              effect in m4; the call raises
#                                                                              existence_error(procedure,foo/1)
#     ladder__rung16_termio_current_char_conversion  m3=PASS m4=FAIL(rc=1)  -- ERROR 022 Undefined function called
# Green at a4bbdb554^ (001f904e2) in both modes; red at a4bbdb554; still red at 3377cf43e.
#
# ⛔ IT IS NOT NAME SHADOWING, and this gate exists so nobody re-derives that. None of dynamic/1,
# char_conversion/2, current_char_conversion/2 is in pl_det_leaves[] or in the early table -- all three are
# special-cased ABOVE the leaf lookup in goal(). No wrapper stands in front of them; the damage comes from the
# bulk registration itself, on the compiled side only.
#
# ⭐ THE GRADING IS NOT REIMPLEMENTED HERE. It defers to test_prolog_ladder.sh, which owns the population, the
# refs and the m4 recipe, and greps that runner's own verdict lines. A criterion that re-cut its own refs could
# drift away from the ladder it claims to protect; this one cannot.
#
# ⭐ THE m3 ARM IS A CONTROL, NOT A SECOND CHECK. Both witnesses pass in m3 today and the defect is m4-only. If
# m3 goes red the baseline itself is broken, and this gate REFUSES rc=2 rather than reporting an m4 defect it can
# no longer attribute -- a red here must mean "the m4 regression is present", never "something upstream died".
#
# EXIT: 0 both witnesses m4=PASS · 1 either m4-red (the regression is live) · 2 REFUSED (cannot measure).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
RUNNER="$HERE/test_prolog_ladder.sh"
S="$ROOT/scrip"; RT="$ROOT/out/libscrip_rt.so"
[ -x "$RUNNER" ] || { echo "REFUSE (rc=2): no test_prolog_ladder.sh at $RUNNER"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "REFUSE (rc=2): no built ./scrip in $ROOT -- run make first"; exit 2; }
# ⛔ AND NOT MERELY PRESENT -- CURRENT. This gate's whole verdict is a claim about how a BUILT BINARY behaves
# in m4, so a binary older than the sources is a verdict about a tree nobody has. -x answers "does a file
# exist", which is the narrower question, and the two are indistinguishable in the output.
# ⭐ THE SHIM, NOT A COPY: every rule about what counts as stale lives in gate_require_fresh (lib_gate.sh);
# util_require_fresh.sh is a calling convention over it. A fourth copy of the staleness idea is exactly what
# that file exists to prevent (hq_B, added 2026-09-06 after ARM 15 of test_gate_runners_refuse_on_a_stale_binary.sh
# named this gate as the 1 of 112 executing scrip with no guard, reddening make test for the whole fleet).
"$HERE/util_require_fresh.sh" --gate "pl_meta_wrapper_does_not_break_m4_declarations" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
# WITNESS<TAB>RUNG -- the two the registration broke, each graded on the rung that owns it.
WITNESSES="ladder__rung06_declarations_dynamic	6
ladder__rung16_termio_current_char_conversion	16"
graded=0; m4_red=0; refused=0
while IFS="	" read -r w rung; do
  [ -n "$w" ] || continue
  log="$TMP/rung$rung.log"
  [ -s "$log" ] || timeout -k 5 900 bash "$RUNNER" --only "$rung" > "$log" 2>&1
  line="$(grep -F "$w" "$log" | head -1)"
  if [ -z "$line" ]; then
    echo "REFUSE (rc=2): $w produced no verdict line on rung $rung -- the runner graded zero witnesses for it"
    refused=1; continue
  fi
  graded=$((graded+1))
  m3="FAIL"; m4="FAIL"
  case "$line" in *m3=PASS*) m3="PASS";; esac
  case "$line" in *m4=PASS*) m4="PASS";; esac
  if [ "$m3" != "PASS" ]; then
    echo "REFUSE (rc=2): $w is RED IN m3 -- the control arm is broken, so an m4 verdict here would be unattributable"
    echo "    $line"
    refused=1; continue
  fi
  if [ "$m4" != "PASS" ]; then
    echo "⛔ m4 RED: $w"; echo "    $line"; m4_red=$((m4_red+1))
  else
    echo "✅ m4 PASS: $w"
  fi
done <<< "$WITNESSES"
scrip_h="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
corpus_h="$(git -C "$ROOT/../corpus" rev-parse --short HEAD 2>/dev/null || echo unknown)"
echo "    tree: SCRIP=$scrip_h corpus=$corpus_h  graded=$graded of 2 witnesses (m4 arm; m3 as control)"
[ "$refused" -eq 1 ] && exit 2
[ "$graded" -eq 2 ] || { echo "REFUSE (rc=2): graded $graded of 2 witnesses"; exit 2; }
if [ "$m4_red" -gt 0 ]; then
  echo "⛔ GATE FAIL: $m4_red of 2 witnesses m4-red -- the a4bbdb554 wrapper-registration regression is LIVE"; exit 1
fi
echo "GATE PASS(0) [test_gate_pl_meta_wrapper_does_not_break_m4_declarations]: 2 of 2 m4-green"; exit 0
