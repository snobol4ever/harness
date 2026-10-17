#!/usr/bin/env bash
# util_parser_phase_profile.sh [lang ...] -- THE PHASE PROFILE: EACH parser.sc's PARSE CLOCK SPLIT INTO LEX, SYNTAX AND TREE BUILD
# (Lon 2026-09-30 09:2x CDT, in-chat to the ceo, verbatim: "you can loosen the fact we wish to be at par with the C versions of
# parsers, but the truth is our competition is really SPITBOL. So we want to be 2-3x times faster than SPITBOL at parsing. The lex,
# syntax, and tree build. Those three areas we must OPTIMIZE to the MAX!!!"; CEO-1367; the coo's row
# util-parser-phase-profile-lex-syntax-and-tree-build-shares-per-parser-sc-so-every-landing-names-the-phase-it-moved). A MEASUREMENT:
# it writes no row, no score cell, no progress append. The grid (util_parser_grid.sh) says HOW FAST; this says WHERE THE TIME GOES,
# so a landing names the phase it moved.
#
# THE CHAIN AND THE LIST ARE THE GRID'S: bootstrap/<chain> + parser_<lang>.sc compiled once to a mode-4 binary (a language named
# in PHASE_VIA_TRANSPILE, default raku, compiles the transpiled chain as the grid does), run over every corpus program of the
# language less each file that ends SCRIP's own run (the grid's scan, SCRIP's arm only), at the chain's declared heap and stack (bootstrap/parser_<lang>.heap, .stack -- the grid's own since CEO-1485; CRITERION CHANGED 2026-10-03, earlier profiles ran -s2000m -d8000m -i64m), SCRIP_DIAG=0,
# PARSER_TREE_HASH=1. PHASE_FILES=<n> keeps the first n files of the list (default all).
# ⛔ THE BOX IS SHARED: CALLGRIND RUNS WITH --pop-on-jump=* AND UNDER A WATCHDOG. Measured 2026-09-30 (the coo's own mistake): a
# box's jump to a function's first instruction is a CALL to callgrind, and box-to-box jumps run at one rsp, so its call stack never
# unwound -- the first full -O2 run grew callgrind to 27 GB resident on the snobol4 list and the kernel's global OOM killer took it
# (10:26:29 CDT, nothing else killed), the icon run reached 17 GB in 71 s before it was stopped; 100 snobol4 files passed 4 GB in
# 15 s where the parser itself peaks at 94 MB. --pop-on-jump=* (callgrind's: a jump out of a function is its return) holds the same
# 100 files at 143 MB with the same attribution (the plants below). The watchdog kills a run whose resident memory passes
# PHASE_MAX_RSS_MB (4096) or which outlasts PHASE_TIMEOUT (3600 s), and the language REFUSES naming which; each run's peak is kept.
# THE CLOCK ONLY: the run is made under valgrind --tool=callgrind with collection OFF at start, and a preloaded shim interposes the
# runtime's rt_time_ns (every TIME() reaches it through the PLT) and toggles collection after each reading. Each driver reads TIME()
# twice per file -- once before Init*() + Src ? Compiland + Pop() and once after -- so the profile holds exactly the instructions
# of the parse clock the grid times, and nothing of reading a file, printing a tree or starting up. The count is checked: the shim
# reports its toggles at exit and a count other than twice the files REFUSES, as does a callgrind run whose output differs from the
# plain run's (valgrind changed the program) or that did not reach PARSER-METRICS over every file.
# THE BINARY PROFILED IS THE GRID'S WITH A TRUER SYMBOL TABLE: util_parser_phase_profile.py annotate gives every run of code no sized
# function starts (every port and entry label) a sized symbol of its own before the .s is assembled -- callgrind charges an
# instruction reached by a jump anywhere but a function's start to the function that jumped -- and the .text bytes of the annotated
# build must equal the unannotated build's or the language REFUSES: the instructions are the grid's, byte for byte, the names true.
# THE SPLIT is util_parser_phase_profile.py's (its header holds the rules): the box kind of every emitted symbol, the chain file of
# every other emitted statement (from the .s's .loc lines; via transpile, from the function bodies of the transpiled chain), the
# named runtime families, and INHERITANCE up the call arcs for everything else -- the share that arrived by inheritance is printed.
# COLUMNS: files, bytes, the parse's instructions, instructions per byte, then LEX, SYNTAX, TREE BUILD, OUTSIDE (the dump, quoting,
# code generation and tracing, which the clock should never reach) and UNCLASSIFIED, each as instructions and percent of the parse,
# the inherited share, and the plain run's parse clock in ms. Under each language, the heaviest symbols of each phase in percent.
# THE BAR (the row's): the three shares plus OUTSIDE and UNCLASSIFIED cover 100 percent, UNCLASSIFIED under 10 percent per language.
# THE PLANT (PHASE_PLANT=1, the proof the attribution is live, fail-once): for the first language named, on its first
# PHASE_PLANT_FILES (40) files, the base binary against one with 16 nops planted at the entry of every match_span box (only LEX may
# move) and one with 16 nops planted at the entry of Reduce, its Reduce_α label (only TREE may move); either moving another phase is rc 1.
# THE RUNTIME MEASURED IS A CHECKOUT'S OWN, AS THE GRID'S: PHASE_ROOT=<a SCRIP checkout> (default this one) names the scrip, runtime
# and bootstrap/, refused when older than that checkout's src/; RT_OPT is read back from the linked runtime's tag, never assumed
# (the -O2 -DRT_DIAG=0 speed runtime is built by hand in a scratch worktree, as for the grid; no -O2 arm lives here, CEO-1246).
# rc 0 = every language measured and under the bar (and the plant held when asked); 1 = a language at or over 10 percent
# UNCLASSIFIED, or a plant moved the wrong phase; 2 = something could not be measured (named on its line). A heavy run: never two
# in flight (CEO-1342); PHASE_OUT=<dir> keeps the profiles, lists and maps.
set -uo pipefail
G=util_parser_phase_profile
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; SELF="$(cd "$HERE/../../SCRIP" && pwd)"
refuse() { echo "⛔ REFUSE(2) [$G]: $*"; exit 2; }
W="$(cd "${PHASE_ROOT:-$SELF}" 2>/dev/null && pwd)" || refuse "PHASE_ROOT=${PHASE_ROOT:-} is not a directory"
S4E="${S4E_HOME:-$(cd "$SELF/.." && pwd)}"; CORPUS="${CORPUS:-$S4E/corpus}"
[ -d "$CORPUS/tests" ] || refuse "no corpus at $CORPUS"
[ -x "$W/scripts/util_require_fresh.sh" ] || refuse "$W is not a SCRIP checkout (no ../harness/scripts/util_require_fresh.sh)"
"$W/scripts/util_require_fresh.sh" --gate "$G" "$W/scrip" "$W/out/libscrip_rt.so" || exit 2
PY="$HERE/util_parser_phase_profile.py"; [ -f "$PY" ] || refuse "the classifier $PY is missing"
command -v valgrind > /dev/null || refuse "no valgrind on PATH -- the profile is callgrind's"
. "$(dirname "${BASH_SOURCE[0]}")/lib_ir_measure.sh" 2> /dev/null || refuse "lib_ir_measure.sh unloadable -- the one reader of a callgrind run's status and total"
[ -f /usr/include/valgrind/callgrind.h ] || refuse "no valgrind/callgrind.h -- the shim's toggle is a callgrind client request"
B="$W/bootstrap"; CHAIN="global.sc case.sc assign.sc match.sc counter.sc stack.sc tree.sc ShiftReduce.sc tdump.sc gen.sc qize.sc semantic.sc omega.sc trace.sc"
for f in $CHAIN; do [ -f "$B/$f" ] || refuse "chain file missing: $B/$f"; done
. "$HERE/lib_declared_arena.sh" || { echo "REFUSE(2): cannot load lib_declared_arena.sh"; exit 2; }
SW=""; MAXRSS="${PHASE_MAX_RSS_MB:-4096}"; TMO="${PHASE_TIMEOUT:-3600}"; TMO1="${PHASE_ONE_TIMEOUT:-60}"; VIA=" ${PHASE_VIA_TRANSPILE-raku} "; TOPN="${PHASE_TOPN:-8}"; export SCRIP_DIAG=0
bi() { env -u RT_OPT make -s -C "$W" ${1:+"RT_OPT=$1"} buildinfo 2>/dev/null | sed -n "s/^$2 *: *//p" | sed 's/ *$//'; }
lt="$(readlink "$W/out/libscrip_rt.so" | sed -n 's/^libscrip_rt-\([0-9a-f]*\)\.so$/\1/p')"
[ -n "$lt" ] || refuse "$W/out/libscrip_rt.so names no tagged runtime -- make"
if [ "$(bi '' RT_TAG)" = "$lt" ]; then OPT="$(bi '' RT_OPT) (the checkout's default)"
elif [ -n "${RT_OPT:-}" ] && [ "$(bi "$RT_OPT" RT_TAG)" = "$lt" ]; then OPT="$RT_OPT"
else refuse "the linked runtime libscrip_rt-$lt.so was not built with the checkout's default RT_OPT (tag $(bi '' RT_TAG))${RT_OPT:+ nor with RT_OPT='$RT_OPT' (tag $(bi "$RT_OPT" RT_TAG))} -- name the RT_OPT it was built with in RT_OPT"; fi
if [ -n "${PHASE_OUT:-}" ]; then T="$PHASE_OUT"; mkdir -p "$T" || refuse "cannot create PHASE_OUT=$T"; else T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT; fi
cat > "$T/shim.c" <<'EOF'
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <valgrind/callgrind.h>
static int64_t (*real_time_ns)(void);
static long toggles;
int64_t rt_time_ns(void) {
    if (!real_time_ns) real_time_ns = (int64_t (*)(void))dlsym(RTLD_NEXT, "rt_time_ns");
    int64_t t = real_time_ns();
    CALLGRIND_TOGGLE_COLLECT;
    toggles++;
    return t;
}
__attribute__((destructor)) static void phase_toggles_report(void) { fprintf(stderr, "PHASE-TOGGLES %ld\n", toggles); }
EOF
gcc -O0 -shared -fPIC -o "$T/shim.so" "$T/shim.c" -ldl 2> "$T/shim.err" || refuse "the rt_time_ns toggle shim did not build ($(head -1 "$T/shim.err"))"
declare -A EXT=([snobol4]=sno [snocone]=sc [icon]=icn [prolog]=pl [rebus]=reb [pascal]=pas [raku]=raku)
LANGS="$*"; if [ -z "$LANGS" ]; then for L in snobol4 snocone icon prolog rebus pascal raku; do grep -q "PARSER_FILES" "$B/parser_$L.sc" 2>/dev/null && LANGS="$LANGS $L"; done; fi
[ -n "$LANGS" ] || refuse "no bootstrap/parser_<lang>.sc reads PARSER_FILES"
tree="$(git -C "$W" rev-parse --short HEAD 2>/dev/null)$(git -C "$W" diff --quiet 2>/dev/null || echo -dirty)"
echo "PHASE PROFILE [$G]: tree $tree corpus $(git -C "$CORPUS" rev-parse --short HEAD 2>/dev/null) RT_OPT=$OPT runtime libscrip_rt-$lt.so $(valgrind --version) callgrind, the parse clock only (a toggle at each rt_time_ns) switches $SW SCRIP_DIAG=0 PARSER_TREE_HASH=1 load $(cut -d' ' -f1-3 /proc/loadavg)"
printf '%-8s %5s %9s | %8s | %7s | %13s | %13s | %13s | %12s | %12s | %9s | %8s\n' lang files bytes "parse Ir" "Ir/byte" LEX SYNTAX "TREE BUILD" OUTSIDE UNCLASSIFIED inherited "clock ms"
RC=0
run() {   # $1 list, $2 output stem, $3 the binary: one plain run
    PARSER_FILES="$1" PARSER_TREE_HASH=1 timeout "${TM:-$TMO}" "${3:-$T/$L.bin}" $SW < /dev/null > "$2.out" 2> "$2.err"
}
metric() { grep '^PARSER-METRICS ' "$1" | tail -1 | grep -o " $2=[0-9]*" | cut -d= -f2; }
whole() { [ "$(metric "$1.err" files)" = "$(wc -l < "$2")" ]; }
scan() {  # each file of the population that ends SCRIP's run, named in $T/$L.gone (the grid's scan, SCRIP's arm only)
    local rest="$T/$L.rest" last culprit f; : > "$T/$L.gone"; cp "$T/$L.pop" "$rest"
    : > "$T/$L.none"; run "$T/$L.none" "$T/$L.smoke"; whole "$T/$L.smoke" "$T/$L.none" || return 1
    while [ -s "$rest" ]; do
        run "$rest" "$T/$L.scan"; whole "$T/$L.scan" "$rest" && break
        last="$(grep '^== ' "$T/$L.scan.out" | tail -1 | cut -c4-)"; culprit=""
        # ⛔ A CRASH CAN CUT THE LAST HEADER MID-WRITE (coo 2026-10-08: "== /home/claude_" on the Icon chain's segfault): a name that is
        # not a whole line of the list is no culprit, so the one-file search starts at the head of what is left instead.
        grep -qxF -- "$last" "$rest" || last=""
        while IFS= read -r f; do
            printf '%s\n' "$f" > "$T/$L.one"; TM="$TMO1" run "$T/$L.one" "$T/$L.onerun"; whole "$T/$L.onerun" "$T/$L.one" || { culprit="$f"; break; }
        done < <(awk -v x="$last" 'x == "" || $0 == x { f = 1 } f' "$rest")
        [ -n "$culprit" ] || culprit="$last"; [ -n "$culprit" ] || return 1
        echo "$culprit" >> "$T/$L.gone"
        awk -v x="$culprit" 'f; $0 == x { f = 1 }' "$rest" > "$rest.2"; mv "$rest.2" "$rest"
    done
}
build() {  # $1 the .s, $2 the binary
    gcc -m64 -no-pie -rdynamic "$1" -Wl,-rpath,"$W/out" -L"$W/out" -lscrip_rt -lm -lpthread -o "$2" 2>> "$T/$L.cc.err"
}
profile() {  # $1 list, $2 stem, $3 binary: the callgrind run of the parse clock, checked; prints why it cannot be trusted, else nothing
    local n pid rss peak=0 t0=$SECONDS killed="" vrc v; n=$(wc -l < "$1"); rm -f "$2.cg"
    PARSER_FILES="$1" PARSER_TREE_HASH=1 LD_PRELOAD="$T/shim.so" valgrind --tool=callgrind --collect-atstart=no "--pop-on-jump=*" \
        --callgrind-out-file="$2.cg" "$3" $SW < /dev/null > "$2.out" 2> "$2.err" &
    pid=$!
    while kill -0 "$pid" 2> /dev/null; do   # THE WATCHDOG: the box is shared, and callgrind's own tables are what grow
        rss=$(awk '/^VmRSS:/ { print int($2 / 1024) }' "/proc/$pid/status" 2> /dev/null); rss=${rss:-0}; [ "$rss" -gt "$peak" ] && peak=$rss
        [ "$rss" -gt "$MAXRSS" ] && { kill -9 "$pid" 2> /dev/null; killed="its resident memory passed PHASE_MAX_RSS_MB=$MAXRSS"; }
        [ $((SECONDS - t0)) -gt "$TMO" ] && { kill -9 "$pid" 2> /dev/null; killed="it outlasted PHASE_TIMEOUT=$TMO s"; }
        sleep 0.5
    done
    wait "$pid" 2> /dev/null; vrc=$?; echo "$peak" > "$2.peak"
    [ -z "$killed" ] || { echo "the callgrind run was killed: $killed (peak $peak MB)"; return; }
    v="$(ir_reading "$vrc" "$2.cg")"; ir_is_number "$v" || { echo "the callgrind reading is voided, $(ir_cell "$v"): $(ir_reason "$v")"; return; }
    [ "$(metric "$2.err" files)" = "$n" ] || { echo "the callgrind run did not reach PARSER-METRICS over all $n files"; return; }
    [ "$(sed -n 's/^PHASE-TOGGLES //p' "$2.err")" = "$((2 * n))" ] || { echo "the shim toggled $(sed -n 's/^PHASE-TOGGLES //p' "$2.err") times, not twice per file ($((2 * n))) -- the region is not the clock"; return; }
    cmp -s <(grep -v '^PARSER-METRICS' "$2.out") <(grep -v '^PARSER-METRICS' "$T/$L.plain.out") || { echo "the callgrind run printed other trees than the plain run"; return; }
    [ -s "$2.cg" ] || echo "no callgrind profile was written"
}
pct() { awk -v a="$1" -v t="$2" 'BEGIN { if (t > 0) printf "%.1f", 100 * a / t; else printf "-" }'; }
cell() { awk -v a="$1" -v t="$2" 'BEGIN { if (t <= 0) { printf "-"; exit } u = a; s = ""; if (a >= 1e9) { u = a / 1e9; s = "G" } else if (a >= 1e6) { u = a / 1e6; s = "M" } else if (a >= 1e3) { u = a / 1e3; s = "K" }; printf "%.2f%s %5.1f%%", u, s, 100 * a / t }'; }
phase() { awk -v p="$2" '$1 == "PHASE" && $2 == p { print $3 }' "$1"; }
PLANTED=""
for L in $LANGS; do
    ext="${EXT[$L]:-}"; [ -n "$ext" ] || { echo "$L ⛔ REFUSE(2): not a parser language (${!EXT[*]})"; RC=2; continue; }
    SW="$(declared_switches_beside "$B/parser_$L.sc")" && [ -n "$SW" ] || { echo "$L ⛔ REFUSE(2): bootstrap/parser_$L.sc declares no heap or stack, or the declaration is refused"; RC=2; continue; }
    grep -q "PARSER_FILES" "$B/parser_$L.sc" 2>/dev/null || { echo "$L ⛔ REFUSE(2): bootstrap/parser_$L.sc reads no PARSER_FILES list"; RC=2; continue; }
    : > "$T/$L.sc"; : > "$T/$L.map"; n=0
    for f in $CHAIN parser_$L.sc; do k=$(wc -l < "$B/$f"); echo "range $f $((n + 1)) $((n + k))" >> "$T/$L.map"; n=$((n + k)); cat "$B/$f" >> "$T/$L.sc"; done
    echo "lang parser_$L.sc" >> "$T/$L.map"
    "$W/scrip" --transpile "$T/$L.sc" > "$T/$L.sno" 2> "$T/$L.tr.err" && [ -s "$T/$L.sno" ] || { echo "$L ⛔ REFUSE(2): scrip --transpile of the chain failed"; RC=2; continue; }
    src="$T/$L.sc"; via=""
    case "$VIA" in *" $L "*)
        src="$T/$L.sno"; via=" (via transpile)"; : > "$T/$L.map"
        for f in $CHAIN parser_$L.sc; do   # a function body of the transpiled chain runs from its label to <name>_end
            for fn in $(sed -n 's/^[[:space:]]*function[[:space:]]\{1,\}\([A-Za-z_][A-Za-z0-9_]*\).*/\1/p' "$B/$f"); do
                awk -v fn="$fn" -v f="$f" '$1 == fn && lo == "" { lo = NR } $1 == fn "_end" && lo != "" { print "range", f, lo, NR; exit }' "$T/$L.sno" >> "$T/$L.map"
            done
        done
        echo "lang parser_$L.sc" >> "$T/$L.map" ;;
    esac
    for f in $CHAIN parser_$L.sc; do sed -n 's/^[[:space:]]*function[[:space:]]\{1,\}\([A-Za-z_][A-Za-z0-9_]*\).*/func \1 '"$f"'/p' "$B/$f"; done >> "$T/$L.map"
    "$W/scrip" --compile "$src" -o "$T/$L.raw.s" < /dev/null > "$T/$L.cc.err" 2>&1 && python3 "$PY" annotate "$T/$L.raw.s" "$T/$L.s" > "$T/$L.ann" 2>> "$T/$L.cc.err" && build "$T/$L.s" "$T/$L.bin" \
        || { echo "$L ⛔ REFUSE(2): the ${via:+transpiled }chain did not compile or link to a mode-4 binary ($(head -1 "$T/$L.cc.err" | cut -c1-100))"; RC=2; continue; }
    grep -q '^[[:space:]]*\.loc[[:space:]]' "$T/$L.s" || { echo "$L ⛔ REFUSE(2): the mode-4 .s carries no .loc line, so no emitted statement can be placed in its chain file"; RC=2; continue; }
    build "$T/$L.raw.s" "$T/$L.raw.bin" && objcopy -O binary --only-section=.text "$T/$L.raw.bin" "$T/$L.raw.text" && objcopy -O binary --only-section=.text "$T/$L.bin" "$T/$L.text" \
        || { echo "$L ⛔ REFUSE(2): could not extract the .text bytes of the unannotated and annotated builds"; RC=2; continue; }
    cmp -s "$T/$L.raw.text" "$T/$L.text" || { echo "$L ⛔ REFUSE(2): the annotated .s assembled to other instructions than the unannotated one -- annotate may touch the symbol table only"; RC=2; continue; }
    find "$CORPUS" -type f -name "*.$ext" -not -name 'ALL.*' -not -path '*/.git/*' -not -path "$CORPUS/library/*" | sort > "$T/$L.pop"
    np=$(wc -l < "$T/$L.pop"); [ "$np" -gt 0 ] || { echo "$L ⛔ REFUSE(2): no corpus program ends in .$ext"; RC=2; continue; }
    scan || { echo "$L ⛔ REFUSE(2): SCRIP dies before its first file"; RC=2; continue; }
    grep -vxF -f "$T/$L.gone" "$T/$L.pop" > "$T/$L.all"
    # ⛔ THE LIST IS FILES THE PARSER ACCEPTS (coo 2026-10-08): a file the parser refuses prints Parse Error, and one refused BEFORE its
    # clock (parser_icon.sc returns from ParseOne on a preprocessor error ahead of pf_a = TIME()) reads TIME() no times, so the shim's
    # toggle count fell short of twice the files and the language REFUSED (Icon 76 of 80: the two family_icon.icn copies, $import).
    # Each plain run's refused files leave the list, named in $T/$L.refused, and the list is refilled from the population.
    : > "$T/$L.refused"; okl=1
    for _pass in 1 2 3 4 5 6; do
        grep -vxF -f "$T/$L.refused" "$T/$L.all" > "$T/$L.acc"
        if [ -n "${PHASE_FILES:-}" ]; then head -n "$PHASE_FILES" "$T/$L.acc" > "$T/$L.list"; else cp "$T/$L.acc" "$T/$L.list"; fi
        nf=$(wc -l < "$T/$L.list"); [ "$nf" -gt 0 ] || break
        run "$T/$L.list" "$T/$L.plain"; whole "$T/$L.plain" "$T/$L.list" || { okl=0; break; }
        awk '/^== / { f = substr($0, 4); next } $0 == "Parse Error" && f != "" { print f; f = "" }' "$T/$L.plain.out" > "$T/$L.newref"
        [ -s "$T/$L.newref" ] || break
        cat "$T/$L.newref" >> "$T/$L.refused"; okl=2
    done
    nf=$(wc -l < "$T/$L.list"); [ "$nf" -gt 0 ] || { echo "$L ⛔ REFUSE(2): every file ends SCRIP's run or is refused by the parser"; RC=2; continue; }
    [ "$okl" = 0 ] && { echo "$L ⛔ REFUSE(2): the plain run did not reach PARSER-METRICS over all $nf files"; RC=2; continue; }
    [ -s "$T/$L.newref" ] && { echo "$L ⛔ REFUSE(2): the parser still refuses files of the list after six refills"; RC=2; continue; }
    why="$(profile "$T/$L.list" "$T/$L.prof" "$T/$L.bin")"; [ -z "$why" ] || { echo "$L ⛔ REFUSE(2): $why"; RC=2; continue; }
    python3 "$PY" report "$T/$L.prof.cg" "$T/$L.s" "$T/$L.map" "$L.bin" "$TOPN" > "$T/$L.phases" 2> "$T/$L.py.err" || { echo "$L ⛔ REFUSE(2): the classifier failed ($(tail -1 "$T/$L.py.err"))"; RC=2; continue; }
    tot=$(awk '$1 == "TOTAL" { print $2 }' "$T/$L.phases"); [ "${tot:-0}" -gt 0 ] || { echo "$L ⛔ REFUSE(2): the profile holds no instruction of the parse"; RC=2; continue; }
    inh=$(awk '$1 == "PHASE" { s += $4 } END { print s + 0 }' "$T/$L.phases"); un=$(phase "$T/$L.phases" UNCLASSIFIED); by=$(metric "$T/$L.plain.err" bytes)
    printf '%-8s %5s %9s | %8s | %7s | %13s | %13s | %13s | %12s | %12s | %9s | %8s\n' "$L" "$nf" "$by" "$(cell "$tot" "$tot" | cut -d' ' -f1)" \
        "$(awk -v t="$tot" -v b="$by" 'BEGIN { if (b > 0) printf "%.0f", t / b; else printf "-" }')" \
        "$(cell "$(phase "$T/$L.phases" LEX)" "$tot")" "$(cell "$(phase "$T/$L.phases" SYNTAX)" "$tot")" "$(cell "$(phase "$T/$L.phases" TREE)" "$tot")" \
        "$(cell "$(phase "$T/$L.phases" OUTSIDE)" "$tot")" "$(cell "$un" "$tot")" "$(pct "$inh" "$tot")%" \
        "$(awk -v u="$(metric "$T/$L.plain.err" parse_us)" 'BEGIN { printf "%.1f", u / 1000 }')"
    for p in LEX SYNTAX TREE OUTSIDE UNCLASSIFIED; do
        top="$(awk -v p="$p" '$1 == "PHASE" && $2 == p { $1 = $2 = $3 = $4 = ""; sub(/^ +/, ""); print }' "$T/$L.phases")"
        [ -n "$top" ] && echo "   $L $p: $top"
    done
    echo "   $L list: $nf of $np corpus programs$via; dropped because the file ended SCRIP's run: $(wc -l < "$T/$L.gone"); refused by the parser (Parse Error): $(wc -l < "$T/$L.refused")${PHASE_FILES:+ (PHASE_FILES=$PHASE_FILES kept)}; callgrind peak $(cat "$T/$L.prof.peak") MB"
    awk -v u="$un" -v t="$tot" 'BEGIN { exit !(u * 10 >= t) }' && { echo "   $L ⛔ OVER THE BAR: UNCLASSIFIED $(pct "$un" "$tot")% >= 10%"; [ "$RC" = 2 ] || RC=1; }
    if [ "${PHASE_PLANT:-}" = 1 ] && [ -z "$PLANTED" ] && [ -z "$via" ]; then
        PLANTED=1; head -n "${PHASE_PLANT_FILES:-40}" "$T/$L.list" > "$T/$L.plist"; run "$T/$L.plist" "$T/$L.plain"
        NOPS='nop; nop; nop; nop; nop; nop; nop; nop; nop; nop; nop; nop; nop; nop; nop; nop'
        why="$(profile "$T/$L.plist" "$T/$L.pbase" "$T/$L.bin")"
        if [ -n "$why" ]; then echo "   $L ⛔ PLANT REFUSE(2): base: $why"; RC=2
        else
            python3 "$PY" report "$T/$L.pbase.cg" "$T/$L.s" "$T/$L.map" "$L.bin" 1 > "$T/$L.pbase.phases"
            for spec in "LEX:^n[0-9]+_match_span_α:" "TREE:^Reduce_α:"; do
                ph="${spec%%:*}"; rx="${spec#*:}"; k=$(grep -cE "$rx" "$T/$L.s")
                [ "$k" -gt 0 ] || { echo "   $L ⛔ PLANT REFUSE(2): no label in the .s matches $rx"; RC=2; continue; }
                sed -E "/$rx/a\\
                        $NOPS" "$T/$L.s" > "$T/$L.plant$ph.s"
                build "$T/$L.plant$ph.s" "$T/$L.plant$ph.bin" || { echo "   $L ⛔ PLANT REFUSE(2): the $ph-planted .s did not assemble"; RC=2; continue; }
                why="$(profile "$T/$L.plist" "$T/$L.pplant$ph" "$T/$L.plant$ph.bin")"; [ -z "$why" ] || { echo "   $L ⛔ PLANT REFUSE(2): $ph: $why"; RC=2; continue; }
                python3 "$PY" report "$T/$L.pplant$ph.cg" "$T/$L.plant$ph.s" "$T/$L.map" "$L.plant$ph.bin" 1 > "$T/$L.pplant$ph.phases"
                out="$(python3 "$PY" compare "$T/$L.pbase.phases" "$T/$L.pplant$ph.phases" "$ph")"; prc=$?
                echo "   $L $out ($k labels, $(wc -l < "$T/$L.plist") files)"; [ "$prc" = 0 ] || { [ "$RC" = 2 ] || RC=1; }
            done
        fi
    fi
done
[ "${PHASE_PLANT:-}" = 1 ] && [ -z "$PLANTED" ] && { echo "⛔ REFUSE(2) [$G]: PHASE_PLANT=1 but no language compiled directly was measured"; RC=2; }
echo "BAR [$G]: LEX + SYNTAX + TREE BUILD + OUTSIDE + UNCLASSIFIED = the parse's instructions; UNCLASSIFIED under 10 percent per language; rc $RC; load at end $(cut -d' ' -f1-3 /proc/loadavg)${PHASE_OUT:+; profiles, lists and maps kept under $PHASE_OUT}"
exit $RC
