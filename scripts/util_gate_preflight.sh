#!/usr/bin/env bash
# util_gate_preflight.sh -- THE PRE-LANDING PREFLIGHT FOR ONE GATE FILE (ceo CEO-432 item 3, ordered again in
# CEO-441 item 7 as hq_T's first instrument).  Run it on the gate you are about to push.
#
#     bash ../harness/scripts/util_gate_preflight.sh test_gate_sno_dump_matches_spitbol.sh
#     bash ../harness/scripts/util_gate_preflight.sh --all          # the same checks over every gate on disk
#
# ⛔ WHY A PER-FILE TOOL WHEN TWO FLEET-WIDE CENSUSES ALREADY EXIST.  They do, and they work -- ARM 15 of
# test_gate_runners_refuse_on_a_stale_binary.sh names any scrip-executing gate with no freshness guard, and
# util_gate_wiring.py names any gate that landed in no recipe.  Both of them fire INSIDE `make test`, which
# means they fire in EVERYBODY ELSE'S sitting, about a file one seat pushed.  That is the wrong moment and the
# wrong person: hq_S measured it when test_gate_sno_fence_body_dynamic_operand.sh landed unwired and the gate
# that could have graded its cure was run by nothing for a day, and the ceo measured it again the night
# test_gate_define_alternate_entry.sh landed unwired AND with the S4E_HOME root defect -- reds that arrived in
# other seats' `make test`, hours after the author had moved on.  ⭐ THE POINT IS NOT A NEW CHECK.  It is the
# SAME checks, addressable by one file name, cheap enough to run before the push, so the debt is paid by the
# seat that created it while the file is still in front of them.
#
# ⛔⭐ AND IT DELEGATES EVERY CHECK IT CAN, WHICH IS THE ONLY WAY THIS FILE IS ALLOWED TO EXIST.  The freshness
# population rule is gate_file_executes_scrip/gate_file_has_fresh_guard in lib_gate.sh -- EXTRACTED from ARM 15
# and now called by both, so the census and the preflight cannot disagree about the same file.  The wiring
# question is `util_gate_wiring.py reach`, the one authority on what `make test` actually runs.  This lane has
# measured the cost of copy number two more than once (gate_require_fresh vs assert_binary_current: cured in
# one, regenerated in the other, cured a SECOND time nine days later); a preflight that re-spelled either rule
# would tell the seat "clean" while the census that gates the fleet says "uncovered", and the seat would
# believe the instrument that ran first.
#
# THE SEVEN CHECKS, and what each one has actually caught:
#   1 EXISTS + is a readable regular file                        -- refuses rc=2, never a verdict on nothing.
#   2 SHEBANG                                                    -- shape only; the recipe says `bash <file>`.
#   3 FRESHNESS: executes ./scrip => carries the guard           -- ARM 15's rule, asked one file at a time.
#   4 ROOT NOT RESOLVED FROM BARE $S4E_HOME                      -- the cfo's 2026-09-09 class: S4E_HOME is the
#     SEAT root (/home/claude_T), not the checkout (/home/claude_T/SCRIP), so a gate that reads it as the
#     checkout finds every path MISSING for any seat that exports it -- and PASSES inside `make test`, where
#     S4E_HOME is unset.  ⭐ THE DANGEROUS HALF IS THAT IT IS GREEN WHERE IT IS TESTED: the author runs
#     `make test`, sees green, and the gate is red for every DONE-WHEN in the fleet, which all export S4E_HOME.
#   5 WIRING                                                     -- reachable from a recipe, or declared out
#     with a reason in gate_wiring.tsv; landed-unwired-and-undeclared is the defect.
#   6 A REFUSAL PATH (rc=2)                                      -- "I could not measure" must be sayable.
#   7 A PRINTED DENOMINATOR                                      -- a green that examined nothing is the
#     original sin of this whole family (31 of 105 gates could not say no, seat16's audit).
#
# EXIT: 0 every check clean · 1 at least one check RED · 2 REFUSED (the file is not there, or an authority
# this tool delegates to is missing).  ⛔ NEVER 0 on a file it could not read: that is the shape it grades for.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
GATE_NAME=util_gate_preflight
. "$HERE/lib_gate.sh"
command -v gate_file_executes_scrip >/dev/null 2>&1 || {
    echo "⛔ REFUSED(2) [$GATE_NAME]: lib_gate.sh carries no gate_file_executes_scrip -- the freshness population rule is not"
    echo "   reachable, and re-spelling it here is exactly what this tool exists not to do."; exit 2; }

ALL=0; ARGS=()
while [ $# -gt 0 ]; do
    case "$1" in
        --all) ALL=1 ;;
        -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
        --) shift; break ;;
        -*) echo "⛔ REFUSED(2) [$GATE_NAME]: unknown flag '$1' -- implemented: --all"; exit 2 ;;
        *) ARGS+=("$1") ;;
    esac; shift
done
[ $# -gt 0 ] && ARGS+=("$@")
if [ "$ALL" = 0 ] && [ "${#ARGS[@]}" -eq 0 ]; then
    echo "⛔ REFUSED(2) [$GATE_NAME]: name a gate, or pass --all"
    echo "   usage: bash ../harness/scripts/util_gate_preflight.sh <gate>[.sh] ...   |   bash ../harness/scripts/util_gate_preflight.sh --all"
    exit 2
fi

# ⭐ THE REACHABLE SET IS READ ONCE, not once per file: `reach` walks the Makefile and every list, and asking it
# 330 times under --all turns a 0.3s preflight into a minute nobody spends.
REACH=""
if [ -f "$HERE/util_gate_wiring.py" ]; then
    REACH="$(python3 "$HERE/util_gate_wiring.py" reach 2>/dev/null)" || REACH=""
fi
[ -n "$REACH" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: util_gate_wiring.py reach returned nothing -- the wiring authority is"
                     echo "   unreadable, and a preflight that silently skipped the wiring check would report the comfortable half."; exit 2; }
WIRING_TSV="$HERE/gate_wiring.tsv"

files=(); if [ "$ALL" = 1 ]; then
    for f in "$HERE"/test_gate_*.sh; do files+=("$f"); done
else
    for a in "${ARGS[@]}"; do
        case "$a" in */*) p="$a" ;; *) p="$HERE/$a" ;; esac
        [ -e "$p" ] || [ "${p%.sh}" = "$p" ] && [ ! -e "$p" ] && p="$p.sh"
        files+=("$p")
    done
fi

red_total=0; examined=0; red_files=""
for f in "${files[@]}"; do
    name="$(basename "$f")"
    red=0; note=0
    say() { case "$1" in ok) printf '  ok    %s\n' "$2" ;; RED) printf '  ⛔RED %s\n' "$2"; red=$((red+1)) ;; note) printf '  --    %s\n' "$2"; note=$((note+1)) ;; esac; }
    echo "=== $name ==="
    # 1 EXISTS
    if [ ! -f "$f" ] || [ ! -r "$f" ]; then
        echo "  ⛔ REFUSED(2): not a readable file: $f"
        red_total=$((red_total+1)); red_files="$red_files $name"; continue
    fi
    examined=$((examined+1))
    say ok "exists and is readable"
    # 2 SHEBANG
    head -1 "$f" | grep -q '^#!' && say ok "carries a shebang" || say note "no shebang (the recipe says \`bash <file>\`, so this is shape only)"
    # 3 FRESHNESS
    if gate_file_executes_scrip "$f"; then
        gate_file_has_fresh_guard "$f"; _fg=$?
        # ⛔⭐ rc=2 IS "I COULD NOT READ IT", NOT "IT HAS NO GUARD" (hq_T 2026-09-09). This tool tells an author to EDIT a
        # file; sending them to edit one whose guard-check merely failed to complete is a false RED, and the author will
        # add a second guard line to a file that already has one. See gate_file_has_fresh_guard's header for the measured
        # case (three different innocent files accused across two runs of ARM 15).
        if [ "$_fg" = 2 ]; then
            say note "UNMEASURED: the guard check could not be established for this file -- two reads disagreed. NOT an accusation; re-run."
        elif [ "$_fg" = 0 ]; then
            say ok "executes ./scrip AND carries the staleness preflight"
        else
            say RED "EXECUTES ./scrip WITH NO FRESHNESS GUARD -- it will grade whatever binary lies in the tree and"
            echo "        stamp that verdict with a git SHA that is not evidence about the artifact that ran."
            echo "        cure: add as line 2 --"
            echo '        "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?'
        fi
    else
        say ok "does not execute ./scrip -- freshness N/A"
    fi
    # 4 ROOT FROM BARE $S4E_HOME -- ⛔⭐ READ THE DEFAULT, NOT THE USES.
    #
    # THE DEFECT (cfo, measured 2026-09-09): test_gate_preflight_arms_stay_cheap.sh resolved its checkout root
    # as ROOT="${S4E_HOME:-$(cd "$HERE/../../SCRIP" && pwd)}".  S4E_HOME is the SEAT root (/home/claude_T); the checkout
    # is /home/claude_T/SCRIP.  Every DONE-WHEN exports S4E_HOME, so for every seat all 33 arms read MISSING and
    # the gate exited 1 -- while PASSING inside `make test`, where S4E_HOME is unset.  ⭐ Green exactly where its
    # author tests it, red everywhere it is actually used.
    #
    # ⛔ THE FIRST DRAFT OF THIS CHECK COULD NOT SEE THAT FILE, which is why the rule below is what it is.  It
    # looked at how the variable was USED -- $V/scrip, $V/src, $V/Makefile -- and the defective gate uses neither:
    # it says `cd "$ROOT"` and "$ROOT/$script".  So the check passed the one file it was written for, and instead
    # named test_gate_no_weak_abort_stub.sh, which is CORRECT.  Wrong on both files, in both directions, from a
    # rule that sounded reasonable.  ⭐ The fix is not a longer list of uses: it is to stop guessing from uses at
    # all.  The `${S4E_HOME:-<default>}` idiom STATES what the author believes S4E_HOME is, in the default, and
    # that belief is the whole defect -- so read the default and classify it:
    #     $HERE/../..  ·  $(dirname $0)/../..  ·  $ROOT/..     -> the SEAT root.  Correct, this is the convention.
    #     $HERE/../../SCRIP     ·  $ROOT               ·  $(dirname $0)/../../SCRIP  -> the CHECKOUT.  The author has it backwards.
    # Exact, not heuristic, and it needs no list of the ways a path can later be spelled.
    body="$(grep -vE '^[[:space:]]*#' "$f")"
    bad_root=""; soft_root=""
    while IFS= read -r ln; do
        grep -qE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=.*\$\{S4E_HOME:-' <<<"$ln" || continue
        v="$(sed -E 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=.*/\1/' <<<"$ln")"
        [ "$v" = "S4E_HOME" ] && continue          # re-exporting the seat root under its own name is not this defect
        dflt="${ln#*\$\{S4E_HOME:-}"
        grep -q '/SCRIP' <<<"$dflt" && continue                     # spelled the checkout out; nothing to infer
        grep -qE '\.\./\.\.|\$\{?ROOT\}?/\.\.|\$\{?R\}?/\.\.' <<<"$dflt" && continue   # -> the SEAT root: correct
        grep -qE '/\.\.|\$\{?ROOT\}?' <<<"$dflt" || continue        # unrecognised default: say nothing, guess nothing
        # ⭐ SEVERITY SPLIT.  A gate that ALSO reaches a /SCRIP-qualified path still resolves correctly today --
        # its first try is simply the wrong one and the fallback is load-bearing (the cfo's words for hq_P's
        # test_gate_define_alternate_entry.sh: "a fallback that papers over it").  That is a different fact from
        # "reads MISSING for the whole fleet", and flattening the two into one RED is how a census stops being read.
        if grep -qE "\\\$\\{?$v\\}?/SCRIP/|$v=[^=]*/SCRIP" <<<"$body"; then soft_root="$soft_root $v"
        else bad_root="$bad_root $v"; fi
    done <<<"$body"
    if [ -n "$bad_root" ]; then
        say RED "READS \$S4E_HOME AS THE CHECKOUT ($bad_root) -- its default resolves ONE level up from ../harness/scripts/,"
        echo "        so the author has taken S4E_HOME for the checkout. It is the SEAT root: /home/claude_T, not"
        echo "        /home/claude_T/SCRIP. Every DONE-WHEN exports it, so this gate reads MISSING for the whole fleet"
        echo "        while PASSING inside \`make test\`, where S4E_HOME is unset. (cfo 2026-09-09: 33 arms MISSING, rc=1.)"
        echo "        cure: ROOT=\"\$(cd \"\$HERE/../../SCRIP\" && pwd)\"   -- and \$S4E_HOME/SCRIP where the SEAT root is what you meant."
    elif [ -n "$soft_root" ]; then
        say note "assigns$soft_root from \$S4E_HOME as if it were the checkout, but reaches a /SCRIP-qualified path"
        echo "        too, so it resolves correctly today -- the fallback is load-bearing, and the first path tried is wrong."
    else
        say ok "the checkout root is not taken from \$S4E_HOME"
    fi
    # 5 WIRING -- delegated whole to util_gate_wiring.py, the one authority on what a recipe actually runs.
    # hq_S's measured case: test_gate_sno_fence_body_dynamic_operand.sh landed in the same push as the cure it
    # grades, in no recipe, and for a day the one instrument that could grade that cure was run by nothing.
    # ⛔ NOTHING COULD HAVE NOTICED -- it was green by hand, ls found it, the commit looked complete, and every
    # board was byte-identical with and without the cure BY CONSTRUCTION. An unwired gate is indistinguishable
    # from a wired one by every check except reading the recipe.
    # ⛔ A util_* IS NOT A GATE AND MUST NOT BE GRADED AS ONE. Caught by running this tool on the first file
    # written after it: util_icon_ref_provenance.sh came back RED as "landed unwired", which is a category
    # error -- a util is reached by its CALLERS, and gate_wiring.tsv's population is ../harness/scripts/test_gate_*.sh by
    # construction. ⭐ An instrument that answers the same question of every input it is handed will be wrong
    # about every input that is not the kind it was built for, and it will be wrong CONFIDENTLY.
    if [ "${name#test_gate_}" = "$name" ]; then
        say note "not a test_gate_* file -- wiring N/A (a util is reached by its callers, not by a recipe)"
    elif grep -qx "$name" <<<"$REACH"; then
        say ok "reachable from \`make test\` / test-postoffice / preflight"
    elif [ -f "$WIRING_TSV" ] && grep -qE "^$name	(RULING|TASK)" "$WIRING_TSV"; then
        cls="$(grep -E "^$name	" "$WIRING_TSV" | cut -f2 | head -1)"
        say note "not in a recipe, but DECLARED $cls in gate_wiring.tsv (out on purpose, with a reason)"
    else
        say RED "LANDED UNWIRED AND UNDECLARED -- on disk, in no recipe, in no list: it is run by nothing."
        echo "        cure: add it to the Makefile \`test:\` recipe, or rule it out WITH A REASON --"
        echo "        python3 ../harness/scripts/util_gate_wiring.py declare $name RULING \"<why it is deliberately out>\""
    fi
    # ⭐ THE DELEGATED BODY IS PART OF THE FILE FOR CHECKS 6 AND 7.  A gate whose whole body is
    # `. .../lib_port_trace.sh; port_trace_main "$@"` or `exec python3 .../util_score_row.py agree` carries none
    # of its own machinery and is CORRECT -- the shared body has it.  Reading only the named file calls all six
    # port-trace gates and score_tables_agree defective, which is a false RED on the files that best follow the
    # one-body rule this lane spent a week landing.
    deleg=""; delegated_names=""
    while IFS= read -r ln; do
        case "$ln" in
            *". \""*|*"source \""*|*". $"*|*"source $"*)
                d="$(grep -oE '/(lib_[A-Za-z0-9_]+\.sh)' <<<"$ln" | head -1 | tr -d /)"; ;;
            *) d="$(grep -oE '\b(exec[[:space:]]+)?(python3|bash)[[:space:]]+[^|;&]*/(util|lib|corpus)_[A-Za-z0-9_]+\.(py|sh)' <<<"$ln" \
                    | grep -oE '(util|lib|corpus)_[A-Za-z0-9_]+\.(py|sh)' | head -1)" ;;
        esac
        [ -n "${d:-}" ] && [ -f "$HERE/$d" ] && { deleg="$deleg $HERE/$d"; delegated_names="$delegated_names $d"; }
    done <<<"$body"
    # ⛔⭐ NO PIPELINE HERE, AND THE REASON IS A FALSE RED THIS FUNCTION PRODUCED WHILE BEING WRITTEN.  It was
    # `grep -v '^#' "$g" | grep -qE "$pat"` -- and under `set -o pipefail` the -q grep EXITS EARLY on its first
    # match, which kills the upstream grep with SIGPIPE (141), which pipefail then reports as the PIPELINE's
    # status.  So the match SUCCEEDING made the test FAIL: util_score_row.py carries sixteen refusal lines and
    # this gate was told it had none.  ⭐ That is the digest's own `$?`-after-a-pipeline trap ("$? reports the
    # LAST command's status, not the one you care about") wearing its other face -- here the last command
    # succeeded and an EARLIER one was killed BY that success.  Capture first, then test.
    reach_body() { local pat="$1" g gb; grep -qE "$pat" <<<"$body" && return 0
                   for g in $deleg; do gb="$(grep -vE '^[[:space:]]*#' "$g")"; grep -qE "$pat" <<<"$gb" && return 0; done; return 1; }
    # 6 A REFUSAL PATH
    if reach_body 'exit 2|return 2|gate_require|REFUS'; then
        say ok "has a refusal path (rc=2 is sayable)${delegated_names:+ [via$delegated_names]}"
    else
        say RED "NO rc=2 REFUSAL PATH -- it cannot distinguish \"clean\" from \"I could not measure\", which is the"
        echo "        one distinction lib_gate.sh's three exit codes exist for.  A gate handed an empty tree that"
        echo "        exits 0 closes every DONE-WHEN citing it on a lie (seat16's audit: 31 of 105 gates)."
    fi
    # 7 A PRINTED DENOMINATOR -- ⛔ THIS ONE IS DELIBERATELY A NOTE AND NEVER A RED, AND THE REASON IS THE
    # MEASUREMENT THAT BUILT IT.  The first draft grepped for denominator-shaped text and named 224 of 330 gates;
    # every widening of the pattern shrank the list (224 -> 64 -> 50 -> 35) and EVERY FILE SAMPLED OUT OF THE
    # SURVIVORS WAS CORRECT -- test_gate_icn_no_stack prints "count N <= ceiling M", test_gate_sm_dead prints a
    # live-reference count, test_gate_sno_dump_matches_spitbol prints "graded=$GRADED".  ⭐ The class of honest
    # shapes is OPEN-ENDED (denominators, ceilings, occurrence counts, delegated bodies), so each new pattern is
    # a guess, and the guess fails in the direction that destroys the instrument: a false RED on a correct file
    # is what teaches a seat to stop reading the preflight.  What IS establishable textually is the narrow
    # question -- does it route through gate_verdict, the one authority that prints `examined N` itself.  The
    # BEHAVIOURAL question ("would it say green having examined nothing") already has an instrument that answers
    # it by execution rather than by reading: test_gate_gates_can_say_no.sh injects an empty tree.  So this check
    # states what it established, names what it did not, and points at the thing that can.
    if reach_body 'gate_verdict'; then
        say ok "routes its verdict through gate_verdict, which prints \`examined N\`${delegated_names:+ [via$delegated_names]}"
    else
        say note "prints its own verdict rather than calling gate_verdict -- whether that verdict states a"
        echo "        population is NOT established by reading the text (see this check's header note). The"
        echo "        behavioural answer comes from: bash ../harness/scripts/test_gate_gates_can_say_no.sh"
    fi
    if [ "$red" -gt 0 ]; then red_total=$((red_total+red)); red_files="$red_files $name"; fi
done

echo "------------------------------------------------------------"
if [ "$examined" -eq 0 ]; then
    echo "⛔ REFUSED(2) [$GATE_NAME]: graded ZERO gate files -- a runner that cannot measure never prints the success shape"
    exit 2
fi
if [ "$red_total" -ne 0 ]; then
    echo "⛔ PREFLIGHT FAIL(1): $red_total defect(s) over $examined gate file(s) --$red_files"
    exit 1
fi
echo "✅ PREFLIGHT PASS(0): $examined gate file(s), 0 defects"
exit 0
