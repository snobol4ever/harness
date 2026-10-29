#!/usr/bin/env bash
# test_design_planner_finish_steps.sh -- THE STEP-THROUGH HARNESS of DESIGN-PLAN: planner-finish (the cto, 2026-10-28, CEO-1996/1998;
# .github/ARCH-THREE-ZETAS-EMISSION.md section 11). The plan is corpus/tests/snobol4/planner_finish/STEPS.tsv; the witnesses are the
# planner_finish/ folders of corpus/tests/{snobol4,icon,prolog,pascal}, each program beside a .ref cut from its oracle (sbl -bf, icont/iconx,
# swipl 9.0.4 -q -t halt, fpc 3.2.2).
#
#   --list       print the steps and run nothing
#   --step N     grade step N: every witness of the step in mode 3 (./scrip w) and mode 4 (--compile, as, gcc, run), byte-equal to its .ref with
#                rc 0 (a move changes no byte, so a witness that reads red names a regression of the landing); then the step's PROBE tokens
#                (STEPS.tsv's header spells them: the census's A-fn counts, a symbol absent or present in a source scope, the slot-map
#                registration count, the two dumps, the ZSM frame line, the cfo's scoped bar, the finish): red before the step lands, green after
#   --out DIR    where the .s and logs go (default <root>/.scratch/planner_finish)
#
# VERDICT: STEP N <slug>: m3=<pass>/<n> m4=<pass>/<n> probe=<token:reading ...> -> GREEN|RED|REFUSED; rc 0 GREEN, 1 RED, 2 could not measure
# (no ./scrip, no witness, no ref, no census). The finish token runs the census bar, the count of the four names the plan deletes (drive_slots_all,
# zd_edge_retains, planner_home_dyn, planner_retains_emitter_view, named anywhere in src/; ARCH-THREE-ZETAS-EMISSION 11.7), the eight smokes and the nm gate,
# which take a minute, and names each.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SC="$ROOT/SCRIP"
STEPS="$ROOT/corpus/tests/snobol4/planner_finish/STEPS.tsv"
CENSUS="$HERE/util_emitter_memory_model_census.py"
NMGATE="$HERE/test_gate_planner_objects_leave_no_emitter_symbol_undefined.sh"
OUT="$ROOT/.scratch/planner_finish"
refuse() { echo "REFUSE(2): $*" >&2; exit 2; }
[ -f "$STEPS" ] || refuse "no step table at $STEPS"
mode=""; step=""
while [ $# -gt 0 ]; do
    case "$1" in
        --list) mode=list; shift ;;
        --step) mode=step; step="${2:-}"; [ -n "$step" ] || refuse "--step takes a number"; shift 2 ;;
        --out) OUT="${2:-}"; shift 2 ;;
        *) refuse "usage: $0 --list | --step N [--out DIR]" ;;
    esac
done
[ -n "$mode" ] || refuse "usage: $0 --list | --step N [--out DIR]"
col() { awk -F'\t' -v n="$1" -v k="$2" '!/^#/ && $1 == n {print $k; exit}' "$STEPS"; }
if [ "$mode" = list ]; then
    echo "DESIGN-PLAN: planner-finish -- $(awk -F'\t' '!/^#/ && $1 != "step" && NF >= 6' "$STEPS" | wc -l) steps (STEPS.tsv); witnesses in corpus/tests/<lang>/planner_finish"
    printf '%-4s %-38s %-32s %-14s %s\n' step slug executor depends witnesses
    for n in $(awk -F'\t' '!/^#/ && $1 != "step" {print $1}' "$STEPS"); do
        printf '%-4s %-38s %-32s %-14s %s\n' "$n" "$(col "$n" 2)" "$(col "$n" 3)" "$(col "$n" 4)" "$(col "$n" 6)"
    done
    exit 0
fi
[ -n "$(col "$step" 1)" ] || refuse "no step $step in $STEPS (--list names them)"
slug="$(col "$step" 2)"; probe="$(col "$step" 5)"; wits="$(col "$step" 6)"
[ -x "$SC/scrip" ] || refuse "no $SC/scrip"
[ -f "$CENSUS" ] || refuse "no census at $CENSUS"
mkdir -p "$OUT/step$step"
# one box-wide run slot for the step (CEO-1894)
if [ -z "${S4E_RUN_SLOT_HELD:-}" ]; then
    nslots="${S4E_RUN_SLOTS:-8}"; mkdir -p /tmp/s4e-run-slots; got=""
    for i in $(seq 0 $((nslots - 1))); do exec 9>"/tmp/s4e-run-slots/slot$i"; flock -n 9 && { got=$i; break; }; done
    [ -n "$got" ] || { exec 9>"/tmp/s4e-run-slots/slot$(( $$ % nslots ))"; flock 9; }
    export S4E_RUN_SLOT_HELD=1
fi
ext_of() { case "$1" in snobol4) echo sno ;; icon) echo icn ;; prolog) echo pl ;; pascal) echo pas ;; *) echo "" ;; esac; }
m3p=0; m4p=0; n=0; reds=""; first_src=""; first_dir=""
for w in $wits; do
    lang="${w%%/*}"; name="${w#*/}"; ext="$(ext_of "$lang")"; [ -n "$ext" ] || refuse "witness $w names no known language"
    dir="$ROOT/corpus/tests/$lang/planner_finish"; src="$dir/$name.$ext"; ref="$dir/$name.ref"; o="$OUT/step$step/$name"
    [ -f "$src" ] && [ -f "$ref" ] || refuse "witness $w has no .$ext or .ref in $dir"
    [ -n "$first_src" ] || { first_src="$name.$ext"; first_dir="$dir"; }
    n=$((n + 1))
    ( cd "$dir" && timeout -k 5 120 "$SC/scrip" "$name.$ext" < /dev/null > "$o.m3.out" 2> "$o.m3.err" ); rc=$?
    if [ "$rc" = 0 ] && cmp -s "$o.m3.out" "$ref"; then m3p=$((m3p + 1)); else reds="$reds m3:$w(rc$rc)"; fi
    if ( cd "$dir" && timeout -k 5 300 "$SC/scrip" --compile --out="$o.s" "$name.$ext" < /dev/null > /dev/null 2> "$o.m4c.err" ) \
       && gcc -c "$o.s" -o "$o.o" 2> /dev/null && gcc "$o.o" -L"$SC/out" -lscrip_rt -lm -Wl,-rpath,"$SC/out" -o "$o.bin" 2> /dev/null; then
        ( cd "$dir" && timeout -k 5 120 "$o.bin" < /dev/null > "$o.m4.out" 2> "$o.m4.err" ); rc=$?
        if [ "$rc" = 0 ] && cmp -s "$o.m4.out" "$ref"; then m4p=$((m4p + 1)); else reds="$reds m4:$w(rc$rc)"; fi
    else reds="$reds m4:$w(no-binary)"; fi
done
# the probe tokens
afn_count() { # $1 census args, $2 comma-separated callee names: the sum of their A-fn counts
    local out; out="$(cd "$SC" && python3 "$CENSUS" --only A $1 --list 2>/dev/null)" || return 0
    echo "$out" | awk -v names="$2" 'BEGIN { n = split(names, a, ","); for (i = 1; i <= n; i++) want[a[i]] = 1 } $1 == "A-fn" && ($2 in want) { s += $3 } END { print s + 0 }'
}
scope_files() { case "$1" in emit) echo "$SC/src/emitter $SC/src/templates" ;; planner) echo "$SC/src/planner" ;; all) echo "$SC/src" ;; *) echo "" ;; esac; }
grep_scope() { # $1 scope, $2 ERE: the count of matching lines over the scope's .c .cpp .h .inc files
    local files; files="$(scope_files "$1")"; [ -n "$files" ] || { echo -1; return; }
    # shellcheck disable=SC2086
    find $files -type f \( -name '*.c' -o -name '*.cpp' -o -name '*.h' -o -name '*.inc' \) -print0 2>/dev/null | xargs -0 grep -cE -- "$2" 2>/dev/null | awk -F: '{ s += $NF } END { print s + 0 }'
}
readings=""; pgreen=1
for tok in $probe; do
    key="${tok%%=*}"; val="${tok#*=}"
    case "$key" in
        afn) c="$(afn_count "" "$val")"; readings="$readings afn[$val]=$c"; [ "$c" = 0 ] || pgreen=0 ;;
        afn_in) fn="${val%%:*}"; cal="${val#*:}"; c="$(afn_count "--in $fn" "$cal")"; readings="$readings afn_in[$fn:$cal]=$c"; [ "$c" = 0 ] || pgreen=0 ;;
        afn_notin) fn="${val%%:*}"; cal="${val#*:}"; c="$(afn_count "--not-in $fn" "$cal")"; readings="$readings afn_notin[$fn:$cal]=$c"; [ "$c" = 0 ] || pgreen=0 ;;
        absent) sc="${val%%:*}"; re="${val#*:}"; c="$(grep_scope "$sc" "$re")"; readings="$readings absent[$sc:$re]=$c"; [ "$c" = 0 ] || pgreen=0 ;;
        present) sc="${val%%:*}"; re="${val#*:}"; c="$(grep_scope "$sc" "$re")"; readings="$readings present[$sc:$re]=$c"; [ "$c" -gt 0 ] 2>/dev/null || pgreen=0 ;;
        regmax) c="$(grep -c 'bb_slot_register(' "$SC/src/emitter/emit.cpp")"; d="$(grep -cE '^(void|extern void) bb_slot_register\(' "$SC/src/emitter/emit.cpp")"; c=$((c - d)); readings="$readings bb_slot_register_calls=$c(max $val)"; [ "$c" -le "$val" ] || pgreen=0 ;;
        dumps) pr="$(cd "$first_dir" && timeout -k 5 120 "$SC/scrip" --dump-plan --compile "$first_src" < /dev/null 2>/dev/null | grep -c '^PLAN_ROW')"
               hr="$(cd "$first_dir" && timeout -k 5 120 "$SC/scrip" --dump-homes --compile "$first_src" < /dev/null 2>&1 | grep -c -i 'HOME')"
               readings="$readings dump_plan_rows=$pr dump_homes_lines=$hr"; [ "$pr" -gt 0 ] && [ "$hr" -gt 0 ] || pgreen=0 ;;
        zsmframe) z=0; for w in $wits; do lang="${w%%/*}"; name="${w#*/}"; ext="$(ext_of "$lang")"; dir="$ROOT/corpus/tests/$lang/planner_finish"
                      ( cd "$dir" && SCRIP_ZSM=1 timeout -k 5 120 "$SC/scrip" --compile "$name.$ext" < /dev/null > /dev/null 2> "$OUT/step$step/$name.zsm.err" )
                      grep -E '^\[ZSM-FRAME\] .* addrs=[1-9]' "$OUT/step$step/$name.zsm.err" > /dev/null && z=$((z + 1)); done
                  readings="$readings zsm_frame_lines=$z/$n"; [ "$z" = "$n" ] || pgreen=0 ;;
        scoped) b="$(cd "$SC" && python3 "$CENSUS" --only A --in "$val" 2>/dev/null | sed -n 's/^SCOPED_BAR=\([0-9]*\).*/\1/p')"; readings="$readings scoped_bar=${b:-?}"; [ "$b" = 0 ] || pgreen=0 ;;
        finish) b="$(cd "$SC" && python3 "$CENSUS" 2>/dev/null | sed -n 's/.*bar=A+B+D=\([0-9]*\).*/\1/p' | head -1)"; readings="$readings bar=${b:-?}"; [ "$b" = 0 ] || pgreen=0
                dn="$(grep_scope all '\b(drive_slots_all|zd_edge_retains|planner_home_dyn|planner_retains_emitter_view)\b')"; readings="$readings deleted_names=$dn"; [ "$dn" = 0 ] || pgreen=0
                if [ -x "$NMGATE" ]; then ( cd "$SC" && bash "$NMGATE" > "$OUT/step$step/nm.log" 2>&1 ); nr=$?; readings="$readings nm_gate_rc=$nr"; [ "$nr" = 0 ] || pgreen=0; else readings="$readings nm_gate=missing"; pgreen=0; fi
                sm=0; for l in snobol4 snocone rebus icon prolog raku pascal polyglot; do ( cd "$SC" && bash "$HERE/test_smoke_$l.sh" > "$OUT/step$step/smoke_$l.log" 2>&1 ) && sm=$((sm + 1)); done
                readings="$readings smokes=$sm/8"; [ "$sm" = 8 ] || pgreen=0 ;;
        *) refuse "unknown probe token $tok in step $step" ;;
    esac
done
verdict=GREEN; [ "$m3p" = "$n" ] && [ "$m4p" = "$n" ] && [ "$pgreen" = 1 ] || verdict=RED
echo "STEP $step $slug: m3=$m3p/$n m4=$m4p/$n probe=${readings# } -> $verdict${reds:+ reds:$reds}"
[ "$verdict" = GREEN ] && exit 0 || exit 1
