#!/usr/bin/env bash
# util_parser_ab.sh LANG OLD NEW [RUNS] -- a C parser before and after a change, graded on the whole corpus of LANG.
# IDENTITY: every corpus program (*.<ext> outside .git and corpus/library, not ALL.*) is parsed ALONE by both standalone parser
# binaries (out/parser_<lang> built by make parsers, saved before the change as OLD) with the tree dump on (PARSER_TREE_HASH=0);
# stdout, stderr less the PARSER-METRICS line, and the exit status must agree file for file.  Every differing file is named.
# CLOCK: both binaries then time the list of files neither one crashed on, hash on, median of RUNS (3), with the driver's lexer
# clock on (PARSER_LEX_CLOCK=1); the line prints parse and lex microseconds for each and the bare multiple OLD/NEW on both, with
# the load stamped (CEO-743).  rc 0 every file identical, 1 a file differs, 2 could not measure.
set -u
L="${1:-}"; OLD="${2:-}"; NEW="${3:-}"; RUNS="${4:-3}"
here=$(cd "$(dirname "$0")" && pwd); W=$(cd "$here/../../SCRIP" && pwd); CORPUS=$(cd "$W/../corpus" 2>/dev/null && pwd)
declare -A EXT=([snobol4]=sno [snocone]=sc [icon]=icn [prolog]=pl [rebus]=reb [pascal]=pas [raku]=raku)
ext="${EXT[$L]:-}"; [ -n "$ext" ] || { echo "PARSER-AB ⛔ REFUSE(2): not a parser language '$L' (${!EXT[*]})"; exit 2; }
[ -n "$CORPUS" ] && [ -d "$CORPUS" ] || { echo "PARSER-AB ⛔ REFUSE(2): no corpus beside $W"; exit 2; }
[ -n "$OLD" ] && [ -x "$OLD" ] && [ -n "$NEW" ] && [ -x "$NEW" ] || { echo "PARSER-AB ⛔ REFUSE(2): OLD and NEW must both be executable parser binaries"; exit 2; }
OLD=$(readlink -f "$OLD"); NEW=$(readlink -f "$NEW")
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
find "$CORPUS" -type f -name "*.$ext" -not -name 'ALL.*' -not -path '*/.git/*' -not -path "$CORPUS/library/*" | sort > "$T/pop"
np=$(wc -l < "$T/pop"); [ "$np" -gt 0 ] || { echo "PARSER-AB ⛔ REFUSE(2): no corpus program ends in .$ext"; exit 2; }
one() { printf '%s\n' "$2" > "$T/one"; ( cd "$CORPUS" && PARSER_FILES="$T/one" PARSER_TREE_HASH=0 timeout -k 5 60 "$1" < /dev/null > "$3.out" 2> "$3.err" ); rc=$?; echo "rc=$rc" >> "$3.out"; grep -v '^PARSER-METRICS ' "$3.err" >> "$3.out"; return $rc; }
ni=0; nd=0; diffs=""; : > "$T/timed"
while IFS= read -r f; do
    one "$OLD" "$f" "$T/o"; ro=$?; one "$NEW" "$f" "$T/n"; rn=$?
    if cmp -s "$T/o.out" "$T/n.out"; then ni=$((ni + 1)); else nd=$((nd + 1)); diffs="$diffs"$'\n'"  ${f#$CORPUS/} (rc old=$ro new=$rn)"; fi
    [ "$ro" -le 1 ] && [ "$rn" -le 1 ] && printf '%s\n' "$f" >> "$T/timed"
done < "$T/pop"
nt=$(wc -l < "$T/timed")
metric() { grep '^PARSER-METRICS ' "$1" | tail -1 | grep -o " $2=[0-9]*" | cut -d= -f2; }
med() { printf '%s\n' "$@" | sort -n | sed -n "$(( ($# + 1) / 2 ))p"; }
timed() { ( cd "$CORPUS" && PARSER_FILES="$T/timed" PARSER_TREE_HASH=1 PARSER_LEX_CLOCK=1 timeout -k 5 600 "$1" < /dev/null > /dev/null 2> "$2" ); }
po=(); pn=(); lo=(); ln=(); short=""
for k in $(seq "$RUNS"); do
    timed "$OLD" "$T/to.err"; timed "$NEW" "$T/tn.err"
    a=$(metric "$T/to.err" parse_us); b=$(metric "$T/tn.err" parse_us); c=$(metric "$T/to.err" lex_us); d=$(metric "$T/tn.err" lex_us)
    [ -n "$a" ] && [ -n "$b" ] && [ -n "$c" ] && [ -n "$d" ] || { short=" | A TIMED RUN DID NOT REACH PARSER-METRICS"; break; }
    po+=("$a"); pn+=("$b"); lo+=("$c"); ln+=("$d")
done
x() { awk -v r="$1" -v s="$2" 'BEGIN { if (r == "" || s == "" || s == 0) printf "-"; else printf "%.2fx", r / s }'; }
if [ -z "$short" ]; then P0=$(med "${po[@]}"); P1=$(med "${pn[@]}"); L0=$(med "${lo[@]}"); L1=$(med "${ln[@]}"); else P0=""; P1=""; L0=""; L1=""; fi
echo "PARSER-AB lang=$L population=$np identical=$ni differing=$nd timed=$nt runs=$RUNS old_parse_us=${P0:--} new_parse_us=${P1:--} OLD/NEW=$(x "$P0" "$P1") old_lex_us=${L0:--} new_lex_us=${L1:--} OLD/NEW=$(x "$L0" "$L1") load=$(cut -d' ' -f1-3 /proc/loadavg)$short"
[ "$nd" -eq 0 ] || { echo "DIFFERING:$diffs" | head -60; exit 1; }
[ -z "$short" ] || exit 2
exit 0
