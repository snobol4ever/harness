#!/usr/bin/env bash
# test_gate_pas_an_array_element_is_one_guarded_load_or_store_in_the_emitted_code.sh -- Pascal's a[i] and a[i] := v are emitted as a guard and one indexed load or store, with the direct call kept as the cold path.
#
# MEASURED 2026-10-09 by hq_pascal on the sieve kernel (callgrind, mode 4, 20 repetitions): with arr_get and arr_set_pure as direct calls (SCRIP 5686eb4ab) the element access was still 44 percent of the
# instructions: the operands marshalled into an argument block, the call, the -O0 C leaf (about 80 instructions for a store), the result copied back. CURE: bb_call_pas_elem.cpp emits, for arr_get (2 operands) and
# arr_set_pure (3), the whole access inline -- the base descriptor is an array block (DT_A), the index an integer (DT_I), lo <= index <= hi, then data[index - lo] read or written -- reading the operands IN PLACE
# from their slots under ZD and from the argument slots on the flat road; anything else (a character array held as a byte string, an index of another type) falls to the direct call, and an index outside the
# bounds is the same DT_FAIL that reaches the 6.5.3.2 stop. The classifier is pas_elem_kind in emit.cpp; SCRIP_PAS_ELEM=0 turns the arm off, which is how this gate grades the cold path.
#
# ARMS: (1) the census, the eight kernels compiled to mode-4 asm: the inline sites (the data-vector load through rsi+32 that only the arm emits) equal the cold-path calls of pas_arr_get and pas_arr_set, and
# there is at least one in every kernel but towers (which has no array); (2) in BOTH modes a control of integer, negative-bound, Boolean, enumerated-index, character-index, two-dimensional, array-of-record, real,
# set-element and character-array elements, cut LIVE from fpc -Miso, run with the arm on and with SCRIP_PAS_ELEM=0, all three byte-identical; (3) an element read and an element write outside the index type each
# stop with 6.5.3.2 after printing `before`, with the arm on, in both modes. FAIL_ONCE=1 corrupts the control's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- the control's expectation is CUT FROM THE ORACLE"; exit 2; }
CORPUS="${CORPUS_DIR:-$ROOT/../corpus}"; KD="$CORPUS/benchmarks/pascal"; [ -d "$KD" ] || { echo "⛔ GATE REFUSE(2) [$G]: no kernel directory at $KD"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
for k in bubble intmm perm queens quick sieve towers whet; do
  [ -f "$KD/$k.pas" ] || { echo "⛔ GATE REFUSE(2) [$G]: no kernel $KD/$k.pas"; exit 2; }
  ( cd "$T" && timeout -k 5 120s "$SCRIP" --compile -o "$k.s" "$KD/$k.pas" </dev/null >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: kernel $k did not compile to asm"; exit 2; }
  inl=$(grep -cE 'mov +rdx, qword ptr \[rsi \+ 32\]' "$T/$k.s"); cold=$(grep -cE 'call +pas_arr_(get|set)@PLT' "$T/$k.s"); N=$((N + 1))
  if [ "$inl" = "$cold" ] && { [ "$inl" -gt 0 ] || [ "$k" = towers ]; }; then echo "  $k: $inl inline element sites, $cold cold-path calls"; else echo "  ⛔ $k: $inl inline element sites against $cold cold-path calls"; RC=1; fi
done
cat > "$T/ctl.pas" <<'PAS'
program ctl(output);
type color = (red, green, blue);
     rec = record a: integer; b: char end;
var i, j, n: integer; a: array[1..6] of integer; neg: array[-3..3] of integer; flags: array[0..9] of boolean; hue: array[color] of integer; cs: array['a'..'e'] of integer;
    g: array[1..3, 1..4] of integer; rs: array[1..3] of rec; r: array[1..4] of real; sets: array[1..3] of set of 0..9; word: packed array[1..5] of char; chars: array[1..4] of char; big: array[1..200] of integer;
function twice(x: integer): integer; begin twice := x * 2 end;
begin
  for i := 1 to 6 do a[i] := i * i; n := 0; for i := 1 to 6 do n := n + a[i]; writeln(n);
  for i := -3 to 3 do neg[i] := i * 10; for i := -3 to 3 do write(neg[i], ' '); writeln;
  for i := 0 to 9 do flags[i] := odd(i); for i := 0 to 9 do write(flags[i], ' '); writeln;
  hue[red] := 100; hue[green] := 101; hue[blue] := 102; writeln(hue[red] + hue[blue]);
  cs['a'] := 1; cs['e'] := 5; writeln(cs['a'] + cs['e']);
  for i := 1 to 3 do for j := 1 to 4 do g[i, j] := i * 10 + j; writeln(g[2, 3], ' ', g[3, 4], ' ', g[1, 1]);
  for i := 1 to 3 do begin rs[i].a := i; rs[i].b := chr(ord('p') + i) end; writeln(rs[2].a, rs[3].b);
  for i := 1 to 4 do r[i] := i / 4; writeln(r[1]:0:2, ' ', r[4]:0:2);
  for i := 1 to 3 do sets[i] := [i, i + 3]; writeln(5 in sets[2], ' ', 2 in sets[2]);
  word := 'hello'; word[1] := 'J'; word[5] := 'y'; writeln(word, ' ', word[2]);
  for i := 1 to 4 do chars[i] := chr(ord('a') + i); writeln(chars[1], chars[4]);
  for i := 1 to 200 do big[i] := twice(i); n := 0; for i := 1 to 200 do n := n + big[twice(i) div 2]; writeln(n);
  a[a[1] + 1] := 99; writeln(a[2], ' ', a[a[2] - 94])
end.
PAS
cat > "$T/oorr.pas" <<'PAS'
program oorr(output);
var a: array[1..4] of integer; x: integer;
begin a[1] := 1; writeln('before'); x := a[9]; writeln('after') end.
PAS
cat > "$T/oorw.pas" <<'PAS'
program oorw(output);
var a: array[1..4] of integer;
begin a[1] := 1; writeln('before'); a[0] := 5; writeln('after') end.
PAS
if ! ( cd "$T" && "$FPC" -Miso -v0 -octl.fpc ctl.pas >/dev/null 2>&1 ); then echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile the control"; exit 2; fi
( cd "$T" && timeout -k 5 20s ./ctl.fpc </dev/null >"$T/ctl.want" 2>/dev/null ); frc=$?
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/ctl.want"; fi
runm() { local m="$1" p="$2" e="$3"
  if [ "$m" = m3 ]; then ( cd "$T" && SCRIP_PAS_ELEM=$e timeout -k 5 60s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && SCRIP_PAS_ELEM=$e timeout -k 5 60s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || return 99
  ( cd "$T" && timeout -k 5 60s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
for m in m3 m4; do for e in 1 0; do runm $m ctl $e; rc=$?; N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/ctl.want" "$T/o"; then echo "  ctl $m arm=$e: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ ctl $m arm=$e FAILED: rc=$rc (fpc $frc)"; diff "$T/ctl.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi
done; done
for p in oorr oorw; do for m in m3 m4; do runm $m $p 1; rc=$?; N=$((N + 1))
  if [ "$rc" != 0 ] && [ "$(cat "$T/o")" = before ] && grep -q 6.5.3.2 "$T/e"; then echo "  $p $m: stopped with 6.5.3.2 after printing before (rc=$rc)"
  else echo "  ⛔ $p $m FAILED: rc=$rc stdout=[$(head -c 60 "$T/o" | tr '\n' '|')] err=[$(head -c 100 "$T/e")]"; RC=1; fi
done; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: an array element is one guarded load or store with the call as its cold path, byte-identical to fpc with the arm on and off in both modes, $N of $N arms"
else echo "GATE FAIL(1) [$G]: the inline element arm is missing from the asm, or it differs from the cold path or from fpc -Miso"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
