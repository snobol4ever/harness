#!/usr/bin/env bash
# util_entries_green.sh -- THE NAMED ENTRIES OF A SUITE, GRADED IN MODE 3 ON THIS TREE (the chairman 2026-11-18; Lon, in the chairman's window, on the
# measured grades of the developer seats, verbatim: "Well then, help the boys."). MEASURED that morning: every sprint row's DONE-WHEN reads the progress
# store, which grades origin, so it cannot gate its own landing (skill gates-and-witnesses section 1), and s4e_land.sh --row ran it as the gate: five of the
# five red:gate landings of developer_03, 04, 05 and 10 since 07:22 CST were that one fault, each a whole build and gate round lost and a gate script then
# written by hand. This is that gate, written once: the entries a criterion names, run by the harness on the landing's own tree, with the cycle's own
# command form (s4e_cycle.sh run_request), nothing recorded in the store. The store still closes the row.
#
#   util_entries_green.sh SUITE ENTRY...        grade the named entries of one suite key (a master or pkg row of SUITE_RUNNERS.tsv)
#   util_entries_green.sh --row TOPIC           grade the entries the row's DONE-WHEN names: each call  chk SUITE 'ENTRY' ...  of its header criterion
#   util_entries_green.sh --row TOPIC --list    print them, one suite a line (suite TAB entry TAB entry ...), and grade nothing
#   util_entries_green.sh --selftest            the reader and the refusals proved on a scratch postoffice
# rc 0 every entry PASS in mode 3; rc 1 a red, each named  RED SUITE ENTRY (KIND);  rc 2 REFUSE, it could not measure (no row, no call, no suite, no built
# scrip, the harness graded another count than was named, or the harness ran past its budget, which says TIMEOUT and its seconds).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_paths.sh"
RUNNERS="${S4E_SUITE_RUNNERS:-$HERE/SUITE_RUNNERS.tsv}"
PO="${S4E_POSTOFFICE:-${S4E_POST:-/home/resources/postoffice}}"
refuse() { echo "REFUSE(2): $*"; exit 2; }
ext_of() { case "$1" in snobol4) echo sno;; icon) echo icn;; prolog) echo pl;; pascal) echo pas;; raku) echo raku;; rebus) echo reb;; snocone) echo sc;; scriptix) echo md;; esac; }
road_flag() {   # dir -> --run-files when the package declares that road, as s4e_cycle.sh reads it
    local d="$1"
    [ -f "$d/CONTRACT.tsv" ] && [ -f "$d/ALL.csv" ] || return 0
    head -1 "$d/ALL.csv" | tr -d '\r' | tr ',' '\n' | grep -qx path || return 0
    awk -F'\t' '!/^#/ && $1 == "road" && $2 == "run-files" && $3 != "" {f = 1} END {exit !f}' "$d/CONTRACT.tsv" && printf '%s' --run-files
    return 0; }
row_calls() {   # TOPIC -> suite TAB entry... a line, from the header criterion alone; rc 2 with the reason on stdout
    local tf="$PO/tasks/$1.task.md"
    [ -f "$tf" ] || { echo "no baton $tf"; return 2; }
    python3 -I -c '
import re, sys
dw = ""
for l in open(sys.argv[1], encoding="utf-8", errors="replace"):
    if l.startswith("## "): break
    if l.startswith("DONE-WHEN: "): dw = l[11:].rstrip("\n"); break
if not dw:
    print("the baton carries no DONE-WHEN in its header"); sys.exit(2)
calls = re.findall(r"\bchk ([A-Za-z0-9_@.+-]+)((?: +\x27[^\x27]*\x27)+)", dw)
if not calls:
    print("its DONE-WHEN names no call of the form  chk SUITE \x27ENTRY\x27 ..."); sys.exit(2)
for s, e in calls:
    print(s + "\t" + "\t".join(re.findall(r"\x27([^\x27]*)\x27", e)))
' "$tf"; }
grade() {   # SUITE ENTRY... -> rc 0 green, 1 red; exits 2 on a refusal
    local key="$1"; shift
    local row kind lang dir alls parts="" e ttr out rc board n pass reds road
    [ $# -gt 0 ] || refuse "suite $key: no entry named"
    row="$(awk -F'\t' -v k="$key" '!/^#/ && $1 == k && ($2 == "master" || $2 == "pkg") {print $2 "\t" $3 "\t" $5; exit}' "$RUNNERS" 2>/dev/null)"
    [ -n "$row" ] || refuse "suite $key has no master or pkg row in $RUNNERS"
    IFS=$'\t' read -r kind lang dir <<< "$row"
    if [ "$kind" = master ] || [ "$dir" = "corpus/tests/$lang" ]; then dir="$S4E_CORPUS/tests/$lang"; else dir="$S4E_CORPUS/${dir#corpus/}"; fi
    alls="$dir/ALL.$(ext_of "$lang")"
    [ -f "$dir/ALL.csv" ] || refuse "suite $key: no container at $dir"
    [ -x "$S4E_SCRIP/scrip" ] || refuse "no built scrip in $S4E_SCRIP (make -j8 there first)"
    for e in "$@"; do
        case "$e" in ''|*,*|*' '*) refuse "suite $key: the entry name '$e' is empty or holds a comma or a space";; esac
        parts="$parts${parts:+,}entry:$e"; done
    ttr="$(python3 -I "$HERE/util_grade_job.py" budget --suite "$key" --cell "$parts" 2>/dev/null | sed -n 's/.* ttr_s=\([0-9]*\).*/\1/p' | head -1)"; [ -n "$ttr" ] || ttr=1800
    road="$(road_flag "$dir")"
    out="$(cd "$S4E_SCRIP" && S4E_PROGRESS_OFF=1 timeout -k 5 "$ttr" python3 "$HERE/corpus_suite_harness.py" run "$alls" "$dir/ALL.ref" --lang "$lang" --modes m3 --partition "$parts" $road 2>&1 < /dev/null)"; rc=$?
    if [ "$rc" = 124 ] || [ "$rc" = 137 ]; then echo "TIMEOUT $key: the harness ran past its budget of $ttr s on $# entr(y/ies)"; exit 2; fi
    board="$(printf '%s\n' "$out" | grep '^SUITE_BOARD ' | tail -1)"
    [ -n "$board" ] || refuse "suite $key: the harness printed no SUITE_BOARD (rc $rc): $(printf '%s\n' "$out" | grep -E 'REFUS|Traceback|Error' | head -2 | cut -c1-300 | tr '\n' ' ')"
    n="$(printf '%s\n' "$board" | sed -n 's/.* m3_n=\([0-9]*\) .*/\1/p')"; pass="$(printf '%s\n' "$board" | sed -n 's/.* m3_pass=\([0-9]*\) .*/\1/p')"
    [ "$n" = "$#" ] || refuse "suite $key: the harness graded ${n:-no} entr(y/ies) in mode 3 where $# were named"
    if [ "$pass" = "$n" ]; then echo "GREEN $key: $n of $n named entr(y/ies) PASS in mode 3 on SCRIP $(git -C "$S4E_SCRIP" rev-parse --short=9 HEAD 2>/dev/null)"; return 0; fi
    reds="$(printf '%s\n' "$out" | sed -n 's/^  \(FAIL\|CRASH\|HANG\|UNPROVEN\) m3 \([^ ]*\):.*/RED '"$key"' \2 (\1)/p')"
    [ -n "$reds" ] && printf '%s\n' "$reds" || echo "RED $key: $pass of $n named entr(y/ies) pass in mode 3"
    return 1; }
selftest() {
    local w bad="" got rc arms=0
    w="$(mktemp -d "${TMPDIR:-/tmp}/entries_green.XXXXXX")" || refuse "mktemp failed"
    mkdir -p "$w/tasks"
    printf '# TASK a\nGOAL: plant\nDONE-WHEN: cd x && r=0; chk() { s="$1"; shift; o="$(python3 util_score_row.py from-progress --suite "$s")"; }; chk snolib '"'"'LOG.tst'"'"' '"'"'AGT.tst'"'"'; chk rosetta-snobol4 '"'"'loops-for-2'"'"'; [ "$r" = 0 ]\n## NEXT\nDONE-WHEN-BODY: chk other '"'"'x'"'"'\n' > "$w/tasks/a.task.md"
    printf '# TASK b\nGOAL: plant\nDONE-WHEN: cd x && python3 util_score_row.py from-progress --suite advpas350 --reds | grep -q SUITE_ROW\n## NEXT\nplant\n' > "$w/tasks/b.task.md"
    got="$(S4E_POSTOFFICE="$w" bash "$0" --row a --list)"; rc=$?; arms=$((arms + 1))
    [ "$rc" = 0 ] && [ "$got" = "$(printf 'snolib\tLOG.tst\tAGT.tst\nrosetta-snobol4\tloops-for-2')" ] || bad="$bad list_of_a(rc=$rc)"
    got="$(S4E_POSTOFFICE="$w" bash "$0" --row b --list)"; rc=$?; arms=$((arms + 1))
    [ "$rc" = 2 ] && printf '%s' "$got" | grep -q 'names no call' || bad="$bad no_call_refuses(rc=$rc)"
    got="$(S4E_POSTOFFICE="$w" bash "$0" --row no-such-row)"; rc=$?; arms=$((arms + 1))
    [ "$rc" = 2 ] && printf '%s' "$got" | grep -q 'no baton' || bad="$bad no_baton_refuses(rc=$rc)"
    got="$(bash "$0" no-such-suite-key x)"; rc=$?; arms=$((arms + 1))
    [ "$rc" = 2 ] && printf '%s' "$got" | grep -q 'no master or pkg row' || bad="$bad no_suite_refuses(rc=$rc)"
    got="$(bash "$0" snolib)"; rc=$?; arms=$((arms + 1))
    [ "$rc" = 2 ] || bad="$bad no_entry_refuses(rc=$rc)"
    rm -rf "$w"
    [ -z "$bad" ] && { echo "ENTRIES_GREEN_SELFTEST ok arms=$arms"; return 0; }
    echo "ENTRIES_GREEN_SELFTEST RED:$bad"; return 1; }
case "${1:-}" in
    --selftest) selftest; exit $?;;
    --row) topic="${2:-}"; [ -n "$topic" ] || refuse "--row takes a topic"
           calls="$(row_calls "$topic")" || refuse "row $topic: $calls; land it with --gate and the entries named: bash $HERE/util_entries_green.sh SUITE ENTRY..."
           [ "${3:-}" = --list ] && { printf '%s\n' "$calls"; exit 0; }
           worst=0
           while IFS=$'\t' read -r -a f; do grade "${f[@]}" || worst=1; done <<< "$calls"
           exit "$worst";;
    ""|-h|--help) sed -n '2,/^set -uo/p' "$0" | grep '^#' | sed 's/^# \{0,1\}//'; exit 0;;
    -*) refuse "unknown switch $1";;
    *) grade "$@"; exit $?;;
esac
