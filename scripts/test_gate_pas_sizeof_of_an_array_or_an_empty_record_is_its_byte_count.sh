#!/usr/bin/env bash
# test_gate_pas_sizeof_of_an_array_or_an_empty_record_is_its_byte_count.sh -- sizeof(x) of an array variable or type, of an
# empty record type or variable, and of a record or array whose component is one of those, answers as fpc does.
#
# MEASURED 2026-10-03 by hq_pascal, row pascal-every-suite-to-100-under-nonet-ceo-1266. Every sizeof of an array variable, an
# array type, an empty record or a variable of one died at run time with `scrip: error 22: Undefined function called`: pascal.y's
# sizeof arm folded only scalars and records with fields, and the array table never held an element size. FPC test_tprec11
# (sizeof of an array of an empty packed record, and of the empty record) was red on it.
#
# CURE: pascal.y carries the byte size of the type just parsed (g_pas_pend_esz, set by an identifier type, a subrange, an
# empty record, and an array as count * element size) and a name -> bytes table (pas_tsz_add / pas_tsz_get) that a type
# declaration and a variable declaration fill; pas_sizeof_lookup consults it last, so every size it answered before is
# unchanged. A two-dimensional array and an inline enumerated or record element stay UNKNOWN (undefined, as before) rather than
# guessed. pack/unpack no longer refuses a source array whose components are zero bytes (6.6.5.4: there is no value to be
# undefined).
#
# ARMS, both modes, each program's expected stdout and exit code cut LIVE from fpc: (arr) one-dimensional arrays of scalars,
# subranges, a named array type, an array of an array; (rec) arrays of a named and a packed record; (empty) the empty record
# type, a variable of it, a packed record holding one, and an array of that. FAIL_ONCE=1 corrupts the empty arm's ref.
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

cat > "$T/arr.pas" <<'PAS'
{$mode objfpc}
program arr(output);
type small = 0..9; wide = 0..1000; neg = -5..5; vec = array[1..4] of longint;
var a: array[0..15] of longint; b: array[1..7] of byte; c: packed array[0..3] of char; d: array[1..3] of word;
    e: array[1..5] of small; f: array[0..3] of wide; g: array[1..6] of neg; v: vec; m: array[2..4] of array[1..5] of word;
    n: array[1..3] of vec; q: array[0..9] of boolean;
begin
  writeln(sizeof(a), ' ', sizeof(b), ' ', sizeof(c), ' ', sizeof(d), ' ', sizeof(e), ' ', sizeof(f), ' ', sizeof(g));
  writeln(sizeof(v), ' ', sizeof(vec), ' ', sizeof(m), ' ', sizeof(n), ' ', sizeof(q))
end.
PAS
cat > "$T/rec.pas" <<'PAS'
{$mode objfpc}
program rec(output);
type t2 = record a: byte; b: longint; end;
     tpk = packed record a: byte; b: longint; end;
     arr3 = array[1..3] of t2;
var x: array[1..3] of t2; y: array[0..4] of tpk; z: arr3; w: array[1..2] of arr3;
begin
  writeln(sizeof(t2), ' ', sizeof(tpk), ' ', sizeof(x), ' ', sizeof(y), ' ', sizeof(z), ' ', sizeof(arr3), ' ', sizeof(w))
end.
PAS
cat > "$T/empty.pas" <<'PAS'
{$mode macpas}
program empty(output);
type tr = record end;
     tp = packed record i: tr; end;
var e: tr; p: tp; a: array[0..15] of tp; pa: packed array[0..15] of tp; b: array[1..3] of tr;
begin
  pack(a, 0, pa);
  writeln(sizeof(tr), ' ', sizeof(e), ' ', sizeof(tp), ' ', sizeof(p), ' ', sizeof(a), ' ', sizeof(pa), ' ', sizeof(b))
end.
PAS
for p in arr rec empty; do
  frc=$(fpcrun $p)
  if [ "$p" = empty ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: sizeof of an array or an empty record answers as fpc does, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 3 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
