#!/usr/bin/env bash
# s4e_probe_cycle_tells_lap_new_reds.sh -- the criterion of the cycle's lap-end new-red telling (the cio 2026-11-10 on the grading-tube row, CIO-82): a planted
# lap copy where one program reads PASS and a results table where it reads FAIL, the lap-end step (lib_grade_cell.sh tell_lap_new_reds) run with the postoffice
# overridden to a scratch one: exactly ONE telegram, naming that program, in the designer's scratch inbox; planted with no difference: NONE. The live postoffice
# and the live results table are never read or written. One line PROBE_LAP_NEW_REDS ... ok=1 (rc 0) or ok=0 (rc 1); REFUSE(2) when it cannot measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
w="$(mktemp -d "/tmp/s4e/${S4E_SEAT:-probe}-lapreds.XXXXXX" 2>/dev/null || mktemp -d)" || { echo "REFUSE(2) [lap new reds]: mktemp failed"; exit 2; }
trap 'rm -rf "$w"' EXIT
mkdir -p "$w/po/claims" "$w/po/tasks" "$w/po/officer_97/inbox" "$w/po/grader/inbox"
{ head -1 /home/resources/postoffice/MODE 2>/dev/null || echo TENET; echo "# probe"; echo "ROSTER: officer_97 grader"; } > "$w/po/MODE"
[ -f /home/resources/postoffice/PROTOCOL-VERSION ] && cp /home/resources/postoffice/PROTOCOL-VERSION "$w/po/PROTOCOL-VERSION"
printf 'seat\tname\troot\tmodel\teffort\tcolor\ttier\trole\nofficer_97\tPO97\t/tmp\tclaude-opus-5-5\txhigh\tblue\t2\tprobe-suite\n' > "$w/TIERS.tsv"
row() { printf '%s\tgrader\t-\t-\t-\tprobe-suite\t-\t%s\tm3\t%s\n' "$1" "$2" "$3"; }   # ts seat . . . suite . program mode outcome
{ row 2026-11-10T00:00:00Z probe_prog_a PASS; row 2026-11-10T00:00:00Z probe_prog_b PASS; } > "$w/snap.tsv"
{ cat "$w/snap.tsv"; row 2026-11-10T01:00:00Z probe_prog_a FAIL; row 2026-11-10T01:00:00Z probe_prog_b PASS; } > "$w/results.tsv"
run() { env S4E_HOME="$S4E" S4E_POST="$w/po" S4E_TIERS="$w/TIERS.tsv" S4E_RESULTS="$1" S4E_SEAT=grader S4E_NO_BANNER=1 S4E_LAND_IGNORE_MAIL=probe \
        bash -c '. "$S4E_HOME/harness/scripts/lib_grade_cell.sh"; tell_lap_new_reds probe000tree "$0" probe-suite' "$w/snap.tsv" 2>&1; }
o1="$(run "$w/results.tsv")"; n1="$(ls "$w/po/officer_97/inbox" 2>/dev/null | wc -l)"
named="$(cat "$w/po/officer_97/inbox"/* 2>/dev/null | grep -c 'probe_prog_a m3 reads FAIL')"; wrong="$(cat "$w/po/officer_97/inbox"/* 2>/dev/null | grep -c 'probe_prog_b')"
rm -f "$w/po/officer_97/inbox"/*
o2="$(run "$w/snap.tsv")"; n2="$(ls "$w/po/officer_97/inbox" 2>/dev/null | wc -l)"
printf '%s' "$o1" | grep -q '^LAP_NEW_REDS ' || { echo "REFUSE(2) [lap new reds]: the lap-end step printed no LAP_NEW_REDS line: $(printf '%s' "$o1" | head -c 200)"; exit 2; }
ok=0; [ "$n1" = 1 ] && [ "$named" = 1 ] && [ "$wrong" = 0 ] && [ "$n2" = 0 ] && ok=1
echo "PROBE_LAP_NEW_REDS planted_difference_telegrams=$n1 names_the_program=$named names_a_green=$wrong no_difference_telegrams=$n2 ok=$ok"
[ "$ok" = 1 ]
