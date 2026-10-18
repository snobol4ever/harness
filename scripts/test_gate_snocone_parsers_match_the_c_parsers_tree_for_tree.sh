#!/usr/bin/env bash
# test_gate_snocone_parsers_match_the_c_parsers_tree_for_tree.sh -- THE SELF-HOSTED PARSERS PRINT THE SAME TREE AS SCRIP'S OWN
# PARSERS, FILE BY FILE (Lon 2026-09-27, in-chat to hq_snocone, verbatim: "Write a C function to dump the AST. Write an
# equivalent Snocone function to dump the tree. ... Get the trees to match 100%."; and 2026-09-28: "So change from concat one big
# file to run each parser seperatly."; ceo CEO-1340, the row's DONE-WHEN).
#
# THE INSTRUMENT: out/parser_<lang> (src/tools/parser_main.c, one frontend per build, printing through ir_dump_tree in
# src/ir/ast_print.c) and the .sc chain + bootstrap/parser_<lang>.sc printing through TreeDump in bootstrap/tdump.sc -- ONE
# FORMAT, byte for byte: one node per line, two spaces per depth, "(TT_KIND value" then the children then ")"; strings quoted with
# the CQize escapes, integers decimal, reals as %g; the five bookkeeping attributes :line :lline :file :stno :src are printed by
# NEITHER side (the one named exclusion, the same list in both dumpers). Each .sc parser reads its whole input in ONE read (Lon
# 2026-09-28: INPUT(.INPUT, 9, '[-f0 -r16777215]') then Src = INPUT) and matches it with ONE POS(0) ... RPOS(0) pattern.
#
# POPULATION, EACH FILE ALONE: per landing the files of corpus/benchmarks/<lang>; with GATE_POPULATION=corpus or under the bus's
# closure run (S4E_DONE_WHEN_RUN=1) every corpus program of the language (every *.<ext> outside .git and corpus/library, not
# ALL.*) -- the whole-corpus run is a closure run, one at a time (CEO-1341). Each file goes to the C parser and to the .sc parser
# compiled ONCE per language to a mode-4 binary (Lon 2026-09-28: "forget mode 3 runs."), run at the largest arena on the file's own
# stdin; the two dumps are compared for THAT file. Raku is not graded yet: parser_raku.sc is the 2026-09-29 conversion of
# rk_syntax.c + rk_tree.c, not yet byte-identical on every corpus file, and its direct .sc compile hits a Snocone-frontend defect
# (a second statement hangs; its own transpile runs) -- it joins this gate the landing it matches 100%.
# THE TREE HASH (Lon 2026-09-29 18:5x CDT, in-chat to the ceo, verbatim: "You might consider creating a hash calculated of the
# trees to compare quickly success and delay the details." and "hashing the output tree is what I meant. In memory. Then output
# the one number per-test for comparison. It shows only how many do not match, not in what ay do they not match."): each side runs
# under PARSER_TREE_HASH=1 and prints ONE NUMBER per file instead of its tree -- h = (h * 256 + byte) mod (2^55 - 55) over every
# byte its dump would print (C: ir_dump_tree into a hashing stream, src/tools/parser_main.c; .sc: TreeDumpPut/TreeDumpEnd,
# bootstrap/tdump.sc) -- and the gate compares the numbers. THE CANARY: the first compared file of each language is also dumped in full on
# both sides and each number is re-derived from its dump here, so a hash that stopped folding cannot read as MATCH (rc 2).
# GATE_DETAIL=1 dumps the first DIFF file of each language in full and prints its first differing line pair. GATE_REDS=<file> appends one
# line per file that is not a MATCH or a both-refused (language, kind, path under the corpus) -- the list a whole-corpus run owes the lane that cures it. GATE_LANGS="snobol4 icon"
# grades those languages alone (a landing's own arm; the closure run grades all six).
# THE C SIDE DUMPS WHAT ITS PARSER BUILT (the ceo's row, CEO-1364: "the C side dumps the parse tree the .sc reproduces"): Icon
# before link resolution, Pascal before its semantic check, Rebus before lower_rebus.c, Prolog each clause's tree before
# prolog_lower (a clause list with a parse error is refused), Snocone code_to_ast of the statements its parser builds, SNOBOL4
# its parse -- never a FINISH step.
# VERDICT per language: files, hashes compared, MATCH, DIFF, REFUSED (by C, by .sc, by both), CRASH (by C: a signal; by .sc: a
# nonzero exit without Parse Error), COULD-NOT-MEASURE (a timeout), and the first red file. A C refusal is "Parse Error" or a
# nonzero exit below 128 (icon_compile_parse exits 1 on a syntax error). rc 0 = every file of every graded language MATCHes;
# rc 1 = a DIFF, a one-sided refusal or a crash on either side; rc 2 = could not measure. A file BOTH parsers refuse counts as
# agreement (neither built a tree), printed apart; a crash is never agreement.
# RED BY MEASUREMENT on 2026-09-28: the .sc and C trees differ in five shape classes (GOAL-SNOCONE-100.md cursor 2026-09-28b)
# until Lon's canonical forms land in the .sc parsers.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
CORPUS="${CORPUS:-$S4E/corpus}"; [ -d "$CORPUS/tests" ] || { echo "⛔ GATE REFUSE(2) [$G]: no corpus at $CORPUS"; exit 2; }
B="$ROOT/bootstrap"; CHAIN="$B/global.sc $B/case.sc $B/assign.sc $B/match.sc $B/counter.sc $B/stack.sc $B/tree.sc $B/ShiftReduce.sc $B/tdump.sc $B/gen.sc $B/qize.sc $B/semantic.sc $B/omega.sc $B/trace.sc"
for f in $CHAIN; do [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: chain file missing: $f"; exit 2; }; done
. "$HERE/lib_declared_arena.sh" || { echo "⛔ GATE REFUSE(2) [$G]: cannot load lib_declared_arena.sh"; exit 2; }
POP="${GATE_POPULATION:-sample}"; [ "${S4E_DONE_WHEN_RUN:-}" = 1 ] && POP=corpus
TMO="${GATE_TIMEOUT:-300}"
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
declare -A EXT=([snobol4]=sno [snocone]=sc [icon]=icn [prolog]=pl [rebus]=reb [pascal]=pas)
refused() { grep -q '^Parse Error' "$1"; }
tree_fold() { python3 -c 'import sys
b=open(sys.argv[1],"rb").read(); h=0
for c in b: h=(h*256+c)%(2**55-55)
print(h)' "$1"; }
tree_canary() {
    ( cd "$(dirname "$1")"; SNO_LIB="$CORPUS/include" timeout -k 5 "$TMO" "$2" - < "$1" > "$T/k.cdump" 2>/dev/null )
    sc_run "${4:-$1}" timeout -k 5 "$TMO" "$3" $SW > "$T/k.sdump" 2>/dev/null
    refused "$T/k.cdump" || [ "$(tree_fold "$T/k.cdump")" = "$(cat "$T/c.hash")" ] || { echo "C hash $(cat "$T/c.hash") is not the fold of its dump (${1#$CORPUS/})"; return; }
    refused "$T/k.sdump" || [ "$(tree_fold "$T/k.sdump")" = "$(cat "$T/s.hash")" ] || { echo ".sc hash $(cat "$T/s.hash") is not the fold of its dump (${1#$CORPUS/})"; return; }
    echo LIVE; }
# CEO-1483: the .sc parser carries its own Preprocess pattern (text to text) ahead of its Compiland pattern, so it reads the RAW file; only the C parser reads the pre-step's twin. LPATH names the $include directories for both.
export LPATH="$CORPUS/packages/icon/ipl/procs"
# CEO-1366: macro processing is a pre-step; Icon sources go through out/scrip-ipp and BOTH parsers read the same preprocessed twin (prints the twin's path; rc 1 = the pre-step refused)
# SNOBOL4's pre-step is util_sno_include_twin.py (the include lines of snobol4.l as text); the .sc reads the RAW file from the file's own directory, as the C parser does, with the same SNO_LIB
export SNO_LIB="$CORPUS/include:$CORPUS/library:$CORPUS/packages/snobol4/gimpel:$CORPUS/packages/snobol4/snoflake_suite/gimpel"
pp_twin() { case "$1" in
    icon) LPATH="$CORPUS/packages/icon/ipl/procs" "$ROOT/out/scrip-ipp" "$2" > "$T/pp.icn" 2>/dev/null || return 1; echo "$T/pp.icn" ;;
    snobol4) ( cd "$(dirname "$2")" && python3 "$ROOT/../harness/scripts/util_sno_include_twin.py" "$2" ) > "$T/pp.sno" 2>/dev/null || return 1; echo "$T/pp.sno" ;;
    *) echo "$2" ;; esac; }
sc_run() { local f="$1"; shift; ( [ "$L" = snobol4 ] && cd "$(dirname "$f")"; "$@" < "$f" ); }
red() { [ -n "${GATE_REDS:-}" ] && printf '%s\t%s\t%s\n' "$L" "$1" "${f#$CORPUS/}" >> "$GATE_REDS"; true; }
RC=0; GRADED=0; GREEN=0
echo "TREE-FOR-TREE [$G]: population=$POP, EACH FILE ALONE through out/parser_<lang> and the .sc chain compiled once to a mode-4 binary at the chain's declared heap and stack (bootstrap/parser_<lang>.heap, .stack), one tree hash per file per side (PARSER_TREE_HASH=1), timeout ${TMO}s per run"
for L in ${GATE_LANGS:-snobol4 snocone icon prolog rebus pascal}; do
    ext=${EXT[$L]}; exe="$ROOT/out/parser_$L"
    ( . "$HERE/lib_build_currency.sh" && assert_parser_current "$L" "$ROOT" ) || { echo "  $L: ⛔ REFUSE(2) $exe is missing or older than a source it was compiled from (named above) -- make parsers"; RC=2; continue; }
    SW="$(declared_switches_beside "$B/parser_$L.sc")" && [ -n "$SW" ] || { echo "  $L: ⛔ REFUSE(2) bootstrap/parser_$L.sc declares no heap or stack, or the declaration is refused"; RC=2; continue; }
    if [ "$POP" = corpus ]; then find "$CORPUS" -type f -name "*.$ext" -not -name 'ALL.*' -not -path '*/.git/*' -not -path "$CORPUS/library/*" | sort > "$T/$L.files"
    else ls "$CORPUS/benchmarks/$L"/*."$ext" 2>/dev/null | sort > "$T/$L.files"; fi
    nf=$(wc -l < "$T/$L.files"); [ "$nf" -gt 0 ] || { echo "  $L: ⛔ REFUSE(2) empty population ($POP)"; RC=2; continue; }
    cat $CHAIN "$B/parser_$L.sc" > "$T/$L.chain.sc"
    "$SCRIP" --compile "$T/$L.chain.sc" -o "$T/$L.s" </dev/null >/dev/null 2>&1 && gcc -m64 -no-pie -rdynamic "$T/$L.s" -Wl,-rpath,"$ROOT/out" -L"$ROOT/out" -lscrip_rt -lm -lpthread -o "$T/$L.bin" 2>/dev/null \
        || { echo "  $L: ⛔ REFUSE(2) the .sc chain did not compile or link to a mode-4 binary"; RC=2; continue; }
    m=0; d=0; rc_=0; rs=0; rb=0; u=0; hc=0; kc=0; ks=0; first=""; firstf=""; canary=""
    while IFS= read -r f; do
        g=$(pp_twin "$L" "$f") || { rb=$((rb + 1)); continue; }
        ( cd "$(dirname "$f")"; SNO_LIB="$CORPUS/include" PARSER_TREE_HASH=1 timeout -k 5 "$TMO" "$exe" - < "$g" > "$T/c.hash" 2>/dev/null ); crc=$?
        sc_run "$f" env PARSER_TREE_HASH=1 timeout -k 5 "$TMO" "$T/$L.bin" $SW > "$T/s.hash" 2>/dev/null; src=$?
        if [ $crc -eq 124 ] || [ $src -eq 124 ]; then u=$((u + 1)); red TIMEOUT; continue; fi
        if [ $crc -ge 128 ]; then kc=$((kc + 1)); red CRASH-C; [ -n "$first" ] || first="C crashed rc=$crc ${f#$CORPUS/}"; continue; fi
        if [ $src -ne 0 ] && ! refused "$T/s.hash"; then ks=$((ks + 1)); red CRASH-SC; [ -n "$first" ] || first=".sc crashed rc=$src ${f#$CORPUS/}"; continue; fi
        cr=0; sr=0; { refused "$T/c.hash" || [ $crc -ne 0 ]; } && cr=1; refused "$T/s.hash" && sr=1
        if [ $cr = 1 ] && [ $sr = 1 ]; then rb=$((rb + 1))
        elif [ $cr = 1 ]; then rc_=$((rc_ + 1)); red REFUSED-BY-C; [ -n "$first" ] || first="C refused ${f#$CORPUS/}"
        elif [ $sr = 1 ]; then rs=$((rs + 1)); red REFUSED-BY-SC; [ -n "$first" ] || first=".sc refused ${f#$CORPUS/}"
        else hc=$((hc + 1)); [ -n "$canary" ] || canary=$(tree_canary "$g" "$exe" "$T/$L.bin" "$f")
            if cmp -s "$T/c.hash" "$T/s.hash"; then m=$((m + 1))
        else d=$((d + 1)); red DIFF; [ -n "$first" ] || { first="DIFF ${f#$CORPUS/}"; firstf="$f"; }; fi; fi
    done < "$T/$L.files"
    if [ "${GATE_DETAIL:-}" = 1 ] && [ -n "$firstf" ]; then
        g=$(pp_twin "$L" "$firstf")
        ( cd "$(dirname "$firstf")"; SNO_LIB="$CORPUS/include" timeout -k 5 "$TMO" "$exe" - < "$g" > "$T/c.dump" 2>/dev/null )
        L=$L sc_run "$firstf" timeout -k 5 "$TMO" "$T/$L.bin" $SW > "$T/s.dump" 2>/dev/null
        first="$first: $(diff "$T/c.dump" "$T/s.dump" | grep -m2 '^[<>]' | cut -c1-60 | tr '\n' ' ')"
    fi
    [ "$canary" = LIVE ] || [ "$canary" = "" ] || { echo "  $L: ⛔ REFUSE(2) the hash canary: $canary"; RC=2; continue; }
    GRADED=$((GRADED + 1))
    verdict=MATCH; [ $d -gt 0 ] || [ $rc_ -gt 0 ] || [ $rs -gt 0 ] || [ $kc -gt 0 ] || [ $ks -gt 0 ] && verdict=RED; [ $u -gt 0 ] && verdict="COULD-NOT-MEASURE($u)"
    echo "  $L: $verdict files=$nf hashes-compared=$hc MATCH=$m DIFF=$d REFUSED-by-C=$rc_ REFUSED-by-.sc=$rs refused-by-both=$rb CRASH-C=$kc CRASH-.sc=$ks timeout=$u${first:+ -- first: $first}"
    case "$verdict" in MATCH) GREEN=$((GREEN + 1)) ;; RED) [ $RC -eq 2 ] || RC=1 ;; *) RC=2 ;; esac
done
echo "  raku: not graded yet (parser_raku.sc, the rk_syntax.c conversion, joins at 100%)"
[ $RC -eq 2 ] && { echo "⛔ GATE REFUSE(2) [$G]: a language could not be measured (see above)"; exit 2; }
if [ $RC -eq 0 ]; then echo "✅ GATE PASS(0) [$G]: $GREEN/$GRADED graded languages print the same tree from the C parser and the .sc parser on every file ($POP population)"
else echo "⛔ GATE FAIL(1) [$G]: $GREEN/$GRADED graded languages match on every file ($POP population) -- the shape classes are in the cursor"; fi
exit $RC
