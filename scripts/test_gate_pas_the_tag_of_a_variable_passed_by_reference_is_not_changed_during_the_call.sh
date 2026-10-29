#!/usr/bin/env bash
# test_gate_pas_the_tag_of_a_variable_passed_by_reference_is_not_changed_during_the_call.sh -- ISO 7185 6.5.3.3 case B: a component of a variant passed as a variable parameter is a reference that must keep its variant active for the
# whole activation of the callee; changing the tag-field to select another variant while that reference is outstanding is an error (PAT iso7185prt1702b).
#
# MEASURED 2026-10-07 by hq_pascal: PAT 1702b ran to rc 0 in both modes. The variant check of a variable actual was dropped at the call (the parser's
# __pas_vcheck strip, pascal.y mk_call) because a component actual travels copy-in/copy-out and the copy-in check was the one that mattered; the copy-out
# wrote the component back into the variant the callee had deselected. CURE: the dropped checks are re-run after a user PROCEDURE call returns, which
# reads the tag as the callee left it (the ISO text allows the error "when the variant is changed ... or deferred to the time the bad variant is assigned").
# Cases C and D (undiscriminated variants) are NOT covered: fpc -Miso and the master graded programs (test_tprec4, test_tprec12) read one arm after writing
# another, so that is a ruling for the cfo, not a gate.
#
# ARMS, both modes: fault programs print `before`, then fault (stdout exactly `before`, rc non-zero, stderr naming 6.5.3.3); and a control cut LIVE from
# fpc -Miso (tag unchanged, tag re-assigned to the same value, a non-variant component, a function with a variable parameter on a plain field) that must run byte-identical.
# FAIL_ONCE=1 corrupts the control's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile or link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }


cat > "$T/vtag.pas" <<'PAS'
program vtag(output);
var a: record case val: boolean of true: (i: integer); false: (c: char) end;
procedure b(var i: integer); begin a.val := false; i := 1 end;
begin writeln('before'); a.val := true; b(a.i); writeln('after') end.
PAS
cat > "$T/vtag2.pas" <<'PAS'
program vtag2(output);
var a: record case val: boolean of true: (i: integer); false: (c: char) end;
procedure b(var i: integer); begin a.val := false end;
begin writeln('before'); a.val := true; b(a.i); writeln('after') end.
PAS
cat > "$T/vtag3.pas" <<'PAS'
program vtag3(output);
type r = record case val: boolean of true: (i: integer); false: (c: char) end;
var a: r;
procedure b(var x: r; var i: integer); begin x.val := false; i := 1 end;
begin writeln('before'); a.val := true; b(a, a.i); writeln('after') end.
PAS
cat > "$T/ctl.pas" <<'PAS'
program ctl(output);
type r = record n: integer; case val: boolean of true: (i: integer); false: (c: char) end;
var a: r;
procedure inc1(var i: integer); begin i := i + 1 end;
procedure same(var i: integer); begin a.val := true; i := i + 10 end;
function twice(var i: integer): integer; begin i := i * 2; twice := i end;
begin
  a.n := 1; a.val := true; a.i := 5;
  inc1(a.i); writeln(a.i);
  same(a.i); writeln(a.i);
  inc1(a.n); writeln(a.n);
  writeln(twice(a.n), ' ', a.n);
  a.val := false; a.val := true; a.i := 3; writeln(a.i)
end.
PAS
RC=0; N=0
for m in m3 m4; do
  for p in vtag vtag2 vtag3; do
    run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" != 0 ] && [ "$(cat "$T/o")" = before ] && grep -q 6.5.3.3 "$T/e"; then echo "  $p $m: refused with 6.5.3.3 after printing before (rc=$rc)"
    else echo "  ⛔ $p $m FAILED: rc=$rc stdout=[$(head -c 60 "$T/o" | tr '\n' '|')] err=[$(head -c 100 "$T/e")]"; RC=1; fi
  done
done
frc=$(fpcrun ctl)
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/ctl.want"; fi
for m in m3 m4; do run $m ctl; rc=$?; N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/ctl.want" "$T/o"; then echo "  ctl $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ ctl $m FAILED: rc=$rc (fpc $frc)"; diff "$T/ctl.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a tag changed under an outstanding variant reference is refused and a legal control runs as fpc, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined 4 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
