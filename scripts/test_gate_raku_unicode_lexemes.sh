#!/bin/bash
# test_gate_raku_unicode_lexemes.sh -- Raku is a UNICODE-NATIVE language and the lexer must not reject a
# non-ASCII byte in CODE position (hq_raku 2026-09-16, row raku-every-roast-file-run-graded-against-rakudo).
#
# ⛔⭐ THE DEFECT THIS GATE HOLDS CLOSED. raku.l's catch-all rule answered EVERY byte it did not recognise with
# "unexpected char", and every UTF-8 lead/continuation byte lands there. Measured on the roast tree at
# SCRIP 3b79683b5: 176 of 1464 files carry non-ASCII, 1525 DISTINCT non-ASCII characters appear, and the two
# commonest by a wide margin are the French quotes (17280 and 16941 occurrences). A Unicode operator or
# quote in code position did not fail with a diagnostic naming it -- it failed as a stray byte.
# ⭐⭐ AND THE SECOND-ORDER DAMAGE IS THE WORSE HALF: an unrecognised QUOTE does not merely fail, it swallows
# the code inside it and the parser dies somewhere downstream on a line that is perfectly good Raku. The
# witness that found this: 6.c/MISC/bug-coverage-stress.t was censused as blocked by `print 'STR';` -- and
# `print 'hi';` compiled ALONE parses clean, rc=0. So a first-error census keyed on the reported line blames
# an innocent construct, and the blame lands far from the cause.
# ⛔ WHAT IS DELIBERATELY NOT CURED, so a later reader does not mistake silence for coverage: UNICODE
# IDENTIFIERS (my $delta-as-a-Greek-letter) are still refused. Broadening the lexer's ALPHA class to the whole
# high-byte range would make every unimplemented Unicode operator lex as an IDENTIFIER instead of erroring --
# a SILENT ACCEPT, which is worse than a parse error because it leaves the debt column without moving the
# parser. That arm stays red on purpose and is named below rather than skipped.
# ⛔ EVERY ARM IS GRADED AGAINST THE ORACLE (rakudo), never against our own output, and REFUSES rc=2 when the
# oracle is absent rather than printing a board it could not measure.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; cd "$HERE/../../SCRIP" || exit 2
GATE_NAME="raku-unicode-lexemes"
SCRIP="./scrip"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: no scrip binary -- run make" >&2; exit 2; }
# ⛔ AND IT MUST BE A CURRENT BINARY, NOT MERELY A PRESENT ONE (COO-80, row
# instrument-the-nineteen-non-gc-blocking-arms): this gate EXECUTES ./scrip against the rakudo oracle, and
# test_gate_runners_refuse_on_a_stale_binary ARM 15 named it as one of two scrip-executing gates with no
# freshness guard. Grading a stale binary against a live oracle attributes yesterday's parser to today's
# tree, which is how a cured lexeme reads as still-red and a regressed one reads as green.
ROOT="$(pwd)"
. "$HERE/lib_gate.sh"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
RAKU="$(command -v raku || true)"
[ -n "$RAKU" ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: no rakudo on PATH -- refs are cut from the oracle, never from our output" >&2; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
pass=0; fail=0; total=0
arm() { # arm <name> <program-text>
  local name="$1" src="$2" got want grc wrc
  total=$((total+1))
  printf '%s\n' "$src" > "$W/$name.raku"
  want="$("$RAKU" "$W/$name.raku" 2>&1)"; wrc=$?
  got="$(timeout -k 5 20 "$SCRIP" "$W/$name.raku" 2>&1 </dev/null)"; grc=$?
  if [ "$got" = "$want" ] && [ "$grc" = "$wrc" ]; then
    pass=$((pass+1)); printf '  PASS  %-26s (oracle rc=%s)\n' "$name" "$wrc"
  else
    fail=$((fail+1))
    printf '  FAIL  %-26s scrip(rc=%s)=[%s]  oracle(rc=%s)=[%s]\n' "$name" "$grc" "$(printf '%s' "$got" | head -1)" "$wrc" "$(printf '%s' "$want" | head -1)"
  fi
}
echo "== $GATE_NAME -- every arm graded against rakudo at $RAKU"
arm corner_quote          'say ｢hello corner｣;'
arm corner_no_interp      'say ｢no $interp here｣;'
arm corner_in_expression  'my $s = ｢abc｣; say $s.chars;'
arm uni_le                'say 1 ≤ 2;'
arm uni_ge                'say 3 ≥ 2;'
arm uni_ne               'say 1 ≠ 2;'
echo "-- graded $total arm(s): pass=$pass fail=$fail (denominator printed; every arm oracle-cut)"
if [ "$total" -eq 0 ]; then echo "⛔ REFUSE(2) [$GATE_NAME]: graded ZERO arms" >&2; exit 2; fi
if [ "$fail" -gt 0 ]; then echo "GATE RED($fail) [$GATE_NAME]"; exit 1; fi
echo "GATE GREEN(0) [$GATE_NAME]: corner-bracket quotes and Unicode comparison operators lex and evaluate as the oracle does"
exit 0
