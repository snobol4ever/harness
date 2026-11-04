#!/usr/bin/env bash
# util_oracle.sh -- THE ONE LIVE-ORACLE CALLER (ARCH-SHARED-DEVELOPMENT.md 3.4 and 6, shared-dev step 8, R-2041). Every oracle answer is a pure
# function of four things: the oracle binary, the program, the argv and the stdin. So a run takes ONE run slot (util_run_slot.sh, the box's pool),
# runs under timeout -k 5, and stores rc, stdout and stderr under /home/resources/progress/oracle/<ORACLE>/<KEY>, KEY the SHA-256 of the binary's own
# SHA, the argv (every argument naming a regular file also contributes that file's bytes, so a changed program is a new key and the seat's path is
# not part of the key: two seats asking about the same bytes share one answer), the stdin's bytes, the oracle env (S4E_ORACLE_ENV) and each --key-file.
#   util_oracle.sh ORACLE [--stdin FILE] [--timeout S] [--key-file F]... [--no-cache] -- ARGS...
#   ORACLE: sbl (the correctness SPITBOL, -bf added by the caller as always), icont, iconx, swipl, gprolog, gplc, xsb, unicon, rakudo, fpc
# It prints the oracle's stdout to stdout and its stderr to stderr and exits with the oracle's rc. NEVER CACHED: a timeout (rc 124 or 137) or a
# signal death (rc 129 to 159) under a loaded box is not the oracle's answer (R-1696: NO_ORACLE_ANSWER is re-measured, never pinned); --no-cache
# for a program whose output is a FILE it writes (a replay writes no file) or that reads a file not named in its argv and not given as --key-file.
# Every call appends one line to /home/resources/progress/oracle/LOG.tsv (utc, oracle, hit|miss|nocache, rc, seat): the census's oracle_hit count.
# rc: the oracle's own; 2 when the oracle binary is missing (lib_oracle_flags.sh's refusal, never a plausible all-FAIL) or the usage is wrong.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_oracle_flags.sh"
ORC="${1:-}"; shift || true
STDIN=/dev/null; TMO=300; NOCACHE=0; KEYF=()
while [ "$#" -gt 0 ]; do
    case "$1" in
        --stdin) STDIN="$2"; shift 2 ;;
        --timeout) TMO="$2"; shift 2 ;;
        --key-file) KEYF+=("$2"); shift 2 ;;
        --no-cache) NOCACHE=1; shift ;;
        --) shift; break ;;
        *) echo "usage: util_oracle.sh ORACLE [--stdin FILE] [--timeout S] [--key-file F]... [--no-cache] -- ARGS..." >&2; exit 2 ;;
    esac
done
case "$ORC" in
    sbl) BIN="$(sbl_correctness_bin)" || exit 2 ;;
    icont|iconx|swipl|gprolog|xsb|unicon|rakudo|fpc) BIN="$("${ORC}_bin")" || exit 2 ;;
    gplc) BIN="$(gplc_bin)" || exit 2 ;;
    *) echo "REFUSE(2): util_oracle.sh knows no oracle '$ORC' (sbl icont iconx swipl gprolog gplc xsb unicon rakudo fpc)" >&2; exit 2 ;;
esac
[ -n "$BIN" ] && [ -x "$BIN" ] || { echo "REFUSE(2): the $ORC oracle binary is missing ('$BIN')" >&2; exit 2; }
[ -r "$STDIN" ] || { echo "REFUSE(2): --stdin $STDIN is not readable" >&2; exit 2; }
ROOT=/home/resources/progress/oracle
LOGF="$ROOT/LOG.tsv"
SEAT="${S4E_SEAT:-$(basename "${S4E_HOME:-unknown}" | sed 's/^claude_//')}"
logline() { mkdir -p "$ROOT" 2>/dev/null; printf '%s\t%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$ORC" "$1" "$2" "$SEAT" >> "$LOGF" 2>/dev/null; }
key() {
    {
        printf 'oracle %s\nbin %s\n' "$ORC" "$(sha256sum < "$BIN" | cut -c1-64)"
        printf 'env %s\n' "${S4E_ORACLE_ENV:-}"
        for a in "$@"; do
            printf 'arg %s\n' "$(basename -- "$a")"
            [ -f "$a" ] && printf 'file %s\n' "$(sha256sum < "$a" | cut -c1-64)"
        done
        for f in "${KEYF[@]+"${KEYF[@]}"}"; do printf 'keyfile %s\n' "$(sha256sum < "$f" | cut -c1-64)"; done
        printf 'stdin %s\n' "$(sha256sum < "$STDIN" | cut -c1-64)"
    } | sha256sum | cut -c1-64
}
run_live() { bash "$HERE/util_run_slot.sh" timeout -k 5 "$TMO" "$BIN" "$@" < "$STDIN"; }
if [ "$NOCACHE" = 1 ]; then
    run_live "$@"; rc=$?; logline nocache "$rc"; exit "$rc"
fi
K="$(key "$@")"
D="$ROOT/$ORC/${K:0:2}/$K"
if [ -f "$D/rc" ]; then
    cat "$D/stdout"; cat "$D/stderr" >&2
    rc="$(cat "$D/rc")"; logline hit "$rc"; exit "$rc"
fi
TD="$(mktemp -d "${TMPDIR:-/tmp}/s4e-oracle.XXXXXX")" || exit 2
run_live "$@" > "$TD/stdout" 2> "$TD/stderr"; rc=$?
cat "$TD/stdout"; cat "$TD/stderr" >&2
if [ "$rc" != 124 ] && { [ "$rc" -lt 129 ] || [ "$rc" -gt 159 ]; }; then
    printf '%s\n' "$rc" > "$TD/rc"
    mkdir -p "$(dirname "$D")" 2>/dev/null && mv -T "$TD" "$D" 2>/dev/null || rm -rf "$TD"
else
    rm -rf "$TD"
fi
logline miss "$rc"
exit "$rc"
