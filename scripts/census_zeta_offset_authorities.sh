#!/usr/bin/env bash
# census_zeta_offset_authorities.sh — ζ-ONE U-0 (s132; Lon in-chat: "two disagreeing authorities on
# calculating RSP offsets and RBP offsets... make it ONE — one function, one data structure, one pass").
# Counts every RSP/RBP offset-spelling regime in emitter+templates so the migration onto the ONE
# resolver is a measured ratchet, not a vibe.  Advisory by default (always exit 0).
# --strict: exit 1 if any file listed in ../harness/scripts/zone_migrated.list still contains raw [rsp/[rbp
# literals (list is empty at U-0; U-1 populates it as files move onto the resolver).
# Ratchet direction: raw counts -> 0, migrated list -> every file in the top-files table.
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
n() { grep -rn "$1" src/templates src/emitter --include='*.cpp' --include='*.h' 2>/dev/null | wc -l; }
printf '== ζ-ONE offset-authority census ==\n'
printf '%-34s %6s\n' "regime / spelling" "sites"
printf '%-34s %6d\n' "raw [rsp literals" "$(n '\[rsp')"
printf '%-34s %6d\n' "raw [rbp literals" "$(n '\[rbp')"
for p in 'FR(' 'FRQ(' 'LFC(' 'LFCQ(' 'x86_scratch_off' 'capture_frame_slot' 'arbno_frame_slot' 'frame_slot_scan' 'sn4_choice_rbp_off' 'blob_frame_bytes' 'zvo_' 'zd_'; do
    printf '%-34s %6d\n' "$p" "$(n "$p")"
done
printf '\n== top raw-literal files ==\n'
grep -rc '\[rsp\|\[rbp' src/templates src/emitter --include='*.cpp' --include='*.h' 2>/dev/null | awk -F: '$2>0' | sort -t: -k2 -rn | head -10
LIST=../harness/scripts/zone_migrated.list
if [ "${1:-}" = "--strict" ]; then
    bad=0
    if [ -f "$LIST" ]; then
        while IFS= read -r f; do
            case "$f" in ''|\#*) continue;; esac
            c=$(grep -c '\[rsp\|\[rbp' "$f" 2>/dev/null || true)
            [ "${c:-0}" -gt 0 ] && { echo "STRICT FAIL: $f carries $c raw spellings"; bad=1; }
        done < "$LIST"
    fi
    [ "$bad" -eq 0 ] && echo "STRICT OK: every migrated file clean"
    exit "$bad"
fi
exit 0
