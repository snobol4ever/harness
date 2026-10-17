#!/usr/bin/env bash
# test_gate_sno_terminal_read_fails_without_a_tty.sh -- A READ OF THE VARIABLE TERMINAL COMES FROM THE TERMINAL AND
# FAILS THE STATEMENT WHEN THERE IS NONE, EXACTLY AS sbl -bf DOES; IT NEVER YIELDS THE NULL STRING FOREVER.
# Row snobol4-csnobol4-eof-input-unbounded-hang (coo, 2026-09-07; re-scoped: the row's named witness openo2 was
# already green, the live class is TERMINAL). MEASURED BEFORE THE CURE (SCRIP 1e8b5e951, coo): `L X = TERMINAL :F(END)`
# / `OUTPUT = X :(L)` under </dev/null ran to the timeout printing empty lines (2.8 MB in 5 s, both modes) because
# NV_GET_fn treated TERMINAL as an ordinary variable; sbl -bf and csnobol4 exit rc=0 with 0 bytes at once, and do the
# same on PIPED stdin (TERMINAL is the terminal device, not stdin). In the dotnet package code/palin/temp read
# TERMINAL and so hung 20 s each while their streams matched the oracle's empty output (the runner graded that PASS;
# FINDING-2026-09-07-coo-input-at-exhausted-stdin-*). CURE: NV_GET_fn routes TERMINAL to terminal_read(), which reads
# /dev/tty when it opens and FAILS otherwise (and at its EOF); the fastpath guard excludes TERMINAL like INPUT.
# Arms (each witness in BOTH modes, graded against the live sbl -bf oracle, same stdin, 5 s timeout):
#   w_loop     the two-line TERMINAL loop under </dev/null        -- must exit rc=0 within the timeout, stream equal
#   w_pipe     the same loop with piped stdin "a\nb\n"            -- TERMINAL is not stdin: stream equal to the oracle
#   w_input    the INPUT loop with piped stdin                   -- the control arm: INPUT still reads stdin, echoes a b
#   code/palin/temp  the three dotnet programs under </dev/null -- exit within the timeout, stream equal
# Population printed beside the verdict. Needs the built binary and the oracle; UNPROVEN(2) without either.
# Fail-once (2026-09-07 10:1x CDT, coo, MEASURED by rebuilding the pre-cure core.c): 10 of 12 gradings red -- w_loop, w_pipe, palin,
# temp and code all HANG rc=124 in both modes; only the INPUT control arm stays green. Cured: 12 of 12.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
. "$HERE/lib_gate.sh"; gate_parse_args "$@"
G=sno_terminal_read_fails_without_a_tty
"$HERE/util_require_fresh.sh" --gate test_gate_$G "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" >/dev/null 2>&1 || { echo "GATE UNPROVEN(2) [$G]: this tree's binary is stale or unbuilt -- run make"; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "GATE UNPROVEN(2) [$G]: lib_oracle_flags.sh unloadable"; exit 2; }
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "GATE UNPROVEN(2) [$G]: sbl -bf oracle absent"; exit 2; }
DOT="$S4E/corpus/packages/snobol4/dotnet"; [ -d "$DOT" ] || { echo "GATE UNPROVEN(2) [$G]: dotnet package missing at $DOT"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_terminal.XXXXXX")" || { echo "GATE UNPROVEN(2) [$G]: mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
SINK="$(sbl_listing_sink_flag "$W")" || { echo "GATE UNPROVEN(2) [$G]: no listing sink for the oracle"; exit 2; }
printf 'L\tX = TERMINAL\t:F(END)\n\tOUTPUT = X\t:(L)\nEND\n' > "$W/w_loop.sno"; cp "$W/w_loop.sno" "$W/w_pipe.sno"
printf 'L\tX = INPUT\t:F(END)\n\tOUTPUT = X\t:(L)\nEND\n' > "$W/w_input.sno"
for p in code palin temp; do [ -f "$DOT/$p.sno" ] || { echo "GATE UNPROVEN(2) [$G]: $DOT/$p.sno missing"; exit 2; }; cp "$DOT/$p.sno" "$W/"; done
printf 'a\nb\n' > "$W/pipe.txt"
PASS=0; FAIL=0; GRADED=0
grade() { # $1=name $2=stdin-file
    local name="$1" inp="$2" o3 o4 rc3 rc4 ro
    ( cd "$W" && timeout -k 5 5s "$SBL" -bf $SINK "$name.sno" < "$inp" > "$name.oracle" 2>&1 ); ro=$?
    ( cd "$W" && SNO_LIB="$DOT" timeout -k 5 5s "$ROOT/scrip" --run "$name.sno" < "$inp" > "$name.m3" 2>&1 ); rc3=$?
    if ( cd "$W" && SNO_LIB="$DOT" timeout -k 5 5s "$ROOT/scrip" --compile "$name.sno" < /dev/null > "$name.s" 2> "$name.cerr" ) \
       && gcc -c "$W/$name.s" -o "$W/$name.o" 2>/dev/null && gcc "$W/$name.o" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/$name.bin" 2>/dev/null; then
        ( cd "$W" && timeout -k 5 5s "./$name.bin" < "$inp" > "$name.m4" 2>&1 ); rc4=$?
    else rc4=NOBUILD; : > "$W/$name.m4"; fi
    for m in m3 m4; do
        GRADED=$((GRADED+1)); local rc; [ "$m" = m3 ] && rc=$rc3 || rc=$rc4
        if [ "$rc" = 124 ]; then FAIL=$((FAIL+1)); echo "  ⛔ $name $m: HANG (rc=124) -- oracle rc=$ro, $(wc -c < "$W/$name.oracle") bytes"
        elif [ "$rc" = NOBUILD ]; then FAIL=$((FAIL+1)); echo "  ⛔ $name $m: NOBUILD -- $(head -c 120 "$W/$name.cerr")"
        elif cmp -s "$W/$name.$m" "$W/$name.oracle"; then PASS=$((PASS+1)); echo "  ✅ $name $m: stream equals sbl -bf (rc=$rc, oracle rc=$ro, $(wc -c < "$W/$name.oracle") bytes)"
        else FAIL=$((FAIL+1)); echo "  ⛔ $name $m: stream differs from sbl -bf (rc=$rc): $(head -c 100 "$W/$name.$m" | tr '\n' '|')"; fi
    done
}
grade w_loop /dev/null; grade w_pipe "$W/pipe.txt"; grade w_input "$W/pipe.txt"
for p in palin temp; do grade "$p" /dev/null; done
# code.sno: the CLASS arm only (no hang). Its stream is one byte short of the oracle's for a SIBLING defect this
# row does not own: `OUTPUT('BINOUT', .BINOUT, '[-f2 -r1]')` associates a raw-record channel on unit 2 (stderr)
# and `BINOUT = '?'` prints the prompt without a newline; SCRIP does not honour the association (named to the
# ceo for a row 2026-09-07). Graded here as: exits within the timeout in both modes, never rc=124.
for m in m3 m4; do GRADED=$((GRADED+1)); done
( cd "$W" && SNO_LIB="$DOT" timeout -k 5 5s "$ROOT/scrip" --run code.sno < /dev/null > code.m3 2>&1 ); c3=$?
if ( cd "$W" && SNO_LIB="$DOT" timeout -k 5 5s "$ROOT/scrip" --compile code.sno < /dev/null > code.s 2> code.cerr ) && gcc -c "$W/code.s" -o "$W/code.o" 2>/dev/null && gcc "$W/code.o" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/code.bin" 2>/dev/null; then
    ( cd "$W" && timeout -k 5 5s ./code.bin < /dev/null > code.m4 2>&1 ); c4=$?; else c4=NOBUILD; fi
for m in m3 m4; do rc=$c3; [ "$m" = m4 ] && rc=$c4
    if [ "$rc" = 124 ] || [ "$rc" = NOBUILD ]; then FAIL=$((FAIL+1)); echo "  ⛔ code $m: $([ "$rc" = 124 ] && echo HANG || echo NOBUILD) (rc=$rc)"
    else PASS=$((PASS+1)); echo "  ✅ code $m: exits (rc=$rc) -- the stream's one missing byte is the unit-2 raw-record association, a named sibling defect"; fi
done
grep -q '^a$' "$W/w_input.m3" || { FAIL=$((FAIL+1)); echo "  ⛔ w_input m3: the INPUT control arm did not echo the piped line (the cure must not touch INPUT)"; }
echo "------------------------------------------------------------"
if [ "$FAIL" = 0 ]; then echo "GATE PASS(0) [$G]: $PASS of $GRADED gradings green (6 witnesses x 2 modes vs sbl -bf; INPUT control arm echoes)"; exit 0
else echo "GATE FAIL(1) [$G]: $FAIL red of $GRADED gradings"; exit 1; fi
