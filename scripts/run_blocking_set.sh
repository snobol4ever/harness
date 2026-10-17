#!/usr/bin/env bash
# run_blocking_set.sh -- RUN EVERY ARM OF THE BLOCKING SET, THEN REPORT.  The loop-and-report driver behind
# `make test`, ruled CEO-582 (2026-09-11) on the cfo's first full census of that target.
#
# THE DEFECT IT EXISTS TO KILL, MEASURED BEFORE IT WAS BUILT: `make test` was ONE target of ~150 recipe
# lines and make ABORTS ON THE FIRST FAILING LINE, so when arm 15 went red the set died 24 seconds in and
# 131 ARMS NEVER EXECUTED -- for all 13 seats, for as long as that arm stayed red.  Not red.  Not green.
# UNMEASURED, which our own denominator law names the worst of the three states.  `make -k` does not rescue
# it (measured, 149s, same single red): -k continues across TARGETS, never across the lines of ONE recipe.
# The set could therefore only ever reveal ONE red per cure cycle, each cycle paying a build.  The cfo's
# loop-and-continue census found EIGHT non-green where the target reported ONE -- five reds and three
# refusals, one of which would have passed VACUOUSLY.  WE REPORTED 1 OF 8.
#
# ⛔ THE GUARDS, all from the ruling and all mandatory -- nothing here is weakened relative to abort-first:
#   · the exit code stays NON-ZERO whenever a blocking arm is red (rc=1) or refused (rc=2);
#   · REDS AND REFUSALS ARE PRINTED AS SEPARATE CLASSES, never summed, because rc=1 FAILED and rc=2
#     COULD-NOT-MEASURE are different facts and the second is the better hiding place;
#   · the summary SATISFIES ITS OWN DENOMINATOR -- green + red + refused == arms, printed, and the driver
#     REFUSES rc=2 if that identity does not hold, so a run that dies partway can never read as a clean one.
#
# ⭐ THE POPULATION IS DECLARED, NOT DISCOVERED, and it is declared where it always was: the recipe lines of
# the `test-sequential` target in the Makefile, with every per-arm comment they carry.  That target is the
# old abort-on-first-red form, kept RUNNABLE on purpose -- it is the declaration this driver reads AND an
# executable twin of it, so the two cannot diverge silently, and `make test-sequential` remains the way to
# bisect a set that has gone strange.  test_gate_make_test_loops_and_reports.sh pins the agreement.
#
# ⭐ WHY NOT A SEPARATE arms.txt (the preflight shape): preflight's population genuinely cannot be derived
# (its own comment says a static grep classifies it wrongly in both directions).  This one can be, and the
# arms carry ~50 lines of measured provenance comments that thirteen seats grep by gate name in the
# Makefile.  Moving them would have broken every `grep <gate> Makefile` in the org to save a parser.
#
# USAGE
#   bash ../harness/scripts/run_blocking_set.sh                  # run the declared set, loop and report
#   bash ../harness/scripts/run_blocking_set.sh --list           # print the arms and their class, run nothing
#   bash ../harness/scripts/run_blocking_set.sh --arms-from F    # run an arm list from a file (one per line) instead
#   bash ../harness/scripts/run_blocking_set.sh --target T       # read a different declaration target
#   bash ../harness/scripts/run_blocking_set.sh --shard K/N      # run ONE interleaved slice of the declared set
#   bash ../harness/scripts/run_blocking_set.sh --shards N       # fan out N slices as children and MERGE their report
#   bash ../harness/scripts/run_blocking_set.sh --serial-arms F  # read a different declaration of the arms that run alone
#   bash ../harness/scripts/run_blocking_set.sh --shared-surfaces F  # read a different declaration of the watched surface
#
# ⭐ SHARDS, AND WHAT THEY ARE ACCEPTED ON (ceo CEO-829, from the cfo's economy measurement: 338 arms, ~35
# minutes at load 1.5-2.6, against an origin/main that took 22 landings today -- and the gaps between the last
# twelve were 0,2,2,9,4,0,3,3,322,1,3,49 minutes, so THE AVERAGE HIDES THE SHAPE: landings arrive in BURSTS of
# three or four inside five minutes and a 35-minute set cannot fit inside a burst at all).
# ⛔ THE ACCEPTANCE IS NOT A SPEEDUP. It is that a sharded run reds THE SAME RED NAME SET as a sequential one on
# the same tree (CEO-825 clause 1): an arm whose verdict changes with HOW it was run is the finding, and a faster
# set that quietly greens an arm is worth less than the slow one. Speed is reported BESIDE name-set identity,
# never instead of it; test_gate_blocking_set_shards_agree_with_sequential.sh is what asserts it.
# ⛔ THE HAZARD IS REAL AND THE CENSUS THAT FOUND IT UNDER-DETECTS, so hazardous arms are DECLARED, not sniffed:
# 280 of 336 arms build a mktemp workdir, but the port-trace gates cd into the checkout ROOT (CLAUDE.md records
# their tmp3/tmp4 litter there), timing-sensitive arms read a loaded box differently, and the one-runner board
# arms must not run twice at once. ../harness/scripts/blocking_set_serial_arms.txt names the patterns that RUN ALONE in the
# parent before any fan-out. A null hazard census bounds the probe, not the thing probed.
# ⛔⭐ AND THE REFUSAL MATTERS MORE THAN THE SPEED (coo 2026-09-20, row instruments-the-blocking-set-is-367-
# serial-arms-and-it-caps-every-seat-in-the-fleet, on Lon's TENET). A fan-out that turns a COLLISION into a RED
# manufactures an UNATTRIBUTABLE FINDING: the arm does not reproduce serially, so a seat either chases a defect
# that is not there or learns to discount reds -- and ten seats on one box cannot afford either. So the fan-out
# WATCHES a declared shared surface (../harness/scripts/blocking_set_shared_surfaces.txt) around every arm, and two arms
# whose observed change sets intersect on one path while their run windows OVERLAP are BOTH rc=2 REFUSED, named
# with each other and with the path. Never red. A refusal says the one true thing -- THIS ARM WAS NOT MEASURED --
# and the cure for a repeat offender is a line in blocking_set_serial_arms.txt, never a tolerance.
# ⛔ THE DETECTOR HAS TWO FAILURE DIRECTIONS AND THE GATE PROVES BOTH: unwired, a race reads as a flaky red
# (M1); greedy, an innocent red or green is buried under a refusal and the set stops being able to report a
# defect at all (M2). test_gate_blocking_set_parallel_agrees_with_serial.sh trips on each.
# An arm line prefixed `-` is REPORTED: it is run and classified like any other, it is printed in its class,
# and it CANNOT change the exit code -- exactly what a leading `-` already meant to make.
#
# EXIT: 0 every blocking arm green / 1 at least one blocking arm RED / 2 no blocking red but at least one
# blocking REFUSAL, or the driver itself could not measure (no arms, an unexpandable make variable, a
# denominator that does not sum).
set -u
NAME=run_blocking_set
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
MAKEFILE="$ROOT/Makefile"
DECL_TARGET="test-sequential"
ARMS_FILE=""
LIST_ONLY=0
SHARD=""
SHARDS=""
SERIAL_FILE="$HERE/blocking_set_serial_arms.txt"
SURFACE_FILE="$HERE/blocking_set_shared_surfaces.txt"
# ⛔ THE TWO KNOBS BELOW ARE SOURCE CONSTANTS AND NOT ENVIRONMENT READS, ON PURPOSE. A safety check a seat can
# switch off from the environment is a safety check that will be off on the day it mattered. The acceptance gate
# mutates a COPY of this file at these two anchors -- which is what a mutant is: a patch, not a back door.
RACE_DETECT=1              # ⛔ MUTANT ANCHOR M1 -- 0 unwires the detector, and a race then reads as a flaky RED
RACE_NEEDS_SHARED_PATH=1   # ⛔ MUTANT ANCHOR M2 -- 0 convicts on time alone, and every concurrent arm is refused
refuse() { echo "⛔ REFUSED(2) [$NAME]: $*" >&2; exit 2; }
while [ $# -gt 0 ]; do
    case "$1" in
        --list) LIST_ONLY=1 ;;
        --arms-from) shift; [ $# -gt 0 ] || refuse "--arms-from needs a file"; ARMS_FILE="$1" ;;
        --arms-from=*) ARMS_FILE="${1#*=}" ;;
        --target) shift; [ $# -gt 0 ] || refuse "--target needs a name"; DECL_TARGET="$1" ;;
        --target=*) DECL_TARGET="${1#*=}" ;;
        --makefile) shift; [ $# -gt 0 ] || refuse "--makefile needs a file"; MAKEFILE="$1" ;;
        --makefile=*) MAKEFILE="${1#*=}" ;;
        --shard) shift; [ $# -gt 0 ] || refuse "--shard needs K/N"; SHARD="$1" ;;
        --shard=*) SHARD="${1#*=}" ;;
        --shards) shift; [ $# -gt 0 ] || refuse "--shards needs a count"; SHARDS="$1" ;;
        --shards=*) SHARDS="${1#*=}" ;;
        --serial-arms) shift; [ $# -gt 0 ] || refuse "--serial-arms needs a file"; SERIAL_FILE="$1" ;;
        --serial-arms=*) SERIAL_FILE="${1#*=}" ;;
        --shared-surfaces) shift; [ $# -gt 0 ] || refuse "--shared-surfaces needs a file"; SURFACE_FILE="$1" ;;
        --shared-surfaces=*) SURFACE_FILE="${1#*=}" ;;
        -h|--help) sed -n '1,40p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) refuse "unrecognised argument '$1' -- a driver that treats an unknown flag as a filename is how a typo becomes a plausible answer" ;;
    esac
    shift
done
# ⛔⭐ ONE MEMORY SCOPE AROUND THE WHOLE SET (row instrument-698-runners-..., the coo 2026-09-23; ../harness/scripts/util_mem_scope.py): the
# real declaration is run inside ONE cgroup scope at the blocking-set cap, re-run once from /proc with its original argv; every shard
# is a child and inherits it. A fixture declaration (--arms-from, another --makefile or --target) and --list are left alone, and a
# set already inside a scope enters nothing. A copy of this driver in a gate's scratch tree, with no util_mem_scope.py beside
# it, says so on stderr and runs unscoped (test_gate_make_test_loops_and_reports.sh builds exactly that tree).
if [ -z "$ARMS_FILE" ] && [ "$MAKEFILE" = "$ROOT/Makefile" ] && [ "$DECL_TARGET" = test-sequential ] && [ "$LIST_ONLY" = 0 ] \
   && [ "${S4E_MEM_SCOPE:-}" != unbounded ] && ! grep -qs '/s4e-mem-' /proc/self/cgroup; then
    if [ -f "$HERE/util_mem_scope.py" ]; then
        mapfile -d '' _s4e_mem_argv < /proc/$$/cmdline
        exec python3 "$HERE/util_mem_scope.py" enter --kind blocking-set -- "${_s4e_mem_argv[@]}"
    fi
    echo "⚠ [mem_scope] no util_mem_scope.py beside $HERE/run_blocking_set.sh -- this run carries no memory scope" >&2
fi
MEM_SCOPE_DIR="$(python3 "$HERE/util_mem_scope.py" dir 2>/dev/null)"
mem_oom_kills() { [ -n "$MEM_SCOPE_DIR" ] && awk '$1=="oom_kill"{print $2}' "$MEM_SCOPE_DIR/memory.events" 2>/dev/null; }
# ⛔ THE DECLARATION IS READ, NEVER GUESSED.  A recipe line is an arm; a `#`-only recipe line is prose and is
# skipped; the trailing `   # ...` comment is the arm's provenance and is stripped from the command but kept
# for nothing else -- it is a SHELL comment today (make passes recipe lines to sh verbatim), so leaving it in
# would also be harmless.  We strip it so the make-variable check below can look at the COMMAND only.
FLAGS=(); CMDS=()
read_decl() {
    local line flag cmd
    while IFS= read -r line; do
        case "$line" in
            "	#"*) continue ;;
            "	"*) line="${line#	}" ;;
            *) continue ;;
        esac
        flag=""
        case "$line" in -*) flag="-"; line="${line#-}" ;; esac
        cmd="$(printf '%s\n' "$line" | sed 's/[ 	]#.*$//; s/[ 	]*$//')"
        [ -n "$cmd" ] || continue
        FLAGS+=("$flag"); CMDS+=("$cmd")
    done < <(awk -v t="^${DECL_TARGET}:" '$0 ~ t {f=1; next} f && /^$/ {exit} f' "$MAKEFILE")
}
read_file() {
    local line flag cmd
    while IFS= read -r line; do
        case "$line" in ""|"#"*) continue ;; esac
        flag=""
        case "$line" in -*) flag="-"; line="${line#-}" ;; esac
        cmd="$(printf '%s\n' "$line" | sed 's/[ 	]#.*$//; s/[ 	]*$//')"
        [ -n "$cmd" ] || continue
        FLAGS+=("$flag"); CMDS+=("$cmd")
    done < "$1"
}
if [ -n "$ARMS_FILE" ]; then
    [ -f "$ARMS_FILE" ] || refuse "arms file '$ARMS_FILE' not found"
    read_file "$ARMS_FILE"
    SOURCE="$ARMS_FILE"
else
    [ -f "$MAKEFILE" ] || refuse "$MAKEFILE not found"
    grep -q "^${DECL_TARGET}:" "$MAKEFILE" || refuse "no '${DECL_TARGET}:' target in $MAKEFILE -- the declaration this driver reads is gone or renamed"
    read_decl
    SOURCE="$MAKEFILE:${DECL_TARGET}"
fi
N=${#CMDS[@]}
# ⛔ ZERO ARMS IS A REFUSAL, NOT A GREEN RUN.  An empty population printing the success shape is the exact
# false-green `make test` itself carried for months (named in .PHONY, no recipe, exit 0 having run nothing).
[ "$N" -gt 0 ] || refuse "extracted ZERO arms from $SOURCE -- a set that graded nothing must never print the success shape"
# ⛔ MAKE VARIABLES.  make expands these before the shell sees them and this driver is not make.  `$(MAKE)` is
# the one form the declaration uses and the one form we expand; ANY other is a refusal rather than a guess,
# because `$(FOO)` handed to bash is command substitution and would run FOO as a command.
for i in $(seq 0 $((N - 1))); do
    CMDS[$i]="${CMDS[$i]//\$(MAKE)/${MAKE:-make}}"
    case "${CMDS[$i]}" in
        *'$('*) refuse "arm $((i + 1)) carries a make variable this driver cannot expand: ${CMDS[$i]}" ;;
    esac
done
# ⛔ THE SERIAL SET IS DECLARED, NOT SNIFFED (see the header).  A pattern here matches an arm's command as a
# substring; a matching arm NEVER runs inside a shard.  A missing file is not a refusal -- it means no arm has
# been declared hazardous yet -- but an UNREADABLE one is, because "I could not read the hazard list" and "the
# hazard list is empty" are the two facts this driver must never conflate.
SERIAL_PATS=()
if [ -n "$SERIAL_FILE" ] && [ -e "$SERIAL_FILE" ]; then
    [ -r "$SERIAL_FILE" ] || refuse "serial-arms file '$SERIAL_FILE' exists but cannot be read -- an unreadable hazard list is not an empty one"
    while IFS= read -r _l; do
        case "$_l" in ""|"#"*) continue ;; esac
        SERIAL_PATS+=("$_l")
    done < "$SERIAL_FILE"
fi
is_serial_arm() {  # is_serial_arm <cmd>
    local c="$1" pat
    for pat in ${SERIAL_PATS[@]+"${SERIAL_PATS[@]}"}; do
        case "$c" in *"$pat"*) return 0 ;; esac
    done
    return 1
}
# ⛔⭐ THE RACE DETECTOR.  The watched surface is DECLARED the way the serial arms are (see the header): an
# unreadable declaration REFUSES, because "I could not read the surface list" and "the surface list is empty"
# are the two facts this driver must never conflate.  A MISSING file means no surface has been declared yet and
# the detector is simply off -- and it SAYS SO on the stamp line rather than letting a silent zero read as "no
# races found".
WATCH_DIRS=(); EXCL_RE=""; RACE_ON=0; RACE_STATE="off"
race_load_surfaces() {
    WATCH_DIRS=(); EXCL_RE=""
    if [ "$RACE_DETECT" != 1 ]; then RACE_STATE="UNWIRED(M1)"; return 0; fi
    if [ -z "${SURFACE_FILE:-}" ] || [ ! -e "$SURFACE_FILE" ]; then RACE_STATE="no-surface-declared"; return 0; fi
    [ -r "$SURFACE_FILE" ] || refuse "shared-surfaces file '$SURFACE_FILE' exists but cannot be read -- an unreadable surface declaration is not an empty one"
    local _l
    while IFS= read -r _l; do
        case "$_l" in
            ""|"#"*) continue ;;
            "!"*) EXCL_RE="${EXCL_RE:+$EXCL_RE|}${_l#!}" ;;
            /*) WATCH_DIRS+=("$_l") ;;
            *) WATCH_DIRS+=("$ROOT/$_l") ;;
        esac
    done < "$SURFACE_FILE"
    if [ "${#WATCH_DIRS[@]}" -gt 0 ]; then RACE_STATE="on"; else RACE_STATE="no-surface-declared"; fi
}
race_now() { date +%s%N; }
race_snapshot() {  # race_snapshot <outfile> -- path, mtime, size of every TOP-LEVEL entry of each watched dir
    local d
    for d in ${WATCH_DIRS[@]+"${WATCH_DIRS[@]}"}; do
        [ -d "$d" ] || continue
        find "$d" -maxdepth 1 -mindepth 1 -printf '%p\t%T@\t%s\n' 2>/dev/null
    done | awk -F'\t' -v re="$EXCL_RE" 're == "" || $1 !~ re' | sort > "$1"
}
race_before() {
    RACE_ON=0
    [ "$RACE_STATE" = on ] || return 0
    [ -n "${S4E_BLOCKING_WITNESS:-}" ] && [ -d "${S4E_BLOCKING_WITNESS:-/nonexistent}" ] || return 0
    RACE_ON=1
    RACE_SNAP_A="$(mktemp)"; RACE_SNAP_B="$(mktemp)"
    race_snapshot "$RACE_SNAP_A"
    RACE_T0="$(race_now)"
}
race_after() {  # race_after <cmd>
    [ "${RACE_ON:-0}" = 1 ] || return 0
    local t1 rec p
    t1="$(race_now)"
    race_snapshot "$RACE_SNAP_B"
    rec="$(mktemp)"
    # ⛔ THE WINDOW IS RECORDED FOR EVERY ARM, WRITES OR NONE.  An arm that changed nothing still needs its
    # window on the record: it is what makes "these two overlapped" answerable at all, and it is the only thing
    # the greedy mutant can convict on -- which is how the gate proves the path test is load-bearing.
    printf 'ARMWINDOW\t%s\t%s\t%s\n' "$RACE_T0" "$t1" "$1" > "$rec"
    while IFS= read -r p; do
        [ -n "$p" ] || continue
        printf 'ARMWRITE\t%s\t%s\t%s\t%s\n' "$p" "$RACE_T0" "$t1" "$1" >> "$rec"
    done < <(comm -3 "$RACE_SNAP_A" "$RACE_SNAP_B" | sed 's/^\t//' | cut -f1 | sort -u)
    ( flock 9 2>/dev/null; cat "$rec" >> "$S4E_BLOCKING_WITNESS/writes.tsv" ) 9>> "$S4E_BLOCKING_WITNESS/.lock"
    rm -f "$RACE_SNAP_A" "$RACE_SNAP_B" "$rec"
    RACE_ON=0
}
race_collisions() {  # race_collisions <witness writes.tsv> -> "path<TAB>cmd" per raced arm, sorted
    awk -F'\t' -v need="$RACE_NEEDS_SHARED_PATH" '
        $1 == "ARMWINDOW" { n++; T0[n] = $2 + 0; T1[n] = $3 + 0; C[n] = $4 }
        $1 == "ARMWRITE"  { m++; P[m] = $2; W0[m] = $3 + 0; W1[m] = $4 + 0; WC[m] = $5; G[$2] = G[$2] " " m }
        END {
            if (need == 1) {
                for (p in G) {
                    k = split(G[p], a, " ")
                    for (i = 1; i <= k; i++) for (j = i + 1; j <= k; j++) {
                        x = a[i]; y = a[j]
                        if (WC[x] == WC[y]) continue
                        if (W0[x] < W1[y] && W0[y] < W1[x]) { print P[x] "\t" WC[x]; print P[x] "\t" WC[y] }
                    }
                }
            } else {
                for (i = 1; i <= n; i++) for (j = i + 1; j <= n; j++) {
                    if (C[i] == C[j]) continue
                    if (T0[i] < T1[j] && T0[j] < T1[i]) { print "<any path -- M2: convicted on time alone>\t" C[i]; print "<any path -- M2: convicted on time alone>\t" C[j] }
                }
            }
        }' "$1" | sort -u
}
# ⛔ THE STAMP LINE IS ITS OWN LINE AND NOT AN EXTENSION OF THE SUMMARY.  test_gate_make_test_loops_and_reports.sh
# asserts the summary line by EQUALITY, and an instrument that breaks its own acceptance gate to report a number
# has not reported a number.  Both shapes print this line, spelled identically, so two runs are comparable by
# construction rather than by whoever remembered to note the load.
race_stamp_line() {  # race_stamp_line <shape> <arms> <wall-seconds> <load-at-start> <raced-arm-count>
    local tree
    tree="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    [ -n "$(git -C "$ROOT" status --porcelain 2>/dev/null)" ] && tree="$tree-dirty"
    printf 'blocking set stamp: shape=%s arms=%s wall=%ss load=%s->%s tree=%s detector=%s raced=%s\n' \
        "$1" "$2" "$3" "$4" "$(cut -d" " -f1 /proc/loadavg 2>/dev/null || echo ?)" "$tree" "$RACE_STATE" "$5"
}
# ⛔⭐⭐ A RUN THAT DIES MUST SAY WHO KILLED IT (coo 2026-09-20, row instruments-a-blocking-set-run-is-killed-
# from-outside-and-no-seat-completed-one-today, ceo on the cfo's CFO-147). FIVE DEATHS, THREE SEATS, ONE
# AFTERNOON: the cfo at arm 103 with SIGTERM and at arm 166 with SIGKILL DESPITE setsid, hq_prolog at arm 6
# after thirty seconds, hq_raku at 18 and at 61 -- and not one of them said what ended it, so every seat spent
# the afternoon guessing between a wall clock, an OOM and another seat's pkill. Ten seats share ONE UNIX USER,
# so a `pkill -f` keyed on a script name reaches every other seat's run; the cto signalled eleven pids over
# shared patterns at 01:4x and reported it unprompted, which is the existence proof.
#   · the CATCHABLE signals are trapped and print SIGNAL, ARM REACHED, ELAPSED, counts so far, and the SENDER
#     looked up in the kill ledger s4e_kill_mine.sh now writes -- or "no ledger entry", which is its own fact.
#   · ⛔ SIGKILL CANNOT BE TRAPPED AND NOTHING INSIDE A VICTIM EVER REPORTS IT. That is exactly why the RUNSTATE
#     exists: the next run in this root POSTMORTEMS a state file that was never completed, so a SIGKILL becomes
#     legible after the fact instead of vanishing. A mechanism that only handles the signals you can catch
#     handles the ones that do not happen.
#   · ⛔ THE RUNSTATE LIVES IN /tmp, PER ROOT, AND NEVER UNDER THE CHECKOUT. Writing it under out/ or the root
#     would move a watched path on every arm and make the race detector convict every concurrent arm of racing
#     -- the instrument sabotaging its own sibling, one directory apart.
#   · a trap fires when the arm in flight returns, because bash defers traps during a foreground child. When a
#     `pkill -f` hits the whole tree that is immediate; when only the parent is signalled the report comes at
#     the end of the current arm. Late, never lost, and said here rather than discovered.
RUNSTATE=""   # ⛔ its VALUE is set below, once --shard is parsed: a shard child is supervised by its parent and
              # writes no state of its own, or N children would clobber one file and postmortem each other.
KILL_LEDGER="${S4E_KILL_LEDGER:-${S4E_POST:-/home/resources/postoffice}/kills.tsv}"
RUN_T0=$(date +%s); RUN_ARM_I=0; RUN_ARM_CMD=""
runstate_write() {  # runstate_write <state-word>
    [ -n "$RUNSTATE" ] || return 0
    { printf 'pid=%s\nstarted=%s\nstarted_iso=%s\nroot=%s\nsource=%s\narms=%s\nstate=%s\narm_index=%s\narm_cmd=%s\n' \
        "$$" "$RUN_T0" "$(date -u -d "@$RUN_T0" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" "$ROOT" "$SOURCE" "$N" "$1" "$RUN_ARM_I" "$RUN_ARM_CMD"
      [ "$1" = completed ] && printf 'completed=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    } > "$RUNSTATE" 2>/dev/null || true
}
kill_ledger_lookup() {  # kill_ledger_lookup <pid> <since-epoch> -- prints the sender line or nothing
    [ -r "$KILL_LEDGER" ] || return 1
    awk -F'\t' -v pid="$1" '$6 == pid {last = "seat=" $2 " root=" $3 " sender_pid=" $4 " signal=SIG" $5 " at=" $1 " pattern=" $9} END {if (last != "") print last}' "$KILL_LEDGER"
}
death_report() {  # death_report <signal-name>
    local el sender
    el=$(( $(date +%s) - RUN_T0 ))
    echo
    echo "⛔⛔ BLOCKING SET KILLED BY SIG$1 -- THIS RUN DID NOT COMPLETE, so nothing below it is a verdict."
    printf '   arm reached : %s of %s   %s\n' "$RUN_ARM_I" "$N" "${RUN_ARM_CMD:-<none started>}"
    printf '   elapsed     : %ss   counts so far: green=%s red=%s refused=%s\n' "$el" "${green:-0}" "${red:-0}" "${refused:-0}"
    # ⛔ ALL-ZERO COUNTS ARE AMBIGUOUS AND THE BANNER RESOLVES THEM RATHER THAN LEAVING IT TO THE READER
    # (cfo 2026-09-20, from a real death: "green=0 red=0 refused=0 at arm 20 of 375 after 358 seconds reads
    # like a wedged run rather than a run still walking its serial arms, and I had to check the file to know
    # which I was looking at"). Under fan-out the parent runs the DECLARED-SERIAL arms first and the counters
    # do not move until the shards start, so zero is the CORRECT reading of a healthy run -- and it is also
    # what a genuinely wedged run prints. A reader at the moment their board died should not have to tell
    # those apart by opening a file.
    if [ "$(( ${green:-0} + ${red:-0} + ${refused:-0} ))" -eq 0 ] && [ "${RUN_ARM_I:-0}" -gt 0 ]; then
        if [ -n "${SHARDS:-}" ] && [ "${SHARDS:-1}" -gt 1 ] 2>/dev/null; then
            printf '                 (green=0 red=0 here is NOT a wedged run: this run was still walking its DECLARED-SERIAL\n'
            printf '                  arms in the parent, which run before the %s shard(s) start and before any counter moves.)\n' "$SHARDS"
        else
            printf '                 (green=0 red=0 after %s arm(s) IS worth a look: in sequential mode a counter moves per arm,\n' "$RUN_ARM_I"
            printf '                  so zero counts this far in means the first arm never returned.)\n'
        fi
    fi
    printf '   this run    : pid=%s root=%s source=%s\n' "$$" "$ROOT" "$SOURCE"
    sender="$(kill_ledger_lookup "$$" "$RUN_T0")"
    if [ -n "$sender" ]; then
        printf '   ⭐ SENDER    : %s\n                 (recorded in %s)\n' "$sender" "$KILL_LEDGER"
    else
        printf '   ⛔ SENDER    : NO LEDGER ENTRY for pid %s in %s -- AN UNLOGGED KILLER.\n' "$$" "$KILL_LEDGER"
        printf '                 A kill that leaves no record cannot be named by its victim. Every seat signals through\n'
        printf '                 ../harness/scripts/s4e_kill_mine.sh, which is root-scoped AND records; a bare pkill -f is the reach itself.\n'
    fi
    runstate_write "killed-SIG$1"
}
trap 'death_report TERM; exit 143' TERM
trap 'death_report INT;  exit 130' INT
trap 'death_report HUP;  exit 129' HUP
trap 'death_report QUIT; exit 131' QUIT
# ⛔ THE POSTMORTEM IS READ BEFORE THIS RUN OVERWRITES THE STATE, and it is the only way an untrappable death is
# ever reported: the run that died cannot speak, so the next one speaks for it.
runstate_postmortem() {
    [ -n "$RUNSTATE" ] && [ -r "$RUNSTATE" ] || return 0
    grep -q '^completed=' "$RUNSTATE" 2>/dev/null && return 0
    local pid started iso idx cmd arms el sender
    pid=$(sed -n 's/^pid=//p' "$RUNSTATE"); started=$(sed -n 's/^started=//p' "$RUNSTATE")
    iso=$(sed -n 's/^started_iso=//p' "$RUNSTATE"); idx=$(sed -n 's/^arm_index=//p' "$RUNSTATE")
    cmd=$(sed -n 's/^arm_cmd=//p' "$RUNSTATE"); arms=$(sed -n 's/^arms=//p' "$RUNSTATE")
    el=$(sed -n 's/^state=//p' "$RUNSTATE")
    echo "⛔ POSTMORTEM OF THE PREVIOUS RUN IN THIS ROOT -- it never recorded a completion, so it was ENDED:"
    printf '   pid=%s started %s, reached arm %s of %s, last arm: %s\n' "${pid:-?}" "${iso:-?}" "${idx:-?}" "${arms:-?}" "${cmd:-<none>}"
    printf '   last state it wrote: %s\n' "${el:-unknown}"
    sender="$(kill_ledger_lookup "${pid:-0}" "${started:-0}")"
    if [ -n "$sender" ]; then
        printf '   ⭐ SENDER: %s   (recorded in %s)\n' "$sender" "$KILL_LEDGER"
    else
        printf '   ⛔ SENDER: no ledger entry for pid %s -- an UNLOGGED killer, or a SIGKILL from outside s4e_kill_mine.sh.\n' "${pid:-?}"
        printf '             SIGKILL cannot be trapped, which is why this state file exists at all.\n'
    fi
    echo
}
sig_name_of_rc() {  # sig_name_of_rc <rc> -- prints SIG<NAME> for 128+n, else nothing
    [ "${1:-0}" -gt 128 ] 2>/dev/null || return 1
    local n="$(( $1 - 128 ))" nm
    nm="$(kill -l "$n" 2>/dev/null)"
    [ -n "$nm" ] && printf 'SIG%s' "$nm"
}
# ⛔ ONE ARM, ONE EXECUTION SITE.  The fan-out parent ran its serial arms through a copy of this line and the
# sequential loop through another; a detector wired into one of them and not the other is the half-wired shape
# the org keeps paying for.  ARM_RC / ARM_OUT / ARM_SEC are the outputs.
arm_exec() {  # arm_exec <cmd>
    local t0
    RUN_ARM_I=$((RUN_ARM_I + 1)); RUN_ARM_CMD="$1"; runstate_write running
    race_before
    t0=$SECONDS
    local k0 k1; k0="$(mem_oom_kills)"
    ARM_OUT="$(cd "$ROOT" && bash -c "$1" </dev/null 2>&1)"; ARM_RC=$?
    ARM_SEC=$((SECONDS - t0))
    # ⛔ A CGROUP KILL IN THIS ARM'S WINDOW TURNS A NON-GREEN ARM INTO A REFUSAL, NEVER A RED (row instrument-698-runners-...):
    # the arm's own rc cannot say whether the cap killed its program, the scope's memory.events can. A green arm stays green.
    k1="$(mem_oom_kills)"
    if [ "$ARM_RC" != 0 ] && [ -n "$k0" ] && [ -n "$k1" ] && [ "$k1" -gt "$k0" ]; then
        ARM_OUT="$ARM_OUT
⛔ REFUSE(2) [mem_scope] this arm (rc=$ARM_RC): $(python3 "$HERE/util_mem_scope.py" kill-detail $((k1 - k0)))"
        ARM_RC=2
    fi
    race_after "$1"
}
race_load_surfaces
# ⛔ SHARD SELECTION IS INTERLEAVED AND PARTITIONS THE SET EXACTLY ONCE -- the same k/N convention the suite
# harness uses, so N shards' arm lists concatenate back to the declaration with nothing doubled and nothing
# dropped.  A serial arm is in NO shard: the parent runs it.
SHARD_K=0; SHARD_N=0
if [ -n "$SHARD" ]; then
    case "$SHARD" in
        [1-9]*/[1-9]*) SHARD_K="${SHARD%%/*}"; SHARD_N="${SHARD##*/}" ;;
        *) refuse "--shard takes K/N with 1 <= K <= N (got '$SHARD')" ;;
    esac
    [ "$SHARD_K" -ge 1 ] && [ "$SHARD_K" -le "$SHARD_N" ] || refuse "--shard $SHARD is outside 1..N"
    [ -n "$SHARDS" ] && refuse "--shard and --shards are different jobs: one slice, or a fan-out over all of them"
fi
if [ -n "$SHARDS" ]; then
    case "$SHARDS" in [1-9]|[1-9][0-9]) : ;; *) refuse "--shards takes a count 1..99 (got '$SHARDS')" ;; esac
    # ⛔ THE FAN-OUT CEILING (ceo CEO-1333, 2026-09-27): a seat caps its concurrent children at max(2, min(4, cores - demand)), read from
    # ../harness/scripts/lib_fanout.sh at launch; a requested width above it is CLAMPED and the clamp is printed, never silent.
    . "$HERE/lib_fanout.sh" || refuse "../harness/scripts/lib_fanout.sh is missing -- the fan-out ceiling has no instrument"
    _fw=$(fanout_width); if [ "$SHARDS" -gt "$_fw" ] 2>/dev/null; then echo "fanout: --shards $SHARDS clamped to $_fw at CPU demand $(fanout_demand) ($(fanout_source)) on $(fanout_cores) cores (CEO-1333/1394: max(2, min(4, cores - demand)), never load1)"; SHARDS=$_fw; fi
fi
if [ "$SHARD_N" -gt 0 ]; then
    KEEP_F=(); KEEP_C=(); _slot=0
    for i in $(seq 0 $((N - 1))); do
        if is_serial_arm "${CMDS[$i]}"; then continue; fi
        if [ "$((_slot % SHARD_N))" -eq "$((SHARD_K - 1))" ]; then KEEP_F+=("${FLAGS[$i]}"); KEEP_C+=("${CMDS[$i]}"); fi
        _slot=$((_slot + 1))
    done
    FLAGS=(${KEEP_F[@]+"${KEEP_F[@]}"}); CMDS=(${KEEP_C[@]+"${KEEP_C[@]}"}); N=${#CMDS[@]}
    SOURCE="$SOURCE shard=$SHARD_K/$SHARD_N"
    # ⛔ A SHARD WITH ZERO ARMS IS NOT A GREEN RUN.  It means N exceeds the arm count, and printing the success
    # shape for it is the same false green an empty population always is.
    [ "$N" -gt 0 ] || refuse "shard $SHARD_K/$SHARD_N holds ZERO arms (the set has fewer shardable arms than shards) -- a slice that graded nothing must never print the success shape"
fi

# ⛔ THE RUNSTATE PATH IS DECIDED HERE, WHERE --shard IS FINALLY KNOWN. /tmp and never the checkout: a state file
# under out/ or the root would move a watched path on every arm and make the race detector convict every
# concurrent arm of racing -- one instrument sabotaging its sibling, one directory apart.
# S4E_BLOCKING_RUNSTATE names it elsewhere so the acceptance gate's fixtures are HERMETIC -- a gate that
# postmortemed its own fixtures into this seat's real state file would manufacture a false death report on the
# next real run, which is the class of defect this whole row is about.
[ "$SHARD_N" -gt 0 ] || RUNSTATE="${S4E_BLOCKING_RUNSTATE:-/tmp/si_blockingset$(printf '%s' "$ROOT" | tr '/' '-').runstate}"

# ⛔⭐⭐ BUILD CURRENCY IS CHECKED ONCE, HERE, BEFORE ANY ARM RUNS -- AND THE WHOLE RUN REFUSES.
# (coo 2026-09-21, row instruments-a-blocking-set-run-is-killed-from-outside, from a COMPLETED run rather than
# a reasoned argument.) THE MEASUREMENT THAT PUT THIS HERE: a full set on this box, 6 shards, tree c8ba4567b --
# arms=381 green=110 red=11 REFUSED=260, wall 387s. SIXTY-EIGHT PERCENT OF THE LANDING GATE MEASURED NOTHING,
# and every one of the 260 refused for the SAME reason, discovered 260 times: the binary predated the tree.
# ⛔ AND THE CAUSE IS THE DOCUMENTED LANDING SEQUENCE ITSELF, WHICH IS WHY IT DESERVES A GUARD RATHER THAN A
# REMINDER. Every root's CLAUDE.md says `git pull --rebase` before every push. A REBASE REPLAYS COMMITS, AND
# REPLAYING A COMMIT REWRITES ITS FILES WITH A NEW MTIME -- identical bytes, newer timestamp. So the ordinary
# order (build, test, commit, pull --rebase, push, run the gate) leaves Makefile and src/ newer than a binary
# that is semantically perfectly current. The reflog of the run above shows it exactly: build 10:01:58, rebase
# pick 10:03:28, set started 10:03:52. Nothing was stale. Every arm refused anyway.
# ⛔ WHY THIS IS NOT MERELY WASTEFUL: rc=2 IS NOT RED, so the set runs to completion and prints "6 blocking
# arm(s) failed, 256 refused" -- and a seat at the end of a long sitting reads the 6 and lands. A gate that is
# two-thirds DARK reports in the same shape as a gate that is two-thirds green. That is CEO-582 (DARK is worse
# than RED) arriving inside the landing gate itself.
# ⭐ AND IT IS hq_raku's FINDING FROM THE OTHER DIRECTION, THE SECOND REPORT OF ONE SHAPE IN A DAY: their board
# refused with THE BINARY MOVED UNDER THIS BOARD only at the END, after the run was already paid for, and they
# said it plainly -- nothing told them at the START that they were holding a lock. A guard that fires after the
# cost is a diagnosis, not a guard. 387 seconds of a 16-core box shared by ten seats, to learn what one stat(2)
# answers before the first arm.
if [ "$SHARD_N" -eq 0 ]; then
    # ⛔⭐⭐ IT CALLS gate_require_fresh, THE AUTHORITY THE ARMS THEMSELVES USE, AND THAT IS NOT A STYLE CHOICE --
    # I BUILT THIS GUARD ON THE OTHER ONE FIRST AND IT SILENTLY FAILED TO FIRE. There are TWO build-currency
    # authorities in this tree and they scan DIFFERENT POPULATIONS: lib_build_currency.sh's s4e_bc_newest_src
    # scans ONLY $root/src, while lib_gate.sh's gate_require_fresh scans `git ls-files -- src Makefile` -- src/
    # PLUS THE MAKEFILE. The file they disagree about is the Makefile, which is exactly the file a rebase most
    # often rewrites, so the two authorities differ precisely in the case that caused this row. A guard that
    # disagrees with the arms it is guarding is worse than no guard: it green-lights a run that then refuses
    # 260 times. COLLAPSE TO THE AUTHORITY, DO NOT SYNCHRONISE THE COPIES -- so this calls the arms' own
    # function in a subshell and takes its verdict rather than re-deriving one.
    # ⛔ AND THE DISAGREEMENT ITSELF IS A SEPARATE DEFECT, NOT CURED HERE: two authorities answering one
    # question is a row of its own, and this comment is the evidence for it rather than a fix for it.
    _bc=0
    ( . "$HERE/lib_gate.sh" 2>/dev/null || exit 0
      command -v gate_require_fresh >/dev/null 2>&1 || exit 0
      GATE_NAME="blocking-set-prestart" gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" >/dev/null 2>&1
    ) || _bc=$?
    if [ "$_bc" -eq 2 ]; then
        echo "" >&2
        echo "⛔⛔ BLOCKING SET REFUSES TO START (rc=2) -- THE BINARY PREDATES THE TREE, SO MOST ARMS WOULD" >&2
        echo "    REFUSE ONE AT A TIME AND THE RUN WOULD PRINT A VERDICT SHAPE OVER A MOSTLY DARK SET." >&2
        echo "    Measured on this box 2026-09-21: 260 of 381 arms refused for exactly this, after 387s." >&2
        echo "    ⭐ IF YOU JUST RAN git pull --rebase, NOTHING IS ACTUALLY STALE: the rebase replayed your" >&2
        echo "       commit and rewrote its files with a new mtime. The bytes are fine; the timestamp is not." >&2
        echo "    cure: cd $ROOT && make        (then re-run this set)" >&2
        echo "    the deliberate-stale path is the established one, SCRIP_ALLOW_STALE=1, which is loud by" >&2
        echo "       construction and blocks the leaderboard write; this guard honours it because it is the" >&2
        echo "       arms' own switch and not a second one invented here." >&2
        # the authority's own refusal, printed in full rather than summarised, so the reader sees the timestamps
        ( . "$HERE/lib_gate.sh" 2>/dev/null; GATE_NAME="blocking-set-prestart" gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" ) 2>&1 | sed 's/^/    /' >&2
        exit 2
    fi
    # ⛔⭐ THE BUILD-BEHAVIOUR LEDGER IS RECORDED ONCE, HERE, SERIALLY, BEFORE ANY SHARD EXISTS (the coo 2026-10-14, from two completed sets: 10-13 on
    # 2781bf6e4 refused nine arms as RACED and 10-14 on 0b870cf3e six, a different handful each time, all on out/build_behaviour.sig). THE CAUSE:
    # gate_require_built_from appends a ledger line on a tree's FIRST observation, and a set always runs on a tree the loop has just built, so the first
    # arm of every shard observed it for the first time together and appended together -- the race detector convicted whichever arms overlapped. Naming
    # arms in blocking_set_serial_arms.txt would chase a different handful every run; the writer is the cause. Recorded here, every arm finds the tree
    # observed and only reads. Not on --list (which writes nothing) and not on a serial run (no concurrency to collide with).
    PRIME_LEDGER=1              # ⛔ MUTANT ANCHOR PRIME -- 0 leaves the first observation to the first arms of the shards, which append to out/build_behaviour.sig together
    if [ "$PRIME_LEDGER" = 1 ] && [ -n "$SHARDS" ] && [ "$LIST_ONLY" -eq 0 ]; then
        ( . "$HERE/lib_gate.sh" 2>/dev/null || exit 0
          command -v gate_require_built_from >/dev/null 2>&1 || exit 0
          GATE_NAME="blocking-set-prestart" gate_require_built_from "$ROOT" "$ROOT/scrip" >/dev/null 2>&1
        ) || true
    fi
fi

if [ "$LIST_ONLY" -eq 1 ]; then
    for i in $(seq 0 $((N - 1))); do
        if [ -n "${FLAGS[$i]}" ]; then printf '%3d  REPORTED  %s\n' "$((i + 1))" "${CMDS[$i]}"
        else printf '%3d  BLOCKING  %s\n' "$((i + 1))" "${CMDS[$i]}"; fi
    done
    printf '%s: %d arm(s) declared in %s\n' "$NAME" "$N" "$SOURCE"
    exit 0
fi
# ⭐ THE FAN-OUT.  The parent runs the DECLARED SERIAL ARMS ITSELF, one at a time, then starts N children, each
# `--shard k/N` of this same script over the same declaration, and MERGES their per-arm machine lines.  The merge
# is by ARM NAME, which is what the acceptance compares: same red name set, same refused name set, same total.
if [ -n "$SHARDS" ]; then
    runstate_postmortem
    WORK="$(mktemp -d)" || refuse "no temp dir for the fan-out"
    trap 'rm -rf "$WORK"' EXIT
    LOAD0="$(cut -d" " -f1 /proc/loadavg 2>/dev/null || echo ?)"
    # ⛔ THE WITNESS IS SHARED BY THE PARENT AND EVERY CHILD, and it is what makes a race ANSWERABLE rather than
    # arguable: one append-only record of every arm's window and every path that moved under it, under flock.
    if [ "$RACE_STATE" = on ]; then
        mkdir -p "$WORK/witness" && : > "$WORK/witness/writes.tsv" || refuse "cannot create the race witness under $WORK"
        export S4E_BLOCKING_WITNESS="$WORK/witness"
    fi
    echo "=== blocking set: $N arm(s) from $SOURCE -- FAN-OUT over $SHARDS shard(s); declared serial arms run in the parent first ==="
    printf '%s\n' "${SERIAL_PATS[@]+${SERIAL_PATS[@]}}" | sed '/^$/d; s/^/  serial (never sharded): /'
    t_all=$SECONDS
    : > "$WORK/results.tsv"
    for i in $(seq 0 $((N - 1))); do
        is_serial_arm "${CMDS[$i]}" || continue
        arm_exec "${CMDS[$i]}"
        printf 'ARMRESULT\t%s\t%s\t%s\t%s\n' "$ARM_RC" "$ARM_SEC" "$([ -n "${FLAGS[$i]}" ] && echo R || echo B)" "${CMDS[$i]}" >> "$WORK/results.tsv"
        printf '[serial] rc=%-3s %4ds  %s\n' "$ARM_RC" "$ARM_SEC" "${CMDS[$i]}"
        # ⛔ A RED WITH NO OUTPUT IS A NAME WITHOUT EVIDENCE (ceo CEO-1197): the death gate was red in the serial
        # phase of two full passes and green alone, and nothing said which of its twelve arms failed, because this
        # line threw the arm's output away.  The tail of a non-green serial arm travels with its name.
        [ "$ARM_RC" -eq 0 ] || printf '%s\n' "$ARM_OUT" | tail -8 | sed 's/^/       | /'
    done
    # ⛔ A GRADER INSIDE A SHARD TAKES ITS SHARE OF THE CORES, NOT ITS OWN DEFAULT (ceo 2026-10-15 16:25 health check: load 21 on 16 cores with the
    # set at 4 shards and two pl_iso_rung gates each grading Logtalk at --jobs 8 -- about 16 compile workers from two arms). The eight rung gates read
    # PL_RUNG_JOBS (default 8); under fan-out it defaults to cores / shards, at least 1, unless the caller set it.
    export PL_RUNG_JOBS="${PL_RUNG_JOBS:-$(( $(nproc) / SHARDS > 0 ? $(nproc) / SHARDS : 1 ))}"
    echo "fanout: graders inside a shard take PL_RUNG_JOBS=$PL_RUNG_JOBS worker(s) ($(nproc) cores / $SHARDS shards)"
    for k in $(seq 1 "$SHARDS"); do
        ( echo "shardpid=$BASHPID" > "$WORK/shard.$k.pid"; bash "${BASH_SOURCE[0]}" --shard "$k/$SHARDS" --target "$DECL_TARGET" --makefile "$MAKEFILE" \
              ${ARMS_FILE:+--arms-from "$ARMS_FILE"} --serial-arms "$SERIAL_FILE" --shared-surfaces "$SURFACE_FILE" > "$WORK/shard.$k.out" 2>&1; echo $? > "$WORK/shard.$k.rc" ) &
    done
    wait
    for k in $(seq 1 "$SHARDS"); do
        krc="$(cat "$WORK/shard.$k.rc" 2>/dev/null || echo 2)"
        printf 'shard %d/%s: rc=%s, %s arm(s)\n' "$k" "$SHARDS" "$krc" "$(grep -c '^ARMRESULT	' "$WORK/shard.$k.out" 2>/dev/null || echo 0)"
        # ⛔ A CHILD THAT DIED ON A SIGNAL IS NAMED AS SUCH, NOT LEFT AS A BARE rc. "rc=137" is a number a reader
        # has to decode; "SIGKILL after 14 arms" is the fact, and it is the difference between a shard that
        # FAILED and a shard that WAS ENDED -- the second is never a verdict about the tree.
        _ksig="$(sig_name_of_rc "$krc")"
        if [ -n "$_ksig" ]; then
            printf '   ⛔ shard %d WAS ENDED BY %s after %s arm(s) -- its slice is UNMEASURED, not green and not red.\n' \
                "$k" "$_ksig" "$(grep -c '^ARMRESULT	' "$WORK/shard.$k.out" 2>/dev/null || echo 0)"
            _ksender="$(kill_ledger_lookup "$(sed -n "s/^shardpid=//p" "$WORK/shard.$k.pid" 2>/dev/null)" "$RUN_T0")"
            [ -n "$_ksender" ] && printf '      ⭐ SENDER: %s\n' "$_ksender" \
                || printf '      ⛔ SENDER: no ledger entry -- an unlogged killer (see ../harness/scripts/s4e_kill_mine.sh).\n'
        fi
        grep '^ARMRESULT	' "$WORK/shard.$k.out" >> "$WORK/results.tsv" 2>/dev/null
        if [ "$krc" = 2 ] && ! grep -q '^ARMRESULT	' "$WORK/shard.$k.out" 2>/dev/null; then
            echo "⛔ shard $k/$SHARDS produced NO arm results:"; tail -3 "$WORK/shard.$k.out" | sed 's/^/     /'
        fi
    done
    echo
    # ⛔ THE COLLISIONS ARE COMPUTED BEFORE ANY VERDICT IS PRINTED, because a raced arm's rc is not a verdict and
    # must never be printed as one.  RACED_BY maps an arm to the path(s) it shares with a concurrent arm.
    RACES="$WORK/races.tsv"; : > "$RACES"
    declare -A RACED_BY=()
    if [ "$RACE_STATE" = on ] && [ -s "$WORK/witness/writes.tsv" ]; then
        race_collisions "$WORK/witness/writes.tsv" > "$RACES"
    fi
    n_raced=0
    if [ -s "$RACES" ]; then
        echo "⛔ RACED -- these arms ran CONCURRENTLY and the SAME PATH on the watched surface moved under both."
        echo "   Each is rc=2 COULD-NOT-MEASURE and NEVER a red: a collision reported as a red is an"
        echo "   unattributable finding, and the cure is a line in $(basename "$SERIAL_FILE"), not a tolerance."
        _lastp=""
        while IFS="	" read -r _p _c; do
            [ "$_p" = "$_lastp" ] || { printf '   path %s\n' "$_p"; _lastp="$_p"; }
            printf '     · %s\n' "$_c"
            if [ -z "${RACED_BY[$_c]:-}" ]; then n_raced=$((n_raced + 1)); RACED_BY[$_c]="$_p"
            else RACED_BY[$_c]="${RACED_BY[$_c]}, $_p"; fi
            printf 'ARMRACE\t%s\t%s\n' "$_p" "$_c"
        done < "$RACES"
        echo
    fi
    g=0; r=0; f=0; bred=0; bref=0
    # ⛔ THE FAN-OUT RE-EMITS EVERY MACHINE LINE.  The per-arm ARMRESULT line is this driver's CONTRACT with any
    # consumer -- it is how a verdict is read BY ARM NAME rather than by count -- and a shape of this driver that
    # printed only its merged prose would be unreadable to the very gate that grades shard-vs-sequential identity.
    while IFS="	" read -r _tag rc sec kind cmd; do
        [ "$_tag" = ARMRESULT ] || continue
        # ⛔ A RACED ARM IS rc=2 BEFORE IT IS ANYTHING ELSE -- including before it is green.  An arm that passed
        # while another arm was moving the ground under it did not pass; it was not measured.
        _race="${RACED_BY[$cmd]:-}"
        [ -n "$_race" ] && rc=2
        printf 'ARMRESULT\t%s\t%s\t%s\t%s\n' "$rc" "$sec" "$kind" "$cmd"
        _rep=""; [ "$kind" = R ] && _rep="   (REPORTED)"
        if [ "$rc" = 0 ]; then g=$((g + 1))
        elif [ "$rc" = 2 ]; then f=$((f + 1))
            if [ -n "$_race" ]; then printf '  RACED     %s%s\n              shares %s with a concurrent arm\n' "$cmd" "$_rep" "$_race"
            else printf '  REFUSED   %s%s\n' "$cmd" "$_rep"; fi
            [ "$kind" = B ] && bref=$((bref + 1))
        else r=$((r + 1)); printf '  RED  rc=%-3s %s%s\n' "$rc" "$cmd" "$_rep"; [ "$kind" = B ] && bred=$((bred + 1)); fi
    done < "$WORK/results.tsv"
    # ⛔ THE SHARDS' EVIDENCE IS RE-EMITTED, NOT ONLY THEIR MACHINE LINES (ceo CEO-1197): each child printed the
    # output tail of every arm it reds or refuses; the parent used to keep the child's ARMRESULT lines and delete
    # the rest with $WORK, so a fan-out red arrived as a bare name.  Each line is prefixed so no consumer of the
    # report's own RED/REFUSED lines can read a child's line as a second verdict.
    for k in $(seq 1 "$SHARDS"); do
        sed -n '/^⛔ RED -- examined and FAILED/,/^$/p; /^⛔ REFUSED -- COULD NOT MEASURE/,/^$/p' "$WORK/shard.$k.out" 2>/dev/null \
            | sed '/^$/d' | sed "s/^/  [shard $k] | /"
    done
    tot=$((g + r + f))
    printf 'blocking set: arms=%d  green=%d  red=%d  refused=%d   (%d+%d+%d=%d)  shards=%s  wall=%ds\n' \
        "$N" "$g" "$r" "$f" "$g" "$r" "$f" "$tot" "$SHARDS" "$((SECONDS - t_all))"
    race_stamp_line "fan-out/$SHARDS" "$N" "$((SECONDS - t_all))" "$LOAD0" "$n_raced"
    [ "$tot" -eq "$N" ] || refuse "the fan-out reported $tot arm(s) for a declared $N -- a shard lost or doubled work, and a set that cannot account for its own arms is not a measurement (speed is reported BESIDE name-set identity, never instead of it)"
    runstate_write completed
    if [ "$bred" -gt 0 ]; then echo "⛔ BLOCKING SET RED: $bred blocking arm(s) failed, $bref refused."; exit 1; fi
    if [ "$bref" -gt 0 ]; then echo "⛔ BLOCKING SET UNPROVEN: no blocking arm failed, but $bref could not measure (rc=2).  A refusal is not a pass."; exit 2; fi
    echo "✅ BLOCKING SET GREEN: all $N arm(s) ran across $SHARDS shard(s); every blocking arm passed."
    runstate_write completed
    exit 0
fi

runstate_postmortem
echo "=== blocking set: $N arm(s) from $SOURCE -- EVERY arm runs; reds and refusals are reported separately at the end ==="
LOAD0="$(cut -d" " -f1 /proc/loadavg 2>/dev/null || echo ?)"; T_ALL=$SECONDS
green=0; red=0; refused=0
RED_IDX=(); REF_IDX=(); RC=(); OUT=(); SEC=()
for i in $(seq 0 $((N - 1))); do
    cmd="${CMDS[$i]}"
    arm_exec "$cmd"
    rc=$ARM_RC; out="$ARM_OUT"; dt=$ARM_SEC
    RC+=("$rc"); OUT+=("$out"); SEC+=("$dt")
    # ⛔ THE THREE CLASSES ARE THE THREE EXIT CODES (lib_gate.sh): 0 examined and clean, 2 COULD NOT EXAMINE,
    # anything else examined and bad.  A refusal is never folded into red and never into green.
    if [ "$rc" -eq 0 ]; then green=$((green + 1)); cls=GREEN
    elif [ "$rc" -eq 2 ]; then refused=$((refused + 1)); cls=REFUSED; REF_IDX+=("$i")
    else red=$((red + 1)); cls=RED; RED_IDX+=("$i"); fi
    printf '[%3d/%3d] %-8s rc=%-3s %4ds  %s%s\n' "$((i + 1))" "$N" "$cls" "$rc" "$dt" "$cmd" "${FLAGS[$i]:+   (REPORTED)}"
    # ⛔ the machine line a fan-out parent merges by ARM NAME -- the identity the acceptance compares.  The
    # blocking/reported column is a WORD (B or R) and never empty: IFS=tab COLLAPSES a run of tabs, so an empty
    # field shifts every field after it one to the left, and the first version of this line read a blocking RED
    # as a REPORTED one and exited 0 over it.  A separator that eats an empty field is not a separator.
    printf 'ARMRESULT\t%s\t%s\t%s\t%s\n' "$rc" "$dt" "$([ -n "${FLAGS[$i]}" ] && echo R || echo B)" "$cmd"
done
echo
if [ "${#RED_IDX[@]}" -gt 0 ]; then
    echo "⛔ RED -- examined and FAILED (${#RED_IDX[@]}):"
    for i in "${RED_IDX[@]}"; do
        printf '  RED  rc=%-3s %s%s\n' "${RC[$i]}" "${CMDS[$i]}" "${FLAGS[$i]:+   (REPORTED -- does not fail this run)}"
        printf '%s\n' "${OUT[$i]}" | tail -5 | sed 's/^/       /'
    done
    echo
fi
if [ "${#REF_IDX[@]}" -gt 0 ]; then
    echo "⛔ REFUSED -- COULD NOT MEASURE, rc=2 (${#REF_IDX[@]}).  NOT red and NOT green: an arm in this class graded nothing:"
    for i in "${REF_IDX[@]}"; do
        printf '  REFUSED   %s%s\n' "${CMDS[$i]}" "${FLAGS[$i]:+   (REPORTED -- does not fail this run)}"
        printf '%s\n' "${OUT[$i]}" | tail -5 | sed 's/^/       /'
    done
    echo
fi
# ⛔ THE DENOMINATOR IS PRINTED AND CHECKED.  This line is the whole point of the target: a run that died
# partway used to be indistinguishable from a clean one, and now the arithmetic has to close.
printf 'blocking set: arms=%d  green=%d  red=%d  refused=%d   (%d+%d+%d=%d)\n' \
    "$N" "$green" "$red" "$refused" "$green" "$red" "$refused" "$((green + red + refused))"
race_stamp_line "sequential" "$N" "$((SECONDS - T_ALL))" "$LOAD0" 0
runstate_write completed
[ "$((green + red + refused))" -eq "$N" ] || refuse "the classes do not sum to the arm count -- this driver cannot report its own run"
if [ -f "$HERE/lib_gate.sh" ]; then . "$HERE/lib_gate.sh" 2>/dev/null && gate_stamp 2>/dev/null; fi
# ⛔ REPORTED ARMS CANNOT CHANGE THE VERDICT, which is exactly what a leading `-` meant to make.  Everything
# else does: a blocking red exits 1, a blocking refusal with no red exits 2.
bred=0; bref=0
for i in "${RED_IDX[@]:-}"; do [ -n "${i:-}" ] && [ -z "${FLAGS[$i]}" ] && bred=$((bred + 1)); done
for i in "${REF_IDX[@]:-}"; do [ -n "${i:-}" ] && [ -z "${FLAGS[$i]}" ] && bref=$((bref + 1)); done
if [ "$bred" -gt 0 ]; then
    echo "⛔ BLOCKING SET RED: $bred blocking arm(s) failed, $bref refused, $((red - bred + refused - bref)) non-green arm(s) were REPORTED-only."
    exit 1
fi
if [ "$bref" -gt 0 ]; then
    echo "⛔ BLOCKING SET UNPROVEN: no blocking arm failed, but $bref could not measure (rc=2).  A refusal is not a pass."
    exit 2
fi
echo "✅ BLOCKING SET GREEN: all $N arm(s) ran; every blocking arm passed."
exit 0
