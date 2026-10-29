#!/usr/bin/env bash
# util_icon_disjunction_spine_witness.sh -- A RESUMABLE-ARM DISJUNCTION NEEDS NO RBP FRAME HOME (CEO-1865, ruled 2026-10-21: "ICON'S 70 DISJUNCTION HOMES: prove
# your reading first, with a variant that admits one resumable-arm disjunction to the spine and runs green or red. Then mint the row to hq_icon, naming that
# witness in its DONE-WHEN").
# THE VARIANT (hq_zetas, scratch worktree, never landed): zd_dj_retains() answers 0 for the named disjunction, and the beta regrow (op_zbgrow, SCRIP 48ee9deb2
# for a MATCH_ALTERNATE arm) is staged for an arm whose gamma lands on an IR_DISJUNCTION too. The disjunction then carves its 32 bytes on the spine
# (sub rsp, 32; the arm selector at [rsp + 16], the result cell at [rsp + 0]) instead of an rbp word, each arm's last box copies its result into that cell and
# pops its own carve at gamma, and the arm's beta carves it again.
#   icn_dj_spine_alt     every write((1 to 3) | (7 to 8)), every write(("a" | "b") || (1 to 2)) and every x := ((1 to 2) | 5) do write(x * 10): three
#                        disjunctions, two of them with a resumable arm. GREEN in both modes with either resumable one admitted, both, or all three.
#   icn_dj_spine_nested  every writes(" ", image(e[(1 to 3) | (4 to 5)]) | "\n"), two disjunctions, the inner (graph g0 node 11) a resumable-arm disjunction that is an
#                        operand of a subscript inside the outer one's first arm (node 7). GREEN in both modes when only the inner is admitted. RED when the outer
#                        is admitted (prints " 10 20" and stops), and red again with both admitted (" 10" and the newline arm): an arm that pops its carve at gamma
#                        pops the inner disjunction's selector and the subscript's carves with it, and the consumer's own carves then overwrite them before the
#                        arm's beta carves the region back. The TO arms of the first witness survive the pop only because a TO box keeps its counter in an rbp
#                        local. So the nested case is the OPEN question for hq_icon's resumable-arm design, reported here and never required to read 0.
# The refs are cut from the oracle (/home/resources/icon-master/bin/iconx), which agrees with SCRIP's stock output on both.
# What this script measures, per witness: (a) the program's output equals the ref in mode 3 and in mode 4, (b) scrip --dump-homes prints no IR_DISJUNCTION home
# whose reason is retaining-disjunction (the RBP frame word the planner gives a disjunction with a resumable arm). (a) is required for both witnesses; (b) is
# required to read 0 for icn_dj_spine_alt only (today 2) and is reported for icn_dj_spine_nested (today 2) as the open case.
#   util_icon_disjunction_spine_witness.sh
# Board line: ICON_DJ_SPINE_WITNESS witness=<name> m3=<PASS|FAIL> m4=<PASS|FAIL> retaining_disjunction_homes=<n>
# rc 0 every output equal and icn_dj_spine_alt has no retaining-disjunction home · rc 1 an output differs or that home remains · rc 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SC="$ROOT/SCRIP"
[ -x "$SC/scrip" ] || { echo "REFUSE(2): no $SC/scrip"; exit 2; }
[ -f "$SC/out/libscrip_rt.so" ] || { echo "REFUSE(2): no $SC/out/libscrip_rt.so"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
bad=0
for w in icn_dj_spine_alt icn_dj_spine_nested; do
    need=0; [ "$w" = icn_dj_spine_alt ] && need=1
    src="$HERE/fixtures/$w.icn"; ref="$HERE/fixtures/$w.ref"
    [ -f "$src" ] && [ -f "$ref" ] || { echo "REFUSE(2): no fixture $w"; exit 2; }
    homes="$("$SC/scrip" --dump-homes --compile --out="$T/$w.homes.s" "$src" < /dev/null 2>&1 | grep '^\[HOMES\]' | grep -c 'kind=IR_DISJUNCTION .*xfwhy=retaining-disjunction')"
    m3=FAIL; m4=FAIL
    timeout 60 "$SC/scrip" "$src" < /dev/null > "$T/$w.m3" 2>&1 && cmp -s "$T/$w.m3" "$ref" && m3=PASS
    if "$SC/scrip" --compile --out="$T/$w.s" "$src" < /dev/null > /dev/null 2>&1 \
        && gcc "$T/$w.s" -L"$SC/out" -lscrip_rt -lm -Wl,-rpath,"$SC/out" -o "$T/$w.bin" > /dev/null 2>&1 \
        && timeout 60 "$T/$w.bin" < /dev/null > "$T/$w.m4" 2>&1 && cmp -s "$T/$w.m4" "$ref"; then m4=PASS; fi
    echo "ICON_DJ_SPINE_WITNESS witness=$w m3=$m3 m4=$m4 retaining_disjunction_homes=$homes"
    [ "$m3" = PASS ] && [ "$m4" = PASS ] || bad=1
    [ "$need" = 0 ] || [ "$homes" = 0 ] || bad=1
done
[ "$bad" = 0 ] && { echo "WITNESS OK [util_icon_disjunction_spine_witness]: both witnesses run green in both modes and the alternation witness has no retaining-disjunction home"; exit 0; }
echo "WITNESS RED [util_icon_disjunction_spine_witness]: an output differs or a retaining-disjunction home remains"
exit 1
