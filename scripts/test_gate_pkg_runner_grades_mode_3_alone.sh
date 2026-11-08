#!/usr/bin/env bash
"$(dirname "${BASH_SOURCE[0]}")/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)/scrip" || exit $?
# test_gate_pkg_runner_grades_mode_3_alone.sh -- A PACKAGE RUNNER GRADES MODE 3 ALONE UNDER S4E_MODES=m3 (CYCLE.STOP, Lon 2026-11-08 18:04Z: "We are
# focused on mode 3 ONLY!!!"; the cycle restarts when every pkg runner runs m3, rm CYCLE.STOP). THE READING IS THE RUN, NEVER THE TEXT: the gate runs one
# entry of the pkg row's runner (SUITE_RUNNERS.tsv column 4) with S4E_MODES=m3 and its progress rows in a scratch S4E_PROGRESS_DB, then counts the rows by
# their mode column, found by the header name "mode" (column 9 of results.tsv; column 5 of the single-entry road's 8-column table, which the
# runner names as db= or as "scratch table"). A runner whose text says m3,m4 in its score write is caught by the rows it writes, not by its text.
# The entry is the first whose part column reads core (PARTITION.tsv of the row's directory), else the first entry.
# EXIT: 0 m3 rows and no m4 row; 1 an m4 row written under S4E_MODES=m3; 2 refused (no key, no row, no runner, no partition, no entry, a run that wrote no m3 row).
# FAIL ONCE: logtalk reads rc 1 (its runner defaults MODES to m3,m4 and ignores S4E_MODES). PASS ONCE: unitests reads rc 0.
set -u
G=test_gate_pkg_runner_grades_mode_3_alone
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
refuse() { echo "⛔ REFUSE(2) [$G]: $*"; exit 2; }
KEY="${1:-}"
[ -n "$KEY" ] || refuse "usage: $G <pkg-row-key of SUITE_RUNNERS.tsv>"
LINE="$(awk -F'\t' -v k="$KEY" '!/^#/ && $1==k && $2=="pkg"' "$HERE/SUITE_RUNNERS.tsv" | head -1)"
[ -n "$LINE" ] || refuse "no pkg row $KEY in SUITE_RUNNERS.tsv"
RUNNER="$(printf '%s' "$LINE" | cut -f4)"; DIR="$ROOT/$(printf '%s' "$LINE" | cut -f5)"
set -- $RUNNER; SCRIPT="$1"; shift
[ -f "$HERE/$SCRIPT" ] || refuse "runner $SCRIPT is not a file beside the gate"
[ -f "$DIR/PARTITION.tsv" ] || refuse "no $DIR/PARTITION.tsv"
ENTRY="$(awk -F'\t' '/^#/{next} !h{for(i=1;i<=NF;i++){if($i=="entry")ie=i; if($i=="part")ip=i}; h=1; next} ie && $ip=="core"{print $ie; exit}' "$DIR/PARTITION.tsv")"
[ -n "$ENTRY" ] || ENTRY="$(awk -F'\t' '/^#/{next} !h{for(i=1;i<=NF;i++){if($i=="entry")ie=i}; h=1; next} ie{print $ie; exit}' "$DIR/PARTITION.tsv")"
[ -n "$ENTRY" ] || refuse "no entry listed in $DIR/PARTITION.tsv"
T="$(mktemp -d "${TMPDIR:-/tmp}/$G.XXXXXX")" || refuse "no scratch dir"
trap 'rm -rf "$T"' EXIT
( cd "$ROOT" && S4E_HOME="$ROOT" S4E_MODES=m3 S4E_BATCH=1 S4E_PROGRESS_DB="$T/results.tsv" S4E_CHUNK="entry:$ENTRY" S4E_ONE_RUNNER_OVERRIDE="$G: one entry, mode 3, scratch progress" timeout -k 5 900 bash "$HERE/util_run_slot.sh" bash "$HERE/$SCRIPT" "$@" ) > "$T/run.log" 2>&1 < /dev/null
RC=$?
DB="$(grep -oE '(^| )db=[^ ]+' "$T/run.log" | tail -1 | sed 's/^ *db=//')"
if [ -z "$DB" ]; then B="$(grep -o 'scratch table [^ )]*' "$T/run.log" | tail -1 | cut -c15-)"; if [ -n "$B" ] && [ -f "$B.min" ]; then DB="$B.min"; elif [ -n "$B" ]; then DB="$B"; fi; fi
[ -n "$DB" ] || DB="$T/results.tsv"
[ -f "$DB" ] || { echo "runner rc $RC; its last lines:"; tail -5 "$T/run.log"; refuse "$KEY wrote no scratch progress table ($DB): nothing to count"; }
case "$DB" in "$ROOT"/*|/home/resources/progress/*) refuse "the runner named a live progress table, $DB" ;; esac
M3="$(awk -F'\t' 'NR==1{for(i=1;i<=NF;i++) if($i=="mode") c=i; next} c && $c=="m3"{n++} END{print n+0}' "$DB")"
M4="$(awk -F'\t' 'NR==1{for(i=1;i<=NF;i++) if($i=="mode") c=i; next} c && $c=="m4"{n++} END{print n+0}' "$DB")"
rm -f "$DB" "${DB%.min}" "${DB%.min}.lock"
if [ "$M3" = 0 ]; then
    echo "runner rc $RC; its last lines:"; tail -5 "$T/run.log"
    refuse "$KEY wrote no mode-3 row for $ENTRY under S4E_MODES=m3: the runner graded nothing, so the count does not cover a population"
fi
echo "PKG_RUNNER_MODE3_BOARD key=$KEY entry=$ENTRY runner_rc=$RC m3_rows=$M3 m4_rows=$M4 (tree $(git -C "$HERE/.." rev-parse --short HEAD 2>/dev/null))"
[ "$M4" = 0 ] && { echo "GATE OK [$G]: $KEY grades mode 3 alone under S4E_MODES=m3"; exit 0; }
echo "GATE FAIL [$G]: $KEY wrote $M4 mode-4 row(s) under S4E_MODES=m3"; exit 1
