#!/usr/bin/env bash
# test_gate_oracle_env_sidecar_is_declared_and_reaches_the_oracle.sh -- THE ORACLE'S SIZE IS DECLARED BESIDE THE UNIT AND THE RUNNER PASSES IT
# (ceo CEO-1353, RULES.md clause 8 (g)(3); the coo's approval 2026-09-28 17:1x: "a runner that drops the env reds, and an unadmitted knob
# refuses rc 2"). A unit whose oracle needs more than its own default declares the knob in <stem>.oracle_env, one line
# NAME<TAB>VAR=VALUE[ VAR=VALUE], read by lib_declared_arena.sh's declared_oracle_env_beside through
# corpus_suite_harness.oracle_env_declarations -- the one reader.
#   R1-R5  the reader: a declared line echoes its words; an unadmitted knob, another unit's name, a non-integer value and an empty line
#          each REFUSE rc 2; no sidecar echoes nothing, rc 0.
#   B      the declaration is the oracle's NEED, read behaviourally: a 200000-deep Icon recursion dies under iconx at its default
#          (run-time error 301) and runs to its answer in the environment the reader echoes for its sidecar (MSTKSIZE).
#   W      the self-host gate passes jtran's declaration to its oracle: it calls the reader and hands "${OENV[@]}" to the oracle's env,
#          and a doctored copy that drops the env reads RED here (fail once).
# EXIT: 0 every arm holds; 1 an arm is red; 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G=test_gate_oracle_env_sidecar_is_declared_and_reaches_the_oracle
. "$HERE/lib_declared_arena.sh" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: lib_declared_arena.sh unloadable"; exit 2; }
declare -F declared_oracle_env_beside >/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: lib_declared_arena.sh no longer defines declared_oracle_env_beside"; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: lib_oracle_flags.sh unloadable"; exit 2; }
ICONT="$(icont_bin)"; ICONX="$(iconx_bin)"
[ -x "$ICONT" ] && [ -x "$ICONX" ] || { echo "⛔ GATE REFUSE(2) [$G]: the Icon oracle (icont, iconx) is absent"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_oenv.XXXXXX")" || { echo "⛔ GATE REFUSE(2) [$G]: mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
RED=0
ok() { echo "  ok   $*"; }
bad() { echo "  FAIL $*"; RED=1; }
rd() { local o rc; o="$(declared_oracle_env_beside "$1" 2>/dev/null)"; rc=$?; printf '%s|%s' "$rc" "$o"; }
: > "$W/u.icn"
printf 'u\tCOEXPSIZE=1000000 MSTKSIZE=500000\n' > "$W/u.oracle_env"
[ "$(rd "$W/u.icn")" = "0|COEXPSIZE=1000000 MSTKSIZE=500000" ] && ok "R1 a declared line echoes its words" || bad "R1 the reader echoed '$(rd "$W/u.icn")'"
printf 'u\tHEAPSIZE=5000000\n' > "$W/u.oracle_env"
[ "$(rd "$W/u.icn")" = "2|" ] && ok "R2 a knob outside the admitted list REFUSES rc 2" || bad "R2 an unadmitted knob read '$(rd "$W/u.icn")'"
printf 'v\tCOEXPSIZE=1000000\n' > "$W/u.oracle_env"
[ "$(rd "$W/u.icn")" = "2|" ] && ok "R3 another unit's name REFUSES rc 2" || bad "R3 another unit's line read '$(rd "$W/u.icn")'"
printf 'u\tCOEXPSIZE=big\n' > "$W/u.oracle_env"
[ "$(rd "$W/u.icn")" = "2|" ] && ok "R4 a non-integer value REFUSES rc 2" || bad "R4 a non-integer value read '$(rd "$W/u.icn")'"
printf 'u\t\n' > "$W/u.oracle_env"
[ "$(rd "$W/u.icn")" = "2|" ] && ok "R5a an empty declaration REFUSES rc 2" || bad "R5a an empty declaration read '$(rd "$W/u.icn")'"
rm -f "$W/u.oracle_env"
[ "$(rd "$W/u.icn")" = "0|" ] && ok "R5b no sidecar echoes nothing, rc 0" || bad "R5b no sidecar read '$(rd "$W/u.icn")'"
printf 'procedure main();\n   write(d(200000));\nend\nprocedure d(n);\n   if n = 0 then return 0;\n   return 1 + d(n - 1);\nend\n' > "$W/deep.icn"
printf 'deep\tMSTKSIZE=10000000\n' > "$W/deep.oracle_env"
( cd "$W" && "$ICONT" -s -o deep.x deep.icn ) >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: icont refused the recursion fixture"; exit 2; }
OE="$(declared_oracle_env_beside "$W/deep.icn")" || { echo "⛔ GATE REFUSE(2) [$G]: the reader refused a well-formed fixture"; exit 2; }
read -r -a OENV <<<"$OE"
d0="$( cd "$W" && env -u MSTKSIZE timeout -k 5 60 ./deep.x 2>&1 )"; r0=$?
d1="$( cd "$W" && env -u MSTKSIZE "${OENV[@]}" timeout -k 5 60 ./deep.x 2>&1 )"; r1=$?
if [ "$r0" -eq 124 ] || [ "$r1" -eq 124 ]; then echo "⛔ GATE REFUSE(2) [$G]: the recursion fixture timed out (default rc=$r0, declared rc=$r1)"; exit 2; fi
if [ "$r0" -ne 0 ] && grep -q 'error 301' <<<"$d0" && [ "$r1" -eq 0 ] && [ "$d1" = 200000 ]; then
  ok "B  at iconx's default the recursion dies run-time error 301 (rc=$r0); under the declared ${OE} it prints 200000"
else bad "B  default rc=$r0 '$(head -c 80 <<<"$d0")', declared rc=$r1 '$(head -c 80 <<<"$d1")' -- the declaration is not the oracle's need"; fi
wired() { grep -q 'declared_oracle_env_beside "$D/jtran.icn"' "$1" && grep -q '"${OENV\[@\]}" timeout -k 5 "$TMO" "$W/jtran_oracle"' "$1"; }
SH="$HERE/test_demo_icon_jcon_selfhost.sh"
[ -f "$SH" ] || { echo "⛔ GATE REFUSE(2) [$G]: $SH absent"; exit 2; }
if wired "$SH"; then ok "W  the self-host gate reads jtran.oracle_env and hands it to the oracle's env"; else bad "W  the self-host gate no longer passes jtran's declared oracle environment"; fi
sed 's/"\${OENV\[@\]}" timeout "\$TMO" "\$W\/jtran_oracle"/timeout -k 5 "$TMO" "$W\/jtran_oracle"/' "$SH" > "$W/doctored.sh"
cmp -s "$SH" "$W/doctored.sh" && { echo "⛔ GATE REFUSE(2) [$G]: the doctoring edit did not apply"; exit 2; }
if wired "$W/doctored.sh"; then bad "W' a copy that drops the env still reads as wired"; else ok "W' a copy that drops the env reads RED (fail once)"; fi
if [ "$RED" = 0 ]; then echo "✅ GATE PASS [$G]: the oracle's declared environment is read by the one reader, refused when malformed, needed by the oracle, and passed by the self-host gate"; exit 0; fi
echo "⛔ GATE FAIL [$G]"; exit 1
