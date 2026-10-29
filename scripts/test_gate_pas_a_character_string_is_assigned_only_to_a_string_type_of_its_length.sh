#!/usr/bin/env bash
# test_gate_pas_a_character_string_is_assigned_only_to_a_string_type_of_its_length.sh -- ISO 7185 6.4.3.2 with 6.4.6 and 6.8.2.2: a character-string is assignment-compatible only with a
# string-type of the same number of components, and a string-type is a packed array [1..n] of char with n > 1; a one-character string is a char and no array takes it (PAT iso7185prt1761-1765).
#
# MEASURED 2026-10-07 by hq_pascal: PAT 1761 (an 11-character string to packed array [1..10]), 1762 (index 0..10), 1763 (one component, 'h'), 1764 (not packed) and 1765 (component a
# subrange of char) compiled and ran to rc 0 in both modes, and 1763 printed an empty string; fpc -Miso accepts 1761-1764 (it refuses 1765), so the expectation is the ISO text.
# CURE: pascal.y's 1-D array rule marks a char array PAS_CA_NOSTR unless it is packed, its component is exactly char and its index is 1..n with n > 1; the bit rides g_pas_pend_arr_ischar
# into the named-type table and the variable's row (with the length), and pas_string_assign_check, called beside pas_value_compat in the assignment rule, refuses at compile time.
# A program that declares a non-ISO dialect ({$mode objfpc} and the rest, g_pas_seen_mode_directive) is not held to it.
#
# ARMS, both modes: twelve fault programs must be refused naming the clause, with empty stdout; two controls cut LIVE from fpc (a legal program of correct lengths, named types, a var
# and a value formal, a shadowing local, char and element assignment; a {$mode objfpc} program assigning a string to array [0..4] of char) must run byte-identical. FAIL_ONCE=1
# corrupts the first control's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile or link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }


cat > "$T/flong.pas" <<'PAS'
program flong(output);
var a: packed array [1..10] of char;
begin a := 'h          ' end.
PAS
cat > "$T/fshort.pas" <<'PAS'
program fshort(output);
var a: packed array [1..10] of char;
begin a := 'abcdefghi' end.
PAS
cat > "$T/fnamed.pas" <<'PAS'
program fnamed(output);
type s5 = packed array [1..5] of char;
var x: s5;
begin x := 'abcdef'; writeln(x) end.
PAS
cat > "$T/fformal.pas" <<'PAS'
program fformal(output);
type s5 = packed array [1..5] of char;
procedure p(a: s5);
begin a := 'abcdef'; writeln(a) end;
begin p('hello') end.
PAS
cat > "$T/fshadow.pas" <<'PAS'
program fshadow(output);
var s: packed array [1..10] of char;
procedure p;
var s: packed array [1..3] of char;
begin s := 'abcdefghij'; writeln(s) end;
begin p end.
PAS
cat > "$T/fzero.pas" <<'PAS'
program fzero(output);
var s: packed array [0..10] of char;
begin s := 'h          '; writeln(s) end.
PAS
cat > "$T/flo2.pas" <<'PAS'
program flo2(output);
var s: packed array [2..11] of char;
begin s := 'abcdefghij'; writeln(s) end.
PAS
cat > "$T/funp.pas" <<'PAS'
program funp(output);
var s: array [1..10] of char;
begin s := 'hello, you'; writeln(s) end.
PAS
cat > "$T/fsub.pas" <<'PAS'
program fsub(output);
type mychar = 'a'..'z';
var s: packed array [1..10] of mychar;
begin s := 'hello you '; writeln(s) end.
PAS
cat > "$T/fnamedun.pas" <<'PAS'
program fnamedun(output);
type u = array [1..4] of char;
var x: u;
begin x := 'abcd'; writeln(x) end.
PAS
cat > "$T/fone.pas" <<'PAS'
program fone(output);
var s: packed array [1..1] of char;
begin s := 'h'; writeln(s) end.
PAS
cat > "$T/fchar.pas" <<'PAS'
program fchar(output);
var s: packed array [1..4] of char;
begin s := 'x'; writeln(s) end.
PAS
cat > "$T/ctl.pas" <<'PAS'
program ctl(output);
type s5 = packed array [1..5] of char; u = array [1..3] of char;
var a: packed array [1..10] of char; b: packed array [1..2] of char; x: s5; c: char; u3: u;
procedure q(var z: s5); begin z := 'world'; writeln(z) end;
procedure r(z: s5); begin z := 'again'; writeln(z) end;
procedure p;
var s: packed array [1..3] of char;
begin s := 'abc'; writeln(s) end;
begin
  a := 'abcdefghij'; writeln(a);
  b := 'ab'; writeln(b);
  x := 'hello'; writeln(x); q(x); r(x); writeln(x);
  p; c := 'q'; writeln(c); a[3] := 'z'; writeln(a);
  u3[1] := 'a'; u3[2] := 'b'; u3[3] := 'c'; writeln(u3[2])
end.
PAS
cat > "$T/dialect.pas" <<'PAS'
{$mode objfpc}
program dialect;
var s: array [0..4] of char;
begin s := 'abcde'; writeln(s) end.
PAS
RC=0; N=0
for m in m3 m4; do
  for pc in flong:6.4.6 fshort:6.4.6 fnamed:6.4.6 fformal:6.4.6 fshadow:6.4.6 fzero:6.4.3.2 flo2:6.4.3.2 funp:6.4.3.2 fsub:6.4.3.2 fnamedun:6.4.3.2 fone:6.8.2.2 fchar:6.8.2.2; do
    p=${pc%:*}; cl=${pc#*:}
    if [ $m = m3 ]; then run m3 $p; rc=$?; else ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/$p.s" "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); rc=$?; fi; N=$((N + 1))
    if [ "$rc" != 0 ] && [ ! -s "$T/o" ] && grep -q "ISO 7185 $cl violation" "$T/e"; then echo "  $p $m: refused naming $cl (rc=$rc)"
    else echo "  ⛔ $p $m FAILED: rc=$rc stdout=[$(head -c 60 "$T/o" | tr '\n' '|')] err=[$(head -c 100 "$T/e")]"; RC=1; fi
  done
done
first=1
for c in ctl dialect; do
  frc=$(fpcrun $c)
  if [ -n "${FAIL_ONCE:-}" ] && [ $first = 1 ]; then echo "corrupted by FAIL_ONCE" >> "$T/$c.want"; fi; first=0
  for m in m3 m4; do run $m $c; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$c.want" "$T/o"; then echo "  $c $m: rc=$rc, stdout byte-identical to fpc ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $c $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$c.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi
  done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a character-string is given only to a string-type of its length and a legal program runs as fpc, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined 14 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
