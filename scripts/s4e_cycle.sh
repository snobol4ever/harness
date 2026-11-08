#!/usr/bin/env bash
# s4e_cycle.sh -- THE TEST CYCLE: ONE PROCESS RUNS EVERY SUITE CELL IN ORDER, LAP AFTER LAP (Lon, in the cio's window, 2026-11-08 09:0x CST, verbatim:
# "write a process that runs the test suite and write a fucking monitor to start it when it crashed" / "Is it not called CRON?"). No queue, no tubes,
# no workers, no controller: this process and the cron line that restarts it (s4e_cycle_cron.sh).
#   bash s4e_cycle.sh            the cycle: a lap is sync, make, then every cell of every master or pkg row of SUITE_RUNNERS.tsv; then the next lap
#   bash s4e_cycle.sh --list     print the cells of one lap (suite kind lang runner cell) and their count; runs nothing
#   bash s4e_cycle.sh --one      run the next unfinished cell only, then exit (the proof that one cell runs end to end)
# THE ROOT is S4E_HOME, default /home/claude_grader (the grader's mirror; no seat edits it). THE LAUNCH of a cell is the grade worker's launch, unchanged:
# a master row runs corpus_suite_harness.py run <ALL.ext> <ALL.ref> --lang L --modes m3,m4 --partition <cell>; a pkg row runs S4E_CHUNK=<cell> bash <runner>;
# both under util_run_slot.sh, S4E_CLASS=grader, S4E_BATCH=1 (one scrip --harness per partition and mode, batch-grader step 5), under timeout -k 30 of the
# cell's declared budget (util_grade_job.py budget). After a master suite's last cell its suite row is rewritten (util_score_row.py from-progress).
# THE STATE is /home/resources/progress/CYCLE.state (lap, idx, total, suite, cell, status, since), one line a key, rewritten before and after every cell;
# CYCLE.log gets one line per cell (ts lap idx/total suite cell rc secs) and one per lap; CYCLE.pid is this process. A restart reads CYCLE.state and goes on
# at the cell after the last finished one; a cell found "running" at start killed the process, its count in CYCLE.crash rises, and at three it is skipped
# for good (named in CYCLE.skip, one line each) so no cell can hold the cycle forever.
set -u
S4E="${S4E_HOME:-/home/claude_grader}"
export S4E_HOME="$S4E" S4E_SEAT="${S4E_SEAT:-grader}" S4E_CLASS=grader S4E_BATCH="${S4E_BATCH:-1}" TMPDIR="/tmp/s4e/${S4E_SEAT:-grader}"
PROG=/home/resources/progress
STATE="$PROG/CYCLE.state"; LOG="$PROG/CYCLE.log"; PIDF="$PROG/CYCLE.pid"; CRASH="$PROG/CYCLE.crash"; SKIP="$PROG/CYCLE.skip"
RUNNERS="$S4E/harness/scripts/SUITE_RUNNERS.tsv"
mkdir -p "$TMPDIR/cycle" "$PROG" || exit 2
[ -f "$RUNNERS" ] || { echo "REFUSE(2) [cycle]: no $RUNNERS"; exit 2; }
MODE_ARG="${1:-}"
now() { date -u +%FT%TZ; }
log() { printf '%s %s\n' "$(now)" "$*" >> "$LOG"; }
state_get() { sed -n "s/^$1=//p" "$STATE" 2>/dev/null | head -1; }
state_put() {   # lap idx total suite cell status
    printf 'lap=%s\nidx=%s\ntotal=%s\nsuite=%s\ncell=%s\nstatus=%s\nsince=%s\npid=%s\n' "$1" "$2" "$3" "$4" "$5" "$6" "$(now)" "$$" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"; }
cells() {   # one line per cell: key kind lang runner cell; core first, then chunk:NN in order, per the row order of SUITE_RUNNERS.tsv
    awk -F'\t' -v S="$S4E" '
        !/^#/ && NF >= 5 && ($2 == "master" || $2 == "pkg") {
            row++; dir = ($2 == "master") ? S "/corpus/tests/" $3 : S "/" $5
            f = dir "/PARTITION.tsv"; ip = 0; delete seen
            while ((getline line < f) > 0) {
                if (line ~ /^#/) continue
                nc = split(line, c, "\t")
                if (!ip) { for (i = 1; i <= nc; i++) if (c[i] == "part") ip = i; continue }
                if (ip && c[ip] != "" && !(c[ip] in seen)) {
                    seen[c[ip]] = 1
                    if (c[ip] == "core") print row "\t0\t" $1 "\t" $2 "\t" $3 "\t" $4 "\tcore"
                    else if (c[ip] ~ /^chunk:/) print row "\t1\t" $1 "\t" $2 "\t" $3 "\t" $4 "\t" c[ip]
                }
            }
            close(f)
        }' "$RUNNERS" | sort -t "$(printf '\t')" -k1,1n -k2,2n -k7,7 | cut -f3-
}
budget() { python3 -I "$S4E/harness/scripts/util_grade_job.py" budget --suite "$1" --cell "$2" 2>/dev/null | sed -n 's/.* ttr_s=\([0-9]*\).*/\1/p' | head -1; }
container_key() { case "$1" in snobol4) echo sno-rungs;; icon) echo icn-rungs;; prolog) echo pl-rungs;; pascal) echo pas-rungs;; raku) echo raku-rungs;; snocone) echo snc-rungs;; rebus) echo reb-rungs;; esac; }
ext_of() { case "$1" in snobol4) echo sno;; icon) echo icn;; prolog) echo pl;; pascal) echo pas;; raku) echo raku;; rebus) echo reb;; snocone) echo sc;; esac; }
run_cell() {   # key kind lang runner cell -> rc; the grade worker's launch
    local key="$1" kind="$2" lang="$3" runner="$4" cell="$5" ttr alls rc t0 out
    ttr="$(budget "$key" "$cell")"; [ -n "$ttr" ] || ttr=3600
    out="$TMPDIR/cycle/$key.$cell.log"; t0=$(date +%s)
    if [ "$kind" = master ]; then
        alls="$S4E/corpus/tests/$lang/ALL.$(ext_of "$lang")"
        [ -f "$alls" ] || { log "REFUSED $key $cell: no container $alls"; return 2; }
        ( cd "$S4E" && timeout -k 30 "$ttr" bash harness/scripts/util_run_slot.sh python3 harness/scripts/corpus_suite_harness.py run "$alls" "${alls%/*}/ALL.ref" --lang "$lang" --modes m3,m4 --partition "$cell" ) > "$out" 2>&1 < /dev/null; rc=$?
    else
        set -- $runner
        [ -f "$S4E/harness/scripts/$1" ] || { log "REFUSED $key $cell: no runner $1"; return 2; }
        ( cd "$S4E" && S4E_CHUNK="$cell" timeout -k 30 "$ttr" bash harness/scripts/util_run_slot.sh bash "harness/scripts/$@" ) > "$out" 2>&1 < /dev/null; rc=$?
    fi
    echo "$rc $(( $(date +%s) - t0 ))"
}
record_suite() {   # lang -> the rungs suite row of that language, as the grade worker's record step writes it
    local k; k="$(container_key "$1")"; [ -n "$k" ] || return 0
    ( cd "$S4E" && timeout -k 30 900 python3 -I harness/scripts/util_score_row.py from-progress --suite "$k" ) >> "$TMPDIR/cycle/record.log" 2>&1 < /dev/null
}
lap_start() {
    local sy mk
    ( cd "$S4E" && bash harness/scripts/util_sync_root.sh ) >> "$TMPDIR/cycle/sync.log" 2>&1 < /dev/null; sy=$?
    ( cd "$S4E/SCRIP" && make -j8 ) >> "$TMPDIR/cycle/make.log" 2>&1 < /dev/null; mk=$?
    log "LAP $1 start sync_rc=$sy make_rc=$mk scrip=$(git -C "$S4E/SCRIP" rev-parse --short=9 HEAD 2>/dev/null) corpus=$(git -C "$S4E/corpus" rev-parse --short=9 HEAD 2>/dev/null)"
    [ "$mk" = 0 ] || { log "LAP $1 REFUSED: make rc $mk (see $TMPDIR/cycle/make.log); exit 1, cron starts the next try"; exit 1; }
}
if [ "$MODE_ARG" = --list ]; then cells; echo "CELLS $(cells | wc -l)"; exit 0; fi
if [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF" 2>/dev/null)" 2>/dev/null && [ "$(cat "$PIDF")" != "$$" ]; then echo "REFUSE(2) [cycle]: already running as pid $(cat "$PIDF")"; exit 2; fi
echo $$ > "$PIDF"
trap 'rm -f "$PIDF"' EXIT
lap="$(state_get lap)"; idx="$(state_get idx)"; st="$(state_get status)"; pc="$(state_get cell)"; ps="$(state_get suite)"
[ -n "$lap" ] || lap=0; [ -n "$idx" ] || idx=0
if [ "$st" = running ] && [ -n "$ps" ]; then
    n=$(( $(awk -F'\t' -v s="$ps" -v c="$pc" '$1 == s && $2 == c {print $3; exit}' "$CRASH" 2>/dev/null) + 1 ))
    { grep -v -P "^\Q$ps\E\t\Q$pc\E\t" "$CRASH" 2>/dev/null; printf '%s\t%s\t%s\n' "$ps" "$pc" "$n"; } > "$CRASH.tmp" && mv "$CRASH.tmp" "$CRASH"
    log "CRASH lap=$lap idx=$idx $ps $pc killed the cycle, count=$n"
    if [ "$n" -ge 3 ]; then printf '%s\t%s\t%s\tskipped after %s deaths\n' "$(now)" "$ps" "$pc" "$n" >> "$SKIP"; log "SKIP $ps $cell for good (three deaths)"; fi
    idx=$(( idx + 1 ))
fi
while :; do
    mapfile -t ALL < <(cells); total=${#ALL[@]}
    [ "$total" -gt 0 ] || { log "REFUSED: no cells (SUITE_RUNNERS.tsv or the partitions unreadable)"; exit 2; }
    if [ "$idx" -eq 0 ] || [ "$idx" -ge "$total" ]; then
        [ "$idx" -ge "$total" ] && [ "$lap" -gt 0 ] && log "LAP $lap done cells=$total"
        lap=$(( lap + 1 )); idx=0; lap_start "$lap"
    fi
    while [ "$idx" -lt "$total" ]; do
        IFS=$'\t' read -r key kind lang runner cell <<< "${ALL[$idx]}"
        if grep -q -P "\t\Q$key\E\t\Q$cell\E\t" "$SKIP" 2>/dev/null; then log "SKIPPED lap=$lap $((idx+1))/$total $key $cell"; idx=$(( idx + 1 )); continue; fi
        state_put "$lap" "$idx" "$total" "$key" "$cell" running
        read -r rc secs <<< "$(run_cell "$key" "$kind" "$lang" "$runner" "$cell")"
        log "CELL lap=$lap $((idx+1))/$total $key $cell rc=$rc secs=$secs"
        next_key="$(printf '%s' "${ALL[$((idx+1))]:-}" | cut -f1)"
        [ "$kind" = master ] && [ "$next_key" != "$key" ] && record_suite "$lang"
        idx=$(( idx + 1 )); state_put "$lap" "$idx" "$total" "$key" "$cell" done
        [ "$MODE_ARG" = --one ] && { echo "ONE $key $cell rc=$rc secs=$secs"; exit 0; }
    done
done
