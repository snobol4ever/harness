#!/usr/bin/env bash
# util_parser_grid.sh [lang ...] -- THE PARSER GRID: THE STAND-ALONE C PARSER, SCRIP AND SPITBOL ON THE PARSE CLOCK, ONE FILE LIST
# FOR ALL THREE (Lon 2026-09-29, in-chat to the ceo, verbatim: "The goal is parser.sc same as C and 2x faster than SPITBOL." and "We
# want focus on accuracy and speed of parser.sc as prep for replacing all SCRIP parsers."; MODE QUARTET, CEO-1364; the coo's row
# parser-sc-speed-grid-c-scrip-spitbol-on-the-parse-clock-lon-2026-09-29-ceo-1364, committed from the ceo's scratch pcmp.sh, which
# is .github/wip-patches/pcmp-parsers-vs-clean-sbl-2026-09-29.sh). A MEASUREMENT: it writes no row, no score cell, no progress append.
#
# THE BAR (the row's): SCRIP's parse clock equal to C's (C/SCRIP >= 1.00) and SPITBOL/SCRIP >= 2.00 on every parser.
#
# LANGUAGES: the arguments, else every bootstrap/parser_<lang>.sc whose driver reads PARSER_FILES (six today; Raku joins by itself
# when the rewritten parser_raku.sc prints trees through that driver). A language named whose driver does not read the list REFUSES.
# THE FILE LIST, ONE FOR ALL THREE ENGINES, DERIVED HERE AND PRINTED WITH ITS COUNT: every corpus program of the language (the tree
# gate's corpus population: *.<ext> outside .git and corpus/library, not ALL.*), less each file that ENDS an engine's run before
# its PARSER-METRICS line. Each engine scans the WHOLE population on its own, so its count is independent of the others' (a file
# that kills two engines is counted under both) and the list is the population less the union. Measured on 2026-09-29: the C Icon parser exits the process on a link it cannot open, and SPITBOL stops on
# a run-time error in the parser program (field function argument is wrong datatype) -- either way every later file goes unparsed.
# Each engine runs the list; when a run dies, the files from the last "== <file>" it printed are run ALONE until one dies alone,
# that file leaves the list and the scan resumes after it (a buffered engine can die past the last header it flushed; a file that
# dies only in company leaves as the last one begun). The count each engine dropped is printed beside the list; GRID_OUT keeps names.
# A list run is bounded by GRID_TIMEOUT (600 s) and a file run alone by GRID_ONE_TIMEOUT (60 s); a file that outlasts either leaves.
# THE THREE ENGINES, each reading PARSER_FILES=<list> and printing "== <file>" then the file's tree, and one line
# PARSER-METRICS files= bytes= parse_first_us= parse_us= whose parse_us is the clock:
#   C      out/parser_<lang> (src/tools/parser_main.c): times only its parser -- no lowering, no I/O; a link or include is resolved
#          outside the clock (IPATH names the corpus's IPL procs, since the parser looks beside its own binary, which is out/).
#   SCRIP  the bootstrap chain + bootstrap/parser_<lang>.sc compiled ONCE to a mode-4 binary; the driver times only Init*() +
#          Src ? Compiland + Pop() -- reading a file and printing its tree are outside the clock.
#   SBL    sbl_clean_bin -bf (the clean benchmark oracle, never the monitor-hooked x64 fork: GOAL-SNOCONE-100 cursor 29k) running
#          scrip --transpile of the same chain; the same driver, the same clock. TIME() reads nanoseconds in both, measured.
#   SCRIP runs at the chain's declared heap and stack (bootstrap/parser_<lang>.heap, .stack) and SBL at its declared switches
#   (bootstrap/parser_<lang>.oracle_args), each over its own shipped defaults, read by lib_declared_arena.sh (ceo CEO-1485, RULES.md
#   clause 8 (g)(4): the window is never typed). CRITERION CHANGED 2026-10-03: every reading before ran BOTH at -s2000m -d8000m -i64m,
#   one equal arena with a 64 MB initial window; the header line says so beside every reading from here on. SCRIP_DIAG=0 for the
#   compile and every run. The median of GRID_RUNS (3) runs.
#   VIA TRANSPILE: a language named in GRID_VIA_TRANSPILE (default: raku) has its SCRIP binary compiled from the same transpiled
#   chain SPITBOL runs, through the SNOBOL4 frontend, and its row says "via transpile" -- the ceo's order of 2026-09-29 19:4x
#   (da1b3a85a's rewritten parser_raku.sc hangs on a second statement when the chain is compiled directly as .sc, a Snocone-frontend
#   defect; the default drops raku the day the ceo telegrams the cure). Raku's C clock is rk_parse_tree: parse and tree, as the .sc's.
# COLUMNS: files, bytes, C ms, SCRIP ms, SBL ms, SBL/SCRIP, C/SCRIP, trees -- every run is made under PARSER_TREE_HASH=1, so each
# engine prints ONE NUMBER per file in place of its tree (125bb54e6, the cfo's: the dump's bytes folded in memory, h = (h * 256 +
# byte) mod (2^55 - 55), outside every parse clock), and each file's number from SCRIP is compared with the same file's from
# SPITBOL: SCRIP==SBL when every file agrees, else DIFFER n/N, how many and never how (Lon 2026-09-29: "It shows only how many do
# not match, not in what ay do they not match."; the details come from the full dump of a mismatching file). THE CANARY: the first
# file that printed a number is dumped in full by SCRIP and by SPITBOL, and each number must be an independent fold of its own
# dump, so a hash that stopped folding REFUSES rc=2 instead of reading SCRIP==SBL (the tree gate's canary, the same fold).
# THE HASH-OFF CONTROL (the ceo's ruling of 2026-09-29 20:4x CDT, on its measurement at 20:38: PARSER_TREE_HASH=1 read SCRIP's
# Snocone parse_us 58 -> 83 ms on the 2536a296c runtime although the fold runs outside the clock; 59 -> 60 at 8c610af38; C and
# SPITBOL not inflated): after the timed runs SCRIP runs the list once more with PARSER_TREE_HASH=0, printing its trees in full, and
# that clock is printed beside the hash-on median; a hash-on clock more than ten percent off it either way is named on the
# language's row as HASH GAP. The trees still compare by hash, and the hash-on median stays the grid's SCRIP column.
# THE RUNTIME MEASURED IS A CHECKOUT'S OWN: GRID_ROOT=<a SCRIP checkout> (default: this one) names the scrip, out/libscrip_rt.so,
# out/parser_<lang> and bootstrap/ measured, each refused when older than that checkout's src/. RT_OPT IS READ BACK, NEVER ASSUMED:
# the linked runtime's tag (Makefile: RT_TAG, an md5 of RT_OPT|ZCFLAGS) against the tag of the checkout's default RT_OPT and, when
# it differs, against the tag of the RT_OPT this run was handed in its environment; neither agreeing REFUSES rc=2, because a number
# without its RT_OPT is unlabelled (RULES.md INSTRUMENT LAWS). THE SPEED RUNTIME (-O2 -DRT_DIAG=0, Lon 2026-09-29) IS BUILT BY HAND
# IN A SCRATCH WORKTREE and read here beside the -O0 default: GRID_ROOT=<worktree> RT_OPT='<its RT_OPT>' util_parser_grid.sh.
# No -O2 arm lives in this file (RULES.md NO -O2 BUILDS, CEO-1246: the -O2 build is a by-hand instrument; the grid only reads it).
# rc 0 = every language measured; rc 2 = something could not be measured (named on its line). Never two heavy runs in flight
# (CEO-1342): the whole grid is one heavy run and prints the load at its start and end.
set -uo pipefail
G=util_parser_grid
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; SELF="$(cd "$HERE/../../SCRIP" && pwd)"
refuse() { echo "⛔ REFUSE(2) [$G]: $*"; exit 2; }
W="$(cd "${GRID_ROOT:-$SELF}" 2>/dev/null && pwd)" || refuse "GRID_ROOT=${GRID_ROOT:-} is not a directory"
S4E="${S4E_HOME:-$(cd "$SELF/.." && pwd)}"; CORPUS="${CORPUS:-$S4E/corpus}"
[ -d "$CORPUS/tests" ] || refuse "no corpus at $CORPUS"
[ -x "$W/scripts/util_require_fresh.sh" ] || refuse "$W is not a SCRIP checkout (no ../harness/scripts/util_require_fresh.sh)"
"$W/scripts/util_require_fresh.sh" --gate "$G" "$W/scrip" "$W/out/libscrip_rt.so" || exit 2
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || refuse "cannot load lib_oracle_flags.sh -- the ONE oracle-path authority"
SBL="$(sbl_clean_bin)" || refuse "no clean benchmark oracle (sbl_clean_bin)"
B="$W/bootstrap"; CHAIN="$B/global.sc $B/case.sc $B/assign.sc $B/match.sc $B/counter.sc $B/stack.sc $B/tree.sc $B/ShiftReduce.sc $B/tdump.sc $B/gen.sc $B/qize.sc $B/semantic.sc $B/omega.sc $B/trace.sc"
for f in $CHAIN; do [ -f "$f" ] || refuse "chain file missing: $f"; done
. "$HERE/lib_declared_arena.sh" || refuse "cannot load lib_declared_arena.sh -- the one reader of a declared size"
SWS=""; SWB=""; RUNS="${GRID_RUNS:-3}"; TMO="${GRID_TIMEOUT:-600}"; TMO1="${GRID_ONE_TIMEOUT:-60}"; VIA=" ${GRID_VIA_TRANSPILE-raku} "; export SCRIP_DIAG=0
case "$RUNS" in ''|*[!0-9]*|0) refuse "GRID_RUNS=$RUNS is not a positive count" ;; esac
bi() { env -u RT_OPT make -s -C "$W" ${1:+"RT_OPT=$1"} buildinfo 2>/dev/null | sed -n "s/^$2 *: *//p" | sed 's/ *$//'; }
lt="$(readlink "$W/out/libscrip_rt.so" | sed -n 's/^libscrip_rt-\([0-9a-f]*\)\.so$/\1/p')"
[ -n "$lt" ] || refuse "$W/out/libscrip_rt.so names no tagged runtime -- make"
if [ "$(bi '' RT_TAG)" = "$lt" ]; then OPT="$(bi '' RT_OPT) (the checkout's default)"
elif [ -n "${RT_OPT:-}" ] && [ "$(bi "$RT_OPT" RT_TAG)" = "$lt" ]; then OPT="$RT_OPT"
else refuse "the linked runtime libscrip_rt-$lt.so was not built with the checkout's default RT_OPT (tag $(bi '' RT_TAG))${RT_OPT:+ nor with RT_OPT='$RT_OPT' (tag $(bi "$RT_OPT" RT_TAG))} -- name the RT_OPT it was built with in RT_OPT"; fi
if [ -n "${GRID_OUT:-}" ]; then T="$GRID_OUT"; mkdir -p "$T" || refuse "cannot create GRID_OUT=$T"; else T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT; fi
declare -A EXT=([snobol4]=sno [snocone]=sc [icon]=icn [prolog]=pl [rebus]=reb [pascal]=pas [raku]=raku)
LANGS="$*"; if [ -z "$LANGS" ]; then for L in snobol4 snocone icon prolog rebus pascal raku; do grep -q "PARSER_FILES" "$B/parser_$L.sc" 2>/dev/null && LANGS="$LANGS $L"; done; fi
[ -n "$LANGS" ] || refuse "no bootstrap/parser_<lang>.sc reads PARSER_FILES"
tree="$(git -C "$W" rev-parse --short HEAD 2>/dev/null)$(git -C "$W" diff --quiet 2>/dev/null || echo -dirty)"
echo "PARSER GRID [$G]: tree $tree corpus $(git -C "$CORPUS" rev-parse --short HEAD 2>/dev/null) RT_OPT=$OPT runtime libscrip_rt-$lt.so sbl $(sbl_oracle_fingerprint "$SBL" | cut -d' ' -f1-2) sizes: each chain's declaration (CRITERION CHANGED 2026-10-03, CEO-1485 -- earlier grids ran both engines at -s2000m -d8000m -i64m) SCRIP_DIAG=0 median of $RUNS load $(cut -d' ' -f1-3 /proc/loadavg)"
printf '%-8s %5s %9s | %9s | %9s | %9s | %9s | %7s | %s\n' lang files bytes "C ms" "SCRIP ms" "SBL ms" "SBL/SCRIP" "C/SCRIP" trees
RC=0; NL=0; NC=0; N2=0
run() {   # $1 engine, $2 list, $3 output stem: one run of that engine over the list
    case "$1" in
    C)     ( cd "$CORPUS" && PARSER_FILES="$2" PARSER_TREE_HASH="${H:-1}" IPATH="$CORPUS/packages/icon/ipl/procs" timeout "${TM:-$TMO}" "$W/out/parser_$L" < /dev/null > "$3.out" 2> "$3.err" ) ;;
    SCRIP) PARSER_FILES="$2" PARSER_TREE_HASH="${H:-1}" timeout "${TM:-$TMO}" "$T/$L.bin" $SWS < /dev/null > "$3.out" 2> "$3.err" ;;
    SBL)   PARSER_FILES="$2" PARSER_TREE_HASH="${H:-1}" timeout "${TM:-$TMO}" "$SBL" -bf $SWB "$T/$L.sno" < /dev/null > "$3.out" 2> "$3.err" ;;
    esac
}
section() { awk -v x="$2" '/^== / { f = (substr($0, 4) == x); next } f' "$1"; }   # the lines an output printed for file $2
fold() { python3 -c 'import sys
h = 0
for c in sys.stdin.buffer.read(): h = (h * 256 + c) % (2**55 - 55)
print(h)'; }
canary() {   # prints LIVE, or why the numbers cannot be trusted
    local f e n; f="$(awk '/^== / { nm = substr($0, 4); next } nm != "" && /^[0-9]+$/ { print nm; exit }' "$T/$L.SCRIP.out")"
    [ -n "$f" ] || { echo "no file of the list printed a tree number"; return; }
    printf '%s\n' "$f" > "$T/$L.one"
    for e in SCRIP SBL; do
        n="$(section "$T/$L.$e.out" "$f")"; H=0 run "$e" "$T/$L.one" "$T/$L.canary"
        [ "$(section "$T/$L.canary.out" "$f" | fold)" = "$n" ] || { echo "$e printed $n for ${f#$CORPUS/}, not the fold of its own dump"; return; }
    done
    echo LIVE
}
metric() { grep '^PARSER-METRICS ' "$1" | tail -1 | grep -o " $2=[0-9]*" | cut -d= -f2; }
whole() { [ "$(metric "$1.err" files)" = "$(wc -l < "$2")" ]; }   # the run reached its PARSER-METRICS line over every file of the list
scan() {  # $1 engine: each file of the population that ends the engine's run, named in $T/$L.gone.$1
    local e="$1" rest="$T/$L.rest" last culprit f; : > "$T/$L.gone.$e"; cp "$T/$L.pop" "$rest"
    : > "$T/$L.none"; run "$e" "$T/$L.none" "$T/$L.smoke"; whole "$T/$L.smoke" "$T/$L.none" || return 1
    while [ -s "$rest" ]; do
        run "$e" "$rest" "$T/$L.scan"; whole "$T/$L.scan" "$rest" && break
        last="$(grep '^== ' "$T/$L.scan.out" | tail -1 | cut -c4-)"; culprit=""
        while IFS= read -r f; do
            printf '%s\n' "$f" > "$T/$L.one"; TM="$TMO1" run "$e" "$T/$L.one" "$T/$L.onerun"; whole "$T/$L.onerun" "$T/$L.one" || { culprit="$f"; break; }
        done < <(awk -v x="$last" 'x == "" || $0 == x { f = 1 } f' "$rest")
        [ -n "$culprit" ] || culprit="$last"; [ -n "$culprit" ] || return 1
        echo "$culprit" >> "$T/$L.gone.$e"
        awk -v x="$culprit" 'f; $0 == x { f = 1 }' "$rest" > "$rest.2"; mv "$rest.2" "$rest"
    done
}
med() { printf '%s\n' "$@" | sort -n | sed -n "$(( ($# + 1) / 2 ))p"; }
ms() { awk -v u="$1" 'BEGIN { if (u == "") printf "-"; else printf "%.1f", u / 1000 }'; }
x() { awk -v r="$1" -v s="$2" 'BEGIN { if (r == "" || s == "" || s == 0) printf "-"; else printf "%.2fx", r / s }'; }
for L in $LANGS; do
    ext="${EXT[$L]:-}"; [ -n "$ext" ] || { echo "$L ⛔ REFUSE(2): not a parser language (${!EXT[*]})"; RC=2; continue; }
    grep -q "PARSER_FILES" "$B/parser_$L.sc" 2>/dev/null || { echo "$L ⛔ REFUSE(2): bootstrap/parser_$L.sc reads no PARSER_FILES list"; RC=2; continue; }
    ( . "$HERE/lib_build_currency.sh" && assert_parser_current "$L" "$W" ) || { echo "$L ⛔ REFUSE(2): out/parser_$L missing or older than a source it was compiled from (named above) -- make parsers"; RC=2; continue; }
    SWS="$(declared_switches_beside "$B/parser_$L.sc")" && [ -n "$SWS" ] && SWB="$(declared_oracle_args_beside "$B/parser_$L.sc")" || { echo "$L ⛔ REFUSE(2): bootstrap/parser_$L's declared sizes are missing or refused"; RC=2; continue; }
    echo "  sizes[$L]: SCRIP $SWS | SBL ${SWB:-its defaults}"
    cat $CHAIN "$B/parser_$L.sc" > "$T/$L.sc"
    "$W/scrip" --transpile "$T/$L.sc" > "$T/$L.sno" 2> "$T/$L.tr.err" && [ -s "$T/$L.sno" ] || { echo "$L ⛔ REFUSE(2): scrip --transpile of the chain failed"; RC=2; continue; }
    src="$T/$L.sc"; via=""; case "$VIA" in *" $L "*) src="$T/$L.sno"; via=" | via transpile" ;; esac
    "$W/scrip" --compile "$src" -o "$T/$L.s" < /dev/null > "$T/$L.cc.err" 2>&1 && gcc -m64 -no-pie -rdynamic "$T/$L.s" -Wl,-rpath,"$W/out" -L"$W/out" -lscrip_rt -lm -lpthread -o "$T/$L.bin" 2>> "$T/$L.cc.err" \
        || { echo "$L ⛔ REFUSE(2): the ${via:+transpiled }chain did not compile or link to a mode-4 binary ($(head -1 "$T/$L.cc.err" | cut -c1-100))"; RC=2; continue; }
    sbl_clean_refuse_if_load "$T/$L.sno" > /dev/null || { echo "$L ⛔ REFUSE(2): the transpiled chain calls LOAD(), unverified on the clean oracle"; RC=2; continue; }
    find "$CORPUS" -type f -name "*.$ext" -not -name 'ALL.*' -not -path '*/.git/*' -not -path "$CORPUS/library/*" | sort > "$T/$L.pop"
    np=$(wc -l < "$T/$L.pop"); [ "$np" -gt 0 ] || { echo "$L ⛔ REFUSE(2): no corpus program ends in .$ext"; RC=2; continue; }
    bad=""; for e in C SCRIP SBL; do scan "$e" || { bad="$e"; break; }; done
    [ -z "$bad" ] || { echo "$L ⛔ REFUSE(2): $bad dies before its first file (an empty list does not reach PARSER-METRICS; see $bad's stderr under GRID_OUT)"; RC=2; continue; }
    sort -u "$T/$L.gone.C" "$T/$L.gone.SCRIP" "$T/$L.gone.SBL" > "$T/$L.gone"; grep -vxF -f "$T/$L.gone" "$T/$L.pop" > "$T/$L.list"
    nf=$(wc -l < "$T/$L.list"); [ "$nf" -gt 0 ] || { echo "$L ⛔ REFUSE(2): every file ends some engine's run"; RC=2; continue; }
    tc=(); ts=(); tb=(); short=""
    for k in $(seq "$RUNS"); do
        for e in C SCRIP SBL; do run "$e" "$T/$L.list" "$T/$L.$e"; whole "$T/$L.$e" "$T/$L.list" || short="$short $e"; done
        tc+=($(metric "$T/$L.C.err" parse_us)); ts+=($(metric "$T/$L.SCRIP.err" parse_us)); tb+=($(metric "$T/$L.SBL.err" parse_us))
    done
    [ -z "$short" ] || { echo "$L ⛔ REFUSE(2): a timed run did not reach PARSER-METRICS over all $nf files:$short"; RC=2; continue; }
    c=$(med "${tc[@]}"); s=$(med "${ts[@]}"); b=$(med "${tb[@]}")
    H=0 run SCRIP "$T/$L.list" "$T/$L.SCRIPoff"; so=""; whole "$T/$L.SCRIPoff" "$T/$L.list" && so=$(metric "$T/$L.SCRIPoff.err" parse_us)
    gap=$(awk -v s="$s" -v o="$so" 'BEGIN { if (o == "" || o == 0) print " | HASH-OFF RUN SHORT"; else if (s / o > 1.10 || s / o < 0.90) printf " | HASH GAP %+.0f%% (hash-off %.1f ms)", (s / o - 1) * 100, o / 1000 }')
    k="$(canary)"; [ "$k" = LIVE ] || { echo "$L ⛔ REFUSE(2): the tree-hash canary: $k"; RC=2; continue; }
    nd=$(awk 'FNR == 1 { k++ } /^== / { nm = substr($0, 4); if (k == 1) a[nm] = ""; else b[nm] = ""; next } k == 1 { a[nm] = a[nm] $0 "\n"; next } { b[nm] = b[nm] $0 "\n" }
              END { for (n in a) if (!(n in b) || a[n] != b[n]) d++; for (n in b) if (!(n in a)) d++; print d + 0 }' "$T/$L.SCRIP.out" "$T/$L.SBL.out")
    t=SCRIP==SBL; [ "$nd" = 0 ] || t="DIFFER $nd/$nf"
    printf '%-8s %5s %9s | %9s | %9s | %9s | %9s | %7s | %s\n' "$L" "$nf" "$(metric "$T/$L.SCRIP.err" bytes)" "$(ms "$c")" "$(ms "$s")" "$(ms "$b")" "$(x "$b" "$s")" "$(x "$c" "$s")" "$t$via$gap"
    echo "   $L list: $nf of $np corpus programs; dropped because the file ended or outlasted the run -- C $(wc -l < "$T/$L.gone.C"), SCRIP $(wc -l < "$T/$L.gone.SCRIP"), SBL $(wc -l < "$T/$L.gone.SBL") (each engine over all $np); runs C ${tc[*]} SCRIP ${ts[*]} SBL ${tb[*]} us; SCRIP hash-off ${so:--} us${via:+; SCRIP compiled the transpiled chain}$([ "$L" = raku ] && echo "; the C clock is rk_parse_tree, parse and tree, as the .sc driver's")"
    NL=$((NL + 1)); awk -v c="$c" -v s="$s" 'BEGIN { exit !(s > 0 && c / s >= 1.0) }' && NC=$((NC + 1)); awk -v b="$b" -v s="$s" 'BEGIN { exit !(s > 0 && b / s >= 2.0) }' && N2=$((N2 + 1))
done
echo "BAR [$G]: $NC of $NL parsers at C's parse clock (C/SCRIP >= 1.00), $N2 of $NL at SPITBOL/SCRIP >= 2.00; load at end $(cut -d' ' -f1-3 /proc/loadavg)${GRID_OUT:+; lists, dropped names and dumps kept under $GRID_OUT}"
exit $RC
