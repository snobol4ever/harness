#!/usr/bin/env bash
# test_design_batch_grader_steps.sh -- THE STEP-THROUGH HARNESS of DESIGN-PLAN: batch-grader (the cio, 2026-11-05, on Lon's word: "For the test
# harness, you should move INTO SCRIP. Let scrip run a list of source files on the command line, and reset its base memory cleanly each time."; the
# design text in .github/skills/suites-and-grading/SKILL.md section 5; the SCRIP side ruled by the cto). The plan is harness/designs/batch_grader/STEPS.tsv;
# the witnesses are the programs beside it, each .ref cut from its oracle (sbl -bf; icont and iconx, or unicon through unicon_bin() for a *_uni_* witness whose row carries --dialect=unicon, CTO-554; swipl -q -t halt for the Prolog witnesses of steps 8 and 9, CTO-522), never from our output. A step's measurement is
# its PROBE, one bash command run from S4E_HOME, so a step reads RED until scrip has the switch and GREEN only while the witnesses say so.
#   --list       print the steps and run nothing
#   --step N     run step N's probe (600 s budget; S4E_SEAT names the seat whose /tmp/s4e/<seat> the probe writes under)
#   --cut        re-cut every witness ref from its oracle (the design seat's road; an HQ that changes a witness re-cuts it the same way)
# VERDICT: STEP N <slug>: probe rc=<rc> -> GREEN|RED|REFUSED; rc 0 GREEN, 1 RED, 2 could not measure (a stale ./scrip refuses before any probe that runs it).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_one_runner.sh" && one_runner_mem_scope   # THE MEMORY DOOR (the cio 2026-11-10 12:3x): a witness at its declared heap runs in its own board scope, never in a seat's
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
WD="$HERE/../designs/batch_grader"; STEPS="$WD/STEPS.tsv"   # the table (CIO-56); a probe reads the witnesses in $BG_W, staged by design_witness_stage_all
refuse() { echo "REFUSE(2) [test_design_batch_grader_steps]: $*" >&2; exit 2; }
. "$HERE/lib_design_witness.sh" || refuse "lib_design_witness.sh unloadable"
[ -f "$STEPS" ] || refuse "no step table at $STEPS"
mode=""; step=""
while [ $# -gt 0 ]; do
    case "$1" in
        --list) mode=list; shift ;;
        --step|--probe) mode=step; step="${2:-}"; [ -n "$step" ] || refuse "$1 takes a number"; shift 2 ;;
        --cut) mode=cut; shift ;;
        *) refuse "usage: $0 --list | --step N | --cut" ;;
    esac
done
[ -n "$mode" ] || refuse "usage: $0 --list | --step N | --cut"
col() { awk -F'\t' -v n="$1" -v k="$2" '!/^#/ && $1 == n {print $k; exit}' "$STEPS"; }
if [ "$mode" = list ]; then
    echo "DESIGN-PLAN: batch-grader -- $(awk -F'\t' '!/^#/ && $1 != "step" && NF >= 6' "$STEPS" | wc -l) steps (STEPS.tsv); witnesses the entries batch_grader__<name> of their masters, else loose in corpus/tests/<lang>/batch_grader, bg08 the fixture harness/fixtures/batch_grader"
    printf '%-4s %-110s %-10s %-8s %s\n' step slug executor depends witnesses
    awk -F'\t' '!/^#/ && $1 != "step" && NF >= 6 {printf "%-4s %-110s %-10s %-8s %s\n", $1, $2, $3, $4, $6}' "$STEPS"
    exit 0
fi
if [ "$mode" = cut ]; then
    . "$HERE/lib_oracle_flags.sh" 2>/dev/null || refuse "lib_oracle_flags.sh unloadable"
    SW="$(mktemp -d "${TMPDIR:-/tmp}/bg_cut.XXXXXX")"; design_witness_stage_all batch_grader "$SW" || refuse "the witnesses did not stage (lib_design_witness.sh)"
    awk -F'\t' '$2 == "entry" {print "keep " $1 ": it is the entry batch_grader__" $1 " of the " $3 " master, its answer its master'"'"'s (re-cut by util_add_ladder_witness.py)"}' "$SW/.where"
    for D in $(awk -F'\t' '$2 == "loose" {print $3}' "$SW/.where" | sort -u); do
    cd "$D" || refuse "cannot enter $D"
    for src in *.sno; do
        w="${src%.sno}"; [ -f "$w.expect" ] && { echo "skip $w: the oracle cannot answer it ($w.expect is the record kind)"; continue; }
        in=/dev/null; [ -f "$w.in" ] && in="$w.in"
        bash "$HERE/util_oracle.sh" sbl --stdin "$in" --timeout 60 -- -bf "$src" > "$w.ref" 2>/dev/null; echo "cut $w.ref (sbl rc $?): $(wc -l < "$w.ref") lines"
    done
    for src in *.pl; do
        w="${src%.pl}"; bash "$HERE/util_oracle.sh" swipl --timeout 60 -- -q -t halt "$src" > "$w.ref" 2>/dev/null; echo "cut $w.ref (swipl rc $?): $(wc -l < "$w.ref") lines"
    done
    for src in *.icn; do
        w="${src%.icn}"; x="$(mktemp "${TMPDIR:-/tmp}/bg_icx.XXXXXX")"
        case "$w" in
        *_uni_*)  # CTO-554 step 10a: a markerless program the row tells scrip is Unicon (--dialect=unicon, CTO-473), so its oracle is unicon_bin(); its
                  # row attributes live beside it: $w.cwd/ (the companions, the working directory), $w.args (one line, the argv), $w.env (NAME=VALUE lines),
                  # $w.in (stdin); stderr is merged into the ref (stderr=merged in the row).
            in=/dev/null; [ -f "$w.in" ] && in="$D/$w.in"
            args=""; [ -f "$w.args" ] && args="$(cat "$w.args")"
            cw="$(mktemp -d "${TMPDIR:-/tmp}/bg_ucw.XXXXXX")"; [ -d "$w.cwd" ] && cp -r "$w.cwd/." "$cw/"
            if timeout -k 5 60 "$(unicon_bin)" -s -o "$x.uni" "$src" > /dev/null 2>&1; then
                ( cd "$cw" && [ -f "$D/$w.env" ] && set -a && . "$D/$w.env" && set +a; cd "$cw" && timeout -k 5 60 "$x.uni" $args < "$in" > "$D/$w.ref" 2>&1 ); echo "cut $w.ref (unicon rc $?): $(wc -l < "$w.ref") lines"
            else echo "cut $w.ref SKIPPED: unicon refused $src"; fi
            rm -rf "$cw" "$x.uni" ;;
        *)
            timeout -k 5 60 "$(icont_bin)" -s -o "$x" "$src" 2>/dev/null && timeout -k 5 60 "$(iconx_bin)" "$x" < /dev/null > "$w.ref" 2>/dev/null; echo "cut $w.ref (icont/iconx rc $?): $(wc -l < "$w.ref") lines" ;;
        esac
        rm -f "$x"
    done
    done; rm -rf "$SW"
    exit 0
fi
slug="$(col "$step" 2)"; probe="$(col "$step" 5)"
[ -n "$slug" ] || refuse "no step $step in $STEPS"
cd "$S4E" || refuse "cannot enter $S4E"
case "$probe" in *SCRIP/scrip*) [ -n "${SCRIP_BIN:-}" ] || bash "$HERE/util_require_fresh.sh" --gate test_design_batch_grader_steps "$S4E/SCRIP/scrip" "$S4E/SCRIP/out/libscrip_rt.so" || exit 2 ;; esac
mkdir -p "/tmp/s4e/${S4E_SEAT:-cio}"
out="$(mktemp "${TMPDIR:-/tmp}/s4e_batch_grader_step.XXXXXX")"
BG_W="$(mktemp -d "/tmp/s4e/${S4E_SEAT:-cio}/bg_wit.XXXXXX")" && design_witness_stage_all batch_grader "$BG_W" || refuse "the witnesses did not stage (lib_design_witness.sh: an entry batch_grader__<name>, a loose pair in corpus/tests/<lang>/batch_grader, or harness/fixtures/batch_grader)"
BG_W="$BG_W" S4E_HOME="$S4E" timeout -k 5 600 bash -c "$probe" > "$out" 2>&1; rc=$?; rm -rf "$BG_W"
tail -5 "$out" | sed 's/^/    /'; refused=0; grep -q 'REFUSE(2)' "$out" && refused=1; rm -f "$out"
case "$rc" in 0) v=GREEN; ec=0 ;; 124|137) v="REFUSED (the probe ran past its 600 s budget)"; ec=2 ;; 2) if [ "$refused" = 1 ]; then v="REFUSED (could not measure)"; ec=2; else v="RED (the probe exited 2 without its own REFUSE(2): scrip refused a switch it does not have yet, or cmp found no output file -- the lines above say which)"; ec=1; fi ;; *) v=RED; ec=1 ;; esac
echo "VERDICT: STEP $step $slug: probe rc=$rc -> $v"
exit $ec
