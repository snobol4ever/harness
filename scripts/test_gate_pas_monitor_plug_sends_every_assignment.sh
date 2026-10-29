#!/usr/bin/env bash
# test_gate_pas_monitor_plug_sends_every_assignment.sh -- the Pascal monitor plug sends a VALUE for every assignment, typed as fpx types it
#
# MEASURED 2026-09-25 by hq_pascal (CEO-1270; Lon, in-chat to hq_pascal: "Fix all trace gaps when you find them the instant you find
# them."). A census of the IPC sync-step monitor over the FPC suite's runtime reds (monitor_run.sh --oracle, participants fpx scr)
# found four divergences that were the PLUG, not the program, each blocking a bracket: (G1) an assignment of a string to a whole char
# array sent no VALUE (test_tparray10, webtbs_tw22669); (G2) an assignment to a file's buffer-variable sent none (test_tisobuf3);
# (G3) an enum-typed record field or enum-array element went as INT where fpx sends the constant's name (test_tprec4, test_tprec12);
# (G4) a typed file's buffer read back as a char -- and that one was ALSO a program defect: writeln(f^:1) on a file of integer printed
# '*' where fpc prints 42 (pas_is_charexpr took every __pas_fbuf_get as char). The cure is Pascal's own files: every arm of the
# assignment production ends through pas_trace_assigned (G1, G2), pas_trace_wrap_value names an enum field or element (G3), and a
# typed file's buffer is a char only when its component is (pas_buf_is_char, G4).
#
# ARMS: one witness carrying all four shapes, required (1) to AGREE with fpx event-for-event to a clean end under monitor_run.sh
# --oracle with UNGRADED=0, and (2) to print byte-identical to fpc -Miso in BOTH modes. Pre-cure: (1) diverges at step 2 and (2)
# prints '*'. FAIL_ONCE=1 corrupts the ref of arm 2. No fpx (the instrumented Free Pascal fork) REFUSES rc=2.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- arm 2's ref is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
cat > "$T/plug.pas" <<'PAS'
program plug(output);
type e = (red, green, blue); r = record f1: e; f2: integer end;
var p: packed array [1..4] of char; v: r; a: array [1..3] of e; c: e; f: file of integer; i: integer;
begin
  p := 'ABCD';
  v.f1 := green; v.f2 := 5; a[2] := blue; c := red;
  rewrite(f); f^ := 42; writeln(f^:1); put(f);
  i := ord(v.f1) + ord(a[2]);
  writeln(p, ' ', i:1, ' ', ord(c):1)
end.
PAS
mon=$( cd "$T" && timeout -k 5 300 bash "$HERE/monitor_run.sh" "$T/plug.pas" --oracle 2>&1 ); mrc=$?
[ "$mrc" = 2 ] && { echo "⛔ GATE REFUSE(2) [$G]: the monitor could not measure: $(printf '%s\n' "$mon" | grep -m1 'REFUSE' | cut -c1-160)"; exit 2; }
if [ "$mrc" = 0 ] && printf '%s\n' "$mon" | grep -q 'AGREE: participants fpx scr agree event-for-event.*UNGRADED=0'; then
     echo "  arm 1: $(printf '%s\n' "$mon" | grep -m1 -oE 'clean termination at step [0-9]+ \(AGREE=[0-9]+ DIVERGE=0 UNGRADED=0\)') against fpx"
else echo "  ⛔ arm 1 FAILED: monitor rc=$mrc"; printf '%s\n' "$mon" | grep -a '^| \*\*>\*\*' | head -1 | sed 's/^/      first divergence: /'; RC=1; fi
( cd "$T" && "$FPC" -Miso -v0 -o"plug.fpc" plug.pas >/dev/null 2>&1 && ./plug.fpc ) > "$T/plug.ref" 2>&1
[ -s "$T/plug.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no output for arm 2"; exit 2; }
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/plug.ref"; fi
o3=$( cd "$T" && timeout -k 5 20s "$SCRIP" --run plug.pas </dev/null 2>&1 ); c3=$?
( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out=plug.s plug.pas </dev/null >/dev/null 2>&1 && cc -m64 -no-pie plug.s -o plug.m4 -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) \
  || { echo "⛔ GATE REFUSE(2) [$G]: arm 2 would not compile or link in m4"; exit 2; }
o4=$( cd "$T" && timeout -k 5 20s ./plug.m4 </dev/null 2>&1 ); c4=$?
if [ "$c3" = 0 ] && [ "$c4" = 0 ] && [ "$o3" = "$(cat "$T/plug.ref")" ] && [ "$o4" = "$(cat "$T/plug.ref")" ]; then echo "  arm 2: byte-identical to fpc -Miso in both modes"
else echo "  ⛔ arm 2 FAILED"; echo "      want: $(tr '\n' '|' < "$T/plug.ref")"
     echo "      m3  : rc=$c3 $(printf '%s' "$o3" | tr '\n' '|')"; echo "      m4  : rc=$c4 $(printf '%s' "$o4" | tr '\n' '|')"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: every assignment shape reaches the monitor as fpx sends it, and the program matches fpc -Miso, both modes"
else echo "GATE FAIL(1) [$G]: examined one witness under the monitor and in both modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
