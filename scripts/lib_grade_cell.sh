#!/usr/bin/env bash
# lib_grade_cell.sh -- THE LAP'S NEW REDS, TOLD ONCE A LAP, ONE TELEGRAM A DESIGNER (the cio 2026-11-10, ruling on the grading-tube row, CIO-82; Lon's law of CIO-8:
# nobody fails without knowing). The cycle (s4e_cycle.sh) copies the results table at a lap's start and calls tell_lap_new_reds at the lap's end with every suite
# key the lap graded. A NEW RED is a program whose latest reading in the copy was PASS and whose latest reading now is not PASS (m3 or m4). The SMOKE.tsv line
# of the retired grade worker is gone (nothing read it after 2026-11-08). Requests served from test_requests are not told: the asker reads its own answer.
#   tell_lap_new_reds <tree> <snapshot> <key>...   one telegram per designer naming the tree and, per suite, the count and the first twenty new reds; prints LAP_NEW_REDS
#   designer_of <key>                              the seat whose TIERS.tsv role names the suite key, else the cto (S4E_TIERS overrides the table)
# A telegram wakes nobody (CIO-51: the designer parks the red). S4E_RESULTS overrides the results table; S4E_POST the postoffice (a probe's scratch one).
: "${S4E_HOME:?REFUSE(2) [lib_grade_cell]: S4E_HOME unset}"
RESULTS="${S4E_RESULTS:-/home/resources/progress/results.tsv}"
TIERS="${S4E_TIERS:-$S4E_HOME/.github/TIERS.tsv}"
MSG="$S4E_HOME/harness/scripts/s4e_msg.sh"
designer_of() {
    local s
    s="$(awk -F'\t' -v k="$1" '$1 !~ /^#/ && $1 != "seat" { n = split($8, r, ","); for (i = 1; i <= n; i++) if (r[i] == k) { print $1; exit } }' "$TIERS")"
    echo "${s:-cto}"
}
read -r -d '' NEWREDS_PY <<'PY'
import os, sys
here, snap, res, keys = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]
sys.path.insert(0, here)
try:
    import util_suite_rows_vs_progress as a; name = {k: (a.dbname(k) or k) for k in keys}
except Exception: name = {k: k for k in keys}
want = {v: k for k, v in name.items()}
def load(p):
    d = {}
    if not os.path.isfile(p): return d
    for line in open(p, encoding="utf-8", errors="replace"):
        f = line.rstrip("\n").split("\t")
        if len(f) < 10 or f[5] not in want or f[8] not in ("m3", "m4"): continue
        k = (f[5], f[7], f[8])
        if k not in d or f[0] >= d[k][1]: d[k] = (f[9], f[0])
    return d
prev, now = load(snap), load(res)
for k in sorted(now):
    p = prev.get(k)
    if now[k][0] != "PASS" and p and p[0] == "PASS": print("%s\t%s\t%s\t%s" % (want[k[0]], k[1], k[2], now[k][0]))
PY
tell_lap_new_reds() {
    local tree="$1" snap="$2" lines key prog mode outc d sent=0 total=0; shift 2
    [ -f "$snap" ] || { echo "LAP_NEW_REDS refused=no-snapshot told=0 reds=0"; return 0; }
    lines="$(python3 -c "$NEWREDS_PY" "$S4E_HOME/harness/scripts" "$snap" "$RESULTS" "$@")" || { echo "LAP_NEW_REDS refused=reader told=0 reds=0"; return 0; }
    declare -A BODY=() CNT=() SHOWN=()
    while IFS=$'\t' read -r key prog mode outc; do
        [ -n "$key" ] || continue
        total=$((total + 1)); d="$(designer_of "$key")"; CNT[$d|$key]=$(( ${CNT[$d|$key]:-0} + 1 ))
        if [ "${SHOWN[$d|$key]:-0}" -lt 20 ]; then BODY[$d]="${BODY[$d]:-}  $key: $prog $mode reads $outc"$'\n'; SHOWN[$d|$key]=$(( ${SHOWN[$d|$key]:-0} + 1 )); fi
    done <<< "$lines"
    for d in "${!BODY[@]}"; do
        local sum=""; for k in "${!CNT[@]}"; do [ "${k%%|*}" = "$d" ] && sum="$sum ${k#*|}=${CNT[$k]}"; done
        { echo "THE LAP'S NEW REDS, SCRIP $tree ($(date '+%F %H:%M %Z')): programs that read PASS at the lap's start and do not now; per suite the count:$sum; the first twenty a suite:"
          printf '%s' "${BODY[$d]}"
          echo "A telegram wakes nobody (CIO-51): the designer parks each red as a row; reproduce with corpus_suite_harness.py run on the suite's container with --partition entry:NAME."; } \
            | S4E_SEAT="${S4E_SEAT:-grader}" bash "$MSG" send "$d" "lap-new-reds-$(printf '%s' "$tree" | cut -c1-12)" --stdin > /dev/null 2>&1 && sent=$((sent + 1))
    done
    echo "LAP_NEW_REDS told=$sent reds=$total"
}
if [ "${BASH_SOURCE[0]}" = "$0" ] && [ -n "${1:-}" ]; then "$@"; fi
