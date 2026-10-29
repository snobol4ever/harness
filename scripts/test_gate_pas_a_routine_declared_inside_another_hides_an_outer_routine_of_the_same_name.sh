#!/usr/bin/env bash
# test_gate_pas_a_routine_declared_inside_another_hides_an_outer_routine_of_the_same_name.sh -- ISO 7185 6.2.2: a procedure or function declared inside
# another hides an enclosing routine of the same name for the rest of its region, whatever its parameter list (Pascal-S has an outer enter with five
# parameters and an inner enter with two). MEASURED 2026-10-09 by hq_pascal on the Pascal-S demo (ceo CEO-1579): the run died after six listing lines with
# "libscrip_rt: BOMB -- bb_call_proc_staged: a block-protocol callee is called with the wrong argument count"; reduced to a nine-line program.
# CAUSE: the call resolves its callee by NAME in the procedure table, which finds the outer routine first (a same-arity shadow would have called the wrong
# routine silently). CURE (lower_pascal_tree.c): a routine declared at a deeper scope level than a visible routine of its name gets a unique name (name$N) in the
# tables, mk_proc and the emitted procedure, and a scoped alias definition (PasDef.alias, popped with the scope) makes every call, bare identifier and result
# assignment in its region resolve to it; a forward-declared shadow keeps one name for its body.
# ARMS, both modes, cut LIVE from fpc -Miso: (1) arity -- the minimal witness; (2) samearity -- the same arity, which called the outer routine silently; (3) nesting
# -- siblings with their own helper, a function that shadows an outer function and recurses through its own name, and a helper three levels down.
# FAIL_ONCE=1 corrupts arm 3's ref.
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
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile or link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/arity.pas" <<'PAS'
program arity(output);
var t: integer;
procedure enter(x0: integer; x1: integer; x2: integer);
begin t := t + x0 + x1 + x2 end;
procedure block;
  procedure enter(id: integer);
  begin t := t + id end;
begin enter(5); writeln(t) end;
begin t := 0; enter(1, 2, 3); block; writeln(t) end.
PAS
cat > "$T/samearity.pas" <<'PAS'
program samearity(output);
var t: integer;
procedure bump(n: integer);
begin t := t + n end;
procedure inner;
  procedure bump(n: integer);
  begin t := t + 100 * n end;
begin bump(2) end;
begin t := 0; bump(1); inner; bump(3); writeln(t) end.
PAS
cat > "$T/nesting.pas" <<'PAS'
program nesting(output);
var t: integer;
procedure helper(n: integer);
begin t := t + n end;
function sq(n: integer): integer;
begin sq := n * n end;
procedure a;
  procedure helper(n: integer);
  begin t := t + 100 * n end;
  function sq(n: integer): integer;
  begin if n <= 1 then sq := 1 else sq := n + sq(n - 1) end;
begin helper(2); writeln(t, ' ', sq(4)) end;
procedure b;
  procedure helper(n: integer);
  begin t := t + 1000 * n end;
  procedure deeper;
    procedure helper(n: integer);
    begin t := t + 10000 * n end;
  begin helper(1) end;
begin helper(3); deeper; helper(1); writeln(t) end;
begin
  t := 0;
  helper(1); writeln(t, ' ', sq(3));
  a; b;
  helper(5); writeln(t, ' ', sq(5))
end.
PAS
for p in arity samearity nesting; do
  frc=$(fpcrun $p)
  if [ "$p" = nesting ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a routine declared inside another hides an outer routine of the same name, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 3 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
