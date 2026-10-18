#!/usr/bin/env bash
# test_gate_pas_a_for_variable_threat_names_its_real_lines_and_a_sibling_local_is_not_one.sh -- ISO 7185 6.8.3.9, the for-variable threat checker (pascal_sem.c).
#
# MEASURED 2026-10-09 by hq_pascal: the checker's scoping half is right (an outer variable i assigned by a sibling procedure does not threaten a for statement whose control variable is another procedure's local i:
# the shape of P4's int.p, accepted and byte-identical to fpc -Miso), but the refusal of a REAL threat named the wrong lines: the grammar stamped a source line on no statement node but goto, so `violation in
# t.pas line 0 ... threatened at line 1` (the checker's fallbacks for an unstamped node). CURE: pascal.y stamps the first-token line (the same one __trace_stmt uses) on every statement of a statement list and,
# through the new body_stmt nonterminal, on the body of an if, while, for, with and case arm.
#
# ARMS, both modes (mode 4 is the compile step, the refusal is a compile-time error): (1) the int.p shape accepted, stdout byte-identical to fpc -Miso; (2) a for body that assigns its own control variable refused
# naming for-line 8 and threat-line 9; (3) a procedure assigning the control variable, called from the loop, refused naming for-line 4 and threat-line 3. FAIL_ONCE=1 corrupts arm 1's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- arm 1's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/shape.pas" <<'PAS'
program shape(output);
var i: integer;
procedure sib; begin i := 5 end;
procedure init; var i: integer; begin for i := 1 to 3 do write(i, ' '); writeln end;
begin init; sib; writeln(i) end.
PAS
cat > "$T/body.pas" <<'PAS'
program body(output);
var i: integer;
procedure p;
begin
  i := 1
end;
begin
  for i := 1 to 3 do
    i := i + 1
end.
PAS
cat > "$T/call.pas" <<'PAS'
program call(output);
var i: integer;
procedure p; begin i := 1 end;
begin for i := 1 to 3 do p; writeln('done') end.
PAS
RC=0; N=0
( cd "$T" && "$FPC" -Miso -v0 -oshape.fpc shape.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile the shape"; exit 2; }
( cd "$T" && timeout -k 5 20s ./shape.fpc </dev/null >"$T/shape.want" 2>/dev/null )
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/shape.want"; fi
( cd "$T" && timeout -k 5 60s "$SCRIP" --run shape.pas </dev/null >"$T/o" 2>"$T/e" ); rc=$?; N=$((N + 1))
if [ "$rc" = 0 ] && cmp -s "$T/shape.want" "$T/o"; then echo "  shape m3: accepted, stdout byte-identical to fpc -Miso"; else echo "  ⛔ shape m3 FAILED: rc=$rc err=[$(head -c 120 "$T/e")]"; RC=1; fi
( cd "$T" && timeout -k 5 60s "$SCRIP" --compile -o shape.s shape.pas </dev/null >/dev/null 2>"$T/e" && cc -m64 -no-pie shape.s -o shape.m4 -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 && timeout -k 5 20s ./shape.m4 </dev/null >"$T/o" 2>>"$T/e" ); rc=$?; N=$((N + 1))
if [ "$rc" = 0 ] && cmp -s "$T/shape.want" "$T/o"; then echo "  shape m4: accepted, stdout byte-identical to fpc -Miso"; else echo "  ⛔ shape m4 FAILED: rc=$rc err=[$(head -c 120 "$T/e")]"; RC=1; fi
chk() { local p="$1" fl="$2" tl="$3" m
  for m in m3 m4; do
    if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 60s "$SCRIP" --run $p.pas </dev/null >"$T/o" 2>"$T/e" ); rc=$?
    else ( cd "$T" && timeout -k 5 60s "$SCRIP" --compile -o $p.s $p.pas </dev/null >"$T/o" 2>"$T/e" ); rc=$?; fi
    N=$((N + 1))
    if [ "$rc" != 0 ] && [ -z "$(cat "$T/o")" ] && grep -q "6.8.3.9 violation in $p.pas line $fl: .*threatened at line $tl by" "$T/e"; then echo "  $p $m: refused naming for-line $fl and threat-line $tl"
    else echo "  ⛔ $p $m FAILED: rc=$rc stdout=[$(head -c 40 "$T/o")] err=[$(head -1 "$T/e" | cut -c1-170)]"; RC=1; fi
  done; }
chk body 8 9
chk call 4 3
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a sibling's local is not a threat and a real threat names its lines in both modes, $N of $N arms"
else echo "GATE FAIL(1) [$G]: the for-variable checker is wrong about a threat or about its lines, see the arms above"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
