#!/usr/bin/env bash
# test_gate_pas_the_activation_frame_is_carved_and_released_by_the_emitted_prologue.sh -- a Pascal procedure or function call takes the
# block protocol: the caller builds the argument DESCR cells on its own spine, the callee reads parameter i at [rsp+kt+16i] and its
# exit releases frame and block together; no C helper carves, fills or releases the frame.
#
# ROW pascal-the-block-protocol-reaches-its-own-call-regime-the-six-frame-helpers-leave-every-pascal-graph-ceo-1488 (rank 0, CEO-1491;
# Lon 2026-10-03 17:3x CDT, in-chat to the ceo, verbatim: "Oh you want all languages to use the ZETA technique and ASM not C. Yes that one
# send as high priority since it is huge speed increase."). Layout agreed with hq_prolog by telegram (it answered AGREED): hq_prolog's
# e95282e39, with the landing cell dropped and the wires left where Pascal already keeps them (the caller's two pushed cells, consumed
# by the callee's exit).
#
# CURE: zls_g_det_block (frame_layout.c) names a deterministic Pascal graph by IR properties (static_calls, a non-pinned zframe graph,
# not icn_cells, not root) and zls_g_block_args takes it, so its parameter vslots sit at kt+16i; xa_flat.cpp zeroes the value region inline
# and copies nothing; its exits release kt+16n; bb_call_proc_staged.cpp's bcps_det_block_arm pushes the wire pair, builds the block and
# jumps through the registry word. rt_proc_call_open_detN, rt_proc_call_epilogue_gamma/omega, rt_jmp_frame_lexprep2,
# rt_icn_zframe_args_install and rt_nret_fix_tiny leave every Pascal call path.
#
# ARMS, both modes, expectations cut LIVE from fpc: (census) the mode-4 text of a recursive kernel names none of the six helpers (the
# parent's names them); (rec) Ackermann, mutual recursion through a forward declaration, a linked list built and summed 4000 times;
# (nest) a six-level nest whose innermost routine reads the parameters and locals of five ancestors and writes a var parameter through
# the display; (args) eight parameters mixing integer, real and var, an argument-free procedure, exit from a function.
# (pproc) the MacPas procedure parameter: a local routine passed down two levels and called through its parameter (fpc test tmaclocalprocparam3's
# shape) -- dispatched statically by the lowerer, so no C road reaches a Pascal routine; a procedural TYPE (var f: function...) is a syntax error in
# this parser. FAIL_ONCE=1 corrupts the nest arm's ref.
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

cat > "$T/rec.pas" <<'PAS'
{$mode objfpc}
program rec(output);
type pn = ^node; node = record v: longint; nx: pn end;
var n, t: longint;
function ack(m, n: longint): longint;
begin
  if m = 0 then ack := n + 1
  else if n = 0 then ack := ack(m - 1, 1)
  else ack := ack(m - 1, ack(m, n - 1))
end;
function build(d: longint): pn;
var p: pn;
begin
  if d = 0 then build := nil
  else begin new(p); p^.v := d; p^.nx := build(d - 1); build := p end
end;
function sum(p: pn): longint;
begin if p = nil then sum := 0 else sum := p^.v + sum(p^.nx) end;
function isodd(k: longint): boolean; forward;
function iseven(k: longint): boolean;
begin if k = 0 then iseven := true else iseven := isodd(k - 1) end;
function isodd(k: longint): boolean;
begin if k = 0 then isodd := false else isodd := iseven(k - 1) end;
begin
  writeln(ack(2, 3), ' ', ack(3, 4));
  t := 0; n := 0;
  while n < 4000 do begin t := t + sum(build(60)); n := n + 1 end;
  writeln(t);
  if iseven(100) then writeln('even') else writeln('odd');
  if isodd(7) then writeln('odd7') else writeln('even7')
end.
PAS
cat > "$T/nest.pas" <<'PAS'
{$mode objfpc}
program nest(output);
var total: longint;
procedure l1(a1: longint; var r: longint);
  var v1: longint;
  procedure l2(a2: longint);
    var v2: longint;
    procedure l3(a3: longint);
      var v3: longint;
      procedure l4(a4: longint);
        var v4: longint;
        procedure l5(a5: longint);
          var v5: longint;
          procedure l6(a6: longint);
          begin
            r := r + a1 + v1 + a2 + v2 + a3 + v3 + a4 + v4 + a5 + v5 + a6;
            writeln('l6 ', r)
          end;
        begin v5 := 50; l6(6); l6(60) end;
      begin v4 := 40; l5(5) end;
    begin v3 := 30; l4(4) end;
  begin v2 := 20; l3(3) end;
begin v1 := 10; l2(2) end;
begin
  total := 0;
  l1(1, total); writeln(total);
  l1(100, total); writeln(total)
end.
PAS
cat > "$T/args.pas" <<'PAS'
{$mode objfpc}
program args(output);
var k: longint;
function f8(a, b, c, d, e, f, g, h: longint; x: double; var y: longint): double;
begin y := y + a + b + c + d + e + f + g + h; f8 := x * (a + h) end;
procedure noargs; begin writeln('noargs') end;
procedure leave(n: longint);
begin
  if n = 3 then exit;
  writeln('leave ', n);
  leave(n + 1);
  writeln('back ', n)
end;
function ex(n: longint): longint;
begin
  ex := -1;
  if n > 5 then exit;
  ex := n * 10
end;
begin
  k := 0;
  writeln(f8(1,2,3,4,5,6,7,8, 1.5, k):0:2, ' ', k);
  noargs; noargs;
  writeln(ex(3), ' ', ex(9));
  leave(0);
  writeln('done')
end.
PAS
cat > "$T/pproc.pas" <<'PAS'
{$mode macpas}
program pproc;

  procedure p1( procedure pp);
  begin
    pp
  end;

  procedure p2( procedure pp);
  begin
    p1( pp)
  end;

  procedure n;
  begin
    writeln( 'calling through n')
  end;

  procedure q;
  var qi: longint;

    procedure r;
    begin
      if qi = 1 then
        writeln( 'success for r')
      else
        begin
        writeln( 'fail');
        halt( 1)
      end
    end;

  begin
    qi:= 1;
    p1( r);
    p2( r);
    p1( n);
    p2( n);
  end;

begin
	q
end.
PAS
# arm 0: the mode-4 text of a recursive kernel names none of the six
cat > "$T/census.pas" <<'PAS'
program census(output);
var r: longint;
function f(n: longint): longint;
begin
  if n < 2 then f := n else f := f(n - 1) + f(n - 2)
end;
begin
  r := f(15);
  writeln(r)
end.
PAS
N=0
( cd "$T" && timeout -k 5 60s "$SCRIP" --compile -o census.s census.pas </dev/null >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: the census kernel did not compile"; exit 2; }
HITS=$(grep -cE 'call[[:space:]]+(rt_jmp_frame_lexprep2|rt_icn_zframe_args_install|rt_arg_stage|rt_proc_drop_frame_h|rt_proc_call_open_det[0-9]*|rt_nret_fix_tiny|rt_proc_call_epilogue_)' "$T/census.s")
N=$((N + 1))
if [ "$HITS" = 0 ]; then echo "  census: the kernel's mode-4 text names 0 frame-helper call sites"
else echo "  ⛔ census FAILED: $HITS frame-helper call sites in the kernel's mode-4 text"; RC=1; fi
for p in rec nest args pproc; do
  frc=$(fpcrun $p)
  if [ "$p" = nest ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a Pascal call crosses no C helper and answers as fpc does, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 3 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
