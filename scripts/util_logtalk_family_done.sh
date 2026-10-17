#!/usr/bin/env bash
# util_logtalk_family_done.sh -- the DONE-WHEN body of one Logtalk FAMILY row (ceo CEO-650): grades each named group
# with util_logtalk_grade.py --group (a development aid, never a board -- the coo's test_prolog_logtalk_suite.sh is the
# board) in BOTH modes and is green only when every group's cases ALL PASS IN BOTH MODES over a non-zero population.
#
# ⛔⭐ THE VERDICT IS both-modes-pass == population, NOT FAIL=0, AND THE DIFFERENCE IS A FALSE GREEN THAT
# FIRED (hq_C, 2026-09-13). FAIL is not the only way to not pass: the runner's own doctrine is that a case
# it cannot set up is UNGRADED, named with its reason, "never dropped from the population and never counted
# as passing" -- but a FAIL=0 verdict counts it as passing anyway. Measured that day: a harness change
# turned the 15 cases blocked on stream aliases from FAIL into UNGRADED, and this script immediately
# reported `escape_sequences PASS cases=12 both-modes=8` -- a green group with a THIRD of its cases
# unmeasured, printed on the same line as the 8 that were. ⭐ Nothing about the change was wrong: the
# reclassification was correct and made the board MORE honest. The defect was that this verdict read one of
# the six buckets and treated the other five as empty, so becoming more honest upstream read as becoming
# greener here -- a criterion that improves when the work becomes less measurable can never close its row.
#
# ⛔⭐ ROUTED CASES: SCOPED MEANS ROUTED, NEVER SUBTRACTED (cto ruling to hq_C, 2026-09-13). A family row whose
# group contains cases that only ANOTHER seat's lane can cure narrows its verdict by DECLARING them in
# ../harness/scripts/lib_logtalk_routed.tsv with the row that now owns each one. This gate prints every routed case BY
# NAME with its owning row on every run -- a case dropped silently and a case never measured produce the same
# output, and only naming separates them. ⭐ The declaration expires by itself: a routed case that PASSES, or
# that is not in the group's population at all, REFUSES(2) instead of passing, because a tolerated-red list is
# written when the red is found and read long after it is closed, and so goes stale in the flattering
# direction. The day the owning row lands, the routed cases come back into this row's denominator.
# Usage: bash ../harness/scripts/util_logtalk_family_done.sh <group> [<group>...]
# rc 0 green AND the row may be declared done · 1 red · 2 could not measure, OR every case passes and the DONE
# CLAIM IS REFUSED because a group's population could not have produced the counter-example (see the cross-index
# block below) -- rc 2 is never a pass, so a caller that tests `rc = 0` is already correct without knowing which.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
SUITE="$ROOT/../corpus/packages/prolog/logtalk_iso"; [ -d "$SUITE" ] || { echo "⛔ REFUSE(2): no logtalk_iso at $SUITE"; exit 2; }
[ $# -ge 1 ] || { echo "⛔ REFUSE(2): name at least one group (a directory basename under $SUITE)"; exit 2; }
ROUTED_TSV="${LOGTALK_ROUTED_TSV:-$HERE/lib_logtalk_routed.tsv}"
ALLCSV="$SUITE/ALL.csv"; [ -f "$ALLCSV" ] || { echo "⛔ REFUSE(2): no ALL.csv at $ALLCSV -- the population census a routed declaration is audited against"; exit 2; }
RC=0; POP=0; BOTH=0; F3=0; F4=0; OUT=0; N=$#; ROUTED_TOTAL=0; UNWIT=""; MISPOP=""
for G in "$@"; do
  RAW=$(cd "$ROOT" && timeout -k 5 900 python3 ../harness/scripts/util_logtalk_grade.py --suite "$SUITE" --scrip "$SCRIP" --modes m3,m4 --group "$G" --name-reds 2>&1) || true
  L=$(printf '%s\n' "$RAW" | grep -m1 '^BOARD_FOR_SHELL ') || true
  out=$(printf '%s' "$L" | grep -oE 'outside=[0-9]+' | head -1); out=${out#outside=}
  set -- $L; [ "${1:-}" = BOARD_FOR_SHELL ] && [ "${2:-0}" -gt 0 ] || { echo "⛔ REFUSE(2): group $G graded nothing ($L)"; exit 2; }
  pop=$2; both=$3; p3=$4; f3=$5; p4=$6; f4=$7
  # ⛔ THE GRADED DENOMINATOR IS THE POPULATION MINUS WHAT THE ORACLE CANNOT RUN, AND IT IS NAMED EVERY TIME
  # IT IS USED (cto ruling 2026-09-13; RULES.md FACT RULE CEO-542, CEO-391: outside-the-baseline is named
  # beside the suite, out of the denominator, NEVER HIDDEN). ⭐ An absent outside= field means an OLDER grader
  # that cannot assign the bucket -- it reads 0 and the verdict falls back to the full population, which is
  # the strict direction. A missing measurement must never be the lenient one.
  [ -n "$out" ] || out=0
  gpop=$((pop-out)); OUT=$((OUT+out))
  POP=$((POP+pop)); BOTH=$((BOTH+both)); F3=$((F3+f3)); F4=$((F4+f4))
  [ "$gpop" -gt 0 ] || { echo "⛔ REFUSE(2): group $G has $pop case(s) and ALL of them are outside the baseline -- a group with an empty graded denominator cannot be PASSED or RED, and calling it green would be a verdict on nothing"; exit 2; }
  # ---- routed cases: named every run, and the declaration is policed rather than trusted --------------
  REDS=$(printf '%s\n' "$RAW" | sed -n "s/^[[:space:]]*RED $G:\([^:]*\):.*/\\1/p" | sort -u)
  ROUTED=$(awk -F'\t' -v g="$G" '$1==g && $1 !~ /^#/ {print $2}' "$ROUTED_TSV" 2>/dev/null | sort -u)
  NROUTED=0
  if [ -n "$ROUTED" ]; then
    POPNAMES=$(awk -F, -v g="$G" '$2 ~ "^"g":" {sub("^"g":","",$2); print $2}' "$ALLCSV" | sort -u)
    for r in $ROUTED; do
      printf '%s\n' "$POPNAMES" | grep -qx -- "$r" || { echo "⛔ REFUSE(2): $G routes $r to another row, and $ALLCSV has no such case in this group -- a carve-out naming a case that does not exist can never be audited or expire (renamed? absorbed? deleted?)"; exit 2; }
      if printf '%s\n' "$REDS" | grep -qx -- "$r"; then NROUTED=$((NROUTED+1))
      else echo "⛔ REFUSE(2): $G routes $r to $(awk -F'\t' -v g="$G" -v c="$r" '$1==g&&$2==c{print $3}' "$ROUTED_TSV"), and that case now PASSES -- the owning row has landed, so this declaration is STALE and the case comes back into this row's denominator. Delete its line from $ROUTED_TSV and re-run."; exit 2; fi
    done
    echo "  $G  ROUTED $NROUTED case(s) OUT of this row's verdict and INTO another row -- named, never subtracted:"
    for r in $ROUTED; do awk -F'\t' -v g="$G" -v c="$r" '$1==g&&$2==c{printf "      %s  ->  %s\n           %s\n", c, $3, $4}' "$ROUTED_TSV"; done
  fi
  # ---- the cross-index: the denominator this verdict SHOULD be read against (cto ruling 2026-09-13) -----
  # ⛔⭐ A PREDICATE'S EPONYMOUS GROUP IS NOT ITS DENOMINATOR. predicates/atom_concat_3 read 28 of 28 before
  # and after a real cure and predicates/put_code_2 read 10 of 16 before and after, because every case in
  # both is ASCII and byte indexing and character indexing agree on every ASCII atom -- neither group could
  # have gone red however wrong its predicate was. An instrument that cannot produce the red is
  # indistinguishable from one that found none, and only the second is evidence. The cross-index is derived
  # mechanically from the suite's own ALL.csv feature columns, never hand-kept.
  # ⛔⭐ ARMED, AND ARMED AGAINST THE CLAIM AND NOT AGAINST THE WORK (cto ruling to hq_C, 2026-09-13). The
  # index runs ORDINARY here -- it prints and PROCEEDS, so an unwitnessed group stays workable, stays
  # gradeable and can still read PASS on its own line. What the switch takes away is the right to be
  # DECLARED DONE: the refusal is applied ONCE, at the verdict, and only where the verdict would otherwise
  # have been GREEN. A red row is never stopped by it. A big-bang --strict over the grading path would have
  # stopped 40 live rows in two lanes to remove a false confidence nobody was acting on -- a cure that
  # trades one thing for another (CEO-589), which is no better as process than it is in the suite.
  CLAIM=""
  if [ -f "$HERE/util_logtalk_crossindex.py" ]; then
    CIOUT=$(LOGTALK_SUITE="$SUITE" python3 "$HERE/util_logtalk_crossindex.py" --group "$G" 2>&1) || true
    printf '%s\n' "$CIOUT" | grep -v '^CROSSINDEX_CLAIM '
    CLAIM=$(printf '%s\n' "$CIOUT" | sed -n "s/^CROSSINDEX_CLAIM $G //p" | head -1)
    case "$CLAIM" in
      MIS-POPULATED) MISPOP="$MISPOP $G" ;;
      UNWITNESSED)   UNWIT="$UNWIT $G" ;;
      CLEAN|"")      : ;;
    esac
  fi
  ROUTED_TOTAL=$((ROUTED_TOTAL+NROUTED)); scoped=$((gpop-NROUTED))
  UNROUTED=$(comm -23 <(printf '%s\n' "$REDS" | sed '/^$/d') <(printf '%s\n' "$ROUTED" | sed '/^$/d'))
  if [ "$both" = "$gpop" ]; then echo "  $G  PASS  graded=$gpop both-modes=$both$([ "$out" -gt 0 ] && echo "  (+$out OUTSIDE the baseline, of $pop)")"
  elif [ "$NROUTED" -gt 0 ] && [ -z "$UNROUTED" ] && [ "$both" = "$scoped" ]; then
    echo "  $G  PASS  scoped=$scoped both-modes=$both  (+$NROUTED ROUTED, named above; of $gpop graded)$([ "$out" -gt 0 ] && echo "  (+$out OUTSIDE the baseline, of $pop)")"
  else echo "  $G  RED   graded=$gpop both-modes=$both m3_fail=$f3 m4_fail=$f4 not-passing=$((gpop-both)) routed=$NROUTED$([ "$out" -gt 0 ] && echo "  (+$out OUTSIDE the baseline, of $pop)")"
    [ -n "$UNROUTED" ] && { echo "      not-passing and NOT routed -- this row's own:"; printf '        %s\n' $UNROUTED
      nu=$(printf '%s\n' "$UNROUTED" | sed '/^$/d' | wc -l); rem=$((gpop-both-NROUTED-nu))
      [ "$rem" -gt 0 ] && echo "      ⛔ and $rem further case(s) are not passing with no RED line of their own -- that remainder is UNGRADED, which this verdict counts as not passing (see the false-green note at the top)"; }
    [ -z "$UNROUTED" ] && [ "$NROUTED" -gt 0 ] && echo "      ⛔ every named RED is routed, yet $((gpop-both-NROUTED)) more case(s) are not passing -- the remainder is UNGRADED, which this verdict counts as not passing (see the false-green note at the top)"
    RC=1; fi
done
VERDICT=$([ $RC = 0 ] && echo GREEN || echo RED)
# ⛔⭐ THE DONE CLAIM IS REFUSED HERE AND NOWHERE EARLIER. Every case was graded, every number above is
# real, and the group lines say PASS where they earned it -- what this refuses is RECORDING the family as
# closed on a population that could not have produced the counter-example. ⭐ It expires by itself: both
# classes are recomputed from ALL.csv on every run, so the refusal lifts the moment a witness exists and
# returns the moment one is lost. Nobody has to remember to take it off, which is the only kind of
# carve-out that does not go stale in the flattering direction.
if [ -n "$UNWIT$MISPOP" ]; then
  if [ $RC = 0 ]; then VERDICT="REFUSE(2)-DONE-CLAIM"; else VERDICT="RED-AND-THE-DONE-CLAIM-IS-ALREADY-REFUSED"; fi
fi
echo "LOGTALK_FAMILY groups=$N cases=$POP outside=$OUT routed=$ROUTED_TOTAL graded=$((POP-OUT)) scoped=$((POP-OUT-ROUTED_TOTAL)) both_modes_pass=$BOTH m3_fail=$F3 m4_fail=$F4 verdict=$VERDICT  tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
if [ -n "$UNWIT$MISPOP" ]; then
  LOGTALK_SUITE="$SUITE" python3 "$HERE/util_logtalk_crossindex.py" --group $UNWIT $MISPOP --strict >/dev/null
  if [ $RC = 0 ]; then
    echo "⛔ REFUSE(2) THE DONE CLAIM: every graded case in this row passes in both modes, and the row may NOT be recorded as closed."
    echo "   The work is not refused and nothing above was suppressed -- keep curing, keep re-running this gate. What is refused is the DECLARATION."
    exit 2
  fi
  echo "⚠ This row is RED, so the DONE claim is not yet in question -- but the group(s) named above cannot be declared closed even when they go green. Read the refusal now rather than at the end."
fi
exit $RC