#!/usr/bin/env bash
# test_gate_zd_check_a_read_across_a_retaining_box_goes_through_its_frame.sh -- A GREEN READING THAT CAN FAIL AND IS SHOWN TO HAVE BEEN EXERCISED
# (the coo's 14:4x audit of the closed row zsm-match-defer-gamma-depth-..., the cto's row zd-check-a-read-across-a-retaining-box-reaches-its-cell-
# through-a-frame-home-counted-and-able-to-fail-ceo-1925). The law: a box after a box the planner grades as retaining (a nonzero retains code, 1 to 11,
# the DEFERRED PATTERN among them) reads a cell produced before it through a frame home, never by a fixed rsp distance, because the retaining box's
# live depth is not a compile-time constant. ZD-CHECK's READ arm holds the law but prints nothing when a read goes through the frame, so a green reading
# never showed that a single read had been tested. THE INSTRUMENT is the verifier's per-graph line (SCRIP_ZD_CHECK=1, planner zeta_plan.cpp zd_place):
#   [ZD-CHECK] CROSS graph=<g> reads=<r> via_frame=<f> via_rsp=<s> rsp_codes=<code>:<n>,...
# r counts every operand read crossed by a retaining edge BY PATH (below), f those the emitter reaches through a frame home, s the rest, which the emitter reads at an
# rsp distance; rsp_codes names the retains code of the first crossing edge of each such read.
# The gate extracts every PARTITION.tsv core entry of each master (as test_gate_zd_check_reads_zero_violations_on_the_cores.sh does), compiles it in mode 4
# with SCRIP_ZD_CHECK=1 and sums the lines. PRINTS one line per language and a total:
#   ZD_CROSS_BOARD lang=<l> entries=<n> compiled=<c> reads=<r> via_frame=<f> via_rsp=<s> rsp_codes=<code:n,...>
#   ZD_CROSS_TOTAL reads=<r> via_frame=<f> via_rsp=<s>
# THE COUNT IS BY PATH (the cto, ARCH-ZETA-ONE-COORDINATE section 8, 2026-10-29): a read crosses when a retaining edge lies on a path of control edges from the
# producer to the consumer with no discard between whose record is definite (UNMARK, a completed MATCH_BEGIN..MATCH_END, STATEMENT_BEGIN, CUT); a backward edge into
# an alternation, disjunction or gate is that construct's JOIN and continues to its gamma only. The retaining edges are the planner's own table, zd_edge_retains_g
# (codes 3 8 9 10 11, in a resumable frame) PLUS THE DEFER (code 7), and the PENDING set 4 5 6 (a generator, a retaining and an unresolved callee) which joins the
# zero set at Icon's switch; codes 1 and 2 are not continuation-breaking. A crossing read is read through a frame when the emitter has a frame word for it (the RBP
# mirror xf, a local home, a frame slot, an ACT slot such as the capture cell of a SAVE/COND pair, or an operand with no spine cell), else at an rsp distance.
# MEASURED 2026-10-29 at SCRIP HEAD over the seven cores: 321 crossing reads, every one through a frame, none at an rsp distance. THE HISTORY OF THE COUNT, same
# cores: the node-order span read 660 crossing reads and 206 at an rsp distance (SNOBOL4 25, Snocone 15, Rebus 1, Icon 147, Prolog 18); by path with the discard stop
# 164; with the ACT slot counted as a frame word 130 (the SAVE/COND captures of SNOBOL4 and Snocone read `[rbp + n]`, measured with gdb: the depth at the capture takes
# 152, 520, 424 and 712 across calls and the program is right); with the planner's own retains table instead of the bare code 1 (Icon's 129 held-disjunction reads sat
# in a frame that is not resumable, where the planner proves the base definite); with the join rule 0.
# THE LAW (via_rsp 0 for the zero set and the PENDING set) is held at floor 0 for every language and code: CODE_FLOOR below is the table of exceptions, empty, and a
# floor may only fall. --floors-zero grades with every floor 0 (today the same), --inject-rsp-read adds one synthetic rsp read to the SNOBOL4 board and must read RED
# (the script's own negative control of the floor logic, not a seam in SCRIP).
# THE RUNTIME ARMS (CEO-1680, a proper test, no seam in SCRIP): two witnesses whose retained extent takes two or more sizes across one read -- a SNOBOL4 variable
# holding a one-node pattern then alternations of ARBNOs, the capture read after the DEFER inside the open match (gdb: the depth at the capture takes 152, 520, 424
# and 712 across the calls); an Icon suspending procedure whose call to a generator holds a frame for one argument, fails for another and returns plain for a third,
# a literal read across it -- run in mode 3 and mode 4 against text cut from SPITBOL (-bf) and iconx, and must show crossing reads, none at an rsp distance.
# --corrupt-ref damages the expected text (the script's own switch) and reads RED.
# rc 0 every language reads every code at or under its floor AND the SNOBOL4 core read at least one crossing read (deferred patterns exercise the law, so a
# count of 0 means the instrument sees nothing and the green is vacuous) AND both witnesses pass; rc 1 a bar unmet; rc 2 cannot measure (no scrip, a master without a
# partition, a language whose core compiled 0 entries). --lang <l> limits the board to one language; --witnesses-only runs the two witnesses alone; --corrupt-ref damages their expected text (RED).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$(cd "$HERE/../../SCRIP" 2>/dev/null && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP"; exit 2; }
CORPUS="$(cd "$HERE/../../corpus" 2>/dev/null && pwd)" || { echo "REFUSE(2): no corpus beside harness"; exit 2; }
[ -x "$SCRIP/scrip" ] || { echo "REFUSE(2): $SCRIP/scrip is not built"; exit 2; }
ONLY=""; ZERO=0; CORRUPT=0; WONLY=0; INJECT=0; while [ $# -gt 0 ]; do case "$1" in --lang) ONLY="$2"; shift;; --floors-zero) ZERO=1;; --corrupt-ref) CORRUPT=1;; --witnesses-only) WONLY=1;; --inject-rsp-read) INJECT=1;; *) echo "REFUSE(2): unknown argument $1"; exit 2;; esac; shift; done
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_zdcross.XXXXXX")" || { echo "REFUSE(2): mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
declare -A CODE_FLOOR=()
rc=0; TR=0; TF=0; TS=0; NL=0; SNO_READS=0
for pair in snobol4:sno icon:icn prolog:pl raku:raku pascal:pas snocone:sc rebus:reb; do
    lang="${pair%%:*}"; ext="${pair##*:}"
    [ "$WONLY" = 0 ] || continue
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
        out="$( cd "$SCRIP" && SCRIP_ZD_CHECK=1 timeout -k 2 60 ./scrip --compile --out="$W/$lang.$n.s" "$src" < /dev/null 2>&1 >/dev/null | grep '^\[ZD-CHECK\] CROSS ' )"
        c=$((c+1))
        [ -n "$out" ] || continue
        er="$(printf '%s\n' "$out" | sed -n 's/.* reads=\([0-9][0-9]*\) via_frame.*/\1/p' | awk '{x+=$1} END{print x+0}')"
        ef="$(printf '%s\n' "$out" | sed -n 's/.* via_frame=\([0-9][0-9]*\) via_rsp.*/\1/p' | awk '{x+=$1} END{print x+0}')"
        es="$(printf '%s\n' "$out" | sed -n 's/.* via_rsp=\([0-9][0-9]*\) rsp_codes.*/\1/p' | awk '{x+=$1} END{print x+0}')"
        printf '%s\n' "$out" | sed -n 's/.* rsp_codes=\(.*\)$/\1/p' | tr ',' '\n' | grep -v '^$' >> "$W/$lang.codes"
        r=$((r+er)); f=$((f+ef)); s=$((s+es))
    done < "$D/PARTITION.tsv"
    [ "$c" -gt 0 ] || { echo "REFUSE(2): $lang core compiled 0 entries of $n"; exit 2; }
    [ "$INJECT" = 0 ] || [ "$lang" != snobol4 ] || { echo "7:1" >> "$W/$lang.codes"; s=$((s+1)); }
    codes="$(awk -F: '{a[$1]+=$2} END{for (k in a) printf "%s:%d,", k, a[k]}' "$W/$lang.codes")"
    over=0; below=0; tags=""
    for cc in $(printf '%s' "$codes" | tr ',' ' '); do
        code="${cc%%:*}"; cnt="${cc##*:}"; floor="${CODE_FLOOR[$lang:$code]:-0}"; [ "$ZERO" = 0 ] || floor=0
        [ "$cnt" -le "$floor" ] || { over=1; tags="$tags CODE-$code-OVER-FLOOR-$floor"; }
        [ "$cnt" -ge "$floor" ] || { below=1; tags="$tags CODE-$code-BELOW-FLOOR-LOWER-IT"; }
    done
    for cf in "${!CODE_FLOOR[@]}"; do
        [ "${cf%%:*}" = "$lang" ] && [ "$ZERO" = 0 ] || continue
        case ",$codes" in *",${cf##*:}:"*) ;; *) below=1; tags="$tags CODE-${cf##*:}-BELOW-FLOOR-LOWER-IT";; esac
    done
    echo "ZD_CROSS_BOARD lang=$lang entries=$n compiled=$c reads=$r via_frame=$f via_rsp=$s rsp_codes=${codes:--}$( [ "$over" = 1 ] && echo " RSP-OVER-FLOOR$tags" )$( [ "$below" = 1 ] && [ "$over" = 0 ] && echo "$tags" )"
    NL=$((NL+1)); TR=$((TR+r)); TF=$((TF+f)); TS=$((TS+s))
    [ "$lang" = snobol4 ] && SNO_READS=$r
    [ "$over" = 0 ] || rc=1
done
WIT_RED=0
rt_witness() {
    local label="$1" ext="$2" want="$3" src="$W/wit_$1.$2" got m3 m4 cr er es
    cat > "$src"
    [ "$CORRUPT" = 0 ] || want="x${want}"
    m3="$( cd "$SCRIP" && timeout -k 2 60 ./scrip "$src" < /dev/null 2>&1 )"
    cr="$( cd "$SCRIP" && SCRIP_ZD_CHECK=1 timeout -k 2 60 ./scrip --compile --out="$W/wit_$label.s" "$src" < /dev/null 2>&1 >/dev/null | grep '^\[ZD-CHECK\] CROSS ' )"
    m4="REFUSED"
    if [ -s "$W/wit_$label.s" ] && gcc -m64 "$W/wit_$label.s" -o "$W/wit_$label.bin" -L"$SCRIP/out" -lscrip_rt -Wl,-rpath,"$SCRIP/out" -lm 2> /dev/null; then m4="$( timeout -k 2 60 "$W/wit_$label.bin" < /dev/null 2>&1 )"; fi
    er="$(printf '%s\n' "$cr" | sed -n 's/.* reads=\([0-9][0-9]*\) via_frame.*/\1/p' | awk '{x+=$1} END{print x+0}')"
    es="$(printf '%s\n' "$cr" | sed -n 's/.* via_rsp=\([0-9][0-9]*\) rsp_codes.*/\1/p' | awk '{x+=$1} END{print x+0}')"
    got="ok"; [ "$m3" = "$want" ] || got="M3-DIFFERS-FROM-THE-ORACLE"; [ "$m4" = "$want" ] || got="$got M4-DIFFERS-FROM-THE-ORACLE"
    [ "$er" -gt 0 ] || got="$got NO-CROSSING-READ-EXERCISED"; [ "$es" -eq 0 ] || got="$got $es-READS-AT-AN-RSP-DISTANCE"
    echo "ZD_CROSS_WITNESS $label crossing_reads=$er via_rsp=$es modes=$got"
    [ "$got" = ok ] || WIT_RED=1
}
if [ -z "$ONLY" ]; then
rt_witness defer_two_sizes sno "$(printf '[b]\n[acacab]\n[b]\n[caab]\n[aaaaaaaacb]\n[b]')" <<'WIT'
        DEFINE('T(P,S)')
        P1 = 'b'
        P2 = ARBNO('a' | 'c') 'b'
        OUTPUT = T(P1, 'b')
        OUTPUT = T(P2, 'acacab')
        OUTPUT = T(P1, 'b')
        OUTPUT = T(P2, 'caab')
        OUTPUT = T(P2, 'aaaaaaaacb')
        OUTPUT = T(P1, 'xbx')
        :(END)
T       S ? *P . V :F(NO)
        T = '[' V ']' :(RETURN)
NO      T = 'nomatch' :(RETURN)
END
WIT
rt_witness generator_callee_two_sizes icn "$(cat <<'WANT'
v 1 <1>1
v 1 <10>1
v 1 <100>1
v 2 <2>2
v 2 <20>2
v 2 <200>2
v 4 plain4
w 1 [<1>1] 1
w 2 [<2>2] 2
w 3 [none] 3
w 4 [plain4] 4
WANT
)" <<'WIT'
procedure g(n)
   if n > 2 then fail;
   suspend n | n * 10 | n * 100;
end
procedure p(n)
   if n = 4 then return "plain" || n;
   suspend "<" || g(n) || ">" || n;
end
procedure main()
   every i := 1 to 4 do
      every write("v ", i, " ", p(i));
   every i := 1 to 4 do
      write("w ", i, " ", "[" || (p(i) | "none") || "]", " ", i);
end
WIT
fi
echo "ZD_CROSS_TOTAL reads=$TR via_frame=$TF via_rsp=$TS"
if [ "$WONLY" = 0 ] && { [ -z "$ONLY" ] || [ "$ONLY" = snobol4 ]; }; then
    [ "$SNO_READS" -gt 0 ] || { echo "RED: the SNOBOL4 core read 0 crossing reads -- deferred patterns exercise the law, so the instrument sees nothing and the green is vacuous"; rc=1; }
fi
[ "$WIT_RED" = 0 ] || rc=1
[ "$rc" -eq 0 ] && echo "GATE OK [zd_check_a_read_across_a_retaining_box_goes_through_its_frame]: no language reads more crossing reads at an rsp distance than its floor, and the law was exercised" \
    || echo "GATE RED [zd_check_a_read_across_a_retaining_box_goes_through_its_frame]: a language reads more rsp crossing reads than its floor (RSP-OVER-FLOOR above), the SNOBOL4 core exercised none, or a two-size witness differs from its oracle"
exit $rc
