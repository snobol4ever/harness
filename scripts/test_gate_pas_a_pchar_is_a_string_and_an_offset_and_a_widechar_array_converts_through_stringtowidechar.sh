#!/usr/bin/env bash
# test_gate_pas_a_pchar_is_a_string_and_an_offset_and_a_widechar_array_converts_through_stringtowidechar.sh -- a PChar variable reads through a string and an
# offset: p := PChar(@s[k]) (or a string, or a literal, or another PChar) points at character k, Inc/Dec move it, p[i] (negative i included) and p^ read
# the character, and StringToWideChar(s, @buf[k], n) / widestring(pwidechar(@buf[k])) copy a string into a character array in place (at most n-1 characters
# and a NUL) and read it back to the NUL.
#
# MEASURED 2026-10-04 by hq_pascal on FPC webtbs_tw8191 (PChar(@s[1]), Inc(p,4), p[-4]) and webtbs_tw22669 (StringToWideChar, pwidechar): both died with
# error 22 (undefined function pchar / stringtowidechar). DESIGN (cfo 2026-10-04: no raw address, no interior pointer): a PChar is two values the compiler keeps,
# the string (a copy) and a hidden offset variable __pas_po_<name> declared beside it; there is no aliasing, so a WRITE through a PChar does not reach the
# string it was taken from (not claimed). pas_pchar_assign, the Inc/Dec arm, the index and deref selectors and the two conversions in pascal.y do the rest;
# __pas_s2wide / __pas_wide2s write and read the array's cells in place.
#
# ARMS, both modes, expectations cut LIVE from fpc: (str) forward and negative indexing, Inc/Dec, copy of a PChar, a shortstring base; (lit) a string
# literal and the last character; (wide) round trips through a widechar array with a truncating and a short count. FAIL_ONCE=1 corrupts the str arm.
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
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile or link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }

cat > "$T/str.pas" <<'PAS'
{$mode objfpc}{$H+}
program str(output);
var s: ansistring; sh: shortstring; p, q: PChar;
begin
  s := 'abcdefghij'; sh := '0123456789';
  p := PChar(@s[3]);
  writeln(p[0], p[1], p^);
  inc(p, 2); writeln(p[0], p[-1], p[-2]);
  dec(p); writeln(p^);
  q := p; inc(q, 3); writeln(q[0], ' ', p[0]);
  p := PChar(@sh[1]); inc(p, 4); writeln(p[-4], p[5])
end.
PAS
cat > "$T/lit.pas" <<'PAS'
{$mode objfpc}{$H+}
program lit(output);
var p: PChar;
begin
  p := 'hello'; writeln(p[0], p[4]); inc(p); writeln(p^, p[3])
end.
PAS
cat > "$T/wide.pas" <<'PAS'
{$mode objfpc}{$H+}
program wide(output);
var s, t: ansistring; buf: array[1..8] of widechar;
begin
  s := 'abcdefghij';
  buf[1] := 'z';
  StringToWideChar(s, @buf[1], 8); t := widestring(pwidechar(@buf[1])); writeln(t, length(t));
  StringToWideChar('xy', @buf[2], 8); t := widestring(pwidechar(@buf[2])); writeln(t, length(t));
  t := widestring(pwidechar(@buf[1])); writeln(t, length(t))
end.
PAS
for p in str lit wide; do
  frc=$(fpcrun $p)
  if [ "$p" = str ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a PChar into a string and a widechar array convert as fpc does, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 3 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
