#!/usr/bin/env bash
# util_queue.sh -- THE QUEUE DAEMON'S STATUS AND PROBES (DESIGN-PLAN fleet-queue step 1 and 5, the cio 2026-11-05; skill fleet-bus section 8).
#   util_queue.sh status            the one status line (python3 util_queue.py status); rc 0 only with the client present and the binlog on
#   util_queue.sh tubes             one line per tube
#   util_queue.sh --probe-lease     step 5's probe: plants a job with a 2 s TTR, reserves it from a process that dies, shows it back in its tube,
#                                   the claim cleared and the ledger line written (built with step 5; refuses rc 2 until then)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "${1:-}" in
    status|tubes) exec python3 "$HERE/util_queue.py" "$1" ;;
    --probe-lease) echo "REFUSE(2) [util_queue]: --probe-lease is built by fleet-queue step 5 (the lease); not yet"; exit 2 ;;
    *) echo "usage: util_queue.sh status | tubes | --probe-lease"; exit 2 ;;
esac
