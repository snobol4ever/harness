#!/usr/bin/env bash
# test_design_xsb_tabling_wfs_steps.sh -- THE STEP-THROUGH HARNESS of DESIGN-PLAN: xsb-tabling-wfs (the cto, 2026-10-28, CEO-1996/1998;
# .github/ARCH-PROLOG-WFS-TABLING.md section 8). The plan is corpus/tests/prolog/xsb_wfs/STEPS.tsv; the witnesses are the .P programs beside it
# (XSB's syntax, as the package corpus/packages/prolog/xsb_tests vendors XSB's own tests), each with a .ref cut from XSB 5.0.0 (xsb_bin(),
# ORACLES.md; CEO-1927) by XSB's gentest protocol: `[w]. tell(temp). test. told.` and the file temp's non-empty lines sorted.
#
#   --list       print the steps and run nothing
#   --step N     grade step N: every witness in mode 3 and mode 4 AS THE PACKAGE RUNS AN ENTRY -- the package prelude's directive lines prefixed,
#                the vendored sorted-output driver appended (or, for a NAME:temp:GOAL witness, initialization((GOAL, told)) with the answer the
#                file temp sorted), every sibling .P staged beside under its own name and as .pl, the declared -d131072k -s4096k -- compared with
#                diff -w (ALL.csv's ignore-all-space); then the step's probe tokens: entries=... (the named package entries through
#                corpus_suite_harness.py smoke, no progress row, at most eight: the handful of CEO-1677), families=... and row=N (results.tsv and
#                SUITES.tsv READ, never run). Red before the step lands, green after.
#   --cut        re-cut every witness ref from XSB (the design seat's road; an HQ that changes a witness re-cuts it the same way)
#   --out DIR    where the runs go (default <root>/.scratch/xsb_wfs)
#
# VERDICT: STEP N <slug>: m3=<pass>/<n> m4=<pass>/<n> probe=<token:reading ...> -> GREEN|RED|REFUSED; rc 0 GREEN, 1 RED, 2 could not measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SC="$ROOT/SCRIP"
WD="$ROOT/corpus/tests/prolog/xsb_wfs"
PKG="$ROOT/corpus/packages/prolog/xsb_tests"
STEPS="$WD/STEPS.tsv"
OUT="$ROOT/.scratch/xsb_wfs"
RESULTS=/home/resources/progress/results.tsv
SUITES=/home/resources/progress/SUITES.tsv
refuse() { echo "REFUSE(2): $*" >&2; exit 2; }
[ -f "$STEPS" ] || refuse "no step table at $STEPS"
mode=""; step=""
while [ $# -gt 0 ]; do
    case "$1" in
        --list) mode=list; shift ;;
        --step) mode=step; step="${2:-}"; [ -n "$step" ] || refuse "--step takes a number"; shift 2 ;;
        --cut) mode=cut; shift ;;
        --out) OUT="${2:-}"; shift 2 ;;
        *) refuse "usage: $0 --list | --step N [--out DIR] | --cut" ;;
    esac
done
[ -n "$mode" ] || refuse "usage: $0 --list | --step N [--out DIR] | --cut"
col() { awk -F'\t' -v n="$1" -v k="$2" '!/^#/ && $1 == n {print $k; exit}' "$STEPS"; }
if [ "$mode" = list ]; then
    echo "DESIGN-PLAN: xsb-tabling-wfs -- $(awk -F'\t' '!/^#/ && $1 != "step" && NF >= 6' "$STEPS" | wc -l) steps (STEPS.tsv); witnesses in corpus/tests/prolog/xsb_wfs (XSB syntax, refs from XSB 5.0.0)"
    printf '%-4s %-36s %-12s %-22s %s\n' step slug executor depends witnesses
    for n in $(awk -F'\t' '!/^#/ && $1 != "step" {print $1}' "$STEPS"); do
        printf '%-4s %-36s %-12s %-22s %s\n' "$n" "$(col "$n" 2)" "$(col "$n" 3)" "$(col "$n" 4)" "$(col "$n" 6)"
    done
    exit 0
fi
# the witness spec: NAME or NAME:temp:GOAL
wname() { echo "${1%%:*}"; }
wkind() { case "$1" in *:temp:*) echo temp ;; *) echo sorted ;; esac; }
wgoal() { case "$1" in *:temp:*) echo "${1##*:temp:}" ;; *) echo test ;; esac; }
if [ "$mode" = cut ]; then
    XSB="$(bash -c ". '$HERE/lib_oracle_flags.sh' && xsb_bin")" || refuse "xsb_bin refused (ORACLES.md: the XSB oracle)"
    T="$(mktemp -d "${TMPDIR:-/tmp}/xsbwfs_cut.XXXXXX")"; cp "$WD"/*.P "$T/"
    for spec in $(awk -F'\t' '!/^#/ && $1 != "step" {print $6}' "$STEPS" | tr ' ' '\n' | sort -u); do
        w="$(wname "$spec")"; g="$(wgoal "$spec")"; k="$(wkind "$spec")"
        ( cd "$T" && rm -f temp && { if [ "$k" = temp ]; then printf '[%s]. %s. halt.\n' "$w" "$g"; else printf '[%s]. tell(temp). %s. told. halt.\n' "$w" "$g"; fi; } \
            | timeout -k 5 300 "$XSB" --nobanner --quietload -e 'segfault_handler(warn).' > "$T/$w.xsb.log" 2>&1
          [ -f temp ] && grep -v '^$' temp | sort > "$WD/$w.ref" || : > "$WD/$w.ref" )
        echo "cut $w.ref: $(wc -l < "$WD/$w.ref") lines$(grep -qi '++Error' "$T/$w.xsb.log" && echo ' (XSB RAISED: read the log)')"
    done
    rm -rf "$T"; exit 0
fi
[ -n "$(col "$step" 1)" ] || refuse "no step $step in $STEPS (--list names them)"
slug="$(col "$step" 2)"; probe="$(col "$step" 5)"; wits="$(col "$step" 6)"
[ -x "$SC/scrip" ] || refuse "no $SC/scrip"
[ -f "$PKG/ALL.prelude" ] || refuse "no package prelude at $PKG/ALL.prelude"
PRE="$(grep -v '^#' "$PKG/ALL.prelude" | grep -v '^$')"
DRIVER="xsb_nonempty_line(L) :- string_length(L, N), N > 0. xsb_write_lines([]). xsb_write_lines([X|Xs]) :- write(X), nl, xsb_write_lines(Xs).
xsb_sorted_output(G) :- with_output_to(string(S), catch(ignore(G), E, print_message(error, E))), split_string(S, '\\n', '', L0), include(xsb_nonempty_line, L0, L1), msort(L1, L), xsb_write_lines(L)."
mkdir -p "$OUT/step$step"
# one box-wide run slot for the step (CEO-1894)
if [ -z "${S4E_RUN_SLOT_HELD:-}" ]; then
    nslots="${S4E_RUN_SLOTS:-8}"; mkdir -p /tmp/s4e-run-slots; got=""
    for i in $(seq 0 $((nslots - 1))); do exec 9>"/tmp/s4e-run-slots/slot$i"; flock -n 9 && { got=$i; break; }; done
    [ -n "$got" ] || { exec 9>"/tmp/s4e-run-slots/slot$(( $$ % nslots ))"; flock 9; }
    export S4E_RUN_SLOT_HELD=1
fi
stage() { # $1 dir: every witness .P beside, under its name and as .pl (as corpus_suite_harness.py stage_upstream writes a sibling)
    for f in "$WD"/*.P; do b="$(basename "$f" .P)"; cp "$f" "$1/$b.P"; cp "$f" "$1/$b.pl"; done
}
answer() { # $1 kind, $2 run dir, $3 stdout file -> the graded text on stdout
    if [ "$1" = temp ]; then [ -f "$2/temp" ] && grep -v '^$' "$2/temp" | sort; else grep -v '^$' "$3"; fi
}
m3p=0; m4p=0; n=0; reds=""
for spec in $wits; do
    w="$(wname "$spec")"; k="$(wkind "$spec")"; g="$(wgoal "$spec")"; ref="$WD/$w.ref"
    [ -f "$WD/$w.P" ] && [ -f "$ref" ] || refuse "witness $w has no .P or .ref in $WD"
    n=$((n + 1))
    for m in m3 m4; do
        d="$OUT/step$step/$w.$m"; rm -rf "$d"; mkdir -p "$d"; stage "$d"
        { printf '%s\n' "$PRE"; cat "$WD/$w.P"; echo
          if [ "$k" = temp ]; then printf ':- initialization((%s, told)).\n' "$g"; else printf '%s\n:- initialization(xsb_sorted_output((%s))).\n' "$DRIVER" "$g"; fi; } > "$d/${w}_run.pl"
        if [ "$m" = m3 ]; then
            ( cd "$d" && timeout -k 5 120 "$SC/scrip" -d131072k -s4096k "${w}_run.pl" < /dev/null > "$d/out" 2> "$d/err" ); rc=$?
        else
            if ( cd "$d" && timeout -k 5 300 "$SC/scrip" --compile --out="$d/run.s" "${w}_run.pl" < /dev/null > /dev/null 2> "$d/cerr" ) \
               && gcc -c "$d/run.s" -o "$d/run.o" 2> /dev/null && gcc "$d/run.o" -L"$SC/out" -lscrip_rt -lm -Wl,-rpath,"$SC/out" -o "$d/run.bin" 2> /dev/null; then
                ( cd "$d" && timeout -k 5 120 "$d/run.bin" -d131072k -s4096k < /dev/null > "$d/out" 2> "$d/err" ); rc=$?
            else rc=no-binary; fi
        fi
        answer "$k" "$d" "$d/out" > "$d/got" 2>/dev/null
        if [ "$rc" = 0 ] && diff -w -q "$d/got" "$ref" > /dev/null 2>&1; then [ "$m" = m3 ] && m3p=$((m3p + 1)) || m4p=$((m4p + 1)); else reds="$reds $m:$w(rc$rc)"; fi
    done
done
readings=""; pgreen=1
for tok in $probe; do
    key="${tok%%=*}"; val="${tok#*=}"
    case "$key" in
        entries) es="${val//,/ }"; cnt=0; for e in $es; do cnt=$((cnt + 1)); done; [ "$cnt" -le 8 ] || refuse "step $step names $cnt entries; the handful is at most eight (CEO-1677)"
                 sm="$(cd "$ROOT" && S4E_HOME="$ROOT" timeout -k 10 1500 python3 "$HERE/corpus_suite_harness.py" smoke nl write --tables packages/prolog/xsb_tests --entries "$es" --modes m3,m4 2>&1)"
                 printf '%s\n' "$sm" > "$OUT/step$step/smoke.log"
                 ok=0; for e in $es; do printf '%s\n' "$sm" | grep -E "^AREA_SMOKE_ENTRY .*entry=$e .*m3=PASS.*m4=PASS" > /dev/null && ok=$((ok + 1)); done
                 readings="$readings entries=$ok/$cnt"; [ "$ok" = "$cnt" ] || pgreen=0 ;;
        families) [ -r "$RESULTS" ] || refuse "no $RESULTS"; bad="$(awk -F'\t' -v fams="$val" 'BEGIN { n = split(fams, a, ","); for (i = 1; i <= n; i++) f[a[i]] = 1 }
                    NR > 1 && $6 == "xsb" { split($8, p, "_"); fam = (p[2] == "tests") ? p[1] "_tests" : p[1]; if (!(fam in f)) next; k = $8 "\t" $9; if ($1 > ts[k]) { ts[k] = $1; o[k] = $10 } }
                    END { b = 0; for (k in o) if (o[k] != "PASS") b++; print b }' "$RESULTS")"; readings="$readings families[$val]_not_pass=$bad"; [ "$bad" = 0 ] || pgreen=0 ;;
        row) [ -r "$SUITES" ] || refuse "no $SUITES"; tp="$(awk -F'\t' 'NR == 2 { for (i = 1; i <= NF; i++) h[$i] = i } $1 == "xsb" { print $(h["today_pass"]) }' "$SUITES" | tail -1)"
             readings="$readings row_today_pass=${tp:-?}(need $val)"; [ -n "$tp" ] && [ "$tp" -ge "$val" ] 2>/dev/null || pgreen=0 ;;
        *) refuse "unknown probe token $tok in step $step" ;;
    esac
done
verdict=GREEN; [ "$m3p" = "$n" ] && [ "$m4p" = "$n" ] && [ "$pgreen" = 1 ] || verdict=RED
echo "STEP $step $slug: m3=$m3p/$n m4=$m4p/$n probe=${readings# } -> $verdict${reds:+ reds:$reds}"
[ "$verdict" = GREEN ] && exit 0 || exit 1
