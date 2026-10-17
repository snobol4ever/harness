#!/usr/bin/env bash
# test_gate_pas_a_string_type_is_indexed_by_an_integer_subrange_not_an_enumerated_one.sh -- ISO 7185 6.4.3.2: a string-type is a packed array [1..n] of char, n > 1; the index-type is a subrange of INTEGER (PAT iso7185prt1855).
#
# MEASURED 2026-10-08 by hq_pascal: PAT 1855 (`type enum = (one, two, three); sr = two..three; var s: packed array [sr] of char; ... s := 'ab'`) compiled and ran to rc 0; fpc -Miso refuses it. The ordinals of two..three are 1..2, and
# the string-type test in pascal.y asked only for a low bound of 1 and a high bound of at least 2, so an enumerated subrange that happens to start at ordinal 1 passed for 1..2. The parser kept a subrange as (name, low, high)
# and a constant as (name, value), so the enumerated origin was invisible by the time the array was built.
# CURE (pascal.y, with Lon's in-chat permission for ONE new parser global, 2026-10-08 ~23:5x CDT, verbatim: "Have your parser global."): g_pas_last_const_enum is set by scalar_constant (1 when the constant is an enumeration member, 0 for every
# other form); the enumeration rule marks its members in the constant table (isenum, a struct member); pas_subtype_add records the flag on the named subrange it registers (isenum, a struct member); the one-dimensional array rule
# takes the index's enum-ness (pas_index_is_enum: the subrange just parsed, or the named subrange) through the same global into the string-type test, which then adds PAS_CA_NOSTR so the 6.4.3.2 diagnostic of PAT 1761-1765 applies.
#
# ARMS, both modes: three fault programs (PAT 1855's named subrange, the same subrange written inline in the array, a subrange of the first two members) must be REFUSED at compile time naming 6.4.3.2 with empty stdout; a control cut LIVE from
# fpc -Miso (a char array indexed by an enumerated subrange used element by element, by the enumeration itself, an integer array over the subrange, a genuine 1..2 string-type assigned a string, a 1..3 one) must run
# byte-identical. FAIL_ONCE=1 corrupts the control's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile or link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/tctl.pas" <<'PAS'
program tctl(output);
type enum = (one, two, three);
     sr   = two..three;
     sri  = 1..2;
     srj  = 1..3;
var s: packed array [sr] of char; t: packed array [sri] of char; u: packed array [1..3] of char; v: packed array [enum] of char;
    w: array [sr] of integer; x: packed array [two..three] of char; c: char;
begin
  s[two] := 'a'; s[three] := 'b'; writeln(s[two], s[three]);
  t := 'xy'; writeln(t);
  u := 'abc'; writeln(u);
  v[one] := 'p'; v[two] := 'q'; v[three] := 'r'; writeln(v[one], v[three]);
  w[two] := 5; w[three] := 6; writeln(w[two] + w[three]);
  x[two] := 'm'; x[three] := 'n'; c := x[three]; writeln(x[two], c)
end.
PAS
cat > "$T/fnamed.pas" <<'PAS'
program fnamed(output);
type enum = (one, two, three);
     sr   = two..three;
var s: packed array [sr] of char;
begin s := 'ab'; writeln('x') end.
PAS
cat > "$T/finline.pas" <<'PAS'
program finline(output);
type enum = (one, two, three);
var s: packed array [two..three] of char;
begin s := 'ab'; writeln('x') end.
PAS
cat > "$T/ffirst.pas" <<'PAS'
program ffirst(output);
type color = (red, green, blue, white);
     two = green..blue;
var s: packed array [two] of char;
begin s := 'cd'; writeln('x') end.
PAS
RC=0; N=0
for p in fnamed finline ffirst; do
  for m in m3 m4; do
    if [ $m = m3 ]; then run m3 $p; rc=$?; else ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); rc=$?; fi; N=$((N + 1))
    if [ "$rc" != 0 ] && [ ! -s "$T/o" ] && grep -q "ISO 7185 6.4.3.2 violation: the variable 's' is given a character-string of 2 characters but is not of a string-type" "$T/e"; then echo "  $p $m: refused naming 6.4.3.2 (rc=$rc)"
    else echo "  ⛔ $p $m FAILED: rc=$rc stdout=[$(head -c 60 "$T/o" | tr '\n' '|')] err=[$(head -c 100 "$T/e")]"; RC=1; fi
  done
done
c=tctl
frc=$(fpcrun $c)
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$c.want"; fi
for m in m3 m4; do run $m $c; rc=$?; N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/$c.want" "$T/o"; then echo "  $c $m: rc=$rc, stdout byte-identical to fpc ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ $c $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$c.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a string-type is indexed by an integer subrange and an enumerated one is refused, the legal forms run as fpc does, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined 4 programs in 2 modes"; fi
exit $RC
