#!/usr/bin/env bash
# test_gate_pas_exit_leaves_the_routine_it_names.sh -- exit returns from the routine it is in, or from the enclosing routine it names (FPC, MacPas)
#
# MEASURED 2026-09-25 by hq_pascal, both modes, row pascal-every-suite-to-100-under-nonet-ceo-1266. The Pascal lowerer had no exit: a
# call named exit fell through to the SNOBOL4/Icon builtin exit and ENDED THE PROGRAM wherever it stood. Bracket (monitor_run.sh --oracle,
# FPC test_tmacnonlocalexit1): last agree step 7 (LABEL stno=11, the Exit(Global) inside Local), first diverge step 8 (fpx RETURN global,
# scr END). The cure (lower_pascal.c): a routine that some exit leaves gets an exit node, wired just before the parser's __trace_return
# hook (so a traced exit still reports its RETURN) or else to the routine's return; exit and exit(RoutineItIsIn) go there; the FPC
# exit(value) assigns the function result first; MacPas exit(EnclosingRoutine) rides the nonlocal-goto unwind of landing 5 with its own
# code, and the named routine's unwind node takes it to that routine's exit node when its display frame matches. A user routine named
# exit is still called.
#
# ARMS, each cut LIVE from fpc and required byte-identical in BOTH modes: (1) under -Miso -- exit from a procedure inside nested loops,
# a function exiting with the result it holds, exit(value), a recursion that exits at its base, and the main program exiting mid-loop;
# (2) under {$MODE MACPAS} -- Exit(outer) from two levels down in a recursion, which must terminate that outer activation and no other,
# and Exit(mid) from one level down. It FAILS on the parent tree. FAIL_ONCE=1 corrupts the first ref to prove it can fail.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
run_mode() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null 2>"$T/$p.$m.err" | head -c 8000 >"$T/$p.$m.out"; exit "${PIPESTATUS[0]}" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 ) || { echo "  ⛔ arm $p m4: did not compile"; return 99; }
  ( cd "$T" && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: arm $p compiled but would not link"; exit 2; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null 2>"$T/$p.$m.err" | head -c 8000 >"$T/$p.$m.out"; exit "${PIPESTATUS[0]}" ); return $?; }
cat > "$T/xiso.pas" <<'PAS'
program xiso(output);
var calls, k: integer;
procedure find(target: integer);
var i, j: integer;
begin
  calls := calls + 1;
  i := 0;
  while i < 5 do
  begin
    for j := 1 to 5 do
      if i * 10 + j = target then
      begin
        writeln('found ', target, ' at ', i, ',', j);
        exit
      end;
    i := i + 1
  end;
  writeln('no ', target)
end;
function firstdiv(n: integer): integer;
var d: integer;
begin
  firstdiv := n;
  for d := 2 to n - 1 do
    if n mod d = 0 then
    begin
      firstdiv := d;
      exit
    end
end;
function sign(x: integer): integer;
begin
  if x < 0 then exit(-1);
  if x = 0 then exit(0);
  sign := 1
end;
function depth(n: integer): integer;
begin
  depth := n;
  if n >= 4 then exit;
  depth := depth(n + 1) * 10 + n
end;
begin
  calls := 0;
  find(23); find(42); find(99);
  writeln('firstdiv ', firstdiv(91), ' ', firstdiv(97), ' ', firstdiv(4));
  writeln('sign ', sign(-7), ' ', sign(0), ' ', sign(12));
  writeln('depth ', depth(1));
  for k := 1 to 10 do
    if k = 3 then
    begin
      writeln('main exits at k=', k, ' calls=', calls);
      exit
    end;
  writeln('not reached')
end.
PAS
cat > "$T/xmac.pas" <<'PAS'
program xmac;
{$MODE MACPAS}
var trail: integer;
procedure outer(n: integer);
var tag: integer;
  procedure mid;
    procedure inner;
    begin
      trail := trail * 10 + n;
      if n = 2 then Exit(outer);
      if n = 3 then Exit(mid);
      trail := trail * 10 + 7
    end;
  begin
    inner;
    writeln('mid after inner, n=', n, ' trail=', trail);
    if n = 1 then outer(2);
    if n = 1 then outer(3);
    writeln('mid ends, n=', n)
  end;
begin
  tag := n * 11;
  mid;
  writeln('outer after mid, n=', n, ' tag=', tag, ' trail=', trail)
end;
begin
  trail := 0;
  outer(1);
  writeln('trail=', trail)
end.
PAS
for p in xiso xmac; do
  ( cd "$T" && "$FPC" -Miso -v0 -o"$p.fpc" $p.pas >/dev/null 2>&1 && timeout -k 5 20s ./$p.fpc | head -c 8000 ) > "$T/$p.want" 2>&1
  [ -s "$T/$p.want" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no output for arm $p"; exit 2; }
done
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/xiso.want"; fi
for p in xiso xmac; do for m in m3 m4; do
  run_mode $m $p; rc=$?
  if [ "$rc" = 0 ] && cmp -s "$T/$p.want" "$T/$p.$m.out"; then echo "  arm $p $m: byte-identical to fpc"
  else echo "  ⛔ arm $p $m FAILED: rc=$rc"; echo "      want: $(tr '\n' '|' < "$T/$p.want" | cut -c1-400)"; echo "      got : $(tr '\n' '|' < "$T/$p.$m.out" | cut -c1-400)"
       echo "      err : $(tr '\n' '|' < "$T/$p.$m.err" | cut -c1-160)"; RC=1; fi
done; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: exit leaves the routine it is in or the enclosing routine it names (both arms byte-identical to fpc), both modes"
else echo "GATE FAIL(1) [$G]: examined 2 oracle-cut arms in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
