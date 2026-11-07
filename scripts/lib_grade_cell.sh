#!/usr/bin/env bash
# lib_grade_cell.sh -- THE GRADE CELL'S RECORD OF THE SMOKE BAND AND OF THE NEW REDS (DESIGN-PLAN test-cycle step 4d, CTO-522; the cio 2026-11-07). Copied from the coo's
# tier 1 (its SMOKE.tsv writer) and loop8.sh's tell_part_reds (read-only in the coo's scratch). The lease in s4e_grade_worker.sh calls grade_cell_after once, after record().
#   grade_cell_after <suite> <tree> <band> <snapshot> <secs> [entry...]  a smoke-band cell writes its SMOKE.tsv line; every band tells its NEW REDs; prints GRADE_CELL_AFTER
#   write_smoke_line <tree> <green> <red> <pass> <fail> <secs> [red-entry...]   one SMOKE.tsv line, tier 1's shape (S4E_SMOKE_TSV overrides the file)
#   tell_new_reds <suite> <tree> <snapshot>   one telegram per NEW RED to its designer; prints how many were sent (S4E_RESULTS overrides the results table)
#   designer_of <suite>                        the seat whose TIERS.tsv role names the suite key, else the cto (S4E_TIERS overrides the table)
# A NEW RED is a program whose reading in <snapshot> (the results table copied before the launch) was PASS and whose reading now is not PASS (new_reds.py's v2 rule).
: "${S4E_HOME:?REFUSE(2) [lib_grade_cell]: S4E_HOME unset}"
RESULTS="${S4E_RESULTS:-/home/resources/progress/results.tsv}"
SMOKE_TSV="${S4E_SMOKE_TSV:-/home/resources/progress/SMOKE.tsv}"
TIERS="${S4E_TIERS:-$S4E_HOME/.github/TIERS.tsv}"
MSG="$S4E_HOME/harness/scripts/s4e_msg.sh"
designer_of() {
    local s
    s="$(awk -F'\t' -v k="$1" '$1 !~ /^#/ && $1 != "seat" { n = split($8, r, ","); for (i = 1; i <= n; i++) if (r[i] == k) { print $1; exit } }' "$TIERS")"
    echo "${s:-cto}"
}
write_smoke_line() {
    local corpus at
    corpus="$(git -C "$S4E_HOME/corpus" rev-parse --short HEAD 2>/dev/null || echo -)"; at="$(date -u +%FT%TZ)"
    [ -s "$SMOKE_TSV" ] || printf 'at_utc\tscrip\tcorpus\tgreen\tred\trefused\tpass\tfail\tsecs\treds\n' > "$SMOKE_TSV"
    printf '%s\t%s\t%s\t%s\t%s\t0\t%s\t%s\t%s\t%s\n' "$at" "$1" "$corpus" "$2" "$3" "$4" "$5" "$6" "${*:7}" >> "$SMOKE_TSV"
}
read -r -d '' NEWREDS_PY <<'PY'
import os, sys
suite, snap, res = sys.argv[1], sys.argv[2], sys.argv[3]
def load(p):
    d = {}
    if not os.path.isfile(p): return d
    for line in open(p, encoding="utf-8", errors="replace"):
        f = line.rstrip("\n").split("\t")
        if len(f) < 10 or f[5] != suite or f[8] not in ("m3", "m4"): continue
        k = (f[7], f[8])
        if k not in d or f[0] >= d[k][2]: d[k] = (f[9], f[1], f[0])
    return d
prev, now = load(snap), load(res)
for k in sorted(now):
    o = now[k][0]; p = prev.get(k)
    if o != "PASS" and p and p[0] == "PASS": print("%s\t%s\t%s\t%s" % (k[0], k[1], o, p[1]))
PY
read -r -d '' COUNTS_PY <<'PY'
import sys
res, suite, ents = sys.argv[1], sys.argv[2], sys.argv[3:]
last = {}
for line in open(res, encoding="utf-8", errors="replace"):
    f = line.rstrip("\n").split("\t")
    if len(f) < 10 or f[5] != suite or f[8] not in ("m3", "m4") or f[7] not in ents: continue
    if (f[7], f[8]) not in last or f[0] >= last[(f[7], f[8])][1]: last[(f[7], f[8])] = (f[9], f[0])
green, reds, pas, fail = 0, [], 0, 0
for e in ents:
    outs = [last.get((e, m), ("MISSING", ""))[0] for m in ("m3", "m4")]
    pas += outs.count("PASS"); fail += len(outs) - outs.count("PASS")
    if all(o == "PASS" for o in outs): green += 1
    else: reds.append(e)
print("%d %d %d %d %s" % (green, len(reds), pas, fail, " ".join(reds)))
PY
tell_new_reds() {
    local suite="$1" tree="$2" snap="$3" prog mode outc was designer range topic n=0 lines
    lines="$(python3 -c "$NEWREDS_PY" "$suite" "$snap" "$RESULTS")" || { echo 0; return 0; }
    while IFS=$'\t' read -r prog mode outc was; do
        [ -n "$prog" ] || continue
        designer="$(designer_of "$suite")"
        range="$(git -C "$S4E_HOME/SCRIP" rev-list --count "$was..$tree" 2>/dev/null || echo unknown)"
        topic="grade-new-red-$(printf '%s-%s-%s' "$suite" "$prog" "$mode" | tr -c 'a-zA-Z0-9-' '-' | cut -c1-40)-at-$(printf '%s' "$tree" | cut -c1-12)"
        { echo "coo grade NEW RED, $(date '+%F %H:%M %Z'): suite $suite program $prog reads $outc in $mode on SCRIP $tree where its previous reading was PASS on $was (RANGE since that tree: $range landing(s))."
          echo "Reproduce: bash harness/scripts/corpus_suite_harness.py run on the suite's container with --partition entry:$prog, or bash harness/scripts/test_feature_reps.sh <lang> <feature>. The cure or revert is the lane's."; } \
            | S4E_SEAT="${S4E_SEAT:-worker_20}" "$MSG" send "$designer" "$topic" --stdin > /dev/null 2>&1 && n=$((n + 1))
    done <<< "$lines"
    echo "$n"
}
grade_cell_after() {
    local suite="$1" tree="$2" band="$3" snap="$4" secs="$5" counts g r p f rest nt
    shift 5
    if [ "$band" = smoke ]; then
        counts="$(python3 -c "$COUNTS_PY" "$RESULTS" "$suite" "$@")"
        read -r g r p f rest <<< "$counts"
        write_smoke_line "$tree" "$g" "$r" "$p" "$f" "$secs" $rest
    fi
    nt="$(tell_new_reds "$suite" "$tree" "$snap")"
    echo "GRADE_CELL_AFTER band=$band new_reds_told=$nt"
}
if [ "${BASH_SOURCE[0]}" = "$0" ] && [ -n "${1:-}" ]; then "$@"; fi
