#!/usr/bin/env bash
export SCRIP_DIAG=0
# bench_parser_ir_slope.sh <lang> -- THE PARSER GRID ON INSTRUCTIONS: THE STAND-ALONE C PARSER AND THE .sc PARSER CHAIN, Ir PER BYTE OF SOURCE.
# (Lon 2026-10-21 17:4x CDT, in-chat to the ceo, CEO-1871, verbatim: "I want it to work on parser.sc programs completeness and speed performance
# versus the SCRIP C parsers."; row snocone-parser-sc-every-bootstrap-parser-at-the-c-parsers-parse-clock-ceo-1871.) util_parser_grid.sh reads the
# CLOCK and refuses under load (perf_load_guard); callgrind Ir is load-immune, so this steers the speed work on a busy box and the grid's clock
# reading stays the DONE-WHEN. NOT A WALL-CLOCK PREDICTOR (Ir cannot see cache misses or stalls): it answers "how many instructions does the parse do".
#
# THE METHOD (bench_ir_slope.sh's regression, with the files of one language as the size ladder). The corpus population (the grid's: *.<ext> outside
# .git and library/, not ALL.*) is sorted; three NESTED prefixes of it reach B, 2B and 4B bytes (PIS_BYTES, default 60000); each engine runs each prefix
# under callgrind and the straight line Ir(bytes) = OVERHEAD + bytes * WORK is fitted -- startup, table builds and the .so load cancel EXACTLY in the
# slope. The two interval slopes (B,2B) and (2B,4B) are printed beside the headline (B,4B): files differ in style, so a spread past PIS_LIN_TOL percent
# is named NONLINEAR (rc 1) and the headline is read with that caveat.
# WHAT IS COUNTED -- THE GRID'S CLOCK, NOT THE PROCESS: parse_us times Init*() + Src ? Compiland + Pop() in the .sc and the language's *_compile_parse in C;
# the tree dump / hash fold, the file read and the printing are outside it. So
#   C   = the INCLUSIVE Ir of the C parse entry point (callgrind_annotate --inclusive=yes; PARSE_FN below), the dump and startup excluded;
#   SC  = the whole process of the chain compiled to a mode-4 binary from a SCRATCH copy of the chain whose TreeDump is `return;` (the .sc's dump
#         is inlined Byrd-box code, recursive in callgrind's eyes, so its inclusive cost cannot be read -- 2 million percent; the variant is how the
#         dump leaves the count). Only the scratch copy changes: bootstrap/ is never edited (NEVER REWRITE A parser_*.sc). What stays in SC beyond the parse:
#         INPUT/SIZE per file and one OUTPUT line per file, small and linear in the file count.
#   THE POPULATION IS GRADED FILE BY FILE BEFORE ANY Ir RUN: each file of the sorted corpus population is read ALONE and NATIVELY by both engines
#   (PARSER_TREE_HASH=1, SNO_LIB=corpus/include:corpus/library plus the file's own directory for the chain) and joins the ladder only when both print the SAME tree number; a file either engine refuses, dies on, outlasts
#   PIS_ONE_TIMEOUT (20 s) or prints a different tree for is DROPPED -- not a speed question, the tree gate's -- and the header counts the drops by class
#   (the grid's rule). PIS_TREES=0 relaxes "the same tree" to "both print a tree" (Raku, whose C parser still prints desugared forms: speed alone, said in
#   the header). Examination stops once the accepted bytes reach 4B; a population that ends sooner shrinks the ladder to total/4, total/2, total, said too.
#   PIS_EXCLUDE=<file of paths> drops more files up front.
# THE MULTIPLE is C Ir per byte over SC Ir per byte, a bare x (lib_perf_fmt.sh): 1.00x is the bar of the row, above it SCRIP does less work than C.
# PIS_FULL=1 adds the whole-process Ir of both with the dump (C with PARSER_TREE_HASH=1, SC from the unmodified chain) as a second block.
# EXIT: 0 measured; 1 a line read NONLINEAR; 2 could not measure (named). RT_OPT is read back from the build, never assumed; no -O2 (RULES.md).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; W="$HERE/../../SCRIP"; CORPUS="${CORPUS:-$HERE/../../corpus}"; G=bench_parser_ir_slope
refuse() { echo "⛔ PARSER Ir SLOPE REFUSED (rc=2) [$G]: $*" >&2; exit 2; }
L="${1:-snocone}"; BYTES="${PIS_BYTES:-60000}"; TOL="${PIS_LIN_TOL:-10}"; TMO="${PIS_IR_TIMEOUT:-1800}"; FULL="${PIS_FULL:-0}"; TMO1="${PIS_ONE_TIMEOUT:-20}"; TREES="${PIS_TREES:-1}"
SNO_LIB_BASE="${SNO_LIB:-$CORPUS/include:$CORPUS/library}"
declare -A EXT=([snobol4]=sno [snocone]=sc [icon]=icn [prolog]=pl [rebus]=reb [pascal]=pas [raku]=raku)
declare -A PARSE_FN=([snobol4]="sno_reset sno_parse_ast_buf" [snocone]=snocone_compile_parse [icon]=icon_compile_parse [prolog]=prolog_compile_parse [rebus]=rebus_compile_parse [pascal]=pascal_compile_parse [raku]=raku_compile_whole)
ext="${EXT[$L]:-}"; [ -n "$ext" ] || refuse "'$L' is not a parser language (${!EXT[*]})"
case "$BYTES" in ''|*[!0-9]*|0) refuse "PIS_BYTES=$BYTES is not a positive byte count" ;; esac
command -v valgrind >/dev/null 2>&1 || refuse "valgrind not on PATH"
[ -x "$W/scrip" ] && [ -x "$W/out/parser_$L" ] || refuse "no $W/scrip or $W/out/parser_$L -- make; make parsers"
"$HERE/util_require_fresh.sh" --gate "$G" "$W/scrip" "$W/out/libscrip_rt.so" || exit 2
. "$HERE/lib_ir_measure.sh" 2>/dev/null || refuse "cannot load lib_ir_measure.sh (the ONE Ir authority)"
PERF_STAMP_OFF=1; . "$HERE/lib_perf_fmt.sh" 2>/dev/null || refuse "cannot load lib_perf_fmt.sh (the ONE multiple authority)"
. "$HERE/lib_declared_arena.sh" 2>/dev/null || refuse "cannot load lib_declared_arena.sh"
B="$W/bootstrap"; P="$B/parser_$L.sc"; [ -f "$P" ] || refuse "no $P"
grep -q PARSER_FILES "$P" || refuse "$P reads no PARSER_FILES list"
SWS="$(declared_switches_beside "$P")" && [ -n "$SWS" ] || refuse "$P's declared sizes are missing or refused"
CHAIN="global case assign match counter stack tree ShiftReduce tdump gen qize semantic omega trace"
T="$(mktemp -d "${TMPDIR:-/tmp}/pis.XXXXXX")" || refuse "cannot make a work dir"; trap 'rm -rf "$T"' EXIT
build() {   # $1 = stem, $2 = 0|1 (1: TreeDump becomes `return;`): the chain + parser compiled to a mode-4 binary $T/$1.bin
    local f c="" tdump="$B/tdump.sc"
    if [ "$2" = 1 ]; then
        tdump="$T/tdump_nodump.sc"
        python3 -I - "$B/tdump.sc" "$tdump" <<'PY' || return 1
import sys
s = open(sys.argv[1], encoding='utf-8').read()
a = "function TreeDump(x, outNm) {\n    outNm = IDENT(outNm) .OUTPUT;\n    TreeDumpAt(x, 0, outNm);\n    return;\n}\n"
if s.count(a) != 1: sys.exit("tdump.sc: the TreeDump definition is not the expected text")
open(sys.argv[2], 'w', encoding='utf-8').write(s.replace(a, "function TreeDump(x, outNm) {\n    return;\n}\n"))
PY
    fi
    for f in $CHAIN; do if [ "$f" = tdump ]; then c="$c $tdump"; else c="$c $B/$f.sc"; fi; done
    cat $c "$P" > "$T/$1.sc" && "$W/scrip" --compile "$T/$1.sc" -o "$T/$1.s" < /dev/null > "$T/$1.cc.err" 2>&1 &&
        gcc -m64 -no-pie -rdynamic "$T/$1.s" -Wl,-rpath,"$W/out" -L"$W/out" -lscrip_rt -lm -lpthread -o "$T/$1.bin" 2>> "$T/$1.cc.err"
}
build full 0 || refuse "the $L chain did not compile or link ($(head -1 "$T/full.cc.err" | cut -c1-120))"
build nodump 1 || refuse "the $L chain with TreeDump returning did not compile or link ($(head -1 "$T/nodump.cc.err" | cut -c1-120))"
find "$CORPUS" -type f -name "*.$ext" -not -name 'ALL.*' -not -path '*/.git/*' -not -path "$CORPUS/library/*" | LC_ALL=C sort > "$T/pop"
[ -z "${PIS_EXCLUDE:-}" ] || { [ -f "$PIS_EXCLUDE" ] || refuse "PIS_EXCLUDE=$PIS_EXCLUDE is not a file"; grep -vxF -f "$PIS_EXCLUDE" "$T/pop" > "$T/pop.2"; mv "$T/pop.2" "$T/pop"; }
[ -s "$T/pop" ] || refuse "no corpus program ends in .$ext"
metric() { grep '^PARSER-METRICS ' "$1" | tail -1 | grep -o " $2=[0-9]*" | cut -d= -f2; }
one() {   # $1 engine (c|s), $2 file: the file's tree number, or REFUSED (no number printed), DIED (no PARSER-METRICS) or TIMEOUT
    local e="$1" f="$2" rc out; printf '%s\n' "$f" > "$T/one"
    if [ "$e" = c ]; then
        out="$(timeout -k 2 "$TMO1" bash -c 'cd "$1" && PARSER_FILES="$2" PARSER_TREE_HASH=1 IPATH="$1/packages/icon/ipl/procs" exec "$3"' _ "$CORPUS" "$T/one" "$W/out/parser_$L" < /dev/null 2> "$T/one.err")"; rc=$?
    else out="$(cd "$(dirname "$f")" && SNO_LIB="$(sclib "$T/one")" PARSER_FILES="$T/one" PARSER_TREE_HASH=1 timeout -k 2 "$TMO1" "$T/full.bin" $SWS < /dev/null 2> "$T/one.err")"; rc=$?; fi
    [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ] && { echo TIMEOUT; return; }
    [ "$(metric "$T/one.err" files)" = 1 ] || { echo DIED; return; }
    out="$(printf '%s\n' "$out" | awk '/^== / { next } NF { print; exit }')"
    case "$out" in ''|*[!0-9]*) echo REFUSED ;; *) echo "$out" ;; esac
}
sclib() {   # $1 = a list file: SNO_LIB for the chain over it -- the corpus include dirs plus each listed file's own directory (the C parser finds an -INCLUDE beside the including file, the chain looks in cwd and SNO_LIB)
    printf '%s:%s' "$SNO_LIB_BASE" "$(xargs -d '\n' -n1 dirname < "$1" | sort -u | paste -sd:)"
}
isnum() { case "$1" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }
pick() {   # $1 = base bytes: the three nested prefixes of the accepted files as "k1 k2 k3" -- the first file reaching 1*, 2*, 4* the base, each strictly after the last; fails when there are none
    awk -v b="$1" '{ cumb[NR] = $1 } END { split("1 2 4", m, " "); i = 0
        for (j = 1; j <= 3; j++) { i++; while (i <= NR && cumb[i] < m[j] * b) i++; if (i > NR) exit 1; k[j] = i }
        print k[1], k[2], k[3] }' "$T/cum"
}
: > "$T/acc"; : > "$T/cum"; : > "$T/drops"; : > "$T/accc"; : > "$T/accs"; ACC=0; EXAM=0; TARGET=$((BYTES * 4))
while IFS= read -r f; do
    [ "$ACC" -ge "$TARGET" ] && pick "$BYTES" > /dev/null && break
    EXAM=$((EXAM + 1)); cr="$(one c "$f")"; sr="$(one s "$f")"; ok=0
    if isnum "$cr" && isnum "$sr"; then if [ "$TREES" = 0 ] || [ "$cr" = "$sr" ]; then ok=1; else cls="trees-differ"; fi
    else cls="C-$(isnum "$cr" && echo tree || echo "$cr")/SC-$(isnum "$sr" && echo tree || echo "$sr")"; fi
    if [ "$ok" = 1 ]; then ACC=$((ACC + $(stat -c %s "$f"))); echo "$f" >> "$T/acc"; echo "$ACC" >> "$T/cum"; echo "$cr" >> "$T/accc"; echo "$sr" >> "$T/accs"; else echo "$cls $f" >> "$T/drops"; fi
done < "$T/pop"
NACC=$(wc -l < "$T/acc"); [ -z "${PIS_DROPS:-}" ] || cp "$T/drops" "$PIS_DROPS"
DROPCLS="$(awk '{ c[$1]++ } END { for (k in c) printf " %s=%d", k, c[k]; if (!length(c)) printf " none" }' "$T/drops")"
[ "$NACC" -ge 3 ] || refuse "only $NACC of the $EXAM $L files examined parse in both engines$([ "$TREES" = 1 ] && echo " to the same tree") -- too few for a ladder (the tree gate's question, or PIS_TREES=0)"
SHRUNK=""; BASE="$BYTES"; if [ "$ACC" -lt "$TARGET" ]; then BASE=$((ACC / 4)); SHRUNK=" (population ended: ladder shrunk to total/4, total/2, total of $ACC bytes)"; fi
[ "$BASE" -gt 0 ] || refuse "the accepted $L files total $ACC bytes -- no ladder"
# $T/l1 $T/l2 $T/l3 are the nested lists of the three prefixes, $T/b holds file and byte counts of each
read -r k1 k2 k3 < <(pick "$BASE") || refuse "the $NACC accepted $L files cannot make three distinct nested prefixes at $BASE/$((BASE * 2))/$((BASE * 4)) bytes ($EXAM examined, drops:$DROPCLS); lower PIS_BYTES"
: > "$T/b"; n=0; for k in $k1 $k2 $k3; do n=$((n + 1)); head -n "$k" "$T/acc" > "$T/l$n"; echo "$k $(sed -n "${k}p" "$T/cum")" >> "$T/b"; done
read -r K1 B1 < <(sed -n 1p "$T/b"); read -r K2 B2 < <(sed -n 2p "$T/b"); read -r K3 B3 < <(sed -n 3p "$T/b")
runs() { SNO_LIB="$(sclib "$1")" PARSER_FILES="$1" PARSER_TREE_HASH="${2:-1}" "$T/${3:-full}.bin" $SWS < /dev/null; }
listrun_agrees() {   # $1 engine (c|s): the engine's native run over the whole ladder list prints, file by file, the number its single-file run printed
    local out
    if [ "$1" = c ]; then out="$(cd "$CORPUS" && PARSER_FILES="$T/l3" PARSER_TREE_HASH=1 IPATH="$CORPUS/packages/icon/ipl/procs" "$W/out/parser_$L" < /dev/null 2> /dev/null)"
    else out="$(runs "$T/l3" 1 full 2> /dev/null)"; fi
    [ "$(printf '%s\n' "$out" | awk '/^== / { next } NF { print }')" = "$(head -n "$K3" "$T/acc$1")" ]
}
listrun_agrees c || refuse "out/parser_$L over the $K3-file ladder list prints other tree numbers than its single-file runs did: it carries state from one file to the next (the rebus C parser does: the second file of a list reads a syntax error it does not read alone), so a list-run Ir is not the parse of these files"
listrun_agrees s || refuse "the $L chain over the $K3-file ladder list prints other tree numbers than its single-file runs did: it carries state from one file to the next"
runs "$T/l3" 1 nodump > "$T/n.out" 2> "$T/n.err"; [ "$(metric "$T/n.err" files)" = "$K3" ] && ! grep -q 'Parse Error' "$T/n.out" || refuse "the dump-less chain did not parse all $K3 files of the ladder"
incl() {   # $1 callgrind file, $2.. function names: the summed INCLUSIVE Ir of the entry points, or nothing
    local cg="$1"; shift; callgrind_annotate --inclusive=yes --threshold=100 "$cg" 2> /dev/null | awk -v fns="$*" 'BEGIN { n = split(fns, f, " ") }
        { for (i = 1; i <= n; i++) if (!(f[i] in got) && index($0, ":" f[i] " [") > 0) { v = $1; gsub(/,/, "", v); got[f[i]] = v; s += v } }
        END { if (length(got) == n) print s }'
}
ir_of() {  # $1 engine (c|full|nodump) $2 list $3 out-name $4 fn... -> parse Ir (inclusive of fns for c) or whole Ir, voiding dead runs
    local e="$1" lst="$2" cg="$T/$3.cg" v; shift 3
    export PARSER_FILES="$lst" PARSER_TREE_HASH=1 IPATH="$CORPUS/packages/icon/ipl/procs"
    if [ "$e" = c ]; then v="$(cd "$CORPUS" && IR_TMO="$TMO" IR_OUT="$cg" ir_measure "$W/out/parser_$L" < /dev/null)"
    else v="$(SNO_LIB="$(sclib "$lst")" IR_TMO="$TMO" IR_OUT="$cg" ir_measure "$T/$e.bin" $SWS < /dev/null)"; fi
    ir_is_number "$v" || { echo "⚠ Ir arm voided: $(ir_cell "$v") -- $(ir_reason "$v")" >&2; return 0; }
    if [ $# -gt 0 ]; then incl "$cg" "$@"; else echo "$v"; fi
}
fit() {  # a b c (Ir at B1 B2 B3) -> "headline_slope intercept slope12 slope23 spread% lin"
    awk -v a="$1" -v b="$2" -v c="$3" -v b1="$B1" -v b2="$B2" -v b3="$B3" -v tol="$TOL" 'BEGIN {
        s12 = (b - a) / (b2 - b1); s23 = (c - b) / (b3 - b2); h = (c - a) / (b3 - b1)
        if (s12 <= 0 || s23 <= 0 || h <= 0) { print "0 0 0 0 0 NONLINEAR"; exit }
        d = (s12 > s23 ? (s12 - s23) / s23 : (s23 - s12) / s12) * 100
        printf "%.1f %d %.1f %.1f %.1f %s", h, a - b1 * h, s12, s23, d, (d <= tol ? "ok" : "NONLINEAR") }'
}
RC=0; declare -A ROW
rowdo() {  # $1 label $2 engine $3.. fns
    local lab="$1" e="$2" a b c; shift 2
    a="$(ir_of "$e" "$T/l1" "$lab.1" "$@")"; b="$(ir_of "$e" "$T/l2" "$lab.2" "$@")"; c="$(ir_of "$e" "$T/l3" "$lab.3" "$@")"
    if [ -z "$a" ] || [ -z "$b" ] || [ -z "$c" ]; then ROW[$lab]="UNPROVEN"; RC=2; printf '%-22s %14s %14s %14s  UNPROVEN\n' "$lab" "${a:--}" "${b:--}" "${c:--}"; return; fi
    ROW[$lab]="$(fit "$a" "$b" "$c")"; read -r h o s12 s23 d l <<< "${ROW[$lab]}"
    printf '%-22s %14s %14s %14s %12s %12s %10s %6s%%  %s\n' "$lab" "$a" "$b" "$c" "$h" "$o" "$s12/$s23" "$d" "$l"
    [ "$l" = ok ] || { [ "$RC" -ne 0 ] || RC=1; }
}
TREE="$(git -C "$W" rev-parse --short HEAD 2>/dev/null)$(git -C "$W" diff --quiet 2>/dev/null || echo -dirty)"
OPT="$(env -u RT_OPT make -s -C "$W" buildinfo 2>/dev/null | sed -n 's/^RT_OPT *: *//p' | sed 's/ *$//')"
echo "PARSER_IR_SLOPE lang=$L tree=SCRIP $TREE corpus $(git -C "$CORPUS" rev-parse --short HEAD 2>/dev/null) RT_OPT=${OPT:-unread} instrument=callgrind-Ir-regression date=$(date -u +%Y-%m-%d)"
echo "  basis: Ir(bytes) = OVERHEAD + bytes*WORK over three nested prefixes of the accepted files of the $(wc -l < "$T/pop")-file corpus population: $K1 files $B1 bytes, $K2 files $B2 bytes, $K3 files $B3 bytes$SHRUNK; WORK (Ir per byte) is the headline slope, startup cancels exactly"
echo "  C = inclusive Ir of ${PARSE_FN[$L]} in out/parser_$L; SC = the .sc chain, mode 4, sizes $SWS, TreeDump returning (scratch copy)"
echo "  population: $EXAM files examined alone and natively, $NACC accepted ($([ "$TREES" = 1 ] && echo "both engines print the SAME tree number" || echo "both print a tree; TREES NOT COMPARED (PIS_TREES=0), speed alone")), $(wc -l < "$T/drops") dropped:$DROPCLS"
echo "  load is not a factor for Ir (stamp for the record: $(cut -d' ' -f1-3 /proc/loadavg))"
printf '%-22s %14s %14s %14s %12s %12s %10s %7s  %s\n' row "Ir@$B1" "Ir@$B2" "Ir@$B3" "WORK/byte" "OVERHEAD" "slopes" "spread" lin
rowdo "$L-C-parse" c ${PARSE_FN[$L]}
rowdo "$L-SC-parse" nodump
if [ "$FULL" = 1 ]; then rowdo "$L-C-whole+dump" c; rowdo "$L-SC-whole+dump" full; fi
cw="$(echo "${ROW[$L-C-parse]:-}" | cut -d' ' -f1)"; sw="$(echo "${ROW[$L-SC-parse]:-}" | cut -d' ' -f1)"
if [ -n "$cw" ] && [ -n "$sw" ] && [ "$cw" != 0 ] && [ "$sw" != 0 ] && [ "${ROW[$L-C-parse]}" != UNPROVEN ] && [ "${ROW[$L-SC-parse]}" != UNPROVEN ]; then
    echo "RESULT lang=$L C/SCRIP parse Ir per byte = $(perf_mult "$cw" "$sw") (C $cw Ir/byte, SCRIP $sw Ir/byte; the row's bar is >= 1.00x; Ir, not the clock)"
else echo "RESULT lang=$L UNPROVEN (an arm was voided or read non-linear to nothing)"; [ "$RC" -ne 0 ] || RC=2; fi
exit $RC
