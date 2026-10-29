#!/usr/bin/env bash
# test_gate_sno_parser_refuses_at_compile_time_what_spitbol_refuses.sh -- the first product of the grammar-based harness
# (Lon and the ceo, 2026-10-01, CEO-1393): gen_every_snobol4.icn enumerated every OUTPUT = <expression> statement of at
# most 3 tokens (10834) and each went through SCRIP's compile (scrip --compile: the parser and the lowerer, which owns every
# refusal that is a meaning check -- the constant fold and the name-required rule moved there from the parser at CEO-2016) and
# through sbl -bf; where the oracle refuses a statement AT COMPILE TIME and SCRIP's compile accepts it, SCRIP grades a compile
# refusal as a runtime answer.
# Three classes, one witness each, canonical shapes from the census (699 statements of the first two kinds, 20 of the
# third): a literal as the target of = . $ or under unary @ and & ('a' = X); literal-only arithmetic with a type clash,
# which SPITBOL folds and refuses at compile time ('a' + 1); a keyword name carrying a trailing dot, one name to the
# oracle's lexer and a parse refusal in SCRIP (&ANCHOR. X). Each arm wants the two verdicts EQUAL; the arm is red today.
#   bash ../harness/scripts/test_gate_sno_parser_refuses_at_compile_time_what_spitbol_refuses.sh [ARM]   -- one class arm alone (a row's DONE-WHEN)
# ⛔ the verdict is the rc of `scrip --compile --out=FILE` on the statement alone (0 accepts, nonzero refuses); a stale scrip is
# REFUSED rc=2 by util_require_fresh.sh. Until CEO-2016 the verdict was the standalone parser's, out/parser_snobol4; the parser no
# longer refuses a fold or a value used where a name is required, so that binary would read ACCEPT for what the compile refuses.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
ONLY="${1:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; SCRIP="$ROOT/scrip"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="${SBL:-$(sbl_correctness_bin 2>/dev/null || echo /home/resources/x64/bin/sbl)}"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP -- make first"; exit 2; }
[ -x "$SBL" ] || { echo "⛔ REFUSE(2): no SPITBOL oracle at $SBL"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; trap 'rm -rf "$W"; exit 143' TERM; trap 'rm -rf "$W"; exit 130' INT
fail=0
arm() { # arm <label> <statement>  -- compare SCRIP's compile verdict with the oracle's compile verdict
  [ -z "$ONLY" ] || [ "$1" = "$ONLY" ] || [ "${1#control-}" != "$1" ] || return 0
  printf '\t%s\nEND\n' "$2" > "$W/s.sno"
  if timeout -k 5 20 "$SCRIP" --compile --out="$W/s.s" "$W/s.sno" </dev/null >/dev/null 2>&1; then sc=ACCEPT; else sc=REFUSE; fi
  out="$(cd "$W" && timeout -k 5 5 "$SBL" -bf s.sno </dev/null 2>&1)"
  if printf '%s\n' "$out" | grep -q 'macro spitbol version'; then sb=REFUSE; else sb=ACCEPT; fi
  if [ "$sc" = "$sb" ]; then echo "  ✅ $1: SCRIP compile $sc, SPITBOL compile $sb  [$2]"; else echo "  ⛔ $1: SCRIP compile $sc, SPITBOL compile $sb  [$2]"; fail=$((fail+1)); fi
}
echo "--- SELF-PROOF: a statement both accept and one both refuse ---"
arm "control-accept" "OUTPUT = X + 1"
arm "control-refuse" "OUTPUT = X+1"
echo "--- THE THREE CLASSES ---"
arm "literal-target" "OUTPUT = 'a' = X"
arm "folded-type-clash" "OUTPUT = 'a' + 1"
arm "keyword-trailing-dot" "OUTPUT = &ANCHOR. X"
[ "$fail" = 0 ] && { echo "✅ GATE OK: SCRIP's compile refuses at compile time what SPITBOL refuses at compile time, on the three census classes"; exit 0; }
echo "⛔ GATE RED: $fail arm(s) failed"; exit 1
