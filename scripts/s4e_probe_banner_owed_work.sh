#!/usr/bin/env bash
# s4e_probe_banner_owed_work.sh -- THE PROBE of row bus-the-stop-banner-reads-in-progress-while-the-inbox-holds-mail-or-the-seat-holds-a-claimed-row
# (officer_05, 2026-11-08 12:4x CST, on the coo's telegram of 11:55: Lon, verbatim, "That officer's banner read SUCCESS, so I /clear as a matter of
# protocol." OFFICER-01 read SUCCESS with 12 unread telegrams and CLAIMED:officer_01 on its umbrella row, and lost its context mid-lead).
# MEASURED at harness 2c15684e: the banner's only mail arm is DRAIN FIRST, which fires for an HQ seat alone (s4e_is_hq) and only past 30 min
# (S4E_DRAIN_MIN); a claimed row's OPEN state never reaches the headline. On a scratch postoffice (S4E_POST), never the live one:
#   arm mail    one message in the seat's inbox, no claim          -> the headline (the banner's ✅/⛔/⚠/⏳ line) reads IN-PROGRESS, never SUCCESS
#   arm claim   an empty inbox, the row CLAIMED:<seat> in QUEUE.tsv and its claim file naming the seat -> IN-PROGRESS
#   arm free    an empty inbox, no claim                            -> not IN-PROGRESS (the control: the cure blocks nothing else)
# One line: BANNER_OWED mail=0|1 claim=0|1 free=0|1 ok=0|1. rc 0 ok, 1 red, 2 could not measure.
# The lander copies this file to harness/scripts/s4e_probe_banner_owed_work.sh unchanged and lands it with the cure.
set -u
S4E="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"; ME="${S4E_SEAT:?REFUSE(2): S4E_SEAT unset}"
MSG="$S4E/harness/scripts/s4e_msg.sh"; PO=/home/resources/postoffice
[ -f "$MSG" ] || { echo "REFUSE(2): no $MSG"; exit 2; }
w="$(mktemp -d "/tmp/s4e/$ME/banner_owed.XXXXXX")" || { echo "REFUSE(2): mktemp failed"; exit 2; }
trap 'rm -rf "$w"' EXIT
t="banner-owed-plant-$$"
fresh() { rm -rf "$w/po"; mkdir -p "$w/po/$ME/inbox" "$w/po/tasks" "$w/po/claims"
    { head -1 "$PO/MODE" 2>/dev/null || echo TENET; echo "# probe"; grep -E '^(ROSTER|LANES|ORDER-OF-WORK|BOSSES|ON-CALL|FLEET):' "$PO/MODE" 2>/dev/null; } > "$w/po/MODE"
    [ -f "$PO/PROTOCOL-VERSION" ] && cp "$PO/PROTOCOL-VERSION" "$w/po/PROTOCOL-VERSION"
    printf '# probe\n' > "$w/po/QUEUE.tsv"
    printf '# TASK %s\nGOAL: plant\nDONE-WHEN: false\n## NEXT\nplant\n## QA\n## LEDGER\n' "$t" > "$w/po/tasks/$t.task.md"; }
head_of() { env -u S4E_PID_LOCK S4E_POST="$w/po" S4E_SEAT="$ME" S4E_HOME="$S4E" S4E_NO_BANNER=1 timeout -k 5 120 bash "$MSG" banner 2>&1 < /dev/null | grep -m1 -E '(✅|⛔|⚠|⏳) [A-Z]'; }
fresh; printf 'FROM plant TO %s RE plant\nbody\n' "$ME" > "$w/po/$ME/inbox/1-plant-one.msg"
h1="$(head_of)"; [ -n "$h1" ] || { echo "REFUSE(2): arm mail printed no headline"; exit 2; }
fresh; printf '1\t%s\t%s\tCLAIMED:%s\n' "$t" "$ME" "$ME" >> "$w/po/QUEUE.tsv"; printf '%s\n' "$ME" > "$w/po/claims/$t.claim"
h2="$(head_of)"; [ -n "$h2" ] || { echo "REFUSE(2): arm claim printed no headline"; exit 2; }
fresh
h3="$(head_of)"; [ -n "$h3" ] || { echo "REFUSE(2): arm free printed no headline"; exit 2; }
m=0; printf '%s' "$h1" | grep -q 'IN-PROGRESS' && ! printf '%s' "$h1" | grep -q 'SUCCESS' && m=1
c=0; printf '%s' "$h2" | grep -q 'IN-PROGRESS' && ! printf '%s' "$h2" | grep -q 'SUCCESS' && c=1
f=0; printf '%s' "$h3" | grep -q 'IN-PROGRESS' || f=1
ok=0; [ "$m" = 1 ] && [ "$c" = 1 ] && [ "$f" = 1 ] && ok=1
echo "BANNER_OWED mail=$m claim=$c free=$f ok=$ok"
[ "$ok" = 1 ] || { echo "  mail:  ${h1:0:160}"; echo "  claim: ${h2:0:160}"; echo "  free:  ${h3:0:160}"; }
[ "$ok" = 1 ]
