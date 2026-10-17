#!/usr/bin/env bash
# test_gate_no_rungs_ref_is_an_ast_dump.sh -- NO RUNGS REF IS AN AST DUMP. Every entry of every rung suite is graded by RUNNING it in
# both modes (Lon 2026-09-23, CEO-1218/1230: "Get rid of those m3 and and m4 specific columns. We do not do that here."), so a ref
# that is a `--dump-ast` dump can only ever manufacture a red that means nothing: the entry's program output is diffed against a
# parse tree. This gate is the survivor of test_gate_ast_shaped_refs_are_declared_ast.sh (hq_T 2026-09-05), whose converse arm
# asked that such a ref be DECLARED modes=ast; with the declaration gone, the only correct count of dump-shaped refs is zero.
# ⛔ THE STRICT (ACCUSING) PREDICATE, kept from its predecessor: a ref opens with '(' AND carries a marker ordinary program output
# does not ((STMT, (PROGRAM, :subj, :lhs), so a program that merely prints a parenthesised first line is never accused.
# ⛔ AN UNREADABLE RUNGS IS A REFUSAL rc=2, NEVER A CLEAN LANGUAGE; zero rung suites read is a refusal too.
# EXIT: 0 no dump-shaped ref in any rung suite · 1 at least one, each named · 2 could not measure.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh" 2>/dev/null || { echo "GATE UNPROVEN(2): cannot load lib_gate.sh"; exit 2; }
gate_parse_args "$@"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
HARNESS="$HERE/corpus_suite_harness.py"
TESTS="$S4E/corpus/tests"
gate_require "$HARNESS" "corpus_suite_harness.py, the ONE grading authority"
gate_require "$TESTS" "the per-language rungs suites"
echo "--- no rungs ref is a --dump-ast dump (population = every entry's REF in every rung suite) ---"
python3 - "$HERE" "$TESTS" <<'PY'
import os, sys
sys.path.insert(0, sys.argv[1])
import corpus_suite_harness as m
tests = sys.argv[2]
LANGS = dict({l: c["ext"] for l, c in m.LANG_CONFIGS.items()}, snobol4=".sno")
def is_dump(ref):
    txt = (ref if isinstance(ref, str) else "\n".join(ref)).strip()
    if not txt.startswith("("):
        return False
    return txt.startswith("(STMT") or txt.startswith("(PROGRAM") or ":subj" in txt or ":lhs" in txt
graded = total_entries = violations = 0
for lang in sorted(LANGS):
    d = os.path.join(tests, lang)
    sp = os.path.join(d, "ALL" + LANGS[lang])
    rp = os.path.join(d, "ALL.ref")
    if not (os.path.isfile(sp) and os.path.isfile(rp)):
        continue
    try:
        if lang == "snobol4":
            ents = m.read_suite(sp, rp)
        else:
            cfg = m.LANG_CONFIGS[lang]
            ents = m.read_block_suite(sp, rp, m.banner_re_for(cfg["comment_open"], cfg["comment_close"]))
    except Exception as e:
        sys.stderr.write("REFUSED(2): %s: cannot read its rungs pair (%s)\n" % (lang, str(e)[:140]))
        raise SystemExit(2)
    graded += 1
    total_entries += len(ents)
    dumps = [e.name for e in ents if is_dump(e.ref)]
    print("   %-8s %5d entries : %4d dump-shaped ref(s)  %s" % (lang, len(ents), len(dumps), "⛔" if dumps else "ok"))
    for n in dumps[:8]:
        print("        dump-shaped ref: %s -- re-cut it from the language's oracle" % n)
    if len(dumps) > 8:
        print("        ... and %d more" % (len(dumps) - 8))
    violations += len(dumps)
if graded == 0:
    sys.stderr.write("REFUSED(2): no rungs suite with a readable ALL pair under %s -- nothing measured\n" % tests)
    raise SystemExit(2)
print("   ---")
print("   DENOMINATOR: %d language rung suite(s), %d entries examined" % (graded, total_entries))
if violations:
    print("⛔ GATE FAIL [no_rungs_ref_is_an_ast_dump]: %d dump-shaped ref(s) over %d rung suite(s)" % (violations, graded))
    raise SystemExit(1)
print("✅ GATE PASS [no_rungs_ref_is_an_ast_dump]: no dump-shaped ref in %d rung suite(s), %d entries" % (graded, total_entries))
PY
exit $?
