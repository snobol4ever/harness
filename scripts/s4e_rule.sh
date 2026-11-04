#!/usr/bin/env bash
# s4e_rule.sh -- the bus verb `rule` (DESIGN-PLAN box-scheduler step 12, CTO-496): ONE act writes a ruling ONCE -- the bullet at the head of its
# GOAL file's LIVE CURSOR (committed and pushed, rebased over origin), a telegram to every named seat citing the hash, and the row's baton LEDGER line.
#   bash harness/scripts/s4e_msg.sh rule <GOAL-file> <RULING-ID> --to <seat[,seat...]> --row <topic> [--no-push] --stdin <<'R'
#   <the headline, one line>
#   <the body, any lines>
#   R
#   bash harness/scripts/s4e_msg.sh rule --probe     the verb proved on a scratch postoffice and a scratch git origin: RULE wrote goal telegram baton
# Every input is checked before the first write; a ruling id already heading a LIVE CURSOR bullet refuses (one write per ruling); a failed push undoes
# the local commit and writes nothing else. rc 0 written, 1 refused (nothing written), 2 could not measure.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
PO="${S4E_POST:-/home/resources/postoffice}"
ME="${S4E_SEAT:-}"
[ -n "$ME" ] || { echo "REFUSE(2) [rule]: S4E_SEAT unset -- run it as: bash harness/scripts/s4e_msg.sh rule ..." >&2; exit 2; }
refuse() { echo "⛔ RULE REFUSED (nothing written): $*" >&2; exit 1; }
usage="s4e_msg.sh rule <GOAL-file> <RULING-ID> --to <seat[,seat...]> --row <topic> [--no-push] --stdin <<'R' (headline line, then body) R"
probe() {
    local t po og gh g2 h h0 rc why="" s m
    mkdir -p "/tmp/s4e/$ME" || exit 2
    t="$(mktemp -d "/tmp/s4e/$ME/rule_probe.XXXXXX")" || exit 2
    trap 'rm -rf "$t"' EXIT
    po="$t/po"; og="$t/origin.git"; gh="$t/gh"; g2="$t/g2"
    mkdir -p "$po/tasks" "$po/probe_ruler/inbox" "$po/probe_a/inbox" "$po/probe_b/inbox" || exit 2
    printf '# TASK probe-row\nGOAL: probe\nDONE-WHEN: true\n## NEXT\nprobe\n## QA\n## LEDGER\n- [probe] minted\n' > "$po/tasks/probe-row.task.md"
    gq() { git -c user.name=probe -c user.email=probe@localhost -c init.defaultBranch=main "$@"; }
    gq init -q --bare "$og" && gq clone -q "$og" "$gh" 2>/dev/null || { echo "REFUSE(2) [rule --probe]: cannot make a scratch git origin" >&2; exit 2; }
    printf '# GOAL-PROBE\n\n## LIVE CURSOR\n- **PROBE-0 (seed) -- the old bullet.**\n## LATER\n' > "$gh/GOAL-PROBE.md"
    { gq -C "$gh" add GOAL-PROBE.md && gq -C "$gh" commit -qm seed && gq -C "$gh" push -q origin HEAD:main; } >/dev/null 2>&1 \
        || { echo "REFUSE(2) [rule --probe]: cannot seed the scratch origin" >&2; exit 2; }
    gq clone -q "$og" "$g2" 2>/dev/null && echo other > "$g2/OTHER.md" && gq -C "$g2" add OTHER.md && gq -C "$g2" commit -qm other && gq -C "$g2" push -q origin HEAD:main 2>/dev/null || exit 2
    run() { printf '%s\n' "$1" | env -u S4E_PID_LOCK S4E_POST="$po" S4E_SEAT=probe_ruler S4E_HOME="$S4E" bash "$HERE/s4e_msg.sh" rule "${@:2}" >> "$t/out" 2>&1; }
    count() { ls "$po/$1/inbox" 2>/dev/null | wc -l; }
    run $'PROBE HEADLINE.\nthe probe body, line one\nline two' "$gh/GOAL-PROBE.md" PROBE-1 --to probe_a,probe_b --row probe-row --stdin; rc=$?
    h="$(git -C "$og" rev-parse --short HEAD)"
    [ "$rc" = 0 ] || why="$why first write rc=$rc;"
    git -C "$og" show HEAD:GOAL-PROBE.md | awk 'f {print; exit} /^## LIVE CURSOR/ {f=1}' \
        | grep -q '^- \*\*PROBE-1 (.*probe_ruler) -- PROBE HEADLINE\.\*\* the probe body, line one line two$' || why="$why origin's LIVE CURSOR does not lead with PROBE-1;"
    git -C "$og" show HEAD:GOAL-PROBE.md | grep -q '^- \*\*PROBE-0 ' || why="$why the old bullet is gone;"
    git -C "$og" show HEAD:OTHER.md >/dev/null 2>&1 || why="$why the write did not rebase over origin;"
    for s in probe_a probe_b; do
        [ "$(count $s)" = 1 ] || { why="$why $s holds $(count $s) telegrams;"; continue; }
        m="$(cat "$po/$s/inbox"/*.msg)"
        [ "$(printf '%s\n' "$m" | head -1)" = "FROM probe_ruler TO $s RE ruling-probe-1" ] || why="$why $s telegram header wrong;"
        printf '%s\n' "$m" | grep -q "GOAL-PROBE.md at $h" || why="$why $s telegram does not cite $h;"
    done
    [ "$(count probe_ruler)" = 0 ] || why="$why the ruler telegrammed itself;"
    tail -1 "$po/tasks/probe-row.task.md" | grep -q "^- \[probe_ruler·.*\] RULING PROBE-1 (GOAL-PROBE.md $h): PROBE HEADLINE\. Telegrams: probe_a,probe_b\.$" \
        || why="$why the baton's last LEDGER line is not the ruling;"
    h0="$(git -C "$og" rev-parse HEAD)"; s="$(wc -l < "$po/tasks/probe-row.task.md")"
    run $'PROBE HEADLINE.\nagain' "$gh/GOAL-PROBE.md" PROBE-1 --to probe_a,probe_b --row probe-row --stdin && why="$why a second write of PROBE-1 was accepted;"
    run $'PROBE TWO.\nbad seat' "$gh/GOAL-PROBE.md" PROBE-2 --to probe_a,no_such_seat --row probe-row --stdin && why="$why an unknown seat was accepted;"
    run $'PROBE THREE.\nbad row' "$gh/GOAL-PROBE.md" PROBE-3 --to probe_a --row no-such-row --stdin && why="$why an unknown row was accepted;"
    [ "$(git -C "$og" rev-parse HEAD)" = "$h0" ] && [ "$(count probe_a)" = 1 ] && [ "$(count probe_b)" = 1 ] \
        && [ "$(wc -l < "$po/tasks/probe-row.task.md")" = "$s" ] || why="$why a refused write left a trace;"
    grep -q 'PROBE-2\|PROBE-3' "$gh/GOAL-PROBE.md" && why="$why a refused write left the GOAL file edited;"
    if [ -z "$why" ]; then
        echo "RULE wrote goal telegram baton (probe: PROBE-1 heads the LIVE CURSOR on a scratch origin at $h, rebased over a commit it lacked;" \
             "2 telegrams cite $h; 1 baton LEDGER line; a second write of the same id, an unknown seat and an unknown row each refused and wrote nothing)"
        exit 0
    fi
    sed 's/^/    /' "$t/out" | tail -20
    echo "RULE PROBE RED:$why"; exit 1
}
[ "${1:-}" = --probe ] && probe
[ $# -ge 2 ] || { printf '⛔ REFUSED (rc=2): s4e_msg.sh rule needs a GOAL file and a ruling id -- nothing was read, nothing was written.\n   usage: %s\n' "$usage" >&2; exit 2; }
goal="$1"; id="$2"; shift 2; to=""; row=""; push=1; stdin=0
while [ $# -gt 0 ]; do
    case "$1" in
        --to) to="${2:-}"; shift 2 || refuse "--to takes seats" ;;
        --row) row="${2:-}"; shift 2 || refuse "--row takes a topic" ;;
        --no-push) push=0; shift ;;
        --stdin|-) stdin=1; shift ;;
        *) refuse "unknown argument '$1'; usage: $usage" ;;
    esac
done
case "$goal" in /*) ;; *) goal="$S4E/.github/$goal" ;; esac
gf="$(basename "$goal")"; repo="$(dirname "$goal")"
[ -f "$goal" ] || refuse "no GOAL file $goal"
[ "$(grep -c '^## LIVE CURSOR' "$goal")" = 1 ] || refuse "$gf has no single ## LIVE CURSOR heading"
[[ "$id" =~ ^[A-Z][A-Z0-9]*-[0-9]+$ ]] || refuse "the ruling id '$id' is not NAME-NUMBER (CTO-503)"
grep -qP "^- \*\*[^A-Za-z0-9]*\Q$id\E(?![0-9])" "$goal" && refuse "$id already heads a bullet of $gf -- a ruling is written once"
[ "$stdin" = 1 ] || refuse "the ruling text comes through --stdin with a quoted heredoc; usage: $usage"
text="$(cat)"
case "$text" in *'`'*|*'$('*) refuse "the text carries a backtick or a command substitution; say it in words" ;; esac
headline="$(printf '%s\n' "$text" | head -1 | sed 's/[[:space:]]*$//')"
body="$(printf '%s\n' "$text" | tail -n +2 | tr '\n' ' ' | sed 's/[[:space:]][[:space:]]*/ /g; s/^ //; s/ $//')"
[ -n "$headline" ] || refuse "the first line (the headline) is empty"
[ -n "$to" ] || refuse "--to names the seats telegrammed (comma-separated)"
IFS=, read -ra seats <<< "$to"
for s in "${seats[@]}"; do
    [ "$s" = ceo ] && refuse "the ceo seat was fired 2026-10-31 (CTO-469)"
    [ -n "$s" ] && [ -d "$PO/$s/inbox" ] || refuse "no postoffice mailbox '$s'"
done
[ -n "$row" ] || refuse "--row names the row whose baton records the ruling"
bat="$PO/tasks/$row.task.md"
[ -f "$bat" ] || refuse "no baton $bat"
[ "$(grep -c '^## LEDGER' "$bat")" = 1 ] || refuse "baton $row has no single ## LEDGER heading"
git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || refuse "$repo is not a git checkout"
br="$(git -C "$repo" symbolic-ref --short -q HEAD)" || refuse "$repo is on a detached HEAD"
{ git -C "$repo" diff --quiet -- "$gf" && git -C "$repo" diff --cached --quiet -- "$gf"; } || refuse "$gf carries uncommitted edits; land or drop them first"
[ -z "$(git -C "$repo" diff --cached --name-only)" ] || refuse "$repo has staged files; the ruling commit holds only $gf"
stamp="$(date '+%Y-%m-%d %H:%M %Z')"
bullet="- **$id ($stamp, $ME) -- $headline**${body:+ $body}"
tmp="$(mktemp "$goal.rule.XXXXXX")" || refuse "cannot write beside $goal"
B="$bullet" awk '{print} /^## LIVE CURSOR/ {print ENVIRON["B"]}' "$goal" > "$tmp" && mv "$tmp" "$goal" || { rm -f "$tmp"; refuse "cannot rewrite $gf"; }
gq() { git -C "$repo" -c user.name="$(git -C "$repo" config user.name || echo LCherryholmes)" -c user.email="$(git -C "$repo" config user.email || echo lcherryh@yahoo.com)" "$@"; }
msg="$(printf '%s: %s\n\nWritten by s4e_msg.sh rule (%s); telegrams: %s; row: %s.' "$id" "$headline" "$ME" "$to" "$row")"
gq add -- "$gf" && printf '%s\n' "$msg" | gq commit -q -F - -- "$gf" >/dev/null || { git -C "$repo" checkout -q -- "$gf"; refuse "the commit of $gf failed"; }
where=local
if [ "$push" = 1 ]; then
    if gq pull -q --rebase --autostash origin "$br" >/dev/null 2>&1 && gq push -q origin "HEAD:$br" >/dev/null 2>&1; then where=pushed; else
        git -C "$repo" rebase --abort >/dev/null 2>&1
        gq reset -q --soft HEAD~1 && gq restore -q --staged --worktree -- "$gf"
        refuse "the push of $gf to origin/$br failed; the commit is undone (log it with s4e_push_rejected.sh, then run rule again)"
    fi
fi
h="$(git -C "$repo" rev-parse --short HEAD)"
sent=0; failed=""
for s in "${seats[@]}"; do
    printf 'RULING %s by %s, %s: written to %s at %s (%s), LIVE CURSOR head.\n%s\n%s\nRow: %s.\n' "$id" "$ME" "$stamp" "$gf" "$h" "$where" "$headline" "$body" "$row" \
        | S4E_SEAT="$ME" S4E_POST="$PO" S4E_HOME="$S4E" bash "$HERE/s4e_msg.sh" send "$s" "ruling-${id,,}" --stdin >/dev/null 2>&1 && sent=$((sent+1)) || failed="$failed $s"
done
line="- [$ME·$stamp] RULING $id ($gf $h): $headline Telegrams: $to."
tmp="$(mktemp "$bat.rule.XXXXXX")" || { echo "⛔ RULE PARTIAL: $gf $h written, $sent telegram(s); the baton $row could not be written" >&2; exit 1; }
L="$line" awk 'function out() {if (!done) print ENVIRON["L"]; done=1} /^## / && led {out(); led=0} {print} /^## LEDGER/ {led=1} END {if (led) out()}' "$bat" > "$tmp" \
    && mv "$tmp" "$bat" || { rm -f "$tmp"; echo "⛔ RULE PARTIAL: $gf $h written, $sent telegram(s); the baton $row was not written" >&2; exit 1; }
[ -z "$failed" ] || { echo "⛔ RULE PARTIAL: $gf $h ($where) and baton $row written; telegram(s) NOT delivered to:$failed" >&2; exit 1; }
echo "RULE wrote goal telegram baton: $id heads $gf's LIVE CURSOR at $h ($where); $sent telegram(s) to $to; baton $row LEDGER line"
