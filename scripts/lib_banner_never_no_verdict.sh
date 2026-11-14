#!/usr/bin/env bash
set -u
S=/home/claude_junior_06/harness/scripts/s4e_banner_cached.sh
bash -n "$S" || { echo "GATE RED: syntax"; exit 1; }
T="$(mktemp -d /tmp/s4e/junior_06/bgate.XXXXXX)"; cp "$S" "$T/"
printf '%s\n' '#!/usr/bin/env bash' 'echo "BOX busy 15.3/16 pressure 83.71"' > "$T/s4e_msg.sh"
SEAT="bt-gate-$$"; rm -rf "/tmp/s4e/$SEAT"
o="$(S4E_SEAT=$SEAT S4E_HOME=/home/claude_junior_06 timeout 200 bash "$T/s4e_banner_cached.sh" /home/claude_junior_06 x < /dev/null)"
rm -rf "$T" "/tmp/s4e/$SEAT"
if printf '%s' "$o" | grep -q 'NO VERDICT'; then echo "GATE RED: NO VERDICT still shown"; exit 1; fi
if printf '%s' "$o" | grep -q 'IN-PROGRESS'; then echo "GATE OK [banner-never-no-verdict]"; exit 0; fi
echo "GATE RED: no verdict word at all"; exit 1
