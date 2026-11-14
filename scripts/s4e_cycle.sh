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
S4E="${S4E_HOME:-/home/claude_grader}"
# THE TREE GRADED NAMES ALL FOUR REPOS (officer_02 2026-11-13, row harness-corpus-and-harness-live-once-on-disk-one-seat-owns-them): lib_paths.sh and harness_paths.py read /home/corpus,
# /home/harness and /home/.github once each is a checkout, so every run here pins S4E_SCRIP, S4E_CORPUS, S4E_HARNESS and S4E_GITHUB to the tree it grades (a base, or this root), and a
# chunk keeps its own snapshot whatever the one-disk checkouts hold.
export S4E_HOME="$S4E" S4E_SCRIP="$S4E/SCRIP" S4E_CORPUS="$S4E/corpus" S4E_HARNESS="$S4E/harness" S4E_GITHUB="$S4E/.github" S4E_SEAT=grader S4E_CLASS=grader S4E_BATCH="${S4E_BATCH:-1}" S4E_MODES="${S4E_MODES:-m3}" TMPDIR="${S4E_CYCLE_TMP:-/tmp/s4e/grader}"   # S4E_MODES exported: the cells and the suite row (util_score_row.py from-progress) read the same modes, m3 alone under Lon's mode-3-only order   # one-disk: not a path (the pin: the graded tree's own four repos, by design (lines 20-22))
PROG="${S4E_CYCLE_PROG:-/home/resources/progress}"
STATE="$PROG/CYCLE.state"; LOG="$PROG/CYCLE.log"; PIDF="$PROG/CYCLE.pid"; CRASH="$PROG/CYCLE.crash"; SKIP="$PROG/CYCLE.skip"
RUNNERS="$S4E_HARNESS/scripts/SUITE_RUNNERS.tsv"
mkdir -p "$TMPDIR/cycle" "$PROG" || exit 2
# THE CYCLE RENDERS INTO ITS SCRATCH, NEVER INTO A TRACKED FILE OF THE ROOT (the cio 2026-11-12, row cycle-score-md-dirties-the-grader-root; MEASURED
# 13:5x: the grader root's .github read M SCORE.md between laps, so next refused that seat's jobs rc 2): util_score_row.py and util_suite_banner.py
# render the suite table into S4E_SCORE_MD, the record stays /home/resources/progress/SUITES.tsv; the scratch is seeded from the root's SCORE.md.
export S4E_SCORE_MD="${S4E_SCORE_MD:-$TMPDIR/cycle/SCORE.md}"
[ -s "$S4E_SCORE_MD" ] || [ ! -f "$S4E_GITHUB/SCORE.md" ] || cp -f "$S4E_GITHUB/SCORE.md" "$S4E_SCORE_MD"
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
cells() {   # one line per cell: key kind lang dir cell (dir: the suite's container directory; for a small row the runner's own command words, its cell the one name all); core first, then chunk:NN in order, per the row order of SUITE_RUNNERS.tsv
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
order_cells() {   # stdin: the cells in the table's order; stdout: the lap's order
    awk -F'\t' -v OF="$ORDERF" 'BEGIN { while ((getline l < OF) > 0) { split(l, a, "\t"); s[a[1] "\t" a[2]] = a[3]; have = 1 } }
        { line[NR] = $0; su[NR] = $1; k = $1 "\t" $5; if (k in s) { tot[$1] += s[k]; seen[$1] = 1 } }
        END { for (i = 1; i <= NR; i++) printf "%d\t%d\t%s\n", (!have ? 0 : (su[i] in seen) ? tot[su[i]] + 1 : 0), i, line[i] }' | sort -t "$(printf '\t')" -k1,1n -k2,2n | cut -f3-
}
budget() { S4E_HOME="${3:-$S4E}" S4E_SCRIP="${3:-$S4E}/SCRIP" S4E_CORPUS="${3:-$S4E}/corpus" S4E_HARNESS="${3:-$S4E}/harness" S4E_GITHUB="${3:-$S4E}/.github" python3 -I "${3:-$S4E}/harness/scripts/util_grade_job.py" budget --suite "$1" --cell "$2" 2>/dev/null | sed -n 's/.* ttr_s=\([0-9]*\).*/\1/p' | head -1; }   # one-disk: not a path (the pin of the tree it is given: a base's own four repos)
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
road_flag() {   # dir -> prints --run-files when the package declares that road
    local d="$1"
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
run_cell() {   # key kind lang dir cell -> rc. THE ONE LAUNCH (Lon 2026-11-08 23:0x, in the coo's window, verbatim: "We want ONE UNIFIED test suite system. The same ALL.tsv files etc. Same layout in corpus. Same script. Same spec on attributes and environment." / "Get those deleted and get to work with a complete test suite system."): every cell, master or pkg, is corpus_suite_harness.py run over the suite's container ALL.<ext> and ALL.ref; a suite without one refuses rc 2, named, until its container is built
    local key="$1" kind="$2" lang="$3" dir="$4" cell="$5" ttr alls rc t0 out nw
    out="$TMPDIR/cycle/$key.$cell.log"; t0=$(date +%s)
    if [ "$kind" = small ]; then
        ttr="$(small_budget "$key")"; nw=""; grep -q -- '--no-write' "$S4E_HARNESS/scripts/${dir%% *}" 2>/dev/null && nw=--no-write
        ( cd "$S4E" && timeout -k 30 "$ttr" bash "$S4E_HARNESS/scripts/util_run_slot.sh" bash "$S4E_HARNESS"/scripts/$dir $nw ) > "$out" 2>&1 < /dev/null; rc=$?
        echo "$rc $(( $(date +%s) - t0 ))"; return "$rc"
    fi
    on_base; dir="${dir/#$S4E/$BASE}"; alls="$dir/ALL.$(ext_of "$lang")"   # a master or pkg cell runs on a base at origin's newest heads (choose_base)
    ttr="$(budget "$key" "$cell" "$BASE")"; [ -n "$ttr" ] || ttr=3600
    echo "CELL_BASE $BASE SCRIP=$(git -C "$BASE/SCRIP" rev-parse --short=10 HEAD) corpus=$(git -C "$BASE/corpus" rev-parse --short=10 HEAD) binary=$SBIN" > "$out"
    if ! suite_on_disk "$dir" "$alls"; then echo "REFUSE(2): no suite in $dir: no container ($alls and ALL.ref), no format 2 (MULTI-LINERS.md or ONE-LINERS.$(ext_of "$lang")), no files form (a path column in ALL.csv) -- the unified layout is owed (util_build_package_suite.py)" > "$out"; echo "2 0"; return 2; fi
    ( cd "$BASE" && S4E_HOME="$BASE" S4E_SCRIP="$BASE/SCRIP" S4E_CORPUS="$BASE/corpus" S4E_HARNESS="$BASE/harness" S4E_GITHUB="$BASE/.github" SCRIP="$SBIN" RT_DIR="$RTD" SUITE_LIST_ALL=1 timeout -k 30 "$ttr" bash harness/scripts/util_run_slot.sh python3 harness/scripts/corpus_suite_harness.py run "$alls" "$dir/ALL.ref" --lang "$lang" --modes "${S4E_MODES:-m3}" --partition "$cell" $(road_flag "$dir") ) >> "$out" 2>&1 < /dev/null; rc=$?   # one-disk: not a path (a base's own four repos, the tree this chunk grades)
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
next_request() { local f; for f in "$RQ"/*.req; do [ -f "$f" ] && request_ready "$f" && { printf '%s\n' "$f"; return 0; }; done; return 1; }
# THE BASE MOVES FORWARD EVERY CHUNK (the grader 2026-11-13; Lon, via the coo 12:1x, verbatim: "The cycle runner should be running chunks through and
# updating the code continuously every turn."; skill suites-and-grading section 9). MEASURED that noon by the coo: the lap cells graded on the grader root,
# which syncs only at a lap start, and lap 28 ran 1083 cells over about 11 hours, so 3273 of 3277 grader readings since 17:00Z were on SCRIP 530c2543b5,
# 34 commits behind origin, and no cure landed that day showed in a lap reading. THE BASES are up to S4E_CYCLE_BASES (2) worktrees wt-base<N> of the four
# repositories (s4e_worktree.sh, sparse with demos/ added, named for the row so no sweep takes them). MEASURED 2026-11-13 by the probe: a base is 1542 MB (SCRIP and its
# fetched build 374, the corpus 1148), and it cannot share the pristine's files (util_relink_root.py refuses: /tmp and /home/resources are two
# filesystems, and a hard link cannot join them), so two fit the seat's 4 GB of /tmp. Every cell, request and row write picks one at its start,
# under one lock (choose_base): the root fetches origin (refs and objects, its working tree untouched; at most every S4E_CYCLE_FETCH_SECS, 20); the
# current base is taken when it holds origin's four heads; else a base no chunk holds is forwarded to them (checkout detached, MEASURED 1 s), its binary
# found in the build cache by its SCRIP tree's key (else built once there, make -j8), and made current; with none free the chunk takes the current one,
# a turn behind. A chunk holds its base shared on fd 8 for its life and a forward takes a base exclusive, so a base never moves under a chunk. The binary
# runs in place from the cache entry (SCRIP=, RT_DIR=; MEASURED: copying an entry out took 69 s). With no base to be had a chunk runs on the root, as before.
# THE BASES LIVE WHERE s4e_worktree.sh MAKES THEM, LINKED (officer_02 2026-11-13, row worktrees-live-on-home-and-hard-link-their-build, on the coo's ask: wt-base1
# and wt-base2 held 3.0 GB each of a /tmp under its floor): base_new makes a base by s4e_worktree.sh new --link, now on /home with its corpus, harness and .github
# hard-linked to the pristine (a base only checks out and reads), so the base top is that script's own top (--show-top), else /tmp/s4e. A forward's checkout writes
# each changed file as a new inode, a copy, so a base drifts from its links only by what origin changed since the base was made. A base on /tmp keeps serving until
# it is removed (S4E_WT_TOP=/tmp/s4e S4E_SEAT=grader s4e_worktree.sh rm base<N>), and base_new then makes it anew on /home.
BASE_TOP="${S4E_WT_TOP:-$(S4E_SEAT=grader bash "$S4E_HARNESS/scripts/s4e_worktree.sh" --show-top 2>/dev/null | sed -n 's/^WT top=\([^ ]*\) .*/\1/p')}"; BASE_TOP="${BASE_TOP:-/tmp/s4e}/grader"; NBASES="${S4E_CYCLE_BASES:-2}"; FETCH_SECS="${S4E_CYCLE_FETCH_SECS:-20}"
case "$NBASES" in ''|*[!0-9]*|0) NBASES=2;; esac; case "$FETCH_SECS" in ''|*[!0-9]*) FETCH_SECS=20;; esac
heads_of() { local r; for r in SCRIP harness corpus .github; do git -C "$1/$r" rev-parse "${2:-HEAD}" 2>/dev/null || echo -; done | tr '\n' ' '; }
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
choose_base() {   # sets BASE, SBIN and RTD, and holds BASE shared on fd 8 until this shell exits; rc 2 (a line on stderr) when no base holds a build
    local now last want cur n b r bb
    exec 6> "$TMPDIR/cycle/base.lock"; flock -x 6
    now=$(date +%s); last=$(stat -c %Y "$TMPDIR/cycle/base.fetched" 2>/dev/null || echo 0)
    if [ $(( now - last )) -ge "$FETCH_SECS" ]; then for r in SCRIP harness corpus .github; do timeout -k 5 120 git -C "$S4E/$r" fetch -q origin main 2>/dev/null; done; : > "$TMPDIR/cycle/base.fetched"; fi
    want="$(heads_of "$S4E" origin/main)"; cur="$(cat "$TMPDIR/cycle/base.current" 2>/dev/null)"
    if [ -z "$cur" ] || [ ! -f "$cur/.s4e-bin" ] || ! grep -q "^$cur/SCRIP/scrip " "$cur/.s4e-bin" || [ "$(heads_of "$cur")" != "$want" ]; then   # a .s4e-bin that names another tree's files (the build cache's, before 2026-11-13 17:5x) is stale
        for (( n = 1; n <= NBASES; n++ )); do
            b="$BASE_TOP/wt-base$n"; [ "$b" = "$cur" ] && continue
            base_new "$n" 2>> "$TMPDIR/cycle/base.log" || continue
            exec 8< "$b/.s4e-hold"; flock -n -x 8 || { exec 8<&-; continue; }
            for r in SCRIP harness corpus .github; do git -C "$b/$r" checkout -q --detach origin/main 2>> "$TMPDIR/cycle/base.log" || break; done
            bb=1; [ "$(heads_of "$b")" = "$want" ] && { flock -u 6; base_bin "$b" > "$b/.s4e-bin.tmp" 2>> "$TMPDIR/cycle/base.log" && bb=0; flock -x 6; }   # the make (a fetch, about a minute) runs with the base held exclusive and the lock open, so other chunks launch meanwhile
            if [ "$bb" = 0 ]; then
                mv -f "$b/.s4e-bin.tmp" "$b/.s4e-bin"; printf '%s\n' "$b" > "$TMPDIR/cycle/base.current"; cur="$b"; flock -s 8
                log "BASE $b forward SCRIP=$(git -C "$b/SCRIP" rev-parse --short=10 HEAD) corpus=$(git -C "$b/corpus" rev-parse --short=10 HEAD) harness=$(git -C "$b/harness" rev-parse --short=10 HEAD)"; break
            fi
            rm -f "$b/.s4e-bin" "$b/.s4e-bin.tmp"; exec 8<&-
        done
    fi
    [ -n "$cur" ] && [ -f "$cur/.s4e-bin" ] && grep -q "^$cur/SCRIP/scrip " "$cur/.s4e-bin" || { flock -u 6; exec 6>&-; echo "REFUSE(2): no base holds a build of its own (base.log)" >&2; return 2; }   # a lap cell then runs on the root (on_base), a request waits
    [ "$(readlink -f "/proc/$BASHPID/fd/8" 2>/dev/null)" = "$(readlink -f "$cur/.s4e-hold")" ] || { exec 8< "$cur/.s4e-hold"; flock -s 8; }
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
    row="$(awk -F'\t' -v k="$key" '!/^#/ && $1 == k && ($2 == "master" || $2 == "pkg") {print $2 "\t" $3 "\t" $5; exit}' "$RUNNERS")"
    [ -n "$row" ] && [ -n "$ents" ] || { echo "REFUSE(2): suite $key has no master or pkg row of SUITE_RUNNERS.tsv, or the request names no entries" > "$out"; echo "2 0"; return; }
    IFS=$'\t' read -r kind lang dir <<< "$row"; [ "$kind" = master ] && dir="$S4E_CORPUS/tests/$lang" || dir="$S4E/$dir"   # one-disk: not a path (column 5 of SUITE_RUNNERS.tsv is a path from the root)
    alls="$dir/ALL.$(ext_of "$lang")"
    # A REQUEST READS THE TREE THAT HOLDS ITS LANDING (junior_09 2026-11-13, MEASURED: request 20261113T223938-junior_09-gate_cases_snobol4-493276 was
    # graded at 22:40:46Z on corpus bc7da5229 although origin held the cure b30cac7ee since 22:38:47Z, the root fetched it at 22:39:53Z, and base 1 was
    # forwarded to it at 22:40:35Z: base 1 was held when the request chose, so it took base 2 a turn behind and read a false FAIL). A request fetches
    # origin at once, whatever the rate, and waits until its base holds every head origin had then (each an ancestor of the base's head), trying every
    # 15 s for S4E_REQ_FRESH_WAIT seconds (900); only past that does it grade a turn behind, and the log says REQUEST_BASE_STALE.
    rm -f "$TMPDIR/cycle/base.fetched"
    local want0 tq; tq=$(( $(date +%s) + ${S4E_REQ_FRESH_WAIT:-900} ))
    choose_base 2>> "$out" || { echo "2 $(( $(date +%s) - t0 ))"; return; }   # a request runs on origin's newest heads, never the root's (no fallback)
    want0="$(heads_of "$S4E" origin/main)"
    until base_holds "$BASE" "$want0"; do
        [ "$(date +%s)" -ge "$tq" ] && { echo "REQUEST_BASE_STALE $BASE: no base reached origin's heads of the request ($want0) in ${S4E_REQ_FRESH_WAIT:-900} s; graded a turn behind" >> "$out"; break; }
        exec 8<&-; sleep 15; choose_base 2>> "$out" || { echo "2 $(( $(date +%s) - t0 ))"; return; }
    done
    dir="${dir/#$S4E/$BASE}"; alls="${alls/#$S4E/$BASE}"; echo "REQUEST_BASE $BASE SCRIP=$(git -C "$BASE/SCRIP" rev-parse --short=10 HEAD) corpus=$(git -C "$BASE/corpus" rev-parse --short=10 HEAD) binary=$SBIN" >> "$out"
    # THE BOUND IS READ FROM THE BASE THE REQUEST RUNS ON (senior_01 2026-11-13, MEASURED: it was read from the grader root's ALL.csv before the forward, so
    # puzzles hakank_swi_euler14, whose timeout_s origin had raised to 3600 at corpus dd98b6587, was killed at ttr 420 s though it answers in 299 s)
    ttr="$(budget "$key" "entry:$ents" "$BASE")"; [ -n "$ttr" ] || ttr=1800
    ( cd "$BASE" && S4E_HOME="$BASE" S4E_SCRIP="$BASE/SCRIP" S4E_CORPUS="$BASE/corpus" S4E_HARNESS="$BASE/harness" S4E_GITHUB="$BASE/.github" SCRIP="$SBIN" RT_DIR="$RTD" SUITE_LIST_ALL=1 bash harness/scripts/util_run_slot.sh timeout -k 30 "$ttr" python3 harness/scripts/corpus_suite_harness.py run "$alls" "$dir/ALL.ref" --lang "$lang" --modes "${S4E_MODES:-m3}" --partition "entry:${ents//,/,entry:}" $(road_flag "$dir") ) >> "$out" 2>&1 < /dev/null; rc=$?   # one-disk: not a path (a base's own four repos, the tree this chunk grades)
    [ "$kind" = master ] && record_suite "$lang"; [ "$kind" = pkg ] && record_pkg "$key"
    echo "$rc $(( $(date +%s) - t0 ))"; }
finish_request() {   # name rc secs: the file lands in done/ with its per-entry verdicts and one served= line
    local name="$1" rc="$2" secs="$3" s="$RQ/serving/$1" e erc body tree n=0
    tree="$(git -C "$S4E_SCRIP" rev-parse --short=9 HEAD 2>/dev/null)"; body="$(cat "$s" 2>/dev/null)"
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
    ( cd "${BASE:-$S4E}" && S4E_HOME="${BASE:-$S4E}" S4E_SCRIP="${BASE:-$S4E}/SCRIP" S4E_CORPUS="${BASE:-$S4E}/corpus" S4E_HARNESS="${BASE:-$S4E}/harness" S4E_GITHUB="${BASE:-$S4E}/.github" S4E_CRITERION_CHANGED="$2" timeout -k 30 900 python3 -I harness/scripts/util_score_row.py from-progress --suite "$1" --partial 2>&1 < /dev/null )   # one-disk: not a path (the graded tree's own four repos, a base or this root)
}
runner_row() {   # key -> "kind lang dir" of its SUITE_RUNNERS.tsv row, dir from the corpus root
    awk -F'\t' -v k="$1" '!/^#/ && $1 == k { d = ($2 == "master") ? "tests/" $3 : $5; sub(/^corpus\//, "", d); print $2 "\t" $3 "\t" d; exit }' "$RUNNERS"
}
cycle_nick() {   # key lang -> a banner nick of at most 12 characters for a row the cycle opens
    local ab; case "$2" in snobol4) ab=Sno;; icon) ab=Icn;; prolog) ab=Pro;; pascal) ab=Pas;; raku) ab=Rak;; snocone) ab=Snc;; rebus) ab=Reb;; *) ab=X;; esac
    case "$1" in gate_cases_*) echo "${ab}Cases";; *) printf '%s' "$1" | awk -F'[-_]' '{ s = ""; for (i = 1; i <= NF; i++) s = s toupper(substr($i, 1, 1)) substr($i, 2); print substr(s, 1, 12) }';; esac
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
$( cd "$BASE" && python3 -I harness/scripts/util_suite_banner.py --open-row "$1" "$(cycle_nick "$1" "$lang")" "🧪" "$lang" 2>&1 )"   # one-disk: not a path (the base's own harness, the tree graded)
        o="$o
$(record_once "$1" "")"; rc=$?
    fi
    if [ "$rc" -ne 0 ] && mv="$(printf '%s\n' "$o" | grep -oE 'denominator moves [0-9]+ -> [0-9]+' | tail -1)" && [ -n "$mv" ] && [ -n "$dir" ]; then
        c="$(git -C "$BASE/corpus" log -1 --format='%h %s' -- "$dir" 2>/dev/null | tr '\t|' '  ' | cut -c1-140)"
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
    local sy mk
    # THE GRADER ROOT'S OWN RENDERING NEVER BLOCKS ITS SYNC (the cio 2026-11-10; MEASURED: sync_rc=1 at every lap start since lap 2, sync.log
    # "Your local changes to the following files would be overwritten by merge: SCORE.md", the grader root's .github held at 75efb44b0 while origin
    # moved to 21c79e39a). Since 2026-11-12 the record step renders into S4E_SCORE_MD, the cycle's scratch (above), so the root stays clean;
    # the restore stays for a hand run in this root, and after the sync the scratch is seeded from the root's SCORE.md as origin has it.
    if [ "$(git -C "$S4E_GITHUB" status --porcelain --untracked-files=no 2>/dev/null)" = " M SCORE.md" ]; then git -C "$S4E_GITHUB" checkout -q -- SCORE.md >> "$TMPDIR/cycle/sync.log" 2>&1; fi
    ( cd "$S4E" && bash "$S4E_HARNESS/scripts/util_sync_root.sh" ) >> "$TMPDIR/cycle/sync.log" 2>&1 < /dev/null; sy=$?
    [ ! -f "$S4E_GITHUB/SCORE.md" ] || cp -f "$S4E_GITHUB/SCORE.md" "$S4E_SCORE_MD" 2>> "$TMPDIR/cycle/sync.log"
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
    if [ "$idx" -eq 0 ] || [ "$idx" -ge "$total" ]; then
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
    WF="${S4E_CYCLE_FAST:-${S4E_CYCLE_WIDTH:-8}}"; WS="${S4E_CYCLE_SLOW:-2}"; SLOWS="${S4E_CYCLE_SLOW_SECS:-600}"
    case "$WF" in ''|*[!0-9]*|0) WF=8;; esac; case "$WS" in ''|*[!0-9]*) WS=2;; esac; case "$SLOWS" in ''|*[!0-9]*) SLOWS=600;; esac
    [ "$MODE_ARG" = --one ] && { WF=1; WS=0; }
    declare -A RUN=() LANE=() LEFT=() CSECS=()
    while IFS=$'\t' read -r ok oc os; do [ -n "$ok" ] && CSECS["$ok"$'\t'"$oc"]="${os%%.*}"; done < "$ORDERF" 2>/dev/null
    FQ=(); SQ=(); fp=0; sp=0
    for (( j = idx; j < total; j++ )); do IFS=$'\t' read -r key kind lang dir cell <<< "${ALL[$j]}"
        if [ "$WS" -gt 0 ] && [ "${CSECS["$key"$'\t'"$cell"]:-0}" -gt "$SLOWS" ]; then SQ+=("$j"); else FQ+=("$j"); fi; done
    lane_n() { local n=0 v; for v in "${LANE[@]}"; do [ "$v" = "$1" ] && n=$((n + 1)); done; echo "$n"; }
    start_cell() {   # <index> <lane>: run a lap cell, or log it skipped
        IFS=$'\t' read -r key kind lang dir cell <<< "${ALL[$1]}"
        if grep -q -P "\t\Q$key\E\t\Q$cell\E\t" "$SKIP" 2>/dev/null; then log "SKIPPED lap=$lap $(($1+1))/$total $key $cell"; return 1; fi
        ( run_cell "$key" "$kind" "$lang" "$dir" "$cell" > "$TMPDIR/cycle/res.$1" ) & RUN[$!]="$1"; LANE[$!]="$2"; return 0; }
    mkdir -p "$RQ/serving" "$RQ/done" 2>/dev/null; for f in "$RQ"/serving/*.req; do [ -f "$f" ] && mv "$f" "$RQ/" 2>/dev/null; done   # a request a dead cycle was serving is pending again
    for (( j = idx; j < total; j++ )); do IFS=$'\t' read -r key kind lang dir cell <<< "${ALL[$j]}"; grep -q -P "\t\Q$key\E\t\Q$cell\E\t" "$SKIP" 2>/dev/null || LEFT[$key]=$(( ${LEFT[$key]:-0} + 1 )); done
    while :; do
        while [ "$(lane_n f)" -lt "$WF" ] && rf="$(next_request)"; do   # a free fast slot takes the oldest pending request before any lap cell
            rn="$(basename "$rf")"; mv "$rf" "$RQ/serving/$rn" 2>/dev/null || break
            ( run_request "$RQ/serving/$rn" > "$TMPDIR/cycle/rres.$rn" ) & RUN[$!]="r:$rn"; LANE[$!]=f
        done
        while [ "$fp" -lt "${#FQ[@]}" ] && [ "$(lane_n f)" -lt "$WF" ]; do start_cell "${FQ[$fp]}" f; fp=$(( fp + 1 )); done
        while [ "$sp" -lt "${#SQ[@]}" ] && [ "$(lane_n s)" -lt "$WS" ]; do start_cell "${SQ[$sp]}" s; sp=$(( sp + 1 )); done
        [ "${#RUN[@]}" -gt 0 ] || break
        low="$total"; [ "$fp" -lt "${#FQ[@]}" ] && low="${FQ[$fp]}"; [ "$sp" -lt "${#SQ[@]}" ] && [ "${SQ[$sp]}" -lt "$low" ] && low="${SQ[$sp]}"
        for i in "${RUN[@]}"; do case "$i" in r:*) ;; *) [ "$i" -lt "$low" ] && low="$i";; esac; done
        if [ "$low" -lt "$total" ]; then IFS=$'\t' read -r key kind lang dir cell <<< "${ALL[$low]}"; state_put "$lap" "$low" "$total" "$key" "$cell" running; fi
        dp=""; wait -n -p dp "${!RUN[@]}"; [ -n "$dp" ] && [ -n "${RUN[$dp]:-}" ] || continue
        i="${RUN[$dp]}"; ln="${LANE[$dp]:-f}"; unset 'RUN[$dp]' 'LANE[$dp]'
        case "$i" in r:*) rn="${i#r:}"; rc=2; secs=0; read -r rc secs < "$TMPDIR/cycle/rres.$rn"; rm -f "$TMPDIR/cycle/rres.$rn"; finish_request "$rn" "$rc" "$secs"; continue;; esac
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
    # THE LAP'S NEW REDS (the cio 2026-11-10, CIO-82 on the grading-tube row; Lon's law of CIO-8): one telegram per designer, once a lap, never one per red
    if [ "$MODE_ARG" != --one ]; then
        gk=(); for k in $(printf '%s\n' "${ALL[@]}" | cut -f1 | awk '!s[$0]++'); do graded_this_lap "$k" && gk+=("$k"); done
        [ "${#gk[@]}" -gt 0 ] && log "$( . "$S4E_HARNESS/scripts/lib_grade_cell.sh"; tell_lap_new_reds "$(git -C "$S4E_SCRIP" rev-parse --short=9 HEAD 2>/dev/null)" "$TMPDIR/cycle/lap.$lap.results" "${gk[@]}" ) lap=$lap suites=${#gk[@]}"
    fi
    idx="$total"; state_put "$lap" "$idx" "$total" "$key" "$cell" done
done
