#!/usr/bin/env bash
# test_gate_pas_succ_and_pred_keep_their_arguments_type.sh -- ISO 7185 6.6.6.4, succ and pred yield a value of their argument's type
#
# MEASURED 2026-09-24 by hq_pascal on SCRIP d1c392ecd, both modes, row pascal-all-test-suites-of-the-language-read-100-percent-on-the-
# suite-table-the-home-stretch. A WRONG ANSWER, found writing a control for the 6.6.6.4 range gate: succ(x) "shall yield a value whose
# ordinal number is one greater than that of the expression x" -- a value of x's type -- but mk_call lowered succ and pred to x + 1
# and x - 1, an integer, so writeln(succ(c), pred(c), succ(b), pred(true), succ('x')) printed 99 97 1 0 121 in m3 at rc=0 where
# fpc -Miso prints "ca  true false y". The result now carries the argument's type the way the rest of the parser already reads one:
# a char argument (a char expression or char literal) returns the result through __pas_chrlit, as chr() does, and a Boolean argument
# returns it as a relation (result <> 0), which pas_is_boolexpr and the writer already treat as Boolean. ord() of either still
# unwraps to the ordinal. No suite cell moved; the 6.6.6.4 range checks still fire inside the wrapper (their gate is green).
#
# ARMS: one program cut LIVE from fpc -Miso and required byte-identical in BOTH modes (m4 compiles, links and runs): succ and pred of
# char variables, char literals, a char constant, Boolean variables and literals, written, compared, assigned, ordered and combined
# with and. It FAILS on the parent tree. FAIL_ONCE=1 corrupts the ref to prove the arm can fail.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's ref is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
m4_run() { M4O=$( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/w.s" "$1" </dev/null 2>&1 ); M4RC=$?
  if [ "$M4RC" = 0 ]; then
    ( cd "$T" && cc -m64 -no-pie w.s -o w -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: $1 compiled but would not link -- cannot grade the m4 arm"; exit 2; }
    M4O=$( cd "$T" && timeout -k 5 20s ./w </dev/null 2>&1 ); M4RC=$?
  fi; }
cat > "$T/ok.pas" <<'PAS'
program succtype(output);
const first = 'a';
var c, d: char; b: boolean; n: integer;
begin
  c := 'b'; b := false;
  writeln(succ(c), pred(c), ' ', succ(b), ' ', pred(true), ' ', succ('x'), ' ', succ(first));
  d := pred(c); if succ(c) = 'c' then writeln('succ compares as a char ', d);
  n := 0; c := 'a'; while c < 'e' do begin c := succ(c); n := n + 1 end;
  writeln(n:1, ' ', c, ' ', ord(succ(c)):1, ' ', ord(pred(true)):1, ' ', succ(b) and true)
end.
PAS
for p in ok; do
  N=$((N+1))
  ( cd "$T" && "$FPC" -Miso -v0 $p.pas >/dev/null 2>&1 && ./$p ) > "$T/$p.ref" 2>&1
  [ -s "$T/$p.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no output for arm $p"; exit 2; }
  if [ -n "${FAIL_ONCE:-}" ] && [ "$p" = ok ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.ref"; fi
  o3=$( cd "$T" && timeout -k 5 20s "$SCRIP" --run $p.pas </dev/null 2>&1 ); m4_run "$T/$p.pas"; o4="$M4O"
  if [ "$o3" = "$(cat "$T/$p.ref")" ] && [ "$o4" = "$(cat "$T/$p.ref")" ]; then echo "  arm $p: byte-identical to fpc -Miso in both modes"
  else echo "  ⛔ arm $p FAILED"; echo "      want: $(tr '\n' '|' < "$T/$p.ref")"; echo "      m3  : $(printf '%s' "$o3" | tr '\n' '|')"; echo "      m4  : $(printf '%s' "$o4" | tr '\n' '|')"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: succ and pred of char and Boolean values yield chars and Booleans, byte-identical to fpc -Miso in both modes"
else echo "GATE FAIL(1) [$G]: examined $N oracle-cut arms"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
