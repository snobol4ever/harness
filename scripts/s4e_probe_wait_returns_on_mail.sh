#!/usr/bin/env bash
# s4e_probe_wait_returns_on_mail.sh -- THE PROBE of row bus-next-wait-returns-when-a-telegram-arrives-so-a-waiting-seat-reads-its-mail
# (officer_05, 2026-11-08 13:2x CST, on the coo's telegram of 11:54: an officer's wait (seat-me, ask-opus) never sees its own inbox, so a seat on
# next --wait 240 sat through 12 telegrams). MEASURED at harness 4b3c63ae: next --wait S is ONE beanstalkd reserve with timeout S
# (s4e_queue_reserve_pass's _rh), which looks at nothing else until S passes. On a scratch postoffice and a PRIVATE beanstalkd (never 11300), empty tubes:
#   next --wait 60 as seat pa; at 3 s a telegram lands in pa's inbox.  EXPECT next prints a line starting "MAIL: " before it ends (mail=1);
#   the control: next --wait 6 with no telegram prints no MAIL line (quiet=1); a plain next (no --wait) prints none either (plain=1).
# One line: WAIT_MAIL mail=0|1 quiet=0|1 plain=0|1 ok=0|1. rc 0 ok, 1 red, 2 could not measure.
# The lander copies this file to harness/scripts/s4e_probe_wait_returns_on_mail.sh unchanged and lands it with the cure.
set -u
S4E="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"; ME="${S4E_SEAT:?REFUSE(2): S4E_SEAT unset}"
MSG="$S4E/harness/scripts/s4e_msg.sh"; UQ="$S4E/harness/scripts/util_queue.py"
[ -f "$MSG" ] && [ -f "$UQ" ] || { echo "REFUSE(2): no $MSG or $UQ"; exit 2; }
command -v beanstalkd >/dev/null || { echo "REFUSE(2): no beanstalkd binary"; exit 2; }
mkdir -p "/tmp/s4e/$ME"
port=$((21000 + ($$ % 20000)))
beanstalkd -l 127.0.0.1 -p "$port" >/dev/null 2>&1 & bp=$!
w="$(mktemp -d "/tmp/s4e/$ME/wait_mail.XXXXXX")" || { kill "$bp"; echo "REFUSE(2): mktemp failed"; exit 2; }
trap 'kill "$bp" 2>/dev/null; wait "$bp" 2>/dev/null; rm -rf "$w"' EXIT
export S4E_QUEUE_PORT="$port"
for i in $(seq 1 50); do python3 "$UQ" status 2>/dev/null | grep -q '^QUEUE daemon=beanstalkd' && break; sleep 0.1; done
python3 "$UQ" status 2>/dev/null | grep -q '^QUEUE daemon=beanstalkd' || { echo "REFUSE(2): a private beanstalkd would not start on port $port"; exit 2; }
mkdir -p "$w/tasks" "$w/claims" "$w/pa/inbox"
{ head -1 /home/resources/postoffice/MODE; echo "# probe"; echo "ROSTER: pa"; } > "$w/MODE"
[ -f /home/resources/postoffice/PROTOCOL-VERSION ] && cp /home/resources/postoffice/PROTOCOL-VERSION "$w/PROTOCOL-VERSION"
printf 'seat\tname\troot\tmodel\teffort\tcolor\ttier\trole\npa\tPA-PLANT\t/tmp\tclaude-haiku-5-5\thigh\tblue\t4\tworker\n' > "$w/TIERS.tsv"
printf '# probe\n' > "$w/QUEUE.tsv"
bus() { env -u S4E_PID_LOCK S4E_POST="$w" S4E_SEAT=pa S4E_HOME="$S4E" S4E_TIERS="$w/TIERS.tsv" S4E_NO_BANNER=1 S4E_NO_PREMISE_CHECK=1 timeout -k 5 120 bash "$MSG" next "$@" 2>&1 < /dev/null; }
( sleep 3; printf 'FROM plant TO pa RE plant\nbody\n' > "$w/pa/inbox/1-plant-one.msg" ) & pl=$!
o1="$(bus --wait 60)"; wait "$pl" 2>/dev/null
m=0; printf '%s\n' "$o1" | grep -q '^MAIL: ' && m=1
rm -f "$w/pa/inbox/"*.msg
o2="$(bus --wait 6)"; q=0; printf '%s\n' "$o2" | grep -q '^MAIL: ' || q=1
o3="$(bus)"; p=0; printf '%s\n' "$o3" | grep -q '^MAIL: ' || p=1
ok=0; [ "$m" = 1 ] && [ "$q" = 1 ] && [ "$p" = 1 ] && ok=1
echo "WAIT_MAIL mail=$m quiet=$q plain=$p ok=$ok"
[ "$ok" = 1 ] || { echo "  wait-60 said: $(printf '%s' "$o1" | grep -v '^\s*$' | tail -3 | tr '\n' '|' | cut -c1-240)"; }
[ "$ok" = 1 ]
