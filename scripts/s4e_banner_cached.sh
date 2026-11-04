#!/usr/bin/env bash
# s4e_banner_cached.sh <root> <seat> -- THE STOP HOOK'S BANNER, NEVER EMPTY (the cto, 2026-11-04, CTO-480; Lon in hq_prolog's window:
# "Ensure the banner display is automatic and does not depend on your feeble mind."). MEASURED: the banner verb took 51 s at load 26 in the
# cto's root and 28 s at load 20 in hq_prolog's; the old hook ran it inline under timeout 100 and printed an EMPTY systemMessage when the
# verb ran over, so Lon saw nothing for forty turns. THE SHAPE: print the seat's cached banner at once (/tmp/s4e/<seat>/banner.cache),
# refresh it in the background when it is older than 240 s (one refresh at a time, a lock older than 900 s is stale), and only the very
# first call with no cache runs the verb inline under the old budget. A cached banner older than 60 s says its age and the load.
#   s4e_banner_cached.sh <root> <seat>            the hook's call: prints the JSON {systemMessage} line
#   s4e_banner_cached.sh --refresh <root> <seat>  the background arm: rewrites the cache from the verb
set -u
if [ "${1:-}" = "--refresh" ]; then
    root="$2"; seat="$3"; c="/tmp/s4e/$seat/banner.cache"; mkdir -p "/tmp/s4e/$seat"; : > "$c.lock"
    timeout -k 5 600 bash "$root/harness/scripts/s4e_msg.sh" banner > "$c.tmp" 2>&1
    [ -s "$c.tmp" ] && mv -f "$c.tmp" "$c"
    rm -f "$c.lock" "$c.tmp"; exit 0
fi
root="${1:?root}"; seat="${2:?seat}"; c="/tmp/s4e/$seat/banner.cache"; mkdir -p "/tmp/s4e/$seat"
now=$(date +%s); load=$(cut -d' ' -f1 /proc/loadavg)
[ -f "$c.lock" ] && [ $(( now - $(stat -c %Y "$c.lock") )) -gt 900 ] && rm -f "$c.lock"
spawn() { setsid bash "$root/harness/scripts/s4e_banner_cached.sh" --refresh "$root" "$seat" < /dev/null > /dev/null 2>&1 & }
if [ -f "$c" ]; then
    age=$(( now - $(stat -c %Y "$c") )); out="$(cat "$c")"
    [ "$age" -gt 240 ] && [ ! -f "$c.lock" ] && spawn
    [ "$age" -gt 60 ] && out="$out
(banner cached ${age} s ago at load $load; a refresh is running)"
else
    out="$(timeout -k 5 100 bash "$root/harness/scripts/s4e_msg.sh" banner 2>&1)"
    if [ -n "$out" ]; then printf '%s' "$out" > "$c"; else out="banner: the verb printed nothing within 100 s at load $load; the first refresh runs in the background and the next turn shows it"; [ -f "$c.lock" ] || spawn; fi
fi
if [ -f "$root/.claude/banner_compact.py" ]; then cmp="$(printf '%s' "$out" | python3 -I "$root/.claude/banner_compact.py" 2>/dev/null)" && [ -n "$cmp" ] && out="$cmp"; fi
printf '%s' "$out" | python3 -c 'import json,sys; print(json.dumps(dict(systemMessage=sys.stdin.read())))'
