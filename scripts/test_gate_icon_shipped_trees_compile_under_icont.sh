#!/usr/bin/env bash
# test_gate_icon_shipped_trees_compile_under_icont.sh -- THE SHIPPED-TREE GRADABILITY GATE (CEO-489, hq_V
# 2026-09-10). The widening the ceo granted of test_gate_icon_rungs_entries_compile_under_icont.sh, whose
# criterion this file carries onto EVERY SHIPPED .icn rather than only the ones the Icon rungs stores.
#
# THE CRITERION, in the ceo's words (CEO-489): every shipped `.icn` under corpus packages/icon, tests/icon,
# benchmarks/icon and demos/icon compiles under `icont -s -c`; the SEMICOLON CLASS is reported SEPARATELY from
# the jcon preprocessor and declaration forms, and THE TWO ARE NEVER SUMMED. hq_B's CEO-488 repair row
# (`icon-every-shipped-icn-file-our-conversion-added-semicolons-that-icont-refuses-are-removed-so-icont-
# compiles-it`) closes on THIS gate reading ZERO semicolon-class refusals.
#
# ⛔⭐ WHY THE CLASS SPLIT IS THE WHOLE INSTRUMENT, AND WHY A SINGLE "41 REFUSED" IS WORSE THAN NO NUMBER.
# The two classes have two different owners and two different truths. The semicolon class is OURS: our
# conversion added a statement terminator that Arizona icont refuses, so every carrying file is a file we
# broke and hq_B can repair. The other class is NOT ours and is NOT repairable by deleting anything: it is
# jcon preprocessor and declaration forms (`$undef` arity, `import`, `$ifdef` arity, `=` at declaration
# position, an `inconsistent redeclaration`) that the vendored jcon dialect accepts and Arizona icont never
# did. Summing them produces a number that falls as hq_B works and STILL never reaches zero, so the row's
# DONE-WHEN could never fire and a reader would route vendored-dialect files to hq_B's lane forever.
#
# ⛔⛔ THE CLASSIFIER IS MEASURED, NOT ASSERTED, AND THAT IS NOT GOLD-PLATING -- A MESSAGE-SHAPE CLASSIFIER IS
# MEASURABLY WRONG ON THIS POPULATION. The obvious rule is "the token icont quotes is a `;`". It misfiles
# packages/icon/jcon_tests/prepro.icn, which is a DELIBERATE preprocessor-error fixture: it raises
# `$undef: too many arguments` AND five `";": missing right parenthesis` in one compile, so a token-shape rule
# hands hq_B a vendored fixture whose semicolons cannot be removed and whose refusal cannot be cured. It also
# cannot see the `"}": invalid case clause` shape at all, where the offending `;` sits on the PREVIOUS line and
# the token icont names is the brace. So a file is called SEMICOLON-CLASS here only when this gate has
# DEMONSTRATED, by re-running the oracle, that deleting `;` BYTES AND NOTHING ELSE makes icont accept it --
# which is precisely the property hq_B's DONE-WHEN asserts per file (bytes removed == semicolons removed).
# Every deletion is at a position ICONT ITSELF FLAGGED; this gate never scans for semicolons it likes the look
# of, and it never writes a repair back to the tree -- it measures in a private temp dir and reports.
#
# ⛔ THREE OUTCOMES, NEVER SUMMED -- the CEO-483 lesson applied a second time. semicolon-class refusals,
# other-form refusals, and UNDECIDED (the probe was still deleting semicolons when the iteration cap hit) are
# three diagnoses with three owners. UNDECIDED is rc=2 COULD-NOT-MEASURE and never rc=1, because a probe that
# ran out of budget has proven nothing about the file and must not be delivered to hq_B as work.
#
# ⛔ STAGING IS BY SYMLINK INTO A TEMP TREE, ONE DIRECTORY AT A TIME, AND THE REASON IS CORRECTNESS BEFORE
# SPEED. `icont -s -c` writes `.u1`/`.u2` beside the source, so compiling 1379 files IN PLACE would drop ~2700
# artifacts into the corpus working tree -- and a dirty tree is refused by every runner we own (CEO-174), so
# the gate would break the next seat's measurement rather than its own. Symlinking the whole directory (not
# the one file) is what makes `$include` resolve exactly as it does in the tree: the CEO-483 retraction turned
# on a companion that was present and declared the whole time and that the instrument simply was not staging,
# and the ceo's own slower census carries that same defect -- it reports `"prepro.dat": cannot open` as a
# refusal where this gate compiles the file. Artifacts land as REAL files in temp; the corpus stays clean,
# asserted below rather than assumed.
#
# ⛔ THIS GATE GRADES SHIPPED TEXT, NOT SCRIP. It never runs ./scrip and no compiler change can move it.
# A red here means we ship Icon source Arizona icont refuses.
#
# ⛔ NOT WIRED INTO `make test` WHILE IT IS RED. It reads FAIL(1) with 18 semicolon-class files named until
# hq_B's CEO-488 row lands, and wiring a known-red arm blocking would turn `make test` red for all thirteen
# seats and make every other seat pay for one open row (CEO-463). IT WIRES BLOCKING THE MOMENT IT READS ZERO,
# and it must -- the conversion is a WRITER, and a writer that regresses re-manufactures the class silently,
# which is the identical argument that keeps the rungs gate wired.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
GATE="test_gate_icon_shipped_trees_compile_under_icont"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ $GATE REFUSES rc=2: lib_oracle_flags.sh unloadable" >&2; exit 2; }
ICONT="$(icont_bin)" || exit 2
CORPUS="${GATE_CORPUS_ROOT:-$S4E/corpus}"
[ -d "$CORPUS" ] || { echo "⛔ $GATE REFUSES rc=2: corpus root not a directory: $CORPUS" >&2; exit 2; }

# ── THE SHIPPED TREES, exactly the four the ceo named in CEO-489. A tree that is missing is rc=2, never a
# quietly smaller population: the census that matters is the one over all four, and three-quarters of it
# printed in the success shape is the false-green this gate exists to prevent.
TREES=(packages/icon tests/icon benchmarks/icon demos/icon)
for t in "${TREES[@]}"; do
    [ -d "$CORPUS/$t" ] || { echo "⛔ $GATE REFUSES rc=2: shipped tree missing: $CORPUS/$t" >&2; exit 2; }
done

# ⛔ ALL.icn IS EXCLUDED AND IT IS NOT AN EXCEPTION TO THE CRITERION -- it is A CONTAINER, NEVER COMPILED
# WHOLE (RULES.md; the correction this seat sent hq_C on 09-10). Its ENTRIES are graded one at a time by the
# sibling gate test_gate_icon_rungs_entries_compile_under_icont.sh, which is where that question is asked and
# answered. Feeding the container to icont here would produce one meaningless refusal standing for 758 files.
mapfile -t FILES < <(cd "$CORPUS" && find "${TREES[@]}" -path '*.fixtures' -prune -o -name '*.icn' -type f ! -name 'ALL.icn' -print | sort)
N=${#FILES[@]}
# ⛔ REFUSE ON A COLLAPSED POPULATION rather than print the success shape over nothing (RULES.md: a DONE-WHEN
# never pins a population count in a literal -- this reads the denominator it actually found, and only refuses
# when that denominator is too small to be the shipped corpus at all).
[ "$N" -gt 1000 ] || { echo "⛔ $GATE REFUSES rc=2: found $N shipped .icn files under ${TREES[*]} -- the trees or the filter are wrong" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/icn_shipped_icont_gate.XXXXXX")" || { echo "⛔ $GATE REFUSES rc=2: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

n_ok=0; REFUSED=()
declare -A STAGED
for f in "${FILES[@]}"; do
    d="$(dirname "$f")"; b="$(basename "$f")"
    if [ -z "${STAGED[$d]:-}" ]; then
        mkdir -p "$WORK/$d" || { echo "⛔ $GATE REFUSES rc=2: cannot stage $d" >&2; exit 2; }
        # ⛔⛔ REGULAR FILES ONLY, AND THIS IS THE LOAD-BEARING LINE OF THE WHOLE STAGING SCHEME. Linking a
        # SUBDIRECTORY makes `$WORK/<d>/<sub>` a symlink INTO THE CORPUS; the next iteration's `mkdir -p
        # "$WORK/<d>/<sub>"` then succeeds silently (the path exists, through the link), and every subsequent
        # `ln` and every `icont` in that directory resolves THROUGH IT AND WRITES INTO THE SHIPPED TREE.
        # MEASURED, not hypothesised: the first cut of this gate did exactly that and left 362 untracked
        # `.u1`/`.u2` artifacts in corpus/benchmarks/icon, which is a dirty tree that every runner we own
        # refuses (CEO-174) -- this gate would have broken the next seat's measurement, not its own.
        for s in "$CORPUS/$d"/*; do [ -f "$s" ] && ln -sf "$s" "$WORK/$d/"; done
        STAGED[$d]=1
    fi
    if ( cd "$WORK/$d" && "$ICONT" -s -c "$b" ) >/dev/null 2>&1; then
        n_ok=$((n_ok+1))
    else
        REFUSED+=("$f")
    fi
done
n_refused=${#REFUSED[@]}

# ⛔ A DECLARED FIXTURE DIRECTORY (NAME.fixtures/, staged into a program's run directory by the IPL runner) is DATA, not
# leaked output: progs/utrim trims ucode, so utrim.fixtures/ ships tprog.u1 and tprog.u2 as its input (hq_icon 2026-09-25).
# The leak checks below skip *.fixtures directories, and so does the population (a fixture's .icn is input data -- progs/fset
# lists fsx_cat.icn to show a pattern excluding it -- as lib_inventory.sh's census already treats it); nothing else is skipped.
# ⛔ THE STAGING ASSERTION, not an assumption: if a single `.u1`/`.u2` reached the corpus the gate has dirtied
# the tree it was measuring, and every runner downstream would refuse for a reason that looks like someone
# else's fault. Cheap to check, and it is the one failure of this design that would be invisible in the result.
if find "$CORPUS" -path '*.fixtures' -prune -o \( -name '*.u1' -o -name '*.u2' \) -print 2>/dev/null | grep -q .; then
    echo "⛔ $GATE REFUSES rc=2: icont artifacts reached the corpus tree -- staging leaked, tree is now dirty" >&2
    exit 2
fi

if [ "$n_refused" -eq 0 ]; then
    echo "$GATE: population=$N compiled=$n_ok semicolon-class=0 other-form=0"
    echo "✅ $GATE PASS: all $N shipped Icon files compile under icont -s -c"
    exit 0
fi

# ── THE MEASURED CLASSIFIER. Runs ONLY over the refusal set (tens of files, not the whole population), so the
# cost of being right here is a rounding error against the 1379 compiles above.
CLS="$WORK/.classify.out"
printf '%s\n' "${REFUSED[@]}" | python3 "$HERE/util_icon_semicolon_class_classifier.py" "$ICONT" "$CORPUS" "$WORK" > "$CLS" 2>"$WORK/.classify.err"
PY_STATUS=$?
if [ "$PY_STATUS" -ne 0 ]; then
    echo "⛔ $GATE REFUSES rc=2: the classifier failed -- see below" >&2
    cat "$WORK/.classify.err" >&2
    exit 2
fi
# ⛔ THE LEAK ASSERTION AGAIN, because the classifier runs the oracle dozens more times per refused file and
# stages its own directories. Checking once before it ran would certify a tree it had not yet touched.
if find "$CORPUS" -path '*.fixtures' -prune -o \( -name '*.u1' -o -name '*.u2' \) -print 2>/dev/null | grep -q .; then
    echo "⛔ $GATE REFUSES rc=2: icont artifacts reached the corpus tree during classification" >&2
    exit 2
fi

mapfile -t SEMI  < <(sed -n 's/^SEMICOLON\t//p' "$CLS")
mapfile -t SEQX  < <(sed -n 's/^SEQEXPR\t//p' "$CLS")
mapfile -t CONTR < <(sed -n 's/^CONTAINER\t//p' "$CLS")
mapfile -t OTHER < <(sed -n 's/^OTHER\t//p' "$CLS")
mapfile -t UNDEC < <(sed -n 's/^UNDECIDED\t//p' "$CLS")
n_semi=${#SEMI[@]}; n_seqx=${#SEQX[@]}; n_contr=${#CONTR[@]}; n_other=${#OTHER[@]}; n_undec=${#UNDEC[@]}

echo "$GATE: population=$N compiled=$n_ok refused=$n_refused semicolon-class=$n_semi seqexpr-class=$n_seqx container=$n_contr other-form=$n_other undecided=$n_undec"
# ⛔⭐ A CONTAINER IS NOT A PROGRAM. These files hold many `procedure main()` behind banner separators and are
# NEVER COMPILED WHOLE (RULES.md; the ALL.icn ruling, and the correction this seat sent hq_C on 09-10). Their
# entries are graded one at a time where they are absorbed. Compiled whole they raise `inconsistent
# redeclaration`, which reads exactly like a defect and is not one -- counting them as refusals would put
# three files no one can ever "fix" permanently between hq_B's row and zero. NAMED, and the criterion note
# went to the ceo with this landing rather than being applied as a silent exclusion.
if [ "$n_contr" -gt 0 ]; then
    echo "   $n_contr CONTAINERS -- many entries in one file, never compiled whole (NOT a defect, NOT summed above):" >&2
    printf '     %s\n' "${CONTR[@]}" >&2
fi
# ⭐ THE SEQUENCE-EXPRESSION CLASS IS NAMED SEPARATELY FROM BOTH OTHERS, AND IT IS THE ONE THE CEO'S CENSUS
# COULD NOT SEE. These files carry `(a; b)` -- OUR construct -- where Arizona icont spells a compound
# expression `{a; b}`. The semicolons are CORRECT and deleting them produces `(a b)`, which is also invalid,
# so they are NOT hq_B's deletion row and folding them into it would hand hq_B a repair that cannot succeed
# and a DONE-WHEN (bytes removed == semicolons removed) that can never be satisfied. The repair is the
# GROUPING, made by hand under HQV-19 for tests/icon/parser/paren_seq.icn and measured here per file.
if [ "$n_seqx" -gt 0 ]; then
    echo "   $n_seqx SEQUENCE-EXPRESSION refusals -- \`(a; b)\` needs \`{a; b}\` for icont; the repair is the GROUPING, not deletion (NOT hq_B's row, NOT summed above):" >&2
    printf '     %s\n' "${SEQX[@]}" >&2
fi
# ⭐ NAMED, NEVER COUNTED. A bare count cannot be read for a new arrival, and the semicolon list is hq_B's
# worklist: each line carries the number of `;` bytes whose deletion this gate MEASURED sufficient, which is
# the per-file assertion CEO-488's DONE-WHEN makes (bytes removed == semicolons removed).
if [ "$n_other" -gt 0 ]; then
    echo "   $n_other NON-SEMICOLON refusals (jcon preprocessor and declaration forms; NOT hq_B's row, NOT summed above):" >&2
    printf '     %s\n' "${OTHER[@]}" >&2
fi
if [ "$n_undec" -gt 0 ]; then
    echo "⛔ $GATE REFUSES rc=2: $n_undec files the classifier could not decide within its budget (proven nothing; never delivered as work):" >&2
    printf '     %s\n' "${UNDEC[@]}" >&2
    exit 2
fi
if [ "$n_semi" -gt 0 ]; then
    echo "⛔ $GATE FAIL rc=1: $n_semi shipped Icon files are refused by icont -s -c for SEMICOLONS OUR CONVERSION ADDED (CEO-488, hq_B):" >&2
    printf '     %s\n' "${SEMI[@]}" >&2
    exit 1
fi
echo "✅ $GATE PASS: zero semicolon-class refusals in $N shipped Icon files ($n_other non-semicolon refusals named above)"
exit 0
