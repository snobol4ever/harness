#!/usr/bin/env bash
# test_gate_pas_two_routines_of_one_name_get_distinct_assembler_labels.sh -- a program that declares two routines with the same name (an
# overload pair differing in result type, or a routine nested inside one of its own name) assembles in mode 4 and runs, as fpc's.
#
# MEASURED 2026-10-04 by hq_pascal on FPC test_tover7 and webtbs_tw24129: mode 3 passed (the duplicate went unnoticed) and mode 4 died in the
# assembler, `symbol FN__test is already defined`, because every graph's labels derive from its routine's bare name.
#
# CURE: lower_pascal_stage2 renames the table entry of a routine whose name an earlier entry already holds to name$dup<index> after its graph is
# lowered, so its labels are distinct; the graph's own body (built before the rename) keeps its result variable. LIMIT, stated and not claimed: a CALL
# still resolves by the bare name to the first routine, so a nested routine that shadows an outer one WITH BODIES still calls the outer one in both modes
# (it called the inner one in mode 3 before) -- scope-correct resolution of shadowed and overloaded names is a separate mechanism (this parser has no
# `overload` directive and keys its routine tables by bare name).
#
# ARMS, both modes, expectations cut LIVE from fpc: (over) the tover7 shape, same scope, differing result types; (nest) the tw24129 shape, a routine
# nested twice inside routines of its own name. FAIL_ONCE=1 corrupts the nest arm's ref.
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

cat > "$T/over.pas" <<'PAS'
{$mode objfpc}
program over(output);
procedure Test(aArg: LongInt);
begin
end;
function Test(aArg: LongInt): LongInt;
begin
  Test := aArg
end;
begin
  writeln('ok')
end.
PAS
cat > "$T/nest.pas" <<'PAS'
{$mode delphi}
program nest(output);
procedure Test;
  function Next: integer;
    function Next: integer;
      function Next: integer;
      var
        Next: integer;
      begin
      end;
    begin
    end;
  begin
  end;
begin
end;
begin
  writeln('ok')
end.
PAS
for p in over nest; do
  frc=$(fpcrun $p)
  if [ "$p" = nest ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: two routines of one name assemble and run as fpc does, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 2 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
