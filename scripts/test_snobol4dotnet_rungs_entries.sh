#!/usr/bin/env bash
# test_snobol4dotnet_rungs_entries.sh -- the witness of a snobol4dotnet rungs row: each named entry of the SNOBOL4 master
# ($S4E_CORPUS/tests/snobol4) is graded alone under S4E_ENGINE=dotnet, in mode 3, against the ref sbl -bf cut, by the cycle's own
# road (corpus_suite_harness.py run ... --partition entry:NAME), so it reads the master's two groups and the entry's declared sizes,
# compile switches, input and masks as the cycle does. Its readings go to a private store, never the shared one.
# (Moved here from snobol4dotnet's scripts/rungs_entries_equal_ref.sh, 2026-11-19, on Lon's word: the port's scripts live in harness.
# That text extracted entries from ALL.sno and ALL.ref, which the master no longer holds since its regrouping into ONE-LINERS and
# MULTI-LINERS, so it refused every entry.)
#
#   bash /home/harness/scripts/test_snobol4dotnet_rungs_entries.sh <entry>...   from anywhere; one PASS or RED line per entry
#
# The port is the clone S4E_DOTNET_ROOT names (default /home/claude_dotnet, the dotnet seat's root), built in Release; a missing or
# stale build is refused by run_snobol4dotnet.sh --binaries, never rebuilt here.
# Exit: 0 every entry PASS, 1 an entry RED, 2 could not measure (no build, no master, an entry the harness refuses).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_paths.sh"
export S4E_ENGINE=dotnet S4E_DOTNET_ROOT="${S4E_DOTNET_ROOT:-/home/claude_dotnet}"
M="$S4E_CORPUS/tests/snobol4"
[ "$#" -gt 0 ] || { echo "usage: $0 <entry>..."; exit 2; }
[ -f "$M/ALL.csv" ] || { echo "REFUSE(2): no SNOBOL4 master at $M"; exit 2; }
bash "$HERE/run_snobol4dotnet.sh" --binaries --lang snobol4 > /dev/null || { echo "REFUSE(2): no current Release build of $S4E_DOTNET_ROOT (run_snobol4dotnet.sh --binaries)"; exit 2; }
t="$(mktemp -d)"; trap 'rm -rf "${t:?}"' EXIT
export S4E_PROGRESS_DB="${S4E_PROGRESS_DB:-$t/store.tsv}"
bad=0
for e in "$@"; do
    timeout -k 5 600 python3 "$HERE/corpus_suite_harness.py" run "$M/ALL.sno" "$M/ALL.ref" --lang snobol4 --modes m3 --partition "entry:$e" \
        < /dev/null > "$t/$e.log" 2>&1
    rc=$?
    board="$(grep -m1 '^SUITE_BOARD ' "$t/$e.log")"
    if [ "$rc" = 2 ] || [ -z "$board" ]; then echo "REFUSE(2): $e: the harness gave no board (rc $rc): $(tail -n 3 "$t/$e.log" | tr '\n' ' ')"; exit 2; fi
    n="$(printf '%s\n' "$board" | sed -n 's/.* m3_n=\([0-9][0-9]*\).*/\1/p')"
    p="$(printf '%s\n' "$board" | sed -n 's/.* m3_pass=\([0-9][0-9]*\).*/\1/p')"
    if [ "$n" = 1 ] && [ "$p" = 1 ]; then echo "PASS $e"; else echo "RED $e: ${board#SUITE_BOARD }"; bad=1; fi
done
exit "$bad"
