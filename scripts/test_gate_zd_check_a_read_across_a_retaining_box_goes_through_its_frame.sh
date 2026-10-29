#!/usr/bin/env bash
# test_gate_zd_check_a_read_across_a_retaining_box_goes_through_its_frame.sh -- A GREEN READING THAT CAN FAIL AND IS SHOWN TO HAVE BEEN EXERCISED
# (the coo's 14:4x audit of the closed row zsm-match-defer-gamma-depth-..., the cto's row zd-check-a-read-across-a-retaining-box-reaches-its-cell-
# through-a-frame-home-counted-and-able-to-fail-ceo-1925). The law: a box after a box the planner grades as retaining (a nonzero retains code, 1 to 11,
# the DEFERRED PATTERN among them) reads a cell produced before it through a frame home, never by a fixed rsp distance, because the retaining box's
# live depth is not a compile-time constant. ZD-CHECK's READ arm holds the law but prints nothing when a read goes through the frame, so a green reading
# never showed that a single read had been tested. THE INSTRUMENT is the verifier's per-graph line (SCRIP_ZD_CHECK=1, planner zeta_plan.cpp zd_place):
#   [ZD-CHECK] CROSS graph=<g> reads=<r> via_frame=<f> via_rsp=<s> rsp_codes=<code>:<n>,...
# r counts every operand read whose producer-to-consumer span in the flat chain holds a box with a nonzero retains code, f those the emitter reaches
# through a frame home (the RBP mirror xf, a frame slot, or an operand with no spine cell), s the rest, which the emitter reads at an rsp distance.
# The gate extracts every PARTITION.tsv core entry of each master (as test_gate_zd_check_reads_zero_violations_on_the_cores.sh does), compiles it in mode 4
# with SCRIP_ZD_CHECK=1 and sums the lines. PRINTS one line per language and a total:
#   ZD_CROSS_BOARD lang=<l> entries=<n> compiled=<c> reads=<r> via_frame=<f> via_rsp=<s> rsp_codes=<code:n,...>
#   ZD_CROSS_TOTAL reads=<r> via_frame=<f> via_rsp=<s>
# THE LAW AS WRITTEN (via_rsp 0 on every core) IS RED TODAY: measured 2026-10-29 at SCRIP bfc485e9d plus the counter, 660 crossing reads over the seven cores,
# 454 through a frame and 206 at an rsp distance (snobol4 25 and snocone 15 and rebus 1, all code 7 the deferred pattern; icon 147, code 9 the
# disjunction that holds 146 and code 1 a suspend 1; prolog 18, code 3 an unknown callee 4 and code 11 a retaining target 14; raku and pascal 0), every
# one of those programs passing. So the gate is a RATCHET meanwhile, as test_gate_zd_check_reads_zero_violations_on_the_cores.sh was: RSP_FLOOR below is each
# language's via_rsp count at that cut, a language reading above its floor is RED, and a floor may only fall, by editing the table in the landing that
# lowers the count; which codes must reach 0 is the cto's ruling (a retaining box whose exits restore rsp to a fixed distance is not dynamic, the census
# calibration of 2026-10-21). --floors-zero grades the law as written (every floor 0), the script's own switch and the proof the gate can fail.
# rc 0 every language reads via_rsp at or under its floor AND the SNOBOL4 core read at least one crossing read (deferred patterns exercise the law, so a
# count of 0 means the instrument sees nothing and the green is vacuous); rc 1 a bar unmet; rc 2 cannot measure (no scrip, a master without a partition,
# a language whose core compiled 0 entries). --lang <l> limits it to one language.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$(cd "$HERE/../../SCRIP" 2>/dev/null && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP"; exit 2; }
CORPUS="$(cd "$HERE/../../corpus" 2>/dev/null && pwd)" || { echo "REFUSE(2): no corpus beside harness"; exit 2; }
[ -x "$SCRIP/scrip" ] || { echo "REFUSE(2): $SCRIP/scrip is not built"; exit 2; }
ONLY=""; ZERO=0; while [ $# -gt 0 ]; do case "$1" in --lang) ONLY="$2"; shift;; --floors-zero) ZERO=1;; *) echo "REFUSE(2): unknown argument $1"; exit 2;; esac; shift; done
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_zdcross.XXXXXX")" || { echo "REFUSE(2): mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
declare -A RSP_FLOOR=( [snobol4]=25 [icon]=147 [prolog]=18 [raku]=0 [rebus]=1 [pascal]=0 [snocone]=15 )
rc=0; TR=0; TF=0; TS=0; NL=0; SNO_READS=0
for pair in snobol4:sno icon:icn prolog:pl raku:raku pascal:pas snocone:sc rebus:reb; do
    lang="${pair%%:*}"; ext="${pair##*:}"
    [ -z "$ONLY" ] || [ "$ONLY" = "$lang" ] || continue
    D="$CORPUS/tests/$lang"
    [ -f "$D/PARTITION.tsv" ] && [ -f "$D/ALL.$ext" ] && [ -f "$D/ALL.ref" ] || { echo "REFUSE(2): $D has no PARTITION.tsv or ALL.$ext"; exit 2; }
    n=0; c=0; r=0; f=0; s=0; : > "$W/$lang.codes"
    while IFS=$'\t' read -r entry cls rest; do
        case "$entry" in ''|'#'*|entry) continue;; esac
        [ "$cls" = "core" ] || continue
        n=$((n+1))
        src="$W/$lang.$n.$ext"
        python3 "$HERE/corpus_suite_harness.py" extract "$D/ALL.$ext" "$D/ALL.ref" "$entry" "$src" --out-ref "$W/$lang.$n.ref" --out-in "$W/$lang.$n.in" > /dev/null 2>&1 || continue
        [ -s "$src" ] || continue
        out="$( cd "$SCRIP" && SCRIP_ZD_CHECK=1 timeout -k 2 60 ./scrip --compile -o "$W/$lang.$n.s" "$src" < /dev/null 2>&1 >/dev/null | grep '^\[ZD-CHECK\] CROSS ' )"
        c=$((c+1))
        [ -n "$out" ] || continue
        er="$(printf '%s\n' "$out" | sed -n 's/.* reads=\([0-9][0-9]*\) via_frame.*/\1/p' | awk '{x+=$1} END{print x+0}')"
        ef="$(printf '%s\n' "$out" | sed -n 's/.* via_frame=\([0-9][0-9]*\) via_rsp.*/\1/p' | awk '{x+=$1} END{print x+0}')"
        es="$(printf '%s\n' "$out" | sed -n 's/.* via_rsp=\([0-9][0-9]*\) rsp_codes.*/\1/p' | awk '{x+=$1} END{print x+0}')"
        printf '%s\n' "$out" | sed -n 's/.* rsp_codes=\(.*\)$/\1/p' | tr ',' '\n' | grep -v '^$' >> "$W/$lang.codes"
        r=$((r+er)); f=$((f+ef)); s=$((s+es))
    done < "$D/PARTITION.tsv"
    [ "$c" -gt 0 ] || { echo "REFUSE(2): $lang core compiled 0 entries of $n"; exit 2; }
    codes="$(awk -F: '{a[$1]+=$2} END{for (k in a) printf "%s:%d,", k, a[k]}' "$W/$lang.codes")"
    floor="${RSP_FLOOR[$lang]:-0}"; [ "$ZERO" = 0 ] || floor=0; over=0; [ "$s" -le "$floor" ] || over=1
    echo "ZD_CROSS_BOARD lang=$lang entries=$n compiled=$c reads=$r via_frame=$f via_rsp=$s rsp_floor=$floor rsp_codes=${codes:--}$( [ "$over" = 1 ] && echo ' RSP-OVER-FLOOR' )$( [ "$s" -lt "$floor" ] && echo ' BELOW-FLOOR-LOWER-IT' )"
    NL=$((NL+1)); TR=$((TR+r)); TF=$((TF+f)); TS=$((TS+s))
    [ "$lang" = snobol4 ] && SNO_READS=$r
    [ "$over" = 0 ] || rc=1
done
echo "ZD_CROSS_TOTAL reads=$TR via_frame=$TF via_rsp=$TS"
if [ -z "$ONLY" ] || [ "$ONLY" = snobol4 ]; then
    [ "$SNO_READS" -gt 0 ] || { echo "RED: the SNOBOL4 core read 0 crossing reads -- deferred patterns exercise the law, so the instrument sees nothing and the green is vacuous"; rc=1; }
fi
[ "$rc" -eq 0 ] && echo "GATE OK [zd_check_a_read_across_a_retaining_box_goes_through_its_frame]: no language reads more crossing reads at an rsp distance than its floor, and the law was exercised" \
    || echo "GATE RED [zd_check_a_read_across_a_retaining_box_goes_through_its_frame]: a language reads more rsp crossing reads than its floor (RSP-OVER-FLOOR above), or the SNOBOL4 core exercised none"
exit $rc
