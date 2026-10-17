#!/usr/bin/env bash
# test_gate_sno_charset_dynamic_operand_null_alt.sh -- a charset primitive (SPAN/ANY/NOTANY/BREAK) whose
# operand is a variable the compiler cannot fold to a constant LOSES ITS CHARACTER SET when a NULL-MATCHING
# ALTERNATION BRANCH sits immediately before it in the pattern. It does not fail -- it silently matches the
# wrong thing (SPAN/ANY run past the set, NOTANY is inverted), and BREAK SIGSEGVs. rc=0 on the silent-wrong
# face, so no board anywhere flags it by exit code.
#
# FINDING-2026-09-05-hq_T-a-null-alternation-branch-before-a-charset-primitive-loses-the-character-set-and-
# break-segvs.md (the symptom). FINDING-2026-09-06-hq_U-the-charset-primitive-reads-its-set-at-a-path-
# dependent-rsp-offset-and-a-null-alternation-arm-suspends-16-bytes-under-it.md (the PROVEN mechanism -- read
# this one, not the paragraph below, for anything beyond a one-line summary). Row
# charset-primitive-loses-its-set-after-a-null-alternation-branch (minted by hq_T, 2026-09-06T01:13:33Z),
# owned by hq_U's lane.
#
# ⭐ MECHANISM (hq_U, decisive same-binary/same-pattern/subject-only-varies experiment): bb_match_span's
# `_.op_zres` arm reads the set through ZOPQ(0,8)/ZOPD(0,4), which fall back to a raw RSP-relative spelling
# with ONE emit-time-constant displacement whenever the operand did not earn an RBP frame slot. A null-
# matching alternation arm lowers to IR_MATCH_DEFER, whose success path gamma-SUSPENDs by pushing a two-word
# resume frame and jumping to the merge WITHOUT restoring rsp -- so the null arm and a non-null arm (e.g. a
# literal match) reach the shared merge point 16 bytes apart in rsp, and one compile-time constant cannot be
# correct for both. Two blockers in series keep the operand from earning a slot in the first place:
# xop_frame_member chases gamma from operand to consumer and steps OVER the alternation's DEFER arm rather
# than into it (the hazard is invisible, not the consumer); and blob_frame_scope() is 0 for every inline
# statement graph because `flat_jmp_entry` is set only for HOISTED pattern/proc graphs -- an EMISSION-PATH
# boundary, not the `flat_pat`/"PAT$"-name test an earlier reading of this same row assumed and later
# retracted (do not cite "switched off by name" as current; it is a corrected, superseded claim). This is the
# same shared-engine class as POS/RPOS/FENCE/LEN (test_gate_sno_pos_rpos_dynamic_operand.sh); this gate's four
# witnesses are a further symptom pair (wrong-answer and crash faces both) of the identical two-blocker cause.
#
# ⛔ THIS GATE IS WITNESS-ONLY (seat11, rung 1, per this row's own GOAL text: "never a compiler fix"): it
# PROVES the class, it does not cure it. The recommended cure (a match-frame RBP slot for a dynamic pattern-
# primitive operand, precedented by capture_frame_slot, emit.cpp:2513) is hq_U's shared-engine lane with hq_S
# co-signing the SNOBOL4 board, not a fleet seat's. RED here is this gate doing its job until that cure lands
# -- once it does, this becomes the standing regression gate, unmodified.
#
# ⛔ THE SWEEP IS NOT OPTIONAL, same reasoning as the POS/RPOS/LEN gates (hq_S FINDING sec 2): argv length
# shifts the initial stack, which shifts every RSP-relative address. This class's own finding text describes
# it as deterministic (3/3, 20/20-style readings) but that was never measured across a basename-length sweep
# -- so this gate sweeps 1..20 anyway, in both modes, and reports the true ok3/ok4 count rather than assuming
# it will read 0/20 or 20/20. Determinism is a property of a witness, not of the class.
#
# CONTROLS (span_dyn_lit_nullalt, span_dyn_noalt, span_dyn_altnonull) discriminate this class from a plain
# alternation/charset semantics bug: a foldable (literal) operand, no preceding alternation at all, and an
# alternation with NO null branch are all correct today under the identical sweep and MUST stay correct, or
# this gate cannot tell "the known class" from "a new regression" apart. span_dyn_altnonull in particular is
# built the way the finding's own Corrections section insists on: its subject ('+12x') actually enters the
# non-null branch and SPAN matches a real, non-empty run ('+12') -- a subject that cannot enter the group at
# all would pass on both sides for the wrong reason and prove nothing (the finding's own caught mistake).
#
# rc=0 CLEAN (nothing swept diverges from the oracle, in either mode), rc=1 VIOLATION (at least one does),
# rc=2 UNPROVEN (no oracle, no fresh binary, or a zero denominator -- never printed as a pass).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
S4E="$(cd "$ROOT/.." && pwd)"
GATE_NAME=sno_charset_dynamic_operand_null_alt
. "$HERE/lib_oracle_flags.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: lib_oracle_flags.sh unavailable"; exit 2; }
. "$HERE/lib_gate.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: lib_gate.sh unavailable"; exit 2; }
gate_parse_args "$@"
O="$(sbl_correctness_bin)" || exit 2
gate_require_exec "$ROOT/scrip" "the scrip binary"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"

W="$S4E/corpus/tests/snobol4"
T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT

PROGS="span_dyn_nullalt any_dyn_nullalt notany_dyn_nullalt break_dyn_nullalt span_dyn_lit_nullalt span_dyn_noalt span_dyn_altnonull"
CONTROLS=" span_dyn_lit_nullalt span_dyn_noalt span_dyn_altnonull "

m4_run() {   # $1 = source .sno (absolute), $2 = basename (no ext), writes stdout+stderr to $3, returns rc via $4 varname
    local src="$1" name="$2" outfile="$3" __rcvar="$4" __rc
    ( cd "$T" && timeout -k 5 30s "$ROOT/scrip" --compile -o "$name.s" "$src" </dev/null >/dev/null 2>&1 ) || { echo "M4-COMPILE-FAILED" > "$outfile"; printf -v "$__rcvar" '%d' 1; return; }
    ( cd "$T" && gcc -no-pie "$name.s" -o "$name.bin" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ) || { echo "M4-LINK-FAILED" > "$outfile"; printf -v "$__rcvar" '%d' 1; return; }
    ( cd "$T" && timeout -k 5 10s "./$name.bin" </dev/null >"$outfile" 2>&1 ); __rc=$?
    printf -v "$__rcvar" '%d' "$__rc"
}

red=0; examined=0; RED_NAMES=''; GRADED_NAMES=''
for p in $PROGS; do
    src="$W/$p.sno"; ref="$W/$p.ref"
    if [ ! -f "$src" ] || [ ! -f "$ref" ]; then
        echo "GATE UNPROVEN(2) [$GATE_NAME]: missing committed fixture $p (.sno/.ref)"; gate_stamp; exit 2
    fi
    timeout -k 5 20 "$O" -bf "$src" </dev/null >"$T/$p.oref" 2>/dev/null
    if ! cmp -s "$T/$p.oref" "$ref"; then
        echo "RED  $p: committed ref disagrees with the live oracle -- re-cut it (oracle/ref drift, not this class)"
        red=$((red+1)); examined=$((examined+1)); RED_NAMES="$RED_NAMES $p(ref-drift)"; GRADED_NAMES="$GRADED_NAMES $p"; continue
    fi
    is_control=0
    case "$CONTROLS" in *" $p "*) is_control=1;; esac
    body="$(cat "$src")"
    ok3=0; ok4=0; crash3=0; crash4=0
    for len in $(seq 1 20); do
        name="$(printf 'x%.0s' $(seq 1 "$len"))"
        fn="$T/$name.sno"
        printf '%s\n' "$body" > "$fn"
        ( cd "$T" && timeout -k 5 10s "$ROOT/scrip" "$name.sno" </dev/null >"$T/$name.m3" 2>&1 ); rc3=$?
        cmp -s "$T/$name.m3" "$ref" && ok3=$((ok3+1))
        [ "$rc3" = 139 ] && crash3=$((crash3+1))
        m4_run "$fn" "$name" "$T/$name.m4" rc4
        cmp -s "$T/$name.m4" "$ref" && ok4=$((ok4+1))
        [ "$rc4" = 139 ] && crash4=$((crash4+1))
        rm -f "$fn" "$T/$name.m3" "$T/$name.m4" "$T/$name.s" "$T/$name.bin"
    done
    examined=$((examined+1)); GRADED_NAMES="$GRADED_NAMES $p"
    tag="witness"; [ "$is_control" = 1 ] && tag="control"
    if [ "$ok3" -eq 20 ] && [ "$ok4" -eq 20 ]; then
        echo "PASS $p [$tag]: 20/20 m3, 20/20 m4 -- matches the oracle across the filename-length sweep in both modes"
    else
        extra=""
        [ "$crash3" -gt 0 ] && extra="$extra m3-crashes=$crash3/20"
        [ "$crash4" -gt 0 ] && extra="$extra m4-crashes=$crash4/20"
        echo "RED  $p [$tag]: m3=$ok3/20 m4=$ok4/20 match the oracle across the filename-length sweep$extra"
        red=$((red+1)); RED_NAMES="$RED_NAMES $p[$tag]"
    fi
done
gate_floor "$examined" 7 "witness/control programs"
echo "GRADED[$examined]:$GRADED_NAMES"
[ "$red" -ne 0 ] && echo "RED[$red]:$RED_NAMES"
gate_verdict "$red" "program(s) diverging from the oracle under the filename-length x mode sweep --- RED:${RED_NAMES:- none} --- GRADED:$GRADED_NAMES ---"
