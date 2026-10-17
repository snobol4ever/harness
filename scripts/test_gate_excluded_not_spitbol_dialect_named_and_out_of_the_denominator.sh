#!/usr/bin/env bash
# test_gate_excluded_not_spitbol_dialect_named_and_out_of_the_denominator.sh -- EVERY SNOBOL4 PACKAGE'S EXCLUDED.tsv NAMES ONLY
# SHIPPED PROGRAMS THAT SPITBOL REJECTS, WITH THE CSNOBOL4 FEATURE NAMED, AND THE SUITE ROW CARRIES THE COUNT (ceo CEO-1286).
#
# LON 2026-09-26, in-chat to the ceo, verbatim: "The task is to identify which of the test programs found in the original package
# are in the SPITBOL dialect. We want to exclude from the denominator all that are not SPITBOL dialect. We want to show this number
# of EXCLUDED tests in the test-suite grid." -- and the test: "So the way to tell if a program is SPITBOL dialect is two-fold, 1st
# is rejected by SPITBOL, and 2nd why it is rejected is a CSNOBOL4 feature not supported. Then if these two are true it is NOT
# SPITBOL dialect."
#
# ARMS, per package under corpus/packages/snobol4 (aisnobol csnobol4_suite dotnet gimpel snoflake_suite spitbol_testpgms
# spitbol_x64_tests -- a package with no EXCLUDED.tsv is RED: EXCLUDED=0 is a ruling written down, never an absence):
#   (a) every row is name<TAB>NOT_SPITBOL_DIALECT<TAB>evidence, the evidence 60+ chars naming CSNOBOL4 and sbl -bf
#   (b) every name ships (the file exists) and is not a CONTAINERS.tsv row (a container is already out of shipped)
#   (c) HALF ONE OF THE TEST, MEASURED: every name (or its <name>_driver, gimpel) is in OUTSIDE_SPITBOL_BASELINE.tsv -- the record of
#       what sbl -bf refuses; a program the oracle runs cannot be excluded whatever feature it uses
#   (d) no name twice
#   (a') OR the row is name<TAB>DEFERRED-AFTER-ANNOUNCEMENT-LON-2026-09-27<TAB>evidence (ceo CEO-1345; Lon 2026-09-27, verbatim: "The EXIT()
#       feaure to save/resume executables will be done but after the announcement"), the evidence 60+ chars citing CEO-1345 -- a
#       program the oracle RUNS, so arm (c) does not apply to it; the runner grades it, names it and leaves it out of the denominator
#   (a'') OR the row is name<TAB>NO_ORACLE_ANSWER<TAB>evidence (ceo CEO-1696; Lon 2026-10-11, verbatim: "Exclude any program in which we
#       have no way to get output from an oracle, or in which we do not know the answer."), the evidence 60+ chars citing CEO-1696, and
#       arm (c) MEASURES the premise instead: sbl -bf, run in a scratch copy of the package with stdin /dev/null, prints nothing on
#       stdout or does not finish inside 5 s -- a program the oracle answers is debt in the denominator, never this row
#   (e) SPITBOL's own test deck is never excluded (spitbol_testpgms/*.spt, csnobol4_suite/diag1.sno, diag2.sno -- Lon 2026-09-26:
#       "Get ALL 8 working in SCRIP since they are SPITBOL programs.")
# and, over .github/SUITES.tsv:
#   (f) each package's row carries today_excluded, and it classifies EVERY shipped unit the denominator leaves out (Lon 2026-09-26,
#       "use the Excl column to properly classify the exclusions for good reasons only"; CEO-1288): no fewer than the package's
#       CONTAINERS.tsv include fragments (a container is never in a denominator, so an Excl below them hides one -- Jcon read 86/86
#       with an empty Excl over five), and no more than those plus the EXCLUDED.tsv rows. csnobol4_suite's fragments are outside its
#       graded-pair population and named in its row text, not Excl (CEO-1288), so its bound is EXCLUDED.tsv alone. Arm (f) also reads
#       every other language's package that ships a CONTAINERS.tsv (Icon's arizona_tests, jcon_tests and ipl).
# FAIL_ONCE=1 plants a dotnet row naming a shipped program the oracle RUNS (chap8_funcs.sno), so arm (c) trips.
# FAIL_ONCE=d plants an x64 DEFERRED-AFTER-ANNOUNCEMENT row whose evidence does not cite CEO-1345, so arm (a) trips.
# FAIL_ONCE=n plants a csnobol4_suite NO_ORACLE_ANSWER row for include.sno, which the oracle answers (eight lines), so arm (c) trips.
# FAIL_ONCE=f reads a copy of SUITES.tsv with jcon's today_excluded blanked and dotnet's at 99, so arm (f) trips on both bounds.
# rc 0 = every arm holds; rc 1 = a FAIL named; rc 2 = REFUSED-TO-GRADE (no packages tree, no SUITES.tsv).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
PK="${S4E_CORPUS_ROOT:-$ROOT/corpus}/packages/snobol4"; TSV="$(. "$HERE/lib_suites_tsv.sh"; suites_tsv "$ROOT")"
refuse(){ echo "⛔ REFUSED-TO-GRADE: $*"; exit 2; }
[ -d "$PK" ] || refuse "no packages tree at $PK"
[ -f "$TSV" ] || refuse "no SUITES.tsv at $TSV"
if [ "${FAIL_ONCE:-}" = f ]; then
  _t="$(mktemp)"; trap 'rm -f "$_t"' EXIT
  awk -F'\t' 'BEGIN{OFS="\t"} $1=="jcon"{$13=""} $1=="dotnet"{$13="99"} {print}' "$TSV" > "$_t"; TSV="$_t"
fi
cont_n(){ [ -f "$1/CONTAINERS.tsv" ] && grep -v '^#' "$1/CONTAINERS.tsv" | grep -c . || echo 0; }
arm_f(){ # arm_f <suites-key> <containers counted into Excl> <EXCLUDED.tsv rows>
  local key="$1" con="$2" n="$3" row hdr col te
  row="$(awk -F'\t' -v k="$key" '$1==k' "$TSV")"; hdr="$(grep -v '^#' "$TSV" | head -1)"
  col="$(printf '%s\n' "$hdr" | tr '\t' '\n' | grep -n '^today_excluded$' | cut -d: -f1)"
  if [ -z "$col" ]; then ck FAIL "(f) $key: SUITES.tsv has no today_excluded column"; return; fi
  [ -n "$row" ] || { ck FAIL "(f) $key: no SUITES.tsv row"; return; }
  te="$(printf '%s\n' "$row" | cut -f"$col")"
  case "$te" in ''|*[!0-9]*) ck FAIL "(f) $key: today_excluded reads [$te], not an integer (containers=$con EXCLUDED.tsv=$n)" ;;
    *) if [ "$te" -lt "$con" ]; then ck FAIL "(f) $key: today_excluded=$te is below the $con include fragment(s) of CONTAINERS.tsv -- an exclusion the row does not show"
       elif [ "$te" -gt $((con + n)) ]; then ck FAIL "(f) $key: today_excluded=$te exceeds the $con container(s) plus $n EXCLUDED.tsv row(s) that could classify it"
       else ck ok "(f) $key: today_excluded=$te, classified by $con container(s) and at most $n EXCLUDED.tsv row(s)"; fi ;; esac
}
fails=0; checks=0; ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
rows_of(){ grep -v '^#' "$1/EXCLUDED.tsv" | grep .; [ -n "${FAIL_ONCE:-}" ] && [ "${FAIL_ONCE}" != f ] && [ "${FAIL_ONCE}" != d ] && [ "${FAIL_ONCE}" != n ] && [ "$(basename "$1")" = dotnet ] && printf 'chap8_funcs.sno\tNOT_SPITBOL_DIALECT\tPLANTED by FAIL_ONCE: a program sbl -bf RUNS, so half one of the test fails; csnobol4 runs it too (CSNOBOL4)\n'; [ "${FAIL_ONCE:-}" = d ] && [ "$(basename "$1")" = spitbol_x64_tests ] && printf 'host.sbl\tDEFERRED-AFTER-ANNOUNCEMENT-LON-2026-09-27\tPLANTED by FAIL_ONCE=d: a deferral whose evidence cites no ruling at all, which arm (a) refuses\n'; [ "${FAIL_ONCE:-}" = n ] && [ "$(basename "$1")" = csnobol4_suite ] && printf 'include.sno\tNO_ORACLE_ANSWER\tPLANTED by FAIL_ONCE=n: a program sbl -bf answers with eight lines, which arm (c) measures and refuses (CEO-1696)\n'; return 0; }
SBL="${SBL_BIN:-/home/resources/x64/bin/sbl}"; NOA_T=""
no_answer(){ # no_answer <package dir> <name>: rc 0 when sbl -bf prints nothing on stdout or runs past 5 s, in a scratch copy of the package
  [ -x "$SBL" ] || return 1
  [ -n "$NOA_T" ] || { NOA_T="$(mktemp -d)"; trap 'rm -rf "$NOA_T" ${_t:+"$_t"}' EXIT; }
  [ -d "$NOA_T/$(basename "$1")" ] || cp -r "$1" "$NOA_T/" || return 1
  ( cd "$NOA_T/$(basename "$1")" && timeout -k 2 5 "$SBL" -bf "$2" < /dev/null > "$NOA_T/out" 2> /dev/null ); local rc=$?
  [ "$rc" = 124 ] || [ ! -s "$NOA_T/out" ]
}
echo "=== gate: EXCLUDED.tsv names only shipped programs SPITBOL rejects for a CSNOBOL4 feature, and the row carries the count (CEO-1286) ==="
for spec in aisnobol:aisnobol csnobol4_suite:csnobol4 dotnet:dotnet gimpel:gimpel snoflake_suite:snoflake spitbol_testpgms:testpgms spitbol_x64_tests:x64tests spitbol_x32_tests:x32tests; do
  p="${spec%%:*}"; key="${spec#*:}"; d="$PK/$p"
  if [ ! -f "$d/EXCLUDED.tsv" ]; then ck FAIL "$p: no EXCLUDED.tsv -- EXCLUDED=0 is written down, never absent"; continue; fi
  bad_shape=""; missing=""; container=""; not_outside=""; dup=""; deck=""; n=0; ndef=0; nnoa=0
  while IFS=$'\t' read -r name cls ev; do
    [ -n "$name" ] || continue; n=$((n+1))
    if [ "$cls" = DEFERRED-AFTER-ANNOUNCEMENT-LON-2026-09-27 ]; then
      { [ "${#ev}" -ge 60 ] && printf '%s' "$ev" | grep -q 'CEO-1345'; } || bad_shape="$bad_shape $name"; ndef=$((ndef+1))
    elif [ "$cls" = NO_ORACLE_ANSWER ]; then
      { [ "${#ev}" -ge 60 ] && printf '%s' "$ev" | grep -q 'CEO-1696'; } || bad_shape="$bad_shape $name"; nnoa=$((nnoa+1))
    else
      { [ "$cls" = NOT_SPITBOL_DIALECT ] && [ "${#ev}" -ge 60 ] && printf '%s' "$ev" | grep -q 'CSNOBOL4' && printf '%s' "$ev" | grep -q 'sbl -bf'; } || bad_shape="$bad_shape $name"
    fi
    [ -f "$d/$name" ] || missing="$missing $name"
    [ -f "$d/CONTAINERS.tsv" ] && awk -F'\t' -v n="$name" '$1==n{f=1} END{exit f?0:1}' "$d/CONTAINERS.tsv" && container="$container $name"
    stem="${name%.*}"
    if [ "$cls" = DEFERRED-AFTER-ANNOUNCEMENT-LON-2026-09-27 ]; then :
    elif [ "$cls" = NO_ORACLE_ANSWER ]; then no_answer "$d" "$name" || not_outside="$not_outside $name(the oracle answers it)"
    elif [ -f "$d/OUTSIDE_SPITBOL_BASELINE.tsv" ]; then
      awk -F'\t' -v a="$name" -v b="${stem}_driver.${name##*.}" -v c="${stem}_driver.sno" '$0 !~ /^#/ && ($1==a || $1==b || $1==c){f=1} END{exit f?0:1}' "$d/OUTSIDE_SPITBOL_BASELINE.tsv" || not_outside="$not_outside $name"
    else not_outside="$not_outside $name(no OUTSIDE_SPITBOL_BASELINE.tsv)"; fi
    case "$p/$name" in spitbol_testpgms/*|csnobol4_suite/diag1.sno|csnobol4_suite/diag2.sno) deck="$deck $name" ;; esac
  done < <(rows_of "$d")
  dup="$(rows_of "$d" | cut -f1 | sort | uniq -d | tr '\n' ' ')"
  [ -z "$bad_shape" ] && ck ok "(a) $p: $n row(s), each NOT_SPITBOL_DIALECT with evidence naming CSNOBOL4 and sbl -bf, or one of $ndef DEFERRED-AFTER-ANNOUNCEMENT citing CEO-1345 or $nnoa NO_ORACLE_ANSWER citing CEO-1696" || ck FAIL "(a) $p: malformed row(s):$bad_shape"
  [ -z "$missing$container" ] && ck ok "(b) $p: every name ships and none is a container" || ck FAIL "(b) $p: not shipped:$missing container:$container"
  [ -z "$not_outside" ] && ck ok "(c) $p: every NOT_SPITBOL_DIALECT program is in OUTSIDE_SPITBOL_BASELINE.tsv (rejected by SPITBOL, half one) and every NO_ORACLE_ANSWER program gets no answer from sbl -bf" || ck FAIL "(c) $p: the oracle does not refuse these, so they cannot be excluded:$not_outside"
  [ -z "$dup" ] && ck ok "(d) $p: no name twice" || ck FAIL "(d) $p: named twice: $dup"
  [ -z "$deck" ] && ck ok "(e) $p: SPITBOL's own test deck is not excluded" || ck FAIL "(e) $p: SPITBOL's own programs excluded:$deck"
  if [ "$p" = csnobol4_suite ]; then arm_f "$key" 0 "$n"; else arm_f "$key" "$(cont_n "$d")" "$n"; fi
done
for spec in icon/arizona_tests:arizona icon/jcon_tests:jcon icon/ipl:ipl; do
  d="${S4E_CORPUS_ROOT:-$ROOT/corpus}/packages/${spec%%:*}"
  [ -f "$d/CONTAINERS.tsv" ] || { ck FAIL "(f) ${spec%%:*}: no CONTAINERS.tsv -- this arm reads the packages that ship one"; continue; }
  n=0; [ -f "$d/EXCLUDED.tsv" ] && n="$(grep -v '^#' "$d/EXCLUDED.tsv" | grep -c .)"
  arm_f "${spec#*:}" "$(cont_n "$d")" "$n"
done
echo "checks=$checks fails=$fails"
[ "$fails" -eq 0 ]
