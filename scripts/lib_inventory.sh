#!/usr/bin/env bash
# lib_inventory.sh — THE ONE PACKAGE-INVENTORY BODY. Sourced by every package runner; never copied.
#
# ⭐ THE ORDER (Lon 2026-09-06, in-chat to ceo, verbatim: "Fix the never graded business. Let's lock
# down our package testing and make it complete."). Every program a vendored package SHIPS is either
# GRADED against the package's own oracle or NAMED UNGRADABLE with the oracle's reason. Never dropped,
# never counted as passed. The denominator is the SHIPPED population.
#
# ⛔⭐ WHAT THIS REPLACES, AND WHY A SINGLE `gap=` WAS THE DEFECT. Four runners already printed
# `shipped=N graded=N gap=N` (arizona, jcon, swi, aisnobol). `gap` is ONE bucket holding two things that
# must never be added together: "not graded YET" (work owed) and "CANNOT be graded" (a ruling, with the
# oracle's reason). ⛔ The lockdown's own criterion is `ungraded=0`, and while an ungradable program sits
# inside `gap` that criterion is UNREACHABLE BY BEING CORRECT — a lane can do every piece of real work
# available to it and still never reach the number. So `gap` splits, and the four buckets must SUM to
# shipped, which is what makes the line an inventory rather than four opinions.
#
# ⛔⭐⭐ THE FIFTH NUMBER, AND IT IS INVISIBLE PRECISELY BECAUSE IT LIVES INSIDE `graded` (hq_P 2026-09-06,
# from hq_B's measured case). The snoflake runner compares errors BY NUMBER — deliberately, documented,
# and correctly, since error TEXT cannot match byte-for-byte across implementations. Consequence:
# gimpel's topological-sort scored PASS FOR MONTHS while SCRIP printed its refusal at LINE 0 STATEMENT 0
# and printed it TWICE, against an oracle that prints it once at line 20 statement 5 and HALTS. Same
# integer, three defects. Such a program is NOT ungraded (it ran, it was compared, it matched) and NOT
# honestly graded either (the comparison was narrower than the claim the percent makes). Collapsed into
# `graded`, it lets a lane reach `ungraded=0` with a wrong program still running.
#
# ⭐ SO THE BUCKET IS NAMED FOR THE PROPERTY, NOT THE INSTANCE — hq_T's call, adopted by hq_P over their
# own ask, and the reason is on the record because it is the whole design: a bucket named
# `graded_errno_only` would silently grade every OTHER narrow instrument as an honest pass, and the next
# narrow comparison would land in `graded` and be rediscovered in three weeks with a different integer.
# `graded_narrow` = THE COMPARISON WAS NARROWER THAN THE CLAIM THE PERCENT MAKES. Error-number equality
# is member one, not the definition. Known siblings: grading rc alone with output to /dev/null (hq_I),
# and — hq_P's purest form — AN INSTRUMENT WHOSE SENSITIVITY IS BELOW THE EFFECT IT WAS BUILT TO DETECT
# IS NOT A WEAK TEST, IT IS A TEST THAT CANNOT FAIL, AND IT PRINTS THE SAME STRING AS ONE THAT PASSED
# (a leak check at 200,000 iterations: 1.6MB against an 8MB stack, passing forever).
#
# ⛔ AND EVERY NARROW GRADING NAMES ITSELF PER ENTRY, in NARROW.tsv. hq_P's sentence is the rule:
# AN UNEXPLAINED BUCKET IS JUST A SMALLER LIE. A count with no per-entry reason cannot be acted on and
# cannot be falsified, which is the same failure one size down.
#
# THE LINE, one shape, from every package runner:
#   PACKAGE_INVENTORY package=<name> shipped=N graded=N ungraded=N ungradable=N deferred=N graded_stream=N graded_narrow=N
#
# ⛔⭐⭐ THE SIXTH TERM, `deferred=N`, AND WHY IT IS ON THE LINE RATHER THAN BESIDE IT (hq_T 2026-09-12, ceo
# CEO-593, on Lon's CEO-579 *"Do not count the FD as failures for us."*). DEFERRED means IN SCOPE, NOT BUILT,
# NOT A FAILURE -- a scheduling ruling by Lon, never a fact about the oracle and never a seat's own judgement
# (ARCH-PROGRAM-LEDGER.md § DEFERRED, sovereign; `.github/DEFERRED.tsv` is its machine twin).
# ⛔ IT HAD TO JOIN THE SUM, WHICH IS WHY IT IS NOT A SECOND LINE LIKE THE SPLIT. The split is DETAIL and
# cannot change a total; a deferral is a BUCKET. Without it the five buckets already sum to shipped, so a
# deferred program has to be smuggled into `ungraded` to keep the arithmetic -- and then it is work owed,
# counted against the lane, which is exactly the ruling's opposite. There was no honest bucket for it, and
# a census with no bucket for a real population is the defect this whole library exists to end.
# ⭐ THE NAMES PRINT WITH IT (`inventory_deferred_line`, condition 2 of the ledger's three), because a name
# that cannot be red must be visible instead: A WRONG EXCLUSION COSTS MORE THAN A WRONG CURE (hq_V).
# ⭐ `deferred=0` for every package with a runner today -- the only DEFERRED population is gnu_fd's 30 FD
# programs and nothing grades them yet. The term lands at zero ON PURPOSE: a bucket added at the moment it is
# first needed is a bucket added by whoever needs the number to move.
#
# THE STANZA a runner writes (four tokens, same shape as lib_port_trace.sh's):
#   INV_PACKAGE=gimpel ; INV_DIR="$CORPUS/packages/snobol4/gimpel" ; INV_EXT=".sno"
#   inventory_line "$STREAM_PASSES" "$NARROW_PASSES"
#
# THE SIDECARS, beside the package (or one directory below it, as ipl/progs/UNGRADED.tsv already sits):
#   UNGRADED.tsv    name<TAB>CLASS<TAB>reason   work owed: why it is not graded YET
#                   name is the PACKAGE-RELATIVE PATH (a bare name only while it is unique in the tree)
#   UNGRADABLE.tsv  name<TAB>CLASS<TAB>reason   a ruling: the ORACLE's reason it cannot be graded
#   NARROW.tsv      name<TAB>NARROWING<TAB>reason   graded, but by a comparison narrower than the claim
#
# ⛔ ALL THREE ARE DECLARATIONS, NEVER INFERENCES. A runner may not decide at run time that something is
# ungradable; that is a ruling somebody makes once, in a file, with a reason a later reader can dispute.
#
# ⛔ THE FOURTH DECLARATION IS NOT A SIDECAR, AND THAT IS DELIBERATE: `.github/DEFERRED.tsv`, one file for
# every package, in the repo whose custody is the ceo's. The three above record MEASUREMENTS and the lane
# that measures owns them; a deferral LIFTS A SCORE, so it must not be editable by the lane whose number it
# raises. (`S4E_DEFERRED_TSV` redirects it, for scratch harnesses only.)

# ⛔⭐⭐ THE REASON-CODE VOCABULARY IS CLOSED (hq_T ruling 2026-09-06, asked for by hq_I: three lanes had
# invented three vocabularies in one morning -- CONTAINER_OR_LIBRARY (hq_I, seat03), NO-ORACLE-SHIPPED and
# ORACLE-IS-NOT-PROGRAM-OUTPUT (corpus a1623cf8f), EMPTY and ORACLE_FAIL (ipl/progs) -- in dashes and in
# underscores, for the same handful of situations).
#
# ⭐ THE RULING IS NOT MAINLY A SPELLING. It is that THE TWO FILES ANSWER TWO DIFFERENT QUESTIONS, so their
# class columns are different vocabularies and a class may not drift between them:
#   UNGRADABLE names WHAT THE ORACLE OR THE PACKAGE DID  -- a ruling, disputable, nobody owes work.
#   UNGRADED   names WHAT IS OWED                        -- a task, claimable, somebody can finish it.
# ⛔ So an UNGRADED class that names an OBSERVATION rather than a task is the defect one size down from
# ARM 8's. `EMPTY` is the measured case: 106 ipl rows say `EMPTY` in the class and *"needs a .in with
# representative input, not yet authored"* in the reason -- the file already knows what is owed, and the
# column a reader sorts by does not. A lane cannot pick up 106 rows of `EMPTY`; it can pick up 106 rows of
# NEEDS_STDIN_FIXTURE. Hence the respellings in INV_CLASS_LEGACY, which is DEBT, listed so it shrinks.
#
# ⭐ Spelling is UPPER_SNAKE because four of the five vocabularies already were; the dashed spellings are
# the minority, and a mixed convention means a grep for a class silently answers over a subset.
# THE TEST FOR ADMITTING A NEW UNGRADABLE CLASS IS NOT THE ONE FOR UNGRADED (hq_T, ruling NEEDS_DISPLAY in for
# hq_I 25 ipl gprogs whose oracle answers "cannot open display", 2026-09-06). UNGRADED classes stay coarse
# because the test there is "can a lane pick up every row of this class as ONE task" -- work buckets, and a
# member per situation defeats the point. But nobody owes work on an UNGRADABLE, so that test says nothing, and
# applying it anyway is how ORACLE_REFUSES becomes a bag holding a headless box beside a genuinely broken
# program. THE UNGRADABLE TEST IS: COULD THIS RULING BE OVERTURNED FOR THE WHOLE CLASS AT ONCE? A display is
# exactly that -- one xvfb-run moves all 25 together -- so the class is a handle somebody can grab, which is the
# same underlying property as the UNGRADED test wearing its other face. ORACLE_REFUSES stays for rulings that
# can only ever be revisited one program at a time. Note NEEDS_INTERACTIVE_TTY was already this family; naming
# the principle that admitted it means the next such class needs no HQ round trip.
# NEEDS_NETWORK ADMITTED 2026-10-03 (hq_icon, on Lon's word that terminal and network test programs may be excluded) BY THAT TEST: a unit whose function is to
# talk to a network peer (HTTP) is overturned for the whole class at once by one reachable peer, so it is a handle somebody can grab, and it needed no round trip.
# ⭐⭐ TWO REASONS ADMITTED 2026-09-06 (hq_T ruling, asked for by hq_I off four ipl rows), AND THEY ARE THE
# FIRST TWO WHERE THE LIMIT IS THE INSTRUMENT OR THE BOX RATHER THAN THE PROGRAM OR THE ORACLE. The test they
# had to pass is hq_I's and it is the one to apply to a third: UNGRADABLE MEANS NOBODY OWES WORK, SO EVERY
# REASON MUST TELL A READER SOMETHING THEY CAN ACT ON -- a name that makes a reader re-open a closed ruling has
# NEGATIVE value.
#   RESULT_NOT_ON_STDOUT -- the program's observable result is a WRITTEN FILE; the instrument compares combined
#     stdout+stderr against a .std, so it can only ever pin a 0-byte ref. ⛔ This is the one reason here that is
#     a fact about THE INSTRUMENT, which is why it is not a variant of the others: the rest are closed rulings,
#     this one is OPEN and names a capability the harness lacks (it can neither FEED a named file nor OBSERVE
#     one -- hq_T holds that row, paired with hq_P's declared data-file sidecar gap). Overturned for the whole
#     class at once the day the harness can observe a named output file, which is the UNGRADABLE admission test.
#     ⛔ DO NOT grade these on their error path instead: pinning a program's own complaint as its ground truth
#     grades nothing the program is for and produces a GREEN cell over a program that never did its job. hq_I
#     measured exactly that trap while cutting these three -- idxtext prints 23 bytes at rc=1 on plain text and
#     ZERO bytes at rc=0 on the gettext-format input it is actually for.
#   ENVIRONMENT_IDENTITY_IN_OUTPUT -- the output carries WHO OR WHERE THE RUN HAPPENED (user, host, path), so a
#     ref cut here is valid only here. ⭐ STABLE IN TIME, VARIES IN SPACE, and that axis is kept in this
#     documentation deliberately, because it is what stops the next reader reaching for NONDETERMINISTIC: nobody
#     can fix this by re-running, and a run-twice check sees a byte-stable program and calls the ruling wrong.
#     The name has to say WHERE rather than WHEN.
# ⛔⭐⭐ AND THE ADMISSION TEST ABOVE IS NOT ENOUGH ON ITS OWN -- SHARPENED 2026-09-10 BY THE ROW THAT WAS
#     REFUSED UNDER IT (hq_V's kwds ask, ceo CEO-514; the correction is hq_V's and is recorded here because a
#     ruling's own limits belong beside the ruling and not in a mailbox). The test I offered was CAN ANY
#     ENVIRONMENT MAKE THESE AGREE -- a row whose output no environment can reconcile is a permanent ruling, one
#     that some environment can is deferred work wearing a ruling's clothes. kwds passed that test and was still
#     deferred work: &version &features &allocated &storage genuinely cannot agree across two implementations,
#     and the ruling closed on exactly that permanence -- but THE PROGRAM WAS FREE TO STOP PRINTING THEM, which
#     is what the cure did. It now prints type() of the four, so existence and type stay graded, the values are
#     not, the row is GONE and the program is green in both modes.
#     ⭐ PERMANENCE ABOUT A VALUE IS NOT PERMANENCE ABOUT A PROGRAM. So the question to ask before closing any
#     UNGRADABLE row is not "can any environment make these agree" but "CAN THE PROGRAM BE MADE TO STOP ASKING",
#     and the first reads as the second while quietly answering something weaker. ⛔ It fails in the direction
#     this file's tie-break already calls the expensive one: a permanent-looking fact makes a ruling feel safe
#     to close, and a closed ruling is what nobody re-reads.
# ⭐⭐ ONE REASON ADMITTED 2026-09-13 (ceo CEO-724, on the last member of test_gate_no_ref_pins_oracle_internal_state.sh's
# floor still sitting inside a graded denominator). It is the first one where the oracle RUNS the program fine and
# the ref is still unmatchable, so none of the reasons above fit and reaching for ORACLE_REFUSES would have been a lie.
#   ORACLE_ACCOUNTING_IN_OUTPUT -- the oracle's own output carries ITS OWN INTERNAL ACCOUNTING, so the ref can only be
#     matched by transcribing that engine's state rather than by being correct. SPITBOL prints `memory used (bytes)`,
#     `memory left (bytes)`, `REGENERATIONS`, `stmts executed` and `execution time msec` on an abnormal termination;
#     measured across the 22 csnobol4 refs carrying them the byte counts are all different and one of them moves with
#     the SOURCE FILENAME'S LENGTH (11408 for prog.sno, 11416 for rewind1.sno, measured 2026-09-13).
#     ⛔ IT IS NOT ENVIRONMENT_IDENTITY_IN_OUTPUT AND THE DIFFERENCE IS THE WHOLE POINT: that one varies in SPACE and
#     names WHERE the run happened, so a reader knows no environment can reconcile it. This one varies by
#     IMPLEMENTATION -- it is stable on this box forever and no second engine reproduces it -- and a reader handed the
#     wrong name goes looking for a machine difference that is not there. ⛔ AND IT IS NOT A LICENCE TO NORMALISE: the
#     gate that found the class already ruled that out, because SCRIP prints NOTHING for these lines and a strip broad
#     enough to remove the oracle's accounting reduces the pin to nothing, turning all 22 green over a compiler that
#     emits no report at all.
#     ⭐ ADMISSION TEST, the one this file already applies: can the ruling be overturned for the whole class at once?
#     Yes -- the day a suite's refs are re-cut without the accounting, every member moves together.
#     ⭐ AND hq_V's SHARPENING WAS APPLIED BEFORE ADMITTING IT, not after: the question is not "can any environment make
#     these agree" but CAN THE PROGRAM BE MADE TO STOP ASKING. rewind1 cannot -- it is three vendored lines whose whole
#     purpose is to raise a fatal error, and the accounting is the oracle's death rattle, not the program's output. What
#     the program tested is carried instead by test_gate_sno_rewind_on_an_unopened_unit_raises_174.sh, which grades the
#     SAME semantic through the ONE ERROR VOICE equivalence list in both modes, so leaving the denominator costs no
#     coverage. ⛔ AN EXCLUSION THAT DROPS A BEHAVIOUR NOBODY RE-CHECKS IS THE EXPENSIVE MISTAKE; pair every member of
#     this class with the instrument that keeps its semantic.
# ⛔ CONTAINER_OR_LIBRARY IS RETIRED (ceo CEO-1272, 2026-09-25): it conflated a library owed its driver with a file that is not a
# program. Every one of its 738 rows was split by measurement (corpus 84dadbe33) -- a LIBRARY to UNGRADED NEEDS_DRIVER, a CONTAINER to
# CONTAINERS.tsv -- and the class is no longer a word this vocabulary knows, so a new row using it refuses.
INV_CLASS_UNGRADABLE="NO_ORACLE_SHIPPED ORACLE_REFUSES ORACLE_CONTRACT_NOT_IMPLEMENTED NEEDS_INPUT NEEDS_INTERACTIVE_TTY NEEDS_NETWORK NEEDS_DISPLAY NONDETERMINISTIC RESULT_NOT_ON_STDOUT ENVIRONMENT_IDENTITY_IN_OUTPUT ORACLE_ACCOUNTING_IN_OUTPUT"
# THE TIE-BREAK, AND IT IS THE MOST LOAD-BEARING SENTENCE IN THIS FILE (hq_T, ruling hq_P's three gimpel
# ERROR-285 drivers, 2026-09-06). hq_P found three rows whose bucket turns on ONE UNMEASURED FACT: FRSORT,
# TIMEGC and TIMER die "include file cannot be opened" because the include chain wants stringout.sno,
# resolution.sno and system.inc, which exist nowhere in corpus. If gimpel never shipped them, that is a ruling
# about the package. If upstream ships them and we failed to vendor them, it is work we owe. hq_P established
# only the absence, said so, and refused to decide it by picking the class that made their own line sum -- which
# is the behaviour the whole lockdown depends on and is worth more than the answer.
# WHEN THE BUCKET TURNS ON A FACT NOBODY HAS MEASURED, THE ANSWER IS UNGRADED. The two errors are not
# symmetric: a wrong UNGRADABLE removes a program from the debt PERMANENTLY and silently -- nobody re-reads a
# closed ruling -- while a wrong UNGRADED merely looks like unfinished work, which is what it will look like
# anyway until someone measures. One failure mode hides work forever; the other costs a row that stays open.
# So the missing measurement never blocks the landing: it can only ever move a row FROM ungraded TO ungradable,
# and that direction is the one a human is forced to justify. Same asymmetry ARM 8 protects one level up.
# NEEDS_DRIVER (coo 2026-09-25, ceo CEO-1269): a LIBRARY is the program and NAME_driver is its grading vehicle, so a library
#   that ships no driver is OWED one -- in the denominator, a non-pass, named -- never ungradable for being a library.
#   Measured at the ruling: gimpel ships 148 libraries and 144 drivers, and BALX, FLOORCEI, PHRASES and stringout have none.
INV_CLASS_UNGRADED="NEEDS_STDIN_FIXTURE NEEDS_ARGV_FIXTURE NEEDS_RUNNER_WIRING NEEDS_VENDORED_SOURCE REF_NOT_CUT ORACLE_FAIL TIMEOUT NONDETERMINISTIC LIVE SUSPECT_USAGE NEEDS_DRIVER"
# ⛔⭐ A CONTAINER IS NOT A PROGRAM AND LEAVES SHIPPED, NAMED WITH ITS MEASUREMENT (ceo CEO-1272, 2026-09-25, on the coo's
# 886-row ask; CEO-700, CEO-1245, CEO-1269). The UNGRADABLE class CONTAINER_OR_LIBRARY conflated two facts, and the split is
# made file by file BY MEASUREMENT (util_container_or_library.py): a LIBRARY is a program owed its driver (UNGRADED NEEDS_DRIVER
# above, in the denominator); a CONTAINER is not a compilation unit on its own and is written in CONTAINERS.tsv beside the
# package's other sidecars -- name<TAB>KIND<TAB>measurement -- where KIND is one of the six below, and INCLUDED_BY/OPENED_BY/
# LOADED_BY name the file that splices, opens or loads it as the measurement's first word (LOADED_BY: a Prolog consult,
# ensure_loaded, use_module, load_files or reexport names it -- ceo CEO-1621, 2026-10-10). inventory_line takes a container OUT of shipped,
# refuses one that also sits in UNGRADED, UNGRADABLE or DEFERRED (two answers for one file), refuses one naming no shipped
# file, and re-derives every row's measurement through util_container_or_library.py verify before it prints a line -- a row
# whose measurement does not re-derive has not earned its way out of the denominator. PACKAGE_INVENTORY gains containers=N
# only where a CONTAINERS.tsv exists, so every package without one prints the byte-identical line it always did.
INV_CONTAINER_KINDS="INCLUDED_BY OPENED_BY LOADED_BY SCAFFOLDING NO_DEFINITION MULTI_PROGRAM"
# inventory_container_names [<pkgdir>] -- echo column 1 of <pkgdir>/CONTAINERS.tsv (default $INV_DIR); rc 2 on a malformed or
# class-less row. Runners that count their own shipped population call this so their census and the inventory's agree.
inventory_container_names() {
    local d="${1:-${INV_DIR:-}}" f n=0 line name kind meas
    f="$d/CONTAINERS.tsv"
    [ -f "$f" ] || return 0
    while IFS= read -r line; do
        n=$((n + 1))
        case "$line" in ''|'#'*) continue ;; esac
        name="$(printf '%s' "$line" | cut -f1)"; kind="$(printf '%s' "$line" | cut -f2)"; meas="$(printf '%s' "$line" | cut -f3-)"
        if [ -z "$name" ] || [ -z "$kind" ] || [ -z "${meas// /}" ]; then
            inventory_refuse "$f line $n: expected name<TAB>KIND<TAB>measurement, got: $line -- a container with no measurement is an opinion (CEO-1272)"; return 2
        fi
        case " $INV_CONTAINER_KINDS " in *" $kind "*) ;; *)
            inventory_refuse "$f line $n: KIND '$kind' is not one of: $INV_CONTAINER_KINDS -- a class-less or unknown container names no measurement (CEO-1272)"; return 2 ;;
        esac
        printf '%s\n' "$name"
    done < "$f"
}
# inventory_is_container <pkgdir> <rel> -- 0 when CONTAINERS.tsv names <rel> by its package-relative path or by its bare name.
inventory_is_container() {
    local names; names="$(inventory_container_names "$1" 2>/dev/null)" || return 1
    [ -n "$names" ] || return 1
    printf '%s\n' "$names" | grep -qxF -e "$2" -e "${2##*/}"
}
# LEGACY: accepted with a WARN so no lane's board breaks on the ruling, and named so the debt is one sed
# wide and visible. ⛔ Do not add to this list -- a new file uses the closed vocabulary above.
INV_CLASS_LEGACY="EMPTY:NEEDS_STDIN_FIXTURE GRADABLE:REF_NOT_CUT NO-ORACLE-SHIPPED:NO_ORACLE_SHIPPED NO-ORACLE:NO_ORACLE_SHIPPED ORACLE-IS-NOT-PROGRAM-OUTPUT:NO_ORACLE_SHIPPED NEEDS_MULTIFILE_LINK:NEEDS_RUNNER_WIRING"
# ⭐⭐ THE LEGACY MAP EARNED ITS KEEP WITHIN THE HOUR, AND ON A CASE THE RULING GOT WRONG, NOT AN OLD ONE.
# hq_I cured jcon concurrently with this ruling landing and wrote NEEDS_MULTIFILE_LINK -- a good, precise
# name for a real situation, invented in good faith minutes after the vocabulary closed. A bare "unruled
# classes refuse" would have red-lit a lane delivering exactly the work Lon had just ordered, and the lane
# would have been right to route around the ruling. ⭐ THE RULING STANDS AND THE FILE STILL PASSES: the
# CLASS is the bucket a lane sorts and picks up work by, so it stays coarse (NEEDS_RUNNER_WIRING covers
# "the runner cannot invoke it the way the package's own harness does" -- a two-file compile and a -L
# preload are the same pickup), and the REASON column carries the specificity, where it costs nothing. A
# vocabulary that grows a member per situation is the every-lane-invents-a-spelling problem wearing a
# tidier hat. ⛔ So the map is not only for pre-ruling debt: it is how a closed vocabulary absorbs a
# collision without stopping anyone, which is the only reason closing one is safe to do mid-flight.

inventory_refuse() { echo "⛔ INVENTORY REFUSES(2): $*" >&2; return 2; }
. "$(dirname "${BASH_SOURCE[0]}")/lib_excluded.sh" || { echo "⛔ INVENTORY REFUSES(2): lib_excluded.sh unloadable -- the one EXCLUDED.tsv reader" >&2; return 2 2>/dev/null || exit 2; }

# ⛔⭐⭐ THE ONE PLACE THAT DECIDES WHETHER A ROW NAMING OUR COMPILER IS A LIE OR A CONTROL (ceo CEO-541).
# `INV_AGREEMENT_MARKER` is vocabulary, not prose: it is the prefix a lane puts on OUR clause, and it is the
# only thing that can move a compiler-naming row out of ARM 8's refusal. ⭐ It is deliberately a MARKER and
# not a smarter regex over the sentence -- the failure this arm hunts (240 of 240 swi_tests rows) was written
# in good faith by careful people, so no amount of reading the wording separates a control from a lie. A lane
# that types the marker is ASSERTING the oracle's verdict stands alone, and that assertion is one grep away
# from any reviewer, forever, instead of being re-derived from the paragraph each time.
INV_AGREEMENT_MARKER="AGREEMENT-CONTROL:"
# the words that mean US, and the words that mean AN ORACLE. Both closed, both matched case-insensitively.
_INV_OURS_RE='(^|[^a-z])(scrip|our compiler|m3|m4|mode-3|mode-4|rung [0-9])([^a-z]|$)'
_INV_ORACLE_RE='(^|[^a-z])(oracle|upstream|icont|iconx|sbl|spitbol|swipl|gprolog|fpc|rakudo|arizona|jcon)([^a-z]|$)'
# _inv_compiler_named_rows <file> -- echo `N:line` for every row that names our compiler AS ITS REASON, i.e.
# every match ARM 8 refuses, MINUS the rows that are admitted agreement controls. Prints nothing when clean.
_inv_compiler_named_rows() {
    local f="$1" n line reason pre
    # ⛔⭐ DATA ROWS ONLY, AND THIS WAS MEASURED THE MOMENT THE MARKER WAS DOCUMENTED (hq_T 2026-09-10). The
    # scan used to read the WHOLE FILE, comments included -- so writing the CEO-541 policy into ipl's own
    # header, in a sentence explaining that a program excluded because SCRIP fails it is a red moved out of
    # the denominator, REFUSED THE PACKAGE. ⭐ A comment cannot be a failure-as-reason: it is not the reason
    # column, no census reads it, and the refusal quotes `cut -f3-` of a data row. An instrument that fires on
    # the documentation OF ITSELF is not being strict, it is answering a wider question than it was asked --
    # and its cost is paid exactly by the lane doing the right thing, which is the worst place to put it.
    # ⛔ The reason column stays mandatory (ARM 6), so nothing can be hidden in a comment: a row still has to
    # say something, and whatever it says is what this arm reads.
    grep -nE "^[^#]" "$f" 2>/dev/null | grep -iE "$_INV_OURS_RE" | while IFS= read -r hit; do
        n="${hit%%:*}"; line="${hit#*:}"
        # ⛔ THE MARKER COUNTS ONLY IN THE REASON COLUMN. A name or a class carrying it would admit a row by
        # accident of spelling; `cut -f3-` is the same field the refusal quotes and the reader reads.
        reason="$(printf '%s\n' "$line" | cut -f3-)"
        case "$reason" in
          *"$INV_AGREEMENT_MARKER"*)
            pre="${reason%%"$INV_AGREEMENT_MARKER"*}"
            # ⭐ TWO CONDITIONS, BOTH ON THE TEXT BEFORE THE MARKER, because that text is the ruling: it must
            # NAME THE ORACLE (the verdict is stated) and must NOT NAME US (it is stated independently).
            # Either one alone is satisfiable by a row whose ruling really does rest on our failure.
            if printf '%s\n' "$pre" | grep -qiE "$_INV_ORACLE_RE" && ! printf '%s\n' "$pre" | grep -qiE "$_INV_OURS_RE"; then
                continue
            fi
            printf '%s: %s\n' "$n" "$(printf '%s' "$line" | cut -c1-200)"
            printf '      ⛔ this row carries %s but does not earn it: the text BEFORE the marker must name the oracle and must not name us.\n' "$INV_AGREEMENT_MARKER" ;;
          *) printf '%s:%s\n' "$n" "$(printf '%s' "$line" | cut -c1-200)" ;;
        esac
    done | head -6
}

# _inv_class_check <kind> <file> <line-no> <class> -- rc 0 known, 1 legacy (warned), 2 unknown (refused).
_inv_class_check() {
    local kind="$1" f="$2" n="$3" cls="$4" known pair
    case "$kind" in
        UNGRADABLE) known="$INV_CLASS_UNGRADABLE" ;;
        UNGRADED)   known="$INV_CLASS_UNGRADED" ;;
        *)          return 0 ;;   # NARROW's narrowing vocabulary is hq_P's to close; format only here.
    esac
    case " $known " in *" $cls "*) return 0 ;; esac
    for pair in $INV_CLASS_LEGACY; do
        [ "${pair%%:*}" = "$cls" ] || continue
        echo "⚠ INVENTORY LEGACY CLASS: $f line $n uses '$cls'; the ruled $kind class is '${pair#*:}' (hq_T 2026-09-06). Accepted, not correct -- one sed from gone." >&2
        return 1
    done
    inventory_refuse "$f line $n: '$cls' is not a $kind class. The vocabulary is CLOSED (hq_T 2026-09-06) because three lanes invented three spellings for the same handful of situations in one morning:
    $kind = $known
    ⛔ Note which question this file answers: UNGRADABLE names what the ORACLE did (a ruling, nobody owes work); UNGRADED names what is OWED (a task somebody can pick up). A class naming an observation in UNGRADED cannot be worked, and a class naming our own work in UNGRADABLE is ARM 8's defect."
    return 2
}

# ⛔⭐ THE DEFERRED READER -- IT READS A RULING, SO IT IS STRICTER THAN THE SIDECAR READERS ABOVE, AND ITS
# FAILURE MODE IS rc=2 RATHER THAN ZERO. A missing DEFERRED.tsv means NOTHING IS DEFERRED (zero, honestly --
# no record is the normal state and must not refuse). A PRESENT record that cannot be read is a refusal: an
# unreadable ruling is the one case where guessing zero would silently count Lon's deferred programs against
# the lane, which is the ruling's exact opposite.
# ⛔ THE GLOB IS RE-EXPANDED HERE, NEVER THE `count` COLUMN TRANSCRIBED. The count is graded against the disk
# by test_gate_deferred_rows_name_a_ruling_and_the_work_they_wait_on.sh; this body uses the FILES, so a stale
# count can never move a live inventory (FINDING-2026-09-09-hq_T: an exclusion list with no staleness arm can
# only ever lower a denominator).
# _inv_deferred_file -- echo the DEFERRED.tsv path (redirectable), or nothing when there is none.
_inv_deferred_file() {
    local f="${S4E_DEFERRED_TSV:-}"
    [ -n "$f" ] || f="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/.github/DEFERRED.tsv"
    [ -f "$f" ] && echo "$f"
    return 0
}
# _inv_deferred_names -- echo the INV_DIR-relative names DEFERRED.tsv defers for INV_PACKAGE, one per line.
_inv_deferred_names() {
    local f home line pkg pop n=0 hit abs rel
    f="$(_inv_deferred_file)"; [ -n "$f" ] || return 0
    home="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
    while IFS= read -r line; do
        n=$((n + 1))
        case "$line" in ''|'#'*) continue ;; esac
        # the header row names the columns; skip it by its own first field rather than by line number,
        # so a comment added above it cannot shift what this reader believes a data row is.
        pkg="$(printf '%s' "$line" | cut -f2)"
        [ "$pkg" = "package" ] && continue
        [ "$pkg" = "$INV_PACKAGE" ] || continue
        pop="$(printf '%s' "$line" | cut -f4)"
        if [ -z "$pop" ]; then
            inventory_refuse "$f line $n defers package '$pkg' with an EMPTY population column -- a deferral naming no programs lifts a score over nothing"
            return 2
        fi
        # ⛔ eval'd ONE field of a version-controlled, reviewed record, for glob expansion only, and the
        # column is validated by the gate to be a corpus-relative path glob. Nothing here comes from a run.
        for hit in $(eval echo "$home/$pop"); do
            [ -f "$hit" ] || continue
            abs="$(cd "$(dirname "$hit")" && pwd)/$(basename "$hit")"
            case "$abs" in
                "$INV_DIR"/*) rel="${abs#"$INV_DIR"/}" ;;
                *) continue ;;   # a row may defer programs in a sibling tree; they are not this census's
            esac
            printf '%s\n' "$rel"
        done
    done < "$f"
    return 0
}

# _inv_tsv <basename> -- echo the path of a sidecar beside INV_DIR or one level below it, or nothing.
_inv_tsv() {
    local b="$1" c
    for c in "$INV_DIR/$b" "$INV_DIR"/*/"$b"; do
        [ -f "$c" ] && { echo "$c"; return 0; }
    done
    return 0
}

# _inv_names <tsv> <kind> -- echo the name column, refusing a malformed, unexplained or misclassed row.
_inv_names() {
    local f="$1" kind="${2:-}" n=0
    [ -n "$f" ] || return 0
    while IFS= read -r line; do
        n=$((n + 1))
        case "$line" in ''|'#'*) continue ;; esac
        # ⛔ THREE COLUMNS, AND THE REASON MAY NOT BE EMPTY. A declaration with no reason is the shape
        # that turns an inventory back into a number nobody can act on.
        local name class reason
        name="$(printf '%s' "$line" | cut -f1)"
        class="$(printf '%s' "$line" | cut -f2)"
        reason="$(printf '%s' "$line" | cut -f3-)"
        if [ -z "$name" ] || [ -z "$class" ] || [ -z "${reason// /}" ]; then
            inventory_refuse "$f line $n: expected name<TAB>CLASS<TAB>reason, got: $line" || return 2
        fi
        _inv_class_check "$kind" "$f" "$n" "$class"; [ "$?" -eq 2 ] && return 2
        printf '%s\n' "$name"
    done < "$f"
}

# ⭐⭐ THE CLASS SPLIT -- ITS OWN LINE, NEVER A FIELD ON PACKAGE_INVENTORY (hq_T ruling 2026-09-06, on
# hq_I's ipl construction). `ungraded=233` answers HOW MUCH is owed and nothing about WHAT: ipl's entire
# debt read as one undifferentiated ORACLE_FAIL bucket 212 rows deep until it was split by measured cause.
# ⭐ A BUCKET A LANE CANNOT SORT IS A BUCKET A LANE CANNOT PICK UP.
# ⛔ SEPARATE FUNCTION, AND SEPARATE ON PURPOSE. test_gate_package_runners_print_the_inventory.sh pins
# inventory_line's output by EXACT STRING EQUALITY and its ARM 1 comment says "exactly one line", so
# appending here -- or printing a second line from inventory_line itself -- reds that gate. A caller opts
# in with one more call; PACKAGE_INVENTORY stays byte-identical and no want= string changes.
# ⛔⛔ AND THE INVARIANT IS THE LOAD-BEARING HALF (hq_T: "a split that can disagree with its own total is
# worse than no split, because it looks like detail"). The per-class counts are read from the SAME rows
# _inv_names already validated for inventory_line, and the parts are asserted to sum to the whole. If they
# ever disagree, two readings of one population disagree and NEITHER is printed -- rc=2, like every other
# could-not-measure in this project.
#
# inventory_split_line -- prints PACKAGE_INVENTORY_SPLIT package=<n> ungraded_by_class=... ungradable_by_class=...
#   0 printed · 2 refused (a bucket's classes do not sum to its own row count, or a sidecar is malformed)
_inv_class_hist() {
    local f="$1" kind="$2" want="$3" got parts
    [ -n "$f" ] || { printf 'none'; return 0; }
    got=$(awk -F'\t' 'NF>2 && $1 !~ /^#/{n++} END{print n+0}' "$f")
    if [ "$got" -ne "$want" ]; then
        inventory_refuse "$f holds $got classified row(s) but inventory_line counted $want for $kind -- two readings of one population disagree, so neither is published"
        return 2
    fi
    parts="$(awk -F'\t' 'NF>2 && $1 !~ /^#/{c[$2]++} END{n=0; for (k in c) {printf "%s%s:%d", (n++?",":""), k, c[k]}}' "$f")"
    printf '%s' "${parts:-none}"
}
inventory_split_line() {
    [ -n "${INV_PACKAGE:-}" ] || { inventory_refuse "INV_PACKAGE unset -- the split has no package to name"; return 2; }
    [ -d "${INV_DIR:-}" ]     || { inventory_refuse "INV_DIR '${INV_DIR:-}' is not a directory"; return 2; }
    local ung_f ugd_f ung_n ugd_n ung_c ugd_c hu hd
    ung_f="$(_inv_tsv UNGRADED.tsv)"; ugd_f="$(_inv_tsv UNGRADABLE.tsv)"
    ung_n="$(_inv_names "$ung_f" UNGRADED)"   || return 2
    ugd_n="$(_inv_names "$ugd_f" UNGRADABLE)" || return 2
    ung_c=$(printf '%s' "$ung_n" | grep -c . || true)
    ugd_c=$(printf '%s' "$ugd_n" | grep -c . || true)
    hu="$(_inv_class_hist "$ung_f" ungraded "$ung_c")"   || return 2
    hd="$(_inv_class_hist "$ugd_f" ungradable "$ugd_c")" || return 2
    echo "PACKAGE_INVENTORY_SPLIT package=$INV_PACKAGE ungraded_by_class=$hu ungradable_by_class=$hd"
    return 0
}

inventory_line() {
    local graded_stream="${1:-0}" graded_narrow="${2:-0}"
    [ -n "${INV_PACKAGE:-}" ] || { inventory_refuse "INV_PACKAGE unset -- the stanza is incomplete"; return 2; }
    [ -d "${INV_DIR:-}" ]     || { inventory_refuse "INV_DIR '${INV_DIR:-}' is not a directory -- the package moved; re-pin rather than reinterpret"; return 2; }
    [ -n "${INV_EXT:-}" ]     || { inventory_refuse "INV_EXT unset -- cannot census a shipped population without knowing its extension"; return 2; }

    # ⛔⭐ SHIPPED IS COUNTED BY EXTENSION OVER THE WHOLE PACKAGE TREE, never by the one directory anyone
    # had in mind. This is CLAUDE.md's own most-reused lesson (census by extension, never by the one you
    # had in mind) applied to the population that the entire lockdown percentage divides by.
    local shipped=0 e f rel
    local -A _rel=() _base=() _brel=()
    for e in $INV_EXT; do
        while IFS= read -r f; do
            rel="${f#"$INV_DIR"/}"
            # ⛔⭐ OUR OWN GENERATED RUNGS IS NOT A SHIPPED PROGRAM. Four packages carry an `ALL.<ext>`
            # concatenated rungs beside the vendor's files (ipl, aisnobol, csnobol4_suite, gimpel,
            # measured 2026-09-06). Counting it inflates `shipped` by exactly one and makes the SUM
            # unreachable by one FOREVER -- a lane grades every vendor program and still refuses.
            # ⭐ It is also the whole of the 851-vs-852 disagreement between hq_I's Icon runner (which
            # excludes ALL.icn) and this body (which did not): two correct instruments answering two
            # different questions, and neither able to say so.
            case "${f##*/}" in ALL.*) continue ;; esac
            # ⛔⭐ A DRIVER IS A GRADING VEHICLE, NEVER A SHIPPED PROGRAM (ceo CEO-1269, CEO-700 applied; coo 2026-09-25, row
            # instruments-the-arizona-jcon-and-gimpel-runners-grade-a-library-through-its-driver-...): NAME_driver<ext> tests
            # the library NAME<ext>, and the library is the program. The runners grade the library by its driver and record
            # it under the library's name. gimpel counted 144 drivers AND 148 libraries here, and 292 was two populations.
            case "${f##*/}" in *_driver"$e") continue ;; esac
            _rel["$rel"]=1
            _base["${f##*/}"]=$(( ${_base["${f##*/}"]:-0} + 1 ))
            _brel["${f##*/}"]="$rel"
            shipped=$((shipped + 1))
        done < <(find "$INV_DIR" -type f -name "*$e" ! -path "*.fixtures/*" 2>/dev/null)
    done
    [ "$shipped" -gt 0 ] || { inventory_refuse "zero files matching '$INV_EXT' under $INV_DIR -- an empty shipped population is not an inventory, and a percent over zero is not a score"; return 2; }

    local ung_f ugd_f nar_f
    ung_f="$(_inv_tsv UNGRADED.tsv)";   ugd_f="$(_inv_tsv UNGRADABLE.tsv)"; nar_f="$(_inv_tsv NARROW.tsv)"
    local ung_n ugd_n
    ung_n="$(_inv_names "$ung_f" UNGRADED)" || return 2
    ugd_n="$(_inv_names "$ugd_f" UNGRADABLE)" || return 2
    local ungraded ungradable deferred def_n
    ungraded=$(printf '%s' "$ung_n"   | grep -c . || true)
    ungradable=$(printf '%s' "$ugd_n" | grep -c . || true)
    def_n="$(_inv_deferred_names)" || return 2
    def_n="$(printf '%s' "$def_n" | sort -u)"
    deferred=$(printf '%s' "$def_n" | grep -c . || true)

    # ⛔⭐⭐ AN UNGRADABLE DECLARATION MUST GIVE THE ORACLE'S REASON, NEVER OURS -- and this is the arm
    # that stops the lockdown from being satisfiable by failing. hq_C measured it on prolog/swi_tests
    # 2026-09-06: EXCLUDED.md names 240 programs as not graded and 240 OF 240 GIVE A SCRIP-SIDE REASON
    # ("scrip produces zero PASS/FAIL/EMPTY lines for this file today"), ZERO give an oracle-side one.
    # ⛔ A PROGRAM EXCLUDED BECAUSE OUR OWN COMPILER FAILS IT IS A RED MOVED OUT OF THE DENOMINATOR: the
    # score cannot fall when we fail, because failing is what removes the entry. Against the real oracle
    # only FIVE of 170 were genuinely ungradable, all oracle-side (swipl aborts, SIGSEGVs, times out).
    # ⭐ AND NOTE WHY NOBODY CAUGHT IT, because it is the reason this must be a machine check rather than
    # a review habit: every one of those 240 entries is individually honest and well documented, naming
    # file, rung and exact error. 240 carefully-written TRUE notes compose into a denominator that cannot
    # fall. Diligence at the entry level is exactly what makes the aggregate invisible.
    # ⭐⭐ AND THE ONE ADMITTED EXCEPTION IS A CONTROL, NOT A LOOSENING (ceo CEO-541, 2026-09-10, on hq_T's
    # ask). A row may name our compiler when, and only when, it does what icon/ipl's gincl/maccolor.icn does:
    # state THE ORACLE'S OWN VERDICT FIRST AND INDEPENDENTLY (Arizona icont refuses at line 23, verbatim, and
    # upstream's UNMODIFIED copy refuses identically), and only THEN add that we refuse at the same line with
    # the same class. That last clause is an AGREEMENT CONTROL: it does not carry the ruling, it shows the
    # ruling is not our own damage. ⛔ THE DISCRIMINATOR IS THE ONE THIS WHOLE ARM USES -- THE RULING MUST
    # STAND UNCHANGED IF SCRIP WERE PERFECT AT EVERYTHING ELSE -- and here it does: a perfect SCRIP would
    # still be refused by icont at line 23, so the row survives its own agreement clause being deleted.
    # ⛔ AND IT IS ADMITTED BY A MARKER, NOT BY A READER'S JUDGEMENT, which is the entire point of CEO-541:
    # `AGREEMENT-CONTROL:` prefixes OUR clause, so the arm separates a control from a failure-as-reason
    # MECHANICALLY. Without the marker the row stays refused however true its prose -- the tpp precedent
    # below is unweakened, and a row that merely mentions us in passing has not earned an exception.
    # ⭐ WHY THE PREFIX MUST ITSELF BE CLEAN: "stated independently" is checkable exactly once -- the text
    # BEFORE the marker must name the oracle and must NOT name us. If our compiler appears ahead of the
    # marker the oracle's verdict is no longer stated on its own, and a reader cannot tell whether the
    # ruling would survive without it. That is the same property ARM 8 has always protected; the marker
    # moves it from prose a reviewer must weigh to a position a grep can find.
    if [ -n "$ugd_f" ]; then
        local badreason
        badreason="$(_inv_compiler_named_rows "$ugd_f")"
        if [ -n "$badreason" ]; then
            inventory_refuse "$ugd_f names OUR OWN COMPILER as the reason a program cannot be graded:
$badreason
    ⛔ UNGRADABLE is a statement about the ORACLE, never about us. A program excluded because SCRIP fails it is a RED MOVED OUT OF THE DENOMINATOR -- the score cannot fall when we fail, because failing is what removes the entry. If the oracle grades it and we do not, it is GRADED and RED. Move it, or give the oracle's own reason.
    ⭐ AND A ROW CITING **BOTH** IS STILL REFUSED, deliberately -- measured on arizona general/tpp.icn, whose reason gives \"TWO reasons this is ungradable here\": one oracle-side (tpp.ok was never vendored) and one ours (no preprocessor-only mode). The oracle-side half is sufficient on its own, so state it on its own; while our half is written beside it a reader cannot tell whether the ruling would survive without it, and that is the whole property this arm protects.
    ⭐ THE ONE ADMITTED SHAPE (ceo CEO-541) is an AGREEMENT CONTROL: state the oracle's verdict first and on its own, then prefix our clause with $INV_AGREEMENT_MARKER -- as in \`... Arizona icont REFUSES IT AT COMPILE, rc=1, verbatim \"...\"; upstream's unmodified copy refuses identically. $INV_AGREEMENT_MARKER we refuse at the same line with the same class, so we AGREE with the oracle.\` The text before the marker must NAME THE ORACLE and must NOT name us; nothing else is accepted, and the marker cannot rescue a row whose ruling rests on our failure."
            return 2
        fi
    fi

    # ⛔ A NAME MAY NOT BE IN BOTH FILES. "Work owed" and "ruled impossible" are contradictory claims
    # about one program, and whichever the reader saw first would decide whether the lane owes work.
    # ⛔⭐ THIS DIAGNOSTIC USED TO NAME AN INNOCENT FILE (hq_S 2026-09-06, measured on csnobol4).
    # `sort | uniq -d` over the CONCATENATION of the two files fires for a name repeated inside ONE of
    # them exactly as readily as for a name in both -- but the message hard-coded the cross-file story.
    # Two lanes ruled aa/aa.sno within minutes of each other and git kept both rows, so ONE file held a
    # duplicate; the refusal reported "named in BOTH UNGRADED.tsv and UNGRADABLE.tsv" with both files
    # open in front of the reader and no such UNGRADED row anywhere in either.
    # ⭐ THE ARITHMETIC WAS RIGHT AND ONLY THE STORY WAS WRONG, which is the dangerous half: a refusal
    # that stops the right run for the wrong stated reason sends its reader to audit a file that is
    # innocent, and spends the credibility the refusal exists to have. Same family as this library's own
    # header lesson -- an instrument answering a narrower question than the reader thinks it asked, and
    # never saying so. So: name INTERNAL duplicates per file first, then the cross-file intersection,
    # which only becomes unambiguous once each file is known to be internally unique.
    local dup_ung dup_ugd
    dup_ung="$(printf '%s\n' "$ung_n" | grep -v '^$' | sort | uniq -d)"
    dup_ugd="$(printf '%s\n' "$ugd_n" | grep -v '^$' | sort | uniq -d)"
    if [ -n "$dup_ung" ]; then
        inventory_refuse "$ung_f names the same program more than once: $(printf '%s' "$dup_ung" | tr '\n' ' ')-- one UNGRADED row per program. ⛔ This is an INTERNAL duplicate in that ONE file, NOT a name in both files: two lanes ruling the same program in one sitting is how it happens, and git keeps both rows."
        return 2
    fi
    if [ -n "$dup_ugd" ]; then
        inventory_refuse "$ugd_f names the same program more than once: $(printf '%s' "$dup_ugd" | tr '\n' ' ')-- one UNGRADABLE row per program. ⛔ This is an INTERNAL duplicate in that ONE file, NOT a name in both files: two lanes ruling the same program in one sitting is how it happens, and git keeps both rows."
        return 2
    fi
    local both
    both="$(printf '%s\n%s\n' "$ung_n" "$ugd_n" | grep -v '^$' | sort | uniq -d)"
    [ -z "$both" ] && : || { inventory_refuse "named in BOTH UNGRADED.tsv and UNGRADABLE.tsv: $(printf '%s' "$both" | tr '\n' ' ')-- a program cannot be both work owed and ruled impossible"; return 2; }
    # ⛔ AND A DEFERRED PROGRAM MAY NOT ALSO BE DECLARED HERE. This is not tidiness: the sum below counts it
    # once per bucket it appears in, so a program in DEFERRED.tsv and UNGRADED.tsv makes shipped unreachable
    # by one and the whole census refuses -- with a message about arithmetic, for a defect about authority.
    # ⭐ The direction matters too: DEFERRED comes from a ruling and UNGRADED from a lane, so the collision is
    # a lane still carrying work Lon has already taken off the board, which reads as debt that cannot close.
    local defboth
    defboth="$(printf '%s\n%s\n%s\n' "$ung_n" "$ugd_n" "$def_n" | grep -v '^$' | sort | uniq -d)"
    if [ -n "$defboth" ] && [ "$deferred" -gt 0 ]; then
        local d hitdef=""
        for d in $defboth; do case " $(printf '%s' "$def_n" | tr '\n' ' ') " in *" $d "*) hitdef="$hitdef $d" ;; esac; done
        [ -z "$hitdef" ] || { inventory_refuse "named in DEFERRED.tsv AND in a package sidecar:$hitdef -- a deferral is Lon's ruling that the program is not owed and not a failure; a sidecar row for the same program is the lane claiming otherwise. Delete the sidecar row, or ask for the deferral to be withdrawn -- never both."; return 2; }
    fi

    # ⛔ A DECLARATION NAMING NOTHING SHIPPED IS STALE -- the same refusal the wantrc/xfail sidecars make.
    # A stale line silently shrinks `graded` and inflates the lane's apparent debt, or hides a real one.
    local nm miss="" ambig=""
    for nm in $ung_n $ugd_n $def_n; do
        if [ -n "${_rel["$nm"]:-}" ]; then continue; fi
        case "${_base["$nm"]:-0}" in
            0) miss="$miss $nm" ;;
            1) : ;;
            *) ambig="$ambig $nm(${_base["$nm"]})" ;;
        esac
    done
    [ -z "$ambig" ] || { inventory_refuse "declared by a BARE NAME that names more than one shipped file:$ambig -- write the package-relative path instead. A bare name is only a name while it is unique; ipl ships four such collisions (gener/morse/repeats/spokes under both procs/ and progs/), so the ruling would land on whichever file the census happened to reach first."; return 2; }
    [ -z "$miss" ] || { inventory_refuse "declared but not shipped:$miss -- a declaration matching no file is a rename or a leftover, and both withdraw a guarantee silently"; return 2; }

    # ⛔⭐ THE CONTAINERS LEAVE SHIPPED HERE, EACH ONE RESOLVED TO ONE FILE AND ITS MEASUREMENT RE-DERIVED (CEO-1272; the block
    # beside INV_CONTAINER_KINDS above). Resolved like every other declaration -- a package-relative path, or a bare name while
    # it is unique -- and compared by RESOLVED FILE with the other three buckets, so a bare name here and a path there cannot hide
    # one file carrying two answers.
    local con_n="" containers="" c_rel c_miss="" c_ambig="" c_both="" _nm
    if [ -f "$INV_DIR/CONTAINERS.tsv" ]; then
        con_n="$(inventory_container_names "$INV_DIR")" || return 2
        local -A _con=() _declared=()
        for _nm in $ung_n $ugd_n $def_n; do
            if [ -n "${_rel["$_nm"]:-}" ]; then _declared["$_nm"]=1; elif [ "${_base["$_nm"]:-0}" = 1 ]; then _declared["${_brel["$_nm"]}"]=1; fi
        done
        containers=0
        for _nm in $con_n; do
            if [ -n "${_rel["$_nm"]:-}" ]; then c_rel="$_nm"
            else case "${_base["$_nm"]:-0}" in 0) c_miss="$c_miss $_nm"; continue ;; 1) c_rel="${_brel["$_nm"]}" ;; *) c_ambig="$c_ambig $_nm(${_base["$_nm"]})"; continue ;; esac; fi
            [ -z "${_con["$c_rel"]:-}" ] || { inventory_refuse "$INV_DIR/CONTAINERS.tsv names $c_rel more than once -- one container row per file"; return 2; }
            _con["$c_rel"]=1
            [ -z "${_declared["$c_rel"]:-}" ] || c_both="$c_both $c_rel"
            containers=$((containers + 1))
        done
        [ -z "$c_miss" ] || { inventory_refuse "CONTAINERS.tsv names a file this package does not ship:$c_miss -- a container matching no file is a rename or a leftover (CEO-1272)"; return 2; }
        [ -z "$c_ambig" ] || { inventory_refuse "CONTAINERS.tsv declares by a BARE NAME that names more than one shipped file:$c_ambig -- write the package-relative path"; return 2; }
        [ -z "$c_both" ] || { inventory_refuse "a container is also declared in UNGRADED.tsv, UNGRADABLE.tsv or DEFERRED.tsv:$c_both -- not a program and owed or ruled as one are two answers for one file (CEO-1272)"; return 2; }
        local _v _vrc
        _v="$(python3 "$(dirname "${BASH_SOURCE[0]}")/util_container_or_library.py" verify "$INV_DIR" 2>&1)"; _vrc=$?
        [ "$_vrc" -eq 0 ] || { inventory_refuse "CONTAINERS.tsv does not re-derive its own measurements (util_container_or_library.py verify rc=$_vrc) -- a container leaves the denominator only on a measurement that holds:
$_v"; return 2; }
        shipped=$((shipped - containers))
    fi
    local exc_n="" excluded="" excluded_tail="" e_rel e_miss="" e_con=""
    if [ -f "$INV_DIR/EXCLUDED.tsv" ]; then
        exc_n="$(inventory_excluded_names "$INV_DIR")" || return 2
        excluded=0
        for _nm in $exc_n; do
            if [ -n "${_rel["$_nm"]:-}" ]; then e_rel="$_nm"
            else case "${_base["$_nm"]:-0}" in 0) e_miss="$e_miss $_nm"; continue ;; 1) e_rel="${_brel["$_nm"]}" ;; *) e_miss="$e_miss $_nm(ambiguous)"; continue ;; esac; fi
            if [ -f "$INV_DIR/CONTAINERS.tsv" ] && inventory_is_container "$INV_DIR" "$e_rel"; then e_con="$e_con $e_rel"; continue; fi
            excluded=$((excluded + 1))
        done
        [ -z "$e_miss" ] || { inventory_refuse "EXCLUDED.tsv names a file this package does not ship:$e_miss -- an exclusion matching no file is a rename or a leftover (CEO-1286)"; return 2; }
        [ -z "$e_con" ] || { inventory_refuse "EXCLUDED.tsv names a container:$e_con -- a container is already out of shipped, so excluding it again would subtract it twice (CEO-1286)"; return 2; }
        excluded_tail=" excluded=$excluded denominator=$((shipped - excluded))"
    fi

    # ⛔ AN UNEXPLAINED NARROW BUCKET IS JUST A SMALLER LIE (hq_P). A count with no per-entry narrowing
    # cannot be acted on and cannot be disputed.
    if [ "$graded_narrow" -gt 0 ]; then
        [ -n "$nar_f" ] || { inventory_refuse "graded_narrow=$graded_narrow but no NARROW.tsv beside $INV_DIR -- name which narrowing applies to which entry, or do not claim the bucket"; return 2; }
        local nar_n; nar_n="$(_inv_names "$nar_f" NARROW)" || return 2
        local nar_c; nar_c=$(printf '%s' "$nar_n" | grep -c . || true)
        [ "$nar_c" -eq "$graded_narrow" ] || { inventory_refuse "graded_narrow=$graded_narrow but NARROW.tsv names $nar_c entr(y/ies) -- the count and the explanation must be the same population"; return 2; }
    fi

    # ⛔⭐ THE FOUR BUCKETS MUST SUM TO SHIPPED. This is the whole load-bearing property: without it the
    # line is four independent opinions, each individually plausible, and a program can fall out of every
    # bucket -- which is the "never graded" defect the order exists to end, wearing an inventory's clothes.
    local graded=$((graded_stream + graded_narrow))
    local total=$((graded + ungraded + ungradable + deferred))
    if [ "$total" -ne "$shipped" ]; then
        inventory_refuse "buckets do not sum: graded($graded)=stream($graded_stream)+narrow($graded_narrow) + ungraded($ungraded) + ungradable($ungradable) + deferred($deferred) = $total, but shipped=$shipped (delta $((shipped - total))). Every shipped program lands in exactly one bucket, or the inventory is five opinions rather than a census."
        return 2
    fi
    echo "PACKAGE_INVENTORY package=$INV_PACKAGE shipped=$shipped graded=$graded ungraded=$ungraded ungradable=$ungradable deferred=$deferred graded_stream=$graded_stream graded_narrow=$graded_narrow${containers:+ containers=$containers}${excluded_tail:-}"
    return 0
}

# inventory_containers_of "<PACKAGE_INVENTORY line>" -- echo the line's containers=N, 0 when the package declares none. A row's
# Excl is every shipped unit its denominator leaves out (Lon 2026-09-26, "use the Excl column to properly classify the exclusions
# for good reasons only"; CEO-1288): its containers plus its EXCLUDED.tsv programs, read off the inventory the runner already
# printed, never counted a second time.
inventory_containers_of() {
    local n; n="$(printf '%s\n' "${1:-}" | grep -oE ' containers=[0-9]+' | head -1 | cut -d= -f2)"; echo "${n:-0}"
}

# ⛔⭐ CONDITION 2 OF THE LEDGER'S THREE: PRINTED, NEVER SUBTRACTED IN SILENCE. A runner with a nonzero
# `deferred=` calls this immediately after inventory_line so the names stand beside the count.
# ⭐ SEPARATE LINE, SEPARATE CALL, for the reason inventory_split_line already documents: PACKAGE_INVENTORY is
# pinned by EXACT STRING EQUALITY, so nothing may print from inside it. ⛔ But unlike the split, this one is
# NOT OPTIONAL WHEN IT HAS CONTENT -- a deferred count with no names is the shape a wrong exclusion hides in.
# It prints nothing and returns 0 when the count is zero, which is every package with a runner today.
#   PACKAGE_INVENTORY_DEFERRED package=<n> deferred=N names=a,b,c ruled_by=CEO-...,CEO-...
inventory_deferred_line() {
    [ -n "${INV_PACKAGE:-}" ] || { inventory_refuse "INV_PACKAGE unset -- the deferred line has no package to name"; return 2; }
    local def_n c f ruled names
    def_n="$(_inv_deferred_names)" || return 2
    def_n="$(printf '%s' "$def_n" | sort -u)"
    c=$(printf '%s' "$def_n" | grep -c . || true)
    [ "$c" -gt 0 ] || return 0
    f="$(_inv_deferred_file)"
    ruled="$(awk -F'\t' -v p="$INV_PACKAGE" '$1 !~ /^#/ && $2 == p {print $6}' "$f" | paste -sd';' -)"
    names="$(printf '%s' "$def_n" | paste -sd, -)"
    echo "PACKAGE_INVENTORY_DEFERRED package=$INV_PACKAGE deferred=$c names=$names ruled_by=${ruled:-NONE}"
    return 0
}
