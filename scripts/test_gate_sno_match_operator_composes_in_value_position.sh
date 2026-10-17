#!/bin/bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ⭐ WITNESS GATE for row snobol4-the-match-operator-in-value-position-has-no-value-so-the-whole-statement-is-silently-dropped
# (hq_I found it walking the Snocone rung09 ladder as defect D2; ceo routed the cure to cfo as CEO-673; cfo 2026-09-13).
# A match with the binary match operator in VALUE position yields the matched substring and COMPOSES with the
# expression around it.  MEASURED on 854f31238, BOTH modes: it had NO VALUE in the general expression lowerer, so
# the ENTIRE enclosing statement was silently dropped -- OUTPUT = (S ? 'hel') 'X' printed nothing at rc=0 where
# sbl -bf prints helX, and dump-ir showed no ASSIGN box and no concatenation ever built.  The operator only ever
# appeared to work through a special case in case TT_ASSIGN that rewrites a right-hand side which is ENTIRELY a
# TT_SCAN into a capture into the assignment target.
# ⛔ GRADED ON THE OUTPUT, BYTE FOR BYTE, NEVER ON rc (ceo CEO-673 addendum, CEO-556 class): the broken shapes
# exit 0 with no output, so every rc-based predicate reads them as green and cannot tell a cure from a silencing.
# ⛔ ARMS 5-7 ARE CONTROLS: the two shapes that ALREADY WORKED through the special case, and a FAILED match, whose
# correct answer is that the statement fails and prints nothing -- a cure that makes a failed match yield the null
# string instead of failing would pass every other arm and break the language.
# ⛔ REFUSES rc=2 rather than grading when the oracle is absent or answers the same program two different ways.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="${S4E_HOME:-$(cd "$HERE/../../SCRIP" && pwd)}"; [ -x "$ROOT/scrip" ] || ROOT="$(cd "$HERE/../.." && pwd)/SCRIP"
cd "$ROOT" || exit 2
. ../harness/scripts/lib_oracle_flags.sh
O=$(sbl_correctness_bin) || { echo "⛔ REFUSE(2): no SPITBOL correctness oracle"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT; rc=0; ran=0
arm() { n="$1"; body="$2"; printf "\tS = 'hello'\n%b\nEND\n" "$body" > "$T/$n.sno"
  timeout -k 5 8s "$O" -bf "$T/$n.sno" </dev/null > "$T/$n.ref" 2>&1
  timeout -k 5 8s "$O" -bf "$T/$n.sno" </dev/null > "$T/$n.ref2" 2>&1
  cmp -s "$T/$n.ref" "$T/$n.ref2" || { echo "⛔ REFUSE(2): oracle answered arm $n two different ways"; exit 2; }
  ran=$((ran + 1))
  timeout -k 5 8s ./scrip "$T/$n.sno" </dev/null > "$T/$n.m3" 2>&1
  cmp -s "$T/$n.ref" "$T/$n.m3" || { echo "⛔ RED $n m3 (< oracle, > scrip):"; diff "$T/$n.ref" "$T/$n.m3" | head -4; rc=1; }
  if ./scrip --compile -o "$T/$n.s" "$T/$n.sno" </dev/null >/dev/null 2>&1 && as -o "$T/$n.o" "$T/$n.s" 2>/dev/null && gcc -o "$T/$n.bin" "$T/$n.o" out/libscrip_rt.so -Wl,-rpath,"$PWD/out" 2>/dev/null; then
    timeout -k 5 8s "$T/$n.bin" </dev/null > "$T/$n.m4" 2>&1
    cmp -s "$T/$n.ref" "$T/$n.m4" || { echo "⛔ RED $n m4 (< oracle, > scrip):"; diff "$T/$n.ref" "$T/$n.m4" | head -4; rc=1; }
  else echo "⛔ RED $n m4: compile/assemble/link failed -- a BUILD failure, not a run diff"; rc=1; fi; }
arm concat_right "\tOUTPUT = (S ? 'hel') 'X'"
arm concat_left "\tOUTPUT = 'X' (S ? 'hel')"
arm fnc_arg "\tOUTPUT = SIZE(S ? 'hel')"
arm concat_both "\tOUTPUT = 'A' (S ? 'hel') 'B'"
arm ctl_bare_var "\tR = (S ? 'hel')\n\tOUTPUT = 'r=[' R ']'"
arm ctl_bare_output "\tOUTPUT = (S ? 'hel')"
arm ctl_failed_match "\tOUTPUT = (S ? 'zzz') 'X'\n\tOUTPUT = 'statement above failed'"
[ "$ran" = 7 ] || { echo "⛔ REFUSE(2): measured $ran of 7 arms"; exit 2; }
[ "$rc" = 0 ] && echo "GATE OK: 7 arms x 2 modes byte-exact against sbl -bf -- the match operator composes in value position and the three controls are unmoved"
exit $rc
