#!/usr/bin/env bash
# test_gate_pas_zero_based_strings_make_low_zero_and_index_from_zero_after_the_directive.sh -- after {$ZEROBASEDSTRINGS ON}
# (also {$ZEROBASEDSTRINGS+}) the first character of an ansistring is s[0], low(s) is 0 and high(s) is Length(s)-1; {$ZEROBASEDSTRINGS OFF}
# (or -) and {$Pop} restore one-based strings; a shortstring is untouched.
#
# MEASURED 2026-10-03 by hq_pascal, row pascal-every-suite-to-100-under-nonet-ceo-1266. FPC webtbs_tw22936 halted rc=1 on its
# first check after the directive: the lexer ignored {$ZEROBASEDSTRINGS} so low(s) stayed 1.
#
# CURE (Lon granted the new global in-chat 2026-10-03): pascal.l keeps g_pas_zerobased_strings (set and cleared by the
# directive, saved and restored by {$Push}/{$Pop}); pascal.y's low/high fold answers 0 and Length(s)-1 for an ansi-family
# variable while it is on, and the index selector of such a variable lowers s[i] to the one-based s[i+1].
# ALSO CURED here (found by this gate's own first run): an element s[i] of a string variable is a char, so writeln(s[1]) prints
# the character -- pas_is_charexpr knew only char ARRAYS and printed the ordinal 97 for an ansistring's first character.
#
# ARMS, both modes, expectations cut LIVE from fpc: (zbs) the tw22936 shape plus a loop low..high and an element write;
# (offon) ON, OFF, + and - toggles and a {$Push}{$ON}{$Pop} that returns to one-based; (short) a shortstring beside an
# ansistring while the flag is on. FAIL_ONCE=1 corrupts the offon arm's ref.
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

cat > "$T/zbs.pas" <<'PAS'
{$mode objfpc}{$H+}
program zbs(output);
var s: ansistring; i: integer;
begin
  s := 'abc';
  writeln(low(s), ' ', high(s), ' ', s[1]);
{$ZEROBASEDSTRINGS ON}
  writeln(low(s), ' ', high(s), ' ', s[0]);
  for i := low(s) to high(s) do write(s[i]);
  writeln;
  s[0] := 'X';
{$ZEROBASEDSTRINGS OFF}
  writeln(s, ' ', s[1])
end.
PAS
cat > "$T/offon.pas" <<'PAS'
{$mode objfpc}{$H+}
program offon(output);
var s: ansistring;
begin
  s := 'hello';
{$ZEROBASEDSTRINGS+}
  writeln(low(s), ' ', high(s), ' ', s[0], s[4]);
{$ZEROBASEDSTRINGS-}
  writeln(low(s), ' ', high(s), ' ', s[1], s[5]);
{$Push}
{$ZEROBASEDSTRINGS ON}
  writeln(low(s), ' ', high(s), ' ', s[0]);
{$Pop}
  writeln(low(s), ' ', high(s), ' ', s[1])
end.
PAS
cat > "$T/short.pas" <<'PAS'
{$mode objfpc}{$H+}
program short(output);
var a: ansistring; t: shortstring;
begin
  a := 'abc'; t := 'xyz';
{$ZEROBASEDSTRINGS ON}
  writeln(low(a), ' ', high(a), ' ', a[0]);
  writeln(low(t), ' ', high(t), ' ', t[1]);
{$ZEROBASEDSTRINGS OFF}
  writeln(low(a), ' ', high(a), ' ', a[1])
end.
PAS
for p in zbs offon short; do
  frc=$(fpcrun $p)
  if [ "$p" = offon ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: zero-based strings behave as fpc does, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 3 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
