#!/usr/bin/env bash
# test_gate_pas_a_goto_leaves_its_routine_for_an_enclosing_label.sh -- ISO 7185 6.8.2.4: a goto to a label of an enclosing block terminates every activation between
#
# MEASURED 2026-09-25 by hq_pascal, both modes, row pascal-every-suite-to-100-under-nonet-ceo-1266. lower_pascal.c found only the labels of
# the routine being lowered, so a goto naming an enclosing block's label lowered to a no-op and the routine ran on: FPC webtbs_tw37823 printed
# "not jumped!" and test_tmacnonlocalgoto printed "Failed". Bracket (monitor_run.sh --oracle, tw37823): the last agree is step 6, LABEL stno=14
# (the goto); the first diverge is step 7, where fpx ENDs and scr RETURNs from jump. The cure rides normal returns, no stack surgery: the
# goto stores a code for (owner routine, label) in the hidden program variable __pas_nlg and, when the owner is at display level 1..3, the
# owner's frame (display[L]) in __pas_nlf, then goes to its routine's unwind node; a program with such a goto checks __pas_nlg after every
# call to a user routine; the unwind node of a routine owning a targeted label goes to that label when the code matches AND its own
# display[L] is the stored frame, clearing the code, and otherwise returns. The frame test is what makes a routine passed as a procedural
# parameter unwind to the activation it was created in, not the first activation of its owner on the dynamic chain.
#
# ARMS: one program cut LIVE from fpc -Miso and required byte-identical in BOTH modes: a goto out of a for-loop two levels down into a
# recursive enclosing procedure's label and into the main program's; a goto out of a function evaluated inside an expression; a goto out
# of while and repeat loops through a recursion; and a routine carried as a procedural parameter into deeper activations of its owner, which
# must land in the activation it came from. It FAILS on the parent tree. OPEN EDGE, NOT GRADED HERE: when the owner is at display level
# 4 or deeper the frame is not compared, so only the procedural-parameter case above differs there. FAIL_ONCE=1 corrupts the ref to prove it can fail.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
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
cat > "$T/nlg.pas" <<'PAS'
program nlg(output);
label 9;
var depth, total, hits: integer;
procedure dummy;
begin
  writeln('dummy')
end;
procedure outer(n: integer);
label 5;
var mine: integer;
  procedure inner(k: integer);
  var i: integer;
  begin
    for i := 1 to 10 do
    begin
      total := total + i;
      if (k = 2) and (i = 3) then goto 5;
      if (k = 4) and (i = 2) then goto 9
    end;
    writeln('inner fell through ', k)
  end;
begin
  mine := n * 100;
  depth := depth + 1;
  inner(n);
  writeln('outer after inner ', n);
5:
  writeln('outer at 5, n=', n, ' mine=', mine, ' total=', total);
  if n < 4 then outer(n + 1);
  writeln('outer returns ', n)
end;
function f(x: integer): integer;
begin
  if x > 3 then goto 9;
  f := x * 2
end;
procedure a(lvl: integer; procedure q);
label 1;
var tag: integer;
  procedure c;
  begin
    writeln('c from the activation with tag ', tag);
    goto 1
  end;
begin
  tag := lvl * 11;
  if lvl = 1 then a(2, c) else if lvl = 2 then a(3, q) else q;
  writeln('a not reached ', lvl);
1:
  writeln('a at 1 lvl=', lvl, ' tag=', tag)
end;
procedure p1;
label 7;
var s: integer;
  procedure p2;
    procedure p3(n: integer);
    begin
      hits := hits + 1;
      if n = 0 then goto 7;
      while true do p3(n - 1)
    end;
  begin
    repeat p3(5) until false
  end;
begin
  s := 42;
  p2;
7:
  writeln('p1 at 7 s=', s, ' hits=', hits)
end;
begin
  depth := 0; total := 0; hits := 0;
  a(1, dummy);
  p1; p1;
  writeln('sum ', f(1) + f(2) + f(3));
  outer(1);
  writeln('not reached');
9:
  writeln('main at 9, depth=', depth, ' total=', total);
  if depth < 9 then begin depth := 9; total := 10 + f(5); writeln('not reached either') end;
  writeln('done hits=', hits)
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 -o"nlg.fpc" nlg.pas >/dev/null 2>&1 && timeout -k 5 20s ./nlg.fpc | head -c 8000 ) > "$T/nlg.want" 2>&1
[ -s "$T/nlg.want" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no output for arm nlg"; exit 2; }
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/nlg.want"; fi
for m in m3 m4; do
  run_mode $m nlg; rc=$?
  if [ "$rc" = 0 ] && cmp -s "$T/nlg.want" "$T/nlg.$m.out"; then echo "  arm nlg $m: byte-identical to fpc -Miso"
  else echo "  ⛔ arm nlg $m FAILED: rc=$rc"; echo "      want: $(tr '\n' '|' < "$T/nlg.want" | cut -c1-400)"; echo "      got : $(tr '\n' '|' < "$T/nlg.$m.out" | cut -c1-400)"
       echo "      err : $(tr '\n' '|' < "$T/nlg.$m.err" | cut -c1-160)"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a goto leaves its routine for an enclosing block's label and lands in the activation that owns it (byte-identical to fpc -Miso), both modes"
else echo "GATE FAIL(1) [$G]: examined 1 oracle-cut arm in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
