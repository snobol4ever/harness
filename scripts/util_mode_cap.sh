#!/usr/bin/env bash
# util_mode_cap.sh -- MODE capped to its current header, the history archived (DESIGN-PLAN box-scheduler step 14, CTO-496; Lon 2026-11-04: the
# records are the cio's). MODE line 1 is the mode, line 2 the business as dated blocks newest first (`# <date> <time> C?T: ... PRIOR: `), then the
# keyed lines (ROSTER: LANES: ORDER-OF-WORK: BOSSES: ON-CALL: CONCERNS: REPORT-TO-LON:) and their explanation; every seat's hook reads line 1 and
# the keyed lines at every prompt, so a 466 KB MODE (172 KB on line 2, 99 blocks; 2026-11-04) is paid for a thousand times a day. The cap: the
# first two lines together hold at most S4E_MODE_CAP bytes (8192); the blocks that do not fit, and the `# PRIOR LINE 2`, `# SUPERSEDED` and dated
# history comment lines below, move to MODE.archive (newest first, each stamped), never deleted. Nothing but history moves: line 1, every keyed
# line and every other comment line stay where they are.
#   util_mode_cap.sh --check      rc 0 when head -2 fits the cap and the archive exists, 1 when not (prints the bytes), 2 when MODE is unreadable
#   util_mode_cap.sh --apply      back MODE up (MODE.bak-<stamp>-<seat>-mode-cap), move the history, then --check; prints MODE-CAP ...
#   util_mode_cap.sh --preview    print what --apply would keep and move, writing nothing
#   util_mode_cap.sh --probe      prove it on a scratch copy: over the cap reads RED, --apply moves only history, keyed lines survive, --check GREEN
set -uo pipefail
PO="${S4E_POST:-/home/resources/postoffice}"; MODEF="${S4E_MODE_FILE:-$PO/MODE}"; CAP="${S4E_MODE_CAP:-8192}"; ME="${S4E_SEAT:-$(id -un)}"
check() { local n; [ -r "$MODEF" ] || { echo "REFUSE(2) [mode-cap]: cannot read $MODEF"; return 2; }
    n="$(head -2 "$MODEF" | wc -c)"
    if [ "$n" -le "$CAP" ] && [ -s "$MODEF.archive" ]; then echo "MODE-CAP ok head2_bytes=$n cap=$CAP archive=$(wc -l < "$MODEF.archive") lines"; return 0; fi
    echo "MODE-CAP RED head2_bytes=$n cap=$CAP archive=$([ -s "$MODEF.archive" ] && echo present || echo absent)"; return 1; }
split() {   # split <mode-file> <out-mode> <out-archive-additions>: python does the block arithmetic; bash would reflow the bytes
    python3 - "$@" "$CAP" "$ME" <<'PY'
import re, sys, datetime
src, out_mode, out_arch, cap, me = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), sys.argv[5]
lines = open(src, encoding='utf-8').read().split('\n')
stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
l1, l2, rest = lines[0], lines[1] if len(lines) > 1 else '', lines[2:]
blocks = [b for b in re.split(r'(?=(?<!\S)# 20\d\d-\d\d-\d\d \d\d:\d[0-9x] C[SD]T)', l2) if b != '']
keep, moved, used = [], [], len(l1.encode()) + 2
for b in blocks:
    if moved or used + len(b.encode()) > cap: moved.append(b)
    else: keep.append(b); used += len(b.encode())
if not keep and blocks: keep, moved = blocks[:1], blocks[1:]
hist = re.compile(r'^# (PRIOR LINE 2|SUPERSEDED|20\d\d-\d\d-\d\d )')
kept_rest = [x for x in rest if not hist.match(x)]
moved_rest = [x for x in rest if hist.match(x)]
new_l2 = ''.join(keep)
if moved: new_l2 = re.sub(r'\s*PRIOR:\s*$', '', new_l2) + f' PRIOR: {len(moved)} older block(s) in MODE.archive (mode-cap {stamp}).'
open(out_mode, 'w', encoding='utf-8').write('\n'.join([l1, new_l2] + kept_rest))
with open(out_arch, 'w', encoding='utf-8') as a:
    for b in moved: a.write(f'# ARCHIVED LINE-2 BLOCK (mode-cap {stamp} by {me}): {b.strip()}\n')
    for x in moved_rest: a.write(f'# ARCHIVED HISTORY LINE (mode-cap {stamp} by {me}): {x}\n')
print(f'blocks_kept={len(keep)} blocks_moved={len(moved)} history_lines_moved={len(moved_rest)} head2_bytes={len((l1 + chr(10) + new_l2 + chr(10)).encode())}')
PY
}
apply() { local t stamp r
    [ -r "$MODEF" ] && [ -w "$(dirname "$MODEF")" ] || { echo "REFUSE(2) [mode-cap]: cannot read $MODEF or write beside it"; return 2; }
    t="$(mktemp -d "${TMPDIR:-/tmp}/s4e_mode_cap.XXXXXX")" || { echo "REFUSE(2) [mode-cap]: mktemp failed"; return 2; }
    r="$(split "$MODEF" "$t/MODE" "$t/add")" || { rm -rf "$t"; echo "REFUSE(2) [mode-cap]: the split failed"; return 2; }
    if [ ! -s "$t/add" ]; then rm -rf "$t"; [ -s "$MODEF.archive" ] || : > "$MODEF.archive"; echo "MODE-CAP nothing to move ($r)"; check; return $?; fi
    for k in ROSTER LANES ORDER-OF-WORK BOSSES ON-CALL CONCERNS REPORT-TO-LON; do
        [ "$(grep -c "^$k:" "$MODEF")" = "$(grep -c "^$k:" "$t/MODE")" ] || { rm -rf "$t"; echo "REFUSE(2) [mode-cap]: the keyed line $k: would change; nothing written"; return 2; }
    done
    [ "$(head -1 "$MODEF")" = "$(head -1 "$t/MODE")" ] || { rm -rf "$t"; echo "REFUSE(2) [mode-cap]: line 1 would change; nothing written"; return 2; }
    stamp="$(date -u +%Y%m%d-%H%M%S)"; cp -p "$MODEF" "$MODEF.bak-$stamp-$ME-mode-cap" || { rm -rf "$t"; echo "REFUSE(2) [mode-cap]: no backup, nothing written"; return 2; }
    { cat "$t/add"; [ ! -f "$MODEF.archive" ] || cat "$MODEF.archive"; } > "$t/archive" && mv "$t/archive" "$MODEF.archive" && mv "$t/MODE" "$MODEF" \
        || { echo "REFUSE(2) [mode-cap]: the move failed; MODE.bak-$stamp-$ME-mode-cap holds the original"; rm -rf "$t"; return 2; }
    rm -rf "$t"; echo "MODE-CAP applied $r backup=$MODEF.bak-$stamp-$ME-mode-cap"; check; }
probe() { local t o why="" k
    t="$(mktemp -d "${TMPDIR:-/tmp}/s4e_mode_cap_probe.XXXXXX")" || { echo "REFUSE(2) [mode-cap --probe]: mktemp failed"; exit 2; }
    trap 'rm -rf "$t"' EXIT
    { echo TENET; for i in $(seq 1 12); do printf '# 2026-11-%02d 10:0x CST: block %s %s PRIOR: ' "$i" "$i" "$(head -c 900 /dev/zero | tr '\0' x)"; done; echo
      echo '# PRIOR LINE 2 (old): history'; echo 'ROSTER: cio coo'; echo '# ROSTER is MACHINE-READ'; echo 'BOSSES: cio coo cto'; echo '# 2026-09-05 09:32 CDT cto: MODE QUARTET'; } > "$t/MODE"
    run() { S4E_MODE_FILE="$t/MODE" S4E_SEAT="${ME}" bash "${BASH_SOURCE[0]}" "$@" 2>&1; }
    o="$(run --check)"; [ $? = 1 ] && printf '%s\n' "$o" | grep -q '^MODE-CAP RED' || why="$why over the cap did not read RED [$o];"
    o="$(run --apply)"; [ $? = 0 ] || why="$why --apply did not end GREEN [$o];"
    [ "$(head -2 "$t/MODE" | wc -c)" -le "$CAP" ] || why="$why head -2 still over the cap;"
    [ "$(head -1 "$t/MODE")" = TENET ] || why="$why line 1 changed;"
    for k in 'ROSTER: cio coo' 'BOSSES: cio coo cto' '# ROSTER is MACHINE-READ'; do grep -qxF "$k" "$t/MODE" || why="$why lost line [$k];"; done
    grep -q '# 2026-11-01 10:0x CST: block 1 ' "$t/MODE" || why="$why the newest block was not kept;"
    grep -q 'block 12 ' "$t/MODE" && why="$why the oldest block was not moved;"
    grep -q 'ARCHIVED LINE-2 BLOCK .*block 12 ' "$t/MODE.archive" || why="$why the oldest block is not in the archive;"
    grep -q 'ARCHIVED HISTORY LINE .*# PRIOR LINE 2 (old)' "$t/MODE.archive" && grep -q 'ARCHIVED HISTORY LINE .*MODE QUARTET' "$t/MODE.archive" || why="$why history lines not archived;"
    grep -q '^# PRIOR LINE 2' "$t/MODE" && why="$why a history line stayed in MODE;"
    ls "$t"/MODE.bak-*-mode-cap > /dev/null 2>&1 || why="$why no backup;"
    o="$(run --apply)"; printf '%s\n' "$o" | grep -q 'nothing to move' || why="$why a second apply moved something [$o];"
    [ -z "$why" ] && { echo "MODE-CAP probe ok cap=$CAP (12 blocks over the cap read RED; --apply kept the newest blocks under the cap, moved the rest and the" \
        "history lines to MODE.archive with a backup, kept line 1 and every keyed line; a second apply moved nothing)"; exit 0; }
    echo "MODE-CAP PROBE RED:$why"; exit 1; }
case "${1:-}" in
    --check) check; exit $? ;;
    --apply) apply; exit $? ;;
    --preview) t="$(mktemp -d)"; split "$MODEF" "$t/MODE" "$t/add"; echo "--- would keep (head -2 bytes: $(head -2 "$t/MODE" | wc -c)):"; head -2 "$t/MODE" | cut -c1-160
        echo "--- would move $(wc -l < "$t/add") line(s) to MODE.archive:"; cut -c1-120 "$t/add" | head -5; rm -rf "$t"; exit 0 ;;
    --probe) probe ;;
    *) echo "usage: util_mode_cap.sh --check | --apply | --preview | --probe (box-scheduler step 14: MODE head -2 <= ${CAP} bytes, history in MODE.archive)" >&2; exit 2 ;;
esac
