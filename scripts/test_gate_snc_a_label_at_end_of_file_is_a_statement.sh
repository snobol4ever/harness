#!/usr/bin/env bash
# test_gate_snc_a_label_at_end_of_file_is_a_statement.sh -- A SNOCONE LABEL WITH NO STATEMENT AFTER IT IS A
# STATEMENT, NOT A SYNTAX ERROR (hq_I, row snocone-every-non-package-source-that-runs-with-output-absorbed-into-
# the-master-with-oracle-refs, 2026-09-13).
#
# MECHANISM, read off the grammar and not inferred: snocone_parse.y carried a label ONLY as a prefix of another
# statement -- matched_stmt had "label_decl matched_stmt" and unmatched_stmt had "label_decl unmatched_stmt", and
# there was no production in which a label stood alone. So "fin:" as the last line of a file left the parser
# waiting for the statement the label had to prefix, and the diagnostic landed on the line AFTER the last one:
# claws5.sc:138 in a 137-line file, treebank-append.sc:198 in 197, treebank-prepend.sc:194 in 193. All three end
# with "END:" -- the exit label their own "goto END;" jumps to, which is the idiom that cannot be written last.
# ⛔ THE EMPTY STATEMENT ALREADY EXISTED (simple_stmt: T_SEMICOLON), so "fin: ;" parsed and "fin:" did not -- two
# spellings of one construct disagreeing, which is what made this read as a typo in the corpus rather than a gap
# in the grammar. CURE (this commit): the two prefix productions are REPLACED by a single "matched_stmt:
# label_decl". That is semantically identical for the prefix case and not merely close to it -- sc_append_label_node
# already appends the label as its OWN STMT_t through sc_append_chain and never attaches it to the following
# statement, so "a: b = 1;" built the same two-node chain before this change and after it. Bison agrees: the
# grammar had ZERO conflicts before and has ZERO after, where simply ADDING "| label_decl" beside the prefix
# productions raises 37 shift/reduce -- the replacement is the conflict-free form and the addition is not.
#
# ⛔ THIS GATE CUTS NO REF AND TYPES NO EXPECTED OUTPUT, ON PURPOSE. Snocone has no rival implementation to cut
# one from (corpus/tests/snocone/PROVENANCE.md), and an authored ref here would be this seat grading its own
# opinion. Instead every arm is a TWIN DIFF against the spelling the compiler ALREADY accepted: "fin:" must behave
# byte-for-byte and rc-for-rc like "fin: ;". The control is the construct, not a number.
#
# ARMS: (1) m3 twin diff, trailing label vs explicit empty statement; (2) m4 twin diff, the same pair, because a
# parse cure that reached only one mode would still be a divergence; (3) the LIVE-TARGET arm -- a goto into the
# trailing label must skip the output between, so the label is proven to be a real jump target and not a node the
# parser accepted and dropped; (4) the three corpus kernels that opened the row must PARSE (their runtime state is
# other rows and is deliberately NOT graded here).
# FAIL-ONCE, MEASURED 2026-09-13 BY REBUILDING THE PRE-CURE BINARY (the .y and its generated .tab.c stashed
# together, make re-run, the two binaries verified distinct by md5 -- an A/B that does not prove that compared a
# build with itself): the gate exits NON-ZERO on the pre-cure build with "m3 FAIL (trailing label rc=1 out=
# bare.sc:4: snocone parse error: syntax error ... vs twin rc=0 out=one|two)". ⛔ THAT RUN ALSO FOUND A HOLE IN
# THIS GATE AND IT IS CURED HERE: arm 2 had refused rc=2 when EITHER twin failed to compile, so on the defective
# build it reported "measured nothing" and exited before arms 3 and 4 ran -- a gate that turns the very defect it
# grades into its own inability to measure. It now refuses only when the CONTROL twin cannot compile, and reads a
# control that compiles beside a bare form that does not as the FAILURE it is.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
LIBDIR="$ROOT/out"; [ -f "$LIBDIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no libscrip_rt.so in $LIBDIR"; exit 2; }
CORPUS="${CORPUS_ROOT:-$(cd "$ROOT/.." && pwd)/corpus}"
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
printf 'OUTPUT = "one";\nOUTPUT = "two";\nfin:\n'   > "$T/bare.sc"
printf 'OUTPUT = "one";\nOUTPUT = "two";\nfin: ;\n' > "$T/twin.sc"
printf 'x = 1;\nif (LT(x, 2)) { goto fin; }\nOUTPUT = "not skipped";\nfin:\n' > "$T/jump.sc"
run3() { ( cd "$T" && timeout -k 5 8s "$SCRIP" "$1" </dev/null 2>&1 ); }
bare3="$(run3 bare.sc)"; bare3rc=$?
twin3="$(run3 twin.sc)"; twin3rc=$?
if [ "$twin3rc" != 0 ]; then echo "⛔ GATE REFUSE(2) [$G]: the CONTROL spelling 'fin: ;' does not run (rc=$twin3rc) -- with no control there is nothing to diff against"; exit 2; fi
if [ "$bare3" = "$twin3" ] && [ "$bare3rc" = "$twin3rc" ]; then echo "  m3 PASS (trailing label is byte-identical to the empty-statement twin, rc=$bare3rc: $(printf '%s' "$twin3" | tr '\n' '|'))"
else echo "  m3 FAIL (trailing label rc=$bare3rc out=$(printf '%s' "$bare3" | tr '\n' '|') vs twin rc=$twin3rc out=$(printf '%s' "$twin3" | tr '\n' '|'))"; RC=1; fi
m4() { ( cd "$T" && "$SCRIP" --compile "$1.sc" -o "$1.s" </dev/null >/dev/null 2>&1 ) && gcc -m64 -no-pie -rdynamic "$T/$1.s" -Wl,-rpath,"$LIBDIR" -L"$LIBDIR" -lscrip_rt -lm -lpthread -o "$T/$1.bin" 2>"$T/$1.ld"; }
if ! m4 twin; then echo "⛔ GATE REFUSE(2) [$G]: the CONTROL twin would not compile or link in mode 4, so arm 2 has no baseline and measured nothing (see $T/twin.ld)"; exit 2; fi
if ! m4 bare; then echo "  m4 FAIL (the control twin compiles in mode 4 and the trailing-label form does not -- that asymmetry IS the defect, not an inability to measure: $(head -1 "$T/bare.ld" 2>/dev/null))"; RC=1
else
    b4="$(timeout -k 5 8s "$T/bare.bin" </dev/null 2>&1)"; b4rc=$?
    t4="$(timeout -k 5 8s "$T/twin.bin" </dev/null 2>&1)"; t4rc=$?
    if [ "$b4" = "$t4" ] && [ "$b4rc" = "$t4rc" ]; then echo "  m4 PASS (the same twin diff holds in mode 4, rc=$b4rc: $(printf '%s' "$t4" | tr '\n' '|'))"
    else echo "  m4 FAIL (mode 4 diverged: bare rc=$b4rc $(printf '%s' "$b4" | tr '\n' '|') vs twin rc=$t4rc $(printf '%s' "$t4" | tr '\n' '|'))"; RC=1; fi
fi
j3="$(run3 jump.sc)"; j3rc=$?
if [ "$j3rc" = 0 ] && [ -z "$j3" ]; then echo "  live-target PASS (goto into the trailing label skipped the statement between it, so the label is a real jump target)"
else echo "  live-target FAIL (rc=$j3rc, output $(printf '%s' "$j3" | tr '\n' '|') -- expected empty: the goto must skip 'not skipped')"; RC=1; fi
kern=0; kbad=0
for k in benchmarks/snocone/demo/claws5.sc benchmarks/snocone/demo/treebank-append.sc benchmarks/snocone/demo/treebank-prepend.sc; do
    [ -f "$CORPUS/$k" ] || continue
    kern=$((kern + 1))
    if ( cd "$(dirname "$CORPUS/$k")" && timeout -k 5 20s "$SCRIP" --dump-ast "$(basename "$k")" </dev/null ) >/dev/null 2>"$T/k.err"; then :
    else if grep -q 'parse error' "$T/k.err"; then kbad=$((kbad + 1)); echo "  kernel FAIL $k: $(head -1 "$T/k.err")"; fi; fi
done
if [ "$kern" = 0 ]; then echo "  kernels SKIP (none of the three found under $CORPUS -- arms 1 to 3 are minted here and still bind)"
elif [ "$kbad" = 0 ]; then echo "  kernels PASS ($kern/3 of the corpus kernels that opened this row parse; their runtime state is other rows and is not graded here)"
else RC=1; fi
if [ "$RC" = 0 ]; then echo "✅ GATE PASS(0) [$G]: a label at end of file is a statement, in both modes, and it is a live jump target"
else echo "⛔ GATE FAIL(1) [$G]: a trailing label does not behave as its empty-statement twin"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
