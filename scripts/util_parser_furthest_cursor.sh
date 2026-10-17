#!/usr/bin/env bash
# util_parser_furthest_cursor.sh -- WHERE does a self-hosted parser stop? (hq_snocone 2026-09-27, the instrument that took
# parser_pascal.sc from 167 to 514 of 586 and parser_icon.sc from 867 to 1686 of 1708 on the SPITBOL arm in one sitting)
#
#   bash ../harness/scripts/util_parser_furthest_cursor.sh <lang> <source> [<source>...]   [--engine sbl|scrip] [--rebuild] [--timeout S]
#
# For each source it prints ONE line:  <source> TAB PARSED | TIMEOUT | CRASH | <line>:<col> TAB <that line> TAB <text at the cursor>
# where line:col is the FURTHEST point the parser's blank-skipping rule (Gray, the $' ' name) was ever evaluated at -- with
# a backtracking parser that is where the first construct it cannot take begins, or the token right after it.
# METHOD: the 14-file bootstrap chain + bootstrap/parser_<lang>.sc are transpiled once (scrip --transpile) to a twin .sno in
# which Gray = ((White | epsilon) @FARC *FarSet()) records the maximum cursor and the driver prints "Parse Error at N"; the
# twin runs on the engine named (default: sbl -bf, the correctness oracle, so the answer is the PARSER's, never SCRIP's;
# --engine scrip runs the same .sno on ./scrip, the m3 arm, for a SCRIP-arm refusal). N is mapped to line:col here after
# trimming each line's trailing blanks, because SPITBOL's INPUT trims them. The twin is cached under the scratch dir named
# by $SCRATCH (default /tmp/parser_furthest_cursor.<uid>) and rebuilt with --rebuild or when the parser is newer.
# rc: 0 every source PARSED, 1 some did not, 2 could not measure (no binary, no oracle, no parser, transpile failed).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP_ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
lang=""; engine=sbl; rebuild=0; tmo=60; srcs=()
while [ $# -gt 0 ]; do
    case "$1" in
        --engine) engine="$2"; shift 2 ;;
        --rebuild) rebuild=1; shift ;;
        --timeout) tmo="$2"; shift 2 ;;
        -*) echo "REFUSE unknown option $1" >&2; exit 2 ;;
        *) if [ -z "$lang" ]; then lang="$1"; else srcs+=("$1"); fi; shift ;;
    esac
done
[ -n "$lang" ] && [ ${#srcs[@]} -gt 0 ] || { echo "usage: $0 <lang> <source>... [--engine sbl|scrip] [--rebuild] [--timeout S]" >&2; exit 2; }
parser="$SCRIP_ROOT/bootstrap/parser_$lang.sc"
[ -f "$parser" ] || { echo "REFUSE no parser: $parser" >&2; exit 2; }
[ -x "$SCRIP_ROOT/scrip" ] || { echo "REFUSE no ./scrip (make first)" >&2; exit 2; }
SBL="${SBL:-$(type -t sbl_correctness_bin >/dev/null 2>&1 && sbl_correctness_bin || echo /home/resources/x64/bin/sbl)}"
if [ "$engine" = sbl ]; then [ -x "$SBL" ] || { echo "REFUSE no SPITBOL oracle at $SBL" >&2; exit 2; }; fi
# Both engines run the twin at the CHAIN's declared sizes (ceo CEO-1353, RULES.md clause 8 (g)(3)-(4)), never typed here: scrip at
# bootstrap/parser_<lang>.heap and .stack, sbl at bootstrap/parser_<lang>.oracle_args, read by lib_declared_arena.sh.
. "$HERE/lib_declared_arena.sh" || { echo "REFUSE cannot load lib_declared_arena.sh" >&2; exit 2; }
SW="$(declared_switches_beside "$parser")" || exit 2
[ -n "$SW" ] || { echo "REFUSE $parser declares no heap or stack (bootstrap/parser_$lang.heap, .stack)" >&2; exit 2; }
OARGS="$(declared_oracle_args_beside "$parser")" || exit 2
SCRATCH="${SCRATCH:-/tmp/parser_furthest_cursor.$(id -u)}"; mkdir -p "$SCRATCH"
twin="$SCRATCH/parser_${lang}_furthest.sno"
chain=""; for f in global case assign match counter stack tree ShiftReduce tdump gen qize semantic omega trace; do chain="$chain $SCRIP_ROOT/bootstrap/$f.sc"; done
if [ $rebuild = 1 ] || [ ! -s "$twin" ] || [ "$parser" -nt "$twin" ] || [ "$SCRIP_ROOT/bootstrap/global.sc" -nt "$twin" ]; then
    plain="$SCRATCH/parser_${lang}_plain.sno"
    "$SCRIP_ROOT/scrip" --transpile $chain "$parser" > "$plain" 2> "$SCRATCH/transpile.err" < /dev/null || { echo "REFUSE transpile failed:" >&2; head -3 "$SCRATCH/transpile.err" >&2; exit 2; }
    python3 - "$plain" "$twin" <<'PY' || exit 2
import sys
src=open(sys.argv[1]).read()
import re
m=re.findall(r'^\tGray = (.*)$', src, re.M)
if len(m)!=1: print("REFUSE the transpiled parser has no unique Gray rule to hook", file=sys.stderr); sys.exit(2)
src=src.replace('\tGray = '+m[0]+'\n','\tGray = ('+m[0]+' @FARC *FarSet())\n')
b="\tInitCounter()\n"
if src.count(b)!=1: print("REFUSE the transpiled driver has no unique InitCounter() call to hook", file=sys.stderr); sys.exit(2)
src=src.replace(b,"\tDEFINE('FarSet()')\t:(FarSet_end)\nFarSet\t(FAR = GT(FARC,FAR) FARC)\n\t:(RETURN)\nFarSet_end\n\t(FAR = 0)\n"+b)
cs=["OUTPUT = 'Parse Error.'", "OUTPUT = 'Parse Error'"]
if not any(src.count(c) for c in cs): print("REFUSE the transpiled driver prints no Parse Error", file=sys.stderr); sys.exit(2)
for c in cs: src=src.replace(c,"OUTPUT = 'Parse Error at ' FAR")
open(sys.argv[2],'w').write(src)
PY
fi
rc=0
for f in "${srcs[@]}"; do
    [ -f "$f" ] || { printf '%s\tREFUSE no such file\n' "$f"; rc=2; continue; }
    if [ "$engine" = sbl ]; then out=$(timeout -k 5 "$tmo" "$SBL" -bf $OARGS "$twin" < "$f" 2>&1); r=$?
    else out=$(timeout -k 5 "$tmo" "$SCRIP_ROOT/scrip" $SW "$twin" < "$f" 2>&1); r=$?; fi
    if [ $r = 124 ]; then printf '%s\tTIMEOUT\n' "$f"; rc=1; continue; fi
    far=$(printf '%s\n' "$out" | grep -o 'Parse Error at [0-9]*' | head -1 | grep -o '[0-9]*$')
    if [ -z "$far" ]; then
        if printf '%s\n' "$out" | grep -q '^('; then printf '%s\tPARSED\n' "$f"; else printf '%s\tCRASH rc=%s %s\n' "$f" "$r" "$(printf '%s\n' "$out" | head -1 | cut -c1-100)"; rc=1; fi
        continue
    fi
    rc=1
    python3 - "$f" "$far" <<'PY'
import sys
f,far=sys.argv[1],int(sys.argv[2])
s='\n'.join(l.rstrip(' \t\r') for l in open(f,encoding='latin-1').read().split('\n'))
ln=s[:far].count('\n')+1; col=far-(s[:far].rfind('\n')+1)
lines=s.split('\n'); txt=lines[ln-1] if ln-1 < len(lines) else ''
print(f"{f}\t{ln}:{col}\t{txt.strip()[:120]}\t{txt[col:col+60].strip()}")
PY
done
exit $rc
