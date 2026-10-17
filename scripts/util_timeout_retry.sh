#!/usr/bin/env bash
# util_timeout_retry.sh -- `timeout` FOR A GRADED RUN: A TIMEOUT WHILE THE 1-MINUTE LOAD EXCEEDS THE CORES IS COULD NOT MEASURE,
# SO THE COMMAND IS RUN ONCE MORE AND ONLY A SECOND TIMEOUT STANDS (ceo CEO-1335; row instruments-a-per-program-timeout-while-
# load1-exceeds-the-cores-is-could-not-measure-retried-once-serially-before-fail-and-the-retry-stamped-on-the-progress-row-ceo-1335;
# the coo 2026-10-09). The package runners' half of the row; corpus_suite_harness.classify is the harness's half (SCRIP 42bce05d2).
# MEASURED: pass 44's make test-boards (SCRIP cffeedb19, load ~20 on 16 cores) read fpc 180/181 -- webtbs_tw15203, 33 s unloaded and
# 74 s at load 19, was killed at its declared 120 s and test_pascal_fpc_suite.sh graded the rc 124 FAIL output-differs-from-ref, an
# hour after the same tree read it PASS. The timeout measured the scheduler.
# USAGE: exactly timeout's -- util_timeout_retry.sh [timeout options] DURATION COMMAND [ARG]... -- so a runner swaps the word
# `timeout` for "$TIMEOUT_RETRY" (lib_progress.sh) and changes nothing else at the site: behind run_at_declared_table, env, a
# $(...) capture, `> out 2> err`, `2>&1` and `< in` alike.
#   * stdin is NEVER read by this tool: the first attempt inherits it untouched (a command that reads no stdin leaves a caller's
#     `while read ... done < list` loop its input -- an eager buffer swallowed the roast runner's file list, measured 2026-10-09);
#     the retry re-opens a regular file or a character device (/dev/null) by its path, and a pipe it cannot replay is inherited as
#     it stands, the stamp saying stdin-not-replayed
#   * stdout and stderr are buffered and only the attempt that stands is written; when the two are one file (2>&1) they are captured
#     as one stream, so the interleaving the caller grades is the program's own
#   * the exit status is the standing attempt's, timeout's own (124 on a timeout, 125-127 and 128+n as timeout returns them)
#   ⛔⭐ EVERY TIMEOUT IS RETRIED ONCE, LONGER, WHATEVER THE LOAD (Lon 2026-10-15 15:3x CDT, in-chat to the coo, verbatim: "So timeout
#     SHOULD NOT count as valid." and "The strategy should be to accumulate a list of timeouts, and do a retry with longer timeouts.";
#     superseding CEO-1335's "a timeout at or under the cores is graded at once" and its same-length retry). Measured: the logtalk_iso
#     pass on 52f822b69 ran 9318 s at load 19-21 on 16 cores and 344 of its 361 m4 reds were timeouts. The retry's limit is
#     S4E_TIMEOUT_RETRY_FACTOR (default 6) times the first, capped at S4E_TIMEOUT_RETRY_CAP seconds (default 600) unless the first is
#     longer already; only a timeout at that longer limit stands, and the stamp lists every retried unit (the accumulated list)
#   * S4E_TIMEOUT_RETRY=0 is plain timeout (exec'd), the gate's fail-once arm
#   * the load and the cores are lib_fanout.py's (fanout_load1, fanout_cores), the harness's one definition; FANOUT_PROC plants a load
#   * a retry appends one line to $S4E_TIMEOUT_STAMP (lib_progress.sh points it per runner):
#     <key> TAB <m3|m4|oracle> TAB retried=1 load1=<first>/<second> nproc=<n> at=<retry limit>s [timeout-twice]
#     <key> is $S4E_TIMEOUT_KEY when the runner names the unit it is grading, else the argv's file stems; util_progress_append.py
#     attaches the stamp to that unit's progress row (m3 to m3, m4 to m4, an oracle's to every mode) and clears the file
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
longer() { awk -v d="$1" -v f="${S4E_TIMEOUT_RETRY_FACTOR:-6}" -v c="${S4E_TIMEOUT_RETRY_CAP:-600}" 'BEGIN {
    if (!match(d, /^[0-9]*\.?[0-9]+[smhd]?$/)) { print d; exit }
    u = substr(d, length(d)); m = 1; if (u == "m") m = 60; else if (u == "h") m = 3600; else if (u == "d") m = 86400
    t = (u ~ /[smhd]/ ? substr(d, 1, length(d) - 1) : d) * m; l = t * f; k = (t > c ? t : c); if (l > k) l = k
    printf "%gs\n", l }'; }
[ "${1:-}" = --longer ] && { longer "${2:?util_timeout_retry.sh --longer DURATION}"; exit 0; }   # the retry limit, for a runner that retries its own timed run
opts=()
while [ $# -gt 0 ]; do
    case "$1" in
        -k|-s|--kill-after|--signal) opts+=("$1" "${2:-}"); shift 2 ;;
        --) shift; break ;;
        -*) opts+=("$1"); shift ;;
        *) break ;;
    esac
done
[ $# -ge 2 ] || { echo "util_timeout_retry.sh: usage: util_timeout_retry.sh [timeout options] DURATION COMMAND [ARG]..." >&2; exit 125; }
# ⛔ A TIMEOUT CARRIES A KILL (ceo CEO-1796): SIGTERM alone left three swipl runs burning a core each for two hours; a caller that names no -k gets -k 5.
case " ${opts[*]-} " in *" -k "*|*" --kill-after "*|*" --kill-after="*) ;; *) opts+=(-k 5) ;; esac
[ "${S4E_TIMEOUT_RETRY:-1}" = 0 ] && exec timeout ${opts[@]+"${opts[@]}"} "$@"
dur="$1"; shift
W="$(mktemp -d "${TMPDIR:-/tmp}/s4e-tretry.XXXXXX")" || exec timeout ${opts[@]+"${opts[@]}"} "$dur" "$@"
trap 'rm -rf "$W"' EXIT
fd0="/proc/$$/fd/0"
REOPEN=""
if [ ! -t 0 ] && { [ -c "$fd0" ] || [ -f "$fd0" ]; }; then REOPEN="$(readlink -f "$fd0" 2>/dev/null)"; [ -r "$REOPEN" ] || REOPEN=""; fi
same=0
[ "$(stat -L -c %d:%i "/proc/$$/fd/1" 2>/dev/null)" = "$(stat -L -c %d:%i "/proc/$$/fd/2" 2>/dev/null)" ] && same=1
attempt() {
    if [ -z "$IN" ]; then
        if [ "$same" = 1 ]; then timeout ${opts[@]+"${opts[@]}"} "$dur" "$@" > "$W/o" 2>&1; else timeout ${opts[@]+"${opts[@]}"} "$dur" "$@" > "$W/o" 2> "$W/e"; fi
    else
        if [ "$same" = 1 ]; then timeout ${opts[@]+"${opts[@]}"} "$dur" "$@" < "$IN" > "$W/o" 2>&1; else timeout ${opts[@]+"${opts[@]}"} "$dur" "$@" < "$IN" > "$W/o" 2> "$W/e"; fi
    fi
}
IN=""
load() { python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import lib_fanout as f; print("%.2f %d" % (f.fanout_load1(), f.fanout_cores()))' "$HERE" 2>/dev/null || echo "0.00 1"; }
attempt "$@"; rc=$?
if [ "$rc" = 124 ]; then
    read -r l1 n <<<"$(load)"
    IN="$REOPEN"; rm -f "$W/o" "$W/e"; dur="$(longer "$dur")"
    attempt "$@"; rc=$?
    read -r l2 _n <<<"$(load)"
    if [ -n "${S4E_TIMEOUT_STAMP:-}" ]; then
        role=m4; isscrip=0; isoracle=0; compile=0
        for a in "$@"; do
            case "$(basename -- "$a" 2>/dev/null)" in
                scrip) isscrip=1 ;;
                sbl|spitbol|fpc|gprolog|swipl|icont|iconx|raku|rakudo|csnobol4|snobol4|jcont|jconx) isoracle=1 ;;
            esac
            case "$a" in *--compile*) compile=1 ;; esac
        done
        if [ "$isscrip" = 1 ]; then role=m3; [ "$compile" = 1 ] && role=m4
        elif [ "$isoracle" = 1 ]; then role=oracle
        fi
        key="${S4E_TIMEOUT_KEY:-}"
        if [ -z "$key" ]; then
            for a in "$@"; do case "$a" in -*) ;; */*|*.*) s="$(basename -- "$a")"; key="${key:+$key,}${s%.*}" ;; esac; done
        fi
        tw=""; [ "$rc" = 124 ] && tw=" timeout-twice"
        [ -n "$REOPEN" ] || [ -t 0 ] || tw="$tw stdin-not-replayed"
        printf '%s\t%s\tretried=1 load1=%s/%s nproc=%s at=%s%s\n' "$key" "$role" "$l1" "$l2" "$n" "$dur" "$tw" >> "$S4E_TIMEOUT_STAMP" 2>/dev/null
    fi
fi
cat "$W/o"
[ "$same" = 1 ] || { [ -f "$W/e" ] && cat "$W/e" >&2; }
exit "$rc"
