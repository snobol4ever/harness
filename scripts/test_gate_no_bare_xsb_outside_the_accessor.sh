#!/usr/bin/env bash
# test_gate_no_bare_xsb_outside_the_accessor.sh -- THE XSB ORACLE IS NAMED ONE WAY (ceo CEO-1927, 2026-10-23).
#
# Lon 2026-10-23 11:3x CDT, in-chat to the cfo, verbatim: "Since SWIPL does not have all XSB, we should begin to use XSB system as the third oracle."
# RULES.md § Oracles, FACT RULE XSB IS THE THIRD PROLOG ORACLE, FOR THE XSB PACKAGE: XSB 5.0.0 is reached only through xsb_bin() in lib_oracle_flags.sh,
# never a bare path. A hand-assembled /home/resources/prologs/xsb/XSB/bin/xsb, a `command -v xsb` / `which xsb`, or a bare `xsb -e` anywhere else under
# ../harness/scripts/ is an XSB that nothing checks is present -- the silent-absence false-number class of ORACLES.md. 0 sites at the accessor's landing.
#
# WHAT IS A SITE: `prologs/xsb/XSB/bin/xsb`, `command -v xsb`, `which xsb`, or `xsb -e` / `xsb --` not preceded by a word character, `/`, `$`, `"`, `'`
# or `-` (so `"$(xsb_bin)" -e` and `$XSB_ORACLE_BIN -e` are not sites). NOT a site: a comment line; an echo/printf/refuse line (prose naming the engine);
# lib_oracle_flags.sh itself; this gate. The exemptions are by SHAPE, never by file name beyond those two.
#
# FAIL-ONCE: GATE_FIXTURE_LINE='xsb -e "[f]."' adds one synthetic site and the gate must read 1 and exit 1.
set -u
GATE_NAME=test_gate_no_bare_xsb_outside_the_accessor
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$HERE/lib_oracle_flags.sh" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no lib_oracle_flags.sh beside this gate -- nothing to hold the sites to"; exit 2; }
grep -q '^xsb_bin()' "$HERE/lib_oracle_flags.sh" || { echo "⛔ REFUSED(2) [$GATE_NAME]: lib_oracle_flags.sh defines no xsb_bin -- the accessor the sites must use is missing"; exit 2; }
RX='prologs/xsb/XSB/bin/xsb|command -v xsb\b|which xsb\b|(^|[^[:alnum:]_/$"'"'"'-])xsb (-e|--)'
list="$(grep -rnE --include='*.sh' --include='*.py' "$RX" "$HERE" 2>/dev/null | grep -v '/fixtures/' | grep -vE "^[^:]*/(lib_oracle_flags\.sh|$GATE_NAME\.sh):" \
  | awk -v here="$HERE/" '{ line=$0; sub(/^[^:]*:[0-9]+:/, "", line); if (line ~ /^[[:space:]]*(#|echo |printf |refuse )/) next; sub("^" here, "  "); print }')"
n=$(printf '%s' "$list" | grep -c .)
if [ -n "${GATE_FIXTURE_LINE:-}" ]; then
  printf '%s' "$GATE_FIXTURE_LINE" | grep -qE "$RX" && { n=$((n+1)); list="$list"$'\n'"  (fixture) $GATE_FIXTURE_LINE"; }
fi
pop=$(find "$HERE" \( -name '*.sh' -o -name '*.py' \) -not -path '*/fixtures/*' | wc -l)
echo "bare xsb sites under ../harness/scripts/ (population: $pop scripts; the oracle is xsb_bin): $n"
if [ "$n" -ne 0 ]; then
  printf '%s\n' "$list"
  echo "⛔ GATE FAIL [$GATE_NAME]: $n site(s) name the XSB oracle outside xsb_bin -- reach it through lib_oracle_flags.sh (RULES.md § Oracles, CEO-1927)"
  exit 1
fi
echo "✅ GATE PASS [$GATE_NAME]: every XSB invocation under ../harness/scripts/ goes through xsb_bin"
exit 0
