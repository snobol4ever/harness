#!/usr/bin/env bash
# test_gate_pas_a_char_value_assigned_to_a_string_variable_is_one_character_not_its_decimal_text.sh -- s := chr(n) stores the one character of
# code n, so ord(s[1]) is n and length(s) is 1; before, the integer ordinal chr yields was coerced to its decimal text (s := chr(2) read back 50,
# the code of the digit 2; s := chr(65) printed 65).
#
# MEASURED 2026-10-03 by hq_raku, minted as row pascal-chr-of-a-small-code-assigned-to-a-string-reads-back-as-its-decimal-text; cured here by
# hq_pascal: mk_assign wraps a char-valued right-hand side (chr(...), a char variable, a char expression) in __pas_chr when the target is a string
# variable (the declaration visible at the assignment), as the write path already did. NOT cured and not claimed: string concatenation s := s + 'x'
# fails in this Pascal for every string type (the BINOP fails silently, rc=1) -- a separate defect the PLUS operator would need a concatenation for.
#
# ARMS, both modes, expectations cut LIVE from fpc: (code) chr of small, printable and high codes into a shortstring and an ansistring variable;
# (var) a char variable and a char expression assigned to a string; (plain) a char variable assigned to a char variable stays an ordinal.
# FAIL_ONCE=1 corrupts the code arm's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile or link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }

cat > "$T/code.pas" <<'PAS'
{$mode objfpc}{$H+}
program code(output);
var s: ansistring; t: string;
begin
  s := chr(2); writeln(ord(s[1]), ' ', length(s));
  s := chr(65); writeln(ord(s[1]), ' ', length(s), ' ', s);
  s := chr(200); writeln(ord(s[1]), ' ', length(s));
  t := chr(9); writeln(ord(t[1]), ' ', length(t));
  t := chr(122); writeln(t, ' ', ord(t[1]))
end.
PAS
cat > "$T/varr.pas" <<'PAS'
{$mode objfpc}{$H+}
program varr(output);
var s: ansistring; c: char; n: longint;
begin
  c := 'q'; s := c; writeln(s, ' ', length(s), ' ', ord(s[1]));
  n := 66; s := chr(n); writeln(s, ' ', ord(s[1]));
  s := chr(n + 1); writeln(s)
end.
PAS
cat > "$T/plain.pas" <<'PAS'
{$mode objfpc}{$H+}
program plain(output);
var c, d: char; n: longint;
begin
  c := chr(7); d := c; writeln(ord(c), ' ', ord(d));
  n := ord('a'); c := chr(n); writeln(c, ' ', ord(c))
end.
PAS
for p in code varr plain; do
  frc=$(fpcrun $p)
  if [ "$p" = code ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a char code assigned to a string reads back as that code, as fpc does, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 3 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
