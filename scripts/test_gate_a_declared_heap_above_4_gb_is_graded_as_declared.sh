#!/usr/bin/env bash
# test_gate_a_declared_heap_above_4_gb_is_graded_as_declared.sh -- a heap_kb above 4 GB is a declaration like any other (R-2083; NO FIXED LIMITS). ProPuzzles' euler10 and euler24 declare 10 GB
# (9765625 KB), and ./scrip -d9765625k runs: the runtime's hard cap (-d) has NO 4 GB window, its only bound is the collector's page map, which holds each block's offset in 8-byte units in 32 bits, so the
# reservation stops at 32 GB (gc_heap.c names it). The 4194304 KB ceiling the harness refused with ("the ceiling SCRIP_HEAP_KB itself refuses") was copied from the env-var windows of the INITIAL heap
# window (SCRIP_HEAP_KB 64..4096*1024 KB, SCRIP_HEAP_MB 1..4096, -i), which bound the window and never the cap, and the stack ceiling was the same number copied again. Now every window is the box's own
# (sysconf(_SC_PHYS_PAGES) * page size, never above the 32 GB the page map addresses) in the runtime and in the harness, and the three harness copies (lib_declared_arena.sh, corpus_suite_harness.py,
# util_arena_pin_census.py) are one derived number. ARMS. (1) the shell library accepts euler10's and euler24's 9765625 KB and a 5 GB stack, echoing them back; (2) corpus_suite_harness.py's validate_heap_kb and
# validate_stack_kb do the same; (3) the ceiling is the BOX'S and not absent: the library and the python validator agree on it, accept exactly it and refuse one KB past it with rc 2 naming the box (so
# deleting the check would read RED); (4) the runtime serves it: a trivial program runs rc 0 in m3 and m4 under -d9765625k, under -i5242880k -d9765625k and under SCRIP_HEAP_KB=5242880 (an initial window above
# 4 GB, committed lazily); (5) the runtime still REFUSES what it cannot serve and says why: a SCRIP_HEAP_KB window past the box, and a -d cap past 32 GB, both rc != 0 with the [ZHP] line naming the bound.
# NOT IN THIS GATE, MEASURED ONCE (the row's ledger): a program holding 6 GB live (six 1 GB strings, nice 19) completes under -d9765625k and overflows with error 204 under -d4194304k.
# rc 0 every arm holds; rc 1 an arm failed; rc 2 could not measure (no build, a box under 10 GB cannot hold euler10's declaration, no python3, no gcc).
set -u
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP"; exit 2; }
BIN="${SCRIP_BIN:-$ROOT/scrip}"; LIB="$(dirname "$BIN")/out"; [ -d "$LIB" ] || LIB="$ROOT/out"
[ -x "$BIN" ] || { echo "GATE REFUSED(2) [$G]: no $BIN -- run make"; exit 2; }
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc > /dev/null 2>&1 && command -v python3 > /dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc or python3 absent"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/heap4g.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
BOX="$(python3 -I -c 'import os; k = int(os.sysconf("SC_PHYS_PAGES")) * int(os.sysconf("SC_PAGE_SIZE")) // 1024; print(min(k, 33554432))')"
[ -n "$BOX" ] && [ "$BOX" -ge 10000000 ] 2> /dev/null || { echo "GATE REFUSED(2) [$G]: this box holds ${BOX:-?} KB, under the 9765625 KB euler10 declares -- nothing here can serve that declaration"; exit 2; }
printf 'entry,heap_kb,stack_kb\nhakank_swi_euler10,9765625,262144\nhakank_swi_euler24,9765625,262144\nfx_stack5g,262144,5242880\nfx_at_box,%s,262144\nfx_past_box,%s,262144\nfx_stack_past_box,262144,%s\n' "$BOX" "$((BOX + 1))" "$((BOX + 1))" > "$W/f.csv"
. "$HERE/lib_declared_arena.sh" || { echo "GATE REFUSED(2) [$G]: lib_declared_arena.sh unloadable"; exit 2; }
bad=0
for e in hakank_swi_euler10 hakank_swi_euler24; do
  out="$(declared_arena_kb "$W/f.csv" "$e" 2> "$W/lib.err")"; rc=$?
  if [ "$rc" = 0 ] && [ "$out" = 9765625 ]; then echo "  ok   (1) the shell library accepts $e's heap_kb=9765625 and echoes it"; else echo "  RED  (1) the shell library on $e: rc=$rc out='$out' $(head -c 200 "$W/lib.err")"; bad=1; fi
done
out="$(declared_stack_kb "$W/f.csv" fx_stack5g 2> "$W/lib.err")"; rc=$?
if [ "$rc" = 0 ] && [ "$out" = 5242880 ]; then echo "  ok   (1) the shell library accepts a 5 GB stack_kb and echoes it"; else echo "  RED  (1) the shell library on a 5 GB stack: rc=$rc out='$out' $(head -c 200 "$W/lib.err")"; bad=1; fi
cat > "$W/py.py" <<'EOF'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("csh", sys.argv[1]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
box = int(sys.argv[2])
def run(fn, raw):
    try:
        return "ok", fn(raw, "fx")
    except SystemExit as e:
        return "exit%s" % e.code, None
print("heap_euler", *run(m.validate_heap_kb, "9765625"))
print("stack_5g", *run(m.validate_stack_kb, "5242880"))
print("heap_at_box", *run(m.validate_heap_kb, str(box)))
print("heap_past_box", *run(m.validate_heap_kb, str(box + 1)))
print("stack_past_box", *run(m.validate_stack_kb, str(box + 1)))
print("ceilings", m.GC_HEAP_KB_MAX, m.GC_STACK_KB_MAX)
EOF
python3 -I "$W/py.py" "$HERE/corpus_suite_harness.py" "$BOX" > "$W/py.out" 2> "$W/py.err"; prc=$?
[ "$prc" = 0 ] || { echo "GATE REFUSED(2) [$G]: the python validators could not be loaded: $(head -c 300 "$W/py.err")"; exit 2; }
if grep -q '^heap_euler ok 9765625$' "$W/py.out" && grep -q '^stack_5g ok 5242880$' "$W/py.out"; then echo "  ok   (2) validate_heap_kb accepts 9765625 and validate_stack_kb a 5 GB stack"; else echo "  RED  (2) the python validators: $(tr '\n' ';' < "$W/py.out" | cut -c1-300)"; bad=1; fi
out="$(declared_arena_kb "$W/f.csv" fx_at_box 2> /dev/null)"; rc=$?; out2="$(declared_arena_kb "$W/f.csv" fx_past_box 2> "$W/past.err")"; rc2=$?; out3="$(declared_stack_kb "$W/f.csv" fx_stack_past_box 2> "$W/spast.err")"; rc3=$?
if [ "$rc" = 0 ] && [ "$out" = "$BOX" ] && [ "$rc2" = 2 ] && grep -q 'this box can hold' "$W/past.err" && [ "$rc3" = 2 ] && grep -q 'this box can hold' "$W/spast.err" && [ "$DECLARED_ARENA_MAX_KB" = "$BOX" ] && [ "$DECLARED_STACK_MAX_KB" = "$BOX" ]; then
  echo "  ok   (3) the shell library's ceiling is the box's $BOX KB: it accepts exactly that and refuses one KB past it, heap and stack, rc 2 naming the box"
else echo "  RED  (3) the shell library's ceiling: at_box rc=$rc out='$out', past rc=$rc2, stack past rc=$rc3, DECLARED_ARENA_MAX_KB=$DECLARED_ARENA_MAX_KB DECLARED_STACK_MAX_KB=$DECLARED_STACK_MAX_KB, box=$BOX"; bad=1; fi
if grep -q "^heap_at_box ok $BOX\$" "$W/py.out" && grep -q '^heap_past_box exit2 None$' "$W/py.out" && grep -q '^stack_past_box exit2 None$' "$W/py.out" && grep -q "^ceilings $BOX $BOX\$" "$W/py.out"; then
  echo "  ok   (3) the python validators' ceiling is the same $BOX KB: accepted at it, rc 2 one KB past it"
else echo "  RED  (3) the python validators' ceiling: $(tr '\n' ';' < "$W/py.out" | cut -c1-300)"; bad=1; fi
printf '        OUTPUT = "ok"\nEND\n' > "$W/ok.sno"
"$BIN" --compile --out="$W/ok.s" "$W/ok.sno" < /dev/null > "$W/c.err" 2>&1 || { echo "GATE REFUSED(2) [$G]: the trivial program does not compile ($(head -c 160 "$W/c.err"))"; exit 2; }
gcc -o "$W/ok.bin" "$W/ok.s" -L"$LIB" -lscrip_rt -Wl,-rpath,"$LIB" -lm -lpthread > "$W/link.err" 2>&1 || { echo "GATE REFUSED(2) [$G]: the trivial program does not link ($(head -c 160 "$W/link.err"))"; exit 2; }
serve() { local tag="$1"; shift; local m3 m4
  m3="$(env "$@" timeout -k 5 60 "$BIN" $SW_ARGS "$W/ok.sno" < /dev/null 2>&1)"; local r3=$?
  m4="$(env "$@" timeout -k 5 60 "$W/ok.bin" $SW_ARGS < /dev/null 2>&1)"; local r4=$?
  if [ "$r3" = 0 ] && [ "$m3" = ok ] && [ "$r4" = 0 ] && [ "$m4" = ok ]; then echo "  ok   (4) m3 and m4 run rc 0 under $tag"; else echo "  RED  (4) under $tag: m3 rc=$r3 '$(printf '%s' "$m3" | head -c 150)'; m4 rc=$r4 '$(printf '%s' "$m4" | head -c 150)'"; bad=1; fi; }
SW_ARGS="-d9765625k"; serve "-d9765625k (a 10 GB hard cap)" A=1
SW_ARGS="-i5242880k -d9765625k"; serve "-i5242880k -d9765625k (a 5 GB initial window under a 10 GB cap)" A=1
SW_ARGS=""; serve "SCRIP_HEAP_KB=5242880 (a 5 GB initial window)" SCRIP_HEAP_KB=5242880
o1="$(SCRIP_HEAP_KB=$((BOX + 1)) timeout -k 5 60 "$BIN" "$W/ok.sno" < /dev/null 2>&1)"; r1=$?
o2="$(timeout -k 5 60 "$BIN" -d40000000k "$W/ok.sno" < /dev/null 2>&1)"; r2=$?
if [ "$r1" != 0 ] && printf '%s' "$o1" | grep -q '\[ZHP\] SCRIP_HEAP_KB=.*REFUSED' && [ "$r2" != 0 ] && printf '%s' "$o2" | grep -q '\[ZHP\].*32 GB'; then
  echo "  ok   (5) the runtime still refuses a window past the box and a cap past the page map's 32 GB, and names why"
else echo "  RED  (5) the refusals: window past the box rc=$r1 '$(printf '%s' "$o1" | head -c 140)'; cap past 32 GB rc=$r2 '$(printf '%s' "$o2" | head -c 140)'"; bad=1; fi
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2> /dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2> /dev/null || echo -DIRTY)"
if [ "$bad" = 0 ]; then echo "GATE PASS(0) [$G]: a declared heap above 4 GB is graded as declared (SCRIP $TREE, box $BOX KB)"; exit 0; fi
echo "GATE RED(1) [$G]: see the RED arms above (SCRIP $TREE)"; exit 1
