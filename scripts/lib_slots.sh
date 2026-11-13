#!/usr/bin/env bash
# lib_slots.sh -- THE ONE RULE OF THE BOX'S TWO POOLS, WITH A SEAT'S SHARE AND THE GRADER'S RESERVATION (the cto, ARCH-SHARED-DEVELOPMENT.md
# section 4.3 and 4.6, R-2041 step 3; Lon 2026-10-31: "Everyone is compiling at the same time" / "Maximize sharing and minimize contention").
# Sourced by util_cc_slot.sh and util_run_slot.sh (the takers that exec a command) and by the design-step harnesses (which hold a run slot in
# their own shell); corpus_suite_harness.py reads the SAME knobs from this file (the S4E_*_DEFAULT lines below, by name) and follows the same
# rule, which test_gate_pools_cap_a_seat_and_reserve_the_grader.sh checks on both.
#
# THE RULE. Two pools of flock files: compile slots /tmp/s4e-cc-slots/slot0..7 and run slots /tmp/s4e-run-slots/slot0..7 (S4E_CC_SLOTS,
# S4E_RUN_SLOTS override the size; S4E_CC_SLOT_DIR, S4E_RUN_SLOT_DIR the place, the gates' seam). A taker FIRST takes one of its SEAT's files
# (<pool dir>/seat/<seat>/0..cap-1, cap S4E_CC_SEAT_CAP 4 or S4E_RUN_SEAT_CAP 3) and ONLY THEN a pool slot, both held on their own fd for the
# process's life (the kernel frees a killed holder's locks), so a seat at its cap waits on its own files and never on the pool: another seat's
# single compile is never behind one seat's eight. A full pool or a full seat is waited on by RESCANNING every file twice a second, never by
# queuing on one (R-2054). THE GRADER (S4E_CLASS=grader: the coo's loop8 and tier1 and everything they start) takes no seat file and may take
# any run slot; every other taker may take only run slots 0..N-1-S4E_RUN_GRADER_RESERVED, so two run slots always answer the grader at once.
# A run already under a harness slot (S4E_RUN_SLOT_HELD) takes nothing (no nested wait, no deadlock); a compile slot is held by a compiler, a
# leaf that starts nothing. The census reads the holders from /proc/*/fd (a held file is open for the holder's life: kernel truth, no sidecar). The seat is S4E_SEAT (every root's settings env sets it),
# else the first path component under /home of the working directory. A wait of a second or more is one line in SLOT_WAITS.tsv (R-2078).
S4E_CC_POOL_DEFAULT=6
S4E_RUN_POOL_DEFAULT=18
S4E_CC_SEAT_CAP_DEFAULT=3
S4E_RUN_SEAT_CAP_DEFAULT=4
S4E_RUN_GRADER_RESERVED_DEFAULT=10
# ---- THE ONE CORE BUDGET (row one-core-budget-every-compile-and-run-takes-a-token-from-one-count; the cio 2026-11-13; Lon: "how are we going to fix the fleet infra-structure?" /
# "does it not require a hard wired solution, not a soft brained solution?"; the coo's proposal he read: one budget counted in cores, taken at the door, grading's share first,
# the rest waiting without running). MEASURED before it (/home/resources/fleet-ops-research, files 01 and 08): 16 cores, 36 admissions at once by class (compile 6, run 18, land 12),
# each pool counting alone; load 43 to 87; the test runs fully stalled 47 per cent of the time. THE RULE WITH THE FILE: /home/resources/postoffice/CORES.conf (S4E_CORES_CONF names
# another, the probe's seam), key=value a line, read at every take so a number is changed on the live fleet by editing one line: cores=N the tokens in all, grader=G the top G tokens
# that only S4E_CLASS=grader may take and takes first, seat=K a seat's tokens in all, wait=S the seconds a taker waits before it refuses rc 2 (default 1800). A COMPILE AND A RUN TAKE
# FROM THE SAME COUNT: the token files are the run pool's own (<run slot dir>/slot0..N-1, the seat files <run slot dir>/seat/<seat>/0..K-1), so a taker still on the library of
# before contends on the same files for its runs. NO NESTED TAKE: a taker started under a held token (S4E_CORE_HELD, or S4E_RUN_SLOT_HELD as before) takes none and runs on its
# parent's; with one pool a holder that waited for a second token is the pool-locking deadlock, and this makes a worker hold one token at most. WITH NO FILE, or no cores line,
# the two pools above are the rule, unchanged. corpus_suite_harness.py follows the same rule by reading the same file (_cores_conf).
S4E_CORES_CONF_DEFAULT=/home/resources/postoffice/CORES.conf
s4e_cores_conf() {   # <key> -- the key's whole number in CORES.conf; nothing when the file, the key or a number is absent
    awk -F= -v k="$1" '!/^#/ && $1 == k { v = $2 } END { if (v ~ /^[0-9]+$/) print v }' "${S4E_CORES_CONF:-$S4E_CORES_CONF_DEFAULT}" 2>/dev/null
}
s4e_slot_seat() { if [ -n "${S4E_SEAT:-}" ]; then printf '%s' "$S4E_SEAT"; else pwd -P | sed -n 's|^/home/\([^/]*\).*|\1|p' | grep . || printf 'seat'; fi; }
s4e_slot_note() {   # <kind> <t0> <cmd>... -- one line per wait of a second or more
    local f w k="$1" t0="$2"; shift 2
    f="${S4E_SLOT_WAITS:-/home/resources/progress/SLOT_WAITS.tsv}"; w=$(awk -v a="$t0" -v b="$(date +%s.%N)" 'BEGIN{printf "%.1f", b-a}')
    case "$w" in 0.*) return 0;; esac
    [ -s "$f" ] || printf '# at_utc\tseat\tkind\twait_s\tcmd  -- one line per slot wait of a second or more (R-2078: the pools kept no record, so contention could not be measured)\n' > "$f" 2>/dev/null
    printf '%s\t%s\t%s\t%s\t%s\n' "$(date -u +%FT%TZ)" "$(s4e_slot_seat)" "$k" "$w" "$(printf %s "$*" | tr '\t\n' '  ' | cut -c1-80)" >> "$f" 2>/dev/null
    return 0
}
# s4e_slot_hold <kind> -- take a seat file then a pool slot for THIS shell, on fds 7 (seat) and 8 (run pool) or 9 (compile pool); rc 0 held,
# rc 1 the pool directory cannot be made (the caller runs unbounded, as before). Exports S4E_RUN_SLOT_HELD=1 for a run slot.
s4e_slot_hold() {
    local kind="$1" dir n cap lo hi seat sfd pfd i t0 grader=0
    case "$kind" in
        cc)  dir="${S4E_CC_SLOT_DIR:-/tmp/s4e-cc-slots}"; n="${S4E_CC_SLOTS:-$S4E_CC_POOL_DEFAULT}"; cap="${S4E_CC_SEAT_CAP:-$S4E_CC_SEAT_CAP_DEFAULT}"; pfd=9; hi=$((n - 1)) ;;
        run) dir="${S4E_RUN_SLOT_DIR:-/tmp/s4e-run-slots}"; n="${S4E_RUN_SLOTS:-$S4E_RUN_POOL_DEFAULT}"; cap="${S4E_RUN_SEAT_CAP:-$S4E_RUN_SEAT_CAP_DEFAULT}"; pfd=8
             if [ "${S4E_CLASS:-}" = grader ]; then grader=1; hi=$((n - 1)); else hi=$((n - 1 - ${S4E_RUN_GRADER_RESERVED:-$S4E_RUN_GRADER_RESERVED_DEFAULT})); [ "$hi" -ge 0 ] || hi=0; fi ;;
        *) return 2 ;;
    esac
    local one=0 res="${S4E_RUN_GRADER_RESERVED:-$S4E_RUN_GRADER_RESERVED_DEFAULT}" cores; cores="$(s4e_cores_conf cores)"
    if [ -n "$cores" ] && [ "$cores" -ge 1 ]; then   # THE ONE CORE BUDGET: the file is there, so this take is one token of the one count, compile or run
        [ -n "${S4E_CORE_HELD:-}${S4E_RUN_SLOT_HELD:-}" ] && return 1   # NO NESTED TAKE: the caller runs its command on its parent's token (rc 1, not the refusal's 2)
        one=1; dir="${S4E_RUN_SLOT_DIR:-/tmp/s4e-run-slots}"; n="$cores"; cap="$(s4e_cores_conf seat)"; cap="${cap:-$n}"; [ "$cap" -ge 1 ] || cap=1
        res="$(s4e_cores_conf grader)"; res="${res:-0}"; [ "$res" -lt "$n" ] || res=$((n - 1))
        if [ "${S4E_CLASS:-}" = grader ]; then grader=1; hi=$((n - 1)); else grader=0; hi=$((n - 1 - res)); fi
    fi
    sfd=7; seat="$(s4e_slot_seat)"
    mkdir -p "$dir/seat/$seat" 2>/dev/null || return 1
    t0=$(date +%s.%N); local bound; bound="${S4E_SLOT_WAIT_MAX:-}"
    if [ -z "$bound" ] && [ "$one" = 1 ]; then bound="$(s4e_cores_conf wait)"; bound="${bound:-1800}"; fi   # with one count the rest wait: the bound is the file's, long, the same for a compile and a run
    if [ -z "$bound" ]; then if [ "$grader" = 1 ]; then bound=900; else case "$(date +%H)" in 0[6-9]|1[0-9]|2[01]) bound=600;; *) bound=900;; esac; fi; fi
    s4e_slot_bound() { awk -v a="$t0" -v b="$(date +%s.%N)" -v m="$bound" 'BEGIN {exit !(b - a >= m)}' || return 0
        s4e_slot_note "$kind-refused" "$t0" "bound=${bound}s"
        printf 'REFUSE(2) [util_%s_slot]: no %s slot within %s s for %s (pool %s of %s slots, seat cap %s): the box is over-admitted, the wait is recorded in SLOT_WAITS.tsv, nothing ran (box-budget step 5).\n' "$kind" "$kind" "$bound" "$seat" "$n" "$dir" "$cap" >&2
        return 2; }
    if [ "$grader" = 0 ]; then
        while :; do
            i=0
            while [ "$i" -lt "$cap" ]; do
                eval "exec $sfd>>\"$dir/seat/$seat/$i\"" || return 1
                if flock -n "$sfd"; then break 2; fi
                eval "exec $sfd>&-"
                i=$((i + 1))
            done
            s4e_slot_bound || return 2
            sleep 0.5
        done
    fi
    # THE GRADER TAKES ITS RESERVED SLOTS FIRST (the coo's measurement of 2026-11-11 01:25, CIO-120: it sat in two of the seats' four slots while three of
    # its own four stood empty, because every taker tried slot 0 first): the reserved range, the top of the pool, then the shared slots.
    local order res_lo
    if [ "$grader" = 1 ]; then res_lo=$((n - res)); [ "$res_lo" -ge 0 ] || res_lo=0; order="$(seq "$res_lo" "$hi") $([ "$res_lo" -gt 0 ] && seq 0 $((res_lo - 1)))"
    else order="$(seq 0 "$hi")"; fi
    while :; do
        for i in $order; do
            eval "exec $pfd>>\"$dir/slot$i\"" || return 1
            if flock -n "$pfd"; then break 2; fi
            eval "exec $pfd>&-"
        done
        s4e_slot_bound || { [ "$grader" = 0 ] && eval "exec $sfd>&-"; return 2; }
        sleep 0.5
    done
    [ "$kind" = run ] && export S4E_RUN_SLOT_HELD=1
    [ "$one" = 1 ] && export S4E_CORE_HELD=1
    S4E_SLOT_T0="$t0"
    return 0
}

s4e_cores_probe() {   # util_run_slot.sh --probe-cores: SIX ARMS ON A SCRATCH POOL AND A SCRATCH FILE (cores=3 grader=1 seat=2), each an order of events, never a clock: (1) a compile and a run, two seats, hold the two shared tokens; (2) a third compile and a third run are kept out and refuse rc 2 at their bound having run nothing; (3) the grader takes the reserved token while the shared ones are held; (4) a compile started under a held token runs at once; (5) the harness's own taker holds a shared token for a seat and the reserved one for the grader, by the same file; (6) with no file a compile takes a slot of the compile pool of before and no token file is made.
    local here T a b rc why="" i n
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; T="$(mktemp -d "/tmp/s4e/$(s4e_slot_seat)/cores-probe.XXXXXX" 2>/dev/null || mktemp -d)"
    printf 'cores=3\ngrader=1\nseat=2\n' > "$T/CORES.conf"
    local -a E=(env -u S4E_CORE_HELD -u S4E_RUN_SLOT_HELD -u S4E_ADMITTED -u S4E_CLASS S4E_CORES_CONF="$T/CORES.conf" S4E_RUN_SLOT_DIR="$T/run" S4E_CC_SLOT_DIR="$T/cc" S4E_SLOT_WAITS=/dev/null)
    "${E[@]}" S4E_SEAT=probe_a bash "$here/util_cc_slot.sh" sleep 300 > /dev/null 2>&1 & a=$!
    "${E[@]}" S4E_SEAT=probe_b bash "$here/util_run_slot.sh" sleep 300 > /dev/null 2>&1 & b=$!
    held() { n=0; for i in 0 1 2; do [ -e "$T/run/slot$i" ] && ! flock -n "$T/run/slot$i" true 2>/dev/null && n=$((n + 1)); done; printf '%s' "$n"; }
    i=0; while [ "$(held)" != 2 ] && [ "$i" -lt 200 ]; do sleep 0.1; i=$((i + 1)); done
    [ "$(held)" = 2 ] || why="$why arm 1: a compile and a run did not hold two tokens of the one pool (held $(held));"
    [ -e "$T/cc/slot0" ] && why="$why arm 1: the compile took a slot of the old compile pool;"
    "${E[@]}" S4E_SEAT=probe_c S4E_SLOT_WAIT_MAX=1 bash "$here/util_cc_slot.sh" sh -c ": > '$T/third_cc'" > /dev/null 2>&1; rc=$?
    [ "$rc" = 2 ] && [ ! -e "$T/third_cc" ] || why="$why arm 2: a third compile was not kept out (rc $rc);"
    "${E[@]}" S4E_SEAT=probe_c S4E_SLOT_WAIT_MAX=1 bash "$here/util_run_slot.sh" sh -c ": > '$T/third_run'" > /dev/null 2>&1; rc=$?
    [ "$rc" = 2 ] && [ ! -e "$T/third_run" ] || why="$why arm 2: a third run was not kept out (rc $rc);"
    "${E[@]}" S4E_SEAT=probe_g S4E_CLASS=grader S4E_SLOT_WAIT_MAX=20 bash "$here/util_run_slot.sh" sh -c ": > '$T/grader'" > /dev/null 2>&1; rc=$?
    [ "$rc" = 0 ] && [ -e "$T/grader" ] || why="$why arm 3: the grader did not take its reserved token (rc $rc);"
    "${E[@]}" S4E_SEAT=probe_c S4E_CORE_HELD=1 S4E_SLOT_WAIT_MAX=1 bash "$here/util_cc_slot.sh" sh -c ": > '$T/nested'" > /dev/null 2>&1; rc=$?
    [ "$rc" = 0 ] && [ -e "$T/nested" ] || why="$why arm 4: a compile under a held token did not run at once (rc $rc);"
    kill "$a" "$b" 2>/dev/null; wait "$a" "$b" 2>/dev/null
    i=0; while [ "$(held)" != 0 ] && [ "$i" -lt 200 ]; do sleep 0.1; i=$((i + 1)); done
    "${E[@]}" S4E_SEAT=probe_h python3 -c "
import sys, os
sys.path.insert(0, '$here')
import corpus_suite_harness as h
s = h._run_slot(); print('seat', os.path.basename(s.pool_f.name), os.path.relpath(s.seat_f.name, '$T/run')); s.close()
os.environ['S4E_CLASS'] = 'grader'
g = h._run_slot(); print('grader', os.path.basename(g.pool_f.name), g.seat_f is None); g.close()
" > "$T/py.out" 2>&1
    grep -qx 'seat slot[01] seat/probe_h/[01]' "$T/py.out" && grep -qx 'grader slot2 True' "$T/py.out" || why="$why arm 5: the harness's taker did not follow the file ($(tr '\n' ';' < "$T/py.out" | cut -c1-160));"
    env -u S4E_CORE_HELD -u S4E_RUN_SLOT_HELD -u S4E_CLASS S4E_CORES_CONF="$T/absent" S4E_RUN_SLOT_DIR="$T/run2" S4E_CC_SLOT_DIR="$T/cc2" S4E_SLOT_WAITS=/dev/null S4E_SEAT=probe_a bash "$here/util_cc_slot.sh" true > /dev/null 2>&1; rc=$?
    [ "$rc" = 0 ] && [ -e "$T/cc2/slot0" ] && [ ! -e "$T/run2/slot0" ] || why="$why arm 6: with no file a compile did not take the compile pool of before (rc $rc);"
    if [ -z "$why" ]; then rm -rf "$T"; echo "CORES probe ok arms=6 (one count for compiles and runs: two shared tokens held by a compile and a run kept a third of each kind out, refused rc 2 with nothing run; the grader took its reserved token; a compile under a held token ran at once; the harness's taker followed the same file; with no file the compile pool of before)"; return 0; fi
    echo "CORES probe RED:$why"; echo "    kept: $T"; return 1
}

# ---- ADMISSION BY GNU sem (DESIGN-PLAN fleet-queue step 18; the cio 2026-11-05; the coo and the cio ruled 17:4x: sem only where a take is rare and long, never on the per-entry or per-compile path above) ----
# util_run_slot.sh --admit <compile|run> <command>: the taker holds at most TWO sems, outer to inner, in one holder process (util_slot_holder.sh): its SEAT's share (SLOTS.tsv compile-seat, run-seat), then the class's pool
# (compile; run-seats, or run-grader for S4E_CLASS=grader: the grader's two slots are a pool of their own, so the reservation is not a third sem). Caps and timeouts are SLOTS.tsv's, the pool lives in
# PARALLEL_HOME=S4E_SEM_HOME (default /tmp/s4e-sem; the probe's seam). sem re-parses argv through a shell, so a user's command never goes through it: sem runs only the fixed holder and the taker keeps the holder's stdin
# FIFO (opened read-write, so no open ever blocks) on fd 6, inherited by the command it execs: the admission lives as long as the command and its children, and a killed holder frees it. A negative
# --semaphoretimeout refuses (rc 1 from sem); a positive one steals the slot. COST, MEASURED 2026-11-05 (perf stat -e instructions:u): sem --fg true 327 M user instructions a take (a perl script), against 12-19 M for
# the flock take; two nested sems about 650 M: acceptable for a batch job, a build, a suite run or a landing, which is why the per-entry slot stays flock.
S4E_SLOTS_TABLE_DEFAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/SLOTS.tsv"
S4E_SLOT_HOLDER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_slot_holder.sh"
s4e_slot_row() {   # <class> <column> -- one cell of SLOTS.tsv (2 id, 3 cap, 4 timeout_s, 5 timeout_night_s)
    awk -F'\t' -v c="$1" -v n="$2" '$1 == c { print $n; exit }' "${S4E_SLOTS_TABLE:-$S4E_SLOTS_TABLE_DEFAULT}"
}
s4e_sem_chain() {   # <compile|run> <seat> <grader 0|1> -- "id:cap id:cap", outer to inner; the env overrides keep their meaning (S4E_CC_SLOTS, S4E_CC_SEAT_CAP, S4E_RUN_SLOTS, S4E_RUN_SEAT_CAP, S4E_RUN_GRADER_RESERVED)
    local class="$1" seat="$2" grader="$3" n cap res
    seat="$(printf '%s' "$seat" | tr -c 'A-Za-z0-9_' _)"
    case "$class" in
        compile) n="${S4E_CC_SLOTS:-$(s4e_slot_row compile 3)}"; cap="${S4E_CC_SEAT_CAP:-$(s4e_slot_row compile-seat 3)}"
                 printf '%s%s:%s %s:%s' "$(s4e_slot_row compile-seat 2)" "$seat" "$cap" "$(s4e_slot_row compile 2)" "$n" ;;
        run)     n="${S4E_RUN_SLOTS:-$(s4e_slot_row run 3)}"; cap="${S4E_RUN_SEAT_CAP:-$(s4e_slot_row run-seat 3)}"; res="${S4E_RUN_GRADER_RESERVED:-$(s4e_slot_row run-grader 3)}"
                 if [ "$grader" = 1 ]; then printf '%s:%s' "$(s4e_slot_row run-grader 2)" "$res"
                 else [ $((n - res)) -ge 1 ] && res=$((n - res)) || res=1
                      printf '%s%s:%s %s:%s' "$(s4e_slot_row run-seat 2)" "$seat" "$cap" "$(s4e_slot_row run-seats 2)" "$res"; fi ;;
        land)    n="${S4E_LAND_SLOTS:-$(s4e_slot_row land 3)}"; printf '%s:%s' "$(s4e_slot_row land 2)" "$n" ;;   # fleet-control step 3: one pool, no seat share, two landings on the box
        *) return 2 ;;
    esac
}
s4e_sem_bound() {   # <compile|run> <grader> -- S4E_SLOT_WAIT_MAX, else the table's night bound for the grader and by night, its day bound 06:00-21:59
    if [ -n "${S4E_SLOT_WAIT_MAX:-}" ]; then printf '%s' "$S4E_SLOT_WAIT_MAX"; return; fi
    if [ "$2" = 1 ]; then s4e_slot_row "$1" 5; return; fi
    case "$(date +%H)" in 0[6-9]|1[0-9]|2[01]) s4e_slot_row "$1" 4;; *) s4e_slot_row "$1" 5;; esac
}
# s4e_sem_admit <compile|run> -- take the chain for THIS shell on fd 6; rc 0 admitted, rc 1 sem cannot be used (no pool directory, or it failed three times other than by a timeout: a line says so and the caller
# goes on unadmitted, as before), rc 2 REFUSED (no sem on PATH, or no admission within the bound: nothing ran). Exports S4E_ADMITTED=<class>.
s4e_sem_admit() {
    local class="$1" grader=0 seat chain bound t0 home sem cp d line rc item attempt
    local -a argv=()
    [ "$class" = run ] && [ "${S4E_CLASS:-}" = grader ] && grader=1
    sem="${S4E_SEM:-sem}"
    command -v "$sem" > /dev/null 2>&1 || { printf 'REFUSE(2) [util_run_slot --admit]: no GNU sem on PATH (apt: parallel); nothing ran\n' >&2; return 2; }
    home="${S4E_SEM_HOME:-/tmp/s4e-sem}"; mkdir -p "$home" 2> /dev/null || return 1
    seat="$(s4e_slot_seat)"; chain="$(s4e_sem_chain "$class" "$seat" "$grader")" || return 2; bound="$(s4e_sem_bound "$class" "$grader")"
    case "$bound" in ''|*[!0-9]*) bound=900;; esac
    for item in $chain; do argv+=("$sem" --will-cite -u --id "${item%:*}" -j "${item##*:}" --semaphoretimeout "-$bound" --fg); done
    argv+=(bash "$S4E_SLOT_HOLDER")
    for attempt in 1 2 3; do   # a sem started while another taker's pid file is being cleaned has exited 0 WITHOUT running its command (seen once, 2026-11-05): try again, only a timeout refuses
        d="$(mktemp -d "$home/f.XXXXXX" 2> /dev/null)" || return 1
        mkfifo "$d/in" "$d/out" 2> /dev/null || { rm -rf "$d"; return 1; }
        t0=$(date +%s.%N)
        eval "exec 5<>\"$d/out\" 6<>\"$d/in\""
        ( eval "exec 5<&- 6>&-"; export PARALLEL_HOME="$home"; exec "${argv[@]}" < "$d/in" > "$d/out" ) &
        cp=$!; line=""
        while ! read -r -t 1 -u 5 line; do
            kill -0 "$cp" 2> /dev/null || break
            awk -v a="$t0" -v b="$(date +%s.%N)" -v m="$((bound + 60))" 'BEGIN{exit !(b - a >= m)}' && { kill "$cp" 2> /dev/null; break; }
        done
        if [ "$line" = HELD ]; then
            eval "exec 5<&-"; rm -rf "$d"; export S4E_ADMITTED="$class"; S4E_SLOT_T0="$t0"; return 0
        fi
        eval "exec 5<&- 6>&-"; rm -rf "$d"; wait "$cp" 2> /dev/null; rc=$?
        if [ "$rc" = 1 ] || [ "$rc" = 143 ] || [ "$rc" = 137 ]; then
            s4e_slot_note "$class-admit-refused" "$t0" "bound=${bound}s"
            printf 'REFUSE(2) [util_run_slot --admit %s]: no admission within %s s for %s (chain %s, sem home %s): the box is over-admitted, the wait is recorded in SLOT_WAITS.tsv, nothing ran.\n' "$class" "$bound" "$seat" "$chain" "$home" >&2
            return 2
        fi
        sleep 1
    done
    printf 'WARN [util_run_slot --admit %s]: sem exited %s three times without an admission; running UNADMITTED (chain %s)\n' "$class" "$rc" "$chain" >&2
    return 1
}
