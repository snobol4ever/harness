#!/usr/bin/env bash
# THE SHIFT PLANT SAYS WHETHER IT APPLIED, AND ITS DECLINE NEVER READS AS AN APPLICATION (cto 2026-09-21, MODE TENET,
# on the coo's flag).  SCRIP_GC_PLANT_SHIFT=N forwards every live block N bytes up at every collection: it is the
# forced-movement mechanism under three gc gates, so a run in which it silently did NOTHING is a gate grading ordinary
# compaction while reporting forced relocation (CTO-113).  The decline was made loud at SCRIP 1b317bea3 -- and the loud
# line carried BOTH errors a reader can make, in OPPOSITE directions, measured at HEAD before this gate was cut:
#   (a) the decline text told the reader to COUNT a literal that the decline text ITSELF SPELLED, so an unanchored grep
#       for it matched the decline and counted a DECLINE as an APPLICATION.  Measured: hb_coexpr_create.icn at
#       SCRIP_HEAP_MB=1 stress 3 shift 1048576 -- 0 applications, unanchored count 1.  Found by the coo, who read
#       applied=1 off a run that planted nothing.
#   (b) the applied banner was gated behind SCRIP_ZETA_TELEM/SCRIP_GC_MAPS, so a reader following that same advice with
#       no telemetry counted ZERO on EVERY run.  Measured: the same witness at shift 4096 -- 199 applications, 0 visible.
# One message, two finding-shaped lies.  The cure is in the runtime's own text and gating (gc_heap.c), and this gate
# holds it on the EMITTED BYTES rather than on the source: the applied banner prints once per process with nothing
# asked for and once per collection under telemetry, and the decline spells no countable literal.
# ⛔ THE DIRECTION OF THIS GATE'S OWN ERROR IS A REFUSAL, NEVER A FINDING (the coo's rule, 2026-09-21): both arms rest
# on a premise -- that this arena/shift pair APPLIES, or that it DECLINES -- and the premise is measured by telemetry,
# which counts the collector's own applications rather than reading prose.  A premise that does not hold exits 2 with
# the numbers, because a plant that cannot be made to decline here is a configuration statement, not a defect.
# ARMS. (1) at a shift that applies, the anchored banner is visible with NOTHING asked for, and telemetry still gives
# the per-collection form.  (2) at a shift that declines, the decline is present, the anchored count is 0, and an
# UNANCHORED grep for the counted literal is also 0 -- the decline impersonates nothing.  (3) DECLARED SET: every
# script that drives the plant as its forced-movement mechanism reads the applied banner, so none of them can grade an
# unplanted run in silence.  The set is named here and an unnamed newcomer is a FAIL, not a pass (a dispatch guard is a
# CLOSED ENUMERATION -- MODE TENET line 2).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
WIT="$ROOT/../harness/scripts/gc_witnesses/hb_coexpr_create.icn"
[ -f "$WIT" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing $WIT"; exit 2; }
APPLY_KB=256; DECLINE_KB=64
LIT='[GC-FLIP] plant:'
run() { local kb="$1" tel="$2" out="$3"; if [ "$tel" = tel ]; then ( cd "$T" && env SCRIP_HEAP_KB="$kb" SCRIP_GC_PLANT_FLIP=1 SCRIP_GC_STRESS=3 SCRIP_ZETA_TELEM=1 timeout -k 5 300 "$SCRIP" "$WIT" >/dev/null 2>"$out" </dev/null ); else ( cd "$T" && env SCRIP_HEAP_KB="$kb" SCRIP_GC_PLANT_FLIP=1 SCRIP_GC_STRESS=3 timeout -k 5 300 "$SCRIP" "$WIT" >/dev/null 2>"$out" </dev/null ); fi; }
echo "  HOLDS: the flip's applied banner is the proof it applied and prints with nothing asked for; its decline spells no literal a count would match; every gate that plants the flip reads the banner; the knob table is closed against src/ (CEO-1794: the flip is the one movement plant left, SHIFT, RELOC, PIN_SKIP, PIN_TYPE, UNROOT and RTCCB retired with the bitmap collector, ARCH-GC section 15)"
run "$APPLY_KB" notel "$T/a_notel.txt"; run "$APPLY_KB" tel "$T/a_tel.txt"
a_tel=$(grep -c "^\[GC-FLIP\] plant:" "$T/a_tel.txt"); a_tel=${a_tel:-0}
a_bare=$(grep -c "^\[GC-FLIP\] plant:" "$T/a_notel.txt"); a_bare=${a_bare:-0}
[ "$a_tel" -ge 1 ] || { echo "⛔ GATE REFUSE(2) [$G]: PREMISE UNMET -- at SCRIP_HEAP_KB=$APPLY_KB the flip applied $a_tel times under telemetry, so this configuration cannot grade the banner"; exit 2; }
if [ "$a_bare" -ge 1 ]; then echo "  arm 1 PASS: the plant announces itself with nothing asked for -- $a_bare line(s) bare, $a_tel under SCRIP_ZETA_TELEM (once per process, then once per collection)"
else echo "  arm 1 FAIL: the plant applied $a_tel times under telemetry and printed $a_bare lines without it -- the banner is telemetry-gated again and every bare reader counts zero applications"; RC=1; fi
run "$DECLINE_KB" notel "$T/d_notel.txt"; run "$DECLINE_KB" tel "$T/d_tel.txt"
d_tel=$(grep -c "^\[GC-FLIP\] plant:" "$T/d_tel.txt"); d_tel=${d_tel:-0}
d_dec=$(grep -c 'plant DECLINED' "$T/d_notel.txt"); d_dec=${d_dec:-0}
[ "$d_tel" -eq 0 ] && [ "$d_dec" -ge 1 ] || { echo "⛔ GATE REFUSE(2) [$G]: PREMISE UNMET -- at SCRIP_HEAP_KB=$DECLINE_KB the flip applied $d_tel times and printed $d_dec decline line(s), so this configuration cannot grade the decline"; exit 2; }
d_anch=$(grep -c "^\[GC-FLIP\] plant:" "$T/d_notel.txt"); d_anch=${d_anch:-0}
d_bare=$(grep -cF "$LIT" "$T/d_notel.txt"); d_bare=${d_bare:-0}
if [ "$d_anch" -eq 0 ] && [ "$d_bare" -eq 0 ]; then echo "  arm 2 PASS: a declined collection impersonates nothing -- decline lines=$d_dec, anchored applications=0, and an UNANCHORED count of the literal also reads 0"
else echo "  arm 2 FAIL: the plant applied 0 times yet a count reads anchored=$d_anch unanchored=$d_bare -- the decline text spells the literal it tells the reader to count"; RC=1; fi
TBL='SCRIP_GC_PLANT_FLIP|GC-FLIP|test_gate_dyn_caps_a_long_prolog_term_and_a_regrown_function_table_pass_the_old_runtime_bounds.sh test_gate_gc_a_coexpression_frame_image_lives_on_its_own_stack.sh test_gate_gc_a_heap_mark_on_the_prolog_trail_moves_with_the_first_young_block.sh test_gate_gc_a_result_preserving_poll_shields_the_subject_register.sh test_gate_gc_a_suspended_scan_banks_its_subject_where_the_walker_relocates_it.sh test_gate_gc_differential_configs_agree.sh test_gate_gc_every_gva_island_cell_is_a_root_a_hidden_compiler_temporary_included.sh test_gate_gc_forced_relocation_moves_every_live_block.sh test_gate_gc_pas_heap_cells_survive_forced_movement.sh test_gate_gc_the_coexpression_roots_are_typed_and_the_parked_stacks_are_segments.sh test_gate_gc_the_flip_plant_turns_a_stale_pointer_into_a_located_fault.sh test_gate_gc_the_icon_operator_context_survives_a_collection.sh test_gate_gc_the_scan_subject_base_is_reloaded_after_a_call_inside_a_scan.sh test_gate_icn_the_cset_registry_is_weak_so_a_dead_computed_cset_leaves_the_collector.sh test_gate_pl_cyclic_terms_unify_compare_copy_and_survive_a_collection_as_swipl_does.sh
SCRIP_GC_PLANT_SCAN_BANK|GC-SCANBANK|test_gate_gc_a_suspended_scan_banks_its_subject_where_the_walker_relocates_it.sh test_gate_gc_the_flip_plant_turns_a_stale_pointer_into_a_located_fault.sh
SCRIP_GC_PLANT_CSET_STRONG|GC-CSET|test_gate_icn_the_cset_registry_is_weak_so_a_dead_computed_cset_leaves_the_collector.sh
SCRIP_GC_PLANT_ICN_OP|GC-ICNOP|test_gate_gc_the_icon_operator_context_survives_a_collection.sh'
scan="$(cd "$HERE" && grep -HnE 'SCRIP_GC_PLANT_[A-Z_]+=' test_gate_*.sh 2>/dev/null | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#')"
bad=""; rows=0; gates=0
while IFS='|' read -r knob lit want; do
  [ -n "$knob" ] || continue
  rows=$((rows+1))
  found="$(printf '%s\n' "$scan" | grep -F "${knob}=" | cut -d: -f1 | grep -v "^${G}.sh$" | sort -u | tr '\n' ' ' | sed 's/ $//')"
  wantn="$(printf '%s' "$want" | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' ' | sed 's/ $//')"
  [ "$found" = "$wantn" ] || bad="$bad [$knob: declared='$wantn' found='${found:-none}']"
  for f in $found; do gates=$((gates+1)); grep -vE '^[[:space:]]*#' "$HERE/$f" | grep -F "$lit" >/dev/null || bad="$bad [$knob: $f plants and never reads the '$lit' banner on any line the shell executes]"; done
done <<EOF
$TBL
EOF
if [ -z "$bad" ]; then echo "  arm 3 PASS: $rows plant knob(s) declared, $gates planting gate(s) found by ASSIGNMENT on executable lines, every one reads its own knob's applied literal"
else echo "  arm 3 FAIL:$bad -- a gate whose forced movement IS the plant must read that plant's banner or it grades an unplanted run in silence; a newcomer is declared in the table above or it is not a plant"; RC=1; fi
src_knobs="$(cd "$ROOT" && grep -rhoE 'SCRIP_GC_PLANT_[A-Z_]+' src/ 2>/dev/null | sort -u | tr '\n' ' ' | sed 's/ $//')"
tbl_knobs="$(printf '%s\n' "$TBL" | cut -d'|' -f1 | sort -u | tr '\n' ' ' | sed 's/ $//')"
if [ "$src_knobs" = "$tbl_knobs" ]; then echo "  arm 4 PASS: the knob table is closed against src/ -- the runtime reads exactly the $rows declared plant knob(s): $src_knobs"
else echo "  arm 4 FAIL: src/ reads '$src_knobs' and this gate's table declares '$tbl_knobs' -- a plant knob the table does not know is a planting family arm 3 cannot see, and a table entry the runtime does not read is a plant no run can apply"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS(0) [$G]: the plant says whether it applied, its decline impersonates nothing, the knob table is closed against src/, every planting gate reads its own plant's banner (examined 4 arms)"
else echo "GATE FAIL(1) [$G]: the plant's own report can be read backwards, a plant is held by no reader, or the table and src/ disagree (examined 4 arms)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
