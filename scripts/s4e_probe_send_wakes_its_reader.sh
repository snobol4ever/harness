#!/usr/bin/env bash
# s4e_probe_send_wakes_its_reader.sh -- THE PROBE of row bus-send-ends-with-the-wake-line-of-the-seat-it-wrote-to
# (officer_05, 2026-11-08 13:1x CST, on the coo's telegram of 11:54: OFFICER-01 sat idle with 12 unread telegrams, among them CTO-560's rows for it,
# while tier-haiku held 0 ready jobs and 3 juniors idled; each officer needed the coo's SendMessage to move). MEASURED at harness 4b3c63ae: queue,
# escalate, ask, answer, assign and mint end with lib_wake.sh's WAKE line (CIO-8), but send ends with "sent -> <seat>/<topic>" alone, so a telegram that
# carries work wakes nobody and the sender is never told whom to SendMessage. On a scratch postoffice (S4E_POST) and a scratch TIERS table:
#   send px <topic> --stdin  -> prints "sent -> px/<topic>" and then a line starting "WAKE: SendMessage to PX-PLANT" (px's session name).
# One line: SEND_WAKE sent=0|1 wake=0|1 ok=0|1. rc 0 ok, 1 red, 2 could not measure.
# The lander copies this file to harness/scripts/s4e_probe_send_wakes_its_reader.sh unchanged and lands it with the cure.
set -u
S4E="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"; ME="${S4E_SEAT:?REFUSE(2): S4E_SEAT unset}"
MSG="$S4E/harness/scripts/s4e_msg.sh"; PO=/home/resources/postoffice
[ -f "$MSG" ] || { echo "REFUSE(2): no $MSG"; exit 2; }
w="$(mktemp -d "/tmp/s4e/$ME/send_wake.XXXXXX")" || { echo "REFUSE(2): mktemp failed"; exit 2; }
trap 'rm -rf "$w"' EXIT
mkdir -p "$w/po/$ME/inbox" "$w/po/px/inbox" "$w/po/tasks" "$w/po/claims"
{ head -1 "$PO/MODE" 2>/dev/null || echo TENET; echo "# probe"; echo "ROSTER: $ME px"; } > "$w/po/MODE"
[ -f "$PO/PROTOCOL-VERSION" ] && cp "$PO/PROTOCOL-VERSION" "$w/po/PROTOCOL-VERSION"
printf '# probe\n' > "$w/po/QUEUE.tsv"
printf 'seat\tname\troot\tmodel\teffort\tcolor\ttier\trole\n%s\tME-PLANT\t/tmp\tclaude-opus-5-5\thigh\tyellow\t2\tofficer\npx\tPX-PLANT\t/tmp\tclaude-haiku-5-5\thigh\tcyan\t4\tworker\n' "$ME" > "$w/TIERS.tsv"
t="send-wake-plant-$$"
o="$(printf 'a plant body that asks px for work\n' | env -u S4E_PID_LOCK S4E_POST="$w/po" S4E_SEAT="$ME" S4E_HOME="$S4E" S4E_TIERS="$w/TIERS.tsv" S4E_NO_BANNER=1 timeout -k 5 60 bash "$MSG" send px "$t" --stdin 2>&1)"
s=0; printf '%s\n' "$o" | grep -qxF "sent -> px/$t" && s=1
[ "$s" = 1 ] || { echo "REFUSE(2): send did not deliver on the scratch postoffice: $(printf '%s' "$o" | tail -3 | tr '\n' '|' | cut -c1-200)"; exit 2; }
k=0; printf '%s\n' "$o" | grep -q '^WAKE: SendMessage to PX-PLANT' && k=1
# ARM 2 (the cio, 2026-11-12 12:4x CST, on the cfo's find of 12:4x): under FLEET: IDLE every seat reads asleep, so CIO-106's override named the operating
# boss for a fable seat's tube, and send to the cio printed "SendMessage to COO (seat coo; tube seat-cio)"; a telegram is read only by its addressee.
# A scratch MODE with FLEET: IDLE and BOSSES fx ox (ox the tier-2 operating boss), no seat scopes: send fx must name FX-PLANT, never OX-PLANT.
mkdir -p "$w/po/fx/inbox" "$w/po/ox/inbox" "$w/scopes"
{ head -1 "$PO/MODE" 2>/dev/null || echo TENET; echo "# probe"; echo "ROSTER: $ME px fx ox"; echo "BOSSES: fx ox"; echo "FLEET: IDLE (probe)"; } > "$w/po/MODE"
printf 'fx\tFX-PLANT\t/tmp\tclaude-fable-5-2\thigh\tred\t1\tdesigner\nox\tOX-PLANT\t/tmp\tclaude-opus-5-5\thigh\tblue\t2\tofficer\n' >> "$w/TIERS.tsv"
o2="$(printf 'a plant telegram to a sleeping boss\n' | env -u S4E_PID_LOCK S4E_POST="$w/po" S4E_SEAT="$ME" S4E_HOME="$S4E" S4E_TIERS="$w/TIERS.tsv" S4E_SEAT_SCOPES="$w/scopes" S4E_NO_BANNER=1 timeout -k 5 60 bash "$MSG" send fx "$t-2" --stdin 2>&1)"
printf '%s\n' "$o2" | grep -qxF "sent -> fx/$t-2" || { echo "REFUSE(2): arm 2 send did not deliver: $(printf '%s' "$o2" | tail -3 | tr '\n' '|' | cut -c1-200)"; exit 2; }
a=0; printf '%s\n' "$o2" | grep -q '^WAKE: SendMessage to FX-PLANT now (seat fx; tube seat-fx' && a=1
ok=0; [ "$s" = 1 ] && [ "$k" = 1 ] && [ "$a" = 1 ] && ok=1
echo "SEND_WAKE sent=$s wake=$k addressee_when_idle=$a ok=$ok"
[ "$ok" = 1 ]
