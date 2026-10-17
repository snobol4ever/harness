#!/usr/bin/env bash
# test_gate_no_bare_gprolog_or_gplc_outside_the_accessors.sh -- THE GNU PROLOG ORACLE IS NAMED ONE WAY (ceo CEO-1598, 2026-10-10).
#
# Lon 2026-10-10 10:2x CDT, in-chat to the ceo, verbatim: "Get the new oracle 1.6.0 and begin using it instead of the older one."
# The oracle moved from /usr/bin/gprolog (1.4.5, Lon's apt install, left in place) to the pristine 1.6.0 build under
# /home/resources/gprolog-mon/pristine (ORACLES.md, ORACLE SWAP 2026-10-10). The ONE way a script names it is gprolog_bin / gplc_bin in
# lib_oracle_flags.sh. A bare `gprolog`, `gplc`, `command -v gprolog`, `command -v gplc` or `/usr/bin/gprolog` anywhere else under ../harness/scripts/
# is the retired binary grading something, silently -- the false-FAIL/false-PASS class of CLAUDE.md § Oracles. 38 such sites in 13 scripts
# were re-cut at the swap landing; this gate keeps the count at 0.
#
# WHAT IS A SITE: an invocation shape -- `gprolog --consult-file|--init-goal|--entry-goal|--query-goal|--version`, `gplc --no-top-level`,
# `gplc -o`, `gplc <file>.pl`, `command -v gprolog`, `command -v gplc`, `/usr/bin/gprolog`, `/usr/bin/gplc` -- not preceded by a word
# character, `/`, `$`, `"`, `'` or `-` (so `"$(gprolog_bin)" --consult-file` and `$GPROLOG_MON/bin/gplc` are not sites). NOT a site: a
# comment line; an echo/printf/refuse line (prose naming the engine); a line naming GPROLOG_MON (the instrumented fork, never a grader);
# lib_oracle_flags.sh itself; ../harness/scripts/monitor/oracles/ (the fork's build). The exemptions are by SHAPE, never by file name beyond those two.
#
# FAIL-ONCE: GATE_FIXTURE_LINE='gplc -o x x.pl' adds one synthetic site and the gate must read 1 and exit 1.
set -u
GATE_NAME=test_gate_no_bare_gprolog_or_gplc_outside_the_accessors
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$HERE/lib_oracle_flags.sh" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no lib_oracle_flags.sh beside this gate -- nothing to hold the sites to"; exit 2; }
grep -q '^gplc_bin()' "$HERE/lib_oracle_flags.sh" || { echo "⛔ REFUSED(2) [$GATE_NAME]: lib_oracle_flags.sh defines no gplc_bin -- the accessor the sites must use is missing"; exit 2; }
RX='command -v g(prolog|plc)\b|/usr/bin/g(prolog|plc)\b|(^|[^[:alnum:]_/$"'"'"'-])gprolog --(consult-file|init-goal|entry-goal|query-goal|version)|(^|[^[:alnum:]_/$"'"'"'-])gplc (--no-top-level|-o |[[:alnum:]_./$"]+\.pl)'
list="$(grep -rnE --include='*.sh' --include='*.py' "$RX" "$HERE" 2>/dev/null | grep -v '/fixtures/' | grep -vE '^[^:]*/(lib_oracle_flags\.sh|monitor/oracles/[^:]*):' \
  | awk -v here="$HERE/" '{ line=$0; sub(/^[^:]*:[0-9]+:/, "", line); if (line ~ /GPROLOG_MON/ || line ~ /^[[:space:]]*(#|echo |printf |refuse )/ || line ~ /rival must be/) next; sub("^" here, "  "); print }')"
n=$(printf '%s' "$list" | grep -c .)
if [ -n "${GATE_FIXTURE_LINE:-}" ]; then
  printf '%s' "$GATE_FIXTURE_LINE" | grep -qE "$RX" && { n=$((n+1)); list="$list"$'\n'"  (fixture) $GATE_FIXTURE_LINE"; }
fi
pop=$(find "$HERE" \( -name '*.sh' -o -name '*.py' \) -not -path '*/fixtures/*' | wc -l)
echo "bare gprolog/gplc sites under ../harness/scripts/ (population: $pop scripts; the oracle is gprolog_bin/gplc_bin): $n"
if [ "$n" -ne 0 ]; then
  printf '%s\n' "$list"
  echo "⛔ GATE FAIL [$GATE_NAME]: $n site(s) name the GNU Prolog oracle outside gprolog_bin/gplc_bin -- a bare name on PATH is the retired 1.4.5 (ORACLES.md, ORACLE SWAP 2026-10-10)"
  exit 1
fi
echo "✅ GATE PASS [$GATE_NAME]: every GNU Prolog invocation under ../harness/scripts/ goes through gprolog_bin/gplc_bin"
exit 0
