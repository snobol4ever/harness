#!/usr/bin/env bash
# s4e_banner_cached.sh <root> <seat> -- THE STOP HOOK'S BANNER, NEVER EMPTY (the cto, 2026-11-04, CTO-480; Lon in hq_prolog's window:
# "Ensure the banner display is automatic and does not depend on your feeble mind."). MEASURED: the banner verb took 51 s at load 26 in the
# cto's root and 28 s at load 20 in hq_prolog's; the old hook ran it inline under timeout 100 and printed an EMPTY systemMessage when the
# verb ran over, so Lon saw nothing for forty turns. THE SHAPE: print the seat's cached banner at once (/tmp/s4e/<seat>/banner.cache),
# refresh it in the background when it is older than 240 s (one refresh at a time, a lock older than 900 s is stale), and only the very
# first call with no cache runs the verb inline under the old budget. A cached banner older than 60 s says its age and the load.
#   s4e_banner_cached.sh <root> <seat>            the hook's call: prints the JSON {systemMessage} line
#   s4e_banner_cached.sh --refresh <root> <seat>  the background arm: rewrites the cache from the verb
# THE WAKE BY HOOK (box-scheduler step 10, CTO-496): the Stop hook's JSON on stdin goes to s4e_stop_gate.sh; while the seat holds unread mail or a row
# ASSIGNED or CLAIMED to it the gate answers {"decision":"block","reason":...}; since 2026-11-08 08:1x (Lon) that verdict is only shown in the banner, never returned.
# The seat is S4E_SEAT when the session sets it (every root's settings.local.json does), else the hook's argument.
set -u
# THE THREE HOME REPOS (Lon 2026-11-13 19:4x CST: "the complete re-write of the make and shell scripts and fleet system to use the THREE NEW repos in /home folder"; row
# harness-every-seats-hooks-and-claude-md-name-the-three-home-repos): every sibling this banner runs is read beside this script (HERE), never under <root>/harness, so a
# root that has dropped its harness keeps its banner; S4E_HOME is the root, exported for the bus verbs it runs.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "${1:-}" = "--refresh" ]; then
    root="$2"; seat="$3"; export S4E_HOME="${S4E_HOME:-$root}"; c="/tmp/s4e/$seat/banner.cache"; mkdir -p "/tmp/s4e/$seat"; : > "$c.lock"; start=$(date +%s)
    timeout -k 5 600 bash "$HERE/s4e_msg.sh" banner > "$c.tmp" 2>&1
    [ -s "$c.tmp" ] && mv -f "$c.tmp" "$c" && touch -d "@$start" "$c"   # the cache is dated by its SNAPSHOT, not by the write: a bus action after the start makes it stale
    rm -f "$c.lock" "$c.tmp"; exit 0
fi
root="${1:?root}"; seat="${S4E_SEAT:-${2:?seat}}"; export S4E_HOME="${S4E_HOME:-$root}"; c="/tmp/s4e/$seat/banner.cache"; mkdir -p "/tmp/s4e/$seat"
hookin=""; [ -t 0 ] || hookin="$(timeout 2 cat 2>/dev/null)"
now=$(date +%s); load=$(cut -d' ' -f1 /proc/loadavg)
[ -f "$c.lock" ] && [ $(( now - $(stat -c %Y "$c.lock") )) -gt 900 ] && rm -f "$c.lock"
spawn() { setsid bash "$HERE/s4e_banner_cached.sh" --refresh "$root" "$seat" < /dev/null > /dev/null 2>&1 & }
# THE STALE CACHE (Lon 2026-11-08 22:4x, in the cto's window: the banner said IN-PROGRESS on a row released a minute before; "something to do with caching?").
# MEASURED: the cache written 22:46:20 carried the BOX stamp 22:45:11, the verb's start, and the row was released at 22:45:4x; the hook served it
# until it was 240 s old and even then showed it once more while the refresh ran. THE RULE: every state-changing bus verb stamps
# /tmp/s4e/<seat>/bus.stamp at its exit (s4e_pid_release); a cache whose snapshot is older than the stamp is STALE and is refreshed inline
# under the 100 s budget before it is shown; only when the verb runs over is the stale text shown, marked STALE, with the refresh spawned.
stamp="/tmp/s4e/$seat/bus.stamp"; stale=0
[ -f "$c" ] && [ -f "$stamp" ] && [ "$(stat -c %Y "$stamp")" -ge "$(stat -c %Y "$c")" ] && stale=1
if [ "$stale" = 1 ] && [ ! -f "$c.lock" ]; then
    start=$now; fresh="$(timeout -k 5 100 bash "$HERE/s4e_msg.sh" banner 2>&1)"
    if [ -n "$fresh" ]; then printf '%s' "$fresh" > "$c"; touch -d "@$start" "$c"; stale=0; fi
fi
if [ -f "$c" ]; then
    age=$(( now - $(stat -c %Y "$c") )); out="$(cat "$c")"
    if [ "$stale" = 1 ]; then [ -f "$c.lock" ] || spawn; out="(STALE banner: a bus action followed this snapshot of ${age} s ago at load $load; the refresh ran over 100 s and now runs in the background)
$out"
    else [ "$age" -gt 240 ] && [ ! -f "$c.lock" ] && spawn; fi
    [ "$stale" = 0 ] && [ "$age" -gt 60 ] && out="(banner cached ${age} s ago at load $load; a refresh is running)
$out"   # first section, never the end (Lon 2026-11-06: "Remove the verbaiage \"(banner cahced ... blah)\" from the end of the banner. Put it in the first section instead.")
else
    out="$(timeout -k 5 100 bash "$HERE/s4e_msg.sh" banner 2>&1)"
    if [ -n "$out" ]; then printf '%s' "$out" > "$c"; else out="banner: the verb printed nothing within 100 s at load $load; the first refresh runs in the background and the next turn shows it"; [ -f "$c.lock" ] || spawn; fi
fi
if [ -f "$root/.claude/banner_compact.py" ]; then cmp="$(printf '%s' "$out" | python3 -I "$root/.claude/banner_compact.py" 2>/dev/null)" && [ -n "$cmp" ] && out="$cmp"; fi
# ONE WORD AND A HUGE ICON (Lon 2026-11-11 13:0x CST, in officer_04's window, verbatim: "I just want one word and a huge icon so I can see from a distance. All those words are NEVER read."):
# the hook shows the verdict word under a block icon and nothing else; the coo's suite grid (CIO-129) stays under it. The full text still goes to BOARD.md and the cache.
word="$(printf '%s\n' "$out" | grep -xE 'SUCCESS|IN-PROGRESS|DRAIN|STOP|FAILURE' | tail -1)"; grid="$(printf '%s\n' "$out" | grep -E '│|^[0-9]+ suites, ')"   # the grid and its closing summary line ("73 suites, 44 at 100%; ..."), which carries no │ (MEASURED 2026-11-13: the filter dropped it, Lon: "It does not show the summary at the end.")
# THE CYCLE LINE, THE BUG COUNTDOWN AND A FRESH GRID FOR A SEAT WHOSE BANNER CARRIES THE GRID (the grader 2026-11-13, row one-banner-script-seat-aware-run-from-each-seats-own-root; Lon, in the
# grader's window, verbatim: "do not reach into another's root folder and run a script." / "All seats should be running the SAME banner script with code that know WHO the HELL you ARE."): the
# coo's own Stop script printed these for the coo alone, so the fleet ran two banners. This one script prints them for every seat whose banner carries the grid (s4e_msg.sh banner chooses by
# seat: the coo and the grader), from util_cycle_countdown.py, and renders that grid fresh by util_suite_banner.py (MEASURED 2026-11-13: 0.46 s at load 53, while the cached grid is up to 240 s
# old and read a different SUITES.tsv than the fresh one). Each part is bounded; the countdown's last good render waits in /tmp/s4e/<seat>/countdown.cache for a read that runs over.
extra=""
if [ -n "$grid" ]; then
    gf="$(timeout -k 2 10 python3 -I "$HERE/util_suite_banner.py" < /dev/null 2>/dev/null | grep -E '│|^[0-9]+ suites, ')"; [ -n "$gf" ] && grid="$gf"
    cc="/tmp/s4e/$seat/countdown.cache"; extra="$(timeout -k 2 8 python3 -I "$HERE/util_cycle_countdown.py" < /dev/null 2>/dev/null)"
    if [ -n "$extra" ]; then printf '%s\n' "$extra" > "$cc"
    elif [ -s "$cc" ]; then extra="$(cat "$cc")
(the cycle line and the countdown above were rendered at $(date -r "$cc" +%H:%M); the live read did not finish in 8 s)"; fi
fi
# COLOUR AND A FIRST NEW LINE (Lon 2026-11-11 13:1x CST, in officer_04's window, verbatim: "Notice the Stop says: forgot the new line and the color is gray not green."): the client prints hook text
# gray after "Stop says:", so the icon is drawn in coloured emoji squares, which keep their colour, and it starts on its own line. Each "#" is a square, each "." two spaces (an emoji is two columns).
case "$word" in
  SUCCESS)     ic='✅'; sq='🟩'; pat='......#
.....#.
#...#..
.#.#...
..#....' ;;
  IN-PROGRESS) ic='⏳'; sq='🟨'; pat='#####
.###.
..#..
.###.
#####' ;;
  DRAIN)       ic='📬'; sq='🟦'; pat='..#..
..#..
..#..
.....
..#..' ;;
  *)           ic='⛔'; sq='🟥'; [ -n "$word" ] || word="NO VERDICT"; pat='#...#
.#.#.
..#..
.#.#.
#...#' ;;
esac
art="$(printf '%s\n' "$pat" | sed "s/#/$sq/g; s/\./  /g")"
out="
$art

$ic  $word"; [ -n "$extra" ] && out="$out
$extra"; [ -n "$grid" ] && out="$out
$grid"
# THE ROWS THE CYCLE COULD NOT WRITE ARE NAMED UNDER THE GRID (the grader 2026-11-12, s4e_cycle.sh record_row): a row the score writer refused keeps
# its old reading, so the grid alone looks current while it is not; one line a refusal class names its held rows (the grader 2026-11-13, Lon: "You banner ends with </persisted-output> and isUSELESS!" MEASURED: the Stop message was 10,146 characters, over Claude Code's 10,000 for a hook message, and 24 held rows at one 180-character line each were 4,300 of them; CYCLE.refused keeps each refusal in full).
_held="${S4E_CYCLE_REFUSED:-/home/resources/progress/CYCLE.refused}"
if [ -n "$grid" ] && [ -s "$_held" ]; then out="$out
⛔ SUITE ROWS HELD ($(grep -c . "$_held")): the grid shows their older reading; each refusal in full is $_held
$(awk -F'\t' '{ r = $3; c = (r ~ /denominator moves/) ? "denominator moved, no stamp" : (r ~ /no suite (table|key)/) ? "no banner row" : (r ~ /have no reading/) ? "entries unread" : "other"; n[c]++; k[c] = k[c] " " $1 } END { for (c in n) printf "   %s (%d):%s\n", c, n[c], k[c] }' "$_held" | sort)"; fi
gate="{}"; g="$HERE/s4e_stop_gate.sh"
[ -f "$g" ] && gate="$(printf '%s' "$hookin" | timeout 20 bash "$g" "$root" "$seat" --json 2>/dev/null)"
printf '%s' "$out" | G="$gate" python3 -c 'import json,os,sys
m=sys.stdin.read()
try: g=json.loads(os.environ.get("G") or "{}")
except Exception: g={}
# NO STOP IS EVER HELD (Lon 2026-11-08 08:1x CST, in the officer_01 window, verbatim: "I NEVER want to see \"Stop hook error\" ever again." /
# "Whoops, you just displayed \"Stop hook error\". I am about to whack you."): Claude Code labels every {"decision":"block"} at a Stop as a
# "Stop hook blocking error", so the verdict of the gate is never passed on; its reason is shown in the banner and the seat stops. A seat is woken
# for its work by a message, never by a held stop.
print(json.dumps({"systemMessage": m}))'
