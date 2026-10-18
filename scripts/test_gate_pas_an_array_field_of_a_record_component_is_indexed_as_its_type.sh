#!/usr/bin/env bash
# test_gate_pas_an_array_field_of_a_record_component_is_indexed_as_its_type.sh -- an array field of a record that is itself a
# component (a record field of a record, or an element of an array of records) is indexed as the array it is declared: through a
# record variable, through a pointer, and through an array element, the values stored read back (ISO 7185 6.4.3.3, 6.5.3.2)
# (row pascal-an-array-field-inside-a-nested-record-stores-and-reads-through-different-paths; ceo CEO-1343 from the coo's COO-213)
#
# MEASURED 2026-09-28 by hq_pascal on SCRIP fcae697bb, both modes, against fpc -Miso: nest (o.in1.a[i], the coo's p1) and arrrec
# (v[j].a[i], the coo's p3) stop with a FALSE ISO 7185 6.5.3.2 index error where fpc prints the values; nestptr (the same record
# reached through new) is the row's second path.
#
# ARMS, both modes, stdout and exit code cut LIVE from fpc -Miso: nest, nestptr, arrrec. FAIL_ONCE=1 corrupts nestptr's ref.
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
  if [ "$m" = m3 ]; then ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile and link"; return 125; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/nest.pas" <<'PAS'
program nest(output);
type inner = record a : array[1..3] of integer; n : integer end;
     outer = record k : integer; in1 : inner end;
var o : outer; i : integer;
begin o.k := 7; o.in1.n := 3; for i := 1 to 3 do o.in1.a[i] := i * 10; writeln(o.k, o.in1.n, o.in1.a[1], o.in1.a[3]) end.
PAS
cat > "$T/nestptr.pas" <<'PAS'
program nestptr(output);
type inner = record a : array[1..3] of integer; n : integer end;
     outer = record k : integer; in1 : inner end;
     po = ^outer;
var p : po; i : integer;
begin new(p); p^.k := 7; p^.in1.n := 3; for i := 1 to 3 do p^.in1.a[i] := i * 10;
  writeln(p^.k, p^.in1.n, p^.in1.a[1], p^.in1.a[2], p^.in1.a[3]) end.
PAS
cat > "$T/arrrec.pas" <<'PAS'
program arrrec(output);
type inner = record a : array[1..3] of integer; n : integer end;
var v : array[1..2] of inner; i, j : integer;
begin for j := 1 to 2 do begin v[j].n := j; for i := 1 to 3 do v[j].a[i] := j * 100 + i end;
  for j := 1 to 2 do writeln(v[j].n, v[j].a[1], v[j].a[3]) end.
PAS
for p in nest nestptr arrrec; do
  frc=$(fpcrun $p)
  if [ "$p" = nestptr ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: an array field of a record component is indexed as its type, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 3 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
