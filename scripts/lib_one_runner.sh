#!/bin/bash
# lib_one_runner.sh -- ONE RUNNER, ONE BOARD (Lon 2026-09-10 16:3x CDT, in-chat to ceo, verbatim: "Quit running the boards over and over
# again. Co-ordinate with one runner and one board. Do something to alleviate the churn."; RULES.md § FACT RULES, CEO-523).
# Sourced on line 2 of every rung suite/package board runner and called by corpus_suite_harness.py run: a board is refused (rc=2) to any
# seat but the one MODE's LANES: line names for the board's LANGUAGE (CEO-775 below; the centralized coo runner is history). Exempt: the bus's own
# computed `done`/dispatch run of a DONE-WHEN (S4E_DONE_WHEN_RUN=1, set by s4e_msg.sh, one run per closure) and a loud, named
# override (S4E_ONE_RUNNER_OVERRIDE="why", printed on the board). ⛔⭐ THE OVERRIDE ADMITS THE RUN AND NOTHING ELSE (ceo CEO-961,
# 2026-09-20, on the coo's report; row one-runner-override-gates-the-run-and-the-leaderboard-write-needs-its-own-consent): until that
# ruling the same variable also opened util_score_row.py's LEADERBOARD write, so there was no way to say "run the arm and publish
# nothing" and a runner driven as a CONTROL ARM -- the shape RULES.md § SHARED-NODE VERDICT SCOPE requires of every landing -- published
# a row as a side effect of being used as a measurement (measured: the coo's gimpel arm, COO-115, reverted by hand). A leaderboard write
# now needs its OWN loud recorded consent, S4E_SCORE_WRITE="why", or the seat the LANES: line names for that language; a control arm
# writes NOTHING by default. Identity: S4E_SEAT if set, else the ONE root-path map in
# util_score_row.derive_measurer (never a fourth copy). `bash lib_one_runner.sh --check` exits 0/2 silently for a Makefile arm to test.
# ⛔⭐ WHAT MAKES A RUN A BOARD IS THE POPULATION IT GRADES, NOT THE ENTRY POINT (ceo CEO-547 part 1, 2026-09-11, on the cfo's
# measurement). one_runner_guard <board> [suite_path]: with a suite_path OUTSIDE the corpus tree the run is NOT a board and is
# never refused -- a gate's own two-entry mktemp fixture publishes no row, writes no score, grades no corpus population and costs
# about a second. Called with no suite_path, the run is judged a board, so a caller that does not say what it grades is refused
# rather than waved through; every shell board runner above is exactly that caller. The python copy in corpus_suite_harness.py
# carries the same rule, and passes args.sno with the corpus root, because the two copies must stay word for word.
# ⛔⭐ ONE MEMORY SCOPE AT THE OUTERMOST BOARD (row instrument-698-runners-bound-the-clock-and-zero-bound-memory-..., the coo
# 2026-09-23; ../harness/scripts/util_mem_scope.py is the mechanism and its header the evidence). one_runner_guard calls this for a run it has
# judged a BOARD -- after its "a suite outside the corpus tree is not a board" return, before admission, so a refusal is printed once
# and inside the scope. The runner is re-run ONCE, with its original argv read from /proc (an argument it already shifted is not
# lost), inside ONE cgroup scope -- MemoryMax, MemorySwapMax=0, OOMPolicy=continue -- whose supervisor prints the peak beside the
# clock and turns a cgroup kill into a REFUSE rc=2 naming the cap and the peak, never a red. A runner already inside a scope (nested,
# or under make test) enters nothing; a `bash -c "source ..."` probe is not a runner ($0 is not the file at the bottom of the source
# stack); and a verb that never calls the guard -- scorecard_snobol4.sh oracle, whose last line util_ref_mint.sh parses -- is not a
# board and is left exactly as it was (measured: the first shape, entered at source time, broke that verb's protocol line).
one_runner_mem_scope() {
  [ -f "$0" ] && [ "${BASH_SOURCE[-1]}" = "$0" ] || return 0
  [ "${S4E_MEM_SCOPE:-}" != unbounded ] || return 0
  grep -qs '/s4e-mem-' /proc/self/cgroup && return 0
  [ -f "$(dirname "${BASH_SOURCE[0]}")/util_mem_scope.py" ] || return 0
  local _s4e_mem_argv
  mapfile -d '' _s4e_mem_argv < /proc/$$/cmdline
  exec python3 "$(dirname "${BASH_SOURCE[0]}")/util_mem_scope.py" enter --kind board -- "${_s4e_mem_argv[@]}"
}
one_runner_seat() {
  if [ -n "${S4E_SEAT:-}" ]; then printf '%s\n' "$S4E_SEAT"; return 0; fi
  local here; here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  S4E_HOME="${S4E_HOME:-$(cd "$here/../.." && pwd)}" python3 -c 'import sys; sys.path.insert(0,sys.argv[1]); import util_score_row as u; print(u.derive_measurer() or "")' "$here" 2>/dev/null
}
# ⛔⭐ WHOSE corpus IS IT? (coo 2026-09-18, row instruments-the-progress-fingerprint-gate-appends-no-rows-arms-1-and-2-red-and-arm-4-
# vacuous). CEO-547 part 1 says a gate's own mktemp fixture is not a board because it grades no corpus population -- but the test
# written for it asked a PATH question, "is the suite under the corpus root", and the corpus root is whatever S4E_HOME/corpus
# resolves to. A hermetic fixture that builds its own two-repo world and points S4E_HOME at it therefore lands INSIDE its own corpus
# tree and is judged a board: test_gate_progress_rows_carry_the_start_fingerprint.sh was DARK on origin for a day because its
# eight-entry scratch rungs was refused rc=2, the harness appended nothing, and arms 1 and 2 read FAIL for a reason that was never
# about fingerprints. ⭐ THE FACT ASKED IS THE ONE CEO-547 NAMES -- is this the population every seat has? -- and it is asked of the
# remote: a real checkout carries origin snobol4ever/corpus, a `git init` scratch world carries no remote at all. ⛔ BOTH FACTS, NEVER
# EITHER: a real board that merely redirected its progress writes is still a board, and a checkout that merely lost its remote is
# still the shared population. ⛔ UNREADABLE ANSWERS BOARD: a guard that cannot tell must refuse, never wave through.
ONE_RUNNER_SHARED_CORPUS_REMOTE='snobol4ever/corpus'
ONE_RUNNER_LIVE_PROGRESS_DB='/home/resources/progress/results.tsv'
one_runner_corpus_is_the_shared_population() {  # rc 0 = a checkout of the shared corpus; git that cannot run at all (127) answers yes
  # ⛔ A DIRECTORY THAT IS NO GIT REPOSITORY IS NOT THE SHARED POPULATION (the coo 2026-10-03): this answered yes on ANY git failure, so a
  # gate's scratch S4E_CORPUS (a mktemp tree, git-initialised or not, per the guard's own rule below) read as the shared corpus and a
  # runner whose population comes from S4E_CORPUS -- test_prolog_swi_suite.sh -- could never run as a fixture; it now answers as
  # one_runner_in_a_shared_checkout does (127 yes, any other failure no).
  local cr="$1" out rc
  out="$(git -C "$cr" remote -v 2>/dev/null)"; rc=$?
  [ "$rc" = 127 ] && return 0
  [ "$rc" = 0 ] || return 1
  case "$out" in *"$ONE_RUNNER_SHARED_CORPUS_REMOTE"*) return 0;; *) return 1;; esac
}
one_runner_writes_the_live_progress_table() {
  local db="${S4E_PROGRESS_DB:-$ONE_RUNNER_LIVE_PROGRESS_DB}"
  [ "$(readlink -f "$db" 2>/dev/null || printf '%s' "$db")" = "$(readlink -f "$ONE_RUNNER_LIVE_PROGRESS_DB" 2>/dev/null || printf '%s' "$ONE_RUNNER_LIVE_PROGRESS_DB")" ]
}
# ⛔⭐ OUTSIDE THE CONFIGURED ROOT IS NOT OUTSIDE THE SHARED CORPUS (coo 2026-09-23, found wiring the package runners for CEO-1229).
# The root below is whatever S4E_CORPUS or S4E_HOME say, so pointing either at a scratch directory made EVERY real corpus suite read
# "outside the corpus tree, not a board" -- and a seat no lane names was admitted to it, the harness too (its paths["corpus"] is
# S4E_HOME/corpus). The suite's OWN checkout answers instead, whatever the environment says: a suite inside a checkout of the shared
# corpus is a board. A directory outside every checkout (a gate's mktemp fixture) still is not.
one_runner_in_a_shared_checkout() {  # rc 0 = inside a checkout of the shared corpus; git that cannot run at all (127) answers yes
  local d="$1" out rc
  out="$(git -C "$d" remote -v 2>/dev/null)"; rc=$?
  [ "$rc" = 127 ] && return 0
  [ "$rc" = 0 ] || return 1
  case "$out" in *"$ONE_RUNNER_SHARED_CORPUS_REMOTE"*) return 0;; *) return 1;; esac
}
one_runner_suite_is_a_board() {
  local suite="$1" corpus sp cr
  corpus="${S4E_CORPUS:-${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/corpus}"
  sp="$(cd "$(dirname "$suite")" 2>/dev/null && pwd)/$(basename "$suite")" || return 0
  cr="$(cd "$corpus" 2>/dev/null && pwd)" || return 0
  [ -n "$cr" ] || return 0
  case "$sp" in "$cr"/*|"$cr") ;; *) one_runner_in_a_shared_checkout "$(dirname "$sp")" && return 0; return 1;; esac
  if ! one_runner_corpus_is_the_shared_population "$cr" && ! one_runner_writes_the_live_progress_table; then
    printf 'ONE-RUNNER: FIXTURE, not a board -- %s is under %s, which is not a checkout of %s, and this run appends to a scratch progress table. No row reaches the shared record (CEO-547 part 1).\n' "$sp" "$cr" "$ONE_RUNNER_SHARED_CORPUS_REMOTE"
    return 1
  fi
  return 0
}
# ⛔⭐⭐⭐ NO CENTRAL RUNNER: EVERY LANGUAGE HQ RUNS ITS OWN LANGUAGE'S TEST AND BENCHMARK SUITES (Lon 2026-09-16 10:5x CDT, in-chat
# to ceo, verbatim: "So do not have a centralized runner at all. Let's each HQ run its language test and benchmark suites."; ceo CEO-775,
# RULES.md § FACT RULE -- ONE RUNNER PER LANGUAGE). The property Lon wanted on 09-10 -- one runner per board, no two seats grading the
# same suite -- is kept by PARTITIONING the runner by language instead of centralizing it: a board belongs to the language it grades,
# and the seat that may run it is the seat MODE's LANES: line names for that language (rebus=cfo today). Nobody is the runner of every
# board; an officer is refused every board its lane does not name, exactly as a non-coo seat was before. The law source is the LANES
# line, never a name baked in here (CEO-756 still binds). A board with no language (board_packages.sh) is admitted to any LANES seat;
# its per-language runners refuse the seats that do not own them.
one_runner_lang() {
  local board="${1:-}" suite="${2:-}" sp l
  if [ -n "$suite" ]; then
    sp="$(cd "$(dirname "$suite")" 2>/dev/null && pwd)/$(basename "$suite")"
    # ⛔ A BARE LANGUAGE DIRECTORY IS A SUITE PATH TOO (coo 2026-09-23, found building test_rebus_bench_suite.sh): the pattern needed a
    # component BELOW the language directory, so corpus/benchmarks/rebus printed the WHOLE PATH as its "language", its slashes broke
    # one_runner_who's sed ("unknown option to `s'"), and the guard refused every seat -- the lane owner included -- under "the LANES
    # line names none for this language". A token that is not a bare name falls through to the board-name rules below, never to sed.
    case "$sp" in */corpus/tests/*|*/corpus/packages/*|*/corpus/benchmarks/*|*/corpus/demos/*)
      l="$(printf '%s\n' "$sp" | sed -E 's#.*/corpus/(tests|packages|benchmarks|demos)/([^/]+)(/.*)?$#\2#')"
      case "$l" in ''|*[!a-z0-9_]*) ;; *) printf '%s\n' "$l"; return 0;; esac;;
    esac
  fi
  case "$board" in
    *icon*|*jcon*|*ipl*|*arizona*) printf 'icon';;
    *prolog*|*inria*|*swi*|*gnu*|*logtalk*) printf 'prolog';;
    *pascal*|*fpc*|*pat_suite*) printf 'pascal';;
    *raku*|*roast*) printf 'raku';;
    *snocone*) printf 'snocone';;
    *rebus*) printf 'rebus';;
    *snobol4*|*snoflake*|*gimpel*|*aisnobol*|*csnobol4*|*dotnet*|*spitbol*|*testpgms*) printf 'snobol4';;
    board_packages*) printf 'all';;
    *) printf 'unknown';;
  esac
}
# ⛔⭐ AN ABSENT OR UNPARSEABLE LANES LINE REFUSES RATHER THAN RESOLVES (ceo CEO-957, 2026-09-19, on the coo's
# report; row instruments-an-absent-lanes-line-in-mode-must-refuse-not-resolve-every-language-to-the-coo).
# This function used to fall back to a BAKED SEAT NAME when MODE carried no LANES: line -- ceo under MODE CEO
# and coo under EVERY other mode, for EVERY language. That is the CENTRALIZED RUNNER that CEO-775 removed on
# Lon's word, reachable by deleting one line from MODE, and it contradicted the rule written three lines above
# it in this same file: the law source is the LANES line, never a name baked in here. It is the CEO-907 shape
# in a new place -- a flip rewrites the prose and leaves a machine-read line behind. Reproduced by both seats:
# a three-line MODE carrying QUARTET and no LANES read icon -> coo, rebus -> coo, all -> coo.
# one_runner_who now returns EMPTY, and one_runner_guard refuses rc=2 on an empty owner NAMING THE MISSING
# LANES LINE specifically -- a missing line and a line that names no owner for this language are DIFFERENT
# faults and a reader must not have to guess which one they are looking at.
one_runner_seat_is_language_hq() {   # an hq_* seat IS a language HQ by its name (Lon: "all 5 HQ's"; CEO-1342: the LANES line names the coo for every language, so an HQ is no longer found there -- read by name it is refused, read from LANES it would be ADMITTED with the override, the hole the coo closed 2026-09-28)
  case "$1" in hq_*) return 0;; *) return 1;; esac
}
one_runner_lanes_line() {
  grep -m1 '^LANES:' "${S4E_POST:-/home/resources/postoffice}/MODE" 2>/dev/null | sed 's/^LANES://'
}
one_runner_who() {
  local lang="${1:-}" lanes
  lanes="$(one_runner_lanes_line)"
  if [ -z "$lanes" ]; then printf ''; return 0; fi
  case "$lang" in
    all) printf '%s' "$lanes" | tr ' ' '\n' | sed -n 's/^[a-z0-9]*=//p' | sort -u | tr '\n' ' ' | sed 's/ $//';;
    ''|unknown) printf '';;
    *) printf '%s' "$lanes" | tr ' ' '\n' | sed -n "s/^$lang=//p" | head -1;;
  esac
}
one_runner_seat_admitted() {
  local seat="$1" who="$2" w
  for w in $who; do [ "$seat" = "$w" ] && return 0; done
  return 1
}
# ⛔⭐ THE BINARY IS STAMPED WHERE EVERY BOARD STARTS (coo 2026-09-16; hq_raku's report against themselves, ceo CEO-802; row instruments-
# a-board-does-not-refuse-when-its-own-seat-rebuilds-the-binary-under-it-the-raku-master-graded-a-tree-that-changed-mid-run): a board and a
# build share one mutable artefact, ./scrip + out/libscrip_rt.so, and a board whose seat ran `make` under it printed RakRungs 764/927 -- a
# measurement of nothing. one_runner_guard exports S4E_BIN_AT_START (lib_gate.sh's fingerprint shape: md5 first 12 of each file, space-
# joined); util_progress_append.py and util_score_row.py REFUSE when the binary they see differs, and corpus_suite_harness.py checks it
# before printing any board. An outer runner's stamp is kept by an inner one.
one_runner_bin_fingerprint() {
  # the checkout THIS FILE lives in, whose scrip every runner beside it grades ($SD/scrip) -- never S4E_HOME/SCRIP, which in a worktree is
  # another binary (the coo 2026-09-28: util_progress_append.py reads the same tree, so the start and the append-time readings agree)
  local _t _b _r
  _t="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
  _b="${SCRIP:-$_t/scrip}"; _r="${RT_DIR:-$_t/out}/libscrip_rt.so"
  [ -f "$_b" ] && [ -f "$_r" ] || return 1
  md5sum "$_b" "$_r" 2>/dev/null | cut -c1-12 | tr '\n' ' '
}
# one_runner_population_of "$@" -- the population a runner was pointed at by its caller: the word after --corpus on its command line,
# else its CORPUS variable, else nothing (the runner grades its default population, the one its environment resolves). ⛔ WHY (ceo
# CEO-1302 (c), 2026-09-27): the fixture exemption holds only for a population outside the shared corpus, and a runner that takes its
# population from an argument or its own variable called the guard with none, so the guard judged the default -- the real corpus --
# and refused a gate's scratch package (test_icon_jcon_suite.sh --corpus <mktemp>). Such a runner hands this to the guard.
one_runner_population_of() {
  while [ $# -gt 0 ]; do [ "$1" = --corpus ] && [ -n "${2:-}" ] && { printf '%s' "$2"; return 0; }; shift; done
  printf '%s' "${CORPUS:-}"
}
ONE_RUNNER_SMOKE_MODE_RUNNERS="test_icon_ipl_suite.sh test_snobol4_gimpel_suite.sh"   # runners with an area-smoke mode that writes nothing (see one_runner_guard)
ONE_RUNNER_SINGLE_FILE_RUNNERS="test_prolog_swi_suite.sh test_prolog_gnu_suite.sh"   # runners whose --file mode grades exactly one file and writes no progress row and no score row (see one_runner_guard)
one_runner_guard() {
  # ⭐ THE RUN'S START, STAMPED BY EVERY RUNNER FOR ITSELF (Lon 2026-10-08, in-chat to the ceo: "List in a grid the total time for each test
  # suite to run."; CEO-1562): util_score_row.py turns it into the row's wall clock (SUITES.tsv today_secs, the grid's Wall). Unconditional,
  # unlike S4E_BIN_AT_START: a runner a board launches times its own run, not its parent's.
  S4E_RUN_T0="$(date +%s)"; export S4E_RUN_T0
  if [ -z "${S4E_BIN_AT_START:-}" ]; then S4E_BIN_AT_START="$(one_runner_bin_fingerprint)" && export S4E_BIN_AT_START; fi
  local board="${1:-${0##*/}}" suite="${2:-}" seat who lang
  if [ -n "$suite" ] && ! one_runner_suite_is_a_board "$suite"; then return 0; fi
  one_runner_mem_scope
  if [ -z "${S4E_MEM_OOM_AT_START:-}" ]; then S4E_MEM_OOM_AT_START="$(python3 "$(dirname "${BASH_SOURCE[0]}")/util_mem_scope.py" oom-kills 2>/dev/null || echo 0)"; export S4E_MEM_OOM_AT_START; fi
  seat="$(one_runner_seat)"; lang="$(one_runner_lang "$board" "$suite")"; who="$(one_runner_who "$lang")"
  if [ -n "$seat" ] && one_runner_seat_admitted "$seat" "$who"; then return 0; fi
  # ⛔⭐ ONE SEAT, ONE LANGUAGE: A LANGUAGE HQ NEVER RUNS ANOTHER LANGUAGE'S BOARD -- NEITHER EXEMPTION BELOW ADMITS IT (Lon 2026-09-24,
  # in-chat to hq_prolog, verbatim: "Just have each seat run only their own test suites." / "We can not have all 5 HQ's deciding to
  # run all seven test suites simultaneously. Fix that."). An hq_* seat the LANES: line names falls through to the refusal; a
  # shared-code landing is graded by its lander on its OWN language and every other language reads it on its own next pass (CEO-775).
  # A GATE running a runner as an instrument fixture (a tiny slice inside the blocking set, never a seat's board run) says so with
  # S4E_ONE_RUNNER_FIXTURE="why" and is admitted for every seat; S4E_ONE_RUNNER_OVERRIDE is the SEAT's override and is not an HQ's.
  # ⛔⭐ AND THE EXEMPTION HOLDS ONLY FOR A POPULATION OUTSIDE THE SHARED CORPUS (ceo CEO-1302 (c), 2026-09-27, on the coo's COO-198
  # report): it admitted the variable alone, whatever the runner graded, so test_gate_nreturn_by_name_value_broken.sh and
  # test_gate_snocone_returns_codegen.sh ran test_corpus_snobol4.sh over the real 1991-entry rungs inside a control arm -- two whole
  # SnoRungs passes and 7964 dev-pass rows under a seat that runs no board. A suite path that reaches this line is a board (a scratch one
  # returned above), and a runner that names none is judged by the corpus its environment resolves -- S4E_CORPUS, else S4E_HOME/corpus
  # -- which is a fixture only when it lies inside no checkout of the shared corpus (one_runner_in_a_shared_checkout, the test a suite
  # outside the configured root already gets: a gate's mktemp root, git-initialised or not, is outside; a worktree of the corpus is
  # inside). Not admitted, the run falls through to the checks below, which end in the refusal.
  # ⭐ THE AREA SMOKE'S DELEGATED GRADE (the coo 2026-10-02, row instruments-the-area-smoke-grades-ipl-entries-without-their-sidecars-
  # and-reads-nine-false-reds): a package whose board grades each program under per-program sidecars the harness cannot apply (the IPL's
  # .pin shim, .dat stdin, .argv, .outfiles, fixtures) is smoked THROUGH ITS OWN RUNNER in that runner's smoke mode -- the named entries
  # only, no progress row, no score row (CEO-1342: every seat runs the area smoke; a smoke is not a board). Admitted only for a runner
  # in ONE_RUNNER_SMOKE_MODE_RUNNERS, which honours S4E_AREA_SMOKE_ENTRIES and writes nothing, and only with no suite path named.
  if [ -n "${S4E_AREA_SMOKE_ENTRIES:-}" ] && [ -z "$suite" ] && case " $ONE_RUNNER_SMOKE_MODE_RUNNERS " in *" $board "*) true ;; *) false ;; esac; then
    printf 'ONE-RUNNER AREA SMOKE by %s on %s: %s named entr(ies), no progress row and no score row\n' "${seat:-?}" "$board" "$(printf '%s\n' $S4E_AREA_SMOKE_ENTRIES | grep -c .)"; return 0
  fi
  # ⭐ ONE FILE IS NOT A BOARD (ceo CEO-1664, 2026-10-11, measured: under SEPTET hq_prolog, the cto and the cfo work SWI's 1563 reds
  # class by class, and every one of them was refused rc 2 grading the one plunit file its row names -- the runner's own --file mode,
  # which its header calls "a development aid, never a board; writes no row", fell through to the board refusal). A runner in
  # ONE_RUNNER_SINGLE_FILE_RUNNERS sets S4E_ONE_RUNNER_SINGLE_FILE from its OWN argv on line 2 (empty without --file, so an inherited
  # value never admits a whole run), grades exactly one file in that mode (it refuses a --file matching more), and writes no progress
  # row and no score row; it is admitted for every seat and for the bus's computed done, so a class row's DONE-WHEN can name its file.
  if [ -n "${S4E_ONE_RUNNER_SINGLE_FILE:-}" ] && case " $ONE_RUNNER_SINGLE_FILE_RUNNERS " in *" $board "*) true ;; *) false ;; esac; then
    printf 'ONE-RUNNER SINGLE FILE by %s on %s: %s, no progress row and no score row\n' "${seat:-?}" "$board" "$S4E_ONE_RUNNER_SINGLE_FILE"; return 0
  fi
  if [ -n "${S4E_ONE_RUNNER_FIXTURE:-}" ]; then
    local _fxpop="${S4E_CORPUS:-${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/corpus}"
    if [ -z "$suite" ] && ! one_runner_in_a_shared_checkout "$_fxpop"; then printf 'ONE-RUNNER FIXTURE by %s on %s: %s\n' "${seat:-?}" "$board" "$S4E_ONE_RUNNER_FIXTURE"; return 0; fi
    printf '⛔ ONE-RUNNER FIXTURE NOT ADMITTED: %s grades %s, the shared corpus or a population a board reads -- the exemption admits a scratch population only (ceo CEO-1302 (c)); point the fixture at one (S4E_HOME, --corpus, the runner'"'"'s *_SUITE) with a scratch S4E_PROGRESS_DB\n' "$board" "${suite:-$_fxpop}" >&2
  fi
  local _hq=0; [ -n "$seat" ] && one_runner_seat_is_language_hq "$seat" && _hq=1
  if [ "$_hq" = 0 ]; then
    # ⛔ DONE RUNS NO BOARD FOR ANY SEAT (ceo CEO-1342 clause 5, the coo's row bus-done-runs-no-board-for-any-seat-..., 2026-09-28): the bus's
    # computed done (S4E_DONE_WHEN_RUN=1) was the one road by which a non-tester seat still ran a suite; it is refused here and in the
    # harness alike. A DONE-WHEN that needs a suite's verdict reads the coo's SUITE TABLE row at a tree at or after the landing
    # (../harness/scripts/util_suite_row_at_or_after.sh <suite-key> <tree>); the lane owner's own done never reaches this line (admitted above).
    if [ "${S4E_DONE_WHEN_RUN:-}" = 1 ]; then printf '⛔ REFUSE(2) DONE RUNS NO BOARD FOR ANY SEAT (ceo CEO-1342 clause 5): %s is a board, seat %s is not its runner, and the bus computed done no longer admits it -- read the coo'"'"'s SUITE TABLE row instead: ../harness/scripts/util_suite_row_at_or_after.sh <suite-key> <tree>\n' "$board" "${seat:-?}"; return 2; fi
    if [ -n "${S4E_ONE_RUNNER_OVERRIDE:-}" ]; then printf '⚠ ONE-RUNNER OVERRIDE by %s on %s: %s\n' "${seat:-?}" "$board" "$S4E_ONE_RUNNER_OVERRIDE"; return 0; fi
  else
    printf '⛔ ONE SEAT, ONE LANGUAGE: %s is a language HQ -- no S4E_ONE_RUNNER_OVERRIDE and no DONE-WHEN admits it to a %s board (Lon 2026-09-24: "Just have each seat run only their own test suites.")\n' "$seat" "${lang:-unknown}" >&2
  fi
  local _noseat
  if [ -z "$(one_runner_lanes_line)" ]; then
    _noseat="<NO SEAT: the MODE file carries NO LANES: line at all, so no language has an owner. This REFUSES and no longer resolves to a baked name (ceo CEO-957). Fix MODE, or, in a fixture, declare a lane table the way gate_stage_picker_lane_table does>"
  else
    _noseat="<no seat -- the LANES line is present but names none for this language>"
  fi
  printf '⛔ REFUSE(2) ONE RUNNER, ONE BOARD -- ONE RUNNER PER LANGUAGE: %s is a %s board and seat %s is not %s, the seat MODE LANES: names for %s. Every language HQ runs its OWN language suites, once per landing, on origin HEAD, and writes its own rows (Lon 2026-09-16 10:5x, MODE line 2, RULES.md § ONE RUNNER PER LANGUAGE, CEO-775); another language board is an ASK to that language HQ. S4E_ONE_RUNNER_OVERRIDE="why" is loud and recorded, and it admits THE RUN ONLY -- publishing a leaderboard row needs its own consent, S4E_SCORE_WRITE="why" (ceo CEO-961).\n' "$board" "$lang" "${seat:-?}" "${who:-$_noseat}" "$lang"
  return 2
}
# ⛔⭐ THE SEAM: EVERY GUARD SHIPS A SANCTIONED WAY TO BE TRIPPED THAT DOES NOT REQUIRE DOING THE FORBIDDEN THING
# (ceo CEO-560, 2026-09-11, on hq_B's self-report and hq_U's mirror case the same hour; FINDING-2026-09-11-hq_B-a-guard-
# whose-only-proof-of-firing-is-committing-the-act-it-forbids.md). Until now the ONLY route to this guard's refusal was
# S4E_SEAT=coo -- i.e. asserting another seat's identity, the exact act the guard exists to stop -- so proving it fires
# meant committing the offence. A guard that can only be tested that way is tested that way OR NOT AT ALL, and "not at
# all" is how icn_port_trace got to 22 of 24. ⭐ THE PROBE SEAT IS INERT BY CONSTRUCTION: it is a reserved name that can
# never be a real seat, so it can only ever REMOVE privilege and never grant it -- the opposite of S4E_ONE_RUNNER_OVERRIDE,
# which proves the BYPASS works and says nothing about the refusal. Those are different assertions and a seam must not
# conflate them. The caller stays themselves throughout; the coo can run this and see a refusal without ceasing to be the coo.
ONE_RUNNER_PROBE_SEAT='__one_runner_probe_not_a_seat__'
one_runner_prove_seam() {
  local out rc fails=0 outside
  out=$(S4E_SEAT="$ONE_RUNNER_PROBE_SEAT" S4E_DONE_WHEN_RUN='' S4E_ONE_RUNNER_OVERRIDE='' S4E_ONE_RUNNER_FIXTURE='' one_runner_guard 'one-runner-seam-probe' "${S4E_CORPUS:-${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/corpus}" 2>&1); rc=$?
  if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q 'REFUSE(2) ONE RUNNER'; then printf '  OK   ARM 1 the guard REFUSES a board to a seat its language LANE does not name (rc=2, message asserted)
'
  else printf '  FAIL ARM 1 expected rc=2 and a REFUSE message on a corpus-rooted board, got rc=%s: %s
' "$rc" "${out:-<silent>}"; fails=$((fails+1)); fi
  outside="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  S4E_SEAT="$ONE_RUNNER_PROBE_SEAT" S4E_DONE_WHEN_RUN='' S4E_ONE_RUNNER_OVERRIDE='' S4E_ONE_RUNNER_FIXTURE='' one_runner_guard 'one-runner-seam-probe' "$outside" >/dev/null 2>&1; rc=$?
  if [ "$rc" = 0 ]; then printf '  OK   ARM 2 the guard ADMITS a suite path OUTSIDE the corpus tree (a gate fixture is not a board)
'
  else printf '  FAIL ARM 2 expected rc=0 for a non-corpus suite path, got rc=%s
' "$rc"; fails=$((fails+1)); fi
  [ "$fails" = 0 ] || return 1
  printf 'ONE-RUNNER SEAM: PASS -- refusal and admission both proven, no seat identity asserted
'
}
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "${1:-}" in
    --prove-seam) one_runner_prove_seam; exit $?;;
    --check) seat="$(one_runner_seat)"; lang="$(one_runner_lang "${2:-}" "${3:-}")"; { { [ -n "$seat" ] && one_runner_seat_admitted "$seat" "$(one_runner_who "$lang")"; } || [ -n "${S4E_ONE_RUNNER_FIXTURE:-}" ] || { ! one_runner_seat_is_language_hq "$seat" && { [ "${S4E_DONE_WHEN_RUN:-}" = 1 ] || [ -n "${S4E_ONE_RUNNER_OVERRIDE:-}" ]; }; }; } && exit 0; exit 2;;
    --who) one_runner_who "$(one_runner_lang "${2:-}" "${3:-}")"; echo; exit 0;;
    --lang) one_runner_lang "${2:-}" "${3:-}"; echo; exit 0;;
    --seat) one_runner_seat; exit 0;;
    *) echo "usage: lib_one_runner.sh --check <board> [suite] | --who <board> [suite] | --lang <board> [suite] | --seat | --prove-seam  (or source it and call one_runner_guard <board> [suite_path])" >&2; exit 2;;
  esac
fi
