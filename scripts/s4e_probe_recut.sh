#!/usr/bin/env bash
# s4e_probe_recut.sh -- box-scheduler step 27's probe (CTO-496), run as: bash harness/scripts/s4e_msg.sh recut --probe
# On a scratch postoffice, under the caller's identity, the verb `recut` re-cuts a plant row whose DONE-WHEN refuses (its first command word
# is not on this box) and whose QUEUE state is RETIRED:criterion-refused, the way the sweep retires it. It proves: the re-cut writes ONE
# DONE-WHEN-WAS receipt holding the old criterion verbatim, directly above the single new DONE-WHEN; the retired row reopens to FREE; the
# baton LEDGER gets its RE-CUT line; and four refusals (the same text again, a prose criterion, a sweep placeholder, an unknown topic) each
# exit non-zero with the baton byte-identical. Prints one line on success:
#   RECUT wrote DONE-WHEN-WAS (probe: ...)
# rc 0 green; rc 1 the verb misbehaves (RECUT PROBE RED:<why>); rc 2 could not measure (no seat, no scratch).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
ME="${S4E_SEAT:-}"
refuse() { echo "REFUSE(2) [recut --probe]: $*"; exit 2; }
[ -n "$ME" ] || refuse "S4E_SEAT unset -- run it as: bash harness/scripts/s4e_msg.sh recut --probe"
mkdir -p "/tmp/s4e/$ME" || refuse "cannot make /tmp/s4e/$ME"
w="$(mktemp -d "/tmp/s4e/$ME/recut_probe.XXXXXX")" || refuse "mktemp failed"
trap 'rm -rf "$w"' EXIT
po="$w/po"; t="recut-probe-$$"; now="$(date -u +%FT%TZ)"; b="$po/tasks/$t.task.md"
mkdir -p "$po/tasks" "$po/$ME/inbox" || refuse "cannot make the scratch postoffice"
printf '3\t%s\tprobe_owner\tRETIRED:criterion-refused-3-sweeps-probe\n' "$t" > "$po/QUEUE.tsv"
printf '# TASK %s\nGOAL: plant\nDONE-WHEN: no-such-command-recut-probe --arg\nLINKS: minted via `mint` by probe_owner, %s\n## NEXT\nprobe\n## QA\n## LEDGER\n- [probe_owner] minted\n' "$t" "$now" > "$b"
bus() { env -u S4E_PID_LOCK S4E_POST="$po" S4E_SEAT="$ME" S4E_HOME="$S4E" S4E_NO_BANNER=1 bash "$HERE/s4e_msg.sh" "$@"; }
new='test -f "$S4E_HOME/harness/scripts/s4e_msg.sh"'
why=""

printf '%s\n' "$new" | bus recut "$t" --stdin > "$w/out_good" 2>&1; rc1=$?
[ "$rc1" = 0 ] || why="$why the re-cut returned rc $rc1 ($(tail -1 "$w/out_good"));"
[ "$(grep -c '^DONE-WHEN:' "$b")" = 1 ] || why="$why the baton carries $(grep -c '^DONE-WHEN:' "$b") DONE-WHEN lines, not one;"
grep -qxF "DONE-WHEN: $new" "$b" || why="$why the new DONE-WHEN is not on the baton;"
grep -qxF 'DONE-WHEN: no-such-command-recut-probe --arg' "$b" && why="$why the old DONE-WHEN survived;"
grep -q '^DONE-WHEN-WAS: .*: no-such-command-recut-probe --arg$' "$b" || why="$why no DONE-WHEN-WAS receipt holds the old criterion;"
n1="$(grep -n '^DONE-WHEN-WAS: ' "$b" | cut -d: -f1)"; n2="$(grep -n '^DONE-WHEN: ' "$b" | cut -d: -f1)"
[ -n "$n1" ] && [ "$n1" = "$((n2 - 1))" ] || why="$why the receipt is not directly above the new DONE-WHEN (receipt line ${n1:-none}, DONE-WHEN line ${n2:-none});"
st="$(awk -F'\t' -v t="$t" '$2 == t { print $4; exit }' "$po/QUEUE.tsv")"
[ "$st" = FREE ] || why="$why the retired row's state is '$st', not FREE;"
grep -q "^- \[$ME·.*\] RE-CUT DONE-WHEN (box-scheduler step 27, CTO-496): " "$b" || why="$why no RE-CUT LEDGER line;"
cp "$b" "$w/after.task.md"

refuse_case() {   # <name> <criterion text>: refused, and the baton is byte-identical to after the good re-cut
    printf '%s\n' "$2" | bus recut "$t" --stdin > "$w/out_$1" 2>&1 && why="$why $1 was accepted;"
    cmp -s "$b" "$w/after.task.md" || why="$why $1 changed the baton;"
}
refuse_case same "$new"
refuse_case prose 'the recut should make this work'
refuse_case placeholder 'echo "⛔ NOT MEASURED: probe placeholder"; exit 1'
bus recut "recut-probe-no-such-$$" --stdin < <(printf '%s\n' "$new") > "$w/out_unknown" 2>&1 && why="$why an unknown topic was accepted;"
cmp -s "$b" "$w/after.task.md" || why="$why an unknown topic changed the baton;"
[ ! -d "$po/.mint.lock" ] || why="$why a refusal left the mint lock held;"

if [ -z "$why" ]; then
    echo "RECUT wrote DONE-WHEN-WAS (probe: on a scratch postoffice a RETIRED plant row was re-cut: the old criterion kept verbatim on one receipt directly above the single new DONE-WHEN, the row reopened to FREE, one RE-CUT LEDGER line; the same text, a prose criterion, a placeholder and an unknown topic each refused with the baton byte-identical and no lock left)"
    exit 0
fi
echo "RECUT PROBE RED:$why"
tail -5 "$w/out_good" | sed 's/^/    /'
exit 1
