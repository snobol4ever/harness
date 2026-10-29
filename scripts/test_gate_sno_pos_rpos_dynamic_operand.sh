#!/usr/bin/env bash
# test_gate_sno_pos_rpos_dynamic_operand.sh -- POS(N)/RPOS(N) with a DYNAMIC (variable) integer argument, under
# an ARBNO that has moved RSP, are read through the raw RSP-relative operand spelling FRQ(op_sa+8) instead of
# the frame-slot-safe XSAQ every other dynamic-argument match box already uses (any/notany/break/breakx/span/
# tab/rtab, plus LEN since its 2026-09-05 XSAQ cure -- src/templates/bb/bb_match_len.cpp). Because POS/RPOS are
# ZERO-WIDTH, a garbage cursor can never fault -- so instead of crashing (LEN's class) the match returns the
# WRONG ANSWER SILENTLY at rc=0, in BOTH modes, and no board anywhere flags it.
#
# PROVEN by hq_U 2026-09-05 (SCRIP 23c6e45d6 / corpus 7ffe8b899, oracle /home/resources/x64/bin/sbl -bf): three
# witnesses, 20/20 WRONG at every swept filename length, deterministic (unlike the LEN class's 13-18/20, which
# reads a garbage INDEX that sometimes faults -- POS/RPOS read a garbage cursor into a COMPARISON, which is
# simply never equal). Row snobol4-pos-rpos-dynamic-operand-returns-a-silently-wrong-answer.
#
# ⛔ THIS GATE IS WITNESS-ONLY (seat11, rung 1): it PROVES the class, it does not cure it -- the cure
# (src/templates/bb/bb_match_pos.cpp, bb_match_rpos.cpp) is hq_U's to author. It is EXPECTED to read RED/
# VIOLATION(1) until that cure lands; a RED verdict here is this gate doing its job, not a broken gate. Once
# the cure lands this becomes the standing regression gate for the class -- same script, no rewrite needed,
# only the tree underneath changes from red to green.
#
# ⛔ THE SWEEP IS NOT OPTIONAL (hq_S FINDING-2026-09-05-hq_S-nqueens-is-a-dynamic-len-operand-read-through-a-
# moving-rsp-not-an-arbno-recede.md sec 2): argv length shifts the initial stack, which shifts every RSP-
# relative address, so a single invocation is one sample of a coin. Every witness AND control below runs at
# BASENAME lengths 1..20 (a run of 'x' characters plus the .sno extension) in BOTH modes -- a single-length or
# single-mode read of any of them is not evidence of anything. These three witnesses happen to be deterministic
# (20/20 at every length observed), but the sweep runs regardless: determinism is a property of the witness,
# not of the class, and a gate that samples once would read a future, less-deterministic sibling as cured when
# it is 1/20.
#
# CONTROLS (pos_dyn_lit, rpos_dyn_lit, pos_dyn_noarbno, rpos_dyn_inline) discriminate this class from a plain
# alternation/ARBNO semantics bug: a literal argument, no ARBNO, and the inline RPOS shape are all correct
# today and MUST stay correct under the identical sweep, or this gate cannot tell "the known class" from "a new
# regression" apart.
#
# rc=0 CLEAN (nothing swept diverges from the oracle, in either mode), rc=1 VIOLATION (at least one does),
# rc=2 UNPROVEN (no oracle, no fresh binary, or a zero denominator -- never printed as a pass).
# THE SEVEN PROGRAMS ARE MASTER ENTRIES (hq_snobol4 2026-10-17, row snobol4-absorb-every-owed-source-into-the-one-master-
# unabsorbed-census-reads-zero): each is extracted from tests/snobol4/ALL.{sno,ref} by its ORIGIN (its old loose basename,
# the durable key in ALL.csv), never by the entry name the builder assigns and may re-sort.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S4E="$(cd "$ROOT/.." && pwd)"
GATE_NAME=sno_pos_rpos_dynamic_operand
. "$HERE/lib_oracle_flags.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: lib_oracle_flags.sh unavailable"; exit 2; }
. "$HERE/lib_gate.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: lib_gate.sh unavailable"; exit 2; }
gate_parse_args "$@"
O="$(sbl_correctness_bin)" || exit 2
gate_require_exec "$ROOT/scrip" "the scrip binary"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"

W="$S4E/corpus/tests/snobol4"
T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT

PROGS="pos_dyn_var rpos_dyn_var pos_dyn_inline pos_dyn_lit rpos_dyn_lit pos_dyn_noarbno rpos_dyn_inline"
CONTROLS=" pos_dyn_lit rpos_dyn_lit pos_dyn_noarbno rpos_dyn_inline "

m4_run() {   # $1 = source .sno (absolute), $2 = basename (no ext), writes stdout+stderr to $3
    local src="$1" name="$2" outfile="$3"
    ( cd "$T" && timeout -k 5 30s "$ROOT/scrip" --compile --out="$name.s" "$src" </dev/null >/dev/null 2>&1 ) || { echo "M4-COMPILE-FAILED" > "$outfile"; return; }
    ( cd "$T" && gcc -no-pie "$name.s" -o "$name.bin" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ) || { echo "M4-LINK-FAILED" > "$outfile"; return; }
    ( cd "$T" && timeout -k 5 10s "./$name.bin" </dev/null >"$outfile" 2>&1 )
}

red=0; examined=0; RED_NAMES=''; GRADED_NAMES=''
for p in $PROGS; do
    src="$T/w_$p.sno"; ref="$T/w_$p.ref"
    if ! python3 "$HERE/corpus_suite_harness.py" extract "$W/ALL.sno" "$W/ALL.ref" --origin "$p" "$src" --out-ref "$ref" >/dev/null 2>&1 || [ ! -f "$src" ] || [ ! -f "$ref" ]; then
        echo "GATE UNPROVEN(2) [$GATE_NAME]: the master entry of origin $p could not be extracted from $W/ALL.{sno,ref,csv}"; gate_stamp; exit 2
    fi
    timeout -k 5 20 "$O" -bf "$src" </dev/null >"$T/$p.oref" 2>/dev/null
    if ! cmp -s "$T/$p.oref" "$ref"; then
        echo "RED  $p: committed ref disagrees with the live oracle -- re-cut it (oracle/ref drift, not this class)"
        red=$((red+1)); examined=$((examined+1)); RED_NAMES="$RED_NAMES $p(ref-drift)"; GRADED_NAMES="$GRADED_NAMES $p"; continue
    fi
    is_control=0
    case "$CONTROLS" in *" $p "*) is_control=1;; esac
    body="$(cat "$src")"
    ok3=0; ok4=0
    for len in $(seq 1 20); do
        name="$(printf 'x%.0s' $(seq 1 "$len"))"
        fn="$T/$name.sno"
        printf '%s\n' "$body" > "$fn"
        ( cd "$T" && timeout -k 5 10s "$ROOT/scrip" "$name.sno" </dev/null >"$T/$name.m3" 2>&1 )
        cmp -s "$T/$name.m3" "$ref" && ok3=$((ok3+1))
        m4_run "$fn" "$name" "$T/$name.m4"
        cmp -s "$T/$name.m4" "$ref" && ok4=$((ok4+1))
        rm -f "$fn" "$T/$name.m3" "$T/$name.m4" "$T/$name.s" "$T/$name.bin"
    done
    examined=$((examined+1)); GRADED_NAMES="$GRADED_NAMES $p"
    tag="witness"; [ "$is_control" = 1 ] && tag="control"
    if [ "$ok3" -eq 20 ] && [ "$ok4" -eq 20 ]; then
        echo "PASS $p [$tag]: 20/20 m3, 20/20 m4 -- matches the oracle across the filename-length sweep in both modes"
    else
        echo "RED  $p [$tag]: m3=$ok3/20 m4=$ok4/20 match the oracle across the filename-length sweep"
        red=$((red+1)); RED_NAMES="$RED_NAMES $p[$tag]"
    fi
done
gate_floor "$examined" 7 "witness/control programs"
# ⛔ THE VERDICT LINE NAMES THE ENTRIES (ceo ruling 2026-09-05, wiring this gate into `make test` as a blocking
# arm): a blocking red that reports only a COUNT makes the reader open the script to learn what broke, and the
# whole reason this gate is wired red is that an unread gate reads as coverage while exercising nothing.
echo "GRADED[$examined]:$GRADED_NAMES"
[ "$red" -ne 0 ] && echo "RED[$red]:$RED_NAMES"
gate_verdict "$red" "program(s) diverging from the oracle under the filename-length x mode sweep --- RED:${RED_NAMES:- none} --- GRADED:$GRADED_NAMES ---"
