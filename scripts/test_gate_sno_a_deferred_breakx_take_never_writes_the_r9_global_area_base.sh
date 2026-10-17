#!/usr/bin/env bash
# test_gate_sno_a_deferred_breakx_take_never_writes_the_r9_global_area_base.sh -- a deferred BREAKX whose argument calls an
# undefined function fails its statement and the program runs on, as sbl -bf does, in both modes. Row
# snobol4-a-deferred-breakx-whose-argument-calls-an-undefined-function-crashes-both-modes (cto 2026-10-09). THE BRACKET: the fault was
# the NEXT statement's assignment V = 'b', n25_assign_bx's mov qword ptr [r9], rax with r9 = 0 (both modes, SIGSEGV at a null
# address). r9 is the pinned base of the global-variable area (RTCC_GLOBAL_R9_GVA; the veneer re-establishes it after a call), and
# bb_match_breakx.cpp's deferred arms loaded the take's length into r9d as scratch before copying it to edx; on the take's error
# road (js to omega, F undefined) no later call ran, so r9 left the statement holding a length. The cure loads the take's pointer
# and length straight into rsi and edx, and the template never writes r9.
# ARMS: (1) the witness in mode 3 prints sbl's lines, rc 0; (2) the same in mode 4; (3) mode 3 under SCRIP_GC_STRESS=1 the same;
# (4) STATIC: bb_match_breakx.cpp never writes r9 (a mov, lea, pop or xor naming r9 or r9d as its destination; r8 is ordinary scratch).
# FAIL_ONCE=1 greps the static arm for rsi instead of r9, which the template does write, so arm 4 must red.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; G=sno_a_deferred_breakx_take_never_writes_the_r9_global_area_base
[ -x "$ROOT/scrip" ] || { echo "GATE REFUSED(2) [$G]: no $ROOT/scrip -- run make"; exit 2; }
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
SBL="${SBL:-/home/resources/x64/bin/sbl}"; [ -x "$SBL" ] || { echo "GATE REFUSED(2) [$G]: no sbl at $SBL"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/snobx.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
printf "        'ab' ? BREAKX(*F())\n        V = 'b'\n        OUTPUT = 'next'\n        'ab' ? BREAKX(*F()) 'x'\n        V2 = 'c'\n        OUTPUT = 'again'\n        'ab' ? SPAN(*G())\n        W = 'd'\n        OUTPUT = 'after span ' V V2 W\nEND\n" > "$W/w.sno"
( cd "$W" && timeout -k 5 10 "$SBL" -bf "$W/w.sno" < /dev/null 2>/dev/null ) | grep -v '^$' > "$W/ref"
[ -s "$W/ref" ] || { echo "GATE REFUSED(2) [$G]: sbl printed nothing"; exit 2; }
( cd "$W" && timeout -k 5 60 "$ROOT/scrip" --compile "$W/w.sno" < /dev/null > "$W/w.s" 2>/dev/null ) && gcc -no-pie "$W/w.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/w.bin" 2>/dev/null || { echo "GATE REFUSED(2) [$G]: the witness does not compile or link"; exit 2; }
bad=0
arm() {
    local n="$1" label="$2"; shift 2
    ( cd "$W" && "$@" < /dev/null > "$W/$n.out" 2>/dev/null ); local rc=$?
    grep -v '^\[GC-' "$W/$n.out" | grep -v '^$' > "$W/$n.txt"
    if [ $rc -eq 0 ] && cmp -s "$W/$n.txt" "$W/ref"; then echo "  ok  ($n) $label: rc 0, sbl's lines"; else echo "  RED ($n) $label: rc=$rc, the output differs from sbl's"; diff "$W/ref" "$W/$n.txt" | head -4; bad=1; fi
}
arm 1 "mode 3" timeout -k 5 10 "$ROOT/scrip" "$W/w.sno"
arm 2 "mode 4" timeout -k 5 10 "$W/w.bin"
arm 3 "mode 3 under SCRIP_GC_STRESS=1" env SCRIP_GC_STRESS=1 timeout -k 5 30 "$ROOT/scrip" "$W/w.sno"
REG='r9d?'; [ "${FAIL_ONCE:-0}" = 1 ] && REG='rsi'
hits=$(grep -nE 'x86\("(mov|lea|pop|xor)", "'"$REG"'"' "$ROOT/src/templates/bb/bb_match_breakx.cpp" | wc -l)
if [ "$hits" -eq 0 ]; then echo "  ok  (4) static: bb_match_breakx.cpp never writes r9"; else echo "  RED (4) static: bb_match_breakx.cpp writes $REG at $hits site(s):"; grep -nE 'x86\("(mov|lea|pop|xor)", "'"$REG"'"' "$ROOT/src/templates/bb/bb_match_breakx.cpp" | head -4; bad=1; fi
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: a deferred BREAKX's error road leaves r9 the global area's base and the program runs on as sbl does (tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: a deferred BREAKX's take disturbs r9 or the program does not run on as sbl does (tree SCRIP=$TREE)"; exit 1
