#!/usr/bin/env bash
# test_gate_pas_a_program_using_a_unit_keeps_its_typed_constants_and_fpc_rounds_halves_to_even.sh -- (1) a program that `uses` a unit
# keeps its own const / type / var parts in SOURCE order, so a typed record constant sees its record type; (2) Min and Max of real
# arguments answer as reals; (3) round of a half goes to the even integer in the FPC dialects and away from zero in ISO.
#
# MEASURED 2026-10-14 by hq_pascal for PasRosetta's empty-output class (ceo CEO-1709): knapsack-problem-unbounded (uses math, const
# sack: bounty = (...)) died "FATAL emit_drive: IR op=4 ... REFUSED AT A GUARD": pas_flatten_units merged EVERY const part ahead of EVERY
# type part, so the typed record constant was lowered before its type existed (its initialisers assigned __pas_unresolved_target and
# sack.weight read 0); min(real, real) hit the integer-only math Min ("actual-parameter 1 of 'min' is a real value"); and round(22.5)
# gave 23 where fpc -Mfpc / -Mobjfpc / -Mdelphi give 22 (half to even) and fpc -Miso gives 23.
# THE CURE (lower_pascal_tree.c): pas_flatten_units merges only the UNITS' parts and appends the program's own const / type / var parts in
# their source order after them; math.pas gains FpcMaxDouble / FpcMinDouble and E_call_with_args renames max / min to them when an argument
# is a real expression and the math unit is present (pas_expr_is_real) -- SCRIP has no overload resolution, so same-named routines would
# redefine each other; round lowers to the new __pas_rounde (rint, half to even) when pas_dialect_fpc holds.
# OPEN, NOT GRADED HERE: real overload resolution (pascal.y also rejects overload / inline directives on a unit interface header).
#
# ARMS: unitprog and roundfpc against fpc -Mobjfpc, roundiso against fpc -Miso, both modes, cut LIVE. MEASURED on the parent (in-tree
# swap): unitprog and roundfpc red, roundiso green (the guard). FAIL_ONCE=1 corrupts unitprog.
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
cat > "$T/unitprog.pas" <<'PAS'
program unitprog;
{$mode objfpc}
uses math, sysutils;
type
  bounty = record value: longint; weight, volume: real; tags: string end;
  tpair = record lo, hi: integer end;
const
  limit = 3;
  panacea: bounty = (value: 3000; weight: 0.3; volume: 0.025; tags: 'p');
  sack: bounty = (value: 7; weight: 25.0; volume: 0.25; tags: 'sack');
  span: tpair = (lo: 2; hi: limit * 2);
  names: array [1..limit] of string = ('a', 'bb', 'ccc');
var
  x: longint; r: real; i: integer;
begin
  x := round(min(sack.weight / panacea.weight, sack.volume / 0.025));
  r := sack.weight / panacea.weight;
  writeln(x, ' ', r:0:3, ' ', sack.value, ' ', sack.tags, ' ', panacea.tags, ' ', span.lo, ' ', span.hi);
  for i := 1 to limit do write(names[i], length(names[i]), ' ');
  writeln(max(span.lo, span.hi), ' ', min(0.5, r) :0:2, ' ', round(max(1.5, 2.25) * 10))
end.
PAS
cat > "$T/roundfpc.pas" <<'PAS'
program roundfpc;
{$mode objfpc}
var r: real;
begin r := 0.5; write(round(r), ' '); r := 1.5; write(round(r), ' '); r := 2.5; write(round(r), ' '); r := 3.5; write(round(r), ' '); r := -2.5; write(round(r), ' '); r := -0.5; write(round(r), ' '); r := 22.5; write(round(r)); writeln end.
PAS
cat > "$T/roundiso.pas" <<'PAS'
program roundiso(output);
var r: real;
begin r := 0.5; write(round(r), ' '); r := 1.5; write(round(r), ' '); r := 2.5; write(round(r), ' '); r := 3.5; write(round(r), ' '); r := -2.5; write(round(r), ' '); r := -0.5; write(round(r), ' '); r := 22.5; write(round(r)); writeln end.
PAS
for pm in "unitprog -Mobjfpc" "roundfpc -Mobjfpc" "roundiso -Miso"; do p=${pm% *}; om=${pm#* }
  frc=$(fpcrun $p $om) || exit 2
  if [ -n "${FAIL_ONCE:-}" ] && [ "$p" = unitprog ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc $om ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a unit-using program keeps its typed constants, real min/max answer as reals and round goes half to even in the FPC dialects, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined three programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
