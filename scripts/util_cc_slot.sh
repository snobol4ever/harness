#!/usr/bin/env bash
# util_cc_slot.sh <compiler> <args>... -- ONE POOL OF COMPILE SLOTS FOR THE WHOLE BOX (Lon 2026-10-22, in-chat to the ceo, verbatim: "You are meant
# to fix the load not hurt it" · "don't flag things, fix things."; ceo CEO-1894). Every seat's `make -j8` used to start its own eight compilers, so
# eleven seats building at once ran far past the sixteen cores. The SCRIP Makefile runs every gcc and g++ through this wrapper: it takes one of
# S4E_CC_SLOTS (default 8, half the box) slot locks under /tmp/s4e-cc-slots, waiting when all are held, and execs the compiler with the lock
# held on fd 9 for the compiler's whole life (flock is released by the kernel when the process exits, so a killed compile frees its slot).
# A free slot is taken at once; with none free it rescans every slot twice a second and never queues on one (a holder that lives long would pin the waiter; coo 2026-10-30, CEO-2054). Not a gate and no record: it only bounds how many compilers run.
N="${S4E_CC_SLOTS:-8}"
D="${S4E_CC_SLOT_DIR:-/tmp/s4e-cc-slots}"
mkdir -p "$D" 2>/dev/null || exec "$@"
s4e_slot_note() { local f w; f="${S4E_SLOT_WAITS:-/home/resources/progress/SLOT_WAITS.tsv}"; w=$(awk -v a="$W0" -v b="$(date +%s.%N)" 'BEGIN{printf "%.1f", b-a}'); case "$w" in 0.*) return 0;; esac
  [ -s "$f" ] || printf '# at_utc\tseat\tkind\twait_s\tcmd  -- one line per slot wait of a second or more (ceo CEO-2078: the pools kept no record, so contention could not be measured)\n' > "$f" 2>/dev/null
  printf '%s\t%s\t%s\t%s\t%s\n' "$(date -u +%FT%TZ)" "${S4E_SEAT:-$(basename "${S4E_HOME:-$PWD}")}" "$1" "$w" "$(shift; printf %s "$*" | tr '\t\n' '  ' | cut -c1-80)" >> "$f" 2>/dev/null; return 0; }
W0=$(date +%s.%N)
while :; do
  i=0
  while [ "$i" -lt "$N" ]; do
    exec 9>>"$D/slot$i" || exec "$@"
    if flock -n 9; then s4e_slot_note cc "$@"; exec "$@"; fi
    exec 9>&-
    i=$((i + 1))
  done
  sleep 0.5
done
