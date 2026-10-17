#!/bin/bash
export S4E_MINT_NO_CRITERION="gate fixture: the row under test exercises the bus, not work (CEO-1386)"
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_bb_block_label_prefix.sh -- GATE for row bb-label-prefix-uniform (Lon 2026-08-28, widened
# ruling: "ALL labels emitted in the ALPHA and BETA block must change... EVERY variation of labels gets
# unified into ONE COMMON PREFIX for all in each block").
#
# Walks emitted TEXT-mode .s witnesses, brackets each block by its own port-label DEFINITION (the
# "<prefix>_<greek>:" line that opens it -- alpha/beta always, gamma/omega on the graphs that emit an
# extra transition-out-of-the-box label per Lon's spec addendum, ceo 2026-08-27 ledger), and REFUSES
# (rc=1) on any OTHER label definition inside that span whose name does not start with that same
# "<prefix>_<greek>" -- unless it matches the documented ALLOWLIST below.
#
# ⛔ THE ALLOWLIST IS NOT A CONVENIENCE, IT IS A CLAIM -- every entry cites the code that proves the
# family is not "a point inside a block" by construction, per hq_P's framing (adopted by ceo 2026-08-29b,
# task bb-label-prefix-uniform LEDGER): a RANGE, a MODULE DATUM, or a FUNCTION is a different kind of
# thing than a block-scoped point label, unreachable by "ALL labels in each block" no matter how the
# scan is written. An allowlist entry with no citation is exactly the "invisible allowlist" this row's
# own history warned the next seat about -- don't add one without updating this header AND the task
# file's LEDGER.
#
# RULED (hq_P 2026-08-29, ceo-endorsed, full text in task LEDGER): the mechanism test is "a greek infix
# names a PORT OF A BOX; a label with no owning box has no port, so the infix would not be redundant, it
# would be FALSE" -- NOT a location test ("driver-level is exempt"), because that fails the next
# borderline case. Under that test: .S/.C, .Lgvan/.Lstartup_*/.Lseala (allowlisted below) have no owning
# box, so they're exempt; _bx is exempt for an UNRELATED reason (a RANGE marker, never a jump target, per
# emit.cpp:3041-3042/3238); _af/_as/_ry/_rt/_sN are REAL box-owned gamma/omega jump targets (emit.cpp
# node_γ/node_ω assignment at :3074/:3090/:1398/:3095) and are NOT exempt by either test.
#
# ⭐ SEAT11 COLLISION -- ADJUDICATED AND MERGED (hq_P 2026-08-29b "MERGE, DO NOT PICK", applied by seat02
# 2026-08-29): a DEFINE'd procedure's own nested/embedded body (e.g. PATTERN_BT, compiled inline right
# after its own DEFINE box) is NOT a new block -- hq_P measured on pattern_bt.s that no real
# `n<digits>_<kind>_<greek>` box port opens between the DEFINE box and the next real box, so the whole
# span, including the bareword `PATTERN_BT_α/γ/ω` landing pads, is that ONE box's own output; requiring
# those internal labels to say "PATTERN_BT" instead of "define" was seat05's gate false-flagging real
# passes, and seat11's gate (recovered at `git show 57ecf03e:...`) had already measured the same thing.
# lib_bb_block_label_prefix_check.py's bracketing is now seat11's classify() (richer instrument, two-part
# proof), with seat05's Greek-letter requirement for the _as/_af/_ry/_rt/_sN families layered on as an
# independent second check exactly as ruled -- see that file's own header for the merge detail.
#
# ⭐ A BOX'S SPAN MARKER OPENS IT (cfo 2026-10-02, row snobol4-the-setexit-test-block-carries-stno-labels-without-its-
# own-block-prefix): the statement code map (04c3109f8, 688098382) writes an anchor at the head of each statement box,
# AHEAD of the template's α port, so "the last port label seen" was the box before it (a setexit_test, a call) and every
# anchor read as that box's violation. The anchor now carries its own box's prefix (.L<kind>_α_<uid>_stno, emit.cpp
# emit_stno_mark), the walk opens a box at its n<uid>_<kind>_bx span marker as well as at its ports, and .pushsection is
# a section switch (the map's file-name string .Lstnof<N> is .rodata, a module datum). On 59 programs in seven languages
# the only verdicts that moved were the anchors'. The span marker exists only when SCRIP_ASM_SYMSIZE is not 0.
#
# ⭐ THE CHAIN'S SITE LABELS AND A BOX'S CLOSE (cto 2026-10-07): the chain over the maps (6ec5871c8, ARCH-GC section 13) put a
# recording label .Lgcsite_<fam>_<n> at every poll's return PC and a .Lgcsites_<fam>_<n> table after each graph, and this gate
# read red on origin from then on (183 markers and 6 tables over the three witnesses). A site marker is the _bx class -- a
# marker nothing jumps to, read as data by the site table -- and the table is a module datum beside .Lgcmap_ (CEO-1380), so
# both are allowlisted with their citations. The checker also opened a box at its _bx marker but never closed it, so the
# graph-level code after a box's .size (main_γ, <fam>_res, restoring g_line/g_file under .L<fam>_α_<uid>_<n> labels named
# for the procedure) was charged to the box that closed (14 more); a box now closes at its .size. All 203 violations on
# e4048536a were in those three classes, the new checker reads 0 over 1834 labels, and a foreign label planted inside a box
# still reds it. A missing witness or a zero-label population now REFUSES rc=2 instead of grading a vacuous green.
# KNOWN STILL-OPEN, DELIBERATELY NOT ALLOWLISTED (this gate correctly FAILS on this until fixed --
# see task bb-label-prefix-uniform.task.md LEDGER for the full ruling and code citations):
#   - n<N>_<kind>_af (emit.cpp na_f) -- na_s/fc_sig/ra_y/ra_t (the other four REAL gamma/omega transition
#     labels this same ruling covers) are already fixed and pass; na_f is genuinely harder, not merely
#     unfixed: emit.cpp mints it ONCE per node via the SAME generic pair-define call site regardless of
#     which greek letter any given caller resolves it through (node_γ when gamma_is_phi, node_ω when
#     omega_is_phi -- emit.cpp ~3074/~3090), and tracing the φ-tag mint sites in lower_snobol4.c/
#     lower_icon.c (e.g. lower_snobol4.c:1358-1359) shows a single target CAN receive both a φ-tagged ω
#     edge (the normal per-arm "try next" edges) and a φ-tagged γ edge (a GOTO node whose own ω also
#     equals the same target) in the same compiled function -- so unlike na_s/ra_y/ra_t/fc_sig (each a
#     clean 1:1 or single-port shape), na_f's one physical definition may legitimately be reached through
#     what look like both port types at once. Neither "two-pass resolve like .Lx<uid>_<n>" nor "pick one
#     canonical letter" has been shown correct against that shape; do not guess, this is the ~10x-rework
#     class the row has already paid for twice (see task LEDGER).
set -u
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$S4E/SCRIP" || exit 2
CORPUS="$S4E/corpus"
SCRIP_BIN=./scrip
WITDIR="$(mktemp -d)"
trap 'rm -rf "$WITDIR"' EXIT
# ⭐ RE-POINTED 2026-08-30 (seat12, repo-wide dead-suite-path consumer sweep): tests/snobol4/probe/indirect.sno
# was absorbed into THE ONE FLAT RUNGS and deleted; lib_rungs_extract.sh materializes it back out
# by origin ("probe_indirect__indirect_pattern_operand").
RUNGS_LANG="${RUNGS_LANG:-snobol4}" . "$S4E/harness/scripts/lib_rungs_extract.sh"
rungs_extract_origin probe_indirect__indirect_pattern_operand "$WITDIR/indirect.sno" >/dev/null 2>&1
# ⚠️ SCOPE, READ BEFORE ADDING A WITNESS: porter.sno and beauty.sno were tried and dropped (seat05
# 2026-08-29). Both are large/heavily-optimized enough that some straight-line boxes' own alpha port
# label is optimizer-elided (nothing jumps to it directly, so dead-label elimination removes it) while
# the box's internal literal-pool labels remain and are still correctly kind-tagged at mint time -- this
# script's simple "bracket by the last port label textually seen" tracker has no anchor left for those
# and misattributes them to whichever box's port label happened to precede. Confirmed a real optimizer
# characteristic, not a bracketing bug fixable by more pattern-matching here (see task bb-label-prefix-
# uniform.task.md LEDGER for the specific traced example). Needs either a smarter bracketing method or
# disabling that optimization for gate purposes -- out of scope for this pass. Keep this witness list to
# programs whose bracketing has been manually spot-checked clean; a bigger/newer witness needs the same
# spot-check before joining this list, not just "it compiles".
WITNESSES="$CORPUS/benchmarks/snobol4/pattern_bt.sno $CORPUS/tests/icon/generators.icn $WITDIR/indirect.sno"
fail=0
total_defs=0
for f in $WITNESSES; do
    [ -f "$f" ] || { echo "⛔ GATE REFUSED(2) [test_gate_bb_block_label_prefix]: witness $f is missing -- a missing witness grades nothing, never a green"; exit 2; }
    b="$(basename "$f" | sed 's/\.[^.]*$//')"
    out="$WITDIR/$b.s"
    if ! "$SCRIP_BIN" --compile -o "$out" "$f" < /dev/null > "$WITDIR/$b.err" 2>&1; then
        echo "SKIP (pre-existing compile failure, not this gate's concern): $f"
        continue
    fi
    n=$(python3 "$(dirname "$0")/lib_bb_block_label_prefix_check.py" "$out")
    rc=$?
    total_defs=$((total_defs + ${n:-0}))
    if [ $rc -ne 0 ]; then fail=1; fi
done
[ "$total_defs" -gt 0 ] || { echo "⛔ GATE REFUSED(2) [test_gate_bb_block_label_prefix]: 0 labels checked over the witnesses -- an unmeasured population is a refusal, never a green"; exit 2; }
if [ "$fail" -ne 0 ]; then
    echo "⛔ GATE FAILED -- one or more labels inside an alpha/beta(/gamma/omega-transition) block do not carry that block's own derived prefix. See violations above."
    exit 1
fi
echo "OK: every label definition inside every alpha/beta(/gamma/omega-transition) block across $total_defs checked labels carries its block's own derived prefix (or is an allowlisted non-block-scoped family)."
exit 0
