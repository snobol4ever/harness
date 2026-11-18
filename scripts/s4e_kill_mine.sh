#!/usr/bin/env bash
# s4e_kill_mine.sh -- scoped kill: signals ONLY pids under the caller's own root,
#                     and ANSWERS THE SAME QUESTION WITHOUT KILLING ANYTHING.
#
# Why this exists: every seat runs as the SAME unix user on ONE box, so a bare
# `pkill -f <pattern>` (or `pgrep -f`) matches and kills every OTHER seat's
# processes too -- hq_P's 18:28 box-wide kill took 19 other seats' harness
# workers; seat07 typed the same shape minutes after reading that relay and
# was saved only because the pattern matched its own shell first. `-f` is
# also a self-match trap: the pattern argument is itself part of THIS
# script's own command line, so a naive `pgrep -f "$pattern"` run from inside
# this script matches this script (and its whole ancestor chain, since a
# parent's cmdline can carry the same text -- e.g. a wrapper script that
# embeds the pattern literally). See RULES.md pgrep -x history.
#
# Scope, in order:
#   1. Walk this process's OWN ancestor chain ($$  up through every PPid) and
#      exclude it completely -- the caller's shell/pid tree is never a target,
#      no matter what it matches.
#   2. Of what remains, keep only pids whose /proc/<pid>/cwd resolves under
#      the caller's own root ($S4E_HOME, or derived from $0 per the D-17
#      sibling-root convention -- same derivation s4e_msg.sh uses).
#   3. Of what remains, keep pids matching the given pattern by exact
#      executable name (comm) OR as a substring of their argv/cmdline.
# There is no flag that skips step 2 -- there is no box-wide form.
#
# ⛔⭐⭐ --explain-only EXISTS BECAUSE A REFUSAL YOU CAN ONLY REACH BY KILLING IS NOT
# A REACHABLE REFUSAL (R-560; row a-seats-kill-must-name-its-own-root-and-the-
# refusal-is-reachable-without-killing-anything, R-976, coo 2026-09-20).
# The incident that rowed it: at about 01:4x CDT 2026-09-20 a seat signalled ELEVEN
# pids over a pattern list including `corpus_suite_harness` and `test-arena` --
# patterns EVERY seat shares -- and SIX were pids it had not verified were its own.
# A background waiter belonging to a THIRD seat died with exit 144 in the same
# window. The scoping below would have prevented all of it and was not used, and
# the reason it was not used is the whole lesson: UNTIL NOW THE ONLY WAY TO LEARN
# WHAT THIS SCRIPT WOULD DO WAS TO LET IT DO IT. An instrument whose safe behaviour
# can only be observed by taking the unsafe action gets replaced, under pressure,
# by the unsafe action -- so the dry run is not a convenience, it is the feature
# that makes the scoping adoptable. `--explain-only` signals NOTHING, ever, and
# names every pid it WOULD DECLINE together with the reason class it was declined
# under, so the decision is auditable before it is irreversible.
#
# ⛔⭐ AND THE ROOT IS NAMED, NEVER MERELY INHERITED. Arm one of that row: a kill
# from a seat NAMES ITS OWN ROOT OR REFUSES. `--root <dir>` states it explicitly and
# is CHECKED against the root this script derives independently -- a named root that
# is not the caller's own is REFUSED rather than honoured, which is what makes
# `--root /` (the box-wide form this script's header promises does not exist) a
# refusal rather than a wildcard. When no --root is given the derived root is still
# PRINTED on every path, including the kill path: a signal whose scope was never
# stated in its own output cannot be audited afterwards, and the eleven-pid incident
# is exactly the case where afterwards is the only time anyone looks.
set -u

S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 sibling root

usage() {
  echo "usage: $0 [--root <dir>] [--explain-only] [--] <exact-process-name-or-argv-token>" >&2
  echo "       --explain-only   answer the question and SIGNAL NOTHING; names every pid it would decline and why" >&2
  echo "       --root <dir>     name the root this kill is scoped to; a root that is not the caller's own REFUSES" >&2
}

KILL_LEDGER="${S4E_KILL_LEDGER:-${S4E_POST:-/home/resources/postoffice}/kills.tsv}"
kill_ledger_append() {  # kill_ledger_append <pid> <signal> <target-cwd> <target-cmd>
  local when me sender_root line
  when="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  me="${S4E_SEAT:-$(basename "$S4E" 2>/dev/null | sed 's/^claude_//')}"
  sender_root="$S4E"
  # TAB-separated, and every field is a WORD so a reader splitting on tabs cannot shift a column.
  line="$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s' \
      "$when" "${me:-unknown}" "$sender_root" "$$" "$2" "$1" "${4:-unknown}" "${3:-unknown}" "${pattern:-<none>}")"
  if ! ( flock 9 2>/dev/null; printf '%s\n' "$line" >> "$KILL_LEDGER" ) 9>>"${KILL_LEDGER}.lock" 2>/dev/null; then
    echo "  ⚠ COULD NOT RECORD this kill in $KILL_LEDGER -- the signal was still sent, and its victim will read 'no ledger entry'" >&2
  fi
}
me_seat="${S4E_SEAT:-$(printf '%s' "$S4E" | sed -n 's|^/home/claude_\(.*\)$|\1|p')}"; bgdir="${S4E_KEEP:-/home/resources/keep}/${me_seat:-seat}/bg"; oldbg="/tmp/s4e/${me_seat:-seat}/bg"   # the handles live on /home (util_run_slot.sh --bg, Lon 2026-11-14); oldbg is where a run started before that wrote its handle
# THE SEAT'S NAME BEFORE THE RENAME (the chairman 2026-11-18, on the president's measurement: pids 524971 and 528268, 19 hours old, ran on in s4e-seat-officer_04.scope, a scope made
# before officer_NN became developer_NN that morning, and developer_04's kill read them "not mine"): developer_01 to developer_12 own what a scope named for officer_01 to officer_12 holds.
old_seat=""; case "$me_seat" in developer_0[1-9]|developer_1[0-2]) old_seat="officer_${me_seat#developer_}" ;; esac; seat_re="${me_seat}${old_seat:+|$old_seat}"
hfile() { if [ -f "$bgdir/$1.handle" ]; then printf '%s' "$bgdir/$1.handle"; else printf '%s' "$oldbg/$1.handle"; fi; }
mine_pid() {  # mine_pid <pid> -> 0 when the pid carries one of this seat's handles or runs under this root; prints why
  local env h cwd; [ -d "/proc/$1" ] || { echo "pid $1 is not alive"; return 1; }
  h="$(tr '\0' '\n' < "/proc/$1/environ" 2>/dev/null | sed -n 's/^S4E_BG_HANDLE=//p')"
  [ -n "$h" ] && [ -f "$(hfile "$h")" ] && { echo "handle $h of $me_seat"; return 0; }
  cwd=$(readlink -f "/proc/$1/cwd" 2>/dev/null); case "$cwd" in "$S4E"|"$S4E"/*) echo "cwd $cwd under $S4E"; return 0 ;; esac
  # THE SEAT'S OWN SCOPE (the coo 2026-11-14, on officer_05's measurement: a seat's sandbox cannot read /proc/<pid>/environ or cwd, so all 6 of its orphaned reduce runs read
  # "not mine" and were killed by hand; /proc/<pid>/cgroup is world-readable there): a pid in s4e-seat-<seat>.scope or in one of the seat's s4e-mem-<seat>-* scopes is the seat's
  [ -n "$me_seat" ] && grep -qE "/(s4e-seat-(${seat_re})\.scope|s4e-mem-(${seat_re})-[^/]*\.scope)(/|\$)" "/proc/$1/cgroup" 2>/dev/null && { echo "cgroup $(sed -n 's|^0::||p' "/proc/$1/cgroup" | sed 's|.*/||') of $me_seat"; return 0; }
  # THE SEAT'S OWN SLICE (the coo 2026-11-16, on the grader's measurement: the cycle's cells run in s4e-grader.slice/s4e-cycle-<N>.scope, which is neither scope of the arm above,
  # so the grader's kill of two held cells of its own cycle was refused "not mine" and it sent the TERM by hand): a pid in a scope of the slice named for the seat, s4e-<seat>.slice, is the seat's
  [ -n "$me_seat" ] && grep -qE "/s4e-${me_seat}\.slice/[^/]*\.scope(/|\$)" "/proc/$1/cgroup" 2>/dev/null && { echo "cgroup $(sed -n 's|^0::||p' "/proc/$1/cgroup" | sed 's|.*/||') in s4e-${me_seat}.slice of $me_seat"; return 0; }
  echo "not mine: no handle of $me_seat in its environment${h:+ (handle $h is not under $bgdir)} and cwd ${cwd:-?} is not under $S4E"; return 1; }
kill_one() {  # kill_one <pid> <why>: TERM, then KILL after 3 s; the ledger line; prints the KILL-MINE line
  local pid="$1" cwd cmd i; cwd=$(readlink -f "/proc/$pid/cwd" 2>/dev/null); cmd=$( (tr '\0' ' ' < "/proc/$pid/cmdline") 2>/dev/null | sed 's/[[:space:]]*$//')
  kill -TERM "$pid" 2>/dev/null; kill_ledger_append "$pid" TERM "$cwd" "$cmd"
  for i in 1 2 3 4 5 6; do [ -d "/proc/$pid" ] || break; sleep 0.5; done
  [ -d "/proc/$pid" ] && { kill -KILL "$pid" 2>/dev/null; kill_ledger_append "$pid" KILL "$cwd" "$cmd"; sleep 0.5; }
  echo "KILL-MINE pid=$pid root=$S4E $2 signalled=$([ -d "/proc/$pid" ] && echo TERM+KILL,still-alive || echo TERM,gone) cmd=$(printf '%s' "$cmd" | cut -c1-120)"; }
probe() {
  local o id pid why="" f other
  o="$(bash "$(dirname "${BASH_SOURCE[0]}")/util_run_slot.sh" --bg sleep 600 2>&1)" || { echo "KILL-MINE PROBE RED: util_run_slot.sh --bg refused [$o]"; exit 1; }
  id="$(printf '%s\n' "$o" | sed -n 's/^BG handle=\([^ ]*\) .*/\1/p')"; pid="$(printf '%s\n' "$o" | sed -n 's/.* pid=\([0-9]*\) .*/\1/p')"
  [ -n "$id" ] && [ -n "$pid" ] || { echo "KILL-MINE PROBE RED: no BG handle line [$o]"; exit 1; }
  # the dry-run arm: --explain-only signals nothing with --pid or --handle, on either side of them (MEASURED 2026-11-17: it killed with --pid)
  o="$(bash "${BASH_SOURCE[0]}" --explain-only --pid "$pid" 2>&1)"; printf '%s\n' "$o" | grep -q "^EXPLAIN-ONLY pid=$pid " && [ -d "/proc/$pid" ] || why="$why --explain-only --pid signalled its pid or said nothing [$o];"
  o="$(bash "${BASH_SOURCE[0]}" --pid "$pid" --explain-only 2>&1)"; printf '%s\n' "$o" | grep -q "^EXPLAIN-ONLY pid=$pid " && [ -d "/proc/$pid" ] || why="$why --pid --explain-only signalled its pid or said nothing [$o];"
  o="$(bash "${BASH_SOURCE[0]}" --handle "$id" --explain-only 2>&1)"; printf '%s\n' "$o" | grep -q "^EXPLAIN-ONLY pid=$pid handle=$id " && [ -d "/proc/$pid" ] && [ -f "$(hfile "$id")" ] || why="$why --handle --explain-only signalled its run or retired its handle [$o];"
  o="$(bash "${BASH_SOURCE[0]}" --handle "$id" 2>&1)"; printf '%s\n' "$o" | grep -q "^KILL-MINE pid=$pid " || why="$why --handle did not kill its own run [$o];"
  [ -d "/proc/$pid" ] && why="$why pid $pid is still alive after --handle;"
  [ -f "$(hfile "$id")" ] && why="$why the handle file was not retired;"
  o="$(bash "${BASH_SOURCE[0]}" --pid 1 2>&1)"; [ $? = 2 ] && [ -d /proc/1 ] || why="$why --pid 1 was not refused rc 2 [$o];"
  other="$(for f in /proc/[0-9]*/cwd; do c=$(readlink -f "$f" 2>/dev/null) || continue
    case "$c" in /home/claude_*) case "$c" in "$S4E"|"$S4E"/*) ;; *) echo "${f#/proc/}" | cut -d/ -f1; break ;; esac ;; esac; done)"
  if [ -n "$other" ]; then o="$(bash "${BASH_SOURCE[0]}" --pid "$other" 2>&1)"; [ $? = 2 ] && [ -d "/proc/$other" ] || why="$why another root's pid $other was not refused rc 2 [$o];"; fi
  o="$(bash "${BASH_SOURCE[0]}" --handle "no-such-handle-$$" 2>&1)"; [ $? = 2 ] || why="$why an unknown handle was not refused rc 2 [$o];"
  # the scope arm: a run in the seat's own s4e-mem-<seat>-* scope, its cwd / and no handle in its environment, is the seat's (the only test a sandboxed seat can read)
  ( cd / && exec env -i PATH=/usr/bin:/bin HOME="$HOME" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}" \
      systemd-run --user --scope --quiet --slice=s4e-batch.slice --unit="s4e-mem-${me_seat}-killprobe-$$" sleep 600 ) >/dev/null 2>&1 &
  local sp="" bp=$! i; for i in $(seq 1 20); do grep -q "s4e-mem-${me_seat}-killprobe-$$" "/proc/$bp/cgroup" 2>/dev/null && { sp="$bp"; break; }; sleep 0.5; done
  if [ -z "$sp" ]; then why="$why the scope arm could not start a run in s4e-mem-${me_seat}-killprobe-$$;"
  else o="$(bash "${BASH_SOURCE[0]}" --pid "$sp" 2>&1)"; printf '%s\n' "$o" | grep -q "^KILL-MINE pid=$sp .*cgroup s4e-mem-${me_seat}-killprobe" || why="$why a run in the seat's own scope (cwd /, no handle) was not killed as the seat's [$o];"
    [ -d "/proc/$sp" ] && { kill -KILL "$sp" 2>/dev/null; why="$why the scope arm's pid $sp is still alive;"; }; fi
  [ -z "$why" ] && { echo "KILL-MINE probe ok dry_run_signals_nothing=yes handle=$id own_pid=$pid killed=yes foreign_refused=pid1${other:+,pid$other} unknown_handle_refused=yes own_scope_killed=yes root=$S4E"; exit 0; }
  echo "KILL-MINE PROBE RED:$why"; exit 1; }
explain_only=""
# --explain-only binds WHEREVER IT STANDS ON THE LINE, and it binds --pid and --handle too (the grader 2026-11-17, MEASURED: `--explain-only --pid 382874`
# signalled TERM and killed the live cycle mid-lap, since the --pid branch killed at once and the flag was read only by the pattern form). So the line is
# read for it first, and under it --pid and --handle print what they would signal and signal nothing.
for _a in "$@"; do [ "$_a" = --explain-only ] && explain_only=1; done
named_root=""
pattern=""
while [ $# -gt 0 ]; do
  case "$1" in
    --probe) probe ;;
    --handle) h="${2:-}"; [ -n "$h" ] || { echo "refuse: --handle needs the id a BG line printed -- rc=2" >&2; exit 2; }
      [ -f "$(hfile "$h")" ] || { echo "refuse: no handle $h under $bgdir (not this seat's background run) -- rc=2, nothing signalled" >&2; exit 2; }
      hp="$(sed -n 's/^pid=\([0-9]*\) .*/\1/p' "$(hfile "$h")")"
      if ! w="$(mine_pid "$hp")"; then [ -n "$explain_only" ] || rm -f "$(hfile "$h")"; echo "refuse: handle $h: $w (the handle is retired) -- rc=2, nothing signalled" >&2; exit 2; fi
      [ -n "$explain_only" ] && { echo "EXPLAIN-ONLY pid=$hp handle=$h ($w): it would be signalled; nothing was signalled"; exit 0; }
      kill_one "$hp" "handle=$h ($w)"; rm -f "$(hfile "$h")"; exit 0 ;;
    --pid) hp="${2:-}"; [[ "$hp" =~ ^[0-9]+$ ]] || { echo "refuse: --pid needs a number -- rc=2" >&2; exit 2; }
      w="$(mine_pid "$hp")" || { echo "refuse: pid $hp: $w -- rc=2, nothing signalled" >&2; exit 2; }
      [ -n "$explain_only" ] && { echo "EXPLAIN-ONLY pid=$hp ($w): it would be signalled; nothing was signalled"; exit 0; }
      kill_one "$hp" "pid=$hp ($w)"; exit 0 ;;
    --explain-only) explain_only=1; shift ;;
    --root) named_root="${2:-}"; shift 2 || { echo "refuse: --root needs a directory" >&2; exit 2; } ;;
    --root=*) named_root="${1#--root=}"; shift ;;
    -h|--help) usage; exit 2 ;;
    --) shift; pattern="${1:-}"; break ;;
    -*) usage; echo "refuse: unknown flag '$1' -- refusing rather than guessing what it scopes to" >&2; exit 2 ;;
    *) pattern="$1"; shift ;;
  esac
done

# --- ARM ONE, AND IT IS CHECKED BEFORE ANYTHING IS ENUMERATED: a named root that is
# not the caller's own is a refusal.  Order matters -- validating the root only after
# building a target list would mean the wrong-root case had already read every other
# seat's /proc entry to decide what it was "about" to do.
if [ -n "$named_root" ]; then
  nr=$(readlink -f "$named_root" 2>/dev/null || printf '%s' "$named_root")
  if [ "$nr" != "$S4E" ]; then
    echo "refuse: --root '$named_root' (resolves to '$nr') is NOT this caller's own root '$S4E'." >&2
    echo "        A kill names its own root or it refuses; there is no box-wide form, so '/' is a refusal and not a wildcard." >&2
    echo "        rc=2 -- nothing was enumerated and nothing was signalled." >&2
    exit 2
  fi
fi

if [ -z "$pattern" ] && [ -z "$explain_only" ]; then
  usage
  echo "refuse: no pattern given -- there is no box-wide form" >&2
  exit 2
fi

# --- step 1: the caller's own shell/pid tree, always excluded ---
declare -A ancestors
p=$$
while [[ $p =~ ^[0-9]+$ ]]; do
  ancestors[$p]=1
  [ "$p" -le 1 ] && break
  p=$(awk '/^PPid:/{print $2}' "/proc/$p/status" 2>/dev/null)
done

# --- steps 2+3: root-scope, then name/argv match.  In --explain-only every pid that
# falls out is RECORDED WITH THE REASON CLASS IT FELL OUT UNDER, because "I would not
# touch this" is only checkable if it says which rule spared it.
targets=()
declined_ancestor=() declined_outside=() declined_nomatch=()
scanned=0
for pidpath in /proc/[0-9]*/; do
  pid=${pidpath#/proc/}
  pid=${pid%/}
  scanned=$((scanned + 1))
  if [ -n "${ancestors[$pid]:-}" ]; then
    [ -n "$explain_only" ] && declined_ancestor+=("$pid")
    continue
  fi

  cwd=$(readlink -f "/proc/$pid/cwd" 2>/dev/null) || continue
  case "$cwd" in
    "$S4E"|"$S4E"/*) ;;
    *) [ -n "$explain_only" ] && declined_outside+=("$pid"); continue ;;
  esac

  comm=$(cat "/proc/$pid/comm" 2>/dev/null) || comm=""
  cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null) || cmdline=""

  match=""
  if [ -n "$pattern" ]; then
    [ "$comm" = "$pattern" ] && match=1
    case "$cmdline" in *"$pattern"*) match=1 ;; esac
  fi
  if [ -n "$match" ]; then
    targets+=("$pid")
  else
    [ -n "$explain_only" ] && declined_nomatch+=("$pid")
  fi
done

show() { # pid -> one evidence line
  local pid="$1" c m
  c=$(readlink -f "/proc/$pid/cwd" 2>/dev/null)
  m=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)
  printf '      pid=%s cwd=%s cmd=%s\n' "$pid" "${c:-<gone>}" "${m:0:120}"
}

if [ -n "$explain_only" ]; then
  echo "s4e_kill_mine --explain-only: SIGNALLING NOTHING. This is the answer to the question, not the act."
  # ⛔ `${v:+a}${v:-b}` IS NOT AN IF/ELSE and this line proved it in testing: when v is set,
  # ${v:-b} expands to v's VALUE, so the "verified" branch printed the root a second time
  # ("...and verified/home/claude_coo"). Two expansions of the same variable are not two
  # branches of one choice. Written as a plain if, which is what it always meant.
  if [ -n "$named_root" ]; then
    echo "  root scoped to: $S4E   (named as '$named_root' and VERIFIED against this caller's own derived root)"
  else
    echo "  root scoped to: $S4E   (derived, D-17 sibling root -- name it with --root to have it verified)"
  fi
  echo "  pattern: ${pattern:-<none given> -- with no pattern NOTHING can match, so every pid below is declined and the decline reasons are the point}"
  echo "  /proc entries scanned: $scanned"
  echo "  WOULD SIGNAL: ${#targets[@]} pid(s)"
  for pid in "${targets[@]:-}"; do [ -n "$pid" ] && show "$pid"; done
  echo "  WOULD DECLINE: $(( ${#declined_ancestor[@]} + ${#declined_outside[@]} + ${#declined_nomatch[@]} )) pid(s), by reason class:"
  echo "    would decline ${#declined_ancestor[@]} as ANCESTOR_CHAIN -- the caller's own shell/pid tree, never a target whatever it matches (step 1)"
  for pid in "${declined_ancestor[@]:-}"; do [ -n "$pid" ] && show "$pid"; done
  echo "    would decline ${#declined_outside[@]} as NOT_UNDER_ROOT -- cwd resolves outside $S4E; THIS IS THE CLASS THE ELEVEN-PID INCIDENT SIGNALLED (step 2)"
  echo "    would decline ${#declined_nomatch[@]} as $([ -n "$pattern" ] && echo NO_PATTERN_MATCH || echo NO_PATTERN_GIVEN) -- under this root, but no comm/argv match (step 3)"
  echo "  ⛔ NOTHING WAS SIGNALLED BY THIS RUN. Re-run without --explain-only to act, and the root above is the scope you get."
  exit 0
fi

if [ "${#targets[@]}" -eq 0 ]; then
  echo "refuse: nothing under $S4E matches '$pattern' (root-scoped, ancestor chain excluded) -- rc=2" >&2
  exit 2
fi

echo "s4e_kill_mine: root=$S4E ${named_root:+(named and verified)} -- signalling ${#targets[@]} pid(s) matching '$pattern':"
for pid in "${targets[@]}"; do
  cwd=$(readlink -f "/proc/$pid/cwd" 2>/dev/null)
  cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)
  printf '  pid=%s cwd=%s cmd=%s\n' "$pid" "$cwd" "$cmdline"
done

# ⛔⭐ EVERY SIGNAL THIS SCRIPT SENDS IS RECORDED, BECAUSE A KILL THAT LEAVES NO RECORD CANNOT BE NAMED BY ITS
# VICTIM (coo 2026-09-20, row instruments-a-blocking-set-run-is-killed-from-outside-and-no-seat-completed-one-
# today, on the cfo's CFO-147). FIVE DEATHS, THREE SEATS, ONE AFTERNOON -- the cfo at arm 103 with SIGTERM
# and arm 166 with SIGKILL despite setsid, hq_prolog at arm 6 after thirty seconds, hq_raku at 18 and at 61 --
# and NOT ONE OF THEM COULD SAY WHO KILLED IT. Ten seats share one unix user, so the question "was that me?"
# is answerable only from a shared record. This is that record: append-only, one line per pid signalled,
# naming the SENDER as well as the target, under flock so ten seats can write it at once.
# ⛔ --explain-only WRITES NOTHING, and that is not an oversight: it signals nothing, so a line here would be
# a record of an event that did not happen -- the same false-green shape in ledger clothing.
# ⛔ AND AN UNWRITABLE LEDGER DOES NOT BLOCK THE KILL. A seat trying to stop its own runaway process must not
# be stopped by a full disk; the kill proceeds and the failure is PRINTED, so the victim's report will read
# "no ledger entry" honestly rather than being silently robbed of its answer.
for pid in "${targets[@]}"; do
  _cwd=$(readlink -f "/proc/$pid/cwd" 2>/dev/null)
  # ⛔ THE SUBSHELL IS THE POINT: a pid can vanish between enumeration and this read (a child dying with its
  # parent is the common case), and `< /proc/N/cmdline 2>/dev/null` cannot suppress the SHELL's own redirection
  # error -- it prints "No such file" from the middle of a kill report. The record then reads "unknown", which
  # is the honest value for a process that was already gone.
  _cmd=$( (tr '\0' ' ' < "/proc/$pid/cmdline") 2>/dev/null | sed 's/[[:space:]]*$//')
  # ⛔⭐ THE RECORD IS WRITTEN BEFORE THE SIGNAL, AND THE ORDER IS THE WHOLE CURE (cfo 2026-09-20, PROVEN on
  # their own board rather than argued: pid 783278, signalled 22:14:36Z, its victim trap read this ledger at
  # 22:14:35Z and reported "NO LEDGER ENTRY ... AN UNLOGGED KILLER" -- about a kill that was correct, scoped,
  # and by then already recorded. THE VICTIM LOST BY ONE SECOND. The cfo replayed the victim's own awk a
  # minute later and it named them correctly, which isolates the defect to WHEN the file was read and clears
  # the lookup, the field-6 key and the runstate write. Signal-then-append raced structurally and not by luck:
  # the append for their pid came after nineteen other pids had been signalled and probed through /proc.
  # ⛔ WHY THE OLD ORDER WAS THE MOST EXPENSIVE POSSIBLE WRONG ANSWER: it converted a CORRECT, ROOT-SCOPED,
  # LEDGERED kill into the accusation of an unlogged rogue -- in exactly the words this instrument uses to make
  # a REAL rogue findable -- and the live banner is what a seat reads first, while the postmortem correction
  # only ever reaches a seat that starts another run in the same root. A seat who dies, reads AN UNLOGGED
  # KILLER and goes hunting never sees the retraction.
  # ⛔ AND THE ROW NOW MEANS AN ATTEMPT, WHICH IS SAID HERE RATHER THAN LEFT TO BE INFERRED: a row written
  # before a signal that then fails records a kill that was TRIED. That is strictly better than a victim
  # accusing a phantom, and a signal that did not land is PRINTED below so the record and reality never
  # silently disagree.
  kill_ledger_append "$pid" "TERM" "$_cwd" "$_cmd"
  if ! kill -TERM "$pid" 2>/dev/null; then
    echo "  ⚠ pid $pid was already gone when the signal was sent -- the ledger row above records the ATTEMPT, not a delivered signal" >&2
  fi
done
echo "s4e_kill_mine: ${#targets[@]} signal(s) recorded in $KILL_LEDGER BEFORE being sent -- a victim can now name this kill"
exit 0
