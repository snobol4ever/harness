#!/usr/bin/env bash
# test_gate_pas_an_array_element_is_not_fetched_by_a_builtin_looked_up_by_its_name.sh -- the Pascal lowerer emits a[i] as the call arr_get and a[i] := v as the call arr_set_pure.
#
# MEASURED 2026-10-09 by hq_pascal on the eight Pascal benchmark kernels (bubble intmm perm queens quick sieve towers whet), mode 4 asm: 130 call sites (84 arr_get, 46 arr_set_pure) carried the
# builtin's NAME as a string operand to rt_call_arr_bl, which resolved it by strcmp against the builtin table on every element access (callgrind, CEO-1282: __strcmp_avx2 46-52 percent of the
# instructions of queens, bubble, sieve and whet). CURE: dop_direct_fp (bb_call.cpp) answers arr_get with rt_pas_arr_get and arr_set_pure with rt_pas_arr_set, the two C functions the by-name arms
# now call, so bb_call_fn's direct-leaf arm calls the function itself and the asm carries no name.
#
# ARMS: (1) the row's own census, the eight kernels compiled to asm in mode 4, zero by-name array calls (arr_get, arr_set_pure, arr_set, iand as string names); (2) in BOTH modes a control program
# cut LIVE from fpc -Miso that reads and writes integer, negative-low-bound, boolean, enumerated, character and two-dimensional arrays, an array of records, an array passed whole to a var and to
# a value formal, and a packed array of char element write, byte-identical to the oracle. FAIL_ONCE=1 corrupts the control's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- the control's expectation is CUT FROM THE ORACLE"; exit 2; }
CORPUS="${CORPUS_DIR:-$ROOT/../corpus}"; KD="$CORPUS/benchmarks/pascal"; [ -d "$KD" ] || { echo "⛔ GATE REFUSE(2) [$G]: no kernel directory at $KD"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0; SITES=0
for k in bubble intmm perm queens quick sieve towers whet; do
  [ -f "$KD/$k.pas" ] || { echo "⛔ GATE REFUSE(2) [$G]: no kernel $KD/$k.pas"; exit 2; }
  ( cd "$T" && timeout -k 5 120s "$SCRIP" --compile -o "$k.s" "$KD/$k.pas" </dev/null >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: kernel $k did not compile to asm"; exit 2; }
  c=$(grep -c '"arr_get"\|"arr_set_pure"\|"arr_set"\|"iand"' "$T/$k.s"); N=$((N + 1)); SITES=$((SITES + c))
  if [ "$c" = 0 ]; then echo "  $k: no by-name array call in the asm"; else echo "  ⛔ $k: $c by-name array call sites in the asm"; RC=1; fi
done
cat > "$T/ctl.pas" <<'PAS'
program ctl(output);
type color = (red, green, blue);
     rec = record a: integer; b: char end;
     grid = array[1..3, 1..4] of integer; vec = array[1..6] of integer;
var i, j, n: integer; a: vec; neg: array[-3..3] of integer; flags: array[0..9] of boolean; hue: array[color] of integer; cs: array['a'..'e'] of integer;
    g: grid; rs: array[1..3] of rec; word: packed array[1..5] of char; en: array[1..3] of color;
procedure fill(var x: vec); var k: integer; begin for k := 1 to 6 do x[k] := k * 7 end;
function total(x: vec): integer; var k, s: integer; begin s := 0; for k := 1 to 6 do s := s + x[k]; x[1] := 0; total := s end;
begin
  for i := 1 to 6 do a[i] := i * i; n := 0; for i := 1 to 6 do n := n + a[i]; writeln(n);
  for i := -3 to 3 do neg[i] := i * 10; for i := -3 to 3 do write(neg[i], ' '); writeln;
  for i := 0 to 9 do flags[i] := odd(i); for i := 0 to 9 do write(flags[i], ' '); writeln;
  hue[red] := 100; hue[green] := 101; hue[blue] := 102; writeln(hue[red], ' ', hue[green], ' ', hue[blue]);
  cs['a'] := 1; cs['e'] := 5; writeln(cs['a'] + cs['e']);
  for i := 1 to 3 do for j := 1 to 4 do g[i, j] := i * 10 + j; writeln(g[2, 3], ' ', g[3, 4], ' ', g[1, 1]);
  for i := 1 to 3 do begin rs[i].a := i; rs[i].b := chr(ord('p') + i) end; writeln(rs[2].a, rs[3].b);
  fill(a); writeln(a[1], ' ', a[6]); writeln(total(a), ' ', a[1]);
  word := 'hello'; word[1] := 'J'; word[5] := 'y'; writeln(word, ' ', word[2]);
  en[1] := blue; en[2] := green; en[3] := red; writeln(ord(en[1]), ord(en[2]), ord(en[3]));
  a[a[1] div 7 + 1] := 99; writeln(a[2], ' ', a[a[2] - 94])
end.
PAS
if ! ( cd "$T" && "$FPC" -Miso -v0 -octl.fpc ctl.pas >/dev/null 2>&1 ); then echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile the control"; exit 2; fi
( cd "$T" && timeout -k 5 20s ./ctl.fpc </dev/null >"$T/ctl.want" 2>/dev/null ); frc=$?
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/ctl.want"; fi
for m in m3 m4; do
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run ctl.pas </dev/null >"$T/o" 2>"$T/e" ); rc=$?
  else
    ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o ctl.s ctl.pas </dev/null >/dev/null 2>&1 && cc -m64 -no-pie ctl.s -o ctl.m4 -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ ctl m4 did not compile or link"; RC=1; continue; }
    ( cd "$T" && timeout -k 5 20s ./ctl.m4 </dev/null >"$T/o" 2>"$T/e" ); rc=$?
  fi
  N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/ctl.want" "$T/o"; then echo "  ctl $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ ctl $m FAILED: rc=$rc (fpc $frc)"; diff "$T/ctl.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: the eight kernels' asm carries no by-name array call and the control runs as fpc in both modes, $N of $N arms"
else echo "GATE FAIL(1) [$G]: $SITES by-name array call sites across the kernels, or the control differs from fpc -Miso"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
