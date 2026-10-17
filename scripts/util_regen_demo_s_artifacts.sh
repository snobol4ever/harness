#!/usr/bin/env bash
# util_regen_demo_s_artifacts.sh — regenerate x64 demo .s artifacts and commit to corpus.
# GRACEFUL-SKIP (harmonized with benchmark/feature regen, session 10): emit to a temp file,
# gcc -c it, and only mv over the committed .s on assembler-accept. A program whose --compile
# crashes/empties or whose .s is assembler-rejected leaves its last-good committed .s UNTOUCHED
# and is flagged — NEVER truncate-then-fail. scrip --compile is deterministic, so an unchanged
# compiler yields no mv and no commit (idempotent). The .s is the honest current output, never pinned.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"
CORPUS="${CORPUS:-$S4E/corpus}"
DEMO="$CORPUS/demos"

if [ ! -x "$SCRIP" ]; then echo "SKIP  scrip not found: $SCRIP"; exit 0; fi
if [ ! -d "$DEMO" ]; then echo "SKIP  corpus demo dir not found: $DEMO"; exit 0; fi
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT   # PER-INVOCATION scratch: /tmp/demo_<name>.* was program-keyed and /tmp/demo_as_err.txt outright fixed, so two seat roots regenerating at once collided (s169 seat2 FINDING §7.5)

cd "$DEMO"
# ⛔⭐⭐ THE REFUSED ARM — A REFUSING PROGRAM'S COMMITTED .s IS A PRE-CUT SNAPSHOT, NOT AN ARTIFACT (hq_P 2026-09-02,
# ceo row regen-demo-s-artifacts-writes-a-refused-marker-for-a-refusing-program).  The graceful-skip above is right for a
# CRASH — a flaky failure must never erase a good .s — but it is WRONG for a construct-ladder REFUSAL, because a refusal
# is not a transient: the compiler ran, understood the program, and declined it by name.  Leaving the last-good .s in
# place then publishes asm that NO CURRENT COMPILER EMITS.  Measured at the rung-6 landing: the four Prolog demo .s
# carried 214 `rt_call_arr_bl` by-name calls that the by-name dispatcher no longer generates at all.
# ⭐ THE DISCRIMINATOR IS POSITIVE EVIDENCE IN STDERR, never an exit code: `is not on the ladder yet` is printed only by
# the ladder's own refusal path, exactly as util_regen_prolog_bench_s_artifacts.sh keys its .s.REFUSED arm (23 markers
# since rung 0).  Only THERE is the destructive delete of a committed .s legitimate.  Everything else — timeout, crash,
# empty emit, assembler-reject — keeps the graceful-skip and leaves the .s untouched.
# ⛔ THE MARKER IS SELF-RETIRING: the first run after that rung lands sees real asm, removes the marker and writes the
# .s, so the tree converges on honest output without anyone remembering to clean up.
emit_one() {   # $1 = source path RELATIVE TO $DEMO (cwd), $2 = committed .s path, $3 = label for the log
    local rel="$1" dst="$2" label="$3" rc=0
    local tmp="$TMPD/emit_$(printf '%s' "$label" | tr -c 'A-Za-z0-9._-' '_').s"
    # ⛔ COMPILE VIA A $DEMO-RELATIVE PATH (cwd is $DEMO), NEVER an absolute path: since perf-per-statement-loc-emission
    # the compiler emits `.file 1 "<path as given>"`, so an absolute path bakes THIS SEAT ROOT into a committed artifact
    # and every other root regenerates it back — a permanent churn war between /home/claude_P and /home/claude_C. hq_P 2026-08-28.
    timeout -k 5 90 "$SCRIP" --compile "$rel" </dev/null >"$tmp" 2>"$TMPD/cerr.txt" || rc=$?
    if [ "$rc" -eq 124 ]; then
        echo "  SKIP  $label — --compile TIMED OUT at 90s (committed .s untouched; a timeout is NOT a refusal)"; return 0
    fi
    if grep -q 'is not on the ladder yet' "$TMPD/cerr.txt"; then
        rm -f "$dst"
        printf 'REFUSED by the construct ladder -- no codegen until its rung lands (%s)\n' \
               "$(sed -nE 's/^scrip: [a-z0-9_]+: (.*is not on the ladder yet -- rung [0-9]+ lands it).*/\1/p' "$TMPD/cerr.txt" | head -1 | cut -c1-110)" > "$dst.REFUSED"
        echo "  REFUSED $label -> $(basename "$dst").REFUSED"; return 0
    fi
    if [ "$rc" -ne 0 ]; then echo "  SKIP  $label — --compile failed rc=$rc (committed .s untouched)"; return 0; fi
    if [ ! -s "$tmp" ];  then echo "  SKIP  $label — empty emit (committed .s untouched)"; return 0; fi
    local sz; sz=$(stat -c %s "$tmp" 2>/dev/null || echo 0)
    if [ "$sz" -gt 52428800 ]; then   # Lon: "we do not want the huge ones"; GitHub refuses a file over 100 MB and warns over 50 MB
        echo "  SKIP  $label — $((sz / 1048576)) MB of asm, over the 50 MB a corpus artifact may be (committed .s untouched)"; return 0
    fi
    if ! gcc -c "$tmp" -o "$TMPD/emit.o" 2>"$TMPD/demo_as_err.txt"; then
        echo "  SKIP  $label — assembler-rejected (committed .s untouched)"; return 0
    fi
    rm -f "$dst.REFUSED"                                   # real asm retires any marker from an earlier rung
    if [ -f "$dst" ] && cmp -s "$tmp" "$dst"; then echo "  same  ${dst#$CORPUS/}"; else mv "$tmp" "$dst"; chmod 644 "$dst"; echo "  upd   ${dst#$CORPUS/}"; fi
}

# THE SANCTIONED SET (widened 2026-07-26 by Lon directive: "get them all but porter stemmer can be excluded";
# narrowed same day: "exclude expression.s also — we do not want the huge ones").
# Was the s151 five (roman wordcount claws5 treebank-list treebank-array) — which silently left hello.s and four
# other legacy artifacts frozen at 2026-06-25 while the compiler moved a month underneath them, and left the ten
# s158 working-set programs with no artifact at all.  TWO PROGRAMS ARE DELIBERATELY ABSENT ON SIZE, NOT ON
# HEALTH — porter (~37k lines of stemmer pattern tables) and expression (~36k) both compile clean and assemble
# clean; they are out because committing them churns ~73k lines on every codegen commit.  Their .s files are
# NOT left behind stale: a name dropped from this list must have its artifact deleted in the same commit, which
# is the whole lesson of the hello.s fossil.  Re-add a name here if the churn is ever wanted.  Largest member
# now is json at ~18k; that is the standing ceiling unless Lon rules otherwise.
DEMOS="roman wordcount claws5 treebank \
       arithmetic counter hello pattern_test \
       calculator-1 calculator-1-match calculator-1-match-fence \
       calculator-2 calculator-2-match calculator-2-match-fence \
       claws5-match claws5-match-fence \
       json json-match json-match-fence \
       treebank-match treebank-match-fence"
# ⛔⭐⭐ RESOLVE EACH NAME TO ITS PATH -- THE FLAT `$f.sno` LOOKUP THIS REPLACED HAD BEEN SILENTLY
# REGENERATING NOTHING SINCE THE s272 CORPUS RE-GRID (hq_P, 2026-08-27).  The re-grid moved demos from
# corpus/demos/<name>.sno to corpus/demos/snobol4/<family>/<name>.sno.  This loop cd'd to corpus/demos and
# tested `[ -f "$f.sno" ]`, so after the move EVERY one of the 21 sanctioned names failed that test, took
# the `continue`, and the script then printed "No changes -- demo artifacts already current."
# ⛔ THAT IS A FALSE GREEN, NOT A GAP: the script reported SUCCESS while doing NOTHING, so the handoff rule
# "if the session touched codegen, regenerate the .s artifacts" has been a no-op for every seat since the
# re-grid, and the committed demo .s files silently froze while the compiler moved underneath them -- the
# exact hello.s fossil this script's own header was written to prevent, reintroduced by a path change.
# MEASURED at the time of the fix: a fresh --compile of calculator-1-match differs from its committed .s
# by 1,749 diff lines, none of them from tonight's cure (it is another seat's label-prefix change).
# ⭐ THE CLASS, and it is the third instance this month: A GUARD OR A LOOKUP KEYED ON A PATH IS NOT KEYED
# ON THE THING, IT IS KEYED ON A COINCIDENCE THAT A REORGANISATION CAN END -- same shape as the inert
# */programs/lon/* guards in util_oracle_flag_sweep.sh and test_gate_argnote_sweep.sh.  Resolving by SEARCH
# and REFUSING on an unresolvable member ties the script to the FILE rather than to its address.
# ⛔ AND THE SKIP IS NOW A REFUSAL, per RULES.md: a tool that cannot do its job exits non-zero rather than
# reporting success.  These 21 names are the SANCTIONED SET -- a member that does not resolve is a real
# error (a renamed or deleted demo), never something to pass over quietly.
echo "Emitting + verifying demo .s (resolve-by-search; refuses on an unresolvable sanctioned name)..."
RESOLVE_RC=0
for f in $DEMOS; do
    hits="$(find "$DEMO" -name "$f.sno" -type f | sort)"
    n="$(printf '%s\n' "$hits" | grep -c . || true)"
    if [ "$n" -eq 0 ]; then
        echo "  ⛔ REFUSE  $f — no $f.sno anywhere under $DEMO (sanctioned set member unresolvable; the corpus moved or the demo was renamed/deleted)"; RESOLVE_RC=2; continue
    fi
    if [ "$n" -gt 1 ]; then
        echo "  ⛔ REFUSE  $f — $n files named $f.sno under $DEMO; ambiguous, not guessing:"; printf '      %s\n' $hits; RESOLVE_RC=2; continue
    fi
    src="$hits"
    emit_one "${src#$DEMO/}" "${src%.sno}.s" "$f"
done

# ⛔⭐⭐ THE PROLOG DEMO ARM -- ADDED 2026-09-02 BECAUSE NOTHING REGENERATED THIS TREE AT ALL.  The row that sent me here
# described the four stale Prolog demo .s as the graceful-skip declining to overwrite them.  ⛔ THAT MECHANISM WAS WRONG,
# AND THE TRUE ONE IS WORSE: the sanctioned set above is 21 SNOBOL4 names resolved as `$f.sno`, so corpus/demos/prolog/**
# was never a candidate for regeneration in the first place -- not skipped, NOT LOOKED AT.  The three chain scripts
# between them walk corpus/benchmarks/snobol4, corpus/demos (the 21 names) and corpus/benchmarks/prolog/bench; the Prolog
# DEMO tree fell in the gap between them and its artifacts had not been regenerated since they were first committed.
# ⭐ SO THIS ARM ENUMERATES BY SEARCH, NOT BY A LIST: every *.pl under $DEMO/prolog, recursively (family_net/ is nested),
# which is the same resolve-by-search discipline the SNOBOL4 arm learned from the re-grid.  A hardcoded roster is what
# put this tree in the gap; adding a second roster would only move the gap.
# ⛔ AND AN ABSENT OR EMPTY TREE IS A REFUSAL, NOT A QUIET SKIP -- that is precisely the false green this file's own
# history is a monument to: if a future re-grid moves the Prolog demos, this arm must say so loudly rather than report
# "artifacts already current" while regenerating nothing.
PLDEMO="$DEMO/prolog"
if [ ! -d "$PLDEMO" ]; then
    echo "  ⛔ REFUSE  prolog demo tree absent: $PLDEMO (the corpus moved, or this root is not stocked) — NOT reporting artifacts current"; RESOLVE_RC=2
else
    pl_srcs="$(find "$PLDEMO" -name '*.pl' -type f | sort)"
    pl_n="$(printf '%s\n' "$pl_srcs" | grep -c . || true)"
    if [ "$pl_n" -eq 0 ]; then
        echo "  ⛔ REFUSE  $PLDEMO holds zero *.pl (an empty demo tree is a moved corpus, never a finished job)"; RESOLVE_RC=2
    else
        echo "Emitting + verifying prolog demo .s ($pl_n program(s), enumerate-by-search)..."
        while IFS= read -r src; do
            [ -n "$src" ] || continue
            emit_one "${src#$DEMO/}" "${src%.pl}.s" "${src#$DEMO/}"
        done <<< "$pl_srcs"
    fi
fi
[ "$RESOLVE_RC" -eq 0 ] || { echo "⛔ GATE REFUSES: one or more sanctioned demo names did not resolve (see above). NOT reporting artifacts current -- that is the false green this refusal exists to stop."; exit "$RESOLVE_RC"; }

# ⛔ REPO GUARD (mirrors util_regen_prolog_bench_s_artifacts.sh): with a CORPUS override pointing outside a git repo the
# old code ran `git diff --cached` in a non-repo, took the non-zero as "there are changes", tried to commit and exited 1.
# A regen that cannot commit has still done its job — say so and leave the artifacts in the worktree.
if ! git -C "$CORPUS" rev-parse --git-dir >/dev/null 2>&1; then
    echo "  SKIP commit — $CORPUS is not a git repo; regenerated artifacts left in the worktree."
    echo "Done."; exit 0
fi
echo "Committing to corpus..."
cd "$CORPUS"
PATHS=()
for f in $DEMOS; do
    d="$(find "$DEMO" -name "$f.s" -type f | sort | head -1)"
    [ -n "$d" ] && PATHS+=("${d#$CORPUS/}")
done
# ⭐ `-A` ON THE PROLOG SUBTREE, not `git add` of found files: this arm DELETES a .s and CREATES a .s.REFUSED, and a
# plain add of existing paths stages the new marker while silently leaving the deletion unstaged — half a cure, committed.
PLREL="${PLDEMO#$CORPUS/}"
[ -d "$PLDEMO" ] && PATHS+=("$PLREL")
[ "${#PATHS[@]}" -gt 0 ] && git add -A -- "${PATHS[@]}" 2>/dev/null
if git diff --cached --quiet -- "${PATHS[@]}"; then
    echo "  No changes — demo artifacts already current."
else
    RUNG="${1:-regen}"
    if git -c user.name="LCherryholmes" -c user.email="lcherryh@yahoo.com" \
           commit -q -m "x64 demo artifacts: $RUNG" -- "${PATHS[@]}"; then
        echo "  Committed:"; git show --stat --oneline HEAD | sed -n '1,40p'
    else
        echo "  COMMIT FAILED — artifacts regenerated and STAGED but NOT committed."; exit 1
    fi
fi
echo "Done."
