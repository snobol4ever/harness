#!/usr/bin/env bash
# s4e_cycle.sh -- THE TEST CYCLE: ONE PROCESS RUNS EVERY SUITE CELL IN ORDER, LAP AFTER LAP (Lon, in the cio's window, 2026-11-08 09:0x CST, verbatim:
# "write a process that runs the test suite and write a fucking monitor to start it when it crashed" / "Is it not called CRON?"). No queue, no tubes,
# no workers, no controller: this process and the cron line that restarts it (s4e_cycle_cron.sh).
#   bash s4e_cycle.sh            the cycle: a lap is sync, make, then every cell of every master or pkg row of SUITE_RUNNERS.tsv, S4E_CYCLE_WIDTH (4) cells at once; then the next lap
#   bash s4e_cycle.sh --list     print the cells of one lap (suite kind lang dir cell) and their count; runs nothing
#   bash s4e_cycle.sh --one      run the next unfinished cell only, then exit (the proof that one cell runs end to end)
#   S4E_CYCLE_TMP names a scratch TMPDIR for a probe (default /tmp/s4e/grader, the live cycle's cell logs; a probe that leaves it unset overwrites them)
#   bash s4e_cycle.sh --next     do the restart accounting (CYCLE.crash, CYCLE.skip) and print NEXT lap=L idx=I cell=KEY CELL, the cell a restart runs first; runs no cell (S4E_CYCLE_PROG names a scratch progress dir for a probe)
# THE ROOT is S4E_HOME, default /home/claude_grader (the grader's mirror; no seat edits it). THE LAUNCH of a cell is the grade worker's launch, unchanged:
# EVERY row, master or pkg, runs ONE launch (Lon 2026-11-08 23:0x: "ONE UNIFIED test suite system"): corpus_suite_harness.py run <dir>/ALL.<ext> <dir>/ALL.ref --lang L --modes $S4E_MODES --partition <cell>, dir the master's corpus/tests/<lang> or the pkg row's column 5; the package runner scripts are deleted; a row with no container refuses rc 2 by name;
# both under util_run_slot.sh, S4E_CLASS=grader, S4E_BATCH=1 (one scrip --harness per partition and mode, batch-grader step 5), S4E_MODES default m3 (Lon 2026-11-08 10:2x: "We will test mode 3 only until further notice"), under timeout -k 30 of the
# cell's declared budget (util_grade_job.py budget). After a master suite's or a pkg row's last cell its suite row is rewritten (util_score_row.py from-progress, in S4E_MODES).
# THE STATE is /home/resources/progress/CYCLE.state (lap, idx, total, suite, cell, status, since), one line a key, rewritten before and after every cell;
# CYCLE.log gets one line per cell (ts lap idx/total suite cell rc secs) and one per lap; CYCLE.pid is this process. A restart reads CYCLE.state and goes on
# at the cell after the last finished one; a cell found "running" at start killed the process, its count in CYCLE.crash rises, and at three it is skipped
# for good (named in CYCLE.skip, one line each) so no cell can hold the cycle forever.
set -u
S4E="${S4E_HOME:-/home/claude_grader}"
export S4E_HOME="$S4E" S4E_SEAT=grader S4E_CLASS=grader S4E_BATCH="${S4E_BATCH:-1}" S4E_MODES="${S4E_MODES:-m3}" TMPDIR="${S4E_CYCLE_TMP:-/tmp/s4e/grader}"   # S4E_MODES exported: the cells and the suite row (util_score_row.py from-progress) read the same modes, m3 alone under Lon's mode-3-only order
PROG="${S4E_CYCLE_PROG:-/home/resources/progress}"
STATE="$PROG/CYCLE.state"; LOG="$PROG/CYCLE.log"; PIDF="$PROG/CYCLE.pid"; CRASH="$PROG/CYCLE.crash"; SKIP="$PROG/CYCLE.skip"
RUNNERS="$S4E/harness/scripts/SUITE_RUNNERS.tsv"
mkdir -p "$TMPDIR/cycle" "$PROG" || exit 2
[ -f "$RUNNERS" ] || { echo "REFUSE(2) [cycle]: no $RUNNERS"; exit 2; }
MODE_ARG="${1:-}"
SELF="$(readlink -f "${BASH_SOURCE[0]}")"; SELF_SUM="$(md5sum < "$SELF" 2>/dev/null)"
now() { date -u +%FT%TZ; }
log() { printf '%s %s\n' "$(now)" "$*" >> "$LOG"; }
state_get() { sed -n "s/^$1=//p" "$STATE" 2>/dev/null | head -1; }
state_put() {   # lap idx total suite cell status
    printf 'lap=%s\nidx=%s\ntotal=%s\nsuite=%s\ncell=%s\nstatus=%s\nsince=%s\npid=%s\n' "$1" "$2" "$3" "$4" "$5" "$6" "$(now)" "$$" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"; }
cells() {   # one line per cell: key kind lang dir cell (dir: the suite's container directory); core first, then chunk:NN in order, per the row order of SUITE_RUNNERS.tsv
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
                    if (c[ip] == "core") print row "\t0\t" $1 "\t" $2 "\t" $3 "\t" dir "\tcore"
                    else if (c[ip] ~ /^chunk:/) print row "\t1\t" $1 "\t" $2 "\t" $3 "\t" dir "\t" c[ip]
                }
            }
            close(f)
        }' "$RUNNERS" | sort -t "$(printf '\t')" -k1,1n -k2,2n -k7,7 | cut -f3-
}
budget() { python3 -I "$S4E/harness/scripts/util_grade_job.py" budget --suite "$1" --cell "$2" 2>/dev/null | sed -n 's/.* ttr_s=\([0-9]*\).*/\1/p' | head -1; }
container_key() { case "$1" in snobol4) echo sno-rungs;; icon) echo icn-rungs;; prolog) echo pl-rungs;; pascal) echo pas-rungs;; raku) echo raku-rungs;; snocone) echo snc-rungs;; rebus) echo reb-rungs;; esac; }
ext_of() { case "$1" in snobol4) echo sno;; icon) echo icn;; prolog) echo pl;; pascal) echo pas;; raku) echo raku;; rebus) echo reb;; snocone) echo sc;; esac; }
# A SUITE IS ON DISK IN ONE OF THREE FORMS, AND THE ONE LAUNCH READS ALL THREE UNDER THE SAME ALL.<ext> ALL.ref COMMAND LINE (the coo 2026-11-10, row
# cycle-a-suite-in-format-2-or-the-files-form-is-run-not-refused-sno-rungs-refused-three-laps; fmt2_dir_of and pkg_dir_of of corpus_suite_harness.py):
# the container (ALL.<ext> and ALL.ref), format 2 of a test folder (MULTI.md or ONE.<ext>, CIO-24), the files form of a package (a path column in
# ALL.csv, CIO-59, CIO-113). MEASURED: testing for the container alone refused all 24 cells of the SNOBOL4 master in laps 12, 13 and 14 (format 2 since
# 2026-11-10) and the cells of aisnobol and dotnet in lap 14 (the files form), each logged rc=2 secs=0.
suite_on_disk() {   # dir alls -> 0 when the launch can read a suite there
    local d="$1" a="$2"
    if [ -f "$a" ] && [ -f "$d/ALL.ref" ]; then return 0; fi
    if [ -f "$d/MULTI.md" ] || [ -f "$d/ONE.${a##*.}" ]; then return 0; fi
    [ -f "$d/ALL.csv" ] && head -1 "$d/ALL.csv" | tr -d '\r' | tr ',' '\n' | grep -qx path
}
# THE ROAD OF A PACKAGE IS ITS OWN DECLARATION (the coo 2026-11-11, row cycle-a-package-whose-contract-names-the-run-files-road-is-run-by-the-package-switch-fpc-first;
# run-switches step 12, CIO-118): a package in the files form whose CONTRACT.tsv carries the row road<TAB>run-files<TAB>evidence is run by the package
# switch (the launch takes --run-files: mode 3 in one scrip process, graded from its OUT directory); no row is the per-process road. The row is written
# only after the package read equal entry for entry on both roads; the evidence names that reading. The switch runs mode 3, so the flag needs m3.
road_flag() {   # dir -> prints --run-files when the package declares that road
    local d="$1"
    [ -f "$d/CONTRACT.tsv" ] && [ -f "$d/ALL.csv" ] || return 0
    case ",${S4E_MODES:-m3}," in *,m3,*) ;; *) return 0;; esac
    head -1 "$d/ALL.csv" | tr -d '\r' | tr ',' '\n' | grep -qx path || return 0
    awk -F'\t' '!/^#/ && $1 == "road" && $2 == "run-files" && $3 != "" {f = 1} END {exit !f}' "$d/CONTRACT.tsv" && printf '%s' --run-files
    return 0
}
run_cell() {   # key kind lang dir cell -> rc. THE ONE LAUNCH (Lon 2026-11-08 23:0x, in the coo's window, verbatim: "We want ONE UNIFIED test suite system. The same ALL.tsv files etc. Same layout in corpus. Same script. Same spec on attributes and environment." / "Get those deleted and get to work with a complete test suite system."): every cell, master or pkg, is corpus_suite_harness.py run over the suite's container ALL.<ext> and ALL.ref; a suite without one refuses rc 2, named, until its container is built
    local key="$1" kind="$2" lang="$3" dir="$4" cell="$5" ttr alls rc t0 out
    ttr="$(budget "$key" "$cell")"; [ -n "$ttr" ] || ttr=3600
    out="$TMPDIR/cycle/$key.$cell.log"; t0=$(date +%s)
    alls="$dir/ALL.$(ext_of "$lang")"
    if ! suite_on_disk "$dir" "$alls"; then echo "REFUSE(2): no suite in $dir: no container ($alls and ALL.ref), no format 2 (MULTI.md or ONE.$(ext_of "$lang")), no files form (a path column in ALL.csv) -- the unified layout is owed (util_build_package_suite.py)" > "$out"; echo "2 0"; return 2; fi
    ( cd "$S4E" && SUITE_LIST_ALL=1 timeout -k 30 "$ttr" bash harness/scripts/util_run_slot.sh python3 harness/scripts/corpus_suite_harness.py run "$alls" "$dir/ALL.ref" --lang "$lang" --modes "${S4E_MODES:-m3}" --partition "$cell" $(road_flag "$dir") ) > "$out" 2>&1 < /dev/null; rc=$?
    echo "$rc $(( $(date +%s) - t0 ))"
}
# THE TEST REQUESTS (the cio 2026-11-10, row bus-one-queue-the-grading-tube-retires-the-cycle-serves-the-test-requests-itself, CIO-82; the grade tube,
# its feeder and its worker retired): a request is one file test_requests/STAMP-SEAT-SUITE-N.req (seat, suite, table, filed, entries). It is PENDING while
# it sits in that folder, whatever fed= line an old feeder wrote. Before any cell is started the pool serves the oldest pending request as one more
# cell: the file moves to serving/ (a restart puts it back), the one launch runs its entries (entry:A,entry:B) in S4E_MODES under the budget of that
# entry cell, the suite row is recorded, and the file lands in done/ with graded=/rc= per entry and one served= line, as the grade worker wrote it.
RQ="${S4E_TEST_REQUEST_DIR:-/home/resources/postoffice/test_requests}"
next_request() { local f; for f in "$RQ"/*.req; do [ -f "$f" ] && { printf '%s\n' "$f"; return 0; }; done; return 1; }
run_request() {   # serving file -> "rc secs" on stdout; the harness log in $TMPDIR/cycle/req.<name>.log
    local f="$1" name key ents row kind lang dir alls ttr t0 rc out
    name="$(basename "$f")"; out="$TMPDIR/cycle/req.$name.log"; t0=$(date +%s)
    key="$(sed -n 's/^suite=//p' "$f" | head -1)"; ents="$(sed -n 's/^entries=//p' "$f" | head -1 | tr -s ' ,' '\n\n' | grep -v '^$' | tr '\n' ',' | sed 's/,$//')"
    row="$(awk -F'\t' -v k="$key" '!/^#/ && $1 == k && ($2 == "master" || $2 == "pkg") {print $2 "\t" $3 "\t" $5; exit}' "$RUNNERS")"
    [ -n "$row" ] && [ -n "$ents" ] || { echo "REFUSE(2): suite $key has no master or pkg row of SUITE_RUNNERS.tsv, or the request names no entries" > "$out"; echo "2 0"; return; }
    IFS=$'\t' read -r kind lang dir <<< "$row"; [ "$kind" = master ] && dir="$S4E/corpus/tests/$lang" || dir="$S4E/$dir"
    alls="$dir/ALL.$(ext_of "$lang")"
    ttr="$(budget "$key" "entry:$ents")"; [ -n "$ttr" ] || ttr=1800
    ( cd "$S4E" && SUITE_LIST_ALL=1 timeout -k 30 "$ttr" bash harness/scripts/util_run_slot.sh python3 harness/scripts/corpus_suite_harness.py run "$alls" "$dir/ALL.ref" --lang "$lang" --modes "${S4E_MODES:-m3}" --partition "entry:${ents//,/,entry:}" $(road_flag "$dir") ) > "$out" 2>&1 < /dev/null; rc=$?
    [ "$kind" = master ] && record_suite "$lang"; [ "$kind" = pkg ] && record_pkg "$key"
    echo "$rc $(( $(date +%s) - t0 ))"; }
finish_request() {   # name rc secs: the file lands in done/ with its per-entry verdicts and one served= line
    local name="$1" rc="$2" secs="$3" s="$RQ/serving/$1" e erc body tree n=0
    tree="$(git -C "$S4E/SCRIP" rev-parse --short=9 HEAD 2>/dev/null)"; body="$(cat "$s" 2>/dev/null)"
    for e in $(sed -n 's/^entries=//p' "$s" | head -1 | tr ',' ' '); do
        erc="$rc"; [ "$rc" = 1 ] && { grep -qE "^  (FAIL|CRASH|HANG|UNPROVEN) [^ ]+ ([^ ]+__)?$e[: ]" "$TMPDIR/cycle/req.$name.log" 2>/dev/null && erc=1 || erc=0; }
        body="$body"$'\n'"graded=$e"$'\n'"rc=$erc"; n=$((n+1)); done
    printf '%s\nserved=%s tree=%s rc=%s rows=%s by=cycle secs=%s\n' "$body" "$(TZ=America/Chicago date '+%F %T CST')" "$tree" "$rc" "$n" "$secs" > "$RQ/done/$name" && rm -f "$s"
    log "REQUEST lap=$lap $name rc=$rc secs=$secs entries=$n"; }
record_suite() {   # lang -> the rungs suite row of that language, as the grade worker's record step writes it
    local k; k="$(container_key "$1")"; [ -n "$k" ] || return 0
    ( cd "$S4E" && timeout -k 30 900 python3 -I harness/scripts/util_score_row.py from-progress --suite "$k" ) >> "$TMPDIR/cycle/record.log" 2>&1 < /dev/null
}
record_pkg() {   # key -> that pkg row of SUITES.tsv, from its progress rows in S4E_MODES (the cycle exports m3), after the row's last cell
    ( cd "$S4E" && timeout -k 30 900 python3 -I harness/scripts/util_score_row.py from-progress --suite "$1" ) >> "$TMPDIR/cycle/record.log" 2>&1 < /dev/null
}
graded_this_lap() {   # key -> rc 0 when a cell of this lap graded that suite (rc 0 or 1); read from the log, so a restart mid-suite still knows
    grep -qE " CELL lap=$lap [0-9]+/[0-9]+ $(printf '%s' "$1" | sed 's/[.[\*^$]/\\&/g') [^ ]+ rc=[01] " "$LOG" 2>/dev/null
}
lap_start() {
    local sy mk
    # THE GRADER ROOT'S OWN RENDERING NEVER BLOCKS ITS SYNC (the cio 2026-11-10; MEASURED: sync_rc=1 at every lap start since lap 2, sync.log
    # "Your local changes to the following files would be overwritten by merge: SCORE.md", the grader root's .github held at 75efb44b0 while origin
    # moved to 21c79e39a): the record step re-renders SCORE.md in this root from /home/resources/progress/SUITES.tsv, which is the record; the
    # rendering is the cycle's own scratch and is restored before the sync when it is the only tracked change, so the lap reads origin's .github.
    if [ "$(git -C "$S4E/.github" status --porcelain --untracked-files=no 2>/dev/null)" = " M SCORE.md" ]; then git -C "$S4E/.github" checkout -q -- SCORE.md >> "$TMPDIR/cycle/sync.log" 2>&1; fi
    ( cd "$S4E" && bash harness/scripts/util_sync_root.sh ) >> "$TMPDIR/cycle/sync.log" 2>&1 < /dev/null; sy=$?
    ( cd "$S4E/SCRIP" && make -j8 ) >> "$TMPDIR/cycle/make.log" 2>&1 < /dev/null; mk=$?
    log "LAP $1 start sync_rc=$sy make_rc=$mk scrip=$(git -C "$S4E/SCRIP" rev-parse --short=9 HEAD 2>/dev/null) corpus=$(git -C "$S4E/corpus" rev-parse --short=9 HEAD 2>/dev/null)"
    [ "$mk" = 0 ] || { log "LAP $1 REFUSED: make rc $mk (see $TMPDIR/cycle/make.log); exit 1, cron starts the next try"; exit 1; }
    # A LANDED CHANGE OF THIS SCRIPT IS LIVE AT THE NEXT LAP, WITH NO HAND SWAP (the cio 2026-11-10; MEASURED: pid 4174123 ran the code of
    # 2026-11-08 23:14 for ten laps while three cycle cures sat synced in its own root, and the swap before it needed Lon's hand): bash holds
    # the loop it parsed at start, so when the sync has changed this file the process replaces itself with the new text here, at the one
    # point where no cell runs. The state is put back one lap so the new process starts this same lap; the pid and CYCLE.pid do not change.
    if [ "$(md5sum < "$SELF" 2>/dev/null)" != "$SELF_SUM" ] && bash -n "$SELF" 2>/dev/null; then
        log "SWAP lap=$1: s4e_cycle.sh changed under the sync; the cycle re-executes itself and starts lap $1 on the new text"
        state_put "$(( $1 - 1 ))" 0 0 "" "" swap
        exec bash "$SELF" ${MODE_ARG:+"$MODE_ARG"}
    fi
}
if [ "$MODE_ARG" = --list ]; then cells; echo "CELLS $(cells | wc -l)"; exit 0; fi
{ [ "${BASH_VERSINFO[0]}" -gt 5 ] || { [ "${BASH_VERSINFO[0]}" -eq 5 ] && [ "${BASH_VERSINFO[1]}" -ge 1 ]; }; } || { echo "REFUSE(2) [cycle]: bash ${BASH_VERSION} has no wait -n -p (5.1 or newer; the rolling pool needs it)"; exit 2; }
if [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF" 2>/dev/null)" 2>/dev/null && [ "$(cat "$PIDF")" != "$$" ]; then echo "REFUSE(2) [cycle]: already running as pid $(cat "$PIDF")"; exit 2; fi
echo $$ > "$PIDF"
trap 'rm -f "$PIDF"' EXIT
# THE BINARY IS FRESH AT EVERY START, not only at a lap start (the cio 2026-11-08 10:5x: the grader root synced mid-lap without a make, and cells 25 to 40 refused rc 2 in 2 s each on a stale binary): make on a built tree is a no-op or a cache fetch.
( cd "$S4E/SCRIP" && make -j8 ) >> "$TMPDIR/cycle/make.log" 2>&1 < /dev/null || { log "START REFUSED: make rc $? (see $TMPDIR/cycle/make.log); exit 1, cron starts the next try"; exit 1; }
lap="$(state_get lap)"; idx="$(state_get idx)"; st="$(state_get status)"; pc="$(state_get cell)"; ps="$(state_get suite)"
[ -n "$lap" ] || lap=0; [ -n "$idx" ] || idx=0
if [ "$st" = running ] && [ -n "$ps" ]; then
    n=$(( $(awk -F'\t' -v s="$ps" -v c="$pc" '$1 == s && $2 == c {print $3; exit}' "$CRASH" 2>/dev/null) + 1 ))
    { grep -v -P "^\Q$ps\E\t\Q$pc\E\t" "$CRASH" 2>/dev/null; printf '%s\t%s\t%s\n' "$ps" "$pc" "$n"; } > "$CRASH.tmp" && mv "$CRASH.tmp" "$CRASH"
    log "CRASH lap=$lap idx=$idx $ps $pc killed the cycle, count=$n"
    if [ "$n" -ge 3 ]; then printf '%s\t%s\t%s\tskipped after %s deaths\n' "$(now)" "$ps" "$pc" "$n" >> "$SKIP"; log "SKIP $ps $pc for good (three deaths)"; fi
fi
if [ "$MODE_ARG" = --next ]; then IFS=$'\t' read -r key kind lang dir cell <<< "$(cells | sed -n "$(( idx + 1 ))p")"; echo "NEXT lap=$lap idx=$idx cell=$key $cell"; exit 0; fi
while :; do
    mapfile -t ALL < <(cells); total=${#ALL[@]}
    [ "$total" -gt 0 ] || { log "REFUSED: no cells (SUITE_RUNNERS.tsv or the partitions unreadable)"; exit 2; }
    if [ "$idx" -eq 0 ] || [ "$idx" -ge "$total" ]; then
        [ "$idx" -ge "$total" ] && [ "$lap" -gt 0 ] && log "LAP $lap done cells=$total"
        lap=$(( lap + 1 )); idx=0; lap_start "$lap"
        cp "${S4E_RESULTS:-/home/resources/progress/results.tsv}" "$TMPDIR/cycle/lap.$lap.results" 2>/dev/null; rm -f "$TMPDIR/cycle/lap.$(( lap - 2 )).results"   # the lap's own copy: its end tells the new reds against it
        # THE LAP'S CELLS ARE READ FROM THE TREE IT GRADES, after the sync (the cio 2026-11-10: the list was read before lap_start, so a
        # partition landed between two laps ran one lap on the old cell names, and a chunk the new table no longer has refused rc 2).
        mapfile -t ALL < <(cells); total=${#ALL[@]}
        [ "$total" -gt 0 ] || { log "REFUSED: no cells after the sync (SUITE_RUNNERS.tsv or the partitions unreadable)"; exit 2; }
    fi
    # THE WIDTH (the cio, 2026-11-08 10:4x CST; MEASURED: 20 cells in 1579 s one at a time, 78 s a cell, a lap of 190 cells 250 min, at load 8 on 16 cores
    # with no CPU pressure): up to S4E_CYCLE_WIDTH cells (default 4; 1 under --one) run at once, each under its own run slot in the grader's pool.
    # THE ROLLING POOL (the cio 2026-11-10, row cycle-keeps-its-width-of-cells-running; MEASURED by the coo 20:53Z: lap 11 stood 1 h 40 min on xsb chunk:02
    # with three of four slots idle, because a batch waited on ALL its cells): the moment ANY cell finishes (wait -n -p) it is handled and its slot is
    # refilled with the next cell. The state names the LOWEST index still running, so a crash is charged to it and a restart resumes there (a later cell
    # that had finished runs again: time, never a reading). CELL lines come in order of finish, each with its own index. A suite's row is recorded when
    # the last of its cells of this lap has finished, whatever the order.
    W="${S4E_CYCLE_WIDTH:-4}"; [ "$MODE_ARG" = --one ] && W=1; case "$W" in ''|*[!0-9]*|0) W=4;; esac
    declare -A RUN=() LEFT=(); nxt="$idx"
    mkdir -p "$RQ/serving" "$RQ/done" 2>/dev/null; for f in "$RQ"/serving/*.req; do [ -f "$f" ] && mv "$f" "$RQ/" 2>/dev/null; done   # a request a dead cycle was serving is pending again
    for (( j = idx; j < total; j++ )); do IFS=$'\t' read -r key kind lang dir cell <<< "${ALL[$j]}"; grep -q -P "\t\Q$key\E\t\Q$cell\E\t" "$SKIP" 2>/dev/null || LEFT[$key]=$(( ${LEFT[$key]:-0} + 1 )); done
    while :; do
        while [ "${#RUN[@]}" -lt "$W" ] && rf="$(next_request)"; do   # the oldest pending request first, as one more cell
            rn="$(basename "$rf")"; mv "$rf" "$RQ/serving/$rn" 2>/dev/null || break
            ( run_request "$RQ/serving/$rn" > "$TMPDIR/cycle/rres.$rn" ) & RUN[$!]="r:$rn"
        done
        while [ "$nxt" -lt "$total" ] && [ "${#RUN[@]}" -lt "$W" ]; do
            IFS=$'\t' read -r key kind lang dir cell <<< "${ALL[$nxt]}"
            if grep -q -P "\t\Q$key\E\t\Q$cell\E\t" "$SKIP" 2>/dev/null; then log "SKIPPED lap=$lap $((nxt+1))/$total $key $cell"; nxt=$(( nxt + 1 )); continue; fi
            ( run_cell "$key" "$kind" "$lang" "$dir" "$cell" > "$TMPDIR/cycle/res.$nxt" ) & RUN[$!]="$nxt"; nxt=$(( nxt + 1 ))
        done
        [ "${#RUN[@]}" -gt 0 ] || break
        low="$nxt"; for i in "${RUN[@]}"; do case "$i" in r:*) ;; *) [ "$i" -lt "$low" ] && low="$i";; esac; done
        if [ "$low" -lt "$total" ]; then IFS=$'\t' read -r key kind lang dir cell <<< "${ALL[$low]}"; state_put "$lap" "$low" "$total" "$key" "$cell" running; fi
        dp=""; wait -n -p dp "${!RUN[@]}"; [ -n "$dp" ] && [ -n "${RUN[$dp]:-}" ] || continue
        i="${RUN[$dp]}"; unset 'RUN[$dp]'
        case "$i" in r:*) rn="${i#r:}"; rc=2; secs=0; read -r rc secs < "$TMPDIR/cycle/rres.$rn"; rm -f "$TMPDIR/cycle/rres.$rn"; finish_request "$rn" "$rc" "$secs"; continue;; esac
        IFS=$'\t' read -r key kind lang dir cell <<< "${ALL[$i]}"
        rc=2; secs=0; read -r rc secs < "$TMPDIR/cycle/res.$i"; rm -f "$TMPDIR/cycle/res.$i"
        log "CELL lap=$lap $((i+1))/$total $key $cell rc=$rc secs=$secs"
        LEFT[$key]=$(( ${LEFT[$key]:-1} - 1 ))
        # A SUITE ROW IS WRITTEN ONLY BY A LAP THAT GRADED THE SUITE (the cio 2026-11-10; MEASURED: inria's five cells refused rc 2 in 0 s on
        # laps 2 to 10, no grader row for inria is later than 2026-11-08T20:19Z, and its SUITES.tsv row reads today_date 2026-11-09; logtalk
        # and dotnet the same): from-progress stamps the box-clock day, so a record after a lap in which every cell refused re-dates old
        # readings as today's. No cell of this lap at rc 0 or 1, no record; the row keeps the day of its last reading and the log says so.
        if [ "${LEFT[$key]}" -le 0 ] && [ "$MODE_ARG" != --one ]; then
            if graded_this_lap "$key"; then
                [ "$kind" = master ] && record_suite "$lang"
                [ "$kind" = pkg ] && record_pkg "$key"
            else
                log "NORECORD lap=$lap $key: no cell of this lap graded (every cell refused, died or was held); its suite row is not rewritten"
            fi
        fi
        [ "$MODE_ARG" = --one ] && { echo "ONE $key $cell rc=$rc secs=$secs"; state_put "$lap" "$((i+1))" "$total" "$key" "$cell" done; exit 0; }
    done
    # THE LAP'S NEW REDS (the cio 2026-11-10, CIO-82 on the grading-tube row; Lon's law of CIO-8): one telegram per designer, once a lap, never one per red
    if [ "$MODE_ARG" != --one ]; then
        gk=(); for k in $(printf '%s\n' "${ALL[@]}" | cut -f1 | awk '!s[$0]++'); do graded_this_lap "$k" && gk+=("$k"); done
        [ "${#gk[@]}" -gt 0 ] && log "$( . "$S4E/harness/scripts/lib_grade_cell.sh"; tell_lap_new_reds "$(git -C "$S4E/SCRIP" rev-parse --short=9 HEAD 2>/dev/null)" "$TMPDIR/cycle/lap.$lap.results" "${gk[@]}" ) lap=$lap suites=${#gk[@]}"
    fi
    idx="$total"; state_put "$lap" "$idx" "$total" "$key" "$cell" done
done
