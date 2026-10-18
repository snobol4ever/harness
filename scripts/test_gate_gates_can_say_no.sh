#!/bin/bash
# test_gate_gates_can_say_no.sh -- V2-5.  THE GATE THAT TESTS THE GATES.
#
# ONE QUESTION, ASKED OF EVERY GATE: given NOTHING to examine, does it refuse -- or does it say green?
# A gate handed an empty tree has proven nothing.  If it exits 0 anyway, every DONE-WHEN that cites it is
# closing rows on a lie (ARCH-FLEET-CEO.md LAW 1).  seat16's audit found 31 such gates by hand-injection;
# this runs the same injection mechanically, every time, so gate #32 cannot reintroduce the hole.
#
# THE INJECTION is deliberately the crudest possible one: a scratch sibling root holding the gate script and
# NOTHING ELSE -- no scrip binary, no out/libscrip_rt.so, empty src/, empty corpus/.  Both $HERE/../../SCRIP and
# $S4E_HOME resolve into the scratch root, so the gate genuinely cannot see the real tree.  Any gate that
# returns 0 from that state is, by construction, not reading what it claims to read.
#
# EXPECTED verdicts are pinned per script, so this gate can say no in BOTH directions:
#   REFUSE  -- must exit non-zero on the empty tree (the honest answer).
#   PASSES  -- known-still-vacuous, pinned with its audit tier.  A PASSES entry that starts REFUSING is a
#              WIN and is reported as a FIXED row -- update the pin.  This is the ratchet.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_gate.sh"
gate_parse_args "$@"

# The 31 CANNOT-SAY-NO scripts from FINDING-2026-08-22-seat16-rung-gate-false-green-audit.md, by tier.
GATES_T1="test_gate_rtcc_claimed_regs test_gate_omega_own_k test_gate_no_c_to_bb test_gate_no_vstack test_gate_pl_coupling"
GATES_T2="test_gate_zeta_no_arena test_gate_rbp_census_ratchet test_gate_sn7_beauty_self_host"
GATES_T3="test_gate_bb_emit_blind test_gate_fb_predicate_tripwire test_gate_icn_zk5_gva test_gate_fc_no_residual_rbp test_gate_no_handencoded_bytes test_gate_no_hidden_global_in_emitted test_gate_argnote_sweep test_gate_asm_tabs_identity test_gate_clobarm test_gate_emit_no_ir_mutation test_gate_emit_no_lang test_gate_emit_no_slot_alloc test_gate_s130_behav test_gate_s130_blast"
GATES_T4="test_gate_em_template_byte_identity test_gate_const_graph test_gate_rtx_inventory_live test_gate_pas_frame_pairing audit_bb_fixup_rank audit_jcon_wholesale bench_min_of_n bench_prolog_ix_ab"
# ⛔⭐ SEAT10'S LIST, PINNED AT LAST (coo 2026-09-18, on the cto's CTO-74).  seat16's 31 above were cured by hq_P
# and pinned here, which is why they have held.  seat10 then audited the scripts that pin never covered and named
# about 23 more on 2026-08-23 -- AND THAT SECOND LIST WAS NEVER PINNED, and the file naming it was deleted three
# weeks later.  The cto recovered it from .github history and re-measured at HEAD with this gate's own injection:
# examined 23, REFUSED 13, VACUOUS 10.  The ten are cured and pinned here, so the hole cannot reopen silently.
# ⛔ TWO OF THEM WERE NOT MERELY VACUOUS.  test_gate_ir_field_discipline, test_gate_sm_dead and
# test_gate_icn_one_reg_frame are RATCHETS: a vacuous hard-zero gate lies about a measurement, but a vacuous
# ratchet reads as a WIN AGAINST ITS TARGET and then prints an instruction to tighten it -- so acting on the
# gate's own printed advice would entrench a false target permanently, and it would be a careful seat following
# the instrument that did it.  Their cure refuses BEFORE the comparison, never after.
GATES_S10="test_gate_icn_one_reg_frame test_gate_port_functions test_gate_no_bb_bin_t test_gate_no_brokered test_gate_rbx_quarantine test_gate_ir_field_discipline test_gate_sm_dead test_gate_stage2_isolation test_gate_template_medium_invisible board_sno15_ident"
ALL="$GATES_T1 $GATES_T2 $GATES_T3 $GATES_T4 $GATES_S10"

TIMEOUT="${GATE_TIMEOUT:-25}"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
REFUSED=0; VACUOUS=0; N=0
VACUOUS_LIST=""

for g in $ALL; do
    N=$((N+1))
    src="$ROOT/../harness/scripts/$g.sh"
    [ -f "$src" ] || { echo "  MISSING   $g  (script not in ../harness/scripts/ -- pin is stale)"; VACUOUS=$((VACUOUS+1)); VACUOUS_LIST="$VACUOUS_LIST $g(missing)"; continue; }
    S="$WORK/$g"
    mkdir -p "$S/harness/scripts" "$S/SCRIP/src/emitter" "$S/SCRIP/src/templates" "$S/SCRIP/src/runtime" "$S/SCRIP/out" "$S/corpus"
    cp "$src" "$S/harness/scripts/" 2>/dev/null
    cp "$ROOT/../harness/scripts/lib_gate.sh" "$S/harness/scripts/" 2>/dev/null
    cp "$ROOT/../harness/scripts/lib_oracle_flags.sh" "$S/harness/scripts/" 2>/dev/null
    rc=0
    ( cd "$S/SCRIP" && S4E_HOME="$S" CORPUS="$S/corpus" SCRIP="$S/SCRIP/scrip" SCRIP_BIN="$S/SCRIP/scrip" \
        RT_DIR="$S/SCRIP/out" timeout -k 5 "$TIMEOUT" bash "$S/harness/scripts/$g.sh" ) >"$S/out.txt" 2>&1 || rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "  ⛔ VACUOUS  $g  -- exit 0 on an EMPTY tree"
        VACUOUS=$((VACUOUS+1)); VACUOUS_LIST="$VACUOUS_LIST $g"
    else
        echo "  ✅ REFUSED  $g  (exit $rc)"
        REFUSED=$((REFUSED+1))
    fi
done

# ⛔⭐⭐ THE CANARY: PROVE THE DETECTOR STILL DETECTS (coo 2026-09-18, on the cto's warning, which they earned the
# hard way -- they widened the digest gate's FINDING arm after it reported PASS over 50 digests while five still
# asserted the retired prohibition verbatim, because its canary matched and the gate self-certified a tree it had
# not read).  THE HAZARD HERE IS EXACT: this gate's verdict is "every pinned script REFUSED", and a script can
# refuse for reasons that have nothing to do with honesty -- a missing lib_gate.sh, a bad copy, a timeout, a
# scratch root that stopped being empty.  If the INJECTION itself broke, every entry would REFUSE, VACUOUS would
# read 0, and this gate would report a perfect green while testing nothing at all.  That is the precise failure
# this whole file exists to catch, one level up, and a pinned list that grows without its canary growing is a
# ratchet with a blind spot of exactly its own shape.
# ⭐ SO A KNOWN-VACUOUS SCRIPT IS PLANTED AND MUST BE CAUGHT.  It exits 0 unconditionally, so if the machinery is
# working it is detected as VACUOUS; if it is NOT detected, the detector is broken and this gate REFUSES rc=2
# rather than reporting on the pinned list it can no longer judge.  The canary is NOT counted in the population.
CANARY="$WORK/canary"
mkdir -p "$CANARY/harness/scripts" "$CANARY/SCRIP/src/emitter" "$CANARY/SCRIP/src/templates" "$CANARY/SCRIP/src/runtime" "$CANARY/SCRIP/out" "$CANARY/corpus"
cat > "$CANARY/harness/scripts/test_gate_canary_always_vacuous.sh" <<'CANARY_EOF'
#!/usr/bin/env bash
# PLANTED CANARY -- never runs outside test_gate_gates_can_say_no.sh's injection. It examines NOTHING and says OK,
# which is the exact defect this gate hunts. It MUST be caught as VACUOUS or the detector is broken.
echo "OK: canary examined nothing and said so cheerfully."
exit 0
CANARY_EOF
cp "$ROOT/../harness/scripts/lib_gate.sh" "$CANARY/harness/scripts/" 2>/dev/null
crc=0
( cd "$CANARY/SCRIP" && S4E_HOME="$CANARY" CORPUS="$CANARY/corpus" SCRIP="$CANARY/SCRIP/scrip"     SCRIP_BIN="$CANARY/SCRIP/scrip" RT_DIR="$CANARY/SCRIP/out" timeout -k 5 "$TIMEOUT"     bash "$CANARY/harness/scripts/test_gate_canary_always_vacuous.sh" ) >/dev/null 2>&1 || crc=$?
if [ "$crc" -ne 0 ]; then
    echo ""
    echo "GATE UNPROVEN(2) [$GATE_NAME]: THE CANARY WAS NOT CAUGHT -- a script that examines nothing and exits 0"
    echo "    came back with rc=$crc, so the injection is refusing for its own reasons and every REFUSED above is"
    echo "    unreliable. This gate cannot certify a list it can no longer judge, so it refuses rather than"
    echo "    reporting REFUSED=$REFUSED VACUOUS=$VACUOUS over a broken detector."
    gate_stamp
    exit 2
fi
echo "  canary: caught (a planted always-vacuous script is detected, so REFUSED verdicts above mean what they say)"

echo ""
echo "examined $N gate script(s): REFUSED=$REFUSED  VACUOUS=$VACUOUS"
[ -n "$VACUOUS_LIST" ] && { echo "still vacuous:"; for v in $VACUOUS_LIST; do echo "    $v"; done; }
gate_floor "$N" 40 "gate scripts (seat16's pinned 31 + seat10's 10, cured and pinned 2026-09-18, less test_gate_pl_m34_parity, deleted 2026-10-04 with the .expected population it graded)"
gate_verdict "$VACUOUS" "gate(s) still return 0 on an empty tree"
