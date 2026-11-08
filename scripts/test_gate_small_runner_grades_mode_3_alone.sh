#!/usr/bin/env bash
"$(dirname "${BASH_SOURCE[0]}")/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)/scrip" || exit $?
# test_gate_small_runner_grades_mode_3_alone.sh KEY ENTRY -- A SMALL OR PKG SUITE RUNNER GRADES MODE 3 ALONE UNDER S4E_MODES=m3 (Lon 2026-11-08 13:0x: "get all
# those test suite runners to mode 3 and using --harness feature."; THING 1 families A and B, officer_02). The sibling of test_gate_pkg_runner_grades_mode_3_alone.sh
# (officer_08 and officer_05), which reads a pkg row's PARTITION.tsv for its entry: a small runner (the bench runners, gnu, jcon) has none, so the entry is
# the second argument, a name the runner admits under S4E_CHUNK=entry:ENTRY. THE READING IS THE RUN: the runner runs that entry with S4E_MODES=m3 and its
# progress rows in a scratch S4E_PROGRESS_DB, and the rows are counted by their mode column. Built because util_runner_road_census.py reads only a literal
# m3,m4, and a runner that loops "for m in m3 m4" with no literal reads s4e there (MEASURED: test_raku_bench_suite.sh lines 132 and 140,
# test_snocone_bench_suite.sh line 104, test_snobol4_bench_suite.sh line 57 MODES="m3 m4").
# EXIT: 0 m3 rows and no m4 row; 1 an m4 row written under S4E_MODES=m3; 2 refused (no key, a port row, no runner, a run that wrote no m3 row).
set -u
G=test_gate_small_runner_grades_mode_3_alone
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
refuse() { echo "⛔ REFUSE(2) [$G]: $*"; exit 2; }
KEY="${1:-}"; ENTRY="${2:-}"
[ -n "$KEY" ] && [ -n "$ENTRY" ] || refuse "usage: $G <key of SUITE_RUNNERS.tsv> <entry the runner admits>"
LINE="$(awk -F'\t' -v k="$KEY" '!/^#/ && $1==k && ($2=="small" || $2=="pkg")' "$HERE/SUITE_RUNNERS.tsv" | head -1)"
[ -n "$LINE" ] || refuse "no small or pkg row $KEY in SUITE_RUNNERS.tsv"
RUNNER="$(printf '%s' "$LINE" | cut -f4)"
set -- $RUNNER; SCRIPT="$1"; shift
[ -f "$HERE/$SCRIPT" ] || refuse "runner $SCRIPT is not a file beside the gate"
T="$(mktemp -d "${TMPDIR:-/tmp}/$G.XXXXXX")" || refuse "no scratch dir"
trap 'rm -rf "${T:?}"' EXIT
( cd "$ROOT" && S4E_HOME="$ROOT" S4E_MODES=m3 S4E_BATCH=1 S4E_PROGRESS_DB="$T/results.tsv" S4E_CHUNK="entry:$ENTRY" S4E_ONE_RUNNER_OVERRIDE="$G: one entry, mode 3, scratch progress" timeout -k 5 1800 bash "$HERE/util_run_slot.sh" bash "$HERE/$SCRIPT" "$@" ) > "$T/run.log" 2>&1 < /dev/null
RC=$?
DB="$(grep -oE '(^| )db=[^ ]+' "$T/run.log" | tail -1 | sed 's/^ *db=//')"
if [ -z "$DB" ]; then B="$(grep -o 'scratch table [^ )]*' "$T/run.log" | tail -1 | cut -c15-)"; if [ -n "$B" ] && [ -f "$B.min" ]; then DB="$B.min"; elif [ -n "$B" ]; then DB="$B"; fi; fi
[ -n "$DB" ] || DB="$T/results.tsv"
[ -f "$DB" ] || { echo "runner rc $RC; its last lines:"; tail -5 "$T/run.log"; refuse "$KEY wrote no scratch progress table ($DB): nothing to count"; }
case "$DB" in "$ROOT"/*|/home/resources/progress/*) refuse "the runner named a live progress table, $DB" ;; esac
M3="$(awk -F'\t' 'NR==1{for(i=1;i<=NF;i++) if($i=="mode") c=i; next} c && $c=="m3"{n++} END{print n+0}' "$DB")"
M4="$(awk -F'\t' 'NR==1{for(i=1;i<=NF;i++) if($i=="mode") c=i; next} c && $c=="m4"{n++} END{print n+0}' "$DB")"
if [ "$M3" = 0 ]; then
    echo "runner rc $RC; its last lines:"; tail -5 "$T/run.log"
    refuse "$KEY wrote no mode-3 row for $ENTRY under S4E_MODES=m3: the runner graded nothing, so the count does not cover a population"
fi
echo "SMALL_RUNNER_MODE3_BOARD key=$KEY entry=$ENTRY runner_rc=$RC m3_rows=$M3 m4_rows=$M4 (tree $(git -C "$HERE/.." rev-parse --short HEAD 2>/dev/null))"
[ "$M4" = 0 ] && { echo "GATE OK [$G]: $KEY grades mode 3 alone under S4E_MODES=m3"; exit 0; }
echo "GATE FAIL [$G]: $KEY wrote $M4 mode-4 row(s) under S4E_MODES=m3"; exit 1
