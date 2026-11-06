#!/usr/bin/env bash
# test_design_raku_roast_causes_steps.sh -- THE STEP-THROUGH HARNESS of DESIGN-PLAN: raku-roast-causes (the cao, 2026-11-05, Lon in the coo's window:
# "Each failing program is getting fixed today."; row raku-roast-every-red-program-triaged-and-its-fix-designed-by-the-cao). One step per CAUSE of a
# Roast red. The plan is corpus/tests/raku/roast_causes/STEPS.tsv; the witnesses are the .raku programs beside it, each with a .ref cut from Rakudo
# (rakudo_bin of lib_oracle_flags.sh: rakudo-local 2026.05). The shape is test_design_raku_rewrite_steps.sh's.
#
#   --list       print the steps and run nothing
#   --step N     grade step N: every witness in mode 3 and mode 4 (-d131072k -s4096k, stdout compared exactly with the ref), then the probe tokens,
#                every one a READ of a stored measurement (the coo's loop measures; a seat runs no board):
#                  moved=ERE@P1,P2,...  none of the named roast programs has a latest mode-3 note matching ERE (grep -E; write a space as .), and
#                                       every one has a reading: the cause is no longer the program's first red
#                  pass=P1,P2,...       every named roast program reads PASS in both modes in its latest readings
#                  chapter=PREFIX:N     roast files under PREFIX (comma list a union) PASS in both modes, at least N
#                  row=KEY:N            SUITES.tsv today_pass of suite KEY at least N
#                  census=SYMBOL:N      occurrences of SYMBOL under SCRIP/src, at most N
#                  smoke                test_smoke_raku.sh green
#                Red before the step lands, green after.
#   --land N     the LANDING GATE of step N: the witnesses in both modes and the tokens a lander can prove before the push (census, smoke);
#                the tokens that read the coo's grading of the landed code (moved, pass, chapter, row) are named as POST-LAND and not read, so
#                s4e_land.sh gates on --land N, the lander files s4e_test_request.sh roast <entries>, parks PARKED-AWAITING the request id, and the
#                row closes by done on --step N once the coo's reading is in (worker_11's measurement on step 2, 2026-11-06: --step 2 read pass=0/10
#                before the landing and could never gate it). A row's PREMISE-WHEN reads --land N.
#   --cut        re-cut every witness ref from Rakudo
#   --out DIR    where the runs go (default a fresh /tmp/s4e/<seat>/runner_out.raku_roast_causes.<pid>.* deleted at the verdict; an explicit DIR is kept)
#
# VERDICT: STEP N <slug>: m3=<pass>/<n> m4=<pass>/<n> probe=<token:reading ...> -> GREEN|RED|REFUSED; rc 0 GREEN, 1 RED, 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SC="$ROOT/SCRIP"
WD="$ROOT/corpus/tests/raku/roast_causes"
STEPS="$WD/STEPS.tsv"
OUT=""
SUITES=/home/resources/progress/SUITES.tsv
RESULTS=/home/resources/progress/results.tsv
refuse() { echo "REFUSE(2): $*" >&2; exit 2; }
[ -f "$STEPS" ] || refuse "no step table at $STEPS"
mode=""; step=""; land=0
while [ $# -gt 0 ]; do
    case "$1" in
        --list) mode=list; shift ;;
        --step) mode=step; step="${2:-}"; [ -n "$step" ] || refuse "--step takes a number"; shift 2 ;;
        --land) mode=step; land=1; step="${2:-}"; [ -n "$step" ] || refuse "--land takes a number"; shift 2 ;;
        --cut) mode=cut; shift ;;
        --out) OUT="${2:-}"; shift 2 ;;
        *) refuse "usage: $0 --list | --step N [--out DIR] | --land N [--out DIR] | --cut" ;;
    esac
done
[ -n "$mode" ] || refuse "usage: $0 --list | --step N [--out DIR] | --land N [--out DIR] | --cut"
[ -n "$OUT" ] || { . "$HERE/lib_runner_out.sh" && runner_out_default raku_roast_causes; } || refuse "no output directory under /tmp/s4e (lib_runner_out.sh)"
col() { awk -F'\t' -v n="$1" -v k="$2" '!/^#/ && $1 == n {print $k; exit}' "$STEPS"; }
if [ "$mode" = list ]; then
    echo "DESIGN-PLAN: raku-roast-causes -- $(awk -F'\t' '!/^#/ && $1 != "step" && NF >= 6' "$STEPS" | wc -l) steps (STEPS.tsv); witnesses in corpus/tests/raku/roast_causes (refs from Rakudo 2026.05)"
    printf '%-4s %-46s %-9s %-10s %s\n' step slug executor depends witnesses
    for n in $(awk -F'\t' '!/^#/ && $1 != "step" {print $1}' "$STEPS"); do
        printf '%-4s %-46s %-9s %-10s %s\n' "$n" "$(col "$n" 2)" "$(col "$n" 3)" "$(col "$n" 4)" "$(col "$n" 6)"
    done
    exit 0
fi
RAKU="$(. "$HERE/lib_oracle_flags.sh" && rakudo_bin)" || refuse "no rakudo (lib_oracle_flags.sh rakudo_bin)"
if [ "$mode" = cut ]; then
    for w in $(awk -F'\t' '!/^#/ && $1 != "step" && $6 != "-" {print $6}' "$STEPS" | tr ' ' '\n' | sort -u); do
        T="$(mktemp -d "${TMPDIR:-/tmp}/rkrc_cut.XXXXXX")"; cp "$WD/$w.raku" "$T/"
        ( cd "$T" && timeout -k 5 300 "$RAKU" "$w.raku" < /dev/null > "$WD/$w.ref" 2> "$T/err" ); echo "cut $w.ref: $(wc -l < "$WD/$w.ref") lines$(grep -q . "$T/err" && echo " (RAKUDO COMPLAINED: $(head -c 100 "$T/err" | tr '\n' ' '))")"
        rm -rf "$T"
    done
    exit 0
fi
[ -n "$(col "$step" 1)" ] || refuse "no step $step in $STEPS (--list names them)"
slug="$(col "$step" 2)"; probe="$(col "$step" 5)"; wits="$(col "$step" 6)"
[ -x "$SC/scrip" ] || refuse "no $SC/scrip"
mkdir -p "$OUT/step$step"
if [ -z "${S4E_RUN_SLOT_HELD:-}" ]; then
    . "$HERE/lib_slots.sh"; s4e_slot_hold run || true   # the one rule (lib_slots.sh): a seat file, then a pool slot; the grader's two slots reserved
fi
m3p=0; m4p=0; n=0; reds=""
[ "$wits" = "-" ] && wits=""
for w in $wits; do
    ref="$WD/$w.ref"
    [ -f "$WD/$w.raku" ] && [ -f "$ref" ] || refuse "witness $w has no .raku or .ref in $WD"
    n=$((n + 1))
    for m in m3 m4; do
        d="$OUT/step$step/$w.$m"; rm -rf "$d"; mkdir -p "$d"; cp "$WD/$w.raku" "$d/$w.raku"
        if [ "$m" = m3 ]; then
            ( cd "$d" && timeout -k 5 120 "$SC/scrip" -d131072k -s4096k "$w.raku" < /dev/null > "$d/out" 2> "$d/err" ); rc=$?
        else
            if ( cd "$d" && timeout -k 5 300 "$SC/scrip" --compile --out="$d/run.s" "$w.raku" < /dev/null > /dev/null 2> "$d/cerr" ) \
               && gcc -c "$d/run.s" -o "$d/run.o" 2> /dev/null && gcc "$d/run.o" -L"$SC/out" -lscrip_rt -lm -Wl,-rpath,"$SC/out" -o "$d/run.bin" 2> /dev/null; then
                ( cd "$d" && timeout -k 5 120 "$d/run.bin" -d131072k -s4096k < /dev/null > "$d/out" 2> "$d/err" ); rc=$?
            else rc=no-binary; fi
        fi
        if [ "$rc" = 0 ] && diff -q "$d/out" "$ref" > /dev/null 2>&1; then [ "$m" = m3 ] && m3p=$((m3p + 1)) || m4p=$((m4p + 1)); else reds="$reds $m:$w(rc$rc)"; fi
    done
done
latest_roast() { # prints program<TAB>m3outcome<TAB>m4outcome<TAB>m3note for every roast program's latest reading per mode
    [ -r "$RESULTS" ] || refuse "no $RESULTS"
    awk -F'\t' 'NR > 1 && $6 == "roast" { k = $8 "\t" $9; if (!(k in t) || $1 > t[k]) { t[k] = $1; o[k] = $10; nt[k] = $12 } }
        END { for (k in t) { split(k, a, "\t"); p[a[1]] = 1; r[k] = o[k] }
              for (q in p) printf "%s\t%s\t%s\t%s\n", q, r[q "\tm3"], r[q "\tm4"], nt[q "\tm3"] }' "$RESULTS"
}
readings=""; pgreen=1; postland=""
[ "$probe" = "-" ] && probe=""
for tok in $probe; do
    key="${tok%%=*}"; val="${tok#*=}"; arg="${val%%:*}"; lim="${val##*:}"
    case "$key" in moved|pass|chapter|row) [ "$land" = 1 ] && { postland="$postland $tok"; continue; } ;; esac
    case "$key" in
        moved) ere="${val%@*}"; progs="${val##*@}"; [ -n "$ere" ] && [ -n "$progs" ] && [ "$ere" != "$val" ] || refuse "moved= takes ERE@P1,P2 in step $step"
               lr="$(latest_roast)"; c=0; miss=""; hit=""
               for p in ${progs//,/ }; do
                   l="$(printf '%s\n' "$lr" | awk -F'\t' -v p="$p" '$1 == p')"; [ -n "$l" ] || { miss="$miss $p"; continue; }
                   printf '%s\n' "$l" | cut -f4 | grep -qE -- "$ere" && { c=$((c + 1)); hit="$hit,$p"; }
               done
               [ -z "$miss" ] || refuse "moved=: no roast reading for$miss"
               readings="$readings moved[$ere]=$c(at_most 0${hit:+ still:${hit#,}})"; [ "$c" = 0 ] || pgreen=0 ;;
        pass) lr="$(latest_roast)"; c=0; k=0; red=""
              for p in ${val//,/ }; do k=$((k + 1)); printf '%s\n' "$lr" | awk -F'\t' -v p="$p" '$1 == p && $2 == "PASS" && $3 == "PASS" { f = 1 } END { exit !f }' && c=$((c + 1)) || red="$red,$p"; done
              readings="$readings pass=$c/$k${red:+ red:${red#,}}"; [ "$c" = "$k" ] || pgreen=0 ;;
        chapter) c="$(latest_roast | awk -F'\t' -v pre="$arg" 'BEGIN { n = split(pre, ps, ",") } $2 == "PASS" && $3 == "PASS" { for (i = 1; i <= n; i++) if (index($1, ps[i]) == 1) { c++; break } } END { print c + 0 }')"
                 readings="$readings chapter[$arg]=$c(at_least $lim)"; [ "$c" -ge "$lim" ] || pgreen=0 ;;
        row) [ -r "$SUITES" ] || refuse "no $SUITES"; c="$(awk -F'\t' -v k="$arg" 'NR == 2 { for (i = 1; i <= NF; i++) h[$i] = i } $1 == k { print $(h["today_pass"]) }' "$SUITES")"; [ -n "$c" ] || refuse "no row $arg in SUITES.tsv"
             readings="$readings row[$arg]=$c(at_least $lim)"; [ "$c" -ge "$lim" ] || pgreen=0 ;;
        census) c="$(grep -rc -- "$arg" "$SC/src" --include=*.c --include=*.cpp --include=*.h --include=*.inc 2>/dev/null | awk -F: '{ s += $2 } END { print s + 0 }')"; readings="$readings census[$arg]=$c(at_most $lim)"; [ "$c" -le "$lim" ] || pgreen=0 ;;
        smoke) if ( cd "$SC" && timeout -k 10 600 bash "$HERE/test_smoke_raku.sh" > "$OUT/step$step/smoke.log" 2>&1 ); then readings="$readings smoke=green"; else readings="$readings smoke=red"; pgreen=0; fi ;;
        *) refuse "unknown probe token $tok in step $step" ;;
    esac
done
verdict=GREEN; [ "$m3p" = "$n" ] && [ "$m4p" = "$n" ] && [ "$pgreen" = 1 ] || verdict=RED
[ "$land" = 1 ] && { echo "LAND STEP $step $slug: m3=$m3p/$n m4=$m4p/$n probe=${readings# } -> $verdict${reds:+ reds:$reds} (POST-LAND, read by --step $step after the coo grades:${postland:- none})"; [ "$verdict" = GREEN ] && exit 0 || exit 1; }
echo "STEP $step $slug: m3=$m3p/$n m4=$m4p/$n probe=${readings# } -> $verdict${reds:+ reds:$reds}"
[ "$verdict" = GREEN ] && exit 0 || exit 1
