#!/usr/bin/env bash
# test_gate_pas_a_real_value_parameter_is_assignable_inside_its_procedure.sh -- a procedure or function may assign to its own value parameter of
# type real (ISO 7185 6.6.3.2: the formal is a local variable initialised from the actual), and the caller's variable is unchanged.
# MEASURED 2026-10-09 by hq_pascal on the Star Trek demo (CEO-1579): the traced run died after "Warp factor" with
# "[IDX] BOMB rt_assign_var: lvalue is not a variable (dtype=5)", the last statement `warp := warp - 0.125` in a nested procedure whose value
# parameter is real. Minimised: procedure inner(w: real); begin w := w - 0.125 end -- integer value parameters were fine.
# CAUSE: mk_proc built the procedure's by-reference mask from every parameter node that carries a child, and the elaborator marks a REAL value
# parameter with a TT_FLIT child (and a pchar one with a TT_QLIT child) for the callers' coercion tables; the mask therefore called a real value
# parameter by-reference, the lowerer emitted ASSIGN_VAR through it, and the caller had passed a value. CURE (lower_pascal_tree.c, mk_proc): only
# a TT_SUCCEED child (the var marker pas_vparam_scan reads) makes a parameter by-reference.
# ARMS, both modes, expected stdout and exit code cut LIVE from fpc -Miso: (1) toplevel -- the minimal witness; (2) nested -- a nested procedure
# whose real value parameter shadows the enclosing procedure's local and whose var parameter shadows another, the Star Trek shape; (3) caller -- the
# caller's actual is unchanged after the callee assigns its copy, and a function result built from the modified copy. FAIL_ONCE=1 corrupts arm 3's ref.
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
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile or link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/toplevel.pas" <<'PAS'
program toplevel(output);
procedure inner(w: real);
begin w := w - 0.125; writeln(w:6:3) end;
begin inner(0.5) end.
PAS
cat > "$T/nested.pas" <<'PAS'
program nested(output);
procedure outer;
var warp: real; xp: real; course: integer;
  procedure inner(var xp: real; course: integer; warp: real);
  begin
    while warp >= 0.125 do begin xp := xp + 1.0; warp := warp - 0.125 end
  end;
begin
  xp := 0; warp := 0.5; course := 3;
  inner(xp, course, warp);
  writeln(xp:6:2, warp:6:2)
end;
begin outer end.
PAS
cat > "$T/caller.pas" <<'PAS'
program caller(output);
var a: real;
function half(x: real): real;
begin x := x / 2.0; half := x + 1.0 end;
procedure bump(r: real; k: integer);
begin r := r + k; k := k * 2; writeln(r:6:2, k:3) end;
begin
  a := 3.0;
  writeln(half(a):6:2, a:6:2);
  bump(a, 4);
  writeln(a:6:2)
end.
PAS
for p in toplevel nested caller; do
  frc=$(fpcrun $p)
  if [ "$p" = caller ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a real value parameter is assigned inside its procedure and the caller keeps its value, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 3 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
