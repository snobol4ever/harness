#!/usr/bin/env bash
# util_run_slot.sh <command> <args>... -- AN AD-HOC RUN TAKES ONE OF THE BOX'S RUN SLOTS (Lon 2026-10-30, in-chat to the ceo, verbatim: "let's get
# the machine here not to be overloaded currently." · "Yes, do try your suggestions to fix the load problems."; ceo CEO-2033). Measured at 09:4x
# CDT: load 27 on 16 cores while the box's pools sat nearly idle (1 of 8 compile slots, 2 of 8 run slots), because the heavy runs bypassed them:
# a seat's own before-and-after binaries, a second scrip run started by hand, a compile-all sweep. The harness takes a run slot for every child it
# starts (corpus_suite_harness.py:_run_slot, CEO-1894); this wrapper takes the SAME slot locks under /tmp/s4e-run-slots for a run a seat starts
# itself, so hand runs and harness runs share one pool of S4E_RUN_SLOTS (default 8). It waits when every slot is held (rescanning every slot twice a second, never queued on one: a serial script holding a slot for hours pinned a waiter 17 minutes, 10-30) and execs the command with
# the lock on fd 8 for the command's whole life (the kernel frees it when the process exits, so a killed run frees its slot). A run already under
# a harness slot (S4E_RUN_SLOT_HELD set) takes no second one.
#   bash ../harness/scripts/util_run_slot.sh ./scrip prog.sno < /dev/null
#   bash ../harness/scripts/util_run_slot.sh ./old.bin -d64m
[ "$#" -gt 0 ] || { echo "usage: util_run_slot.sh <command> <args>..." >&2; exit 2; }
[ -n "${S4E_RUN_SLOT_HELD:-}" ] && exec "$@"
N="${S4E_RUN_SLOTS:-8}"
D="${S4E_RUN_SLOT_DIR:-/tmp/s4e-run-slots}"
mkdir -p "$D" 2>/dev/null || exec "$@"
export S4E_RUN_SLOT_HELD=1
s4e_slot_note() { local f w; f="${S4E_SLOT_WAITS:-/home/resources/progress/SLOT_WAITS.tsv}"; w=$(awk -v a="$W0" -v b="$(date +%s.%N)" 'BEGIN{printf "%.1f", b-a}'); case "$w" in 0.*) return 0;; esac
  [ -s "$f" ] || printf '# at_utc\tseat\tkind\twait_s\tcmd  -- one line per slot wait of a second or more (ceo CEO-2078: the pools kept no record, so contention could not be measured)\n' > "$f" 2>/dev/null
  printf '%s\t%s\t%s\t%s\t%s\n' "$(date -u +%FT%TZ)" "${S4E_SEAT:-$(basename "${S4E_HOME:-$PWD}")}" "$1" "$w" "$(shift; printf %s "$*" | tr '\t\n' '  ' | cut -c1-80)" >> "$f" 2>/dev/null; return 0; }
W0=$(date +%s.%N)
while :; do
  i=0
  while [ "$i" -lt "$N" ]; do
    exec 8>>"$D/slot$i" || exec "$@"
    if flock -n 8; then s4e_slot_note run "$@"; exec "$@"; fi
    exec 8>&-
    i=$((i + 1))
  done
  sleep 0.5
done
