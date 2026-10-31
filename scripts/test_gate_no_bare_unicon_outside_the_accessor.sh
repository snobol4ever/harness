#!/usr/bin/env bash
# test_gate_no_bare_unicon_outside_the_accessor.sh -- THE UNICON ORACLE IS NAMED ONE WAY AND IS NEVER A NORMALIZER (ceo CEO-2072, 2026-10-31).
#
# Lon 2026-10-31, in-chat to the ceo, verbatim: "Let's extend Icon to Unicon with a command-line switch, or if it is a super set then a switch is not needed."  The Unicon translator is reached
# only through unicon_bin() in lib_oracle_flags.sh, never a bare path (the silent-absence false-number class of ORACLES.md), and it is NEVER run with -E: the 2026-09-11 ruling (Lon: "We do not want
# you ... using it to add semi-colons on the fly versus adding the files to the corpus repo", CEO-570) is superseded only for the superset itself, and its second reason stands -- a source rewritten at
# grade time is not the artifact in the repo (CEO-567).
#
# ARM 1  no script under ../harness/scripts/ names the oracle any way but unicon_bin: a SITE is `/unicon/bin/`, `command -v unicon`, `which unicon`, or a bare `unicon -x` / `unicon f.icn` not preceded by a
#        word character, `/`, `$`, `"`, `'` or `-`.  NOT a site: a comment line; an echo/printf/refuse line; lib_oracle_flags.sh itself; this gate.
# ARM 2  no non-comment line passes -E to the oracle (`unicon_bin ... -E`, `$UNICON_ORACLE_BIN ... -E`): 0 sites.
# ARM 3  the accessor behaves: it prints an executable path when the oracle is built, and REFUSES (rc 1, the loud message on stderr, nothing on stdout) when the binary is absent.
# FAIL-ONCE: GATE_FIXTURE_LINE='unicon -E x.icn' (or '"$(unicon_bin)" -E x.icn') adds one synthetic site and the gate must read it and exit 1.
# rc 0 all arms hold - rc 1 an arm is red - rc 2 REFUSAL (no accessor to hold the sites to).
set -u
GATE_NAME=test_gate_no_bare_unicon_outside_the_accessor
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$HERE/lib_oracle_flags.sh" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no lib_oracle_flags.sh beside this gate -- nothing to hold the sites to"; exit 2; }
grep -q '^unicon_bin()' "$HERE/lib_oracle_flags.sh" || { echo "⛔ REFUSED(2) [$GATE_NAME]: lib_oracle_flags.sh defines no unicon_bin -- the accessor the sites must use is missing"; exit 2; }
RX1='/unicon/bin/|command -v unicon\b|which unicon\b|(^|[^[:alnum:]_/$"'"'"'-])unicon (-[A-Za-z]+|[A-Za-z0-9_./-]+\.icn)'
RX2='(unicon_bin[)"]*|UNICON_ORACLE_BIN"?)[^#|;&]* -E([[:space:]]|$)'
sites() { grep -rnE --include='*.sh' --include='*.py' "$1" "$HERE" 2>/dev/null | grep -v '/fixtures/' | grep -vE "^[^:]*/(lib_oracle_flags\.sh|$GATE_NAME\.sh):" \
  | awk -v here="$HERE/" '{ line=$0; sub(/^[^:]*:[0-9]+:/, "", line); if (line ~ /^[[:space:]]*(#|echo |printf |refuse )/) next; sub("^" here, "  "); print }'; }
l1="$(sites "$RX1")"; l2="$(sites "$RX2")"
n1=$(printf '%s' "$l1" | grep -c .); n2=$(printf '%s' "$l2" | grep -c .)
if [ -n "${GATE_FIXTURE_LINE:-}" ]; then
  printf '%s' "$GATE_FIXTURE_LINE" | grep -qE "$RX1" && { n1=$((n1+1)); l1="$l1"$'\n'"  (fixture) $GATE_FIXTURE_LINE"; }
  printf '%s' "$GATE_FIXTURE_LINE" | grep -qE "$RX2" && { n2=$((n2+1)); l2="$l2"$'\n'"  (fixture) $GATE_FIXTURE_LINE"; }
fi
pop=$(find "$HERE" \( -name '*.sh' -o -name '*.py' \) -not -path '*/fixtures/*' | wc -l)
red=0
echo "ARM 1 bare unicon sites under ../harness/scripts/ (population: $pop scripts; the oracle is unicon_bin): $n1"
[ "$n1" -ne 0 ] && { printf '%s\n' "$l1"; red=1; }
echo "ARM 2 sites passing -E to the oracle (the normalizer): $n2"
[ "$n2" -ne 0 ] && { printf '%s\n' "$l2"; red=1; }
got="$( . "$HERE/lib_oracle_flags.sh"; unicon_bin 2>/dev/null )"; grc=$?
if [ -n "$got" ] && [ -x "$got" ]; then echo "ARM 3 unicon_bin prints an executable path: $got"
else echo "ARM 3 RED: unicon_bin printed no executable path (rc $grc) -- run build_unicon_oracle.sh"; red=1; fi
out="$( . "$HERE/lib_oracle_flags.sh"; UNICON_ORACLE_BIN=/nonexistent/unicon_zz; unicon_bin 2>"$(mktemp)" )"; mrc=$?
err="$( . "$HERE/lib_oracle_flags.sh"; UNICON_ORACLE_BIN=/nonexistent/unicon_zz; unicon_bin 2>&1 >/dev/null )"
if [ -z "$out" ] && [ "$mrc" -ne 0 ] && printf '%s' "$err" | grep -q 'UNICON ORACLE IS MISSING'; then echo "ARM 3 unicon_bin refuses loudly when the binary is absent (rc $mrc, nothing on stdout)"
else echo "ARM 3 RED: unicon_bin did not refuse loudly for an absent binary (rc $mrc, stdout '$out')"; red=1; fi
if [ "$red" -ne 0 ]; then echo "⛔ GATE FAIL [$GATE_NAME] (RULES.md § Oracles, CEO-2072)"; exit 1; fi
echo "✅ GATE PASS [$GATE_NAME]: every Unicon invocation under ../harness/scripts/ goes through unicon_bin, none passes -E, and the accessor refuses loudly when absent"
exit 0
