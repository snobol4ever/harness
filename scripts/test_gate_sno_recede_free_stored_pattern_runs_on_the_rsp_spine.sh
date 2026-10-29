#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_recede_free_stored_pattern_runs_on_the_rsp_spine.sh -- A PRE-COMPILED PATTERN CARRIES NO RBP ACTIVATION FRAME WHEN
# THE RSP SPINE SUFFICES (Lon 2026-09-30 07:2x CDT, in-chat to the ceo, verbatim: "Ensure that pre-compiled patterns do no carry the
# extra weight of an RBP activation frame when just the RSP spine will suffice."; GOAL-CEO.md CEO-1366; the BB FRAME-PLACEMENT
# CRITERION, RULES.md, Lon 2026-08-27: RESULT/LOCALS stay on the RSP spine iff every consumer reaches them at a fixed compile-time
# offset on every path, and move to an RBP frame the moment a gamma->beta window with unbounded activity between can intervene).
#
# THE WITNESS: p1 is recede-free and holds no value -- POS, LIT, SPAN, ANY, LEN, BREAK, LIT and RPOS: no box in it can be receded into
# after gamma (a beta into any of them fails straight through to omega) and none keeps a DESCR, so its PAT$ thunk has no gamma->beta
# window, nothing for the collector to see, and needs no frame, no map cell and no zero-fill. p2 holds an alternation and p3 an ARBNO,
# each a recede window, so their thunks keep the frame -- the control: a framed-needed shape run frameless is this gate's red as much
# as a recede-free one framed. NOT GRADED HERE, the row's next steps: a pattern whose frame holds only RAW scratch (SPAN, BREAK and
# ANY save the cursor through rbp today) or a pending assignment's DESCR keeps its frame today by the EMITTER's placement, not by any
# collector need -- the collector visits a tagged DESCR cell on the RSP spine by its tag (gc_walk_words; ARCH-GC-COMPILE-TIME-FRAME-
# MAPS.md section 2b, the spine carries its own types; Lon's question of 2026-09-30, answered by measurement). The thunks are
# read from the mode-4 .s by their assembler-local faces .LTp<n> in source order (p1 = .LTp0, p2 = .LTp1, p3 = .LTp2); a thunk is FRAMED when the
# text between .LTp<n> and .LTp<n>_omega carries "mov rbp, rsp". The program's output must equal sbl -bf in both modes whatever the
# frames read. MEASURED RED at de0302f83: every thunk is framed (PAT$0 carries push rbp / mov rbp, rsp / sub rsp, 88, the map cell and
# the zero-fill). Exit 0 = p1 frameless, p2 and p3 framed, both modes = the oracle; 1 = otherwise; 2 = cannot measure.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; G="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: cannot load lib_oracle_flags.sh"; exit 2; }
SBL="$(sbl_correctness_bin)" || { echo "⛔ GATE REFUSE(2) [$G]: no SPITBOL correctness oracle"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/w.sno" <<'SNO'
        p1 = POS(0) 'ab' SPAN('cd') ANY('xy') LEN(1) BREAK('!') '!' RPOS(0)
        p2 = 'ab' | SPAN('cd')
        p3 = ARBNO('a' | 'b') 'c'
        'abccdxq..!' p1                                 :F(n1)
        OUTPUT = 'ok1'
n1      'abccdxq..' p1                                  :S(bad1)
        OUTPUT = 'no1'
bad1    'ccd' p2                                        :F(n2)
        OUTPUT = 'ok2'
n2      'ababc' p3                                      :F(n3)
        OUTPUT = 'ok3'
n3      'abd' p3                                        :S(bad3)
        OUTPUT = 'no3'
bad3
END
SNO
(cd "$T" && timeout -k 5 20 "$SBL" $(sbl_lang_flags) w.sno < /dev/null > ref 2>&1); [ -s "$T/ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle printed nothing for the witness"; exit 2; }
timeout -k 5 20 "$SCRIP" "$T/w.sno" < /dev/null > "$T/m3" 2>&1
timeout -k 5 20 "$SCRIP" --compile --out="$T/w.s" "$T/w.sno" < /dev/null > "$T/cc.err" 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: mode-4 compile failed: $(head -1 "$T/cc.err" | cut -c1-120)"; exit 2; }
gcc -m64 -no-pie "$T/w.s" -Wl,-rpath,"$ROOT/out" -L"$ROOT/out" -lscrip_rt -lm -lpthread -o "$T/w.bin" 2>> "$T/cc.err" || { echo "⛔ GATE REFUSE(2) [$G]: mode-4 link failed"; exit 2; }
timeout -k 5 20 "$T/w.bin" < /dev/null > "$T/m4" 2>&1
RC=0
for m in m3 m4; do cmp -s "$T/ref" "$T/$m" && echo "  PASS $m = oracle" || { RC=1; echo "  FAIL $m differs from the oracle: $(diff "$T/ref" "$T/$m" | grep -m2 '^[<>]' | tr '\n' ' ' | cut -c1-160)"; }; done
framed() { sed -n "/^\.LTp$1:/,/^\.LTp$1_ω:/p" "$T/w.s" | grep -c 'mov *rbp, *rsp'; }
for k in 0 1 2; do grep -q "^\.LTp$k:" "$T/w.s" || { echo "⛔ GATE REFUSE(2) [$G]: no .LTp$k thunk in the .s (the witness has three stored patterns)"; exit 2; }; done
f0=$(framed 0); f1=$(framed 1); f2=$(framed 2)
[ "$f0" -eq 0 ] && echo "  PASS PAT\$0 (recede-free: POS LIT SPAN ANY LEN BREAK mark RPOS) runs on the RSP spine, no frame" || { RC=1; echo "  FAIL PAT\$0 is recede-free and still carves an RBP frame ($f0 frame prologue(s))"; }
[ "$f1" -ge 1 ] && echo "  PASS PAT\$1 (an alternation, a recede window) keeps its frame" || { RC=1; echo "  FAIL PAT\$1 holds an alternation and runs frameless"; }
[ "$f2" -ge 1 ] && echo "  PASS PAT\$2 (an ARBNO, a recede window) keeps its frame" || { RC=1; echo "  FAIL PAT\$2 holds an ARBNO and runs frameless"; }
[ "$RC" = 0 ] && echo "GATE PASS(0) [$G]: the recede-free stored pattern runs on the RSP spine, the recede windows keep their frames, both modes = sbl -bf" || echo "⛔ GATE FAIL(1) [$G]: a stored pattern's frame placement contradicts the criterion, or the match differs from the oracle"
exit $RC
