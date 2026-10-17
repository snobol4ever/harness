#!/usr/bin/env bash
# test_gate_icn_rundir_contract.sh -- A WITNESS THAT READS ITS ENVIRONMENT IS GRADED WITH THAT ENVIRONMENT
# PRESENT, AND THE GATE PROVES THE ENVIRONMENT IS WHAT MADE THE DIFFERENCE.
#
# ⛔⛔ THE DEFECT THIS GATE STANDS OVER (hq_I, FINDING-2026-09-10; hq_P, CEO-532). rung36_jcon_recent lists
# its own working directory, reads recent.dat from it, and prints getenv("JCONT"). Graded with none of that
# present it printed 313 orderly lines ending in `can't open recent.dat` -- and the ORACLE, starved the same
# way, printed the same 313 lines. The two agreed, so the witness read PASS. ⭐ AGREEING ABOUT WHERE YOU BOTH
# GAVE UP IS NOT AGREEMENT ABOUT THE PROGRAM: the starved output is non-empty, well-formed, byte-identical
# across runs and stable under every check a runner normally makes. Fed, the program answers 443 lines and
# the extra 130 turned out to contain a real open(<directory>) defect. A starved grading is worth exactly the
# width of the question that survived the starvation.
#
# ⛔ SO A GATE THAT ONLY ASKED "does SCRIP match the ref" WOULD HAVE PASSED THROUGHOUT. That is why ARM 3
# exists and why it is not optional: it re-runs each witness with its contract DELIBERATELY SUPPRESSED and
# REQUIRES the answer to change. An instrument that cannot fail prints the same string as one that passed.
#
# THE FOUR ARMS:
#   1 THE CONTRACTED ANSWER MEETS ITS PINNED FLOOR. ⛔ THIS ARM REPLACED A TAUTOLOGY, and the replacement is
#     the lesson: the first version of ARM 1 compared NAME.fixtures/ against its own copy in the rundir, so
#     DELETING a fixture from the declaration made the declaration smaller and ARM 1 passed. My own negative
#     test (remove recogn.dat) then showed something worse -- ⛔ ARM 2 IS STARVATION-BLIND BY CONSTRUCTION:
#     SCRIP and the oracle both starved to 442 lines and AGREED, exactly the class this gate exists over. So
#     no amount of oracle agreement can guard the rundir; only an absolute floor on the ANSWER can, and it is
#     the one arm that still bites on a row whose ref is disputed. A floor that RISES prints a re-pin line
#     (RUNGS_ENTRY_FLOOR's discipline); only a fixture actually retired may lower one, in the commit that
#     retires it. The fixture/rundir copy check is kept underneath it, as a staging assert, not as the guard.
#   2 SCRIP == THE LIVE ARIZONA ORACLE, byte for byte, in that rundir. ⭐ The oracle is COMPILED FROM THE
#     WITNESS'S OWN SOURCE EVERY RUN, never a checked-in ref, so an oracle/SCRIP difference cannot be a
#     ref-drift artifact. Its binary is kept OUTSIDE the rundir -- inside, it would be a directory entry on
#     one side only, which is the confound wearing a smaller face (hq_I's one-directory-same-inode rule).
#   3 KILLSWITCH -- with the contract suppressed the answer MUST differ. Negative-tested, see below.
#   4 REF AGREEMENT -- the checked-in .ref must equal the contracted oracle answer, EXCEPT for the
#     rows pinned in REF_DISPUTED below, which must still DIFFER. A pinned row that starts matching is an
#     XPASS and FAILS, so a ref cure can never land and leave a stale pin behind.
#
# ⛔ REFUSES (rc=2) RATHER THAN SKIPPING: no scrip, no icont, no corpus, an unstageable fixture, or a witness
# whose oracle will not compile is UNPROVEN, never a pass.
#
# NEGATIVE TESTS ACTUALLY RUN (hq_P 2026-09-10, each restored and the gate reconfirmed green afterwards).
# Recorded with the arm that ACTUALLY fired, because two of them fired somewhere other than where I first
# wrote down, and a negative-test record that names the wrong arm is worth less than none:
#   remove recogn.dat from rung36_jcon_recent.fixtures/  -> ARM1 rc=1 (oracle 442 < floor 443)
#   remove io.std from rung36_jcon_io.fixtures/          -> ARM1 rc=1 (oracle 133 < floor 135) ⭐ the
#       REF-DISPUTED row, where ARM4 is muted -- so this is the case that proves ARM1 is not redundant
#       (2026-09-23, CEO-1222: that fixture is now RETIRED -- no .std may remain, and it served only as a NAME
#       io.icn lists -- so its ref was re-cut and its floor re-pinned 133 in the landing that retired it)
#   set JCONT=WRONG in rung36_jcon_recent.env            -> ARM4 rc=1. ⛔ ARM2 stayed GREEN, correctly:
#       both arms read the same wrong environment and agreed about it. That is the whole thesis of this
#       gate reproduced on demand, and it is why ARM2 is never allowed to be the only guard.
#   a line that is not VAR=value in the .env             -> rc=2 REFUSED (was rc=1 before the reader's
#       glob was anchored -- it had accepted `this is not VAR=value` as a variable named `this is not VAR`)
#   an argv sidecar naming another program               -> rc=2 REFUSED by ipl_argv_read's own name check
#   a contracted witness with no contract_floor() line   -> rc=2 REFUSED
#
# EXIT: 0 = every arm green.  1 = a regression.  2 = REFUSED/UNPROVEN.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
. "$HERE/lib_icn_rundir.sh"
. "$HERE/lib_oracle_flags.sh"

SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
CORPUS="${CORPUS:-$S4E/corpus/tests/icon}"
ICONT="$(icont_bin)"

# ⛔ ROWS WHOSE CHECKED-IN .ref DISAGREES WITH THE ARIZONA ORACLE AND IS KNOWN TO COME FROM A DIFFERENT
# ONE. ⭐⭐ EMPTY AS OF 2026-09-10, AND THE ENTRY THAT EMPTIED IT IS THE ARGUMENT FOR THE MECHANISM: this held
# `rung36_jcon_io` because its .expected was a BYTE-FOR-BYTE COPY OF JCON'S OWN io.std -- a JVM-jcon
# reference, not an icont/iconx cut -- disagreeing on 9 `nonseq:` rows where jcon FAILS a seek past
# end-of-file and prints '-' while Arizona SUCCEEDS and prints '?'. SCRIP matched Arizona on every one.
# ⭐ THE PIN WAS AN XPASS TRAP, NOT A MUTE, AND THAT IS WHY IT CLOSED ITSELF: the coo re-cut the ref from
# Arizona icont (corpus 77a835525, confirmed by cutting it independently in their own directory and getting
# a byte-identical result), and ARM 4 went RED THE NEXT TIME THIS GATE RAN -- "XPASS: pinned in REF_DISPUTED
# but the ref now MATCHES the Arizona oracle" -- which is what removed the row. ⛔ A tolerated red recorded
# as a MUTE would have gone on being tolerated after the thing it tolerated was fixed, silently, forever;
# every entry here must keep that property.
# ⚠️ THE COUNT WAS 10 HERE UNTIL 2026-09-10 AND IT IS 9 (hq_P, measured; the ceo's CEO-534 carried the 10 too,
# and corrected it in CEO-536). It came from ARM 4's own REPORTED line, which counted diff's `<` AND `>` and
# called the total "lines" -- on two files of equal length that is exactly twice the truth. ⭐ A GATE THAT
# MISREPORTS ITS OWN NUMBER TEACHES THAT NUMBER TO EVERY READER DOWNSTREAM: the 10 reached a gate header, a
# FINDING and a ceo ruling before anyone re-derived it. The label now says "ref line(s) disagree" and counts
# `<` alone. Kept here after the row itself is gone, because the lesson outlives the dispute.
REF_DISPUTED=""

# ⭐ THE ANSWER FLOOR, one row per contracted witness: the number of lines the LIVE ORACLE produces in the
# fully-armed rundir. It is the only thing standing between this gate and a silently shrinking contract --
# see ARM 1 in the header. Measured hq_P 2026-09-10, icont/iconx v9.5.25a, three runs each byte-identical.
# ⭐ SIX ROWS ADDED 2026-09-10 (hq_P, on the coo's routed finding). They are not new witnesses -- they were
# always here, carrying a stdin sidecar, and this gate COULD NOT SEE THEM: it discovers its population with
# icn_rundir_declares(), which tested argv/fixtures/env and not stdin, so the contract's own gate graded 2 of
# the 8 contracted witnesses. ⛔ All six measured with the LIVE ORACLE in the fully-armed rundir, by the same
# method this gate uses; the two pre-existing pins (io 135, recent 443) were RE-DERIVED by that method first
# and reproduced exactly, which is what makes the six trustworthy rather than merely plausible. SCRIP agrees
# with the oracle on all eight at the tree that pinned them.
# (2026-09-24: seven. rung36_jcon_others is rungs entry 824 since 09-11 and its loose pair is deleted; its floor went with it.)
contract_floor() {
    case "$1" in
        rung36_jcon_io)      echo 133 ;;   # 135 until 2026-09-23: the retired io.std fixture was two listed names
        rung36_jcon_recent)  echo 443 ;;
        rung36_jcon_btrees)  echo 30  ;;
        rung36_jcon_geddump) echo 313 ;;
        rung36_jcon_prefix)  echo 8   ;;
        rung36_jcon_profsum) echo 62  ;;
        rung36_jcon_recogn)  echo 8   ;;
        *)                   echo "" ;;
    esac
}

fail=0; refuse=0; checked=0
refuse() { echo "⛔ GATE REFUSES(2): $*" >&2; exit 2; }

[ -x "$SCRIP" ]  || refuse "no scrip binary at $SCRIP -- build it; an unmeasured gate must not report green"
[ -d "$CORPUS" ] || refuse "no corpus at $CORPUS"
[ -x "$ICONT" ]  || refuse "no icont at $ICONT -- the Arizona oracle is reached by ABSOLUTE PATH, never by \`command -v\` (every oracle here lives off PATH by design)"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

# every witness that declares a run-directory contract, discovered, never listed
WITNESSES=()
for icn in "$CORPUS"/*.icn; do
    [ -f "$icn" ] || continue
    icn_rundir_declares "$icn" && WITNESSES+=("$icn")
done
[ "${#WITNESSES[@]}" -gt 0 ] || refuse "no witness in $CORPUS declares a run-directory contract -- this gate would be vacuous"

for icn in "${WITNESSES[@]}"; do
    name="$(basename "$icn" .icn)"; checked=$((checked+1))
    stdin_file="$(icn_rundir_stdin "$icn")"
    # ⛔ `cmd || rc=$?` and never `cmd; [ $? -eq 2 ] && …`: this gate does not set -e today, but its twin
    # test_icon_all_rungs.sh does, and there the second form silently aborted the whole board mid-list.
    # One idiom in both places, so nobody has to know which file is which.
    declare -a rd_argv=() rd_env=(); declare rd_rc
    rd_rc=0; icn_rundir_argv "$icn" rd_argv || rd_rc=$?
    [ "$rd_rc" -eq 2 ] && refuse "$name: malformed argv declaration"
    rd_rc=0; icn_rundir_env "$icn" rd_env || rd_rc=$?
    [ "$rd_rc" -eq 2 ] && refuse "$name: malformed env declaration"
    # ⛔ THE FLOOR IS CHECKED FOR EXISTENCE HERE, BEFORE ANY WORK, not where it is USED further down. A
    # witness with no floor would otherwise reach the oracle compile first and refuse for whatever it found
    # there, reporting the second-most-interesting thing about itself.
    floor="$(contract_floor "$name")"
    [ -n "$floor" ] || refuse "$name declares a run-directory contract but has no line in contract_floor() -- a contracted witness with no floor is unguarded against fixture loss, which is the whole defect this gate stands over. Measure it and pin it."

    dir="$(icn_rundir_make "$icn" "$WORK")" || refuse "$name: could not stage the declared fixtures"
    fixdir="${icn%.icn}.fixtures"
    if [ -d "$fixdir" ]; then
        for f in "$fixdir"/*; do
            [ -e "$f" ] || continue
            cmp -s "$f" "$dir/$(basename "$f")" || { echo "FAIL STAGING $name: declared fixture $(basename "$f") did not reach the rundir"; fail=$((fail+1)); }
        done
    fi

    # ---- ARM 2: SCRIP == the live Arizona oracle, in that rundir, oracle binary kept OUTSIDE it
    obin="$WORK/$name.oracle"
    if ! ( cd "$dir" && "$ICONT" -s -o "$obin" "$icn" ) >"$WORK/$name.icont.log" 2>&1; then
        refuse "$name: the oracle would not compile -- $(head -3 "$WORK/$name.icont.log" | tr '\n' ' ')"
    fi
    o_out="$( cd "$dir" && timeout -k 5 60 env ${rd_env[@]+"${rd_env[@]}"} "$obin" ${rd_argv[@]+"${rd_argv[@]}"} < "$stdin_file" 2>/dev/null )"
    rm -f "$obin"

    # ---- ARM 1: the contracted answer meets its pinned floor (see header -- the only starvation-proof arm)
    o_lines="$(printf '%s\n' "$o_out" | wc -l)"
    if [ "$o_lines" -lt "$floor" ]; then
        echo "FAIL ARM1 $name: the ORACLE answers $o_lines lines in the contracted rundir, below the pinned floor $floor."
        echo "     ⛔ Read this as A FIXTURE WENT MISSING, not as an oracle defect: the program stops where its"
        echo "     environment stops, and SCRIP stops at the same place, so ARM2 will AGREE at the wrong answer."
        fail=$((fail+1))
    elif [ "$o_lines" -gt "$floor" ]; then
        echo "⭐ ARM1 $name: the contracted answer GREW to $o_lines lines (floor $floor) -- re-pin contract_floor() to $o_lines in this commit."
        fail=$((fail+1))
    else
        echo "PASS ARM1 $name (contracted answer $o_lines lines == pinned floor)"
    fi
    s_out="$( cd "$dir" && timeout -k 5 60 env ${rd_env[@]+"${rd_env[@]}"} "$SCRIP" --run "$icn" -- ${rd_argv[@]+"${rd_argv[@]}"} < "$stdin_file" 2>/dev/null )"
    if [ "$s_out" = "$o_out" ]; then
        echo "PASS ARM2 $name (SCRIP == icont/iconx, $(printf '%s\n' "$o_out" | wc -l) lines, contracted rundir)"
    else
        echo "FAIL ARM2 $name: SCRIP differs from the live oracle in its own contracted rundir"
        diff <(printf '%s\n' "$s_out") <(printf '%s\n' "$o_out") | head -12
        fail=$((fail+1))
    fi

    # ---- ARM 3: KILLSWITCH -- suppress the contract, the answer MUST change
    bare="$(mktemp -d "$WORK/bare.XXXXXX")"
    b_out="$( cd "$bare" && timeout -k 5 60 "$SCRIP" --run "$icn" < /dev/null 2>/dev/null )"
    if [ "$b_out" = "$o_out" ]; then
        echo "FAIL ARM3 $name: STARVED AND FED ANSWERS ARE IDENTICAL -- the contract is not load-bearing, so"
        echo "     ARM2's green proves nothing about it. Either the declaration is inert or the witness never"
        echo "     reads its environment, and either way this row must not be counted as contract coverage."
        fail=$((fail+1))
    else
        echo "PASS ARM3 $name (killswitch: starved answer differs, $(diff <(printf '%s\n' "$b_out") <(printf '%s\n' "$o_out") | grep -c '^[<>]') lines)"
    fi

    # ---- ARM 4: ref agreement, with the disputed rows pinned as an XPASS trap
    exp="${icn%.icn}.ref"
    if [ -f "$exp" ]; then
        if printf '%s\n' "$REF_DISPUTED" | grep -qx "$name"; then
            if [ "$(cat "$exp")" = "$o_out" ]; then
                echo "FAIL ARM4 $name: XPASS -- pinned in REF_DISPUTED but the ref now MATCHES the Arizona oracle."
                echo "     The cut has landed: delete '$name' from REF_DISPUTED in this gate, in the same commit."
                fail=$((fail+1))
            else
                echo "REPORTED ARM4 $name: ref DISPUTED as declared ($(diff <(cat "$exp") <(printf '%s\n' "$o_out") | grep -c '^<') ref line(s) disagree) -- the coo holds the cut"
            fi
        elif [ "$(cat "$exp")" = "$o_out" ]; then
            echo "PASS ARM4 $name (checked-in ref == the Arizona oracle in the contracted rundir)"
        else
            echo "FAIL ARM4 $name: the checked-in ref disagrees with the Arizona oracle in the contracted rundir"
            diff <(cat "$exp") <(printf '%s\n' "$o_out") | head -12
            fail=$((fail+1))
        fi
    fi
done

# ---- ARM 5: THE UNDECLARED-STDIN SWEEP -- the OTHER half of the contract, and the silent one
# ⛔ THE DEFECT THIS ARM STANDS OVER (coo -> hq_P, 2026-09-10, out of the rung36_jcon_io ref cut): the entry
# could not reproduce its own ref. io.icn reads stdin SIX different ways at lines 16-21 and eats eight lines
# doing it; the entry declared argv and fixtures and stayed SILENT about the one input that decides eight of
# its lines, and icn_rundir_stdin hands back /dev/null when no sidecar exists. So the witness graded STARVED,
# produced a shorter but perfectly orderly answer, and read as A COMPILER DEFECT. ⭐ Every other arm above
# grades witnesses that DO declare a contract; nothing anywhere graded the ones that should and do not, which
# is the harder direction because the evidence of the omission IS the omission.
# ⛔⭐ THE FIRST CUT OF THIS ARM COMPARED THE ORACLE STARVED VS FED SOME GENERIC BYTES, AND IT WAS NEARLY
# VACUOUS -- proven so by its own fail-once test, which is the only reason it is not still here. Hiding
# rung36_jcon_geddump's sidecar (a witness whose oracle answers 313 lines fed and 0 starved) did NOT red it:
# geddump rejects arbitrary bytes exactly as it rejects EOF, so fed and starved agreed and it passed. ⭐ THE
# SAME BLIND SPOT HAD ALREADY MISREAD geddump AND profsum ONCE, in the census that motivated this arm. An
# instrument whose failures and successes look alike is worth less than no instrument, because it also
# reports a number.
# ✅ THE DISCRIMINATOR IS NOW "DOES IT READ STDIN AT ALL", NOT "DOES ITS ANSWER CHANGE", and it is
# program-agnostic: stdin is a FIFO HELD OPEN BY A WRITER THAT SENDS NOTHING. A program that reads stdin
# BLOCKS on it (timeout, rc 124); one that never reads runs to completion untouched. No knowledge of any
# witness's input format is needed, which is exactly what the byte-feeding version required and could not have.
# ⛔ WITH A CONTROL ARM, because "it blocked" has a second explanation: the same program is also run against
# /dev/null, and a witness that fails to finish THERE TOO is slow or looping, not stdin-hungry, and is
# excluded rather than convicted. Conviction needs BOTH: blocks on the fifo AND completes on /dev/null.
# Graded on icont, never on us, so a SCRIP bug can neither raise nor suppress a finding here.
sweep=0; suspects=0; undecided=0
for icn in "$CORPUS"/*.icn; do
    b="$(basename "$icn" .icn)"
    [ -f "$CORPUS/$b.ref" ] || continue                           # ungraded: no verdict depends on its stdin
    # ⛔ THE SAME POPULATION AS BEFORE CEO-1222, STATED INSTEAD OF IMPLIED BY AN EXTENSION: a .expected here meant a
    # loose rung witness graded by the rung runners, and now that every expected output is a .ref the extension alone
    # would also sweep the containers (fed their NAME.in by the suite harness) and the loose non-rung pairs.
    case "$b" in rung[0-9][0-9]_*) ;; *) continue ;; esac
    grep -qE '^#-{3,} [0-9]+ [^[:space:]]' "$icn" && continue
    [ "$(icn_rundir_stdin "$icn")" = /dev/null ] || continue      # already declares one; arms 1-4 own it
    sweep=$((sweep+1))
    (cd "$WORK" && "$ICONT" -s -o "$WORK/$b.a5" "$icn") >/dev/null 2>&1 || continue
    ( cd "$WORK" && timeout -k 5 10 "./$b.a5" </dev/null >/dev/null 2>&1 ); a5_bare=$?
    fifo="$WORK/$b.fifo"; rm -f "$fifo"; mkfifo "$fifo" || { rm -f "$WORK/$b.a5"; continue; }
    sleep 12 > "$fifo" & a5_hold=$!                               # holds the write end open, sends nothing
    ( cd "$WORK" && timeout -k 5 5 "./$b.a5" <"$fifo" >/dev/null 2>&1 ); a5_fifo=$?
    kill "$a5_hold" 2>/dev/null; wait "$a5_hold" 2>/dev/null; rm -f "$fifo" "$WORK/$b.a5"
    if [ "$a5_fifo" = 124 ] && [ "$a5_bare" != 124 ]; then
        echo "FAIL ARM5 $b: the ORACLE BLOCKS waiting on stdin, and this witness declares no stdin sidecar."
        echo "     ⛔ It is being graded against /dev/null in silence -- it reads an input nothing declares."
        echo "     Cut the sidecar (NAME.stdin beside the .icn, or config/NAME.stdin) from the input its ref"
        echo "     was cut with. Do NOT read the short answer as a compiler defect: that is what this looks"
        echo "     like from the board, and it is the whole reason this arm exists."
        suspects=$((suspects+1)); fail=$((fail+1))
    elif [ "$a5_fifo" = 124 ]; then
        undecided=$((undecided+1))
        echo "REPORTED ARM5 $b: blocks on a held-open stdin AND does not finish on /dev/null either -- slow or"
        echo "     looping, not necessarily stdin-hungry. Excluded from the verdict rather than convicted."
    fi
done
[ "$sweep" -gt 0 ] || refuse "ARM 5 examined no witness at all -- every graded witness appears to declare a stdin sidecar, which is not a state this corpus has ever been in. The sweep is vacuous, and a vacuous arm prints the same green as a passing one."
# ⛔ THE VERDICT WORD MUST FOLLOW THE COUNT BESIDE IT. This line read "PASS ARM5 ... 1 starved silently" in
# its first cut -- a summary announcing PASS while printing its own failure count on the same line. That is
# the misreporting class this gate's own header already carries a scar from (ARM 4's doubled ref count), and
# it is worse in a summary line, because a summary is the line a reader trusts INSTEAD of reading the body.
if [ "$suspects" -eq 0 ]; then
    echo "PASS ARM5 ($sweep graded witness(es) with no stdin sidecar swept, none starved, $undecided undecided)"
else
    echo "FAIL ARM5 ($sweep swept, $suspects STARVED SILENTLY, $undecided undecided) -- named above"
fi

echo "--- $checked witness(es) with a declared run-directory contract; $fail failure(s)"
[ "$fail" -eq 0 ] || exit 1
echo "✅ GATE PASS: every declared run-directory contract materializes, is load-bearing, grades SCRIP equal to the live Arizona oracle, and no graded witness outside the contract is silently starved of stdin."
