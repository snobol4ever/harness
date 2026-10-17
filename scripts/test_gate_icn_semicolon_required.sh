#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_icn_semicolon_required.sh — THE PRISON for the ICON SEMICOLON-REQUIRED FACT RULE.
#
# SCRIP Icon REQUIRES an explicit ';' between bare statements. The Icon front-end does NO newline
# processing: a newline is plain whitespace and NEVER becomes a statement separator. Newline-to-
# semicolon insertion (the canonical icont "Beginner/Ender" rule) is FORBIDDEN in this codebase.
#
# This gate is structural AND behavioral, in three independent locks. A reintroduction of newline
# insertion must defeat ALL THREE to pass, which it cannot:
#
#   LOCK 1 (negative grep) — the Icon lexer/parser source carries ZERO newline-insertion machinery:
#       no Beginner/Ender token classification, no newline-crossing detection, no synthetic-token
#       buffering whose purpose is separator insertion. Comments are stripped first.
#
#   LOCK 2 (mint-site) — TK_SEMICOL is MINTED in the Icon lexer ONLY from the literal ';' character.
#       The number of make_tok(TK_SEMICOL,...) sites in icon_lex.c must be exactly 1 (the `case ';'`).
#       (The parser CONSUMES TK_SEMICOL freely; this lock is about where it is PRODUCED.)
#
#   LOCK 3 (behavioral canary) — the actual language behavior is pinned, independent of identifier
#       names. A two-bare-statement program separated only by a NEWLINE MUST FAIL to parse; the same
#       program with an explicit ';' MUST parse. If someone adds insertion, the newline canary starts
#       parsing and this lock trips.
#
# Usage: bash ../harness/scripts/test_gate_icn_semicolon_required.sh        # HARD gate (exit 1 on any breach)
# AUTHORS: Lon Jones Cherryholmes · Jeffrey Cooper M.D. · Claude   DATE: 2026-06-23
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
SCRIP="${SCRIP:-$ROOT/scrip}"
ICN_SRC="$ROOT/src/parsers/icon"
LEX="$ICN_SRC/icon_lex.c"
fail=0

strip_comments() { sed -E 's://.*$::' "$1" | perl -0777 -pe 's{/\*.*?\*/}{}gs'; }

echo "=== ICON SEMICOLON-REQUIRED PRISON ==="

# ---- LOCK 1: no newline-insertion machinery anywhere in the Icon front-end -------------------------
# Tokens that only ever appear when someone is building Beginner/Ender semicolon insertion or
# newline-crossing separator logic. (prev_line/prev_col crossing detection; have_pending separator
# buffering; the canonical icont flag names.)
machinery='tok_is_beginner|tok_is_ender|is_beginner|is_ender|Beginner|Ender|nlsemi|nl_semi|newline_semi|semi_insert|insert_semi|prev_line|have_pending'
mcount=0
for f in "$ICN_SRC"/*.c "$ICN_SRC"/*.h; do
  [ -f "$f" ] || continue
  h=$(strip_comments "$f" | grep -Ec "$machinery" || true)
  if [ "$h" -gt 0 ]; then
    echo "  LOCK 1 BREACH: $(basename "$f") has $h newline-insertion-machinery reference(s):"
    strip_comments "$f" | grep -nE "$machinery" | sed 's/^/      /'
    mcount=$((mcount + h))
  fi
done
if [ "$mcount" -eq 0 ]; then echo "  LOCK 1 OK: zero newline-insertion machinery in src/parsers/icon/."; else fail=1; fi

# ---- LOCK 2: TK_SEMICOL minted only from the literal ';' -------------------------------------------
mint=$(strip_comments "$LEX" | grep -cE 'make_tok\(\s*TK_SEMICOL' || true)
echo "  LOCK 2: make_tok(TK_SEMICOL,...) mint-sites in icon_lex.c = ${mint} (must be 1)"
if [ "$mint" -ne 1 ]; then echo "  LOCK 2 BREACH: TK_SEMICOL is minted from something other than the literal ';' case."; fail=1; else echo "  LOCK 2 OK."; fi

# ---- LOCK 3: behavioral canary --------------------------------------------------------------------
# ⚠️ KNOWN FUTURE BREAK, flagged 2026-09-04 for whoever performs the icon-dialect-...-semicolon landing:
# both probe bodies below close with `end`, which is the dialect Lon confirmed on 2026-09-04 after
# withdrawing the brace proposal: procedure and end STAY, and only the semicolon AFTER a procedure
# header (or after end) is removed. These fixtures are inline heredocs, so no corpus-wide sweep will
# ever reach them -- seat02 flagged that during the brace work and it stays true for the strip.
if [ ! -x "$SCRIP" ]; then
  # ⛔ A GATE THAT CANNOT MEASURE REFUSES rc=2 -- never skip-as-success (RULES.md). Until 2026-09-04 this arm printed
  # SKIP and left fail=0, so an unbuilt tree read "PASS: All locks hold" on two of three locks (hq_B, strip-row audit).
  echo "  ⛔ LOCK 3 REFUSE(2): scrip binary not built at $SCRIP -- the behavioral lock cannot be measured (run make)."; exit 2
else
  tmpd="$(mktemp -d /tmp/icn_semi_XXXXXX)"
  # newline-only: two bare statements separated by a newline — MUST be a parse error
  printf 'procedure main()\n  x := 5\n  y := 6\n  write(x + y)\nend\n' > "$tmpd/nl.icn"
  # semicolon: same program with explicit ';' — MUST parse
  printf 'procedure main()\n  x := 5;\n  y := 6;\n  write(x + y);\nend\n' > "$tmpd/semi.icn"

  nl_err=$("$SCRIP" --run "$tmpd/nl.icn" < /dev/null 2>&1 | grep -c 'parse error' || true)
  semi_err=$("$SCRIP" --run "$tmpd/semi.icn" < /dev/null 2>&1 | grep -c 'parse error' || true)

  if [ "$nl_err" -ge 1 ]; then
    echo "  LOCK 3a OK: newline-separated bare statements correctly REJECTED (parse error)."
  else
    echo "  LOCK 3a BREACH: newline-separated bare statements were ACCEPTED — newline processing is present."
    fail=1
  fi
  if [ "$semi_err" -eq 0 ]; then
    echo "  LOCK 3b OK: semicolon-separated statements correctly ACCEPTED."
  else
    echo "  LOCK 3b BREACH: semicolon-separated statements were REJECTED — the parser is over-strict/broken."
    fail=1
  fi
  rm -rf "$tmpd"
fi

echo "  LOCK 4 (Lon 2026-10-01, CEO-1392): EVERY STATEMENT IN A PROCEDURE BODY ENDS IN ';' -- the last one before end included; only the last expression of a { } block is bare (a ';' there nulls the block's value under iconx too)"
L4T=$(mktemp -d); trap 'rm -rf "$L4T"' EXIT; trap 'rm -rf "$L4T"; exit 143' TERM; trap 'rm -rf "$L4T"; exit 130' INT
l4() { # l4 <want ACCEPT|REFUSE> <source>
  printf '%b' "$2" > "$L4T/p.icn"
  if timeout -k 5 5 "$SCRIP" "$L4T/p.icn" </dev/null >/dev/null 2>"$L4T/err"; then got=ACCEPT; else got=REFUSE; fi
  if [ "$got" = "$1" ]; then echo "    ok   $1  $(printf '%s' "$2" | tr '\n' '~' | cut -c1-70)"; else echo "    BREACH want $1 got $got  $(printf '%s' "$2" | tr '\n' '~' | cut -c1-70)  $(head -1 "$L4T/err" | cut -c1-80)"; fail=1; fi
}
l4 REFUSE 'procedure main(); write(1); write(2) end\n'
l4 REFUSE 'procedure main(); write(1)\nwrite(2); end\n'
l4 REFUSE 'procedure main(); write(1) write(2); end\n'
l4 ACCEPT 'procedure main(); write(1); write(2); end\n'
l4 REFUSE 'procedure main(); if 1 < 2 then write(1) else write(2)\nend\n'
l4 ACCEPT 'procedure main(); repeat { write(1); break }; end\n'
l4 ACCEPT 'procedure main(); local x; x := 1; write(x); end\n'
l4 REFUSE 'procedure main(); local x\nend\n'
l4 REFUSE 'procedure main(); if 1 < 2 then write(1) write(2); end\n'
l4 ACCEPT 'procedure main(); x := {1; 2}; write(x); end\n'
l4 ACCEPT 'procedure main(); every i := 1 to 2 do { write(i) }; end\n'
l4 REFUSE 'procedure main(); every i := 1 to 2 do { write(i) }\nend\n'
l4 REFUSE 'procedure main(); return\nend\n'
l4 ACCEPT 'procedure main(); return; end\n'
l4 REFUSE 'procedure main(); suspend 1\nend\n'
l4 ACCEPT 'procedure main(); suspend 1; end\n'
echo "---"
if [ "$fail" -ne 0 ]; then
  echo "FAIL: ICON SEMICOLON-REQUIRED PRISON breached. Icon does NO newline processing; semicolons are mandatory."
  exit 1
fi
echo "PASS: Icon does no newline processing; semicolons are mandatory between statements. All locks hold."
exit 0
