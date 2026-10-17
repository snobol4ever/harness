#!/usr/bin/env bash
# test_gate_icn_outside_baseline_is_read_and_mirrored.sh -- every OUTSIDE_ARIZONA_BASELINE.tsv under
# corpus/packages/icon is well formed, mirrored into the lockdown buckets with the SAME class word, names
# something that exists, carries the MEASUREMENT that put it there -- and is actually READ by the runner that
# grades its package.  Offline, no oracle, no ./scrip, under two seconds.  hq_T 2026-09-11, ceo CEO-578.
#
# ⛔⭐⭐ WHY THE LAST ARM EXISTS, AND IT IS THE WHOLE REASON THIS GATE WAS WRITTEN. ceo CEO-527 ruled cfuncs and
# extlvals outside the Arizona baseline WEEKS before 09-11, and on 09-11 they were still printing four red cells.
# Two separate failures, and the gate catches both: the rows were never written down, AND the runner that grades
# that package had no reader for the file they belong in -- test_icon_arizona_suite.sh never opened
# OUTSIDE_ARIZONA_BASELINE.tsv at all, while its sister test_icon_jcon_suite.sh had read its own copy since
# CEO-470.  ⭐ A RULING LANDED IN A FILE NO INSTRUMENT OPENS IS INDISTINGUISHABLE FROM A RULING NOBODY MADE, and
# it fails in the expensive direction: everyone believes the question is closed while the board goes on saying no.
# ⛔ The same shape as the hoisted-and-never-wired gate_bin_watch the arizona runner's own header records, and as
# the KEEP.md that declared a pair whose source had left the tree.  The cure is the same one every time: an arm
# that asserts the CONSUMER, not only the DECLARATION.
#
# ⛔ ITS SIBLING IS NOT ITS DUPLICATE, AND THE NAMES ARE CLOSE ENOUGH TO NEED THIS NOTE.
# test_gate_outside_baseline_rows_name_a_live_measurement.sh (hq_R, 2026-09-11) grades the SNOBOL4 packages'
# OUTSIDE_SPITBOL_BASELINE.tsv by RE-ASKING THE ORACLE whether it still refuses each row -- there the oracle's
# refusal IS the premise, and hq_R found five rows quoting the empty string.  That test is meaningless here:
# ARIZONA ANSWERS every row in an Icon OUTSIDE file, and the premise is that the answer is the DISTRIBUTION's
# rather than the LANGUAGE's.  So this gate asks the two questions that premise actually rests on -- is the
# ruling READ by the runner that grades the package, and do the file and its mirror tell one story -- and keeps
# the measurement check only as a FLOOR against a bare name.  ⭐ Two files, two oracles, two premises, two gates;
# merging them would give one gate that asks the wrong question of half its rows.
# ⛔ NOT A BOARD: it grades no corpus program, runs no compiler, publishes no row (CEO-547 -- what makes a run a
# board is the population it grades).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
PKGROOT="$S4E/corpus/packages/icon"
. "$HERE/lib_inventory.sh" 2>/dev/null || { echo "⛔ GATE REFUSES(2): lib_inventory.sh unloadable -- the class vocabulary lives there and this gate will not carry a second copy of it" >&2; exit 2; }
fails=0; checks=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  OK   %s\n' "$2"; else printf '  FAIL %s\n' "$2"; fails=$((fails+1)); fi; }
# ⛔ A GATE THAT FINDS NOTHING TO GRADE REFUSES rc=2 -- it never prints the success shape over an empty census
# (RULES.md; and the failure mode is live here, because these files are created one package at a time).
[ -d "$PKGROOT" ] || { echo "⛔ GATE REFUSES(2): $PKGROOT missing" >&2; exit 2; }
FILES=$(ls "$PKGROOT"/*/OUTSIDE_ARIZONA_BASELINE.tsv 2>/dev/null)
[ -n "$FILES" ] || { echo "⛔ GATE REFUSES(2): no OUTSIDE_ARIZONA_BASELINE.tsv under $PKGROOT -- nothing to grade, and a silent pass here would read as agreement" >&2; exit 2; }
echo "=== OUTSIDE_ARIZONA_BASELINE.tsv, $(printf '%s\n' "$FILES" | wc -l) file(s) under corpus/packages/icon ==="
# ⭐ THE ROW-LEVEL EXEMPTION IS PART OF THE STANDARD, NOT A HOLE IN IT (ceo CEO-516): a key holding ':' names a
# ROW INSIDE a graded program (lgint:bigexp(3 ^ 41)), so it has no shipped file and no mirror by design -- the
# program stays in the denominator, which is the entire intent.  Keys without ':' are programs and carry both.
for f in $FILES; do
  pkg="$(basename "$(dirname "$f")")"
  rows=0
  while IFS=$'\t' read -r name cls reason; do
    case "$name" in ''|'#'*) continue ;; esac
    rows=$((rows+1))
    [ -n "$cls" ] && [ -n "$reason" ] \
      && ck ok "$pkg/$name: three columns (name, CLASS, reason)" \
      || ck fail "$pkg/$name: expected name<TAB>CLASS<TAB>reason -- a row missing its reason is a name with no measurement, which is the thing this file exists to prevent"
    case " $INV_CLASS_UNGRADABLE $INV_CLASS_UNGRADED ROW_OUTSIDE_ORACLE_REACH " in
      *" $cls "*) ck ok "$pkg/$name: class $cls is in the closed vocabulary" ;;
      *) ck fail "$pkg/$name: class '$cls' is in neither INV_CLASS_UNGRADABLE nor INV_CLASS_UNGRADED (nor ROW_OUTSIDE_ORACLE_REACH) -- lib_inventory.sh's vocabulary is closed, and a private class here cannot be sorted by the lane that would pick the work up" ;;
    esac
    # ⭐ hq_V's PRACTICE, MADE ENFORCEABLE (standing since 2026-09-10): A NAME ENTERING A BASELINE FILE CARRIES
    # ITS MEASUREMENT, NEVER JUST THE NAME.  A wrong exclusion costs more than a wrong cure, because a red stays
    # visible and an excluded name cannot be red.  The measurable form of "carries its measurement" is that the
    # reason says what was RUN and, for a program row, what the CONTROL was -- the discriminator the jcon header
    # paid for four times over (geddump/htprep/prepro, recent, kwds, lgint all reversed on a missing control).
    # ⛔⭐ THIS ARM IS A FLOOR, NOT A PROOF, AND SAYING SO IS PART OF IT.  No gate can tell a real measurement
    # from a plausible sentence; what it CAN refuse is a BARE NAME -- a row that asserts a conclusion and cites
    # no observation.  ⛔ ITS FIRST DRAFT MATCHED THE WORD "measured" AND FAILED jcon's THREE lgint ROWS, WHICH
    # CARRY "rc=124 at 600 s" AND "byte-identical" -- as good an observation as this file holds.  That is the
    # trap this tree keeps paying for, committed inside the gate written to police it: THE ARM ASKED A NARROWER
    # QUESTION THAN IT MEANT and would have made three correct rows look like sloppy ones.  Evidence has many
    # spellings; the fix is to look for an OBSERVATION, and to keep the token list open when a new spelling of
    # one shows up.  ⭐ It is deliberately easy to satisfy: the cost of a false FAIL here is a lane rewriting a
    # true row to please a grep, which is worse than the bare-name row it was meant to catch.
    _ev=0
    case "$reason" in *MEASURED*|*measured*|*Measured*|*CONTROL*|*rc=*|*byte-identical*|*prints*|*printed*|*"does not terminate"*) _ev=1 ;; esac
    if [ "$_ev" = 1 ] && [ "${#reason}" -ge 120 ]; then ck ok "$pkg/$name: reason cites an observation (${#reason} chars)"
    elif [ "$_ev" = 1 ]; then ck fail "$pkg/$name: reason cites an observation but is only ${#reason} chars -- too short to say what was run, against what, and what came back"
    else ck fail "$pkg/$name: reason cites no observation (no measurement, control, rc=, byte-identical or printed output) -- a name entering a baseline file carries its measurement, never just the name (hq_V, standing since 2026-09-10)"
    fi
    case "$name" in
      *:*) ck ok "$pkg/$name: ROW-LEVEL key -- exempt from the shipped-file and mirror arms by construction (CEO-516)" ;;
      *)
        [ -f "$(dirname "$f")/$name" ] \
          && ck ok "$pkg/$name: names a shipped file" \
          || ck fail "$pkg/$name: names nothing shipped under $(dirname "$f") -- a rename or a leftover, and it withdraws an exclusion silently"
        # ⛔ THE MIRROR, AND THE CLASS WORD MUST MATCH IT.  The runner's own mirror check asks only whether the
        # name appears in a bucket; this asks whether the two files give the reader THE SAME ANSWER.  One program
        # carries one ruling (the tpp lesson): while two files disagreed about WHY, whichever a reader met first
        # decided whether anybody owed work on it.
        ung="$(awk -F'\t' -v n="$name" '$1==n {print $2; exit}' "$(dirname "$f")/UNGRADED.tsv" 2>/dev/null)"
        ugb="$(awk -F'\t' -v n="$name" '$1==n {print $2; exit}' "$(dirname "$f")/UNGRADABLE.tsv" 2>/dev/null)"
        if [ -n "$ung" ] && [ -n "$ugb" ]; then
          ck fail "$pkg/$name: mirrored in BOTH UNGRADED.tsv and UNGRADABLE.tsv -- one program carries ONE ruling; work owed and nobody-owes-work are opposite answers"
        elif [ -n "$ung$ugb" ]; then
          mirror_cls="$ung$ugb"; where="UNGRADED.tsv"; [ -n "$ugb" ] && where="UNGRADABLE.tsv"
          [ "$mirror_cls" = "$cls" ] \
            && ck ok "$pkg/$name: mirrored in $where with the same class word ($cls)" \
            || ck fail "$pkg/$name: class disagrees across the mirror -- '$cls' here, '$mirror_cls' in $where"
        else
          ck fail "$pkg/$name: mirrored in NEITHER UNGRADED.tsv nor UNGRADABLE.tsv -- out of the graded denominator here and invisible to the lockdown split there, so the population stops summing while every file still reads honest"
        fi ;;
    esac
  done < "$f"
  [ "$rows" -gt 0 ] && ck ok "$pkg: $rows row(s) graded by this gate" || ck fail "$pkg: OUTSIDE_ARIZONA_BASELINE.tsv exists and declares zero rows -- delete it or fill it; an empty exclusion file reads as a ruling that was made"
  # ⛔⭐ THE ARM THIS GATE WAS WRITTEN FOR: DOES THE RUNNER THAT GRADES THIS PACKAGE READ THE FILE?
  runner=""
  case "$pkg" in
    arizona_tests) runner="$HERE/test_icon_arizona_suite.sh" ;;
    jcon_tests)    runner="$HERE/test_icon_jcon_suite.sh" ;;
    *)             runner="" ;;
  esac
  if [ -z "$runner" ]; then
    ck fail "$pkg: no runner is mapped to this package in this gate -- a new package's exclusions would be declared and never read, which is the CEO-578 defect exactly; add the mapping WITH the runner's reader"
  elif [ ! -f "$runner" ]; then
    ck fail "$pkg: mapped runner ${runner##*/} is not on disk"
  else
    grep -q 'OUTSIDE_ARIZONA_BASELINE.tsv' "$runner" \
      && ck ok "$pkg: ${runner##*/} opens OUTSIDE_ARIZONA_BASELINE.tsv" \
      || ck fail "$pkg: ${runner##*/} never opens OUTSIDE_ARIZONA_BASELINE.tsv -- the rows are a ruling no instrument reads (ceo CEO-578: four cells sat red for weeks under exactly this)"
    grep -q 'is_outside_baseline' "$runner" \
      && ck ok "$pkg: ${runner##*/} calls is_outside_baseline" \
      || ck fail "$pkg: ${runner##*/} defines no is_outside_baseline call -- opening the file is not reading it"
    # ⛔ AND IT MUST EXCLUDE BEFORE IT COUNTS. A name subtracted after the denominator moved would ride in the
    # published fraction and be named as excluded in the same breath, which is two answers to one question.
    if excl=$(grep -n 'is_outside_baseline "' "$runner" | grep -v '^[0-9]*:is_outside_baseline()' | head -1 | cut -d: -f1) && [ -n "$excl" ]; then
      cnt=$(grep -nE '^\s*(TOTAL|GRADED)=\$\(\((TOTAL|GRADED)\+1\)\)' "$runner" | head -1 | cut -d: -f1)
      if [ -n "$cnt" ]; then
        [ "$excl" -lt "$cnt" ] \
          && ck ok "$pkg: ${runner##*/} excludes (line $excl) BEFORE it counts (line $cnt)" \
          || ck fail "$pkg: ${runner##*/} counts at line $cnt before excluding at line $excl -- the excluded program rides in the denominator it was ruled out of"
      else ck fail "$pkg: ${runner##*/}: no TOTAL/GRADED increment found, so the ordering cannot be checked -- this gate will not pass on a census it could not take"; fi
    else
      ck fail "$pkg: ${runner##*/} has no is_outside_baseline CALL SITE (only, at most, a definition) -- a reader that is never invoked"
    fi
  fi
done
echo "--- $((checks-fails))/$checks checks passed"
[ "$fails" -eq 0 ] || { echo "⛔ GATE FAILS: $fails check(s) red"; exit 1; }
echo "✅ GATE PASSES"
