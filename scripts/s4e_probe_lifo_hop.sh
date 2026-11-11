#!/usr/bin/env bash
# s4e_probe_lifo_hop.sh plan|offsets|run|verify|final [SCRIP] | same PARENT_SCRIP [CHILD_SCRIP] | --list -- THE PROBES OF prolog-lifo STEP 4 ROWS
# A1, A2, B, C AND D (the cto's CTO-631, GOAL-CTO.md de19e5991; written by officer_02 2026-11-11): A COMMIT UNMARK CARRIES THE HOP CHAIN TO ITS
# BOUND'S RECORD ON THE SPINE, STAGED BEHIND THE PLAN-TIME SWITCH SCRIP_PL_BOUND_HOP=1 THAT ROW D DELETES. Columns are found by their PLAN_COLUMNS names.
#   plan     (A1) under the switch, --dump-plan of lifo_catch_findall prints, inside one PLAN graph, a PLAN_ROW kind=IR_UNMARK whose hop_n reads 1
#            or more and a PLAN_ROW kind=IR_BOUND whose K reads 1 or more (a record carved on the spine; the definite column is the run's base,
#            not the BOUND's definiteness, so it is not read). MEASURED 2026-11-11 at SCRIP 145ad3835 (officer_02, this arm): no hop_n column,
#            RED; 36 of the 146 IR_BOUND rows already read SPINE, so a K alone proves nothing: the chain on the UNMARK is what the switch adds.
#   offsets  (A2) plan GREEN, and every IR_UNMARK row with hop_n N of 1 or more prints hop_rec as N comma-separated integers and hop_c as one
#            integer; every row with hop_n 0 or -1 prints hop_rec - and hop_c -.
#   run      (B) offsets GREEN, and under the switch test_design_prolog_lifo_steps.sh --step 4 reads m3 and m4 full (every step-4 witness
#            prints its .ref in both modes under SCRIP_ZD_RTCHECK=1); the step's own probe column is not read here (row D reads it).
#   verify   (C) run GREEN, and under the switch with SCRIP_ZD_RTCHECK=1 the mode-4 compile of lifo_catch_findall prints on stderr exactly one
#            line ZVERIFY_HOP checked=M bad=0 with M equal to the number of IR_UNMARK rows of its plan with hop_n 1 or more.
#   final    (D) no SCRIP_PL_BOUND_HOP in SCRIP/src, plan GREEN with the switch unset, and test_design_prolog_lifo_steps.sh --step 4 GREEN.
#   same     the proof of A1, A2 and B that the switch unset changes nothing: the mode-4 .s of the eight step-4 witnesses and of the Prolog smoke
#            programs (the heredocs of test_smoke_prolog.sh) is byte-identical between PARENT_SCRIP and CHILD_SCRIP (default the root's
#            SCRIP/scrip). A proof step, never a DONE-WHEN: after the landing there is no parent. About 90 s a program pair on a loaded box.
# rc 0 GREEN, 1 RED naming what is red, 2 REFUSE. Writes only under /tmp/s4e/<seat>.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"
me="s4e_probe_lifo_hop"
refuse() { echo "REFUSE(2) [$me]: $*"; exit 2; }
arm="${1:-}"
[ "$arm" = "--list" ] && { sed -n '4,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0; }
case "$arm" in plan|offsets|run|verify|final|same) ;; *) refuse "usage: $me.sh plan|offsets|run|verify|final [SCRIP] | same PARENT_SCRIP [CHILD_SCRIP] | --list";; esac
lifo="$root/corpus/tests/prolog/lifo"; [ -d "$lifo" ] || refuse "no $lifo"
wit="$lifo/lifo_catch_findall.pl"; [ -f "$wit" ] || refuse "no witness $wit"
seat="${S4E_SEAT:-probe}"; mkdir -p "/tmp/s4e/$seat"; t="$(mktemp -d "/tmp/s4e/$seat/lifo_hop_$arm.XXXXXX")" || refuse "no scratch"
trap 'rm -rf "$t"' EXIT
tree="$(git -C "$root/SCRIP" rev-parse --short=9 HEAD 2>/dev/null)"
if [ "$arm" = same ]; then
    parent="${2:-}"; child="${3:-$root/SCRIP/scrip}"
    [ -n "$parent" ] && [ -x "$parent" ] || refuse "no parent binary (give the root's build of the parent tree)"
    [ -x "$child" ] || refuse "no child binary at $child"
    [ "$(readlink -f "$parent")" != "$(readlink -f "$child")" ] || refuse "the parent and the child are one binary: the comparison measures nothing"
    mkdir -p "$t/src"
    w4="$(awk -F'\t' '$1 == 4 { print $5 }' "$lifo/STEPS.tsv")"; [ -n "$w4" ] || refuse "STEPS.tsv names no step-4 witnesses"
    for w in $w4; do [ -f "$lifo/$w.pl" ] || refuse "no witness $w.pl"; cp "$lifo/$w.pl" "$t/src/"; done
    awk -v d="$t/src" '/^pl "/{ split($0, a, "\""); n=d "/smoke_" a[2] ".pl"; on=1; next } on && /^EOF$/{ on=0; close(n); next } on { print > n }' "$here/test_smoke_prolog.sh"
    np="$(ls "$t/src"/*.pl 2>/dev/null | wc -l)"; ns="$(ls "$t/src"/smoke_*.pl 2>/dev/null | wc -l)"
    [ "$ns" -gt 0 ] || refuse "no smoke program extracted from test_smoke_prolog.sh"
    diff=0; bad=0
    for p in "$t/src"/*.pl; do
        b="$(basename "$p" .pl)"
        ( cd "$t" && env -u SCRIP_PL_BOUND_HOP timeout -k 5 300 bash "$here/util_run_slot.sh" "$parent" --compile --target=x86 "$p" < /dev/null > "$t/$b.parent.s" 2> /dev/null ); r1=$?
        ( cd "$t" && env -u SCRIP_PL_BOUND_HOP timeout -k 5 300 bash "$here/util_run_slot.sh" "$child" --compile --target=x86 "$p" < /dev/null > "$t/$b.child.s" 2> /dev/null ); r2=$?
        { [ "$r1" = 0 ] && [ -s "$t/$b.parent.s" ]; } || { bad=$((bad + 1)); echo "  UNCOMPILED by the parent: $b (rc $r1)"; continue; }
        cmp -s "$t/$b.parent.s" "$t/$b.child.s" || { diff=$((diff + 1)); echo "  DIFFERS: $b (child rc $r2, first difference $(cmp "$t/$b.parent.s" "$t/$b.child.s" 2>/dev/null | sed 's/.*, //'))"; }
        rm -f "$t/$b.parent.s" "$t/$b.child.s"
    done
    echo "LIFO_HOP_SAME_BOARD programs=$np smoke=$ns differ=$diff uncompiled=$bad (child tree $tree)"
    [ "$bad" = 0 ] || refuse "$bad program(s) the parent did not compile: the comparison does not cover the population"
    [ "$diff" = 0 ] && { echo "GATE OK [$me same]: the mode-4 .s of $np programs is byte-identical with the switch unset"; exit 0; }
    echo "GATE FAIL [$me same]: $diff of $np programs emit a different .s with the switch unset"; exit 1
fi
scrip="${2:-$root/SCRIP/scrip}"; [ -x "$scrip" ] || refuse "no binary at $scrip (make -j8 first)"
[ -n "${2:-}" ] || { bash "$here/util_require_fresh.sh" --gate "$me" >/dev/null 2>&1 || { bash "$here/util_require_fresh.sh" --gate "$me"; exit 2; }; }
plan_dump() {   # <switch 1|unset> <out>
    if [ "$1" = 1 ]; then ( cd "$t" && SCRIP_PL_BOUND_HOP=1 timeout -k 5 180 "$scrip" --dump-plan "$wit" < /dev/null > "$2" 2> /dev/null ) || true
    else ( cd "$t" && env -u SCRIP_PL_BOUND_HOP timeout -k 5 180 "$scrip" --dump-plan "$wit" < /dev/null > "$2" 2> /dev/null ) || true; fi
    grep -q '^PLAN_COLUMNS ' "$2" && grep -q '^PLAN_ROW .*kind=IR_UNMARK' "$2" && grep -q '^PLAN_ROW .*kind=IR_BOUND' "$2" \
        || refuse "--dump-plan of $(basename "$wit") printed no PLAN_COLUMNS, no IR_UNMARK row or no IR_BOUND row"
}
plan_verdict() {   # <dump> <label> -> rc 0 GREEN, 1 RED; prints the board line
    local cols hopped carved both undecided
    read -r cols hopped carved both undecided <<< "$(awk '
        /^PLAN_COLUMNS /{ h=0; k=0; for (i=2; i<=NF; i++) { if ($i=="hop_n") h=i-1; if ($i=="K") k=i-1 } }
        /^PLAN graph=/{ if (gu && gb) both++; gu=0; gb=0 }
        /^PLAN_ROW / && h && /kind=IR_UNMARK/ { v=$(h+4); if (v+0 >= 1) { gu=1; hu++ } else if (v == "-1") und++ }
        /^PLAN_ROW / && k && /kind=IR_BOUND/ && ($(k+4)+0) >= 1 { gb=1; kb++ }
        END{ if (gu && gb) both++; print (h ? 1 : 0), hu+0, kb+0, both+0, und+0 }' "$1")"
    echo "LIFO_HOP_PLAN_BOARD $2 hop_column=$cols unmark_rows_with_chain=$hopped bounds_on_spine=$carved graphs_with_both=$both undecided_unmarks=$undecided (tree $tree)"
    [ "$cols" = 1 ] || { echo "  RED: PLAN_COLUMNS names no hop_n column"; return 1; }
    [ "$both" -ge 1 ] || { echo "  RED: no PLAN graph holds both an IR_UNMARK with hop_n 1 or more ($hopped rows) and an IR_BOUND with K 1 or more ($carved rows)"; return 1; }
    return 0
}
step4() {   # <switch 1|unset> -> prints the STEP line into $t/step4.txt; rc of the harness
    if [ "$1" = 1 ]; then SCRIP_PL_BOUND_HOP=1 timeout -k 5 3600 bash "$here/test_design_prolog_lifo_steps.sh" --step 4 < /dev/null > "$t/step4.txt" 2>&1
    else env -u SCRIP_PL_BOUND_HOP timeout -k 5 3600 bash "$here/test_design_prolog_lifo_steps.sh" --step 4 < /dev/null > "$t/step4.txt" 2>&1; fi
}
if [ "$arm" = final ]; then
    n="$(grep -rl 'SCRIP_PL_BOUND_HOP' "$root/SCRIP/src" 2>/dev/null | wc -l)"
    plan_dump unset "$t/plan.txt"; plan_verdict "$t/plan.txt" switch=unset; pr=$?
    step4 unset; sr=$?; sl="$(grep '^STEP 4 ' "$t/step4.txt" | tail -1)"
    [ -n "$sl" ] || refuse "test_design_prolog_lifo_steps.sh --step 4 printed no STEP line (rc $sr)"
    echo "LIFO_HOP_FINAL_BOARD switch_files=$n plan=$([ $pr = 0 ] && echo GREEN || echo RED) step4_rc=$sr (tree $tree)"; echo "  $sl"
    [ "$sr" = 2 ] && refuse "the step-4 harness refused"
    [ "$n" = 0 ] && [ "$pr" = 0 ] && [ "$sr" = 0 ] && { echo "GATE OK [$me final]: the switch is gone, the chain is planned unconditionally and step 4 reads GREEN"; exit 0; }
    echo "GATE FAIL [$me final]: switch files $n, plan rc $pr, step 4 rc $sr"; exit 1
fi
plan_dump 1 "$t/plan.txt"; plan_verdict "$t/plan.txt" switch=1; pr=$?
[ "$arm" = plan ] && { [ "$pr" = 0 ] && { echo "GATE OK [$me plan]: a commit UNMARK of lifo_catch_findall carries a hop chain beside a BOUND carved on the spine"; exit 0; }; echo "GATE FAIL [$me plan]"; exit 1; }
[ "$pr" = 0 ] || { echo "GATE FAIL [$me $arm]: the plan arm reads RED first"; exit 1; }
read -r good badrows <<< "$(awk '
    /^PLAN_COLUMNS /{ h=0; r=0; c=0; for (i=2; i<=NF; i++) { if ($i=="hop_n") h=i-1; if ($i=="hop_rec") r=i-1; if ($i=="hop_c") c=i-1 } }
    /^PLAN_ROW / && /kind=IR_UNMARK/ && h {
        n=$(h+4); hr=(r ? $(r+4) : ""); hc=(c ? $(c+4) : "")
        if (n+0 >= 1) { m=split(hr, a, ","); ok=(r && c && m == n+0 && hc ~ /^-?[0-9]+$/); for (j=1; j<=m && ok; j++) if (a[j] !~ /^-?[0-9]+$/) ok=0; if (ok) g++; else b++ }
        else if (!(r && c && hr == "-" && hc == "-")) b++ }
    END{ print g+0, b+0 }' "$t/plan.txt")"
echo "LIFO_HOP_OFFSETS_BOARD chains_well_formed=$good rows_malformed=$badrows (tree $tree)"
[ "$good" -ge 1 ] && [ "$badrows" = 0 ] || { echo "GATE FAIL [$me $arm]: the offsets arm reads RED ($good chains well formed, $badrows rows malformed: hop_rec must be hop_n integers and hop_c one integer, or both - when hop_n is 0 or -1)"; exit 1; }
[ "$arm" = offsets ] && { echo "GATE OK [$me offsets]: $good chains carry hop_n resume-record distances and a cell distance"; exit 0; }
step4 1; sr=$?; sl="$(grep '^STEP 4 ' "$t/step4.txt" | tail -1)"
[ -n "$sl" ] || refuse "test_design_prolog_lifo_steps.sh --step 4 printed no STEP line under the switch (rc $sr)"
m3="$(printf '%s\n' "$sl" | sed -n 's/.* m3=\([0-9]*\/[0-9]*\) .*/\1/p')"; m4="$(printf '%s\n' "$sl" | sed -n 's/.* m4=\([0-9]*\/[0-9]*\) .*/\1/p')"
full() { [ -n "$1" ] && [ "${1%/*}" = "${1#*/}" ] && [ "${1#*/}" -gt 0 ]; }
echo "LIFO_HOP_RUN_BOARD switch=1 m3=${m3:-?} m4=${m4:-?} (tree $tree)"; echo "  $sl"
full "$m3" && full "$m4" || { echo "GATE FAIL [$me $arm]: under the switch the step-4 witnesses do not all print their .ref in both modes"; exit 1; }
[ "$arm" = run ] && { echo "GATE OK [$me run]: under the switch every step-4 witness prints its .ref in mode 3 and mode 4 under SCRIP_ZD_RTCHECK=1"; exit 0; }
want="$(awk '/^PLAN_COLUMNS /{ h=0; for (i=2; i<=NF; i++) if ($i=="hop_n") h=i-1 } /^PLAN_ROW / && /kind=IR_UNMARK/ && h && ($(h+4)+0) >= 1 { n++ } END{ print n+0 }' "$t/plan.txt")"
( cd "$t" && SCRIP_PL_BOUND_HOP=1 SCRIP_ZD_RTCHECK=1 timeout -k 5 600 bash "$here/util_run_slot.sh" "$scrip" --compile --target=x86 "$wit" < /dev/null > "$t/w.s" 2> "$t/w.err" ); cr=$?
[ "$cr" = 0 ] && [ -s "$t/w.s" ] || refuse "the mode-4 compile of $(basename "$wit") under the switch failed (rc $cr)"
nl="$(grep -c '^ZVERIFY_HOP ' "$t/w.err")"; vl="$(grep '^ZVERIFY_HOP ' "$t/w.err" | head -1)"
echo "LIFO_HOP_VERIFY_BOARD lines=$nl want_checked=$want read: ${vl:-none} (tree $tree)"
[ "$nl" = 1 ] && [ "$vl" = "ZVERIFY_HOP checked=$want bad=0" ] && { echo "GATE OK [$me verify]: the verifier checked all $want chains and found none bad"; exit 0; }
echo "GATE FAIL [$me verify]: want exactly one line ZVERIFY_HOP checked=$want bad=0"; exit 1
