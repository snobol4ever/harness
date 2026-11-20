#!/usr/bin/env bash
# s4e_cycle.sh -- THE TEST CYCLE: ONE PROCESS RUNS EVERY SUITE CELL IN ORDER, LAP AFTER LAP (Lon, in the cio's window, 2026-11-08 09:0x CST, verbatim:
# "write a process that runs the test suite and write a fucking monitor to start it when it crashed" / "Is it not called CRON?"). No queue, no tubes,
# no workers, no controller: this process and the cron line that restarts it (s4e_cycle_cron.sh).
#   bash s4e_cycle.sh            the cycle: a lap is sync, make, then every cell of every master or pkg row of SUITE_RUNNERS.tsv and one cell (all) for every small row, a fast lane of S4E_CYCLE_FAST (8) cells and a slow lane of S4E_CYCLE_SLOW (2) at once; then the next lap
#   bash s4e_cycle.sh --list     print the cells of one lap (suite kind lang dir cell) and their count; runs nothing
#   bash s4e_cycle.sh --one      run the next unfinished cell only, then exit (the proof that one cell runs end to end)
#   S4E_CYCLE_TMP names a scratch TMPDIR for a probe (default /tmp/s4e/grader, the live cycle's cell logs; a probe that leaves it unset overwrites them)
#   bash s4e_cycle.sh --next     do the restart accounting (CYCLE.crash, CYCLE.skip) and print NEXT lap=L idx=I cell=KEY CELL, the cell a restart runs first; runs no cell (S4E_CYCLE_PROG names a scratch progress dir for a probe)
# THE ROOT is S4E_HOME, default /home/claude_grader (the grader's mirror; no seat edits it). THE LAUNCH of a cell is the grade worker's launch, unchanged:
# EVERY row, master or pkg, runs ONE launch (Lon 2026-11-08 23:0x: "ONE UNIFIED test suite system"): corpus_suite_harness.py run <dir>/ALL.<ext> <dir>/ALL.ref --lang L --modes $S4E_MODES --partition <cell>, dir the master's corpus/tests/<lang> or the pkg row's column 5; the package runner scripts are deleted; a row with no container refuses rc 2 by name; a row of kind small is one cell run by its own runner until it is a package (COO-516, small_budget below);
# both under util_run_slot.sh, S4E_CLASS=grader, S4E_BATCH=1 (one scrip --harness per partition and mode, batch-grader step 5), S4E_MODES default m3 (Lon 2026-11-08 10:2x: "We will test mode 3 only until further notice"), under timeout -k 30 of the
# cell's declared budget (util_grade_job.py budget). After a master suite's or a pkg row's last cell its suite row is rewritten (util_score_row.py from-progress, in S4E_MODES).
# THE STATE is /home/resources/progress/CYCLE.state (lap, idx, total, suite, cell, status, since), one line a key, rewritten before and after every cell;
# CYCLE.log gets one line per cell (ts lap idx/total suite cell rc secs) and one per lap; CYCLE.pid is this process. A restart reads CYCLE.state and goes on
# at the cell after the last finished one; a cell found "running" at start killed the process, its count in CYCLE.crash rises, and at three it is skipped
# for good (named in CYCLE.skip, one line each) so no cell can hold the cycle forever.
set -u
if [ "${1:-}" = --probe-port ] && [ -z "${S4E_DOOR_PROBE_T:-}" ]; then   # THE PORTS' PROBE, IN A SANDBOX OF ITS OWN as --probe-door's: scratch progress, tmp, requests, one token, an empty PORTS_TOP
    _T="$(mktemp -d "${TMPDIR:-/tmp}/s4e_probe_port.XXXXXX")" || exit 2; mkdir -p "$_T/prog" "$_T/tmp" "$_T/req" "$_T/run" "$_T/post" "$_T/ports"; printf 'cores=1\ngrader=1\nwait=600\n' > "$_T/CORES.conf"
    env -u S4E_CORE_HELD -u S4E_RUN_SLOT_HELD -u S4E_SLOT_WAIT_MAX -u S4E_CYCLE_PORTS S4E_DOOR_PROBE_T="$_T" S4E_CYCLE_PROG="$_T/prog" S4E_CYCLE_TMP="$_T/tmp" S4E_PROGRESS_DB="$_T/results.tsv" S4E_RESULTS="$_T/results.tsv" \
        S4E_SUITES_TSV="$_T/SUITES.tsv" S4E_SCORE_MD="$_T/SCORE.md" S4E_TEST_REQUEST_DIR="$_T/req" S4E_POST="$_T/post" S4E_POSTOFFICE="$_T/post" S4E_CORES_CONF="$_T/CORES.conf" \
        S4E_RUN_SLOT_DIR="$_T/run" S4E_SLOT_WAITS="$_T/SLOT_WAITS.tsv" S4E_SPRINT_CONF="$_T/no-sprint.conf" S4E_CYCLE_PORTS_TOP="$_T/ports" S4E_CYCLE_PORT_URL="$_T/no-origin" bash "$(readlink -f "${BASH_SOURCE[0]}")" --probe-port; _rc=$?
    rm -rf "$_T"; exit "$_rc"
fi
if [ "${1:-}" = --probe-door ] && [ -z "${S4E_DOOR_PROBE_T:-}" ]; then   # THE DOOR'S PROBE RUNS IN A SANDBOX OF ITS OWN (skill suites-and-grading 9): scratch progress, tmp, requests and one core token
    _T="$(mktemp -d "${TMPDIR:-/tmp}/s4e_probe_door.XXXXXX")" || exit 2; mkdir -p "$_T/prog" "$_T/tmp" "$_T/req" "$_T/run" "$_T/post"; printf 'cores=1\ngrader=1\nwait=600\n' > "$_T/CORES.conf"
    env -u S4E_CORE_HELD -u S4E_RUN_SLOT_HELD -u S4E_SLOT_WAIT_MAX S4E_DOOR_PROBE_T="$_T" S4E_CYCLE_PROG="$_T/prog" S4E_CYCLE_TMP="$_T/tmp" S4E_PROGRESS_DB="$_T/results.tsv" S4E_RESULTS="$_T/results.tsv" \
        S4E_SUITES_TSV="$_T/SUITES.tsv" S4E_SCORE_MD="$_T/SCORE.md" S4E_TEST_REQUEST_DIR="$_T/req" S4E_POST="$_T/post" S4E_POSTOFFICE="$_T/post" S4E_CORES_CONF="$_T/CORES.conf" \
        S4E_RUN_SLOT_DIR="$_T/run" S4E_SLOT_WAITS="$_T/SLOT_WAITS.tsv" S4E_SPRINT_CONF="$_T/no-sprint.conf" S4E_COSTS="$_T/COSTS.tsv" S4E_COSTS_IDX="$_T/COSTS.idx" bash "$(readlink -f "${BASH_SOURCE[0]}")" --probe-door; _rc=$?
    rm -rf "$_T"; exit "$_rc"
fi
S4E="${S4E_HOME:-/home/claude_grader}"
# THE TREE GRADED NAMES ALL FOUR REPOS (officer_02 2026-11-13, row harness-corpus-and-harness-live-once-on-disk-one-seat-owns-them): lib_paths.sh and harness_paths.py read /home/corpus,
# /home/harness and /home/.github once each is a checkout, so every run here pins S4E_SCRIP, S4E_CORPUS, S4E_HARNESS and S4E_GITHUB to the tree it grades (a base, or this root), and a
# chunk keeps its own snapshot whatever the one-disk checkouts hold.
# THE ROOT HOLDS ITS SCRIP CLONE ALONE (the cio 2026-11-14, row harness-one-disk-step-6-the-cutover; Lon, in the cio's window, verbatim: "We are meant not to have folder
# .github, harness, and corpus in each /home/claude folder ... Complete the new disk/file layout."): the root's four are what lib_paths.sh names for it (its SCRIP, and
# /home/corpus, /home/harness and /home/.github once the root holds none of its own), and a base still holds all four as siblings. td <tree> <repo> names a repo of a
# tree, tp <tree> <path> respells a path written under the root (cells: $S4E/corpus/...) for the tree a chunk runs on, and pin <tree> sets T_SCRIP, T_CORPUS,
# T_HARNESS and T_GITHUB, so every launch below pins the four to the tree it grades whichever kind it is.
export S4E_HOME="$S4E"; unset S4E_SCRIP S4E_CORPUS S4E_HARNESS S4E_GITHUB
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_paths.sh"
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_slots.sh"   # s4e_slot_hold: a cell takes its run token itself (door_take)
td() { if [ "$1" = "$S4E" ]; then case "$2" in SCRIP) printf '%s' "$S4E_SCRIP";; corpus) printf '%s' "$S4E_CORPUS";; harness) printf '%s' "$S4E_HARNESS";; .github) printf '%s' "$S4E_GITHUB";; esac; else printf '%s/%s' "$1" "$2"; fi; }
tp() { local rel r; case "$2" in "$S4E"/*) rel="${2#"$S4E"/}"; r="${rel%%/*}"; if [ "$r" = "$rel" ]; then td "$1" "$r"; else printf '%s/%s' "$(td "$1" "$r")" "${rel#*/}"; fi;; *) printf '%s' "$2";; esac; }
pin() { T_SCRIP="$(td "$1" SCRIP)"; T_CORPUS="$(td "$1" corpus)"; T_HARNESS="$(td "$1" harness)"; T_GITHUB="$(td "$1" .github)"; }
export S4E_SEAT=grader S4E_CLASS=grader S4E_BATCH="${S4E_BATCH:-1}" S4E_MODES="${S4E_MODES:-m3}" TMPDIR="${S4E_CYCLE_TMP:-/tmp/s4e/grader}"   # S4E_MODES exported: the cells and the suite row (util_score_row.py from-progress) read the same modes, m3 alone under Lon's mode-3-only order   # one-disk: not a path (the pin: the graded tree's own four repos, by design (lines 20-22))
PROG="${S4E_CYCLE_PROG:-/home/resources/progress}"
STATE="$PROG/CYCLE.state"; LOG="$PROG/CYCLE.log"; PIDF="$PROG/CYCLE.pid"; CRASH="$PROG/CYCLE.crash"; SKIP="$PROG/CYCLE.skip"
RUNNERS="${S4E_CYCLE_RUNNERS:-$S4E_HARNESS/scripts/SUITE_RUNNERS.tsv}"   # S4E_CYCLE_RUNNERS: a probe's own table, never the live cycle's
mkdir -p "$TMPDIR/cycle" "$PROG" || exit 2
# THE CYCLE RENDERS INTO ITS SCRATCH, NEVER INTO A TRACKED FILE OF THE ROOT (the cio 2026-11-12, row cycle-score-md-dirties-the-grader-root; MEASURED
# 13:5x: the grader root's .github read M SCORE.md between laps, so next refused that seat's jobs rc 2): util_score_row.py and util_suite_banner.py
# render the suite table into S4E_SCORE_MD, the record stays /home/resources/progress/SUITES.tsv; the scratch is seeded from the root's SCORE.md.
export S4E_SCORE_MD="${S4E_SCORE_MD:-$TMPDIR/cycle/SCORE.md}"
# THE SEED IS THE RENDER BESIDE THE RECORD when there is one (the grader 2026-11-14, on the cio's harness 944a50d74: outside the cycle the score render now lives in
# $PROG/SCORE.md, never in the one-disk .github checkout, whose tracked copy therefore goes stale); the checkout's copy seeds only a box that has no render yet.
_score_seed="$S4E_GITHUB/SCORE.md"; [ ! -s "$PROG/SCORE.md" ] || _score_seed="$PROG/SCORE.md"
[ -s "$S4E_SCORE_MD" ] || [ ! -f "$_score_seed" ] || cp -f "$_score_seed" "$S4E_SCORE_MD"
[ ! -f "$S4E_SCORE_MD" ] || [ -w "$S4E_SCORE_MD" ] || chmod u+w "$S4E_SCORE_MD"   # a root's tracked files are read-only shared links (skill shared-box 4), so a fresh copy is mode 444 and the render refused PermissionError (MEASURED 2026-11-13, a scratch S4E_CYCLE_PROG)
# THE CYCLE NAMES ITS TABLE, IT NEVER LETS THE ROOT'S NAME CHOOSE IT (the grader 2026-11-13; MEASURED: from 21:26Z every row write refused "rc=1, no
# refusal line" and CYCLE.refused held 71 rows, because util_score_row.py writes /home/resources/progress/SUITES.tsv only for a root spelled
# /home/claude_<seat> and takes every other root for a fixture with its own .github/SUITES.tsv, and the row is written on a base under
# /home/resources/worktrees/grader, which has none: util_suite_banner.py --set died on FileNotFoundError and left SUITES.tsv.lock in the base's .github).
export S4E_SUITES_TSV="${S4E_SUITES_TSV:-$PROG/SUITES.tsv}"
[ -f "$RUNNERS" ] || { echo "REFUSE(2) [cycle]: no $RUNNERS"; exit 2; }
MODE_ARG="${1:-}"
SELF="$(readlink -f "${BASH_SOURCE[0]}")"; SELF_SUM="$(md5sum < "$SELF" 2>/dev/null)"
now() { date -u +%FT%TZ; }
log() { printf '%s %s\n' "$(now)" "$*" >> "$LOG"; }
state_get() { sed -n "s/^$1=//p" "$STATE" 2>/dev/null | head -1; }
state_put() {   # lap idx total suite cell status
    printf 'lap=%s\nidx=%s\ntotal=%s\nsuite=%s\ncell=%s\nstatus=%s\nsince=%s\npid=%s\n' "$1" "$2" "$3" "$4" "$5" "$6" "$(now)" "$$" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"; }
# THE PORT ROWS ARE CELLS OF THE CYCLE (row cycle-the-port-rows-are-cells-of-the-cycle; Lon 2026-11-17 16:4x and 17:0x CST, in the jvm and dotnet windows, verbatim:
# "You need to incorporate the consolidated test-suite cycle-runner and all its container files and get ALL SNOBOL4 tests working with snobol4jvm." / "... with
# snobol4dotnet."; the design dotnet's, /home/resources/progress/ports-2026-11-17/dotnet/CYCLE-PORT-DESIGN.md, with the cio's three changes and jvm's part (f)).
# A port row <key>@<engine> of SUITE_RUNNERS.tsv whose runner is corpus_suite_harness.py is a cell like a pkg row, launched under S4E_ENGINE=<engine>. The engine it
# grades is THE CYCLE'S OWN BUILD of the port at its origin's head, PORTS_TOP/<repo>-<sha10>, never the seat's root (MEASURED by jvm: the seat's root is dirty or
# ahead of origin while it works, so a reading there is UNREAD, or refused by --binaries at its start). The head is read by git ls-remote of the seat root's own
# origin url; a head with no built folder is cloned and built in the background at a lap's start (port_refresh) while the newest built folder serves; the two newest
# are kept. A port with no built folder, or whose runner refuses its --binaries check, emits no cells and one PORT-SKIPPED line a lap naming why. A port cell is a
# slow-lane cell after every SCRIP slow cell, one at a time for both engines, its token through door_take, started only while no request is pending, and never a
# sprint cell. Proof: --probe-port.
CYCLE_PORTS="${S4E_CYCLE_PORTS:-jvm dotnet}"
PORTS_TOP="${S4E_CYCLE_PORTS_TOP:-/home/resources/worktrees/grader/ports}"
port_repo() { case "$1" in jvm) echo snobol4jvm;; dotnet) echo snobol4dotnet;; esac; }
port_root_var() { case "$1" in jvm) echo S4E_JVM_ROOT;; dotnet) echo S4E_DOTNET_ROOT;; esac; }
port_ready() {   # engine -> prints the newest built folder of the port; rc 1 when none is built
    local r d; r="$(port_repo "$1")"; [ -n "$r" ] || return 1
    d="$(ls -dt "$PORTS_TOP/$r"-*/.built 2>/dev/null | head -1)"; [ -n "$d" ] || return 1
    printf '%s' "${d%/.built}"
}
port_ok() {   # engine -> rc 0 when a built folder stands and the engine's runner passes its own --binaries check on it; else rc 1 and the reason on stdout
    local e="$1" d c; d="$(port_ready "$e")" || { echo "no built folder of the port under $PORTS_TOP (port_refresh builds origin's head in the background)"; return 1; }
    c="${S4E_CYCLE_PORT_CHECK:-bash $S4E_HARNESS/scripts/run_snobol4$e.sh}"
    env "$(port_root_var "$e")=$d" $c --binaries --lang snobol4 > /dev/null 2>&1 || { echo "its runner refused --binaries on $d"; return 1; }
    return 0
}
port_refresh() {   # engine: build the port at its origin's head in PORTS_TOP when no folder holds it, under a lock of its own; run in the background
    local e="$1" r url head d; r="$(port_repo "$e")"; [ -n "$r" ] || return 2
    mkdir -p "$PORTS_TOP" || return 2
    url="${S4E_CYCLE_PORT_URL:-$(git -C "/home/claude_$e" remote get-url origin 2>/dev/null)}"; [ -n "$url" ] || { log "PORT $e: no origin url (/home/claude_$e)"; return 2; }
    head="$(timeout -k 5 60 git ls-remote "$url" refs/heads/main 2>/dev/null | cut -c1-10)"; [ -n "$head" ] || { log "PORT $e: git ls-remote read no head of $url"; return 2; }
    [ -f "$PORTS_TOP/$r-$head/.built" ] && return 0
    ( flock -n 9 || exit 0
      d="$PORTS_TOP/$r-$head"; rm -rf "$d"
      git clone -q "$url" "$d" 2> /dev/null && git -C "$d" checkout -q --detach "$head" 2> /dev/null || { log "PORT $e: clone of $head failed"; exit 1; }
      case "$e" in
          jvm) S4E_JVM_ROOT="$d" timeout -k 30 1800 nice -n 10 bash "$S4E_HARNESS/scripts/build_snobol4jvm.sh" ;;
          dotnet) ( cd "$d" && timeout -k 30 1800 nice -n 10 dotnet build Snobol4/Snobol4.csproj -c Release ) ;;
      esac > "$d/.build.log" 2>&1 < /dev/null || { log "PORT $e: build of $head failed ($d/.build.log)"; exit 1; }
      : > "$d/.built"; log "PORT $e built $head ($d)"
      ls -dt "$PORTS_TOP/$r"-*/ 2> /dev/null | tail -n +3 | while read -r o; do o="${o%/}"; fuser -s -m "$o" 2> /dev/null || rm -rf "$o"; done ) 9> "$PORTS_TOP/.$r.build.lock"
}
port_env() {   # key -> the env words of a port cell (S4E_ENGINE and the engine's root on the cycle's newest build); rc 2 when no build stands
    local e="${1##*@}" d; d="$(port_ready "$e")" || return 2
    printf 'S4E_ENGINE=%s %s=%s' "$e" "$(port_root_var "$e")" "$d"
}
ports_on() {   # -> the engines of CYCLE_PORTS whose port_ok passes, space-separated; each other one logs PORT-SKIPPED once a lap when PORT_NOTE_LAP is set
    local e why on=""
    for e in $CYCLE_PORTS; do
        if why="$(port_ok "$e")"; then on="$on $e"
        elif [ -n "${PORT_NOTE_LAP:-}" ] && ! grep -q -P "^\S+ PORT-SKIPPED lap=$PORT_NOTE_LAP engine=$e: " "$LOG" 2> /dev/null; then log "PORT-SKIPPED lap=$PORT_NOTE_LAP engine=$e: $why; its rows emit no cells this lap"; fi
    done
    printf '%s ' "$on"
}
cells() {   # one line per cell: key kind lang dir cell (dir: the suite's container directory; for a small row the runner's own command words, its cell the one name all); core first, then chunk:NN in order, per the row order of SUITE_RUNNERS.tsv
    # THE PARTITION IS READ WHERE THE CORPUS LIVES; THE CELL KEEPS THE ROOT'S SPELLING (the cio 2026-11-14, row harness-one-disk-step-6-the-cutover; MEASURED 08:30 CST: with the
    # grader's root cut the first lap read cells=8 where the lap before read 1092, since every PARTITION.tsv was looked for under S4E/corpus, a folder the root no longer holds,
    # and only the small rows were left). dir stays S4E/corpus/... (not a path: tp respells it for the tree a chunk runs on); the file is read from S4E_CORPUS.
    awk -F'\t' -v S="$S4E" -v C="$S4E_CORPUS" -v PE=" $(ports_on)" '
        function port_on(k,  e) { e = k; sub(/^[^@]*@/, "", e); return (k ~ /@/) && index(PE, " " e " ") > 0 }
        !/^#/ && NF >= 5 && ($2 == "master" || $2 == "pkg" || ($2 == "port" && $4 == "corpus_suite_harness.py" && $5 ~ /^corpus\// && port_on($1))) {
            row++; dir = ($2 == "master") ? S "/corpus/tests/" $3 : S "/" $5
            real = ($2 == "master") ? C "/tests/" $3 : S "/" $5; if (($2 == "pkg" || $2 == "port") && $5 ~ /^corpus\//) real = C "/" substr($5, 8)
            if ($2 == "port" && $5 == "corpus/tests/" $3) { dir = S "/corpus/tests/" $3; real = C "/tests/" $3 }
            f = real "/PARTITION.tsv"; ip = 0; delete seen
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
        }
        !/^#/ && NF >= 5 && $2 == "small" && $4 != "" && $4 != "-" { row++; print row "\t0\t" $1 "\t" $2 "\t" $3 "\t" $4 "\tall" }' "$RUNNERS" | sort -t "$(printf '\t')" -k1,1n -k2,2n -k7,7 | cut -f3-
}
# THE FASTEST SUITES RUN FIRST (the coo 2026-11-11, COO-515, on Lon's word the same morning: "So regarding the order in which the test suites should be
# run, from fastest to slowest." / "I would prefer if you ran the suite that takes seconds now and the long running ones latter"; it reverses COO-510,
# which ran the longest cells first to shorten the lap): a lap's cells are ordered by their SUITE's time, the sum of the seconds each of its cells
# took the last time it graded (rc 0 or 1), the fastest suite first, so the banner shows many suites early and the slow ones last; a suite with no
# reading yet (a new suite) runs before every known one; a suite's own cells stay together in the table's order. The order is FROZEN for the lap in
# CYCLE.order, written at the lap's start, so a restart in the middle of a lap reads the same list and its index names the same cell.
ORDERF="$PROG/CYCLE.order"
order_write() { awk '$2 == "CELL" && $7 != "rc=2" { v = $8; sub(/^secs=/, "", v); s[$5 "\t" $6] = v } END { for (k in s) print k "\t" s[k] }' "$LOG" 2>/dev/null > "$ORDERF.tmp" && mv "$ORDERF.tmp" "$ORDERF"; }
# THE SUITES NAMED FIRST (the grader 2026-11-16, on the coo's word of 11:3x CST and Lon's of 11:1x, "Icon/Prolog graphics and Jupyter lab/notebook
# (SCRIPtix) and GRADING. Three things ONLY!!!"; MEASURED: lap 42 graded no cell for 2 h 17 min behind two rosetta-raku cells while no Icon or Prolog
# suite was read on the day's graphics landings): CYCLE.first, beside CYCLE.order, one line a suite key or lang:L (# a comment). A named key runs first,
# in the file's order; then every suite of a named language, the fastest first as below; then the rest as before. An absent or empty file is no change.
FIRSTF="$PROG/CYCLE.first"
# THE SPRINT IS READ FROM ITS FILE (part 3 of the cio's row cycle-a-cell-takes-its-core-token-before-its-base-and-its-clock-and-a-request-takes-it-first): while SPRINT.conf
# stands (the cio's to set; its lang lines name the sprint's languages), order_cells puts the suites of those languages first, after a suite CYCLE.first names, and a lap
# cell of another language whose last reading took over S4E_CYCLE_SPRINT_SECS (120) is logged SPRINT-HELD and not run (sprint_held); a request is never held. With no file
# nothing changes. It replaces the SPRINT-HOLD lines the cio wrote into CYCLE.skip by hand that hour (267 cells of long Prolog, Pascal and Raku package chunks).
SPRINTF="${S4E_SPRINT_CONF:-/home/resources/postoffice/SPRINT.conf}"
# THE HOLD IS LIFTED BY ONE FILE (Lon 2026-11-17 21:xx CST, in the grader's window, asked how the packages are to be graded, chose "Lift the sprint hold"; MEASURED
# that hour: lap 48 had logged 143 SPRINT-HELD cells by its cell 567 of 1274): while CYCLE.nohold stands beside CYCLE.first, sprint_held holds no cell and the
# sprint's order stands; deleting the file puts the hold back. It is the grader's file: SPRINT.conf, the cio's, and the countdown it drives are not touched.
NOHOLDF="${S4E_CYCLE_NOHOLD:-$PROG/CYCLE.nohold}"
sprint_langs() { awk -F= '!/^#/ && $1 == "lang" { n = split($2, v, /[ ,]+/); for (i = 1; i <= n; i++) if (v[i] != "") print v[i] }' "$SPRINTF" 2> /dev/null | sort -u | tr '\n' ' '; }
sprint_held() {   # key lang cell secs -> rc 0 when the sprint holds this lap cell
    [ -e "$NOHOLDF" ] && return 1
    local sl; sl="$(sprint_langs)"; [ -n "$sl" ] || return 1
    case "$1" in *@*) return 1;; esac   # a port cell is never a sprint cell (it waits in the slow lane behind every SCRIP cell)
    case " $sl " in *" $2 "*) return 1;; esac
    [ "${4:-0}" -gt "${S4E_CYCLE_SPRINT_SECS:-120}" ]
}
order_cells() {   # stdin: the cells in the table's order; stdout: the lap's order
    awk -F'\t' -v OF="$ORDERF" -v FF="$FIRSTF" -v SL="$(sprint_langs)" 'BEGIN { while ((getline l < OF) > 0) { split(l, a, "\t"); s[a[1] "\t" a[2]] = a[3]; have = 1 }
            ns = split(SL, sv, " "); for (i = 1; i <= ns; i++) if (sv[i] != "") sl[sv[i]] = 1
            while ((getline l < FF) > 0) { sub(/#.*/, "", l); gsub(/[ \t]/, "", l); if (l == "") continue; n++; if (l ~ /^lang:/) fl[substr(l, 6)] = n; else fk[l] = n } }
        { line[NR] = $0; su[NR] = $1; la[NR] = $3; k = $1 "\t" $5; if (k in s) { tot[$1] += s[k]; seen[$1] = 1 } }
        END { for (i = 1; i <= NR; i++) { r = (!have ? 0 : (su[i] in seen) ? tot[su[i]] + 1 : 0)
                  if (su[i] ~ /@/) r = 1000000000 + r; else if (su[i] in fk) r = -2000000000 + fk[su[i]]; else if (la[i] in sl) r = r - 1500000000; else if (la[i] in fl) r = r - 1000000000   # a port cell after every SCRIP cell
                  printf "%d\t%d\t%s\n", r, i, line[i] } }' | sort -t "$(printf '\t')" -k1,1n -k2,2n | cut -f3-
}
budget() { local T_SCRIP T_CORPUS T_HARNESS T_GITHUB; pin "${3:-$S4E}"; S4E_HOME="${3:-$S4E}" S4E_SCRIP="$T_SCRIP" S4E_CORPUS="$T_CORPUS" S4E_HARNESS="$T_HARNESS" S4E_GITHUB="$T_GITHUB" python3 -I "$T_HARNESS/scripts/util_grade_job.py" budget --suite "$1" --cell "$2" 2>/dev/null | sed -n 's/.* ttr_s=\([0-9]*\).*/\1/p' | head -1; }   # one-disk: not a path (the pin of the tree it is given: a base's own four repos)
container_key() { case "$1" in snobol4) echo sno-rungs;; icon) echo icn-rungs;; prolog) echo pl-rungs;; pascal) echo pas-rungs;; raku) echo raku-rungs;; snocone) echo snc-rungs;; rebus) echo reb-rungs;; esac; }
ext_of() { case "$1" in snobol4) echo sno;; icon) echo icn;; prolog) echo pl;; pascal) echo pas;; raku) echo raku;; rebus) echo reb;; snocone) echo sc;; scriptix) echo md;; esac; }
# A SUITE IS ON DISK IN ONE OF THREE FORMS, AND THE ONE LAUNCH READS ALL THREE UNDER THE SAME ALL.<ext> ALL.ref COMMAND LINE (the coo 2026-11-10, row
# cycle-a-suite-in-format-2-or-the-files-form-is-run-not-refused-sno-rungs-refused-three-laps; fmt2_dir_of and pkg_dir_of of corpus_suite_harness.py):
# the container (ALL.<ext> and ALL.ref), format 2 of a test folder (MULTI-LINERS.md or ONE-LINERS.<ext>, CIO-24), the files form of a package (a path column in
# ALL.csv, CIO-59, CIO-113). MEASURED: testing for the container alone refused all 24 cells of the SNOBOL4 master in laps 12, 13 and 14 (format 2 since
# 2026-11-10) and the cells of aisnobol and dotnet in lap 14 (the files form), each logged rc=2 secs=0.
suite_on_disk() {   # dir alls -> 0 when the launch can read a suite there
    local d="$1" a="$2"
    if [ -f "$a" ] && [ -f "$d/ALL.ref" ]; then return 0; fi
    if [ -f "$d/MULTI-LINERS.md" ] || [ -f "$d/ONE-LINERS.${a##*.}" ]; then return 0; fi
    [ -f "$d/ALL.csv" ] && head -1 "$d/ALL.csv" | tr -d '\r' | tr ',' '\n' | grep -qx path
}
# THE ROAD OF A PACKAGE IS ITS OWN DECLARATION (the coo 2026-11-11, row cycle-a-package-whose-contract-names-the-run-files-road-is-run-by-the-package-switch-fpc-first;
# run-switches step 12, CIO-118): a package in the files form whose CONTRACT.tsv carries the row road<TAB>run-files<TAB>evidence is run by the package
# switch (the launch takes --run-files: mode 3 in one scrip process, graded from its OUT directory); no row is the per-process road. The row is written
# only after the package read equal entry for entry on both roads; the evidence names that reading. The switch runs mode 3, so the flag needs m3.
road_flag() {   # dir -> prints --run-files when the package declares that road (never under a port engine: the switch is SCRIP's own)
    local d="$1"; [ -n "${PORT_ENV:-}" ] && return 0
    [ -f "$d/CONTRACT.tsv" ] && [ -f "$d/ALL.csv" ] || return 0
    case ",${S4E_MODES:-m3}," in *,m3,*) ;; *) return 0;; esac
    head -1 "$d/ALL.csv" | tr -d '\r' | tr ',' '\n' | grep -qx path || return 0
    awk -F'\t' '!/^#/ && $1 == "road" && $2 == "run-files" && $3 != "" {f = 1} END {exit !f}' "$d/CONTRACT.tsv" && printf '%s' --run-files
    return 0
}
# A SMALL ROW IS ONE CELL, RUN BY THE RUNNER THAT GRADES IT TODAY (the coo 2026-11-11, on Lon's word in the coo's window, verbatim: "get all test suites
# graded and plugged into new cycle runner."; MEASURED the same morning by util_cycle_inventory.py: the cycle launched 42 of the banner's 63 suites; the
# seven demos rows, the seven bench-ref rows and GNU source are kind small and no lap ever ran them, their rows last read by the coo's hand). Such a
# suite is not a package yet (its programs take per-program arguments, inputs, companion folders and, for Rebus, derived answers the builder cannot
# cut), so until each is converted (rows cycle-the-seven-demos-rows... and cycle-the-seven-bench-ref-rows..., CIO-22 F) its cell is the row's own
# runner under one run slot, asked not to write the suite row where it takes --no-write: it appends its progress rows and the cycle records the row
# from them in S4E_MODES like every other. The cap is a small multiple of the cell's last graded seconds (Lon 2026-11-05: a cap scales with the
# expected time), 3600 for a cell never graded (MEASURED 2026-11-11 09:18 by the coo's hand run: the Prolog demos, both modes, stood at 4 of 8 after 14 minutes on a box at CPU pressure 32, and the Pascal bench passed 600 s). THIS ARM GOES when no row of the table is kind small.
small_budget() {   # key -> seconds: five times the last graded seconds of the cell, at least 300, at most 3600; 3600 with no reading
    local s; s="$(awk -F'\t' -v k="$1" '$1 == k && $2 == "all" {print $3; exit}' "$ORDERF" 2>/dev/null)"
    case "$s" in ''|*[!0-9]*) echo 3600; return;; esac
    s=$(( s * 5 )); [ "$s" -lt 300 ] && s=300; [ "$s" -gt 3600 ] && s=3600; echo "$s"
}
# THE DOOR COMES FIRST: TOKEN, THEN BASE, THEN CLOCK (the cio 2026-11-17 14:5x CST, row cycle-a-cell-takes-its-core-token-before-its-base-and-its-clock-and-a-request-takes-it-first,
# built by the grader). MEASURED that hour: CORES.conf cores=8 grader=4, so the grader holds four tokens while the cycle runs eight fast cells, two slow ones and the requests,
# each of which took a base, started its clock and only then waited at the door inside util_run_slot.sh; SLOT_WAITS.tsv 20:00Z to 20:52Z read grader run waits n=110, median
# 46 s, max 1078 s; in lap 48 cells of seconds ended rc 124 having spent their bound at the door (art_of_prolog core 600 s, 8 s the lap before), and no base forwarded from
# 20:30Z to 20:50Z, all four pinned by waiters. So a cell or a request takes its run token in its own shell (s4e_slot_hold run, which exports S4E_RUN_SLOT_HELD and
# S4E_CORE_HELD, so util_run_slot.sh and the harness take no second one) before it holds a base and before its timeout starts: a waiter holds no base, and its bound counts
# its run alone. A REQUEST GOES FIRST AT THE DOOR: while it waits it leaves a ticket in $TMPDIR/cycle/door, and a lap cell tries for a token only while no ticket stands,
# so the next token freed is the request's (a free fast slot already took a pending request before any lap cell; the door now keeps that order). A wait of a second or
# more is one line of SLOT_WAITS.tsv as before. DOOR_EVENTS, set by --probe-door alone, names a file each step is appended to.
# THE LANES ARE AS WIDE AS THE DOOR (part 2 of the same row): the fast and slow widths are read from CORES.conf at each turn of the pool, so what cannot have a token waits in
# the cycle's own queue, where a pending request is served before any lap cell, never at the door holding nothing. grader=G: the slow lane 1 when G is under 6, else 2; the
# fast lane G less the slow lane less one token left for the patch drain and the row writes, at least 1. S4E_CYCLE_FAST (or S4E_CYCLE_WIDTH) and S4E_CYCLE_SLOW still win when
# set, and with no CORES.conf grader line the widths are 8 and 2 as before; --one runs one cell in one lane.
lane_widths() {   # sets WF and WS
    local g; g="$(s4e_cores_conf grader)"
    WS="${S4E_CYCLE_SLOW:-}"; case "$WS" in ''|*[!0-9]*) if [ -n "$g" ]; then if [ "$g" -lt 6 ]; then WS=1; else WS=2; fi; else WS=2; fi;; esac
    WF="${S4E_CYCLE_FAST:-${S4E_CYCLE_WIDTH:-}}"; case "$WF" in ''|*[!0-9]*|0) if [ -n "$g" ]; then WF=$(( g - WS - 1 )); else WF=8; fi;; esac
    [ "$WF" -ge 1 ] || WF=1
    [ "${MODE_ARG:-}" = --one ] && { WF=1; WS=0; }
    return 0
}
port_may_start() {   # slow_next slow_total slow_running port_running WS -> rc 0 when a port cell may start now: every slow cell started, the slow lane and the port's
    # one place free (a port cell counts in the slow lane's width), and no request pending (a request goes first, at the lanes as at the door)
    [ "$1" -ge "$2" ] && [ "$4" -lt 1 ] && [ $(( $3 + $4 )) -lt "${5:-1}" ] || return 1
    ! next_request f > /dev/null 2>&1 && ! next_request s > /dev/null 2>&1
}
# THE CELL NAMES ITS KEY AT THE DOOR (row harness-the-cycles-cell-names-its-key-at-the-door-and-writes-its-ledger-line; the chairman 2026-11-18 13:4x CST; MEASURED by developer_15 in the LEDGER of door step 4:
# the cycle took its token with the cell's words as a label and never a command, so under weights=on every cell and every request drew the class run's 90th percentile, 1155 millicores and 72 MB, whatever it
# graded, where the harness's own runs in the ledger read 843 millicores, 618 MB and 381 s). door_take takes the key as a third word, cell:SUITE:PARTITION or request:SUITE, and passes it as the take's command
# word, which the door's auto key reads with no code of its own; and a cell's launch runs under the ledger wrapper (util_cost_run.py, step 1) with that key, so each cell leaves ONE line in COSTS.tsv (class run,
# the key, its wall seconds, the rusage of its child) and has its own weight after a day. With no weights=on line the word is read by nothing, and the line is the data the weights will read.
cell_cost_args() {   # key -> COSTRUN, the words that put the ledger wrapper in front of a launch (none when S4E_COSTS=off or the wrapper is not in this tree)
    COSTRUN=(); [ "${S4E_COSTS:-}" = off ] && return 0
    [ -f "$S4E_HARNESS/scripts/util_cost_run.py" ] && COSTRUN=(python3 -I -S "$S4E_HARNESS/scripts/util_cost_run.py" --class run --key "${1//[^A-Za-z0-9_.:+,=-]/_}" --)
    return 0
}
door_take() {   # cell|request [what [key]] -> rc 0: this shell holds a run token (or there is no pool and it runs unbounded, as util_run_slot.sh does); rc 2: none within the door's bound
    local who="$1" what="${2:-}" kw="${3:-}" t0 rc bound tk="" waited=0
    kw="${kw//[^A-Za-z0-9_.:+,=-]/_}"
    t0=$(date +%s.%N); mkdir -p "$TMPDIR/cycle/door" 2> /dev/null
    if [ "$who" = request ]; then
        tk="$TMPDIR/cycle/door/req.$BASHPID"; : > "$tk"; [ -n "${DOOR_EVENTS:-}" ] && echo "WAIT request $what" >> "$DOOR_EVENTS"
        S4E_DOOR_PRIO=0 s4e_slot_hold run $kw; rc=$?; rm -f "$tk"
    else
        bound="$(s4e_cores_conf wait)"; bound="${bound:-1800}"
        if [ "$(s4e_cores_word weights)" = on ]; then   # THE WEIGHTED DOOR queues by arrival and serves a request first by its ticket's priority, so a cell waits inside the door, never in this poll
            S4E_DOOR_PRIO=1 s4e_slot_hold run $kw; rc=$?
        else
        while :; do
            if ! compgen -G "$TMPDIR/cycle/door/req.*" > /dev/null; then
                S4E_SLOT_WAIT_MAX=0 S4E_SLOT_WAITS=/dev/null s4e_slot_hold run $kw 2> /dev/null; rc=$?
                [ "$rc" = 2 ] || break
            fi
            [ "$waited" = 0 ] && { waited=1; [ -n "${DOOR_EVENTS:-}" ] && echo "WAIT cell $what" >> "$DOOR_EVENTS"; }
            awk -v a="$t0" -v b="$(date +%s.%N)" -v m="$bound" 'BEGIN {exit !(b - a >= m)}' && { rc=2; break; }
            sleep 0.5
        done
        fi
    fi
    [ "$rc" = 2 ] && { s4e_slot_note run-refused "$t0" "cycle $who $what"; return 2; }
    s4e_slot_note run "$t0" "cycle $who $what"; [ -n "${DOOR_EVENTS:-}" ] && echo "TOKEN $who $what" >> "$DOOR_EVENTS"
    return 0
}
run_cell() {   # key kind lang dir cell -> rc. THE ONE LAUNCH (Lon 2026-11-08 23:0x, in the coo's window, verbatim: "We want ONE UNIFIED test suite system. The same ALL.tsv files etc. Same layout in corpus. Same script. Same spec on attributes and environment." / "Get those deleted and get to work with a complete test suite system."): every cell, master or pkg, is corpus_suite_harness.py run over the suite's container ALL.<ext> and ALL.ref; a suite without one refuses rc 2, named, until its container is built
    local key="$1" kind="$2" lang="$3" dir="$4" cell="$5" ttr alls rc t0 out nw
    out="$TMPDIR/cycle/$key.$cell.log"
    door_take cell "$key $cell" "cell:$key:$cell" || { echo "REFUSE(2): no run token within the door's bound (CORES.conf wait); nothing ran (door_take)" > "$out"; echo "2 0"; return 2; }   # the token first, then the base and the clock
    t0=$(date +%s); cell_cost_args "cell:$key:$cell"
    local PORT_ENV=""
    if [ "$kind" = port ]; then PORT_ENV="$(port_env "$key")" || { echo "REFUSE(2): no build of the port for $key under $PORTS_TOP (port_refresh; CYCLE.log PORT lines)" > "$out"; echo "2 0"; return 2; }; fi
    if [ "$kind" = small ]; then
        ttr="$(small_budget "$key")"; nw=""; grep -q -- '--no-write' "$S4E_HARNESS/scripts/${dir%% *}" 2>/dev/null && nw=--no-write
        ( cd "$S4E" && "${COSTRUN[@]}" timeout -k 30 "$ttr" bash "$S4E_HARNESS/scripts/util_run_slot.sh" bash "$S4E_HARNESS"/scripts/$dir $nw ) > "$out" 2>&1 < /dev/null; rc=$?
        echo "$rc $(( $(date +%s) - t0 ))"; return "$rc"
    fi
    local T_SCRIP T_CORPUS T_HARNESS T_GITHUB
    on_base; pin "$BASE"; dir="$(tp "$BASE" "$dir")"; alls="$dir/ALL.$(ext_of "$lang")"   # a master or pkg cell runs on a base at origin's newest heads (choose_base)
    ttr="$(budget "$key" "$cell" "$BASE")"; [ -n "$ttr" ] || ttr=3600
    echo "CELL_BASE $BASE SCRIP=$(git -C "$T_SCRIP" rev-parse --short=10 HEAD) corpus=$(git -C "$T_CORPUS" rev-parse --short=10 HEAD) binary=$SBIN${PORT_ENV:+ port=$PORT_ENV}" > "$out"
    if ! suite_on_disk "$dir" "$alls"; then echo "REFUSE(2): no suite in $dir: no container ($alls and ALL.ref), no format 2 (MULTI-LINERS.md or ONE-LINERS.$(ext_of "$lang")), no files form (a path column in ALL.csv) -- the unified layout is owed (util_build_package_suite.py)" > "$out"; echo "2 0"; return 2; fi
    ( cd "$BASE" && env $PORT_ENV S4E_HOME="$BASE" S4E_SCRIP="$T_SCRIP" S4E_CORPUS="$T_CORPUS" S4E_HARNESS="$T_HARNESS" S4E_GITHUB="$T_GITHUB" SCRIP="$SBIN" RT_DIR="$RTD" SUITE_LIST_ALL=1 "${COSTRUN[@]}" timeout -k 30 "$ttr" bash "$T_HARNESS/scripts/util_run_slot.sh" python3 "$T_HARNESS/scripts/corpus_suite_harness.py" run "$alls" "$dir/ALL.ref" --lang "$lang" --modes "${S4E_MODES:-m3}" --partition "$cell" $(road_flag "$dir") ) >> "$out" 2>&1 < /dev/null; rc=$?   # one-disk: not a path (a base's own four repos, the tree this chunk grades)
    echo "$rc $(( $(date +%s) - t0 ))"
}
# THE TEST REQUESTS (the cio 2026-11-10, row bus-one-queue-the-grading-tube-retires-the-cycle-serves-the-test-requests-itself, CIO-82; the grade tube,
# its feeder and its worker retired): a request is one file test_requests/STAMP-SEAT-SUITE-N.req (seat, suite, table, filed, entries). It is PENDING while
# it sits in that folder, whatever fed= line an old feeder wrote. Before any cell is started the pool serves the oldest pending request as one more
# cell: the file moves to serving/ (a restart puts it back), the one launch runs its entries (entry:A,entry:B) in S4E_MODES under the budget of that
# entry cell, the suite row is recorded, and the file lands in done/ with graded=/rc= per entry and one served= line, as the grade worker wrote it.
RQ="${S4E_TEST_REQUEST_DIR:-/home/resources/postoffice/test_requests}"
# A REQUEST WAITS FOR THE TREE THAT HOLDS ITS ENTRIES (the coo 2026-11-11, row cycle-a-test-request-for-an-entry-the-cycles-tree-does-not-hold-yet-waits-for-the-next-sync).
# MEASURED: the cycle syncs once a lap; the cio's request for eight csnobol4 entries admitted at 04:5x was served at 04:53 on the tree of 02:28, each entry refused rc 2
# (PARTITION.tsv has no entry atn), and the request was spent. So a request is READY when every entry it names is a row of its suite's PARTITION.tsv in this tree, or
# when its file is older than this lap's sync (it has seen a sync: it is served and refuses as written, so a wrong request cannot wait for ever).
request_ready() {   # pending file -> 0: every request is ready. It used to wait for the lap's next sync when the root's partition lacked its entry
    # (MEASURED 2026-11-12: a worst wait of 445 min from filing to result); the request base is forwarded to origin before each request (run_request),
    # so the entry a seat just landed is there, and an entry origin lacks is refused rc 2 by the harness on that base, in seconds.
    return 0
}
# ONE REQUEST A SEAT AT A TIME, AND A LONG REQUEST IN THE SLOW LANE (the cio 2026-11-18 00:0x UTC, built by the grader; MEASURED 23:49:51Z to 23:59Z: no CELL and no
# REQUEST line, both fast lanes held by two requests of ONE seat, officer_02's rosetta-unicon prime programs, eight entries each under a 1020 s bound, a third of
# the same seat waiting behind them and officer_08's crypto request, which frees 22 programs, with no lane): next_request LANE passes over a pending request whose
# seat (the second field of its file name) already has one in serving, so one seat's burst never holds every lane; and a request any of whose entries declares
# timeout_s over S4E_CYCLE_LONG_REQ_SECS (300) in its suite's ALL.csv is a slow-lane job (req_long), served by `next_request s`, every other by `next_request f`.
req_seat() { basename "$1" | cut -d- -f2; }
req_long() {   # request file -> rc 0 when an entry it names declares timeout_s over S4E_CYCLE_LONG_REQ_SECS in its suite's ALL.csv
    local key ents dir csv
    key="$(sed -n 's/^suite=//p' "$1" | head -1)"; ents="$(sed -n 's/^entries=//p' "$1" | head -1)"
    dir="$(awk -F'\t' -v k="$key" '!/^#/ && $1 == k { d = ($2 == "master") ? "corpus/tests/" $3 : $5; print d; exit }' "$RUNNERS")"
    csv="$S4E_CORPUS/${dir#corpus/}/ALL.csv"; [ -n "$dir" ] && [ -f "$csv" ] || return 1
    awk -F, -v ents=",$(printf '%s' "$ents" | tr -s ' ' ',')," -v lim="${S4E_CYCLE_LONG_REQ_SECS:-300}" 'NR == 1 { for (i = 1; i <= NF; i++) { if ($i == "entry") ie = i; if ($i == "timeout_s") it = i }; next }
        ie && it && index(ents, "," $ie ",") && ($it + 0) > lim { f = 1 } END { exit !f }' "$csv"
}
next_request() {   # [f|s] -> the oldest pending request for that lane (f, the default: the short ones; s: the long ones) whose seat has none in serving
    local f lane="${1:-f}" seat
    for f in "$RQ"/*.req; do
        [ -f "$f" ] && request_ready "$f" || continue
        seat="$(req_seat "$f")"; compgen -G "$RQ/serving/*-$seat-*.req" > /dev/null && continue
        if req_long "$f"; then [ "$lane" = s ] || continue; else [ "$lane" = f ] || continue; fi
        printf '%s\n' "$f"; return 0
    done
    return 1
}
# THE BASE MOVES FORWARD EVERY CHUNK (the grader 2026-11-13; Lon, via the coo 12:1x, verbatim: "The cycle runner should be running chunks through and
# updating the code continuously every turn."; skill suites-and-grading section 9). MEASURED that noon by the coo: the lap cells graded on the grader root,
# which syncs only at a lap start, and lap 28 ran 1083 cells over about 11 hours, so 3273 of 3277 grader readings since 17:00Z were on SCRIP 530c2543b5,
# 34 commits behind origin, and no cure landed that day showed in a lap reading. THE BASES are up to S4E_CYCLE_BASES (4; 2 until 2026-11-14) worktrees wt-base<N> of the four
# repositories (s4e_worktree.sh, sparse with demos/ added, named for the row so no sweep takes them). MEASURED 2026-11-13 by the probe: a base is 1542 MB (SCRIP and its
# fetched build 374, the corpus 1148), and it cannot share the pristine's files (util_relink_root.py refuses: /tmp and /home/resources are two
# filesystems, and a hard link cannot join them), so two fit the seat's 4 GB of /tmp. Every cell, request and row write picks one at its start,
# under one lock (choose_base): the root fetches origin (refs and objects, its working tree untouched; at most every S4E_CYCLE_FETCH_SECS, 20); the
# current base is taken when it holds origin's four heads; else a base no chunk holds is forwarded to them (checkout detached, MEASURED 1 s), its binary
# found in the build cache by its SCRIP tree's key (else built once there, make -j8), and made current; with none free the chunk takes the current one,
# a turn behind. A chunk holds its base shared on fd 5 for its life (fd 8 until 2026-11-17, when the run token of lib_slots.sh, which is fd 8, came to be taken in the same shell) and a forward takes a base exclusive, so a base never moves under a chunk. The binary
# runs in place from the cache entry (SCRIP=, RT_DIR=; MEASURED: copying an entry out took 69 s). With no base to be had a chunk runs on the root, as before.
# THE BASES LIVE WHERE s4e_worktree.sh MAKES THEM, LINKED (officer_02 2026-11-13, row worktrees-live-on-home-and-hard-link-their-build, on the coo's ask: wt-base1
# and wt-base2 held 3.0 GB each of a /tmp under its floor): base_new makes a base by s4e_worktree.sh new --link, now on /home with its corpus, harness and .github
# hard-linked to the pristine (a base only checks out and reads), so the base top is that script's own top (--show-top), else /tmp/s4e. A forward's checkout writes
# each changed file as a new inode, a copy, so a base drifts from its links only by what origin changed since the base was made. A base on /tmp keeps serving until
# it is removed (S4E_WT_TOP=/tmp/s4e S4E_SEAT=grader s4e_worktree.sh rm base<N>), and base_new then makes it anew on /home.
BASE_TOP="${S4E_WT_TOP:-$(S4E_SEAT=grader bash "$S4E_HARNESS/scripts/s4e_worktree.sh" --show-top 2>/dev/null | sed -n 's/^WT top=\([^ ]*\) .*/\1/p')}"; BASE_TOP="${BASE_TOP:-/tmp/s4e}/grader"; NBASES="${S4E_CYCLE_BASES:-4}"; FETCH_SECS="${S4E_CYCLE_FETCH_SECS:-20}"
case "$NBASES" in ''|*[!0-9]*|0) NBASES=4;; esac
# FOUR BASES, SO A LONG CHUNK NEVER FREEZES THE BASE (the grader 2026-11-14, on the cfo's telegram 10:4x CST; MEASURED: from 15:28Z no base moved,
# all 639 readings since 16:00Z were stamped SCRIP 83c939215d and corpus 7c260f9b0 while origin's corpus moved at 15:46Z and SCRIP twice, and the cfo's
# 17 gate_cases_prolog requests read RED where seniors on current trees read PASS). The cause: a forward never moves the current base, and takes any
# other base only exclusive and without waiting; one slow-lane cell (a 5 h budget) held wt-base2 shared for 78 minutes, so with two bases no forward
# could happen and every chunk fell back to the stale current one. A base is held for a chunk's life, so the bases needed are the slow lanes, each of
# which may pin one for hours, plus the current, plus one free to forward: S4E_CYCLE_SLOW (2) + 2 = 4. Since the one-disk cutover the bases live on
# /home/resources/worktrees, not the 4 GB /tmp the count of two was sized for (1.5 GB a base; /home 161 GB free that hour).; case "$FETCH_SECS" in ''|*[!0-9]*) FETCH_SECS=20;; esac
heads_of() { local r; for r in SCRIP harness corpus .github; do git -C "$(td "$1" "$r")" rev-parse "${2:-HEAD}" 2>/dev/null || echo -; done | tr '\n' ' '; }
base_bin() {   # base -> "SCRIP_BIN RT_DIR": the base's OWN SCRIP/scrip and SCRIP/out, one build of its SCRIP tree; rc 2 (a line on stderr) when it cannot be had   # one-disk: not a path (a comment: the base's own clone)
    # THE BASE RUNS ITS OWN BINARY, NEVER THE CACHE'S FILES IN PLACE (the coo and officer_08 2026-11-13 17:4x CST, MEASURED: scrip resolves a linked
    # library relative to its own binary, so the cache's scrip tried /home/resources/builds/scrip/<key>/../corpus/... and every program that links one
    # printed nothing, false FAILs from 23:20Z: rosetta-icon 62, rakudo-t 54, gate_cases_pascal 32, unicon-uni 11; and a base's own out/ was left from
    # the build it was made with, a runtime of another tree). make in the base fetches the cache's entry for the tree (FETCHED, the files copied in) or
    # builds it; the pair is then checked to be one build: out/buildinfo names the tree's key and scrip is the entry's byte for byte.
    local rt k c
    ( cd "$1/SCRIP" && make -j8 ) > "$TMPDIR/cycle/base.make.log" 2>&1 < /dev/null || { echo "REFUSE(2): make failed in $1 for SCRIP $(git -C "$1/SCRIP" rev-parse --short=10 HEAD) (base.make.log)" >&2; return 2; }
    rt="$(cd "$1/SCRIP" && env -u MAKEFLAGS -u MFLAGS -u MAKELEVEL make -s --no-print-directory --eval='s4e-print-rt-tag: ; @echo $(RT_TAG)' s4e-print-rt-tag 2>/dev/null)"
    k="$(bash "$1/harness/scripts/util_build_cache.sh" key --root "$1/SCRIP" --tag "$rt" 2>/dev/null)"; c="${S4E_BUILD_CACHE_DIR:-/home/resources/builds/scrip}/$k"
    [ -x "$1/SCRIP/scrip" ] && [ -e "$1/SCRIP/out/libscrip_rt.so" ] || { echo "REFUSE(2): $1 has no scrip and out/libscrip_rt.so after make" >&2; return 2; }
    if [ -n "$k" ] && [ -x "$c/scrip" ]; then
        grep -qx "key $k" "$1/SCRIP/out/buildinfo" 2>/dev/null && cmp -s "$1/SCRIP/scrip" "$c/scrip" || { echo "REFUSE(2): $1's scrip and out/ are not one build of key $k (buildinfo or the binary differ)" >&2; return 2; }
    fi
    echo "$1/SCRIP/scrip $1/SCRIP/out"
}
base_new() {   # N -> wt-base<N> made at origin's heads; rc 2 when it cannot be made
    local b="$BASE_TOP/wt-base$1"
    [ -d "$b/SCRIP" ] && { [ -f "$b/.s4e-hold" ] || : > "$b/.s4e-hold"; return 0; }
    ( cd "$S4E" && S4E_SEAT=grader bash "$S4E_HARNESS/scripts/s4e_worktree.sh" new "base$1" --link --row cycle-greased-lightning-grader ) > "$TMPDIR/cycle/base$1.new.log" 2>&1 < /dev/null
    [ -d "$b/SCRIP" ] || { echo "REFUSE(2): the base $b could not be made (base$1.new.log)" >&2; return 2; }
    git -C "$b/corpus" sparse-checkout add /demos/ >> "$TMPDIR/cycle/base$1.new.log" 2>&1   # sparse, demos in (pkg rows); benchmarks out (small rows run on the root). MEASURED 2026-11-13: --full made a 3014 MB base from the full root, sparse plus demos 1542 MB
    : > "$b/.s4e-hold"; log "BASE $b made $(du -sm "$b" 2>/dev/null | cut -f1) MB"; return 0
}
choose_base() {   # sets BASE, SBIN and RTD, and holds BASE shared on fd 5 until this shell exits; rc 2 (a line on stderr) when no base holds a build
    local now last want cur n b r bb
    exec 6> "$TMPDIR/cycle/base.lock"; flock -x 6
    now=$(date +%s); last=$(stat -c %Y "$TMPDIR/cycle/base.fetched" 2>/dev/null || echo 0)
    if [ $(( now - last )) -ge "$FETCH_SECS" ]; then for r in SCRIP harness corpus .github; do timeout -k 5 120 git -C "$(td "$S4E" "$r")" fetch -q origin main 2>/dev/null; done; : > "$TMPDIR/cycle/base.fetched"; fi
    want="$(heads_of "$S4E" origin/main)"; cur="$(cat "$TMPDIR/cycle/base.current" 2>/dev/null)"
    if [ -z "$cur" ] || [ ! -f "$cur/.s4e-bin" ] || ! grep -q "^$cur/SCRIP/scrip " "$cur/.s4e-bin" || [ "$(heads_of "$cur")" != "$want" ]; then   # a .s4e-bin that names another tree's files (the build cache's, before 2026-11-13 17:5x) is stale
        for (( n = 1; n <= NBASES; n++ )); do
            b="$BASE_TOP/wt-base$n"; [ "$b" = "$cur" ] && continue
            base_new "$n" 2>> "$TMPDIR/cycle/base.log" || continue
            exec 5< "$b/.s4e-hold"; flock -n -x 5 || { exec 5<&-; continue; }
            for r in SCRIP harness corpus .github; do git -C "$b/$r" checkout -q --detach origin/main 2>> "$TMPDIR/cycle/base.log" || break; done
            bb=1; [ "$(heads_of "$b")" = "$want" ] && { flock -u 6; base_bin "$b" > "$b/.s4e-bin.tmp" 2>> "$TMPDIR/cycle/base.log" && bb=0; flock -x 6; }   # the make (a fetch, about a minute) runs with the base held exclusive and the lock open, so other chunks launch meanwhile
            if [ "$bb" = 0 ]; then
                mv -f "$b/.s4e-bin.tmp" "$b/.s4e-bin"; printf '%s\n' "$b" > "$TMPDIR/cycle/base.current"; cur="$b"; flock -s 5
                log "BASE $b forward SCRIP=$(git -C "$b/SCRIP" rev-parse --short=10 HEAD) corpus=$(git -C "$b/corpus" rev-parse --short=10 HEAD) harness=$(git -C "$b/harness" rev-parse --short=10 HEAD)"; break
            fi
            rm -f "$b/.s4e-bin" "$b/.s4e-bin.tmp"; exec 5<&-
        done
    fi
    [ -n "$cur" ] && [ -f "$cur/.s4e-bin" ] && grep -q "^$cur/SCRIP/scrip " "$cur/.s4e-bin" || { flock -u 6; exec 6>&-; echo "REFUSE(2): no base holds a build of its own (base.log)" >&2; return 2; }   # a lap cell then runs on the root (on_base), a request waits
    [ "$(readlink -f "/proc/$BASHPID/fd/5" 2>/dev/null)" = "$(readlink -f "$cur/.s4e-hold")" ] || { exec 5< "$cur/.s4e-hold"; flock -s 5; }
    BASE="$cur"; read -r SBIN RTD < "$cur/.s4e-bin"; flock -u 6; exec 6>&-; return 0
}
base_holds() {   # base "SCRIP harness corpus .github heads" -> 0 when every one of those heads is an ancestor of (or is) the base's own head in that repo
    local b="$1" r h i=0; local -a hs=($2)
    for r in SCRIP harness corpus .github; do h="${hs[$i]:--}"; i=$((i+1)); [ "$h" = - ] && continue; git -C "$b/$r" merge-base --is-ancestor "$h" HEAD 2>/dev/null || return 1; done
    return 0
}
on_base() {   # the same, falling back to the root and its own build when no base can be had, so a chunk never refuses for want of a base
    choose_base 2>> "$TMPDIR/cycle/base.log" && return 0
    BASE="$S4E"; SBIN="$S4E_SCRIP/scrip"; RTD="$S4E_SCRIP/out"; log "BASE none: the chunk runs on the root (base.log)"
}
run_request() {   # serving file -> "rc secs" on stdout; the harness log in $TMPDIR/cycle/req.<name>.log
    local f="$1" name key ents row kind lang dir alls ttr t0 rc out
    name="$(basename "$f")"; out="$TMPDIR/cycle/req.$name.log"; t0=$(date +%s)
    key="$(sed -n 's/^suite=//p' "$f" | head -1)"; ents="$(sed -n 's/^entries=//p' "$f" | head -1 | tr -s ' ,' '\n\n' | grep -v '^$' | tr '\n' ',' | sed 's/,$//')"
    row="$(awk -F'\t' -v k="$key" '!/^#/ && $1 == k && ($2 == "master" || $2 == "pkg" || ($2 == "port" && $4 == "corpus_suite_harness.py" && $5 ~ /^corpus\//)) {print $2 "\t" $3 "\t" $5; exit}' "$RUNNERS")"
    local PORT_ENV=""; case "$row" in port*) PORT_ENV="$(port_env "$key")" || { echo "REQUEST_PORT: no build of the port for $key under $PORTS_TOP; it is pending again" > "$out"; echo "3 $(( $(date +%s) - t0 ))"; return; };; esac
    [ -n "$row" ] && [ -n "$ents" ] || { echo "REFUSE(2): suite $key has no master or pkg row of SUITE_RUNNERS.tsv, or the request names no entries" > "$out"; echo "2 0"; return; }
    IFS=$'\t' read -r kind lang dir <<< "$row"; { [ "$kind" = master ] || [ "$dir" = "corpus/tests/$lang" ]; } && dir="$S4E/corpus/tests/$lang" || dir="$S4E/$dir"   # one-disk: not a path (the root's spelling, as cells writes it; column 5 of SUITE_RUNNERS.tsv is a path from the root; tp respells it for the base below)
    alls="$dir/ALL.$(ext_of "$lang")"
    # A REQUEST READS THE TREE THAT HOLDS ITS LANDING (junior_09 2026-11-13, MEASURED: request 20261113T223938-junior_09-gate_cases_snobol4-493276 was
    # graded at 22:40:46Z on corpus bc7da5229 although origin held the cure b30cac7ee since 22:38:47Z, the root fetched it at 22:39:53Z, and base 1 was
    # forwarded to it at 22:40:35Z: base 1 was held when the request chose, so it took base 2 a turn behind and read a false FAIL). A request fetches
    # origin at once, whatever the rate, and waits until its base holds every head origin had then (each an ancestor of the base's head), trying every
    # 15 s for S4E_REQ_FRESH_WAIT seconds (900); only past that does it grade a turn behind, and the log says REQUEST_BASE_STALE.
    door_take request "$name" "request:$key" || { echo "REQUEST_DOOR: no run token within the door's bound; it is pending again" >> "$out"; echo "3 $(( $(date +%s) - t0 ))"; return; }   # the token first, then the base and the clock
    rm -f "$TMPDIR/cycle/base.fetched"
    cell_cost_args "request:$key"
    local want0 tq; tq=$(( $(date +%s) + ${S4E_REQ_FRESH_WAIT:-900} ))
    choose_base 2>> "$out" || { echo "3 $(( $(date +%s) - t0 ))"; return; }   # a request runs on origin's newest heads, never the root's (no fallback); 3: no base yet, it is pending again
    want0="$(heads_of "$S4E" origin/main)"
    until base_holds "$BASE" "$want0"; do
        [ "$(date +%s)" -ge "$tq" ] && { echo "REQUEST_BASE_STALE $BASE: no base reached origin's heads of the request ($want0) in ${S4E_REQ_FRESH_WAIT:-900} s; graded a turn behind" >> "$out"; break; }
        exec 5<&-; sleep 15; choose_base 2>> "$out" || { echo "3 $(( $(date +%s) - t0 ))"; return; }
    done
    local T_SCRIP T_CORPUS T_HARNESS T_GITHUB; pin "$BASE"
    dir="$(tp "$BASE" "$dir")"; alls="$(tp "$BASE" "$alls")"; echo "REQUEST_BASE $BASE SCRIP=$(git -C "$T_SCRIP" rev-parse --short=10 HEAD) corpus=$(git -C "$T_CORPUS" rev-parse --short=10 HEAD) binary=$SBIN" >> "$out"
    # THE BOUND IS READ FROM THE BASE THE REQUEST RUNS ON (senior_01 2026-11-13, MEASURED: it was read from the grader root's ALL.csv before the forward, so
    # puzzles hakank_swi_euler14, whose timeout_s origin had raised to 3600 at corpus dd98b6587, was killed at ttr 420 s though it answers in 299 s)
    ttr="$(budget "$key" "entry:$ents" "$BASE")"; [ -n "$ttr" ] || ttr=1800
    ( cd "$BASE" && env $PORT_ENV S4E_HOME="$BASE" S4E_SCRIP="$T_SCRIP" S4E_CORPUS="$T_CORPUS" S4E_HARNESS="$T_HARNESS" S4E_GITHUB="$T_GITHUB" SCRIP="$SBIN" RT_DIR="$RTD" SUITE_LIST_ALL=1 "${COSTRUN[@]}" bash "$T_HARNESS/scripts/util_run_slot.sh" timeout -k 30 "$ttr" python3 "$T_HARNESS/scripts/corpus_suite_harness.py" run "$alls" "$dir/ALL.ref" --lang "$lang" --modes "${S4E_MODES:-m3}" --partition "entry:${ents//,/,entry:}" $(road_flag "$dir") ) >> "$out" 2>&1 < /dev/null; rc=$?   # one-disk: not a path (a base's own four repos, the tree this chunk grades)
    [ "$kind" = master ] && record_suite "$lang"; { [ "$kind" = pkg ] || [ "$kind" = port ]; } && record_pkg "$key"
    echo "$rc $(( $(date +%s) - t0 ))"; }
finish_request() {   # name rc secs: the file lands in done/ with its per-entry verdicts and one served= line
    local name="$1" rc="$2" secs="$3" s="$RQ/serving/$1" e erc body tree n=0
    # THE VERDICT NAMES THE TREE IT WAS GRADED ON (the grader 2026-11-14, on the coo's telegram 11:3x CST and the cfo's measurement: every served
    # request read tree=83c939215, the grader root's SCRIP, which no request runs on since the moving base; and a request refused for want of a base
    # before the first build of a restart was filed as an answer, rc 2, so a junior's close read it as a verdict). The tree is the SCRIP of the
    # REQUEST_BASE line its own run logged; a request with no such line was graded on no base and says so. A request no base can take yet is rc 3
    # in run_request and goes back to pending (REQUEST_PENDING in CYCLE.log), never to done/.
    tree="$(sed -n 's/^REQUEST_BASE [^ ]* SCRIP=\([0-9a-f]*\) .*/\1/p' "$TMPDIR/cycle/req.$name.log" 2>/dev/null | tail -1 | cut -c1-9)"; tree="${tree:-no-base}"; body="$(cat "$s" 2>/dev/null)"
    for e in $(sed -n 's/^entries=//p' "$s" | head -1 | tr ',' ' '); do
        erc="$rc"; [ "$rc" = 1 ] && { grep -qE "^  (FAIL|CRASH|HANG|UNPROVEN) [^ ]+ ([^ ]+__)?$e[: ]" "$TMPDIR/cycle/req.$name.log" 2>/dev/null && erc=1 || erc=0; }
        body="$body"$'\n'"graded=$e"$'\n'"rc=$erc"; n=$((n+1)); done
    printf '%s\nserved=%s tree=%s rc=%s rows=%s by=cycle secs=%s\n' "$body" "$(TZ=America/Chicago date '+%F %T CST')" "$tree" "$rc" "$n" "$secs" > "$RQ/done/$name" && rm -f "$s"
    log "REQUEST lap=$lap $name rc=$rc secs=$secs entries=$n"; }
record_suite() {   # lang -> the rungs suite row of that language, as the grade worker's record step writes it
    local k; k="$(container_key "$1")"; [ -n "$k" ] || return 0
    record_row "$k"
}
record_pkg() {   # key -> that pkg row of SUITES.tsv, from its progress rows in S4E_MODES (the cycle exports m3), after the row's last cell
    record_row "$1"
}
# A REFUSED RECORD IS SAID, NEVER SWALLOWED (the grader 2026-11-12; Lon, in the grader's window, verbatim: "It was rumored that all test suites ran
# multiple times last night, but the banner is still screwed. Anybody on the problem?"). MEASURED that day: the cells of logtalk, sno-rungs, pl-rungs,
# raku-rungs, rosetta-pascal, unitests, stanford-pascal, tply and pas-rungs graded every lap, and from-progress refused each row write (an unstamped
# denominator move, or 48 unread rows) into record.log alone, so their banner rows stood days old and nothing said so. Each refusal is now a
# RECORD_REFUSED line in CYCLE.log and a line of CYCLE.refused (key TAB ts TAB the refusal), which the Stop banner shows; a write that lands clears it.
# THE CYCLE CURES ITS OWN REFUSALS (the grader 2026-11-13; Lon, in the grader's window, verbatim: "You need to fix the REFUSALS instead of just
# appending errors at the end of the banner."; MEASURED that hour: 24 rows held in CYCLE.refused, 11 a denominator move with no stamp, 11 a key with
# no SUITES.tsv row, 2 unread entries). A suite's row is written from the progress store with --partial (an unread entry counts as not passing, the
# total is the whole population); a key of SUITE_RUNNERS.tsv with no row gets one (util_suite_banner.py --open-row); a denominator move is stamped
# with the corpus commit that last changed the suite's table (the honest-denominator rule, CEO-546, asks a move to name why; in the moving sandbox,
# skill suites-and-grading section 9, the why is that commit). CYCLE.refused keeps only what is still refused, for keys the cycle still runs.
record_once() {   # key stamp -> from-progress output; rc its exit
    local T_SCRIP T_CORPUS T_HARNESS T_GITHUB; pin "${BASE:-$S4E}"
    ( cd "${BASE:-$S4E}" && S4E_HOME="${BASE:-$S4E}" S4E_SCRIP="$T_SCRIP" S4E_CORPUS="$T_CORPUS" S4E_HARNESS="$T_HARNESS" S4E_GITHUB="$T_GITHUB" S4E_CRITERION_CHANGED="$2" timeout -k 30 900 python3 -I "$T_HARNESS/scripts/util_score_row.py" from-progress --suite "$1" --partial 2>&1 < /dev/null )   # one-disk: not a path (the graded tree's own four repos, a base or this root)
}
runner_row() {   # key -> "kind lang dir" of its SUITE_RUNNERS.tsv row, dir from the corpus root
    awk -F'\t' -v k="$1" '!/^#/ && $1 == k { d = ($2 == "master") ? "tests/" $3 : $5; sub(/^corpus\//, "", d); print $2 "\t" $3 "\t" d; exit }' "$RUNNERS"
}
# A NICK IS THE LANGUAGE'S PREFIX, THEN THE NAME, WHOLE WORDS (the grader 2026-11-14; Lon 07:3x CST, in the grader's window, verbatim: "Your names are
# not consistent PasRosetta versus RosettaSnobo. get it right."): the cut of 2026-11-13 camel-cased the key and cut it at 12 characters, so rosetta-snobol4
# read RosettaSnobo beside PasRosetta and ProRosetta, and power_of_prolog read PowerOfProlo. The nick is the prefix (Sno Icn Uni Pro Pas Rak Snc Reb Tix;
# Uni for an icon key naming unicon or uni), then the key's other words capitalised, the language's own names and "of" and "the" dropped, demos read
# Demo as the table spells it, the last word dropped while it is over 12 (metalevel_contests ProMetalevel); one word still over 12 prints nothing and
# --open-row refuses, so a row is named by hand (util_suite_banner.py --nick), never cut mid-word. rosetta-raku RakRosetta, rosetta-unicon UniRosetta,
# uni_ipl UniIpl, power_of_prolog ProPower. A row named by hand keeps its name (Gimpel, Logtalk, PrologCafe): the rule names only a row the cycle opens.
cycle_nick() {   # key lang -> the banner nick of a row the cycle opens: prefix and whole words, at most 18 characters (Lon 2026-11-15: the full language prefix, at most 18), or nothing
    local ab drop; case "$2" in snobol4) ab=Snobol4 drop="snobol4 snobol sno";; icon) ab=Icon drop="icon icn";; prolog) ab=Prolog drop="prolog pl pro";; pascal) ab=Pascal drop="pascal pas";; raku) ab=Raku drop="raku rak";; snocone) ab=Snocone drop="snocone snc";; rebus) ab=Rebus drop="rebus reb";; scriptix) ab=Scrip drop="scriptix tix";; *) ab=X drop="";; esac
    case "$1" in gate_cases_*) echo "${ab}Cases"; return 0;; esac
    case "$2:-$1-" in icon:*[-_]uni[-_]*|icon:*[-_]unicon[-_]*) ab=Unicon drop="$drop unicon uni";; esac
    printf '%s' "$1" | awk -F'[-_]' -v ab="$ab" -v drop="$drop of the" 'BEGIN { n = split(drop, d, " "); for (i = 1; i <= n; i++) skip[d[i]] = 1 }
        { m = 0; for (i = 1; i <= NF; i++) if ($i != "" && !($i in skip)) w[++m] = ($i == "demos") ? "Demo" : toupper(substr($i, 1, 1)) substr($i, 2)
          while (m > 0) { s = ab; for (i = 1; i <= m; i++) s = s w[i]; if (length(s) <= 18) { print s; exit } m-- } }'
}
record_row() {   # key -> the suite's row from the progress store; a refusal the cycle cannot cure is logged and held in CYCLE.refused
    local o rc r R="$PROG/CYCLE.refused" kind lang dir mv st c
    IFS=$'\t' read -r kind lang dir <<< "$(runner_row "$1")"
    # A SMALL ROW IS WRITTEN WHERE ITS CELL RAN, ON THE ROOT (the grader 2026-11-13, MEASURED: the seven *-bench-ref rows graded rc 0 on the root every lap
    # and every one of their writes refused "no suite table for key", the bases being sparse without corpus/benchmarks/); a master or pkg row is written
    # on the newest base, its population and stamp that base's tables, held shared while the row is written
    if [ "$kind" = small ]; then local BASE="$S4E"; else on_base; fi
    o="$(record_once "$1" "")"; rc=$?
    if [ "$rc" -ne 0 ] && printf '%s\n' "$o" | grep -q "no suite key $1 in" && [ -n "$kind" ]; then
        o="$o
$( cd "$BASE" && python3 -I "$(td "$BASE" harness)/scripts/util_suite_banner.py" --open-row "$1" "$(cycle_nick "$1" "$lang")" "🧪" "$lang" 2>&1 )"   # one-disk: not a path (the base's own harness, the tree graded)
        o="$o
$(record_once "$1" "")"; rc=$?
    fi
    if [ "$rc" -ne 0 ] && mv="$(printf '%s\n' "$o" | grep -oE 'denominator moves [0-9]+ -> [0-9]+' | tail -1)" && [ -n "$mv" ] && [ -n "$dir" ]; then
        c="$(git -C "$(td "$BASE" corpus)" log -1 --format='%h %s' -- "$dir" 2>/dev/null | tr '\t|' '  ' | cut -c1-140)"
        st="$(date +%F):${mv#denominator moves }, the table ${dir} last moved at corpus ${c:-unknown} (stamped by the cycle)"
        o="$o
$(record_once "$1" "$st")"; rc=$?
    fi
    printf '%s\n' "$o" >> "$TMPDIR/cycle/record.log"
    r=""; [ "$rc" -ne 0 ] && { r="$(printf '%s\n' "$o" | grep -E 'REFUSE' | tail -1 | cut -c1-240)"; [ -n "$r" ] || r="rc=$rc, no refusal line"; log "RECORD_REFUSED lap=${lap:-?} $1 rc=$rc $r"; }
    ( flock 9; { awk -F'\t' -v k="$1" 'NR == FNR { if (!/^#/) run[$1] = 1; next } $1 != k && ($1 in run)' "$RUNNERS" "$R" 2>/dev/null; [ -n "$r" ] && printf '%s\t%s\t%s\n' "$1" "$(now)" "$r"; } > "$R.tmp"; mv -f "$R.tmp" "$R" ) 9> "$R.lock"
    return 0
}
graded_this_lap() {   # key -> rc 0 when a cell of this lap graded that suite (rc 0 or 1); read from the log, so a restart mid-suite still knows
    grep -qE " CELL lap=$lap [0-9]+/[0-9]+ $(printf '%s' "$1" | sed 's/[.[\*^$]/\\&/g') [^ ]+ rc=[01] " "$LOG" 2>/dev/null
}
lap_start() {
    PORT_NOTE_LAP="$1"   # ports_on logs PORT-SKIPPED once this lap for an engine that emits no cells
    local _pe; for _pe in $CYCLE_PORTS; do ( port_refresh "$_pe" ) > /dev/null 2>&1 < /dev/null & done   # a port at origin's head is built in the background while the newest built folder serves
    local sy mk
    # THE GRADER ROOT'S OWN RENDERING NEVER BLOCKS ITS SYNC (the cio 2026-11-10; MEASURED: sync_rc=1 at every lap start since lap 2, sync.log
    # "Your local changes to the following files would be overwritten by merge: SCORE.md", the grader root's .github held at 75efb44b0 while origin
    # moved to 21c79e39a). Since 2026-11-12 the record step renders into S4E_SCORE_MD, the cycle's scratch (above), so the root stays clean;
    # the restore stays for a hand run in this root, and after the sync the scratch is seeded from the root's SCORE.md as origin has it.
    if [ "$(git -C "$S4E_GITHUB" status --porcelain --untracked-files=no 2>/dev/null)" = " M SCORE.md" ]; then git -C "$S4E_GITHUB" checkout -q -- SCORE.md >> "$TMPDIR/cycle/sync.log" 2>&1; fi
    ( cd "$S4E" && bash "$S4E_HARNESS/scripts/util_sync_root.sh" ) >> "$TMPDIR/cycle/sync.log" 2>&1 < /dev/null; sy=$?
    _score_seed="$S4E_GITHUB/SCORE.md"; [ ! -s "$PROG/SCORE.md" ] || _score_seed="$PROG/SCORE.md"
    [ ! -f "$_score_seed" ] || cp -f "$_score_seed" "$S4E_SCORE_MD" 2>> "$TMPDIR/cycle/sync.log"
    [ ! -f "$S4E_SCORE_MD" ] || [ -w "$S4E_SCORE_MD" ] || chmod u+w "$S4E_SCORE_MD"
    : > "$TMPDIR/cycle/lap.sync"   # the marker request_ready compares a pending request with: a request filed after it may name what the next sync brings
    ( cd "$S4E_SCRIP" && make -j8 ) >> "$TMPDIR/cycle/make.log" 2>&1 < /dev/null; mk=$?
    log "LAP $1 start sync_rc=$sy make_rc=$mk scrip=$(git -C "$S4E_SCRIP" rev-parse --short=9 HEAD 2>/dev/null) corpus=$(git -C "$S4E_CORPUS" rev-parse --short=9 HEAD 2>/dev/null)"
    [ "$mk" = 0 ] || log "LAP $1 MAKE_FAILED rc $mk (see $TMPDIR/cycle/make.log): the lap goes on; a master or pkg cell runs on a base and its own binary, a small row on the root may refuse"   # EVERY TURN GOES ON (Lon 2026-11-13 14:0x CST, in the grader's window, verbatim: "Rather at each TURN, you should update if needed and continue another TURN regardless.")
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
if [ "$MODE_ARG" = --record ]; then k="${2:?usage: s4e_cycle.sh --record KEY}"; record_row "$k"; grep -P "^\Q$k\E\t" "$PROG/CYCLE.refused" 2>/dev/null && exit 1; echo "RECORDED $k"; exit 0; fi   # one row written as the cycle writes it (the grader 2026-11-13)
if [ "$MODE_ARG" = --list ]; then cells | order_cells; echo "CELLS $(cells | wc -l)"; exit 0; fi
if [ "$MODE_ARG" = --probe-port ]; then   # THE PORTS' PROBE (row cycle-the-port-rows-are-cells-of-the-cycle): an order of events and of lists, never a clock
    [ -n "${S4E_DOOR_PROBE_T:-}" ] || { echo "REFUSE(2): --probe-port runs only in the sandbox its own first lines make"; exit 2; }
    T="$S4E_DOOR_PROBE_T"; a1=RED; a2=RED; a3=RED; a4=RED
    # arm 1, the order: a port cell waits for every slow cell to start, for the slow lane and its own place, and for a pending request; and it sorts after every
    # SCRIP cell, a sprint of its own language notwithstanding
    o1=""; port_may_start 0 2 0 0 1 && o1="${o1}slow-left "; port_may_start 2 2 1 0 1 && o1="${o1}slow-busy "; port_may_start 2 2 0 1 2 && o1="${o1}port-busy "
    : > "$RQ/probe.req"; port_may_start 2 2 0 0 1 && o1="${o1}request "; rm -f "$RQ/probe.req"; port_may_start 2 2 0 0 1 || o1="${o1}clear-held "
    printf 'name=PROBE\nlang=snobol4\n' > "$T/sprint.conf"
    f1="$(printf 'x@jvm\tport\tsnobol4\td\tcore\ny\tpkg\tprolog\td\tcore\nz\tpkg\tsnobol4\td\tcore\n' | ORDERF="$T/no.order" FIRSTF="$T/no.first" SPRINTF="$T/sprint.conf" order_cells | cut -f1 | tr '\n' ' ')"
    h1=0; SPRINTF="$T/sprint.conf" sprint_held x@jvm prolog core 900 && h1=1
    [ -z "$o1" ] && [ "$f1" = "z y x@jvm " ] && [ "$h1" = 0 ] && a1=ok
    # arm 2, the list: with no port built, the lap's cells are the cells with no port at all; with one built and its check passing, its cells join the list
    printf '# probe table\nsnoflake\tpkg\tsnobol4\tcorpus_suite_harness.py\tcorpus/packages/snobol4/snoflake_suite\nsnoflake@jvm\tport\tsnobol4\tcorpus_suite_harness.py\tcorpus/packages/snobol4/snoflake_suite\n' > "$T/runners.tsv"
    l0="$(RUNNERS="$T/runners.tsv" CYCLE_PORTS="" cells | md5sum)"; lnone="$(RUNNERS="$T/runners.tsv" CYCLE_PORTS="jvm dotnet" cells | md5sum)"
    mkdir -p "$PORTS_TOP/snobol4jvm-probe0001"; : > "$PORTS_TOP/snobol4jvm-probe0001/.built"
    lb="$(RUNNERS="$T/runners.tsv" CYCLE_PORTS="jvm" S4E_CYCLE_PORT_CHECK=true cells | grep -c '^snoflake@jvm	port	')"
    lbad="$(RUNNERS="$T/runners.tsv" CYCLE_PORTS="jvm" S4E_CYCLE_PORT_CHECK=false cells | grep -c '^snoflake@jvm	')"
    [ "$l0" = "$lnone" ] && [ "$lb" -ge 1 ] && [ "$lbad" = 0 ] && a2=ok
    # arm 3, the launch: a port cell runs under S4E_ENGINE, the build folder and mode 3, on a stand-in base whose harness writes what it was given
    mkdir -p "$T/base/harness/scripts" "$T/base/corpus/pkg" "$T/base/SCRIP" "$T/base/.github"; : > "$T/base/corpus/pkg/ALL.sno"; : > "$T/base/corpus/pkg/ALL.ref"
    printf '#!/bin/bash\nexec "$@"\n' > "$T/base/harness/scripts/util_run_slot.sh"
    printf 'import os, sys\nopen(os.environ["PROBE_OUT"], "w").write("engine=%%s root=%%s args=%%s\\n" %% (os.environ.get("S4E_ENGINE", ""), os.environ.get("S4E_JVM_ROOT", ""), " ".join(sys.argv[1:])))\nprint("SUITE_BOARD probe m3_n=1 m3_pass=1")\n' > "$T/base/harness/scripts/corpus_suite_harness.py"
    on_base() { BASE="$T/base"; SBIN=/bin/true; RTD="$T"; }; budget() { echo 60; }
    ( PROBE_OUT="$T/launch" run_cell snoflake@jvm port snobol4 "$T/base/corpus/pkg" core > "$T/res.l" 2> /dev/null ); read -r rcl _ < "$T/res.l"
    g3="$(cat "$T/launch" 2> /dev/null)"
    case "$g3" in "engine=jvm root=$PORTS_TOP/snobol4jvm-probe0001 args="*"--modes m3"*) [ "$rcl" = 0 ] && a3=ok;; esac
    # arm 4, the note: an engine with no built folder logs one PORT-SKIPPED line a lap, never two
    rm -rf "$PORTS_TOP"/snobol4jvm-*; : > "$LOG"
    PORT_NOTE_LAP=7 ports_on > /dev/null; PORT_NOTE_LAP=7 ports_on > /dev/null
    n4="$(grep -c 'PORT-SKIPPED lap=7 engine=jvm: ' "$LOG")"; d4="$(grep -c 'PORT-SKIPPED lap=7 engine=dotnet: ' "$LOG")"
    [ "$n4" = 1 ] && [ "$d4" = 1 ] && a4=ok
    echo "PORT_PROBE order=$a1 list=$a2 launch=$a3 skipped=$a4"
    [ "$a1$a2$a3$a4" = okokokok ] && exit 0
    echo "  order: held-wrongly=[$o1] sorted=[$f1] sprint-held=$h1; list: none-equal=$([ "$l0" = "$lnone" ] && echo yes || echo no) built=$lb refused=$lbad; launch: rc=$rcl [$g3]; skipped: jvm=$n4 dotnet=$d4"; exit 1
fi
if [ "$MODE_ARG" = --probe-door ]; then   # THE DOOR'S PROBE (row cycle-a-cell-takes-its-core-token-before-its-base-and-its-clock-and-a-request-takes-it-first): an order of events, never a clock
    [ -n "${S4E_DOOR_PROBE_T:-}" ] || { echo "REFUSE(2): --probe-door runs only in the sandbox its own first lines make"; exit 2; }
    T="$S4E_DOOR_PROBE_T"; export DOOR_EVENTS="$T/events"; : > "$DOOR_EVENTS"
    # the stand-ins: a base whose launch is a harness that checks it runs under the cell's own token and grades in a second; the bound of a cell is 2 s
    mkdir -p "$T/base/harness/scripts" "$T/base/corpus/pkg" "$T/base/SCRIP" "$T/base/.github"; : > "$T/base/corpus/pkg/ALL.sno"; : > "$T/base/corpus/pkg/ALL.ref"
    printf '#!/bin/bash\n[ -n "${S4E_RUN_SLOT_HELD:-}" ] && [ -n "${S4E_CORE_HELD:-}" ] || { echo "NO TOKEN HELD BY THE CELL"; exit 9; }\nexec "$@"\n' > "$T/base/harness/scripts/util_run_slot.sh"
    printf 'import time\ntime.sleep(1)\nprint("SUITE_BOARD probe m3_n=1 m3_pass=1")\n' > "$T/base/harness/scripts/corpus_suite_harness.py"
    on_base() { echo "BASE $BASHPID" >> "$DOOR_EVENTS"; BASE="$T/base"; SBIN=/bin/true; RTD="$T"; }
    choose_base() { on_base; }
    budget() { echo 2; }
    hold() { : > "$T/hold.$1"; ( exec 9>> "$S4E_RUN_SLOT_DIR/slot0"; flock 9; : > "$T/held.$1"; while [ -f "$T/hold.$1" ]; do sleep 0.1; done ) & }
    until_ev() { local i=0; until grep -q -E -- "$1" "$DOOR_EVENTS" 2> /dev/null || [ -f "$T/$1" ]; do i=$((i + 1)); [ "$i" -gt 3000 ] && return 1; sleep 0.1; done; }   # a guard of 300 s on the setup, never a verdict
    mkdir -p "$S4E_RUN_SLOT_DIR"; v1=RED; v2=RED; v3=RED
    # arms 1 and 2: the probe holds the one token; a cell waits at the door holding no base, waits past its 2 s bound, and when the token is freed takes it, then its base, and grades rc 0
    hold a; until_ev held.a || { echo "REFUSE(2): the plant took no token"; exit 2; }
    ( run_cell probe pkg snobol4 "$T/base/corpus/pkg" core > "$T/res.a" 2> /dev/null ) & ca=$!
    until_ev "WAIT cell probe core|^BASE" || { echo "REFUSE(2): the cell neither reached the door nor took a base"; exit 2; }   # a base taken while the probe holds the token is the red of arm 1
    sleep 3; grep -q '^BASE' "$DOOR_EVENTS" && b1=held || b1=free
    rm -f "$T/hold.a"; wait "$ca"; read -r rca _ < "$T/res.a"
    [ "$b1" = free ] && grep -n . "$DOOR_EVENTS" | awk -F: '/WAIT cell/{w=$1} /TOKEN cell/{t=$1} /^[0-9]+:BASE/{b=$1} END{exit !(w && t > w && b > t)}' && v1=ok
    [ "$rca" = 0 ] && v2=ok
    # arm 3: with the token held, two lap cells wait at the door, then a request is filed; the token freed goes to the request first
    : > "$DOOR_EVENTS"; hold b; until_ev held.b || { echo "REFUSE(2): the plant took no token"; exit 2; }
    ( run_cell probe pkg snobol4 "$T/base/corpus/pkg" chunk:01 > "$T/res.b" 2> /dev/null ) & cb=$!; ( run_cell probe pkg snobol4 "$T/base/corpus/pkg" chunk:02 > "$T/res.c" 2> /dev/null ) & cc=$!
    until_ev "WAIT cell probe chunk:01|^BASE" && until_ev "WAIT cell probe chunk:02|^BASE.*\n.*^BASE|^BASE" || { echo "REFUSE(2): the cells neither reached the door nor took a base"; exit 2; }
    ( door_take request probe-req && sleep 1 ) & cr=$!
    i=0; until compgen -G "$TMPDIR/cycle/door/req.*" > /dev/null || ! kill -0 "$cr" 2> /dev/null; do i=$((i + 1)); [ "$i" -gt 3000 ] && { echo "REFUSE(2): the request neither left a ticket nor ended"; exit 2; }; sleep 0.1; done
    rm -f "$T/hold.b"; wait "$cr" "$cb" "$cc"
    [ "$(grep -m1 '^TOKEN' "$DOOR_EVENTS")" = "TOKEN request probe-req" ] && [ "$(grep -c '^TOKEN cell' "$DOOR_EVENTS")" = 2 ] && v3=ok
    # arm 4, the lanes: the widths follow CORES.conf's grader line (4: fast 2 and slow 1; 8: fast 5 and slow 2), and S4E_CYCLE_FAST still wins when set
    v4=RED; c0="$S4E_CORES_CONF"; printf 'cores=8\ngrader=4\n' > "$T/c4"; printf 'cores=12\ngrader=8\n' > "$T/c8"
    l4="$(S4E_CORES_CONF="$T/c4" bash -c '. "$1"; lane_widths; echo "$WF $WS"' _ <(declare -f lane_widths s4e_cores_conf; echo "S4E_CORES_CONF_DEFAULT=/dev/null"))"
    l8="$(S4E_CORES_CONF="$T/c8" bash -c '. "$1"; lane_widths; echo "$WF $WS"' _ <(declare -f lane_widths s4e_cores_conf; echo "S4E_CORES_CONF_DEFAULT=/dev/null"))"
    le="$(S4E_CORES_CONF="$T/c4" S4E_CYCLE_FAST=3 bash -c '. "$1"; lane_widths; echo "$WF $WS"' _ <(declare -f lane_widths s4e_cores_conf; echo "S4E_CORES_CONF_DEFAULT=/dev/null"))"
    [ "$l4" = "2 1" ] && [ "$l8" = "5 2" ] && [ "$le" = "3 1" ] && v4=ok
    # arm 5, the sprint: with a scratch SPRINT.conf of lang=snobol4, a prolog cell whose last reading took 500 s is held and a snobol4 cell of 500 s is not, a short prolog cell
    # (60 s) is not, and order_cells puts the snobol4 suite first; with no file nothing is held
    v5=RED; printf 'name=PROBE\nlang=snobol4\n' > "$T/sprint.conf"
    # and with CYCLE.nohold standing the same 500 s prolog cell is not held
    h1=1; NOHOLDF="$T/no.nohold" SPRINTF="$T/sprint.conf" sprint_held p1 prolog core 500 && h1=0
    h2=1; NOHOLDF="$T/no.nohold" SPRINTF="$T/sprint.conf" sprint_held s1 snobol4 core 500 && h2=0
    h3=1; NOHOLDF="$T/no.nohold" SPRINTF="$T/sprint.conf" sprint_held p2 prolog core 60 && h3=0
    h4=1; NOHOLDF="$T/no.nohold" SPRINTF="$T/none.conf" sprint_held p1 prolog core 500 && h4=0
    : > "$T/nohold"; h5=1; NOHOLDF="$T/nohold" SPRINTF="$T/sprint.conf" sprint_held p1 prolog core 500 && h5=0
    o1="$(printf 'pl_a\tpkg\tprolog\td\tcore\nsno_a\tpkg\tsnobol4\td\tcore\n' | ORDERF="$T/no.order" FIRSTF="$T/no.first" SPRINTF="$T/sprint.conf" order_cells | head -1 | cut -f1)"
    o0="$(printf 'pl_a\tpkg\tprolog\td\tcore\nsno_a\tpkg\tsnobol4\td\tcore\n' | ORDERF="$T/no.order" FIRSTF="$T/no.first" SPRINTF="$T/none.conf" order_cells | head -1 | cut -f1)"
    [ "$h1$h2$h3$h4$h5" = 01111 ] && [ "$o1" = sno_a ] && [ "$o0" = pl_a ] && v5=ok
    # arm 6, the requests: with seat A's first request in serving, A's second is passed over and B's served; a request naming an entry whose timeout_s is over
    # 300 s is the slow lane's, never the fast lane's
    v6=RED; mkdir -p "$RQ/serving" "$T/rcorpus/packages/longpkg"; rm -f "$RQ"/*.req "$RQ"/serving/*.req
    for r in 20000101T000001-seatA-x-1 20000101T000002-seatA-x-2 20000101T000003-seatB-x-3; do printf 'suite=nosuch\nentries=a\n' > "$RQ/$r.req"; done
    q1="$(basename "$(next_request f)")"; mv "$RQ/$q1" "$RQ/serving/$q1"; q2="$(basename "$(next_request f)")"; rm -f "$RQ"/*.req "$RQ"/serving/*.req
    printf 'longpkg\tpkg\tsnobol4\tcorpus_suite_harness.py\tcorpus/packages/longpkg\n' > "$T/rrunners.tsv"; printf 'entry,timeout_s\nbig,600\nsmall,30\n' > "$T/rcorpus/packages/longpkg/ALL.csv"
    printf 'suite=longpkg\nentries=big\n' > "$RQ/20000101T000004-seatC-longpkg-4.req"
    q3f="$(RUNNERS="$T/rrunners.tsv" S4E_CORPUS="$T/rcorpus" next_request f)"; q3s="$(basename "$(RUNNERS="$T/rrunners.tsv" S4E_CORPUS="$T/rcorpus" next_request s)")"; rm -f "$RQ"/*.req
    [ "$q1" = 20000101T000001-seatA-x-1.req ] && [ "$q2" = 20000101T000003-seatB-x-3.req ] && [ -z "$q3f" ] && [ "$q3s" = 20000101T000004-seatC-longpkg-4.req ] && v6=ok
    # arms 7 to 9, THE CELL'S KEY (row harness-the-cycles-cell-names-its-key-at-the-door-and-writes-its-ledger-line), on a scratch pool of the weighted door (cores=2 weights=on) and a scratch ledger: (7) two cells of unlike cost
    # draw unlike weights, 3000 and 100 millicores, because door_take passes each its own key; with the key taken out both draw the class's 90th percentile and that arm must read RED; (8) a cell's launch under the ledger
    # wrapper leaves ONE line, class run and its key, in the ledger; (9) a request, filed after a cell and waiting behind the same holder, is served first under the weighted door too (its ticket's priority)
    v7=RED; v8=RED; v9=RED; wst() { python3 -I -S "$S4E_HARNESS/scripts/lib_weights.py" status; }
    wmc() { wst | sed -n "s/.*'held_mc': \([0-9]*\).*/\1/p"; }
    printf 'cores=2\nweights=on\npatience=60\nwait=600\n' > "$T/CW.conf"
    { printf '# c\n# at_utc\tseat\tclass\tkey\twall_s\tcpu_s\tcores\trss_mb\ttmp_mb\trc\n'; for i in 1 2 3; do printf '2026-11-18T00:00:00Z\ts\trun\tcell:probe:heavy\t1.0\t3.0\t3.0\t500.0\t0.0\t0\n2026-11-18T00:00:00Z\ts\trun\tcell:probe:light\t1.0\t0.1\t0.1\t5.0\t0.0\t0\n'; done; } > "$T/COSTS.tsv"
    rm -rf "$T/run/w" "$T/COSTS.idx"; keyed=""; nokey=""
    for kk in "heavy cell:probe:heavy" "light cell:probe:light"; do
        set -- $kk; rm -rf "$T/run/w"
        ( S4E_CORES_CONF="$T/CW.conf" door_take cell "probe $1" "$2" && sleep 30 ) > /dev/null 2>&1 & wp=$!
        i=0; until [ -n "$(wmc | grep -v '^0$')" ] || [ "$i" -gt 300 ]; do i=$((i + 1)); sleep 0.1; done
        keyed="$keyed $(wmc)"; kill "$wp" 2> /dev/null; wait "$wp" 2> /dev/null
        rm -rf "$T/run/w"
        ( S4E_CORES_CONF="$T/CW.conf" door_take cell "probe $1" && sleep 30 ) > /dev/null 2>&1 & wp=$!
        i=0; until [ -n "$(wmc | grep -v '^0$')" ] || [ "$i" -gt 300 ]; do i=$((i + 1)); sleep 0.1; done
        nokey="$nokey $(wmc)"; kill "$wp" 2> /dev/null; wait "$wp" 2> /dev/null
    done
    set -- $keyed; k1="${1:-0}"; k2="${2:-0}"; set -- $nokey; n1="${1:-0}"; n2="${2:-0}"
    [ "$k1" = 3000 ] && [ "$k2" = 100 ] && [ "$n1" = "$n2" ] && [ "$n1" != 0 ] && v7=ok
    : > "$T/ledger.before"; cp "$T/COSTS.tsv" "$T/ledger.before"; cell_cost_args "cell:probe:led"; "${COSTRUN[@]}" /bin/true
    [ "$(tail -n +"$(( $(wc -l < "$T/ledger.before") + 1 ))" "$T/COSTS.tsv" | grep -c "	run	cell:probe:led	")" = 1 ] && v8=ok
    v9=ok; for rnd in 1 2 3; do   # three rounds: whichever waiter polls first is a coin, so one round could pass by luck
        rm -rf "$T/run/w" "$T/w.held" "$T/w.release"; : > "$T/wev"
        ( S4E_CORES_CONF="$T/CW.conf" door_take cell "probe holder" "cell:probe:heavy" && : > "$T/w.held" && until [ -f "$T/w.release" ]; do sleep 0.1; done ) > /dev/null 2>&1 & wh=$!
        until_ev w.held || { echo "REFUSE(2): the weighted holder took no place"; exit 2; }
        ( S4E_CORES_CONF="$T/CW.conf" door_take cell "probe late" "cell:probe:heavy" && echo cell >> "$T/wev" && sleep 1 ) > /dev/null 2>&1 & wc1=$!
        i=0; until [ "$(wst | sed -n "s/.*'waiting': \\([0-9]*\\).*/\\1/p")" = 1 ] || [ "$i" -gt 300 ]; do i=$((i + 1)); sleep 0.1; done
        ( S4E_CORES_CONF="$T/CW.conf" door_take request probe-req2 "request:probe" && echo request >> "$T/wev" && sleep 1 ) > /dev/null 2>&1 & wr=$!
        i=0; until [ "$(wst | sed -n "s/.*'waiting': \\([0-9]*\\).*/\\1/p")" = 2 ] || [ "$i" -gt 300 ]; do i=$((i + 1)); sleep 0.1; done
        : > "$T/w.release"; wait "$wh" "$wc1" "$wr" 2> /dev/null
        [ "$(head -1 "$T/wev")" = request ] && [ "$(wc -l < "$T/wev")" = 2 ] || v9=RED
    done
    echo "DOOR_PROBE base_free=$v1 bound_counts_the_run=$v2 request_first=$v3 lanes=$v4 sprint=$v5 requests=$v6 cell_key=$v7 cell_ledger_line=$v8 request_first_weighted=$v9"
    [ "$v6" = ok ] || echo "  requests: first=$q1 second=$q2 (want seatB) long-in-fast=[$q3f] long-in-slow=$q3s"
    [ "$v4$v5" = okok ] || echo "  lanes: grader=4 -> $l4, grader=8 -> $l8, FAST=3 -> $le; sprint held: $h1$h2$h3$h4 (want 0111), first: $o1 (want sno_a), with no file: $o0 (want pl_a)"
    [ "$v7$v8$v9" = okokok ] || echo "  cell key: heavy $k1 light $k2 millicores with the key, $n1 and $n2 without it (want 3000 and 100, equal without); ledger line arm $v8; request-first order: $(tr '\n' ' ' < "$T/wev")"
    [ "$v1$v2$v3$v4$v5$v6$v7$v8$v9" = okokokokokokokokok ] && exit 0
    echo "  events:"; sed 's/^/    /' "$DOOR_EVENTS"; for r in a b c; do echo "  res.$r: $(cat "$T/res.$r" 2> /dev/null)"; done; exit 1
fi
{ [ "${BASH_VERSINFO[0]}" -gt 5 ] || { [ "${BASH_VERSINFO[0]}" -eq 5 ] && [ "${BASH_VERSINFO[1]}" -ge 1 ]; }; } || { echo "REFUSE(2) [cycle]: bash ${BASH_VERSION} has no wait -n -p (5.1 or newer; the rolling pool needs it)"; exit 2; }
if [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF" 2>/dev/null)" 2>/dev/null && [ "$(cat "$PIDF")" != "$$" ]; then echo "REFUSE(2) [cycle]: already running as pid $(cat "$PIDF")"; exit 2; fi
echo $$ > "$PIDF"
trap 'rm -f "$PIDF"' EXIT
# THE BINARY IS FRESH AT EVERY START, not only at a lap start (the cio 2026-11-08 10:5x: the grader root synced mid-lap without a make, and cells 25 to 40 refused rc 2 in 2 s each on a stale binary): make on a built tree is a no-op or a cache fetch.
( cd "$S4E_SCRIP" && make -j8 ) >> "$TMPDIR/cycle/make.log" 2>&1 < /dev/null || log "START MAKE_FAILED rc $? (see $TMPDIR/cycle/make.log): the cycle goes on, every turn (Lon 2026-11-13: \"continue another TURN regardless\"); a master or pkg cell runs on a base and its own binary"
lap="$(state_get lap)"; idx="$(state_get idx)"; st="$(state_get status)"; pc="$(state_get cell)"; ps="$(state_get suite)"
[ -n "$lap" ] || lap=0; [ -n "$idx" ] || idx=0
if [ "$st" = running ] && [ -n "$ps" ]; then
    n=$(( $(awk -F'\t' -v s="$ps" -v c="$pc" '$1 == s && $2 == c {print $3; exit}' "$CRASH" 2>/dev/null) + 1 ))
    { grep -v -P "^\Q$ps\E\t\Q$pc\E\t" "$CRASH" 2>/dev/null; printf '%s\t%s\t%s\n' "$ps" "$pc" "$n"; } > "$CRASH.tmp" && mv "$CRASH.tmp" "$CRASH"
    log "CRASH lap=$lap idx=$idx $ps $pc killed the cycle, count=$n"
    if [ "$n" -ge 3 ]; then printf '%s\t%s\t%s\tskipped after %s deaths\n' "$(now)" "$ps" "$pc" "$n" >> "$SKIP"; log "SKIP $ps $pc for good (three deaths)"; fi
fi
if [ "$MODE_ARG" = --next ]; then IFS=$'\t' read -r key kind lang dir cell <<< "$(cells | order_cells | sed -n "$(( idx + 1 ))p")"; echo "NEXT lap=$lap idx=$idx cell=$key $cell"; exit 0; fi
while :; do
    mapfile -t ALL < <(cells | order_cells); total=${#ALL[@]}
    [ "$total" -gt 0 ] || { log "REFUSED: no cells (SUITE_RUNNERS.tsv or the partitions unreadable)"; exit 2; }
    if { [ "$idx" -eq 0 ] && [ "${topup:-0}" = 0 ]; } || [ "$idx" -ge "$total" ]; then
        [ "$idx" -ge "$total" ] && [ "$lap" -gt 0 ] && log "LAP $lap done cells=$total"
        lap=$(( lap + 1 )); idx=0; lap_start "$lap"
        cp "${S4E_RESULTS:-/home/resources/progress/results.tsv}" "$TMPDIR/cycle/lap.$lap.results" 2>/dev/null; rm -f "$TMPDIR/cycle/lap.$(( lap - 2 )).results"   # the lap's own copy: its end tells the new reds against it
        # THE LAP'S CELLS ARE READ FROM THE TREE IT GRADES, after the sync (the cio 2026-11-10: the list was read before lap_start, so a
        # partition landed between two laps ran one lap on the old cell names, and a chunk the new table no longer has refused rc 2).
        order_write
        mapfile -t ALL < <(cells | order_cells); total=${#ALL[@]}
        [ "$total" -gt 0 ] || { log "REFUSED: no cells after the sync (SUITE_RUNNERS.tsv or the partitions unreadable)"; exit 2; }
    fi
    # THE WIDTH (the cio, 2026-11-08 10:4x CST; MEASURED: 20 cells in 1579 s one at a time, 78 s a cell, a lap of 190 cells 250 min, at load 8 on 16 cores
    # with no CPU pressure): up to S4E_CYCLE_WIDTH cells (default 4; 1 under --one) run at once, each under its own run slot in the grader's pool.
    # THE ROLLING POOL (the cio 2026-11-10, row cycle-keeps-its-width-of-cells-running; MEASURED by the coo 20:53Z: lap 11 stood 1 h 40 min on xsb chunk:02
    # with three of four slots idle, because a batch waited on ALL its cells): the moment ANY cell finishes (wait -n -p) it is handled and its slot is
    # refilled with the next cell. The state names the LOWEST index still running, so a crash is charged to it and a restart resumes there (a later cell
    # that had finished runs again: time, never a reading). CELL lines come in order of finish, each with its own index. A suite's row is recorded when
    # the last of its cells of this lap has finished, whatever the order.
    # THE TWO LANES (the grader 2026-11-12, step 1 of cycle-greased-lightning, on the coo's 18:2x telegram and Lon's word of 18:0x: "The test-suite
    # cycle runner better be GREASED LIGHTING. Each unit of work should be very small relative so that many requests from seats can go through FAST.";
    # MEASURED CYCLE.order 2026-11-12: of 270 cells, 15 took over 600 s and held 10.6 of the lap's 14.9 cell-hours, so with one lane of 4 they held
    # most slots for most of a lap and every request waited behind them): a cell whose last reading took over S4E_CYCLE_SLOW_SECS (600) runs in the
    # SLOW lane, S4E_CYCLE_SLOW slots (2), and every other cell and every seat's request in the FAST lane, S4E_CYCLE_FAST slots (8; the graded-runs
    # slice is 10 cores, the coo 18:2x). A free fast slot takes a pending request before any lap cell, so a request waits only for one fast cell to
    # end; a slow cell never takes a fast slot. --one runs one cell in one lane. S4E_CYCLE_WIDTH, the one-lane width before, sets the fast lane if given.
    lane_widths; SLOWS="${S4E_CYCLE_SLOW_SECS:-600}"; case "$SLOWS" in ''|*[!0-9]*) SLOWS=600;; esac   # the widths, from CORES.conf (lane_widths), read again at each turn below
    declare -A RUN=() LANE=() LEFT=() CSECS=()
    while IFS=$'\t' read -r ok oc os; do [ -n "$ok" ] && CSECS["$ok"$'\t'"$oc"]="${os%%.*}"; done < "$ORDERF" 2>/dev/null
    FQ=(); SQ=(); PQ=(); fp=0; sp=0; pp=0
    for (( j = idx; j < total; j++ )); do IFS=$'\t' read -r key kind lang dir cell <<< "${ALL[$j]}"
        if [ "$kind" = port ]; then PQ+=("$j"); elif [ "$WS" -gt 0 ] && [ "${CSECS["$key"$'\t'"$cell"]:-0}" -gt "$SLOWS" ]; then SQ+=("$j"); else FQ+=("$j"); fi; done
    lane_n() { local n=0 v; for v in "${LANE[@]}"; do [ "$v" = "$1" ] && n=$((n + 1)); done; echo "$n"; }
    start_cell() {   # <index> <lane>: run a lap cell, or log it skipped
        IFS=$'\t' read -r key kind lang dir cell <<< "${ALL[$1]}"
        if grep -q -P "\t\Q$key\E\t\Q$cell\E\t" "$SKIP" 2>/dev/null; then log "SKIPPED lap=$lap $(($1+1))/$total $key $cell"; return 1; fi
        if sprint_held "$key" "$lang" "$cell" "${CSECS["$key"$'\t'"$cell"]:-0}"; then log "SPRINT-HELD lap=$lap $(($1+1))/$total $key $cell lang=$lang secs=${CSECS["$key"$'\t'"$cell"]:-0}: the sprint of $(sprint_langs | sed 's/ $//') stands (SPRINT.conf)"; return 1; fi
        # A CELL GRADED ONCE A LAP IS NOT RUN AGAIN IN IT (the grader 2026-11-16, on the coo's measurement: lap 42 had 1231 CELL lines for 1197 cells,
        # all 34 repeats rosetta-raku's, chunk:13 four times, each pass when the lap's total grew: the list is read again every turn and a new suite sorts
        # first, so every later cell moves right and the index runs again the cells it had passed)
        if grep -q -P "^\S+ CELL lap=$lap \d+/\d+ \Q$key\E \Q$cell\E rc=" "$LOG" 2>/dev/null; then log "DONE-THIS-LAP lap=$lap $(($1+1))/$total $key $cell"; return 1; fi
        ( run_cell "$key" "$kind" "$lang" "$dir" "$cell" > "$TMPDIR/cycle/res.$1" ) & RUN[$!]="$1"; LANE[$!]="$2"; return 0; }
    mkdir -p "$RQ/serving" "$RQ/done" 2>/dev/null; for f in "$RQ"/serving/*.req; do [ -f "$f" ] && mv "$f" "$RQ/" 2>/dev/null; done   # a request a dead cycle was serving is pending again
    for (( j = idx; j < total; j++ )); do IFS=$'\t' read -r key kind lang dir cell <<< "${ALL[$j]}"; grep -q -P "\t\Q$key\E\t\Q$cell\E\t" "$SKIP" 2>/dev/null || LEFT[$key]=$(( ${LEFT[$key]:-0} + 1 )); done
    while :; do
        lane_widths   # each turn: the lanes follow the door's width (part 2)
        while [ "$(lane_n s)" -lt "$WS" ] && rf="$(next_request s)"; do   # a long request takes the slow lane before any slow lap cell
            rn="$(basename "$rf")"; mv "$rf" "$RQ/serving/$rn" 2>/dev/null || break
            ( run_request "$RQ/serving/$rn" > "$TMPDIR/cycle/rres.$rn" ) & RUN[$!]="r:$rn"; LANE[$!]=s
        done
        while [ "$(lane_n f)" -lt "$WF" ] && rf="$(next_request f)"; do   # a free fast slot takes the oldest pending request before any lap cell
            rn="$(basename "$rf")"; mv "$rf" "$RQ/serving/$rn" 2>/dev/null || break
            ( run_request "$RQ/serving/$rn" > "$TMPDIR/cycle/rres.$rn" ) & RUN[$!]="r:$rn"; LANE[$!]=f
        done
        while [ "$fp" -lt "${#FQ[@]}" ] && [ "$(lane_n f)" -lt "$WF" ]; do start_cell "${FQ[$fp]}" f; fp=$(( fp + 1 )); done
        while [ "$sp" -lt "${#SQ[@]}" ] && [ "$(lane_n s)" -lt "$WS" ]; do start_cell "${SQ[$sp]}" s; sp=$(( sp + 1 )); done
        while [ "$pp" -lt "${#PQ[@]}" ] && port_may_start "$sp" "${#SQ[@]}" "$(lane_n s)" "$(lane_n p)" "$WS"; do start_cell "${PQ[$pp]}" p; pp=$(( pp + 1 )); done   # a port cell after every slow cell, one at a time, never past a pending request
        [ "${#RUN[@]}" -gt 0 ] || break
        low="$total"; [ "$fp" -lt "${#FQ[@]}" ] && low="${FQ[$fp]}"; [ "$pp" -lt "${#PQ[@]}" ] && [ "${PQ[$pp]}" -lt "$low" ] && low="${PQ[$pp]}"; [ "$sp" -lt "${#SQ[@]}" ] && [ "${SQ[$sp]}" -lt "$low" ] && low="${SQ[$sp]}"
        for i in "${RUN[@]}"; do case "$i" in r:*) ;; *) [ "$i" -lt "$low" ] && low="$i";; esac; done
        if [ "$low" -lt "$total" ]; then IFS=$'\t' read -r key kind lang dir cell <<< "${ALL[$low]}"; state_put "$lap" "$low" "$total" "$key" "$cell" running; fi
        dp=""; wait -n -p dp "${!RUN[@]}"; [ -n "$dp" ] && [ -n "${RUN[$dp]:-}" ] || continue
        i="${RUN[$dp]}"; ln="${LANE[$dp]:-f}"; unset 'RUN[$dp]' 'LANE[$dp]'
        case "$i" in r:*) rn="${i#r:}"; rc=2; secs=0; read -r rc secs < "$TMPDIR/cycle/rres.$rn"; rm -f "$TMPDIR/cycle/rres.$rn"
            if [ "$rc" = 3 ]; then mv -f "$RQ/serving/$rn" "$RQ/" 2>/dev/null; log "REQUEST_PENDING lap=$lap $rn: no base holds a build yet (base.log); it waits for one, never graded on the root"; continue; fi
            finish_request "$rn" "$rc" "$secs"; continue;; esac
        IFS=$'\t' read -r key kind lang dir cell <<< "${ALL[$i]}"
        rc=2; secs=0; read -r rc secs < "$TMPDIR/cycle/res.$i"; rm -f "$TMPDIR/cycle/res.$i"
        log "CELL lap=$lap $((i+1))/$total $key $cell rc=$rc secs=$secs lane=$ln"
        LEFT[$key]=$(( ${LEFT[$key]:-1} - 1 ))
        # A SUITE ROW IS WRITTEN ONLY BY A LAP THAT GRADED THE SUITE (the cio 2026-11-10; MEASURED: inria's five cells refused rc 2 in 0 s on
        # laps 2 to 10, no grader row for inria is later than 2026-11-08T20:19Z, and its SUITES.tsv row reads today_date 2026-11-09; logtalk
        # and dotnet the same): from-progress stamps the box-clock day, so a record after a lap in which every cell refused re-dates old
        # readings as today's. No cell of this lap at rc 0 or 1, no record; the row keeps the day of its last reading and the log says so.
        # EVERY CHUNK REPORTS THE MOMENT IT ENDS (Lon 2026-11-12 19:0x CST, in the grader's window, verbatim: "You do not have to report a test
        # suite ALL at ONCE. you report each chunk at it comes, and each chunk is bite-size regardless of which suite it came from." / "This waiting
        # around is GOING to STOP!!!"): a cell that graded (rc 0 or 1) rewrites its suite's row at once, from the progress store, in the background so
        # the next cells launch without waiting (from-progress takes 20 s on swi, 1.5 s on most); one lock a suite, so two records of one row run in
        # turn and the newer lands last. A cell that refused, died or was held (rc 2) writes nothing: its row keeps the stamps of its last reading.
        if [ "$MODE_ARG" != --one ]; then
            case "$rc" in 0|1) ( flock 9; case "$kind" in master) record_suite "$lang";; *) record_pkg "$key";; esac ) 9> "$PROG/record.$key.lock" & ;;
                *) log "NORECORD lap=$lap $key $cell: the cell did not grade (rc=$rc); its suite row is not rewritten";; esac
        fi
        [ "$MODE_ARG" = --one ] && { echo "ONE $key $cell rc=$rc secs=$secs"; state_put "$lap" "$((i+1))" "$total" "$key" "$cell" done; exit 0; }
    done
    # THE LAP TAKES IN WHAT LANDED DURING IT (the grader 2026-11-16, on the coo's ask: lap 43 built its queues at 18:06Z, so every entry and chunk landed
    # after waited hours for the next lap; the list itself is read live from /home/corpus). When the queues are spent, the list is read again; a cell
    # with no CELL line in this lap and not held in CYCLE.skip is run before the lap closes, from the first such cell, the ones already graded skipped
    # as DONE-THIS-LAP; at most three top-ups a lap, so a cell that never logs cannot hold the lap open
    topup=0
    if [ "$MODE_ARG" != --one ] && [ "$(grep -c -P "^\S+ TOPUP lap=$lap " "$LOG" 2>/dev/null)" -lt 3 ]; then
        mapfile -t ALL < <(cells | order_cells); total=${#ALL[@]}; nx=-1
        for (( j = 0; j < total; j++ )); do IFS=$'\t' read -r key kind lang dir cell <<< "${ALL[$j]}"
            grep -q -P "\t\Q$key\E\t\Q$cell\E\t" "$SKIP" 2>/dev/null && continue
            grep -q -P "^\S+ CELL lap=$lap \d+/\d+ \Q$key\E \Q$cell\E rc=" "$LOG" 2>/dev/null && continue
            nx=$j; break; done
        if [ "$nx" -ge 0 ]; then log "TOPUP lap=$lap from $((nx+1))/$total $key $cell: cells that landed in the lap"; idx="$nx"; topup=1; state_put "$lap" "$idx" "$total" "$key" "$cell" done; continue; fi
    fi
    # THE LAP'S NEW REDS (the cio 2026-11-10, CIO-82 on the grading-tube row; Lon's law of CIO-8): one telegram per designer, once a lap, never one per red
    if [ "$MODE_ARG" != --one ]; then
        gk=(); for k in $(printf '%s\n' "${ALL[@]}" | cut -f1 | awk '!s[$0]++'); do graded_this_lap "$k" && gk+=("$k"); done
        [ "${#gk[@]}" -gt 0 ] && log "$( . "$S4E_HARNESS/scripts/lib_grade_cell.sh"; tell_lap_new_reds "$(git -C "$S4E_SCRIP" rev-parse --short=9 HEAD 2>/dev/null)" "$TMPDIR/cycle/lap.$lap.results" "${gk[@]}" ) lap=$lap suites=${#gk[@]}"
    fi
    idx="$total"; state_put "$lap" "$idx" "$total" "$key" "$cell" done
done
