#!/usr/bin/env bash
# test_gate_pas_an_iso_call_to_an_fpc_system_routine_is_refused_at_compile_time.sh -- in an ISO program a procedure statement or a
# function call naming randomize, random or stringofchar (FPC System routines ISO 7185 does not define) is refused with 6.2.2.1 when
# the program declares no routine of that name; a program that declares its own random runs as fpc -Miso runs it; the FPC dialects
# keep the routines.
#
# MEASURED 2026-10-14 by hq_pascal for PasRosetta's ISO-dialect programs (ceo CEO-1709; ISO_EXPECTED_REFUSALS, CEO-1228 and CEO-1657):
# the bare identifier random was refused with 6.2.2.1 (test_units_system_trandom is listed for it) but a CALL -- random(5), randomize; --
# only died at run time as "error 22: undefined function called", so guess-the-number, penneys-game, random-latin-squares and
# sorting-algorithms-comb-sort-1 / -2 (dialect iso, fpc -Miso compiles each rc=0) were neither refused nor run. The older gap
# test_gate_pas_fpc_system_and_math_routines_answer_as_fpc_and_stay_refused_in_iso.sh recorded and did not widen. THE CURE
# (lower_pascal_tree.c): mk_call calls pas_scope_require on those three names when pas_dialect_fpc does not hold and no routine or
# variable of the name is known, so the ISO diagnostic is the compile-time one for every spelling.
#
# ARMS: isorandcall and isorandomize are each REFUSED in BOTH modes (rc != 0, empty stdout, 6.2.2.1 on stderr; m4 refuses at --compile);
# isoown (a user function named random in an ISO program) runs byte-identical to fpc -Miso in both modes. MEASURED on the parent
# (in-tree swap): both refusals read a run-time "undefined function". FAIL_ONCE=1 corrupts isoown.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
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
cat > "$T/isorandcall.pas" <<'PAS'
program isorandcall(output);
var i: integer;
begin i := random(5); writeln(i >= 0) end.
PAS
cat > "$T/isorandomize.pas" <<'PAS'
program isorandomize(output);
begin randomize; writeln(1) end.
PAS
cat > "$T/isoown.pas" <<'PAS'
program isoown(output);
var i: integer;
function random(n: integer): integer; begin random := n * 3 + 1 end;
procedure randomize; begin writeln('seeded') end;
begin randomize; i := random(4); writeln(i, ' ', random(0))  end.
PAS
RC=0; N=0
refuse() { local m="$1" p="$2"; N=$((N + 1))
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); else ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); fi; local rc=$?
  if [ "$rc" != 0 ] && [ ! -s "$T/o" ] && grep -q '6\.2\.2\.1' "$T/e"; then echo "  $p $m: refused, rc=$rc, with: $(head -1 "$T/e" | cut -c1-80)"
  else echo "  ⛔ $p $m FAILED: rc=$rc, want a 6.2.2.1 refusal: stdout=[$(head -c 60 "$T/o" | tr '\n' '|')] err=[$(head -c 140 "$T/e")]"; RC=1; fi; }
for m in m3 m4; do refuse $m isorandcall; refuse $m isorandomize; done
frc=$(fpcrun isoown -Miso) || exit 2
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/isoown.want"; fi
for m in m3 m4; do run $m isoown; rc=$?; N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/isoown.want" "$T/o"; then echo "  isoown $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ isoown $m FAILED: rc=$rc (fpc $frc)"; diff "$T/isoown.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: an ISO call to randomize / random / stringofchar is refused at compile time and a user's own random runs, $N of $N arms"
else echo "GATE FAIL(1) [$G]: see the arms above"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
