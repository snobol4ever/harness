#!/usr/bin/env bash
# test_gate_pas_a_program_header_file_binds_to_the_console_as_fpc_miso_binds_it.sh -- a file named in the program heading (other than input and output) is
# bound by the oracle, fpc -Miso, to the command-line argument of its position and, with no such argument, to the console: reset reads standard input, rewrite
# writes standard output (FPCSource rtl/inc/text.inc fpc_textinit_iso: assign(t, paramstr(nr)), an empty name being the console; compiler/pmodules.pas numbers
# the heading's files 1, 2, ... skipping INPUT and OUTPUT). MEASURED 2026-10-09 by the ceo grading the ISO-dialect Pascal downloads (CEO-1589): Pascal-S
# (srcfil), the Hueras-Ledgard prettyprinter (INPUTFILE, OUTPUTFILE) and the P4 interpreter (prd, prr) died "Runtime error 2 at $0" under scrip in both modes
# where fpc -Miso read standard input. CAUSE: lower_pascal_tree.c bound a heading file to the console only under an explicit {$mode iso} directive, and
# otherwise reset opened a file named after the variable; the oracle is fpc -Miso, so with no mode directive the program IS in ISO mode. CURE: the heading
# binding applies unless the source switches fpc out of ISO mode with a known non-ISO {$mode} (pas_seen_mode_directive). The argument-position half of the
# binding (a heading file named by argv) is not built: every graded run passes no argument.
# ARMS, both modes, cut LIVE from fpc -Miso on the same stdin: (1) hdrin -- reset of a heading file reads standard input; (2) hdrout -- rewrite of a heading
# file writes standard output (not interleaved with output: fpc gives the heading file its own 256-byte buffer, flushed when the program ends, so its lines
# land before output's; scrip shares one stream -- a buffering divergence recorded in GOAL-CEO.md CEO-1589, not gated here); (3) hdrcopy -- two heading files, one read and one written. FAIL_ONCE=1 corrupts arm 3's ref.
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
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" <"$T/$p.in" >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: compile or link failed"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" <"$T/$p.in" >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" "$1.pas" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s "./$1.fpc" <"$T/$1.in" >"$T/$1.want" 2>/dev/null ) || { echo "⛔ GATE REFUSE(2) [$G]: the fpc -Miso run of $1 failed"; exit 2; }; [ -s "$T/$1.want" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle printed nothing for $1"; exit 2; }; }
cat > "$T/hdrin.pas" <<'PAS'
program hdrin(input, output, f);
var f: text; x: integer;
begin reset(f); readln(f, x); writeln('twice ', x, ' is ', 2 * x) end.
PAS
printf '21\n' > "$T/hdrin.in"
cat > "$T/hdrout.pas" <<'PAS'
program hdrout(output, g);
var g: text; i: integer;
begin rewrite(g); for i := 1 to 3 do writeln(g, 'heading file line ', i) end.
PAS
: > "$T/hdrout.in"
cat > "$T/hdrcopy.pas" <<'PAS'
program hdrcopy(src, dst);
var src, dst: text; c: char; n: integer;
begin reset(src); rewrite(dst); n := 0;
  while not eof(src) do begin
    while not eoln(src) do begin read(src, c); write(dst, c); n := n + 1 end;
    readln(src); writeln(dst) end;
  writeln(dst, n, ' characters')
end.
PAS
printf 'the heading names\nsrc and dst\n' > "$T/hdrcopy.in"
for p in hdrin hdrout hdrcopy; do fpcrun "$p"; done
[ "${FAIL_ONCE:-0}" = 1 ] && printf 'corrupted\n' >> "$T/hdrcopy.want"
for p in hdrin hdrout hdrcopy; do
  for m in m3 m4; do
    N=$((N+1)); run "$m" "$p"; rc=$?
    if cmp -s "$T/$p.want" "$T/o"; then echo "  ✅ $p $m equals fpc -Miso (rc=$rc)"
    else RC=1; echo "  ⛔ $p $m differs from fpc -Miso (rc=$rc): $(head -c 160 "$T/e" | tr '\n' ' ') $(diff "$T/$p.want" "$T/o" | head -3 | tr '\n' '|')"; fi
  done
done
echo "population: $N arms (3 programs x 2 modes), every expectation cut live from fpc -Miso"
[ "$RC" = 0 ] && { echo "✅ GATE PASS [$G]: a program-heading file binds to the console as fpc -Miso binds it, in both modes"; exit 0; }
echo "⛔ GATE FAIL [$G]: a program-heading file does not bind as fpc -Miso binds it"; exit 1
