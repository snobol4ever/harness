#!/usr/bin/env bash
# test_gate_pas_a_goto_out_of_a_routine_leaves_every_box_of_main_at_one_depth.sh -- in a program whose routines goto a label of the
# main block, every box of main is entered at ONE stack depth, however many times the loop around a call brings it back
# (row pascal-p4-self-hosts-under-scrip..., ceo CEO-1311)
#
# MEASURED 2026-09-27 by hq_pascal, mode 4. After every call to a routine the lowerer tests the non-local-goto flag, and it tested
# __pas_nlg <> 0 with the label dispatcher on the test's GAMMA. The dispatcher sits in a later run of the zd depth plan, so the plan
# left the run holding the call unclaimed: the box before it popped to depth 0, and the unclaimed assignment after it jumped back to
# the loop head, planned at a nonzero depth, without re-pushing. Each pass round the loop then ran the head's boxes shallower than
# planned: P4's int.pas (a 40-arm case in a loop, errori's goto 1) ran 640 bytes high after each mst and SIGSEGV'd at the frame top
# on its first P-code instruction. THE CURE (lower_pascal.c only): the test is __pas_nlg = 0 with the dispatcher on OMEGA, an edge
# the plan already carries between runs. The emitter's own handling of a gamma out of an unclaimed run is the cto's (asked by
# hq_pascal 2026-09-27, ask-zd-plan-an-unclaimed-run-jumps-into-a-claimed-node-without-restoring-its-depth).
#
# INSTRUMENT: gdb breaks on every box label of main in the mode-4 binary and records rsp at each entry; a box entered at two rsp
# values is a depth the plan did not hold (main's frame never moves). ARMS per program: (a) depth -- no box of main at two depths,
# (b) m3 and (c) m4 -- stdout and exit code byte-identical to fpc -Miso. PROGRAMS: loop -- a while loop calling a function, a
# procedure that can goto 1; cases -- the int.pas shape, a while loop over a case whose arm calls a function.
# FAILS on the parent b6b9308ba in both depth arms (the loop head is re-entered 80 and 240 bytes high); the output arms are green there. FAIL_ONCE=1 corrupts cases's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every output arm is CUT FROM THE ORACLE"; exit 2; }
GDB="${GDB_BIN:-/usr/bin/gdb}"; [ -x "$GDB" ] || { echo "⛔ GATE REFUSE(2) [$G]: no gdb at $GDB -- the depth arm reads rsp at each box of main"; exit 2; }
"$GDB" -q -batch -ex 'python print("gdb-python-ok")' 2>/dev/null | grep -q gdb-python-ok || { echo "⛔ GATE REFUSE(2) [$G]: $GDB has no python -- the depth arm's breakpoints are python"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
cat > "$T/depth.py" <<'PY'
import gdb, os
gdb.execute("set pagination off"); gdb.execute("set confirm off")
labs = [l.strip() for l in open(os.environ["BOXES"]) if l.strip()]
where = {int(gdb.parse_and_eval("(long)&%s" % l)): l for l in labs}
seen = {}; bad = []
class Box(gdb.Breakpoint):
    def stop(self):
        l = where[int(gdb.parse_and_eval("$pc"))]; rsp = int(gdb.parse_and_eval("$rsp"))
        if l not in seen: seen[l] = rsp
        elif seen[l] != rsp and len(bad) < 3: bad.append("%s first at rsp %x, later %+d" % (l, seen[l], rsp - seen[l]))
        return False
for a in where: Box("*0x%x" % a, internal=True)
gdb.execute("run < /dev/null > /dev/null 2>&1")
print("DEPTH boxes=%d twice=%d %s" % (len(seen), len(bad), " | ".join(bad)))
PY
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/loop.pas" <<'PAS'
program loop(output);
label 1;
var n, x: integer;
procedure jump; begin writeln('jumped'); goto 1 end;
function f(k: integer): integer; begin f := k * k end;
begin
  n := 0; x := 0;
  while n < 4 do begin n := n + 1; x := x + f(n) end;
  writeln(x:1);
  if n < 0 then jump;
1:
  writeln('end ', n:1)
end.
PAS
cat > "$T/cases.pas" <<'PAS'
program cases(output);
label 1;
var store: array [0..40] of integer; op, sp, mp, n: integer; running: boolean;
procedure errori; begin writeln('error at ', sp:1); goto 1 end;
function base(ld: integer): integer; begin base := mp + ld end;
begin
  sp := 0; mp := 3; n := 0; running := true;
  while running do begin
    n := n + 1;
    if n > 5 then op := 58 else if odd(n) then op := 11 else op := 4;
    case op of
      11: begin store[sp + 2] := base(n); store[sp + 3] := mp; sp := sp + 5 end;
      4: begin store[sp] := base(sp) + store[sp - 3]; sp := sp - 1 end;
      58: running := false
    end;
    if sp > 35 then errori
  end;
  writeln('sp=', sp:1, ' top=', store[sp]:1);
1:
  writeln('n=', n:1)
end.
PAS
for p in loop cases; do
  frc=$(fpcrun $p)
  if [ "$p" = cases ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" --compile -o "$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) \
    || { echo "  ⛔ $p: did not compile and link in mode 4"; RC=1; N=$((N + 3)); continue; }
  awk '/^main:/{m=1} m && /^n[0-9]+_[a-z_]+_bx:/{sub(":", "", $1); print $1}' "$T/$p.s" > "$T/$p.boxes"
  [ -s "$T/$p.boxes" ] || { echo "⛔ GATE REFUSE(2) [$G]: no box label follows main: in $p.s -- the depth arm has nothing to watch"; exit 2; }
  d=$(cd "$T" && BOXES="$T/$p.boxes" LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 120s "$GDB" -q -batch -x "$T/depth.py" "./$p.m4" 2>/dev/null | grep '^DEPTH' | tail -1); N=$((N + 1))
  case "$d" in "DEPTH boxes="*" twice=0 "*) [ "$(echo "$d" | sed 's/DEPTH boxes=\([0-9]*\).*/\1/')" -gt 0 ] && echo "  $p depth: every box of main entered at one rsp (${d#DEPTH })" || { echo "  ⛔ $p depth: no box of main was hit ($d)"; RC=1; } ;;
    "DEPTH "*) echo "  ⛔ $p depth FAILED: ${d#DEPTH }"; RC=1 ;;
    *) echo "⛔ GATE REFUSE(2) [$G]: gdb gave no depth line for $p"; exit 2 ;; esac
  for m in m3 m4; do N=$((N + 1))
    if [ "$m" = m3 ]; then ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); rc=$?
    else ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); rc=$?; fi
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a goto out of a routine leaves every box of main at one depth, output as fpc -Miso, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined 2 programs, a depth arm and 2 modes each"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
