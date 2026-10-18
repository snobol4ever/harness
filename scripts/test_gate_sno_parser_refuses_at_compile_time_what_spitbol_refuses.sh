#!/usr/bin/env bash
# test_gate_sno_parser_refuses_at_compile_time_what_spitbol_refuses.sh -- the first product of the grammar-based harness
# (Lon and the ceo, 2026-10-01, CEO-1393): gen_every_snobol4.icn enumerated every OUTPUT = <expression> statement of at
# most 3 tokens (10834) and each went through SCRIP's parser (out/parser_snobol4) and through sbl -bf; where the oracle
# refuses a statement AT COMPILE TIME and SCRIP's parser accepts it, SCRIP grades a compile refusal as a runtime answer.
# Three classes, one witness each, canonical shapes from the census (699 statements of the first two kinds, 20 of the
# third): a literal as the target of = . $ or under unary @ and & ('a' = X); literal-only arithmetic with a type clash,
# which SPITBOL folds and refuses at compile time ('a' + 1); a keyword name carrying a trailing dot, one name to the
# oracle's lexer and a parse refusal in SCRIP (&ANCHOR. X). Each arm wants the two verdicts EQUAL; the arm is red today.
#   bash ../harness/scripts/test_gate_sno_parser_refuses_at_compile_time_what_spitbol_refuses.sh [ARM]   -- one class arm alone (a row's DONE-WHEN)
# ⛔ `make` never builds out/parser_* (all: is scrip and scrip-ipp); `make parsers` does. A parser binary older than
# src/tools/parser_main.c is REFUSED rc=2: one built before ae0a91289 returned 0 on a SNOBOL4 parse error, so the self-proof's
# control-refuse read ACCEPT and the gate red for a reason that was not SCRIP's parser (the cto and the cfo, 2026-10-03).
set -u
ONLY="${1:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; PS="$ROOT/out/parser_snobol4"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="${SBL:-$(sbl_correctness_bin 2>/dev/null || echo /home/resources/x64/bin/sbl)}"
[ -x "$PS" ] || { echo "⛔ REFUSE(2): no out/parser_snobol4 -- make parsers first"; exit 2; }
( . "$HERE/lib_build_currency.sh" && assert_parser_current snobol4 "$ROOT" ) || { echo "⛔ REFUSE(2): out/parser_snobol4 is older than a source it was compiled from (named above) -- make parsers (make never builds the parser binaries)"; exit 2; }
[ -x "$SBL" ] || { echo "⛔ REFUSE(2): no SPITBOL oracle at $SBL"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; trap 'rm -rf "$W"; exit 143' TERM; trap 'rm -rf "$W"; exit 130' INT
fail=0
arm() { # arm <label> <statement>  -- compare SCRIP's parse verdict with the oracle's compile verdict
  [ -z "$ONLY" ] || [ "$1" = "$ONLY" ] || [ "${1#control-}" != "$1" ] || return 0
  printf '\t%s\nEND\n' "$2" > "$W/s.sno"
  if timeout -k 5 5 "$PS" "$W/s.sno" >/dev/null 2>&1; then sc=ACCEPT; else sc=REFUSE; fi
  out="$(cd "$W" && timeout -k 5 5 "$SBL" -bf s.sno </dev/null 2>&1)"
  if printf '%s\n' "$out" | grep -q 'macro spitbol version'; then sb=REFUSE; else sb=ACCEPT; fi
  if [ "$sc" = "$sb" ]; then echo "  ✅ $1: SCRIP parser $sc, SPITBOL compile $sb  [$2]"; else echo "  ⛔ $1: SCRIP parser $sc, SPITBOL compile $sb  [$2]"; fail=$((fail+1)); fi
}
echo "--- SELF-PROOF: a statement both accept and one both refuse ---"
arm "control-accept" "OUTPUT = X + 1"
arm "control-refuse" "OUTPUT = X+1"
echo "--- THE THREE CLASSES ---"
arm "literal-target" "OUTPUT = 'a' = X"
arm "folded-type-clash" "OUTPUT = 'a' + 1"
arm "keyword-trailing-dot" "OUTPUT = &ANCHOR. X"
[ "$fail" = 0 ] && { echo "✅ GATE OK: SCRIP's parser refuses at compile time what SPITBOL refuses at compile time, on the three census classes"; exit 0; }
echo "⛔ GATE RED: $fail arm(s) failed"; exit 1
