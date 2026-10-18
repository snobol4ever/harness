#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# A match region opened INSIDE A PROCEDURE must have its watermark spent on EVERY edge that leaves the region, not
# only on the edge the statement happens to end on.  zd_exit_pop_s (src/emitter/emit.cpp) applies the close-tracker
# correction only when the exit node is IR_STATEMENT_END / IR_STATEMENT / IR_GOTO_DEFERRED; every other terminal path
# node gets `full`, which OVER-POPS by the match-region interior carve that MATCH_END has already whacked.
#
# ⛔⭐ THE CLASS THIS INSTRUMENT CAN ELIMINATE IN, DECLARED HERE BECAUSE AN UNDECLARED CLASS IS THE DEFECT THIS ROW
# EXISTS BESIDE.  It grades ONE construct family: a match used as an if/while CONDITION inside a procedure, left by
# a named set of edges.  Its green says NOTHING about match regions left by any edge not listed below, about matches
# outside a procedure, or about any other frontend.  The sibling gate
# test_gate_sn4_replacement_releases_its_post_match_spine.sh was green and honest on the tree that first shipped this
# defect, because every one of ITS witnesses leaves by FALL-THROUGH -- an honest instrument with an undeclared class
# is caught by nobody, since every reader who checks it finds it telling the truth about a population they were never
# given the boundary of.  So: the boundary is the EXIT EDGE, and it is named per arm.
#
# ⛔ GRADED ON OUTPUT, NEVER ON rc.  The survivors exit rc=2 (silent), rc=2 and rc=139, so an instrument keyed on
# rc=139 sees a third of the population and reads the rest as a different class or as passing (hq_I, measured).
# ⛔ EXPECTATIONS ARE PINNED, NOT CUT FROM AN ORACLE, and that is a real weakness stated rather than hidden: there is
# no Snocone oracle binary (sbl runs SPITBOL, not this syntax), so ../harness/scripts/test_smoke_snocone.sh pins its expectations
# inline too and this follows that convention.  Each value below is what the construct must mean, cross-checked
# against hq_I's six-witness table measured on both sides of SCRIP 152461d75.
#
# ✅ CURED AND WIRED.  Owner: hq_U.  Row:
# snocone-the-match-region-watermark-is-spent-on-one-edge-so-non-local-exits-out-of-the-region-overpop (rank 0).
# It landed RED 6/9 at SCRIP 910f27184 -- deliberately UNWIRED, because a red gate in the blocking set is a broken
# build for every seat -- and is wired into `make test` HERE, BY THE CURE, per CEO-381.  A gate that lands red with
# an owner and a row named in its own header is a debt with a due date; one that lands red with neither is a line
# every seat learns to ignore.
#
# ⭐ FAIL-ONCE/PASS-ONCE IS PROVEN ON ONE BINARY, NOT BY STASH-AND-REBUILD: the cure carries the killswitch
# SCRIP_ZD_CLOSE=0, so `SCRIP_ZD_CLOSE=0 bash $0` reproduces 6/9 with the same three arms red and `bash $0`
# reads 9/9, from the same ./scrip.  ⛔ THE KILLSWITCH IS A MEASUREMENT INSTRUMENT, NOT A SUPPORTED CONFIGURATION:
# nothing may depend on the OFF position, which is the retired behaviour and is kept only so the next reader can
# re-derive the delta without owning a second tree.
# THE KILLSWITCH IS DELETED (hq_zetas 2026-10-17, the spine flip, under the cto's review: ZETA HAS NO MODES, and CEO-1680
# allows no seam in SCRIP for a test): the 6/9 above was measured at the cure's landing and stands as history.
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 1
SCRIP=./scrip
[ -x "$SCRIP" ] || { echo "GATE SNO-REGION-EXIT: REFUSE -- no ./scrip, run make"; exit 2; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
pass=0; fail=0; graded=0
emit() { printf '%s\n' "$2" > "$T/$1.sc"; }
#  name                     exit edge under test                      program                                                                                     want
emit fallthrough_empty  'function f(s) { if (s ? "h") { } return "done"; }
OUTPUT = f("hi");'
emit fallthrough_store  'function f(s) { t = "zz"; if (s ? "h") { t = "zz"; } return t; }
OUTPUT = f("hi");'
emit while_zero_iter    'function f(s) { while (s ? "zzz") { } return "done"; }
OUTPUT = f("hi");'
emit return_out_of_if   'function f(s) { if (s ? "h") { return "yy"; } return "done"; }
OUTPUT = f("hi");'
emit while_back_edge    'function f(s) { while (s ? "h") { s = "xx"; } return "done"; }
OUTPUT = f("hi");'
emit nested_return      'function f(s) { if (s ? "h") { if (s ? "i") { return "yy"; } } return "done"; }
OUTPUT = f("hi");'
emit ctl_numeric_while  'function f(s) { i = 0; while (LT(i, 2)) { i = i + 1; } return "done"; }
OUTPUT = f("hi");'
emit ctl_bare_then_ret  'function f(s) { s ? "h"; return "Y"; }
OUTPUT = f("hi");'
emit ctl_top_level      's = "hi";
if (s ? "h") { OUTPUT = "yy"; }
OUTPUT = "done";'
grade() {  # $1 name  $2 want  $3 edge-under-test  $4 CURED|CONTROL
  local n="$1" want="$2" edge="$3" kind="$4" got rc
  got=$(timeout -k 5 20 "$SCRIP" "$T/$n.sc" < /dev/null 2>&1); rc=$?
  graded=$((graded+1))
  if [ "$got" = "$want" ]; then
    pass=$((pass+1)); echo "  ok   $kind  $n  [$edge]"
  else
    fail=$((fail+1))
    echo "  FAIL $kind  $n  [$edge]  rc=$rc  want=[$want] got=[$(printf '%s' "$got" | tr '\n' '|' | cut -c1-40)]"
    [ "$kind" = CONTROL ] && echo "       ^ CONTROL -- this shape was GREEN before the cure, so a red here is a REGRESSION, not the class"
  fi
}
echo "== already cured at SCRIP 152461d75: the region is left by FALL-THROUGH =="
grade fallthrough_empty  'done'    'fall-through, empty branch'      CURED
grade fallthrough_store  'zz'      'fall-through, store in branch'   CURED
grade while_zero_iter    'done'    'while cond, ZERO iterations'     CURED
echo "== the class: the region is left by an edge that BYPASSES the close =="
grade return_out_of_if   'yy'      'procedure RETURN out of branch'  CURED
grade while_back_edge    'done'    'while BACK-EDGE, one iteration'  CURED
grade nested_return      'yy'      'nested if + RETURN'              CURED
echo "== controls: each removes exactly ONE ingredient and must stay green =="
grade ctl_numeric_while  'done'    'non-local edge, NO match'        CONTROL
grade ctl_bare_then_ret  'Y'       'match closed by fall-through, later return' CONTROL
grade ctl_top_level      'yy
done'                              'same statement, NO procedure'    CONTROL
if [ "$graded" -eq 0 ]; then echo "GATE SNO-REGION-EXIT: REFUSE -- graded zero witnesses"; exit 2; fi
echo "GATE SNO-REGION-EXIT: $pass passed, $fail failed, $graded graded of 9 expected"
[ "$graded" -eq 9 ] || { echo "GATE SNO-REGION-EXIT: REFUSE -- denominator is $graded, expected 9"; exit 2; }
[ "$fail" -eq 0 ] || exit 1
