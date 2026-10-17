#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ../harness/scripts/test_gate_icn_rbp_census_ratchet.sh -- ICN-FB-0 (GOAL-ICON-BB.md).
#
# THE ICON rbp INSTRUMENT.  Gates the ICN-FB ladder: Lon's s204 directive is that every Icon
# operand resolves through RSP and rbp survives ONLY for housekeeping.  Three numbers, three
# DIFFERENT contracts -- conflating them is what retired the SNOBOL4 ratchet (see that gate's
# FLATDISP-9 header):
#
#   DRIFT      ZERO-ASSERT.  A class-C ref in a region whose prologue never seeded rbp reads
#              the CALLER's frame.  Inherited from FLATDISP-9; 0 is genuinely reachable and
#              anything else is the s188/s189 defect class.  FAILS THE GATE.
#   C_data     RATCHET.  The conversion target.  Unlike SNOBOL4 -- where a seeded ref is the
#              pinned frame model working as designed and can never read zero -- an Icon
#              seeded data ref is removable by moving its GRAPH off the pin, so it ratchets.
#              FAILS THE GATE if it rises above ICN_C_BASELINE.
#   A_ceremony PIN.  ICN-FB-3's gate condition: ceremony EXACTLY UNCHANGED across a conversion
#              step (the s22c proof shape -- if ceremony moves by even one instruction the
#              step touched the class the directive protects).  Advisory here, asserted when
#              ICN_A_EXPECT is set.
#
# ⛔ RATCHET LOWERING IS MANUAL, NEVER AUTO.  3-4 sessions run in parallel (RULES.md
# CONCURRENCY); the landing session lowers ICN_C_BASELINE in the same commit as its conversion.
#
# ⭐⭐ RE-DECLARED UNDER THE THREE-ZETAS LAW (cto 2026-09-26, the ceo's CEO-1272, row icon-the-rbp-census-ratchet-
#    counts-against-a-pre-three-zetas-baseline-...).  The red this gate read (C_data 15796 against 0, E_activation
#    10607 against 961) was two things at once, and neither was a codegen regression:
#    (1) THE INSTRUMENT WENT BLIND.  Since 15d6f203c (2026-08-16) an Icon procedure's entry label is FN__<name>;
#        the census's ENTRY_RE knew only proc_*_α, main and main_init, so each file read as TWO regions (a
#        preamble holding every procedure, then main).  The per-region seed test was blind -- DRIFT could not
#        fire for any procedure -- and in a file with one generator every host-frame ref was counted as E.
#        Cured in util_icn_rbp_census.py (FN__ is an entry); the census prints COLLAPSED (regions holding more
#        than one frame seed) and this gate REFUSES rc 2 when it is not 0, because a collapsed region is the
#        census not looking.  Fail-once: the old ENTRY_RE reads COLLAPSED > 0 on this benchmark set.
#    (2) THE FRAME MODEL CHANGED, LAWFULLY.  The ζ tier is derived (FACT RULE, Lon 2026-09-09; cfe044377
#        fl_derive_tier): an Icon procedure graph holding a window or a callee is PINNED -- its activation frame
#        is addressed through RBP, seeded by `mov rbp, rsp` -- because unbounded growth between γ and β denies
#        its operands a fixed RSP offset (RULES.md § BB FRAME-PLACEMENT CRITERION).  A generator carves its own
#        ζ-ACTIVATION frame at α (9c6ad224f, 2026-09-07), seeded by `lea rbp, [rax + N]`.  s204's "rbp only for
#        housekeeping" predates both; the seeded-frame ref is now the frame model working as designed, as the
#        SNOBOL4 gate's FLATDISP-9 header argues for its own pinned frames.
#    THE CONTRACTS NOW:  DRIFT zero-assert (a [rbp] data ref in a procedure region that never seeded rbp -- the
#    s188/s189 class; measured 0 per procedure).  COLLAPSED zero-assert, refusal (measured 0).  C_data: the
#    pinned HOST frames' refs, a never-rising ratchet at its measurement (25361) -- a rise means a landing
#    pinned a graph or put an operand on RBP, and the lander re-measures and re-declares here with the reason.
#    E_activation: the GENERATOR frames' refs, the ratchet Lon granted 2026-08-29, re-declared at its per-
#    procedure measurement (1042; the 961 of 2026-08-29 was read through the collapsed regions while no host
#    frame carried an rbp ref, so it was right then by luck; +81 since is not attributed to a landing).
#    A_ceremony advisory.  MEASURED on SCRIP (this landing's parent) over the 23 Icon benchmarks, RT_OPT=-O0:
#    A 165, C 25361, D 7, E 1042, DRIFT 0, COLLAPSED 0.
#
# BASELINE HISTORY:
#   ⭐ 0 (s247, seat1, SCRIP 0b1b7d4f pristine, 23 Icon benchmarks, RT_OPT=-O0) — THE DIRECTIVE IS MET.
#      C_data 37872 -> 0, A_ceremony -> 0, D_scratch -> 0, DRIFT -> 0: EVERY program in the benchmark set
#      now emits ZERO rbp references of any kind.  Verified by hand against the raw asm rather than trusting
#      an all-zero board (the "non-empty is not alive" reflex, inverted): queens.icn emits 6,707 lines with
#      0 `rbp` mentions and 2,700 `[rsp` references.  Lon's s204 directive — "ALL operands in EVERY BB
#      accessed via RSP, NOT RBP" — is achieved on the benchmark surface, and the 37,872 ceiling had become
#      37,872 units of silent headroom (the same defect this session found in icn_no_stack, ceiling 127 vs
#      measured 0).  Lowered to 0 per this gate's own TIGHTEN instruction.
#   ⛔⛔ THIS CEILING NOW COLLIDES WITH RUNG N-2 BY DESIGN, AND THAT IS DELIBERATE.  GOAL-ICON-100's N-2
#      gives Icon GENERATORS an RBP ζ-ACTIVATION frame (the SN4 R-4(b) blob shape: `push rbp; mov rbp,rsp;
#      carve`, pair at [rbp+8]/[rbp+16], registry slots at [rbp-N]) because Lon's LATER s242 ruling says a BB
#      owns an RBP frame exactly where compile-time depth is unknowable — "Icon's only dynamic-growth sites
#      are generator procedures and co-expressions".  The moment N-2 lands, C_data goes above 0 and THIS GATE
#      FAILS.  That is the correct behaviour: the two rulings (s204 "rbp only for housekeeping", s242 "frames
#      for genuinely dynamic depth") are not in conflict — s242 names WHERE the exception lives — but
#      encoding that exception here is a GATE RELAXATION of a zero-assert Lon personally directed, so it is
#      HIS CALL, not a side effect of the rung that needs it (precedent: the s230 gate-relaxation flag).
#      ⛔ N-2 MUST NOT LAND WITHOUT THAT RULING.  The proposed shape, for when it is asked: a FIFTH class
#      beside A/C/D/DRIFT — ζ-ACTIVATION refs inside graphs whose depth is genuinely dynamic (generator /
#      co-expression), counted and reported SEPARATELY, with C_data staying a zero-assert everywhere else.
#      Leaving the ceiling at 37,872 instead would let N-2 add frames with the instrument saying nothing at
#      all, which is the failure this whole rung exists to end.
#   37872 (s206, tree dda156eb, 20 Icon benchmarks, RT_OPT=-O0, SCRIP_NOFC default=1).
#         ⚠ THE INHERITED s204 FIGURE OF 39,193 DOES NOT REPRODUCE AT THIS HEAD -- re-measured
#         37,872, a gap of 1,321 (3.4%).  s204's tree predates NOFC-DEFAULT-ON (259b9cdb) and
#         the s22r/s22t SNOBOL4 spine work, all of which move shared emitter code.  The number
#         used by this gate is the MEASURED one; the inherited one is recorded only so the gap
#         is not rediscovered as a regression.  (Ceremony re-measured 873 vs s204's ~830 --
#         same reproduction caveat, same conclusion.)
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
CORPUS="${CORPUS:-$S4E/corpus}"
BENCH="${ICON_BENCH:-$CORPUS/benchmarks/icon}"
ICN_C_BASELINE="${ICN_C_BASELINE:-15486}"   # re-declared 2026-10-14 by hq_icon: +26 (rsg) entered with the n2 road of bb_call_value -- an Icon value call of a region-frame generator runs on the spine, not a pthread; its refs are the box's own callgen.act +0/+8 state words (base 917f42fdd 15460, measured in a scratch worktree). PRIOR: tightened 2026-10-14 by hq_zetas (row zetas-every-rbp-activation-frame-placement-...-ceo-1682, class I-1): an Icon graph is pinned only when it holds a retaining op, so 80 of the 114 pinned graphs lose the pin and C_data reads 15460 on this tree (origin read 25553 before the landing, 141 above the 25412 line below, which entered after 2781bf6e4 and is not this landing's); the previous line: tightened 2026-10-11 by hq_icon: SCRIP 890a0e5aa deleted the fused table-lvalue road and the census reads 25412 again (the CEO-1628 debt paid), unchanged by the subscript-first store for a right side with effects; the previous line: 25616 re-declared 2026-10-10 by the ceo (CEO-1628): +204 entered with SCRIP a004001a7, the fused t[k] := v table store (bb_assign_var.cpp AV_LVTBL and the IR_SEAL_SUBSCRIPT_LVTBL leaf road), measured in a scratch worktree -- 5d2118022 (its parent) reads 25412 exactly and a004001a7 reads 25616; the landing did not declare it. The 204 are the conversion debt of the row icon-the-fused-table-store-s-204-rbp-seeded-data-refs-go-to-rsp-...-ceo-1628 (the ceo, SEPTET); the previous line: re-declared 2026-10-09 by hq_collector: +21 entered with SCRIP 7016f6e25 (the ARCH-GC 13.5 cell conversions: the scan-enter sigma cell tag and zeroed slen, and the suspend-leave bank tag, three frame-relative stores per scan site), measured by hq_icon over the committed bench .s, 25322 at cfcfaf46d and 25412 at 7016f6e25; earlier: 25391 re-declared 2026-09-26 15:3x by the cto on SCRIP 65bb1f417 (read 25391, +30 over the CTO-174 02:4x reading of 25361, the crawl landings between; wired REPORTED in test-sequential under CEO-1274 (3), so a rise prints and never blocks)
ICN_E_BASELINE="${ICN_E_BASELINE:-1074}"   # re-declared 2026-10-14 by hq_icon: +29 (geddump, its three apply boxes in generator frames) with the same n2 road, the same callgen.act +0/+8 words of a generator frame, the class Lon granted 2026-08-29 (base 917f42fdd 1045). PRIOR: re-declared 2026-10-14 by hq_zetas: +1 entered with SCRIP 50f4604e6 (2026-10-11, the Icon generator callgen act +8 word, ZK_PTR_FRAME_H: the FAIL and omega landings now store 0 into the H word of a region-resident generator frame, the correctness half of that landing, an rbp ref of the class Lon granted 2026-08-29), bisected by the coo in a scratch worktree: e14b4a71b reads 1044, 50f4604e6 reads 1045, unchanged through 35d99ead0, 2781bf6e4 and a61aea8a8; the landing did not declare it; the previous line: 1044 re-declared 2026-10-09 by hq_collector: E read 1040 at 7016f6e25~1 and 1044 at 7016f6e25 (the same 13.5 tag stores where a scan sits in a region-resident generator frame); earlier 1042: ⭐ CLASS E ratchet (Lon grant 2026-08-29): ζ-ACTIVATION refs in region-resident generator frames -- never-rising; set at flip-time measurement, lowered manually in the landing commit like C.
PY="$HERE/util_icn_rbp_census.py"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED-TO-GRADE scrip not built"; exit 2; }
[ -d "$BENCH" ] || { echo "⛔ REFUSED-TO-GRADE no Icon benchmark corpus at $BENCH"; exit 2; }
[ -f "$PY" ]    || { echo "GATE FAIL: missing $PY"; exit 2; }
PLANT_DIR=$(mktemp -d) || exit 2; trap 'rm -rf "$PLANT_DIR"' EXIT
printf 'FN__a:\n    mov qword ptr [rsp + 8], rbp\n    mov rbp, rsp\n    mov rax, qword ptr [rbp + 8]\nFN__b:\n    mov rax, qword ptr [rbp + 16]\nmain:\n    ret\n' > "$PLANT_DIR/drift_plant.s"
PLANT=$(python3 "$PY" "$PLANT_DIR/drift_plant.s" 2>&1); PRC=$?
{ [ "$PRC" -eq 1 ] && printf '%s\n' "$PLANT" | grep -q 'FN__b .*\[rbp + 16\]'; } || { echo "⛔ REFUSED-TO-GRADE: the DRIFT detector did not fire on its plant (a second procedure reading [rbp + 16] without seeding rbp; rc=$PRC) -- a zero-assert that cannot say no is not measuring"; exit 2; }
echo "POSITIVE CONTROL OK: the drift plant reads drift=1 and names FN__b."
# ⛔ GLOB MUST BE EXPANDED BEFORE IT IS TRUSTED -- with nullglob off (bash default) an EMPTY
# BENCH makes "$BENCH"/*.icn pass the literal, unmatched string "*.icn" through to python as a
# single bogus filename; the census then reports a silent all-zero row (RATCHET_C=0, exit 0),
# indistinguishable from a genuinely met ratchet.  nullglob + a real count turns that into a
# REFUSAL instead (FACT RULE: a missing prerequisite is rc=2, never a green exit).
shopt -s nullglob
ICN_FILES=("$BENCH"/*.icn)
shopt -u nullglob
[ "${#ICN_FILES[@]}" -gt 0 ] || { echo "⛔ REFUSED-TO-GRADE no .icn files found in $BENCH"; exit 2; }
# ⛔ EXIT STATUS READ FROM python DIRECTLY, NEVER THROUGH A PIPE -- a `| tail` reports TAIL's
# status and silently discards the verdict (the defect test_gate_fc_no_residual_rbp.sh records
# as its own root cause).  Capture, then print, then test.
OUT=$(SCRIP="$SCRIP" python3 "$PY" "${ICN_FILES[@]}" 2>&1); RC=$?
printf '%s\n' "$OUT"
C=$(printf '%s\n' "$OUT" | sed -n 's/^RATCHET_C=\([0-9]*\)$/\1/p' | tail -1)
A=$(printf '%s\n' "$OUT" | sed -n 's/^CEREMONY_A=\([0-9]*\)$/\1/p' | tail -1)
E=$(printf '%s\n' "$OUT" | sed -n 's/^ACTIVATION_E=\([0-9]*\)$/\1/p' | tail -1)
[ -n "$C" ] || { echo "GATE FAIL: census produced no RATCHET_C line"; exit 2; }
COL=$(printf '%s\n' "$OUT" | sed -n 's/^COLLAPSED=\([0-9]*\)$/\1/p' | tail -1)
[ -n "$COL" ] || { echo "⛔ REFUSED-TO-GRADE: census produced no COLLAPSED line -- census/gate version skew"; exit 2; }
[ "$COL" -eq 0 ] || { echo "⛔ REFUSED-TO-GRADE: $COL region(s) hold more than one frame seed -- the census's procedure regions have collapsed (an entry label it does not know), so DRIFT and the C/E split are blind. Teach ENTRY_RE the label; never read this as a verdict."; exit 2; }
echo
if [ "$RC" -ne 0 ]; then
    echo "GATE FAIL: DRIFT -- class-C reference(s) naming a base the prologue never established."
    exit 1
fi
echo "ZERO-ASSERT OK: drift=0."
if [ "$C" -gt "$ICN_C_BASELINE" ]; then
    echo "GATE FAIL: RATCHET C_data=$C > baseline=$ICN_C_BASELINE (+$((C-ICN_C_BASELINE)))."
    exit 1
fi
if [ "$C" -lt "$ICN_C_BASELINE" ]; then
    echo "RATCHET OK, TIGHTEN: C_data=$C < baseline=$ICN_C_BASELINE (-$((ICN_C_BASELINE-C)))."
    echo "  -> lower ICN_C_BASELINE to $C in THIS commit (manual; parallel sessions share this file)."
else
    echo "RATCHET OK: C_data=$C == baseline."
fi
[ -n "$E" ] || { echo "GATE FAIL: census produced no ACTIVATION_E line (fifth class missing -- census/gate version skew)"; exit 2; }
if [ "$E" -gt "$ICN_E_BASELINE" ]; then
    echo "GATE FAIL: RATCHET E_activation=$E > baseline=$ICN_E_BASELINE (+$((E-ICN_E_BASELINE)))."
    exit 1
fi
if [ "$E" -lt "$ICN_E_BASELINE" ]; then
    echo "RATCHET OK, TIGHTEN: E_activation=$E < baseline=$ICN_E_BASELINE -- lower ICN_E_BASELINE to $E in THIS commit."
else
    echo "RATCHET OK: E_activation=$E == baseline."
fi
if [ -n "$ICN_A_EXPECT" ]; then
    if [ "$A" -ne "$ICN_A_EXPECT" ]; then
        echo "GATE FAIL: CEREMONY A=$A != expected $ICN_A_EXPECT -- a conversion step moved a class the directive protects (ICN-FB-3)."
        exit 1
    fi
    echo "CEREMONY PIN OK: A=$A == $ICN_A_EXPECT."
else
    echo "CEREMONY (advisory, set ICN_A_EXPECT to pin): A=$A."
fi
exit 0
