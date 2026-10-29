#!/usr/bin/env bash
# test_gate_pas_a_comment_not_closed_before_the_end_of_the_file_is_refused_at_fpcs_line.sh -- a Pascal source whose { or (* comment is still open at the end of the file
# is refused with a lexical diagnostic naming ISO 7185 6.1.8 and the line where the file ends, the line fpc reports for the same program; closed comments run as before.
#
# WHY (PAT iso7185prt1620, "Unterminated comment"; the ceo's pat-five-reds-after-the-coo-measurement-fix, 2026-10-21): the lexer had no end-of-file rule in its two comment
# states, swallowed the rest of the file silently, and the refusal came from the parser as 'syntax error' with no word about the comment. THE CURE (pascal.l, regenerated into
# pascal.lex.c): <COMMENT,BRACE><<EOF>> prints 'ISO 7185 6.1.8 violation line N: a comment is not closed before the end of the file' and counts an ISO error.
#
# MEASURED 2026-10-21 by hq_pascal against fpc 3.2.2: Fatal: Unexpected end of file at (6) for a 5-line file that ends in a newline and at (3,46) for a 3-line file that does not,
# i.e. the line where the end of the file sits, which is the lexer's own line counter at that point. ARMS (both modes; the refusal side is judged against fpc LIVE -- fpc must refuse,
# scrip must exit non-zero, name 6.1.8 and give fpc's line; the run side is cut from fpc): cmtparen ((* open, trailing newline), cmtbrace ({ open, no trailing newline), cmtbrace2
# ({ open under {$mode objfpc}), cmtok (both kinds closed, a program that prints). FAIL_ONCE=1 corrupts cmtok's expectation.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
printf 'program cmtparen;\nbegin\n  (* open\n  writeln(1)\nend.\n' > "$T/cmtparen.pas"
printf 'program cmtbrace;\nbegin\n  writeln(2) { open at the end without a newline' > "$T/cmtbrace.pas"
printf '{$mode objfpc}\nprogram cmtbrace2;\nbegin\n  { open\n  writeln(3)\nend.\n' > "$T/cmtbrace2.pas"
printf 'program cmtok;\n{ closed }\n(* closed too *)\nbegin writeln(4) end.\n' > "$T/cmtok.pas"
refusal() { local p="$1" om="$2" fl
  mkdir -p "$T/fpc"; fl=$( cd "$T" && "$FPC" $om -v0 -FE"$T/fpc" -o"$T/$p.fpc" "$T/$p.pas" 2>&1 | grep -o "$p.pas([0-9]*" | head -1 | sed 's/.*(//' )
  if [ -z "$fl" ]; then echo "⛔ GATE REFUSE(2) [$G]: fpc $om did not refuse $p with a line -- the oracle gives no line to compare"; exit 2; fi
  for m in m3 m4; do N=$((N + 1))
    if [ "$m" = m3 ]; then ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); rc=$?
    else ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/$p.s" "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); rc=$?; fi
    sl=$(grep -o '6\.1\.8 violation line [0-9]*' "$T/e" | head -1 | tr -dc '0-9' | sed 's/^618//')
    if [ "$rc" != 0 ] && [ "$rc" -lt 124 ] && [ "$sl" = "$fl" ] && [ ! -s "$T/o" ]; then echo "  $p $m: refused rc=$rc naming 6.1.8 at line $sl, the line fpc $om gives"
    else echo "  ⛔ $p $m FAILED: rc=$rc, line '$sl' (fpc $fl): $(head -1 "$T/e" | cut -c1-120)"; RC=1; fi; done; }
refusal cmtparen -Miso
refusal cmtbrace -Miso
refusal cmtbrace2 -Mobjfpc
( cd "$T" && "$FPC" -Miso -v0 -FE"$T/fpc" -o"$T/cmtok.fpc" "$T/cmtok.pas" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc would not compile cmtok"; exit 2; }
( cd "$T" && timeout -k 5 20s "./cmtok.fpc" </dev/null >"$T/cmtok.want" 2>/dev/null ); frc=$?
[ -n "${FAIL_ONCE:-}" ] && echo "corrupted by FAIL_ONCE" >> "$T/cmtok.want"
for m in m3 m4; do N=$((N + 1))
  if [ "$m" = m3 ]; then ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" --run cmtok.pas </dev/null >"$T/o" 2>"$T/e" ); rc=$?
  else ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/cmtok.s" cmtok.pas </dev/null >/dev/null 2>"$T/e" && cc -m64 -no-pie cmtok.s -o cmtok.m4 -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 && timeout -k 5 20s ./cmtok.m4 </dev/null >"$T/o" 2>"$T/e" ); rc=$?; fi
  if [ "$rc" = "$frc" ] && cmp -s "$T/cmtok.want" "$T/o"; then echo "  cmtok $m: rc=$rc, stdout byte-identical to fpc -Miso ($(tr '\n' '|' < "$T/o"))"
  else echo "  ⛔ cmtok $m FAILED: rc=$rc (fpc $frc)"; diff "$T/cmtok.want" "$T/o" | head -4 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: an unclosed comment is refused naming 6.1.8 at fpc's line, closed comments run, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined four programs over $N arms"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
