#!/usr/bin/env bash
# test_gate_pas_an_array_of_records_held_as_a_record_field_compiles_and_runs.sh -- a record field whose type is an array of records
# (o.arr[j].a[i], o.arr[j].n) compiles, runs and prints what fpc -Miso prints, in both modes -- no BOMB
# (the CRASH row minted by hq_pascal on ceo CEO-1343 from the coo's COO-213 witness p2)
#
# MEASURED 2026-09-28 by hq_pascal on SCRIP fcae697bb, both modes: fldarr (the coo's p2) ABORTS rc 134 with
# "BOMB -- bb_call marshal: IR_VAR arg names a local with no LOWER-granted varslot"; fpc -Miso prints two lines.
#
# ARMS, both modes, stdout and exit code cut LIVE from fpc -Miso: fldarr, fldarrptr (the same record reached through new).
# FAIL_ONCE=1 corrupts fldarrptr's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
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
cat > "$T/fldarr.pas" <<'PAS'
program fldarr(output);
type inner = record a : array[1..3] of integer; n : integer end;
     outer = record k : integer; arr : array[1..2] of inner end;
var o : outer; i, j : integer;
begin for j := 1 to 2 do begin o.arr[j].n := j; for i := 1 to 3 do o.arr[j].a[i] := j * 100 + i end;
  for j := 1 to 2 do writeln(o.arr[j].n, o.arr[j].a[1], o.arr[j].a[3]) end.
PAS
cat > "$T/fldarrptr.pas" <<'PAS'
program fldarrptr(output);
type inner = record a : array[1..3] of integer; n : integer end;
     outer = record k : integer; arr : array[1..2] of inner end;
     po = ^outer;
var p : po; i, j : integer;
begin new(p); p^.k := 9; for j := 1 to 2 do begin p^.arr[j].n := j; for i := 1 to 3 do p^.arr[j].a[i] := j * 100 + i end;
  for j := 1 to 2 do writeln(p^.k, p^.arr[j].n, p^.arr[j].a[1], p^.arr[j].a[2], p^.arr[j].a[3]) end.
PAS
for p in fldarr fldarrptr; do
  frc=$(fpcrun $p)
  if [ "$p" = fldarrptr ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: an array of records held as a record field compiles and runs, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 2 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
