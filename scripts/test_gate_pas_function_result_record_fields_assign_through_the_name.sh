#!/usr/bin/env bash
# test_gate_pas_function_result_record_fields_assign_through_the_name.sh -- a function whose RESULT is a record can have its fields assigned through the function name (Mk.s := n; Mk.a[1] := n; with Mk do ...),
# as fpc -Mobjfpc reads it.
#
# MEASURED 2026-10-14 by hq_pascal for PasRosetta (CEO-1562, row pascal-every-suite-to-100-under-nonet-ceo-1266): the target of Mk.s := n
# lowered to __pas_unresolved_target (the function name was not a record variable, so the field select had no layout) and the program died
# 6.5.3.2 at run time; a local record assigned to Mk whole (Mk := x) worked. THE CURE: E_procedure_decl registers the function name as a record
# variable of its result type (pas_recvar_add_from_type) and the body opens with Mk := <the record's initial block>, the same init a local record
# var gets, so the field stores are arr_set_pure updates of the result and the RETURN reads it.
#
# ARMS: recfn -- scalar and static-array fields stored through the name, one of them under an if; recwith -- the same through with Mk do. Both
# modes, stdout and exit code cut LIVE from fpc -Mobjfpc. MEASURED on the parent (cure stashed): recfn died on a TE-4 BOMB (rc 134) and recwith died 6.5.3.2, red in both modes.
# FAIL_ONCE=1 corrupts recfn's expectation.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile and link"; return 125; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { local mode="$2"; mkdir -p "$T/fpc"; ( cd "$T" && "$FPC" $mode -v0 -FE"$T/fpc" -o"$T/$1.fpc" "$T/$1.pas" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc $mode would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s "./$1.fpc" </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/recfn.pas" <<'PAS'
program recfn;
{$mode objfpc}
type tr = record s: integer; a: array[0..3] of integer end;
function Mk(n: integer): tr;
begin
  Mk.s := n;
  Mk.a[3] := n * 3;
  if n > 4 then Mk.a[0] := 99
end;
var r: tr;
begin
  r := Mk(7);
  writeln(r.s, ' ', r.a[3], ' ', r.a[0])
end.
PAS
cat > "$T/recwith.pas" <<'PAS'
program recwith;
{$mode objfpc}
type tr = record s: integer; a: array[0..3] of integer end;
function Mk(n: integer): tr;
begin
  with Mk do begin s := n; a[2] := n + 1 end
end;
var r: tr;
begin
  r := Mk(5);
  writeln(r.s, ' ', r.a[2])
end.
PAS
for pm in "recfn -Mobjfpc" "recwith -Mobjfpc"; do p=${pm% *}; om=${pm#* }
  frc=$(fpcrun $p $om) || exit 2
  if [ -n "${FAIL_ONCE:-}" ] && [ "$p" = recfn ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc $om ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: record fields assigned through the function name, as fpc reads them, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined two programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
