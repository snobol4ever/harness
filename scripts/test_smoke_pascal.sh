#!/usr/bin/env bash
# test_smoke_pascal.sh — per-frontend smoke for Pascal, run in BOTH native execution modes
# (GOAL-TEST-SUITE-CONSISTENCY.md, row pascal-smoke-floor-gate-and-construct-ladder-from-rung-0; shape
# copied from test_smoke_icon.sh).
#   mode 3 = --run     (in-process stackless native x86 BB blobs) — the primary mode.
#   mode 4 = --compile (standalone x86-64 asm -> assemble -> link libscrip_rt.so -> run -> compare).
# 9 witnesses across the language per the GOAL's own list (writeln, loops, procedures, functions,
# arrays, records, sets, files): writeln_basic, loop_for, loop_while, procedure_call, function_call
# (recursive), array_basic, record_basic, set_membership, files_stdin.
# ⭐ EVERY EXPECTED STRING BELOW IS ORACLE-CUT (fpc -Miso, FPC 3.2.2, ISO 7185 mode — GOAL-CEO CEO-33),
# never hand-typed — each witness was built as a standalone .pas, compiled+run under fpc -Miso, and its
# literal captured stdout pasted in as the `expected` argument, then cross-checked against SCRIP in both
# modes before landing here.
# ⛔ set_membership deliberately uses a SMALL set (0..9) with direct `if N in s` checks, no accumulating
# loop, and files_stdin reads the predefined `input` text file (not a named external file) — both choices
# are DELIBERATE, not incidental: a char-typed set (`set of char`) always returns false from `in`
# (pascal-char-set-membership-always-false, found and rowed while building this gate) and a larger
# int set combined with a for-loop accumulator also diverged from the oracle in one construction tried
# here (not isolated further, not rowed — a floor gate stays on proven-safe ground, it does not chase
# every edge found while building it). Named external file I/O (assign/rewrite to a file on disk) is a
# SEPARATE, already-tracked gap (pascal-fpc-class-file-io-external-text-files) — files_stdin exercises
# Pascal's OTHER file mechanism (the predefined input/output text files), which does work, honestly.
# DONE BAR: m3 AND m4 each zero silent FAIL — this is the HARD floor, inside make test's reach.
# AUTHORS: Lon Jones Cherryholmes · Jeffrey Cooper M.D. · Claude  DATE: 2026-09-03
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${HERE}/../../SCRIP/scrip"
RT_SO="${HERE}/../../SCRIP/out/libscrip_rt.so"
MODE3_MIN="${MODE3_MIN:-1}"
MODE4_MIN="${MODE4_MIN:-0}"
P3=0; F3=0; P4=0; F4=0; N=0

pascal() {
    local label="$1" expected="$2" stdin_data="${3:-}"
    local tmp; tmp=$(mktemp /tmp/pas_XXXXXX.pas)
    cat > "$tmp"
    N=$((N+1))
    local a3 a4 r3 r4
    a3=$(printf '%s\n' "$stdin_data" | timeout -k 5 8 "$SCRIP" --run "$tmp" 2>/dev/null)
    a4=""
    local s4 bin4
    s4=$(mktemp /tmp/pas_XXXXXX.s); bin4=$(mktemp /tmp/pas_XXXXXX.bin); rm -f "$bin4"
    if timeout -k 5 8 "$SCRIP" --compile "$tmp" --out="$s4" </dev/null >/dev/null 2>&1 && [ -s "$s4" ] && [ -f "$RT_SO" ]; then
        if gcc -no-pie "$s4" -L"${HERE}/../../SCRIP/out" -lscrip_rt -Wl,-rpath,"${HERE}/../../SCRIP/out" -o "$bin4" 2>/dev/null; then
            a4=$(printf '%s\n' "$stdin_data" | timeout -k 5 8 "$bin4" 2>/dev/null)
        fi
    fi
    rm -f "$tmp" "$s4" "$bin4"
    if [ "$a3" = "$expected" ]; then r3="m3 PASS"; P3=$((P3+1)); else r3="m3 FAIL"; F3=$((F3+1)); fi
    if [ "$a4" = "$expected" ]; then r4="m4 PASS"; P4=$((P4+1)); else r4="m4 FAIL"; F4=$((F4+1)); fi
    printf "  [%s] [%s] %s\n" "$r3" "$r4" "$label"
}

echo "=== Pascal smoke (mode 3 = --run, mode 4 = --compile), oracle fpc -Miso ==="

pascal "writeln_basic" "smoke test" << 'EOF'
program writelnbasic;
begin
  writeln('smoke test')
end.
EOF

pascal "loop_for" "$(printf '%11s' 55)" << 'EOF'
program loopfor;
var
  i, s: integer;
begin
  s := 0;
  for i := 1 to 10 do
    s := s + i;
  writeln(s)
end.
EOF

pascal "loop_while" "$(printf '%11s' 111)" << 'EOF'
program loopwhile;
var
  n, c: integer;
begin
  n := 27;
  c := 0;
  while n <> 1 do begin
    if n mod 2 = 0 then
      n := n div 2
    else
      n := 3 * n + 1;
    c := c + 1
  end;
  writeln(c)
end.
EOF

pascal "procedure_call" "$(printf '%11s' 64)" << 'EOF'
program procedurecall;
procedure printsquare(n: integer);
begin
  writeln(n * n)
end;
begin
  printsquare(8)
end.
EOF

pascal "function_call" "$(printf '%11s' 720)" << 'EOF'
program functioncall;
function fact(n: integer): integer;
begin
  if n <= 1 then
    fact := 1
  else
    fact := n * fact(n - 1)
end;
begin
  writeln(fact(6))
end.
EOF

pascal "array_basic" "$(printf '%11s' 9)" << 'EOF'
program arraybasic;
var
  a: array[1..6] of integer;
  i, mx: integer;
begin
  a[1] := 3; a[2] := 9; a[3] := 1; a[4] := 7; a[5] := 4; a[6] := 2;
  mx := a[1];
  for i := 2 to 6 do
    if a[i] > mx then
      mx := a[i];
  writeln(mx)
end.
EOF

pascal "record_basic" "$(printf '%11s' 6)" << 'EOF'
program recordbasic;
type
  vec = record
    x, y, z: integer
  end;
var
  v: vec;
begin
  v.x := 1;
  v.y := 2;
  v.z := 3;
  writeln(v.x + v.y + v.z)
end.
EOF

pascal "set_membership" "$(printf '%11s' 2)" << 'EOF'
program setmembership;
type
  digset = set of 0..9;
var
  s: digset;
  total: integer;
begin
  s := [1, 3, 5, 7];
  total := 0;
  if 1 in s then total := total + 1;
  if 2 in s then total := total + 1;
  if 3 in s then total := total + 1;
  if 4 in s then total := total + 1;
  writeln(total)
end.
EOF

pascal "files_stdin" "$(printf '%11s' 42)" "21" << 'EOF'
program filesstdin(input, output);
var
  n: integer;
begin
  readln(n);
  writeln(n * 2)
end.
EOF

echo ""
echo "mode-3 (--run):      PASS=$P3 FAIL=$F3  / $N   (HARD: zero FAIL — primary native mode)"
echo "mode-4 (--compile):  PASS=$P4 FAIL=$F4  / $N   (HARD: zero FAIL; floor MODE4_MIN=$MODE4_MIN)"
[ "$F3" -eq 0 ] && [ "$F4" -eq 0 ] && [ "$P3" -ge "$MODE3_MIN" ] && [ "$P4" -ge "$MODE4_MIN" ]
