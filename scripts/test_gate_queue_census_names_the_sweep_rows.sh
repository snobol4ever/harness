#!/usr/bin/env bash
# test_gate_queue_census_names_the_sweep_rows.sh -- util_queue_visibility_census.py PRINTS THE TWO SWEEP LINES AND NAMES THE RIGHT ROWS ON
# EACH, AND `claim` BY NAME MARKS AN ASSIGNED ROW STARTED (the coo 2026-09-27, ceo CEO-1306, row instruments-the-queue-census-names-
# blocking-red-rows-past-their-two-hour-window-and-hq-lane-rows-unserved-past-24-hours-ceo-1306).
#
# Measured the morning it was ruled: three blocking-red rows of the 09-26 audit board sat FREE 23 hours while every make test read
# them as tolerated reds, and 227 rank-0/1 rows sat FREE in HQ lanes that their HQs would not serve while each held its one row. The
# census's two lines make that sweep a reading. A FIXTURE POSTOFFICE, the clock pinned (S4E_CENSUS_NOW), reds each line once:
#   B   BLOCKING-RED PAST WINDOW names exactly the two rows no owner started within two hours of the later of the tagged time and the
#       assignment -- one routed to the cfo by its topic, one to the ceo -- and none of: a row whose claim carries RUNNING, a row still
#       inside its window, a row whose owner wrote a LEDGER line after the assignment, a row its owner claimed from FREE, a DONE row
#   T   the same fixture read at an earlier clock, before either window closed, names none: the line reads time, not tags
#   H   HQ-LANE UNSERVED PAST 24H names exactly the FREE rank-0 row minted 60 hours ago whose HQ holds another claim -- not a rank-2 row,
#       not a row minted 12 hours ago, not a row whose HQ holds nothing
#   C   `s4e_msg.sh claim` by name on a row assigned to the claiming seat appends RUNNING once (so B can read the owner's start), and a
#       second claim appends nothing
# FAIL-ONCE, MEASURED 2026-09-27 (coo): origin 51b935685's census prints neither line (B, T and H red), and its `claim` on an assigned
# row writes nothing (C red).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G=queue_census_names_the_sweep_rows
unproven() { echo "GATE UNPROVEN(2) [$G]: $*"; exit 2; }
Q="$HERE/util_queue_visibility_census.py"; M="$HERE/s4e_msg.sh"
[ -f "$Q" ] && [ -f "$M" ] || unproven "the census or the bus is missing"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_qsweep.XXXXXX")" || unproven "mktemp failed"
trap 'rm -rf "$W"' EXIT
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ✅ $1: $2"; }
red() { FAIL=$((FAIL+1)); echo "  ⛔ $1 RED: $2"; }
mkdir -p "$W/claims" "$W/tasks" "$W/coo/inbox"; printf 'TENET\n' > "$W/MODE"; : > "$W/QUEUE.done.tsv"; : > "$W/QUEUE.tsv"
row()   { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$W/QUEUE.tsv"; }
baton() { printf '# TASK %s\nGOAL: fixture\nDONE-WHEN: true\nLINKS: %s\n## NEXT\n## LEDGER\n%s\n' "$1" "$2" "${3:-}" > "$W/tasks/$1.task.md"; }
claimf(){ local t="$1"; shift; printf '%s\n' "$@" > "$W/claims/$t.claim"; }
BR='minted via `mint` by ceo, 2026-09-27T07:00:00Z · BLOCKING-RED: fixture gates since 2026-09-27T08:00Z'
row 0 br-stuck-row hq_icon ASSIGNED:hq_icon;            baton br-stuck-row "$BR";        claimf br-stuck-row hq_icon 'ASSIGNED-BY ceo 2026-09-27T08:30:00Z'
row 0 br-gc-collector-row hq_icon ASSIGNED:hq_icon;     baton br-gc-collector-row "$BR"; claimf br-gc-collector-row hq_icon 'ASSIGNED-BY ceo 2026-09-27T08:00:00Z'
row 0 br-running-row hq_icon ASSIGNED:hq_icon;          baton br-running-row "$BR";      claimf br-running-row hq_icon 'ASSIGNED-BY ceo 2026-09-27T08:30:00Z' RUNNING
row 0 br-young-row hq_icon ASSIGNED:hq_icon
baton br-young-row 'minted via `mint` by ceo, 2026-09-27T11:00:00Z · BLOCKING-RED: fixture gates since 2026-09-27T11:00Z'; claimf br-young-row hq_icon 'ASSIGNED-BY ceo 2026-09-27T11:00:00Z'
row 0 br-ledger-row hq_icon ASSIGNED:hq_icon
baton br-ledger-row "$BR" '- [hq_icon·2026-09-27 04:1x CDT] started: the bisect is under way'; claimf br-ledger-row hq_icon 'ASSIGNED-BY ceo 2026-09-27T08:30:00Z'
row 0 br-claimed-row hq_icon CLAIMED:hq_icon;           baton br-claimed-row "$BR";      claimf br-claimed-row hq_icon
row 0 br-done-row hq_icon DONE;                         baton br-done-row "$BR";         claimf br-done-row hq_icon 'ASSIGNED-BY ceo 2026-09-27T08:30:00Z' DONE
OLD='minted via `mint` by ceo, 2026-09-25T00:00:00Z'
row 0 hq-old-free-row hq_raku FREE;     baton hq-old-free-row "$OLD"
row 2 hq-old-rank2-row hq_raku FREE;    baton hq-old-rank2-row "$OLD"
row 1 hq-young-free-row hq_raku FREE;   baton hq-young-free-row 'minted via `mint` by ceo, 2026-09-27T00:00:00Z'
row 0 hq-no-hold-row hq_pascal FREE;    baton hq-no-hold-row "$OLD"
row 1 hq-held-row hq_raku CLAIMED:hq_raku; baton hq-held-row "$OLD"; claimf hq-held-row hq_raku
names() { printf '%s\n' "$1" | awk -v h="$2" 'index($0, h) == 1 {f = 1; next} f && /^    [a-z]/ {print $1; next} f {exit}' | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//'; }

# ── B, T, H: the census over the fixture ────────────────────────────────────────────────────────────────────────────────────
o="$(S4E_PO="$W" S4E_CENSUS_NOW=2026-09-27T12:00:00Z python3 "$Q" 2>&1)"; r=$?
[ "$r" = 2 ] && unproven "the census refused the fixture: $(tail -2 <<<"$o" | tr '\n' ' ')"
b="$(names "$o" 'BLOCKING-RED PAST WINDOW:')"; bl="$(grep -m1 '^BLOCKING-RED PAST WINDOW:' <<<"$o")"
if grep -q '^BLOCKING-RED PAST WINDOW: 2 ' <<<"$bl" && [ "$b" = "br-gc-collector-row br-stuck-row" ] \
   && grep -qE '^    br-gc-collector-row .*-> cfo$' <<<"$o" && grep -qE '^    br-stuck-row .*-> ceo$' <<<"$o"; then
    ok B "names exactly [$b], routed cfo and ceo; the RUNNING, young, ledger-started, claimed-from-FREE and DONE rows stay off"
else
    red B "line [${bl:0:60}] names [$b] (want 2: br-gc-collector-row br-stuck-row, routed cfo and ceo)"
fi
o2="$(S4E_PO="$W" S4E_CENSUS_NOW=2026-09-27T09:00:00Z python3 "$Q" 2>&1)"
grep -q '^BLOCKING-RED PAST WINDOW: 0 ' <<<"$o2" && grep -q '^BLOCKING-RED PAST WINDOW: 2 ' <<<"$o" && ok T "at 09:00Z, before any window closed, the same fixture names none" \
    || red T "at 09:00Z: $(grep -m1 '^BLOCKING-RED' <<<"$o2" | cut -c1-60) (want 0)"
h="$(names "$o" 'HQ-LANE UNSERVED PAST 24H:')"
if grep -q '^HQ-LANE UNSERVED PAST 24H: 1 ' <<<"$o" && [ "$h" = "hq-old-free-row" ] && grep -qE '^    hq-old-free-row .*hq_raku holds hq-held-row\]' <<<"$o"; then
    ok H "names exactly [$h], its HQ holding hq-held-row; the rank-2, 12-hour and no-hold rows stay off"
else
    red H "line [$(grep -m1 '^HQ-LANE' <<<"$o" | cut -c1-50)] names [$h] (want 1: hq-old-free-row, hq_raku holds hq-held-row)"
fi

# ── C: `claim` by name marks an assigned row started, once ──────────────────────────────────────────────────────────────────
claimf c-assigned-row coo 'ASSIGNED-BY ceo 2026-09-27T08:30:00Z'; row 1 c-assigned-row coo ASSIGNED:coo; baton c-assigned-row 'minted via `mint` by ceo, 2026-09-27T08:00:00Z'
S4E_POST="$W" S4E_SEAT=coo bash "$M" claim c-assigned-row > "$W/c1.out" 2>&1
S4E_POST="$W" S4E_SEAT=coo bash "$M" claim c-assigned-row > "$W/c2.out" 2>&1
nr="$(grep -cx RUNNING "$W/claims/c-assigned-row.claim")"
[ "$nr" = 1 ] && grep -q 'already yours' "$W/c1.out" && ok C "claim by name on an assigned row appends RUNNING once, and a second claim appends nothing" \
    || red C "RUNNING lines after two claims: $nr (want 1); $(head -1 "$W/c1.out")"

echo "GATE $([ "$FAIL" = 0 ] && echo PASS || echo "FAIL($FAIL)") [$G]: $PASS of $((PASS + FAIL)) arms green (population: a 13-row fixture postoffice at a pinned clock, and the bus's claim verb)"
[ "$FAIL" = 0 ]
