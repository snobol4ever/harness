#!/usr/bin/env bash
# s4e_probe_recut.sh -- box-scheduler step 27's probe (CTO-496), extended for the PREMISE-WHEN form (the cio's fleet-queue ask), run as: bash harness/scripts/s4e_msg.sh recut --probe
# On a scratch postoffice, under the caller's identity, the verb `recut` re-cuts a plant row whose DONE-WHEN refuses and whose PREMISE-WHEN holds, the way the sweep retires it. It proves: a bare body (the step-27 form) re-cuts the DONE-WHEN and keeps the old one on DONE-WHEN-WAS directly above the new line, the premise untouched; a labelled body re-cuts both fields at once, each old text kept on its receipt with the seat and the WHY, both receipts above the DONE-WHEN line; a premise-only body re-cuts the PREMISE-WHEN alone and keeps the old premise on PREMISE-WHEN-WAS; the retired row reopens to FREE; the LEDGER gets its line; and refusals (a body that changes neither field, a label that is not one of the three, a prose premise, the same DONE-WHEN text again, an unknown topic) each exit non-zero with the baton byte-identical. Prints one line on success:
#   RECUT wrote DONE-WHEN-WAS premise_was=1 (probe: ...)
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
oprem='grep -q old-premise-probe "$S4E_HOME/harness/scripts/s4e_msg.sh"'
printf '# TASK %s\nGOAL: plant\nDONE-WHEN: no-such-command-recut-probe --arg\nPREMISE-WHEN: %s\nLINKS: minted via `mint` by probe_owner, %s\n## NEXT\nprobe\n## QA\n## LEDGER\n- [probe_owner] minted\n' "$t" "$oprem" "$now" > "$b"
bus() { env -u S4E_PID_LOCK S4E_POST="$po" S4E_SEAT="$ME" S4E_HOME="$S4E" S4E_NO_BANNER=1 bash "$HERE/s4e_msg.sh" "$@"; }
new='test -f "$S4E_HOME/harness/scripts/s4e_msg.sh"'
new2='test -f "$S4E_HOME/harness/scripts/s4e_probe_recut.sh"'
prem2='grep -q "recut)" "$S4E_HOME/harness/scripts/s4e_msg.sh"'
prem3='grep -q "recut)" "$S4E_HOME/harness/scripts/s4e_probe_recut.sh"'
why=""; pw=0

# 1. the bare step-27 body: the DONE-WHEN re-cut, its old text on DONE-WHEN-WAS directly above the new line, the premise untouched
printf '%s\n' "$new" | bus recut "$t" --stdin > "$w/out_bare" 2>&1; rc1=$?
[ "$rc1" = 0 ] || why="$why the bare re-cut returned rc $rc1 ($(tail -1 "$w/out_bare"));"
[ "$(grep -c '^DONE-WHEN:' "$b")" = 1 ] || why="$why the baton carries $(grep -c '^DONE-WHEN:' "$b") DONE-WHEN lines, not one;"
grep -qxF "DONE-WHEN: $new" "$b" || why="$why the new DONE-WHEN is not on the baton;"
grep -qxF 'DONE-WHEN: no-such-command-recut-probe --arg' "$b" && why="$why the old DONE-WHEN survived;"
grep -q '^DONE-WHEN-WAS: .*: no-such-command-recut-probe --arg$' "$b" || why="$why no DONE-WHEN-WAS receipt holds the old criterion;"
grep -qxF "PREMISE-WHEN: $oprem" "$b" || why="$why the bare body touched the premise;"
n1="$(grep -n '^DONE-WHEN-WAS: ' "$b" | cut -d: -f1)"; n2="$(grep -n '^DONE-WHEN: ' "$b" | cut -d: -f1)"
[ -n "$n1" ] && [ "$n1" = "$((n2 - 1))" ] || why="$why the receipt is not directly above the new DONE-WHEN (receipt line ${n1:-none}, DONE-WHEN line ${n2:-none});"
st="$(awk -F'\t' -v t="$t" '$2 == t { print $4; exit }' "$po/QUEUE.tsv")"
[ "$st" = FREE ] || why="$why the retired row's state is '$st', not FREE;"
grep -q "^- \[$ME·.*\] RE-CUT (box-scheduler step 27" "$b" || why="$why no RE-CUT LEDGER line;"

# 2. a labelled body re-cuts both fields at once; each old text is kept on its receipt with the WHY, both receipts above the DONE-WHEN line
printf 'DONE-WHEN: %s\nPREMISE-WHEN: %s\nWHY: probe second cut\n' "$new2" "$prem2" | bus recut "$t" --stdin > "$w/out_both" 2>&1; rc2=$?
[ "$rc2" = 0 ] || why="$why the labelled re-cut returned rc $rc2 ($(tail -1 "$w/out_both"));"
grep -qxF "DONE-WHEN: $new2" "$b" || why="$why the labelled body did not re-cut the DONE-WHEN;"
grep -qxF "PREMISE-WHEN: $prem2" "$b" || why="$why the labelled body did not re-cut the PREMISE-WHEN;"
grep -qF "DONE-WHEN-WAS: " "$b" && grep -qF "(why: probe second cut): $new" "$b" || why="$why no DONE-WHEN-WAS receipt holds the old DONE-WHEN with the WHY;"
grep -qF "PREMISE-WHEN-WAS: " "$b" && grep -qF "(why: probe second cut): $oprem" "$b" || why="$why no PREMISE-WHEN-WAS receipt holds the old PREMISE-WHEN with the WHY;"
nd="$(grep -n '^DONE-WHEN: ' "$b" | cut -d: -f1)"; nw="$(grep -n '^DONE-WHEN-WAS: ' "$b" | tail -1 | cut -d: -f1)"; np="$(grep -n '^PREMISE-WHEN-WAS: ' "$b" | tail -1 | cut -d: -f1)"
[ -n "$np" ] && [ -n "$nw" ] && [ "$np" = "$((nw - 1))" ] && [ "$nw" = "$((nd - 1))" ] || why="$why the receipts are not directly above the DONE-WHEN line (premise receipt ${np:-none}, DONE-WHEN receipt ${nw:-none}, DONE-WHEN ${nd:-none});"

# 3. a premise-only body: the PREMISE-WHEN alone (the premise path), the DONE-WHEN and its receipts unchanged
why_before="$why"; dwas_before="$(grep -c '^DONE-WHEN-WAS: ' "$b")"
printf 'PREMISE-WHEN: %s\nWHY: probe premise alone\n' "$prem3" | bus recut "$t" --stdin > "$w/out_prem" 2>&1; rc3=$?
[ "$rc3" = 0 ] || why="$why the premise-only re-cut returned rc $rc3 ($(tail -1 "$w/out_prem"));"
grep -qxF "PREMISE-WHEN: $prem3" "$b" || why="$why the premise-only body did not re-cut the PREMISE-WHEN;"
grep -qxF "DONE-WHEN: $new2" "$b" || why="$why the premise-only body changed the DONE-WHEN;"
[ "$(grep -c '^DONE-WHEN-WAS: ' "$b")" = "$dwas_before" ] || why="$why the premise-only body wrote a DONE-WHEN receipt;"
grep -qF "(why: probe premise alone): $prem2" "$b" || why="$why no PREMISE-WHEN-WAS receipt holds the premise the premise-only body replaced;"
[ "$why" = "$why_before" ] && pw=1
cp "$b" "$w/after.task.md"

# 4. refusals: each leaves the baton byte-identical to after the premise-only re-cut
refuse_case() {   # <name> <body>: refused, and the baton is byte-identical to after the premise-only re-cut
    printf '%s\n' "$2" | bus recut "$t" --stdin > "$w/out_$1" 2>&1 && why="$why $1 was accepted;"
    cmp -s "$b" "$w/after.task.md" || why="$why $1 changed the baton;"
}
refuse_case same "$new2"
refuse_case whyonly 'WHY: nothing in this body changes a field'
refuse_case label "$(printf 'GOAL: changed the goal\nDONE-WHEN: %s' "$new")"
refuse_case prose "$(printf 'PREMISE-WHEN: the premise holds')"
bus recut "recut-probe-no-such-$$" --stdin < <(printf '%s\n' "$new") > "$w/out_unknown" 2>&1 && why="$why an unknown topic was accepted;"
cmp -s "$b" "$w/after.task.md" || why="$why an unknown topic changed the baton;"
[ ! -d "$po/.mint.lock" ] || why="$why a refusal left the mint lock held;"

# 5. a baton whose ## NEXT repeats the criterion (the mint writes it twice): the header alone is re-cut rc 0, the NEXT line unchanged
t2="$t-next"; b2="$po/tasks/$t2.task.md"
printf '4\t%s\tprobe_owner\tRETIRED:criterion-refused-3-sweeps-probe\n' "$t2" >> "$po/QUEUE.tsv"
printf '# TASK %s\nGOAL: plant\nDONE-WHEN: no-such-command-recut-probe --arg\nLINKS: minted via `mint` by probe_owner, %s\n## NEXT\nprobe\nDONE-WHEN: no-such-command-recut-probe --arg\n## QA\n## LEDGER\n- [probe_owner] minted\n' "$t2" "$now" > "$b2"
printf 'DONE-WHEN: %s\n' "$new2" | bus recut "$t2" --stdin > "$w/out_next" 2>&1; rc5=$?
[ "$rc5" = 0 ] || why="$why a baton whose NEXT repeats the DONE-WHEN was refused rc $rc5 ($(tail -1 "$w/out_next"));"
[ "$(sed '/^## NEXT/q' "$b2" | grep -cxF "DONE-WHEN: $new2")" = 1 ] || why="$why the header DONE-WHEN was not re-cut;"
[ "$(sed -n '/^## NEXT/,$p' "$b2" | grep -cxF 'DONE-WHEN: no-such-command-recut-probe --arg')" = 1 ] || why="$why the NEXT DONE-WHEN line was touched;"
[ -n "$why" ] || [ "$pw" = 1 ] || why="$why the premise path was not exercised;"

if [ -z "$why" ]; then
    echo "RECUT wrote DONE-WHEN-WAS premise_was=1 (probe: on a scratch postoffice a RETIRED plant row was re-cut three ways: a bare body re-cut the DONE-WHEN and kept its old text on DONE-WHEN-WAS above the new line; a labelled body re-cut both fields, each old text on its receipt with the WHY; a premise-only body re-cut the PREMISE-WHEN alone, its old text on PREMISE-WHEN-WAS. The row reopened to FREE and the LEDGER got its line; a baton whose ## NEXT repeats the criterion re-cuts its header alone and leaves the NEXT line; a body that changes neither field, a label that is not one of the three, a prose premise, the same DONE-WHEN text again and an unknown topic each refused with the baton byte-identical)"
    exit 0
fi
echo "RECUT PROBE RED:$why"
tail -5 "$w/out_both" | sed 's/^/    /'
exit 1
