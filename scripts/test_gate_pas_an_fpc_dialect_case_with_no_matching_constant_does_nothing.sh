#!/usr/bin/env bash
# test_gate_pas_an_fpc_dialect_case_with_no_matching_constant_does_nothing.sh -- in the FPC dialects a case-statement whose index
# matches no constant and that has no else runs no arm and goes on, as fpc does; the ISO 7185 6.8.3.5 runtime error binds the ISO
# dialect only (CEO-1657), where test_gate_pas_a_case_statement_with_no_matching_constant_is_an_error.sh keeps it.
#
# MEASURED 2026-10-14 by hq_pascal for PasRosetta (CEO-1562, row pascal-every-suite-to-100-under-nonet-ceo-1266): box-the-compass
# (ALL.dialect fpc-default: its string array flips it) stopped at its first unmatched case with "pascal runtime error: ISO 7185
# 6.8.3.5" where fpc goes on. The case chain's tail was __pas_rterr in every dialect. THE CURE (lower_pascal_tree.c): the tail is a
# TT_SUCCEED when pas_dialect_fpc holds (the whole program's dialect) and the 6.8.3.5 call otherwise.
#
# ARMS: fpccase (flipped by a string declaration: integer and char case-indexes, constant lists and ranges, no arm matching) against
# fpc -Mfpc, objcase ({$mode objfpc}, an enumerated and an integer index) against fpc -Mobjfpc, both modes, stdout and exit code cut
# LIVE. MEASURED on the parent 9924a117a: both red (rc 1, the 6.8.3.5 diagnostic). FAIL_ONCE=1 corrupts fpccase's expectation.
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
cat > "$T/fpccase.pas" <<'PAS'
program fpccase(output);
var i, n: integer; s: string; c: char;
begin
  s := 'x'; n := 0;
  for i := 0 to 7 do
  begin
    case i mod 4 of 1: n := n + 1; 2: n := n + 10 end;
    case i of 3, 5: write('[', i, ']') end
  end;
  c := 'q'; case c of 'a': writeln('a'); 'b'..'d': writeln('bd') end;
  writeln(n, ' ', s)
end.
PAS
cat > "$T/objcase.pas" <<'PAS'
program objcase;
{$mode objfpc}
type colour = (red, green, blue);
var k: colour; t: integer;
begin
  t := 0;
  for k := red to blue do case k of green: t := t + 5 end;
  case t of 1..4: writeln('low') end;
  writeln(t)
end.
PAS
for pm in "fpccase -Mfpc" "objcase -Mobjfpc"; do p=${pm% *}; om=${pm#* }
  frc=$(fpcrun $p $om) || exit 2
  if [ -n "${FAIL_ONCE:-}" ] && [ "$p" = fpccase ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc $om ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: an FPC-dialect case with no matching constant runs no arm and goes on, as fpc does, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined two programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
