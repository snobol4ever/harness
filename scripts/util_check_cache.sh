#!/usr/bin/env bash
# util_check_cache.sh -- THE CHECK CACHE (ARCH-SHARED-DEVELOPMENT section 3.3; row shared-dev-step-7-the-check-cache-a-deterministic-gate-runs-
# once-per-tree-for-done-and-the-sweep-r-2041; the cto's design, built by the cqo 2026-10-31). A deterministic check is a pure function of the
# four trees and the arguments, so it runs ONCE per tree for the whole fleet and every later run on the same trees replays its verdict.
#
#   util_check_cache.sh [--fresh] NAME -- COMMAND [ARG...]
#       KEY  = sha256 of NAME, the HEAD^{tree} of SCRIP, corpus, harness and .github (this script's own root: the four siblings beside
#              harness/), and COMMAND with every ARG (NUL-separated, so no two argument lists share a key).
#       HIT  (the four trees CLEAN at those hashes, SCRIP's out/buildinfo naming the same SCRIP tree, the entry present): prints
#              "CACHED <key> <utc of the run that stored it>", then the stored output, and exits with the stored rc. COMMAND is not run.
#       MISS: runs COMMAND (stdout and stderr together), prints its output, exits with its rc, and STORES rc and output by an atomic rename
#              when the run is cacheable. Only a verdict is stored: rc 0 or rc 1. A refusal (rc 2), a timeout or any other rc is never stored,
#              because "could not measure" is a fact about the box at that moment, not about the trees.
#       LIVE (runs, stores nothing, prints "LIVE <why>" on stderr): a dirty tree in any of the four repos (tracked change or untracked file);
#              a SCRIP whose out/buildinfo is absent or names another tree (the binary is not a build of this tree); NAME, or the basename of
#              any argument, listed in checks_nocache.tsv; S4E_ONE_TEST_ADMIT set, any SCRIP_* variable set (a runtime override), or
#              S4E_NO_CHECK_CACHE=1 (the control arm).
#       --fresh: bypasses the lookup once and says so on the first line ("FRESH <key>"); the run is stored as a miss would be.
#   util_check_cache.sh --cacheable-text TEXT
#       rc 0 when TEXT (a DONE-WHEN) names at least one harness script and every harness script it names is a test_gate_*.sh not in
#       checks_nocache.tsv; rc 1 otherwise. s4e_msg.sh done and the zero-base sweep route a DONE-WHEN through the cache only then: a criterion
#       that names a board, a bus verb or any other script runs live as before.
#   util_check_cache.sh --census
#       prints the test_gate_*.sh whose text reads something the four tree hashes do not name (the patterns below), one per line with its
#       reason; checks_nocache.tsv must hold every one (the gate's arm proves it), and may hold more by hand.
#   util_check_cache.sh --key NAME -- COMMAND [ARG...]      prints the key and why it would or would not hit; runs nothing.
#   util_check_cache.sh [--key] [--fresh] --inputs "TOKENS" NAME -- COMMAND [ARG...]
#       keys a check by the content of the files it reads, not by the four trees, so a commit elsewhere replays the verdict. A token is
#       R@HEAD (R one of SCRIP corpus harness .github: the id is R's HEAD commit, dirty when R has any change), R/P (a tracked file or
#       directory of R: the id is its HEAD blob or tree, dirty when P has a change, an untracked file under P counting), or R/P not in HEAD
#       but a file on disk (the id is the sha256 of the file, never dirty: this is how SCRIP/out/libscrip_rt.so is keyed). Any other token,
#       or a path that is absent, is LIVE ("input TOKEN is absent"); a dirty token is LIVE ("input TOKEN is dirty"). KEY = the first 40 hex of
#       the sha256 of the line inputs-v1, then NAME, then one TOKEN=ID line per token in sorted order, then COMMAND and every ARG NUL-separated.
#       The whole-root rules (the four clean trees, the SCRIP buildinfo) do not apply to this form; every other LIVE rule does. Tool versions
#       (swipl, objdump, gcc) are not keyed in either form.
#   util_check_cache.sh --probe-inputs
#       proves the --inputs form on a scratch root of four repos: six readings (first, second, unrelated, input, dirty, absent) print one
#       INPUTS_PROBE line with ok=1 only when all six are as expected. It writes only under /tmp/s4e/<seat>/cci.*, and removes it.
#
# The store is S4E_CHECK_CACHE_DIR (default /home/resources/progress/checks): <dir>/<NAME>/<key>/{rc,out,utc,cmd}. The gate points it at a
# scratch directory (the seam util_build_cache.sh's gate uses). Entries are never invalidated: a new landing is a new key (section 3.1).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd "$HERE/../.." && pwd -P)"
STORE="${S4E_CHECK_CACHE_DIR:-/home/resources/progress/checks}"
NOCACHE="$HERE/checks_nocache.tsv"
PAT_BUS='/home/resources/postoffice|s4e_msg\.sh|s4e_test_request\.sh|QUEUE\.tsv'
PAT_BOARD='/home/resources/progress|util_score_row|util_suite_row_at_100|_suite\.sh|corpus_suite_harness\.py"? run|test_[a-z0-9]+_ladder\.sh'
PAT_BOX='LOAD\.tsv|SEATS\.tsv|SLICES\.tsv|loadavg|uptime|/proc/pressure|\bpgrep\b|\bps (-e|aux|-o)|systemctl|/sys/fs/cgroup'
PAT_CLOCK='\$SECONDS|\belapsed\b|wall.?clock|date \+%s|perf stat|util_instr_count|callgrind|bench_'
PAT_OVR='S4E_ONE_TEST_ADMIT'
census() {
    local f
    for f in "$HERE"/test_gate_*.sh; do
        if grep -qE "$PAT_BUS" "$f"; then printf '%s\tthe postoffice (the bus, the queue, a seat inbox)\n' "$(basename "$f")"
        elif grep -qE "$PAT_BOARD" "$f"; then printf '%s\tthe progress store or a board (a graded population)\n' "$(basename "$f")"
        elif grep -qE "$PAT_BOX" "$f"; then printf '%s\tthe live box (load, pressure, seats, processes, the slices)\n' "$(basename "$f")"
        elif grep -qE "$PAT_CLOCK" "$f"; then printf '%s\ta clock or a counter (elapsed time, perf, callgrind)\n' "$(basename "$f")"
        elif grep -qE "$PAT_OVR" "$f"; then printf '%s\tan override (S4E_ONE_TEST_ADMIT)\n' "$(basename "$f")"
        fi
    done
}
nocache_has() { [ -f "$NOCACHE" ] && grep -v '^#' "$NOCACHE" | cut -f1 | grep -qxF -- "$1"; }
tree_of() { git -C "$ROOT/$1" rev-parse 'HEAD^{tree}' 2>/dev/null; }
clean_of() { [ -d "$ROOT/$1/.git" ] || [ -f "$ROOT/$1/.git" ] || return 1; [ -z "$(git -C "$ROOT/$1" status --porcelain 2>/dev/null)" ]; }
input_id() {
    local t="$1" r p id d
    case "$t" in
        *@HEAD)
            r="${t%@HEAD}"; case "$r" in SCRIP|corpus|harness|.github) ;; *) return 1 ;; esac
            id="$(git -C "$ROOT/$r" rev-parse HEAD 2>/dev/null)" && [ -n "$id" ] || return 1
            d=0; [ -n "$(git -C "$ROOT/$r" status --porcelain 2>/dev/null)" ] && d=1
            printf '%s %s\n' "$id" "$d" ;;
        */*)
            r="${t%%/*}"; p="${t#*/}"; case "$r" in SCRIP|corpus|harness|.github) ;; *) return 1 ;; esac
            if id="$(git -C "$ROOT/$r" rev-parse "HEAD:$p" 2>/dev/null)" && [ -n "$id" ]; then
                d=0; [ -n "$(git -C "$ROOT/$r" status --porcelain -- "$p" 2>/dev/null)" ] && d=1
                printf '%s %s\n' "$id" "$d"
            elif [ -f "$ROOT/$r/$p" ]; then
                printf '%s 0\n' "$(sha256sum "$ROOT/$r/$p" | cut -c1-40)"
            else return 1; fi ;;
        *) return 1 ;;
    esac
}
probe_inputs() {
    local T r cmd f1 f2 f3 f4 f5 f6 c1 c2 c4 ok=1
    mkdir -p "/tmp/s4e/${S4E_SEAT:-probe}" 2>/dev/null
    T="$(mktemp -d "/tmp/s4e/${S4E_SEAT:-probe}/cci.XXXXXX" 2>/dev/null)" || { echo "REFUSE(2): mktemp failed for the probe" >&2; return 2; }
    for r in SCRIP corpus harness .github; do mkdir -p "$T/$r" && git -C "$T/$r" init -q 2>/dev/null || { rm -rf "$T"; return 2; }; done
    mkdir -p "$T/harness/scripts" && cp "$HERE/util_check_cache.sh" "$HERE/checks_nocache.tsv" "$T/harness/scripts/" || { rm -rf "$T"; return 2; }
    printf 'one\n' > "$T/harness/in.txt"; printf 'other\n' > "$T/harness/other.txt"; printf 'corpus\n' > "$T/corpus/c.txt"
    cm() { git -C "$T/$1" add -A && git -C "$T/$1" -c user.name=probe -c user.email=probe@localhost commit -q --allow-empty -m "$2"; }
    for r in SCRIP corpus harness .github; do cm "$r" init || { rm -rf "$T"; return 2; }; done
    export S4E_CHECK_CACHE_DIR="$T/store"
    cmd="echo run >> $T/count; cat $T/harness/in.txt"
    run_once() { bash "$T/harness/scripts/util_check_cache.sh" --inputs "$1" probe -- bash -c "$cmd" > "$T/out" 2> "$T/err"; }
    klass() { if grep -q LIVE "$T/err"; then echo live; elif head -1 "$T/out" | grep -q '^CACHED '; then echo hit; else echo miss; fi; }
    cnt() { wc -l < "$T/count" 2>/dev/null || echo 0; }
    run_once harness/in.txt; f1="$(klass)"; c1="$(cnt)"
    run_once harness/in.txt; f2="$(klass)"; c2="$(cnt)"
    echo more >> "$T/corpus/c.txt"; cm corpus unrelated; echo more >> "$T/harness/other.txt"; cm harness unrelated
    run_once harness/in.txt; f3="$(klass)"
    echo two >> "$T/harness/in.txt"; cm harness input
    run_once harness/in.txt; f4="$(klass)"; c4="$(cnt)"
    echo dirt >> "$T/harness/in.txt"
    run_once harness/in.txt; f5="$(klass)"
    git -C "$T/harness" checkout -q -- in.txt
    run_once harness/nope.txt; f6="$(klass)"
    [ "$f1" = miss ] && [ "$c1" = 1 ] || ok=0
    [ "$f2" = hit ] && [ "$c2" = 1 ] || ok=0
    [ "$f3" = hit ] || ok=0
    [ "$f4" = miss ] && [ "$c4" = 2 ] || ok=0
    [ "$f5" = live ] || ok=0
    [ "$f6" = live ] || ok=0
    echo "INPUTS_PROBE first=$f1 second=$f2 unrelated=$f3 input=$f4 dirty=$f5 absent=$f6 ok=$ok"
    rm -rf "$T"
    [ "$ok" = 1 ]
}
case "${1:-}" in
    --census) census; exit 0 ;;
    --probe-inputs) probe_inputs; exit $? ;;
    --cacheable-text)
        text="${2:-}"; n=0
        for s in $(printf '%s\n' "$text" | grep -oE '[A-Za-z0-9_./-]*harness/scripts/[A-Za-z0-9_.-]+' | sed 's|.*/||' | sort -u); do
            n=$((n + 1))
            case "$s" in test_gate_*.sh) ;; *) exit 1 ;; esac
            nocache_has "$s" && exit 1
        done
        [ "$n" -gt 0 ]; exit $? ;;
esac
fresh=0; keyonly=0
[ "${1:-}" = --key ] && { keyonly=1; shift; }
[ "${1:-}" = --fresh ] && { fresh=1; shift; }
inputs_mode=0; tokens=""
[ "${1:-}" = --inputs ] && { inputs_mode=1; tokens="${2:-}"; shift $(( $# > 2 ? 2 : $# )); }
read -r -a toks <<< "$tokens"
name="${1:-}"; [ -n "$name" ] && shift
[ "${1:-}" = -- ] && shift
[ -n "$name" ] && [ $# -gt 0 ] || { echo "usage: util_check_cache.sh [--fresh] NAME -- COMMAND [ARG...] | --cacheable-text TEXT | --census | --key NAME -- COMMAND... | [--inputs \"TOKENS\"] NAME -- COMMAND... | --probe-inputs" >&2; exit 2; }
case "$name" in */*|.*|'') echo "util_check_cache.sh: NAME must be one path segment: $name" >&2; exit 2 ;; esac
[ "$inputs_mode" = 1 ] && [ "${#toks[@]}" -eq 0 ] && { echo "REFUSE(2): --inputs needs TOKENS" >&2; exit 2; }
why=""
if [ "$inputs_mode" = 1 ]; then
    lines=""
    for t in "${toks[@]}"; do
        if info="$(input_id "$t")"; then id="${info% *}"; d="${info##* }"; else id=absent; d=0; [ -z "$why" ] && why="input $t is absent"; fi
        [ "$d" = 1 ] && [ -z "$why" ] && why="input $t is dirty"
        lines="$lines$t=$id"$'\n'
    done
    key="$( { printf 'inputs-v1\n%s\n' "$name"; printf '%s' "$lines" | sort; printf '%s\0' "$@"; } | sha256sum | cut -c1-40)"
else
    trees=""
    for r in SCRIP corpus harness .github; do t="$(tree_of "$r")"; trees="$trees|$r=${t:-none}"; done
    key="$( { printf '%s\n%s\n' "$name" "$trees"; printf '%s\0' "$@"; } | sha256sum | cut -c1-40)"
    for r in SCRIP corpus harness .github; do clean_of "$r" || { why="the $r tree is dirty or absent"; break; }; done
    if [ -z "$why" ]; then
        st="$(tree_of SCRIP)"; bt="$(sed -n 's/^tree //p' "$ROOT/SCRIP/out/buildinfo" 2>/dev/null | head -1)"
        [ -n "$bt" ] && [ "$bt" = "$st" ] || why="SCRIP's out/buildinfo does not name the SCRIP tree ${st:0:12} (run make)"
    fi
fi
[ -z "$why" ] && nocache_has "$name" && why="$name is in checks_nocache.tsv"
if [ -z "$why" ]; then for a in "$@"; do b="$(basename -- "$a")"; nocache_has "$b" && { why="$b is in checks_nocache.tsv"; break; }; done; fi
[ -z "$why" ] && [ -n "${S4E_ONE_TEST_ADMIT:-}" ] && why="S4E_ONE_TEST_ADMIT is set"
[ -z "$why" ] && [ -n "$(env | grep -E '^SCRIP_[A-Za-z0-9_]*=' | head -1)" ] && why="a SCRIP_* override is set"
[ -z "$why" ] && [ "${S4E_NO_CHECK_CACHE:-}" = 1 ] && why="S4E_NO_CHECK_CACHE=1"
e="$STORE/$name/$key"
if [ "$keyonly" = 1 ]; then
    if [ -n "$why" ]; then echo "$key LIVE ($why)"; elif [ -f "$e/rc" ]; then echo "$key HIT $(cat "$e/utc" 2>/dev/null)"; else echo "$key MISS"; fi
    exit 0
fi
if [ -z "$why" ] && [ "$fresh" = 0 ] && [ -f "$e/rc" ] && [ -f "$e/out" ]; then
    rc="$(cat "$e/rc")"
    echo "CACHED $key $(cat "$e/utc" 2>/dev/null)"
    cat "$e/out"
    exit "$rc"
fi
[ "$fresh" = 1 ] && echo "FRESH $key (the check cache bypassed once by --fresh)"
[ -n "$why" ] && echo "LIVE $key: $why -- the check runs and nothing is stored" >&2
out="$(mktemp)"; trap 'rm -f "$out"' EXIT
"$@" > "$out" 2>&1; rc=$?
cat "$out"
if [ -z "$why" ] && { [ "$rc" = 0 ] || [ "$rc" = 1 ]; }; then
    mkdir -p "$STORE/$name" 2>/dev/null && t="$(mktemp -d "$STORE/$name/.tmp.$key.XXXXXX" 2>/dev/null)" && {
        printf '%s\n' "$rc" > "$t/rc"; cp "$out" "$t/out"; date -u +%Y-%m-%dT%H:%M:%SZ > "$t/utc"; printf '%s\n' "$*" > "$t/cmd"
        if [ "$fresh" = 1 ] && [ -d "$e" ]; then rm -rf "$e.old.$$"; mv -T "$e" "$e.old.$$" 2>/dev/null; mv -T "$t" "$e" 2>/dev/null || rm -rf "$t"; rm -rf "$e.old.$$"
        else mv -T "$t" "$e" 2>/dev/null || rm -rf "$t"; fi
    }
fi
exit "$rc"
