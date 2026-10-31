#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_gc_a_poll_site_tests_the_pending_flag_before_calling_the_leaf.sh -- EVERY EMITTED POLL SITE TESTS g_gc_pending IN
# LINE AND SKIPS THE CALL WHEN NOTHING IS PENDING (ceo 2026-09-25, CEO-1251). The poll helpers in x86_asm.h wrap their body
# (the bare rt_gc_poll_asm call with its g_rtccb veneer, or a rooted spill + rt_gc_point_arr_c + reload) in x86_gc_gate: push rax,
# load the flag's address (GOT in mode 4, absolute in mode 3), load the dword, test, pop rax, and a forward je over the body --
# a numeric local label in the text medium, a computed rel8/rel32 over the record string in the binary medium. claws5 spent 8.7%
# of its cycles in the leaf plus its PLT and the veneer's seven memory ops per site. THE TRIGGER IS EQUIVALENT: the allocator
# sets g_gc_pending at the pacing-line crossing under BOTH policies (gc_heap.c: the gc_line_paced() guards are gone and
# g_hp_fr.line is the line always), so the skipped leaf's own line test never saw anything the flag did not -- porter at the
# shipped arena collects 1611 times with and without the gate.
# FOUR ARMS: (1) x86_asm.h's poll helpers all go through x86_gc_gate; (2) a witness's .s carries one pending-flag load per poll
# call of every form (rt_gc_poll_asm, rt_gc_poll, rt_gc_point_arr_c) and one numeric local label per load; (3) THE SLOW PATH IS
# LIVE: the witness at the shipped arena reports collections > 0 on its own [GC-EXERCISE] line in m3 and m4; (4) the witness
# prints its oracle-cut lines in both modes at the shipped arena. EXIT 0 all arms; 1 a red (named); 2 REFUSED.
# THE WITNESS LOOPS 40,000 TIMES (cto 2026-10-17): at 4,000 it allocated 862,400 bytes under the shipped 1,024 KB window once the
# runtime leaves got leaner, so arm (3) read collections=0 in both modes with grew=0; at 40,000 it collects 12 times, grew=0.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "REFUSED(2): correctness oracle missing ($SBL)"; exit 2; }
[ -x "$ROOT/scrip" ] || { echo "REFUSED(2): $ROOT/scrip not built"; exit 2; }
X="$ROOT/src/templates/x86/x86_gc.cpp"
red=0
nh=$(grep -o 'x86_gc_gate(' "$X" | wc -l); nhelp=$(grep -c -E '^(static )?std::string x86_rt_gc_poll' "$X")
[ "$nh" -ge 8 ] && [ "$nhelp" -ge 8 ] && echo "ok  x86_gc.cpp: $nhelp poll helpers, $nh gate uses" || { echo "RED: x86_gc.cpp has $nhelp poll helpers and $nh x86_gc_gate uses (want >= 8 each)"; red=1; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/churn.sno" <<'SNO'
        T = TABLE()
        S = 'the quick brown fox jumps over the lazy dog'
        N = 0
LOOP    N = LT(N, 40000) N + 1                          :F(DONE)
        S BREAK(' ') $ W1 ' ' BREAK(' ') $ W2
        T[W1] = T[W1] + 1
        X = W1 '-' W2 '-' N
        S = SUBSTR(S, 2) SUBSTR(S, 1, 1)                :(LOOP)
DONE    OUTPUT = T['the'] ' ' T['quick'] ' ' SIZE(X) ' ' X
END
SNO
"$SBL" $(sbl_lang_flags) "$W/churn.sno" < /dev/null > "$W/churn.ref" 2>&1 || true
[ -s "$W/churn.ref" ] || { echo "REFUSED(2): the oracle printed nothing for the witness"; exit 2; }
( cd "$W" && "$ROOT/scrip" --compile --out="$W/churn.s" churn.sno < /dev/null > /dev/null 2>&1 ) || { echo "RED: churn.sno did not compile"; exit 1; }
loads=$(grep -c 'g_gc_pending@GOTPCREL' "$W/churn.s"); calls=$(grep -cE 'call +(rt_gc_poll_asm|rt_gc_poll|rt_gc_point_arr_c|rt_gc_point_arr_probe_c)($|@)' "$W/churn.s"); lbls=$(grep -c '^1:' "$W/churn.s"); jes=$(grep -c 'je 1f' "$W/churn.s")
[ "$calls" -gt 0 ] && [ "$loads" -eq "$calls" ] && [ "$lbls" -eq "$calls" ] && [ "$jes" -eq "$calls" ] && echo "ok  every poll form is gated: $calls poll calls, $loads flag loads, $jes skips, $lbls landing labels" || { echo "RED: poll calls=$calls flag loads=$loads skips=$jes labels=$lbls (want all equal and > 0)"; red=1; }
gcc "$W/churn.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/churn.bin" 2>/dev/null || { echo "RED: churn.s did not link"; exit 1; }
for M in m3 m4; do
    if [ "$M" = m3 ]; then ( cd "$W" && SCRIP_GC_EXERCISE=1 timeout -k 5 60 "$ROOT/scrip" churn.sno < /dev/null > "$W/churn.$M" 2> "$W/churn.$M.err" ); else ( cd "$W" && SCRIP_GC_EXERCISE=1 timeout -k 5 60 "./churn.bin" < /dev/null > "$W/churn.$M" 2> "$W/churn.$M.err" ); fi
    nc=$(grep -o 'collections=[0-9]*' "$W/churn.$M.err" | head -1 | cut -d= -f2)
    [ -n "$nc" ] && [ "$nc" -gt 0 ] && echo "ok  $M: the slow path is live -- collections=$nc at the shipped arena" || { echo "RED $M: collections=${nc:-unread} at the shipped arena -- the gate never reaches the leaf"; red=1; }
    cmp -s "$W/churn.$M" "$W/churn.ref" && echo "ok  $M = oracle" || { echo "RED $M differs from the oracle:"; diff "$W/churn.ref" "$W/churn.$M" | head -6; red=1; }
done
[ "$red" -eq 0 ] && { echo "GATE OK: every poll site tests the pending flag in line, the leaf is still reached when a collection is due, and the witness matches the oracle in both modes"; exit 0; }
echo "GATE FAILED: see the RED lines above"; exit 1
