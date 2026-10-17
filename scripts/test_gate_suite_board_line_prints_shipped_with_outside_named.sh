#!/usr/bin/env bash
# test_gate_suite_board_line_prints_shipped_with_outside_named.sh -- THE HARNESS BOARD LINE PRINTS PASS OVER THE SHIPPED
# POPULATION WITH OUTSIDE NAMED, AND THE OUTSIDE ENTRIES REACH THE PROGRESS DB (coo 2026-09-16; ceo CEO-772, CEO-749; Lon
# 2026-09-16 "Get those fixed" -- OUTSIDE is debt; row snobol4-master-runner-publishes-over-the-graded-population-1972-not-
# the-shipped-1980-with-outside-named).
#
# THE DEFECT: corpus_suite_harness.py dropped every --outside entry from its SUITE_BOARD total= (1972 for a 1980-entry
# rungs) and recorded nothing for them, so test_corpus_snobol4.sh published 1961/1972 and the SUITES.tsv row had to be
# hand-set to 1961/1980 OUTSIDE=8 (COO-82); on one of the harness's two paths total= still carried the outside
# entries while the mode counts did not -- one word, two arithmetics. Every board write dropped OUTSIDE (hq_snobol4).
#
# THE CURE UNDER TEST: the SUITE_BOARD prints total= (graded) shipped= (graded + outside) outside= (the entries THIS run
# removed, so a sharded sum reads once), OUTSIDE_BASELINE lines name each with the oracle's class and reason, and each is
# appended to the progress DB as OUTSIDE in every requested mode; test_corpus_snobol4.sh quotes all_pass/shipped OUTSIDE=N
# and refuses when the fields are absent.
#
# ARMS (hermetic: a three-entry suite cut from the live rungs under mktemp in a tests/snobol4/ALL.sno layout, the progress
# DB redirected by S4E_PROGRESS_DB to a scratch table -- the live table is never touched; a fixture outside the corpus is not
# a board and the one-runner guard does not apply, CEO-547):
#   (a) with one entry declared outside: SUITE_BOARD total=2 shipped=3 outside=1, all_n=2, m3_n=2 m4_n=2
#   (b) the OUTSIDE_BASELINE line names the entry with its class and reason, and the count line says IN the shipped one
#   (c) the scratch DB carries one OUTSIDE row per requested mode for the entry, note = class: reason
#   (d) ⛔ AMENDED 2026-09-17 (coo): the same suite with NO --outside now rides the SIBLING list and still prints
#       total=2 shipped=3 outside=1, with OUTSIDE_BASELINE_LIST saying DERIVED. This arm used to assert the OPPOSITE
#       (total=3 shipped=3 outside=0), and that assertion was the defect written down: two boards on the same corpus
#       a6bcd8097 76 minutes apart disagreed on seven snobol4-rungs entries -- cfo 22:55:52Z PASS, cto 00:11:39Z
#       OUTSIDE -- because a direct `corpus_suite_harness.py run` omitted the flag and graded the eight entries the
#       ONE ORACLE REFUSES against their stored .ref. A declared fact beside the data may not depend on the caller
#       remembering a flag; the escape is loud, not silent, which is arm (f).
#   (e) STATIC: test_corpus_snobol4.sh writes --suite-total "$_sn4_shipped" and refuses when shipped=/outside= are absent
#       and test_icon_arizona_suite.sh / test_icon_jcon_suite.sh write --suite-total "$SHIPPED", never a graded subset (ceo CEO-1245,
#       CEO-1268: Zona 88/124 and Jcon 82/91, the ungraded staying in the denominator as debt)
#   (f) --outside-none is the LOUD escape: total=3 shipped=3 outside=0 AND the printed line names the list it skipped
#       and says the count is not comparable to a baseline board; --outside with --outside-none together REFUSE rc=2
# FAIL_ONCE=1 rewrites the captured board line's shipped=3 to shipped=2 before arm (a) grades, to prove the arm trips.
# rc 0 = every arm holds; rc 1 = a FAIL named; rc 2 = REFUSED-TO-GRADE (no binary, no rungs to cut the fixture from).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
H="$HERE/corpus_suite_harness.py"; RUNGS="${S4E_CORPUS_ROOT:-$HERE/../../corpus}/tests/snobol4"
refuse(){ echo "⛔ REFUSED-TO-GRADE: $*"; exit 2; }
[ -f "$H" ] || refuse "no harness at $H"
[ -x "$HERE/../../SCRIP/scrip" ] || refuse "no ./scrip binary beside ../harness/scripts/ -- make first"
[ -f "$RUNGS/ALL.sno" ] && [ -f "$RUNGS/ALL.ref" ] || refuse "no rungs pair under $RUNGS to cut a fixture from"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_shipped_outside.XXXXXX")" || refuse "mktemp failed"
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/tests/snobol4"; head -3 "$RUNGS/ALL.sno" > "$W/tests/snobol4/ALL.sno"; head -3 "$RUNGS/ALL.ref" > "$W/tests/snobol4/ALL.ref"
[ "$(wc -l < "$W/tests/snobol4/ALL.sno")" = 3 ] || refuse "the rungs' first three lines did not cut cleanly"
NAME="$(sed -n 2p "$W/tests/snobol4/ALL.sno" | sed 's/.*;\* //')"; [ -n "$NAME" ] || refuse "cannot read the second entry's name from its ';* name' tail"
printf '%s\tORACLE_REFUSES\tfixture: the oracle refuses this entry\n' "$NAME" > "$W/tests/snobol4/ALL.outside.tsv"
DB="$W/results.tsv"; printf 'ts_utc\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome\tsecs\tnote\n' > "$DB"
echo "    fixture: 3 entries cut from the rungs; outside = $NAME"
fails=0; checks=0; ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
echo "=== gate: the board line prints PASS over the shipped population with OUTSIDE named (CEO-749) ==="
out="$(S4E_PROGRESS_DB="$DB" timeout -k 5 120 python3 "$H" run "$W/tests/snobol4/ALL.sno" "$W/tests/snobol4/ALL.ref" --modes m3,m4 --outside "$W/tests/snobol4/ALL.outside.tsv" 2>&1)"; rc=$?
[ "$rc" -le 1 ] || refuse "the harness could not grade the fixture (rc=$rc): $(tail -3 <<<"$out")"
board="$(grep '^SUITE_BOARD ' <<<"$out")"
[ -n "${FAIL_ONCE:-}" ] && board="${board/shipped=3/shipped=2}"
f(){ grep -oE " $1=[0-9]+" <<<"$board" | head -1 | cut -d= -f2; }
if [ "$(f total)" = 2 ] && [ "$(f shipped)" = 3 ] && [ "$(f outside)" = 1 ] && [ "$(f all_n)" = 2 ] && [ "$(f m3_n)" = 2 ] && [ "$(f m4_n)" = 2 ]; then
  ck ok "(a) SUITE_BOARD total=2 (graded) shipped=3 outside=1, all_n=2, m3_n=2 m4_n=2"
else ck no "(a) board fields -- total=$(f total) shipped=$(f shipped) outside=$(f outside) all_n=$(f all_n) m3_n=$(f m3_n) m4_n=$(f m4_n): $board"; fi
grep -q "^OUTSIDE_BASELINE $NAME ORACLE_REFUSES: fixture: the oracle refuses this entry" <<<"$out" && grep -q 'OUTSIDE_BASELINE_COUNT 1 .*IN the shipped one' <<<"$out" \
  && ck ok "(b) OUTSIDE_BASELINE names $NAME with its class and reason; the count line says IN the shipped population" \
  || ck no "(b) OUTSIDE lines -- got: $(grep OUTSIDE <<<"$out" | head -2)"
n_out="$(awk -F'\t' -v p="$NAME" '$8==p && $10=="OUTSIDE"{print $9":"$12}' "$DB" | sort | tr '\n' ' ')"
[ "$n_out" = "m3:ORACLE_REFUSES: fixture: the oracle refuses this entry m4:ORACLE_REFUSES: fixture: the oracle refuses this entry " ] \
  && ck ok "(c) the progress DB carries $NAME as OUTSIDE in m3 and m4 with note = class: reason" \
  || ck no "(c) DB OUTSIDE rows for $NAME: '$n_out'"
out2="$(S4E_PROGRESS_DB="$DB" timeout -k 5 120 python3 "$H" run "$W/tests/snobol4/ALL.sno" "$W/tests/snobol4/ALL.ref" --modes m3,m4 2>&1)"; board2="$(grep '^SUITE_BOARD ' <<<"$out2")"
g(){ grep -oE " $1=[0-9]+" <<<"$board2" | head -1 | cut -d= -f2; }
[ "$(g total)" = 2 ] && [ "$(g shipped)" = 3 ] && [ "$(g outside)" = 1 ] && grep -q 'OUTSIDE_BASELINE_LIST .*DERIVED from the suite directory' <<<"$out2" \
  && ck ok "(d) WITHOUT --outside the sibling list RIDES: total=2 shipped=3 outside=1, and the provenance line says DERIVED" \
  || ck no "(d) derived board: total=$(g total) shipped=$(g shipped) outside=$(g outside); list line: $(grep '^OUTSIDE_BASELINE_LIST' <<<"$out2" | head -1)"
R="$HERE/test_corpus_snobol4.sh"
grep -q -- '--suite-total "\$_sn4_shipped"' "$R" && grep -q 'shipped=/outside= fields' "$R" && ck ok "(e) STATIC: test_corpus_snobol4.sh publishes --suite-total \$_sn4_shipped and refuses when shipped=/outside= are absent" || ck no "(e) test_corpus_snobol4.sh does not publish the shipped population or does not refuse on absent fields"
for R in "$HERE/test_icon_arizona_suite.sh" "$HERE/test_icon_jcon_suite.sh"; do
  grep -q -- '--suite-total "\$SHIPPED"' "$R" && ! grep -qE -- '--suite-total "\$(TOTAL|total|GRADED)"' "$R" \
    && ck ok "(e) STATIC: ${R##*/} publishes --suite-total \$SHIPPED, the shipped population (ceo CEO-1245, CEO-1268)" \
    || ck no "(e) ${R##*/} publishes a graded subset as its suite total, not \$SHIPPED (ceo CEO-1245: the shipped population is the denominator)"
done
out3="$(S4E_PROGRESS_DB="$DB" timeout -k 5 120 python3 "$H" run "$W/tests/snobol4/ALL.sno" "$W/tests/snobol4/ALL.ref" --modes m3,m4 --outside-none 2>&1)"; board3="$(grep '^SUITE_BOARD ' <<<"$out3")"
h(){ grep -oE " $1=[0-9]+" <<<"$board3" | head -1 | cut -d= -f2; }
S4E_PROGRESS_DB="$DB" timeout -k 5 120 python3 "$H" run "$W/tests/snobol4/ALL.sno" "$W/tests/snobol4/ALL.ref" --outside "$W/tests/snobol4/ALL.outside.tsv" --outside-none >/dev/null 2>&1; rc_both=$?
[ "$(h total)" = 3 ] && [ "$(h shipped)" = 3 ] && [ "$(h outside)" = 0 ] \
  && grep -q "OUTSIDE_BASELINE_LIST NONE --outside-none was given and .*ALL.outside.tsv EXISTS" <<<"$out3" \
  && grep -q 'NOT comparable to a board graded against the baseline' <<<"$out3" && [ "$rc_both" = 2 ] \
  && ck ok "(f) --outside-none grades the shipped set (total=3 outside=0), names the list it skipped and says the count is not comparable; --outside with it refuses rc=2" \
  || ck no "(f) --outside-none: total=$(h total) shipped=$(h shipped) outside=$(h outside), rc(both flags)=$rc_both, line: $(grep '^OUTSIDE_BASELINE_LIST' <<<"$out3" | head -1)"
echo "population: $checks arm(s) graded, $fails FAIL"
[ "$fails" = 0 ] && { echo "GATE PASS [suite_board_line_prints_shipped_with_outside_named]: $checks of $checks arms hold"; exit 0; }
echo "⛔ GATE RED [suite_board_line_prints_shipped_with_outside_named]: $fails of $checks arms FAIL"; exit 1
