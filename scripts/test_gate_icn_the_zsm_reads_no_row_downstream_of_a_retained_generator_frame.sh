#!/usr/bin/env bash
# test_gate_icn_the_zsm_reads_no_row_downstream_of_a_retained_generator_frame.sh -- THE ZSM EXPECTATION IS THE PLAN'S COLUMN (cto ARCH-ICON-RTX.md section 11.9, 2026-10-29; ceo CEO-1888; row
# icon-the-zsm-reads-a-constant-delta-aexp-run-through-a-scan-bodys-write-argument-chain-with-the-output-right-the-plans-declared-depth-and-the-machine-disagree, found by the cfo 2026-10-25).
# THE WITNESS: procedure g(); suspend 1 | 2; end, procedure main(); every g() do write("x"); end. Its output is right, and under SCRIP_ZSM=1 SCRIP_ZSM_ALL=1 it printed 14 [ZSM-AEXP]/[ZSM-DISC] rows, every one
# with delta 240 = g's frame RETAINED on the spine (a generator's gamma leaves rsp where the callee left it): the Icon regime reads its operands through rbp cells, so the plan places no rsp-relative
# operand downstream of that gamma and the instrument's RSP - RSP0 == op_zdepth was the wrong expectation there. THE CURE: the plan's row (zeta_plan_t.slid, filled by zd_place for a spine_cells
# plan) records the nodes that run downstream of a call whose callee frame is retained (PR_RETAINING_TARGET, PR_GENERATOR_CALLEE, PR_RETAINING_CALLEE), x86_rsp_slide_known() is deleted, and the ZSM
# event (x86_zsm_ev, x86_zsm_disc) and x86_frame_off read the column as op_zslid; the runtime's DISC check skips an expectation of -1 as the AEXP check always has.
# ARMS: (1) mode 3, SCRIP_ZSM=1 SCRIP_ZSM_ALL=1: no [ZSM-AEXP] or [ZSM-DISC] row and the output equals the ref; (2) mode 4 (--compile with the same switches, assembled, linked, run): the same;
# (3) the same two arms on a second program, a scan whose body runs the generator call and whose loop is followed by plain statements, so the column does not leak into the rest of the procedure's output.
# RED BEFORE (measured 2026-10-29 on SCRIP 74f759a07, the commit before the cure): arm 1 reads 14 rows on the witness, arm 2 the same rows from the compiled binary, arm 3 reads rows too.
# The instrument is not blinded: the cure's negative control (a wrong depth planted in a scratch worktree, never in src, CEO-1680) printed SNOBOL4 rows for c1.sno 0 -> 6 and c2.sno 0 -> 16, and in Icon
# only at the nodes upstream of the call. rc 0 every arm holds; 1 an arm failed; 2 could not measure (no ./scrip, no libscrip_rt.so, no gcc).
set -u
GATE_NAME=test_gate_icn_the_zsm_reads_no_row_downstream_of_a_retained_generator_frame
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SC="$ROOT/SCRIP"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SC/scrip" ] && [ -f "$SC/out/libscrip_rt.so" ] || refuse "no built ./scrip and out/libscrip_rt.so under $SC (run make)"
command -v gcc > /dev/null 2>&1 || refuse "no gcc to assemble and link the mode-4 binary"
T="$(mktemp -d /tmp/zsm_icn_retained_XXXXXX)"; trap 'rm -rf "$T"' EXIT
fails=0; n=0
ck() { n=$((n+1)); if eval "$2"; then echo "  ok   $1"; else fails=$((fails+1)); echo "  FAIL $1"; fi; }
printf 'procedure g(); suspend 1 | 2; end\nprocedure main(); every g() do write("x"); end\n' > "$T/w1.icn"
printf 'x\nx\n' > "$T/w1.ref"
printf 'procedure g(); suspend 1 | 2; end\nprocedure main(); "abc" ? { every g() do write(&subject); write("scan") }; write("after"); every g() do write("y"); write("end"); end\n' > "$T/w2.icn"
printf 'abc\nabc\nscan\nafter\ny\ny\nend\n' > "$T/w2.ref"
rows() { grep -c 'ZSM-AEXP\|ZSM-DISC' "$1"; }
m3() { ( cd "$T" && SCRIP_ZSM=1 SCRIP_ZSM_ALL=1 timeout -k 5 120 "$SC/scrip" "$T/$1.icn" < /dev/null > "$T/$1.m3.out" 2> "$T/$1.m3.err" ); }
m4() {
    ( cd "$T" && SCRIP_ZSM=1 SCRIP_ZSM_ALL=1 timeout -k 5 120 "$SC/scrip" --compile --out="$T/$1.s" "$T/$1.icn" < /dev/null > /dev/null 2> "$T/$1.m4.cerr" ) || return 2
    gcc -c "$T/$1.s" -o "$T/$1.o" 2> /dev/null && gcc "$T/$1.o" -L"$SC/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$SC/out" -o "$T/$1.bin" 2> /dev/null || return 2
    SCRIP_ZSM=1 SCRIP_ZSM_ALL=1 timeout -k 5 60 "$T/$1.bin" < /dev/null > "$T/$1.m4.out" 2> "$T/$1.m4.err"; return 0
}
for w in w1 w2; do
    m3 "$w"; m4 "$w"; r4=$?
    [ "$r4" = 2 ] && refuse "$w: the mode-4 compile, assemble or link did not run: $(head -c 300 "$T/$w.m4.cerr")"
    ck "$w mode 3: no ZSM-AEXP or ZSM-DISC row ($(rows "$T/$w.m3.err") read) and the output equals the ref" '[ "$(rows "$T/$w.m3.err")" = 0 ] && cmp -s "$T/$w.m3.out" "$T/$w.ref"'
    ck "$w mode 4: no ZSM-AEXP or ZSM-DISC row ($(rows "$T/$w.m4.err") read) and the output equals the ref" '[ "$(rows "$T/$w.m4.err")" = 0 ] && cmp -s "$T/$w.m4.out" "$T/$w.ref"'
done
if [ "$fails" = 0 ]; then echo "✅ GATE PASS [$GATE_NAME]: $n of $n arms hold"; exit 0; fi
echo "⛔ GATE FAIL [$GATE_NAME]: $fails of $n arm(s) failed"; for w in w1 w2; do grep -m2 'ZSM-' "$T/$w.m3.err" 2> /dev/null | sed "s/^/      $w m3: /" | cut -c1-200; done; exit 1
