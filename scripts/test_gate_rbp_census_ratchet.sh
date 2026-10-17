#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ../harness/scripts/test_gate_rbp_census_ratchet.sh — FLATDISP rung (d), s193.
#
# THE HONEST rbp INSTRUMENT.  Predecessor instruments each reported convergence the bytes
# contradicted (s184 patience-FC, s188 subset-FC via x86_fc_hit, s192 raw census counting
# class-D): this gate (1) sweeps the COMPILER (`scrip --compile`), NEVER the committed .s
# artifacts (RULES.md handoff step 4: artifacts track design churn, they are not truth);
# (2) EXCLUDES CLASS D — `mov rbp, qword ptr [<non-rsp base> + N]`, rbp as a plain scratch
# GPR destination for a data-field load (s192 census: 14 across the 16 benchmarks).  A
# scratch use is not a frame reference and no frame-pointer rung can ever remove it, so a
# ratchet that counts it can never read zero (s192 headline 3, the third mis-measuring
# instrument).  Classes A (ceremony), B (genuine unwind), C (housekeeping [rbp+N] refs)
# all remain counted — they are exactly what the FLATDISP ladder exists to shrink.
# (3) RATCHETS: fail if NET > baseline; print a TIGHTEN hint when strictly below so the
# landing session lowers the baseline in the same commit (manual, never auto — 3-4
# parallel sessions share this file, RULES.md CONCURRENCY note).
#
# Baseline history: 237 (s193 — post FLATDISP-5b/5c heal + FLATDISP-6 narrowing; ALL=251,
# CLASS_D=14, watermark m3 185/130 m4 183/130 DIVERGE=1).  119 (s194 FLATDISP-7).  113 (s196
# SCANBASE).  48 (s199 DEFER-STAR: emit_graph_has_deep_arrival counted EVERY IR_MATCH_DEFER,
# but that op is built by two lowering arms the node cannot tell apart — TT_DEFER (the `*`
# unevaluated-expression operator) and TT_VAR (a bare pattern-valued variable in pattern
# position).  Only `*` can recurse: SPITBOL manual "Recursive Patterns" p.122 — the operator
# is what "makes the definition possible" and what "allows a forward reference to a pattern
# not yet defined"; a stored pattern reused by name is built EAGERLY and cannot name itself.
# Narrowed to star-sourced only via the sno_defer_is_star side table.  Watermark held exactly
# m3 221/94 m4 219/94 DIVERGE=1, FAIL sets byte-identical both modes, benchmark runtime
# signatures byte-identical pre/post.  NOT the s197 change, which dropped DEFER wholesale and
# was correctly reverted — recursive-`*` witnesses stay deep here, verified.)
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ⭐ V2-5 GATE HONESTY: examining nothing must exit UNPROVEN(2), never read as a pass.
. "$(dirname "$0")/lib_gate.sh"
gate_require_exec "${SCRIP:-${SCRIP_BIN:-$(dirname "$0")/../../SCRIP/scrip}}" "the scrip compiler"
gate_require "${RT_DIR:-$(dirname "$0")/../../SCRIP/out}/libscrip_rt.so" "the runtime shared object out/libscrip_rt.so"
#
# ============================ FLATDISP-9 (s200) — THE RATCHET IS RETIRED ============================
# THE COUNT ABOVE CAN NO LONGER RATCHET, AND THE 48 WAS MEASURED ON A BROKEN TREE.
#
# (1) THE BASELINE WAS TAKEN WHILE THE THING IT MEASURES WAS BROKEN.  48 was set at s199
#     DEFER-STAR, one commit BELOW s197 FLATDISP-8.  On that tree x86_fb() was unconditionally
#     rsp while xa_flat still SEEDED rbp for the pinned classes — the s188/s189 drift — and the
#     watermark it was measured against (SNOBOL4 221/219, Icon 236, Prolog 120/44) was the
#     DAMAGE, not a healthy baseline.  s197 repaired the frame and the count rose 48 -> 57.
#     Ratcheting against a number harvested from a broken frame would forfeit that repair.
# (2) A PER-GRAPH DECISION CANNOT BE RATCHETED BY A PER-FILE COUNT.  FLATDISP-8 made the base
#     PER-GRAPH (emit_jmp_pin_rbp: flat_deep_arrival || flat_pat || flat_gen).  The file-level
#     NET therefore moves whenever the pin CLASSIFICATION legitimately changes — in EITHER
#     direction, with no defect either way.  FLATDISP-5a (inline invariant patterns) will move
#     it down; a new suspending construct moves it up.  A number that changes for correct
#     reasons is not a ratchet, it is a tripwire that fires on progress.
# (3) THE ARGUMENT IS THE ONE THIS GATE ALREADY ACCEPTS FOR CLASS D.  Class D is excluded
#     because "a scratch use is not a frame reference and no frame-pointer rung can ever remove
#     it, so a ratchet that counts it can never read zero."  Every [rbp+N] inside a graph whose
#     prologue SEEDS rbp is that same category: it is the pinned frame model working as
#     designed, unremovable while the graph is pinned.  Counting it makes zero unreachable.
#
# WHAT REPLACES IT — A REAL ZERO-ASSERT ON THE ACTUAL DEFECT CLASS.  The defect FLATDISP exists
# to prevent is a reference naming a base the prologue never established (s188/s189: Icon
# 250->236, SNOBOL4 295/294->221/219, Prolog 164->120, three sessions chasing it separately).
# ../harness/scripts/util_rbp_region_census.py splits each .s into graph regions, asks per region whether
# the prologue emitted `mov rbp, rsp`, and counts [rbp+N] frame references in regions where it
# did NOT.  That count MUST be 0 and 0 is genuinely reachable — it is the drift, nothing else.
# MEASURED AT LANDING (s200, tree 8d0665c8): unseeded=0 across SNOBOL4 benchmarks (30 seeded),
# SNOBOL4 demo+feat (44,616), Icon benchmarks (38,115), Icon programs (110,928), Prolog
# benchmarks (90,677) — ~285,000 frame references, zero drift, all three affected languages.
# NET is still printed, as CONTEXT for how many graphs are pinned.  It is not a pass condition.
# ====================================================================================================
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
CORPUS="${CORPUS:-$S4E/corpus}"
BENCH="$CORPUS/benchmarks/snobol4"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED-TO-GRADE scrip not built"; exit 2; }
[ -d "$BENCH" ]  || { echo "⛔ REFUSED-TO-GRADE no benchmark corpus at $BENCH"; exit 2; }
ALL=0; D=0; TABLE=""
for f in "$BENCH"/*.sno; do
    s=$(mktemp); "$SCRIP" --compile "$f" > "$s" 2>/dev/null
    a=$(grep -cw rbp "$s"); dd=$(grep -Ec "mov +rbp, qword ptr \[r(ax|bx|cx|dx|si|di|8|9|1[0-5])" "$s")
    ALL=$((ALL+a)); D=$((D+dd))
    TABLE="$TABLE$(printf '%-24s all=%-4s classD=%-3s net=%s' "$(basename "$f" .sno)" "$a" "$dd" "$((a-dd))")\n"
    rm -f "$s"
done
NET=$((ALL-D))
echo "=== rbp census (compiler sweep, benchmark corpus) — CONTEXT ONLY, not a pass condition ==="
printf "$TABLE"
echo "ALL=$ALL CLASS_D=$D NET=$NET   (NET = how many graphs are pinned; per-graph since FLATDISP-8, see header)"
echo
echo "=== THE GATE: per-region drift zero-assert (FLATDISP-9) ==="
PY="$HERE/util_rbp_region_census.py"
[ -f "$PY" ] || { echo "GATE FAIL: missing $PY"; exit 2; }
# ⛔ EXIT STATUS IS READ FROM python DIRECTLY, NEVER THROUGH A PIPE.  `python3 ... | tail` would
# report TAIL's status and silently discard the verdict — the identical defect
# test_gate_fc_no_residual_rbp.sh's header records as its own root cause (1) ("the pipeline exit
# status was grep's and timeout's 124 was DISCARDED").  Capture, then echo, then test.
OUT=$(SCRIP="$SCRIP" python3 "$PY" "$BENCH"/*.sno 2>&1); RC=$?
printf '%s\n' "$OUT" | tail -n 24
if [ "$RC" -ne 0 ]; then
    echo "GATE FAIL: unseeded [rbp+N] frame reference(s) — a reference naming a base the prologue never established (the s188/s189 drift class that cost Icon 250->236, SNOBOL4 295/294->221/219, Prolog 164->120)."
    exit 1
fi
echo "GATE OK: zero unseeded frame references."
exit 0
