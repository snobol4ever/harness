#!/usr/bin/env bash
# test_gate_our_files_are_lf.sh -- OUR FILES ARE LF (Lon 2026-09-03, in-chat to hq_P, verbatim: "Do not use CRLF, use LF.";
# 2026-09-04, in-chat to ceo, verbatim: "Fix the CRLF to LF problem. Why am I still hearing about that?").
#
# POPULATION: every git-tracked file in the sibling repos SCRIP, corpus and .github, corpus/packages/ INCLUDED since Lon's
# word of 2026-10-02 (in-chat to the ceo, verbatim: "Get rid of all DOS line-endings; just say no to CR-LF."; ceo CEO-1414: 59
# vendored files converted in one corpus commit, two Gimpel oracle rejections cured by it), MINUS generated flex/bison outputs
# and MINUS the files lf_gate_crlf_is_the_subject.tsv declares -- files whose carriage returns ARE what a test measures, each
# with its reason; a declared file that is gone or holds no CR reds as STALE. (Until 2026-10-02 corpus/packages/ was excluded
# whole, on FINDING-2026-08-20-s183's measurement that curing gimpel's CRLF lowered its score then.)
# WHAT IT COUNTS: a CR at END OF LINE (\r$). A CR byte inside a string literal (benchmarks/icon/geddump.s carries
# "\t\n\r " as DATA in a .string directive) is not a line ending and is not counted.
# WHY IT EXISTS: Python's csv.writer defaults lineterminator to "\r\n", so util_build_rungs_suite.py re-minted every
# ALL.csv as CRLF on each rebuild; tests/prolog/ALL.csv was converted by hand (corpus 1feca4aa4) and the other five were
# not, and a seat then RESTORED snobol4's CRLF (corpus 40441ed53) applying the binary-read rule with no law to read
# against -- RULES.md carried no LF rule until 2026-09-04. A rule with no instrument is a memo; this is the instrument.
# rc=0 clean (population printed) / rc=1 red (every offender named) / rc=2 cannot measure (never a silent zero).
# FAIL-ONCE PROOF: LF_GATE_REPOS="<dir> ..." overrides the repo list; point it at a scratch git repo holding one
# CRLF file and the gate must print RED rc=1, then LF the file and it must print PASS rc=0.
set -u
GATE_NAME=test_gate_our_files_are_lf
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ⛔ THE SCRIP POPULATION IS THIS GATE'S OWN REPO (coo 2026-10-08, CEO-1573): ROOT/SCRIP named the repo BESIDE a worktree by name, so
# from a worktree of any other name the gate refused ("not a git repo") or, with S4E_HOME set, graded the seat's root instead of the
# landing. SCRIP is the parent of ../harness/scripts/; corpus and .github are S4E_HOME's, else the siblings of this checkout. Each repo carries
# its LABEL, because the exception table is keyed by SCRIP / corpus / .github, never by a worktree's directory name.
SELF="$(cd "$HERE/../../SCRIP" && pwd)"
SIB="${S4E_HOME:-$(cd "$SELF/.." && pwd)}"
if [ -n "${LF_GATE_REPOS:-}" ]; then PAIRS="$(for r in $LF_GATE_REPOS; do printf '%s\t%s\n' "$(basename "$r")" "$r"; done)"
else PAIRS="$(printf 'SCRIP\t%s\ncorpus\t%s\n.github\t%s\n' "$SELF" "$SIB/corpus" "$SIB/.github")"; fi
EXC="${LF_GATE_EXCEPTIONS:-$HERE/lf_gate_crlf_is_the_subject.tsv}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
command -v git >/dev/null 2>&1 || refuse "git not on PATH"
[ -f "$EXC" ] || refuse "no exception list at $EXC -- the gate cannot tell a declared CR subject from a DOS file"
awk -F'\t' '!/^#/ && NF && (NF < 3 || $3 ~ /^[[:space:]]*$/) {exit 1}' "$EXC" || refuse "$EXC has a row with no reason -- every exception names why its CRs are a test's subject"
stale=""
total=0; bad=0; badlist=""
while IFS=$'\t' read -r rn r <&3; do
    [ -n "$r" ] || continue
    [ -d "$r" ] && [ "$(git -C "$r" rev-parse --show-toplevel 2>/dev/null)" = "$(cd "$r" && pwd -P)" ] \
        || refuse "$rn: $r is not a git checkout${S4E_HOME:+ (S4E_HOME=$S4E_HOME)} -- a census that cannot see its population is not a zero"
    excl="$(awk -F'\t' -v r="$rn" '!/^#/ && $1==r {print $2}' "$EXC")"
    while IFS= read -r e; do [ -n "$e" ] || continue; { git -C "$r" ls-files --error-unmatch -- "$e" >/dev/null 2>&1 && grep -q $'\r' "$r/$e"; } || stale="$stale
    $r/$e"; done <<< "$excl"
    list="$(git -C "$r" ls-files | grep -vE '\.tab\.[ch]$|lex\.yy\.c$|\.yy\.c$' | { if [ -n "$excl" ]; then grep -vxF -f <(printf '%s\n' "$excl"); else cat; fi; })" || true
    n="$(printf '%s\n' "$list" | grep -c .)"
    [ "$n" -gt 0 ] || refuse "$r: git ls-files listed nothing after the exclusions"
    hits="$(cd "$r" && printf '%s\n' "$list" | xargs -d '\n' grep -lI $'\r$' -- 2>/dev/null)" || true
    if [ -n "$hits" ]; then
        while IFS= read -r h; do [ -n "$h" ] || continue; bad=$((bad+1)); badlist="$badlist
    $r/$h"; done <<< "$hits"
    fi
    total=$((total+n))
done 3<<< "$PAIRS"
echo "LF_CENSUS repos=$(printf '%s\n' "$PAIRS" | grep -c .) tracked_text_files=$total crlf_files=$bad (generated flex/bison outputs and the $(grep -cvE '^#|^$' "$EXC") declared CR subjects of $(basename "$EXC") excluded)"
if [ -n "$stale" ]; then echo "⛔ GATE RED [$GATE_NAME]: STALE exception(s) in $(basename "$EXC") -- the file is gone or holds no CR, so its reason no longer holds:$stale"; exit 1; fi
if [ "$bad" -gt 0 ]; then
    echo "⛔ GATE RED [$GATE_NAME]: $bad tracked file(s) carry CR at end of line -- OUR FILES ARE LF (RULES.md FACT RULE, Lon 2026-09-03/04). Convert each in a commit of its own (prove: HEAD's bytes with CRs stripped == new bytes):$badlist"
    exit 1
fi
echo "GATE PASS(0) [$GATE_NAME]: $total tracked files, 0 with CRLF"
exit 0
