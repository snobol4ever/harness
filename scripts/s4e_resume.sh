#!/usr/bin/env bash
# s4e_resume.sh -- the bus verb `resume` (DESIGN-PLAN box-scheduler step 16, CTO-496; hq_templates 2026-11-04: "a bus verb that appends one timestamped
# RESUME line (tree path, exact command, state, log path) which next prints first"). A seat's resume point is written where the next sitting reads it
# first, not in a chat and not in a 44 KB NEXT block.
#   bash harness/scripts/s4e_msg.sh resume <topic> --tree <path> --command '<the exact command>' --state <word> --log <path>   write the line
#   bash harness/scripts/s4e_msg.sh resume <topic>                                                                              print the newest line
#   bash harness/scripts/s4e_msg.sh resume --probe                                                                              prove it on a scratch baton
# The line: `RESUME <utc-stamp> <seat> tree=<path> command=<the command> state=<word> log=<path>` under the baton's `## RESUME` heading (newest first,
# created before `## NEXT` when absent); the tree and the log must exist when written; `next` prints the newest RESUME line of the served row first.
# rc 0 written or printed, 1 refused (nothing written), 2 could not measure.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
PO="${S4E_POST:-/home/resources/postoffice}"
ME="${S4E_SEAT:-}"
refuse() { echo "⛔ RESUME REFUSED (nothing written): $*" >&2; exit 1; }
usage="s4e_msg.sh resume <topic> [--tree <path> --command '<cmd>' --state <word> --log <path>] | resume --probe"
newest() { awk '/^## RESUME/{f=1;next} /^## /{f=0} f && /^RESUME /{print; exit}' "$1"; }
write_line() { local bat="$1" line="$2" tmp
    tmp="$(mktemp "$bat.resume.XXXXXX")" || refuse "cannot write beside $bat"
    if grep -q '^## RESUME' "$bat"; then L="$line" awk '{print} /^## RESUME/ {print ENVIRON["L"]}' "$bat" > "$tmp"
    else L="$line" awk '/^## NEXT/ && !d {print "## RESUME"; print ENVIRON["L"]; d=1} {print}' "$bat" > "$tmp"; fi
    mv "$tmp" "$bat" || { rm -f "$tmp"; refuse "cannot rewrite $bat"; }; }
probe() {
    local t po bat o why="" tree log
    [ -n "$ME" ] || { echo "REFUSE(2) [resume --probe]: S4E_SEAT unset"; exit 2; }
    t="$(mktemp -d "${TMPDIR:-/tmp}/s4e_resume_probe.XXXXXX")" || { echo "REFUSE(2) [resume --probe]: mktemp failed"; exit 2; }
    trap 'rm -rf "$t"' EXIT
    po="$t/po"; mkdir -p "$po/tasks" "$po/$ME/inbox" "$po/claims" "$t/wt" && : > "$t/run.log"
    { head -1 "$PO/MODE" 2>/dev/null || echo TENET; echo "# probe"; grep -E '^(ROSTER|LANES|ORDER-OF-WORK|BOSSES|ON-CALL):' "$PO/MODE" 2>/dev/null; } > "$po/MODE"
    [ -f "$PO/PROTOCOL-VERSION" ] && cp "$PO/PROTOCOL-VERSION" "$po/PROTOCOL-VERSION"
    printf '# plant queue\n2\tresume-plant\t%s\tCLAIMED:%s\n' "$ME" "$ME" > "$po/QUEUE.tsv"; printf '%s\n' "$ME" > "$po/claims/resume-plant.claim"
    bat="$po/tasks/resume-plant.task.md"
    printf '# TASK resume-plant\nGOAL: plant\nDONE-WHEN: false\n## NEXT\nthe old next block\n## QA\n## LEDGER\n- [plant] minted\n' > "$bat"
    run() { env -u S4E_PID_LOCK S4E_POST="$po" S4E_SEAT="$ME" S4E_HOME="$S4E" S4E_NO_BANNER=1 bash "$HERE/s4e_msg.sh" "$@" 2>&1; }
    o="$(run resume resume-plant --tree "$t/wt" --command "bash harness/scripts/test_design_box_scheduler_steps.sh --step 16" --state step-16-red --log "$t/run.log")"
    printf '%s\n' "$o" | grep -qE "^RESUME [0-9TZ:-]+ $ME tree=$t/wt command=bash harness/scripts/test_design_box_scheduler_steps.sh --step 16 state=step-16-red log=$t/run.log$" \
        || why="$why the write did not echo the line [$o];"
    grep -q '^## RESUME$' "$bat" || why="$why no ## RESUME heading;"
    [ "$(awk '/^## /{print; exit}' "$bat")" = "## RESUME" ] || why="$why ## RESUME is not the first section;"
    grep -q '^the old next block$' "$bat" || why="$why the NEXT block was lost;"
    o="$(run resume resume-plant --tree "$t/wt" --command "second" --state s2 --log "$t/run.log")"
    [ "$(newest "$bat" | sed 's/.* command=//')" = "second state=s2 log=$t/run.log" ] || why="$why the second line is not newest;"
    [ "$(grep -c '^RESUME ' "$bat")" = 2 ] || why="$why not two RESUME lines;"
    o="$(run resume resume-plant)"; printf '%s\n' "$o" | grep -q 'command=second state=s2' || why="$why the read did not print the newest line [$o];"
    run resume resume-plant --tree "$t/absent" --command x --state s --log "$t/run.log" >/dev/null && why="$why an absent tree was accepted;"
    run resume resume-plant --tree "$t/wt" --command x --state s --log "$t/absent.log" >/dev/null && why="$why an absent log was accepted;"
    run resume resume-plant --tree "$t/wt" --command '`x`' --state s --log "$t/run.log" >/dev/null && why="$why a backtick command was accepted;"
    [ "$(grep -c '^RESUME ' "$bat")" = 2 ] || why="$why a refused write left a line;"
    o="$(run next)"; [ -n "$(printf '%s\n' "$o" | awk '/^MODE: /{next} {print; exit}' | grep '^RESUME ')" ] \
        || why="$why next does not print the RESUME line first after the MODE line [$(printf '%s' "$o" | head -2 | tr '\n' '|' | cut -c1-160)];"
    if [ -z "$why" ]; then echo "RESUME tree=$t/wt command=second state=s2 log=$t/run.log (probe: two lines written newest first under ## RESUME ahead of NEXT, the newest read back," \
        "an absent tree, an absent log and a backtick refused and wrote nothing, next prints it first)"; exit 0; fi
    echo "RESUME PROBE RED:$why"; exit 1
}
[ "${1:-}" = --probe ] && probe
[ -n "${1:-}" ] || { printf '⛔ REFUSED (rc=2): s4e_msg.sh resume needs a topic -- nothing was read, nothing was written.\n   usage: %s\n' "$usage" >&2; exit 2; }
topic="$1"; shift; tree=""; command=""; state=""; log=""
while [ $# -gt 0 ]; do
    case "$1" in
        --tree) tree="${2:-}"; shift 2 || refuse "--tree takes a path" ;;
        --command) command="${2:-}"; shift 2 || refuse "--command takes the command" ;;
        --state) state="${2:-}"; shift 2 || refuse "--state takes a word" ;;
        --log) log="${2:-}"; shift 2 || refuse "--log takes a path" ;;
        *) refuse "unknown argument '$1'; usage: $usage" ;;
    esac
done
bat="$PO/tasks/$topic.task.md"; [ -f "$bat" ] || refuse "no baton $bat"
if [ -z "$tree$command$state$log" ]; then l="$(newest "$bat")"; [ -n "$l" ] && { echo "$l"; exit 0; }; echo "no RESUME line on $topic yet; write one: $usage"; exit 1; fi
[ -n "$ME" ] || refuse "S4E_SEAT unset"
[ -n "$tree" ] && [ -n "$command" ] && [ -n "$state" ] && [ -n "$log" ] || refuse "a RESUME line needs all four: --tree --command --state --log"
[ -d "$tree" ] || refuse "the tree $tree does not exist"
[ -e "$log" ] || refuse "the log $log does not exist"
case "$command$state" in *'`'*|*'$('*|*$'\n'*) refuse "the command and the state carry no backtick, command substitution or newline" ;; esac
case "$state" in *[[:space:]]*) refuse "the state is one word" ;; esac
line="RESUME $(date -u +%FT%TZ) $ME tree=$tree command=$command state=$state log=$log"
write_line "$bat" "$line"
echo "$line"
