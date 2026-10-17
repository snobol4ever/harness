#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
# test_gate_package_runners_print_the_inventory.sh — the invariant gate for THE PACKAGE LOCKDOWN's
# instrument (row every-package-runner-prints-shipped-graded-ungraded-and-ungradable-and-the-leaderboard-
# carries-the-inventory, hq_T 2026-09-06, rank 0 on the ceo's order; Lon: "Fix the never graded business.
# Let's lock down our package testing and make it complete.").
#
# WHAT IT PROTECTS. Every lockdown row's DONE-WHEN is `ungraded=0`, so the number that criterion reads is
# load-bearing for the whole fleet. ⛔ THE FAILURE IT GUARDS AGAINST IS NOT A WRONG COUNT — it is a
# program that lands in NO bucket at all and therefore never appears in any number. Measured on the first
# run against a real package: icon/ipl ships 852 .icn files, 211 are declared in UNGRADED.tsv, and 641
# were in no bucket whatsoever. Not red, not skipped, not owed — simply absent, which is exactly the
# "never graded business" the order exists to end.
#
# ⭐⭐ SO THE LOAD-BEARING PROPERTY IS THE SUM, NOT ANY BUCKET. graded + ungraded + ungradable must equal
# shipped. Without that, the line is four independent opinions, each individually plausible, and the
# absent 641 are invisible in all four. A gate that only checked "does the runner print a line" would go
# green on an inventory that omits three quarters of the package.
#
# ⭐ AND THE SUM IS WHY `gap=` HAD TO SPLIT. Four runners printed `shipped/graded/gap`; `gap` held both
# "not graded YET" (work owed) and "CANNOT be graded" (a ruling). While an ungradable program sits inside
# gap, `ungraded=0` is UNREACHABLE BY BEING CORRECT — a lane does every piece of real work available and
# still never reaches its own criterion.
#
# Usage: bash ../harness/scripts/test_gate_package_runners_print_the_inventory.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
gate_require "$HERE/lib_inventory.sh" "the one package-inventory body lib_inventory.sh"
. "$HERE/lib_inventory.sh"

violations=0; examined=0
TD="$(mktemp -d "${TMPDIR:-/tmp}/pkg_inv.XXXXXX")"; trap 'rm -rf "$TD"' EXIT

mkpkg() {  # mkpkg <n-files>; fresh scratch package, no sidecars
    rm -rf "$TD/p"; mkdir -p "$TD/p"
    local i; for i in $(seq 1 "$1"); do echo 'procedure main(); end' > "$TD/p/f$i.icn"; done
    INV_PACKAGE=scratch; INV_DIR="$TD/p"; INV_EXT=".icn"
}
run_inv() { inventory_line "$1" "$2" 2>&1; }

# ARM 1 — the happy path: buckets that sum produce exactly one line, in the one shape, rc=0.
mkpkg 5
printf 'f4.icn\tNEEDS_STDIN_FIXTURE\tstdin-driven filter, no .in authored yet\n' > "$TD/p/UNGRADED.tsv"
printf 'f5.icn\tORACLE_REFUSES\tthe oracle refuses this program: unsupported extension\n' > "$TD/p/UNGRADABLE.tsv"
examined=$((examined+1))
out="$(run_inv 3 0)"; rc=$?
want='PACKAGE_INVENTORY package=scratch shipped=5 graded=3 ungraded=1 ungradable=1 deferred=0 graded_stream=3 graded_narrow=0'
if [ "$rc" -ne 0 ] || [ "$out" != "$want" ]; then
    echo "GATE FAIL: the summing case did not print the one shape (rc=$rc)"; echo "    want: $want"; echo "    got : $out"
    violations=$((violations+1))
fi


# ⭐ ARM 1b — THE CLASS SPLIT, AND THE INVARIANT IS WHY THE ARM EXISTS (hq_T ruling 2026-09-06, on hq_I's
# ipl construction: the split moves into the shared body as its OWN line, and "a split that can disagree
# with its own total is worse than no split, because it looks like detail"). Two properties, both checked
# here: PACKAGE_INVENTORY stays EXACTLY ONE LINE and byte-identical (ARM 1 above already pins that, and
# this arm would have caught an implementation that printed the split from inventory_line instead), and
# the per-class counts sum to the very buckets inventory_line published.
examined=$((examined+1))
split_out="$(inventory_split_line 2>&1)"; split_rc=$?
inv_only="$(run_inv 3 0)"
if [ "$split_rc" -ne 0 ]; then
    echo "GATE FAIL: inventory_split_line refused a package whose inventory sums (rc=$split_rc): $split_out"; violations=$((violations+1))
elif [ "$inv_only" != "$want" ]; then
    echo "GATE FAIL: PACKAGE_INVENTORY is no longer exactly one byte-identical line once the split exists"; violations=$((violations+1))
else
    _u="$(printf '%s' "$split_out" | sed -n 's/.*ungraded_by_class=\([^ ]*\).*/\1/p')"
    _d="$(printf '%s' "$split_out" | sed -n 's/.*ungradable_by_class=\([^ ]*\).*/\1/p')"
    _su=$(printf '%s' "$_u" | tr ',' '\n' | awk -F: '{n+=$2} END{print n+0}')
    _sd=$(printf '%s' "$_d" | tr ',' '\n' | awk -F: '{n+=$2} END{print n+0}')
    # the scratch package above declares exactly one UNGRADED row and one UNGRADABLE row
    if [ "$_su" -ne 1 ] || [ "$_sd" -ne 1 ]; then
        echo "GATE FAIL: the split's per-class counts do not sum to the buckets inventory_line published (ungraded parts=$_su want 1, ungradable parts=$_sd want 1); split line: $split_out"; violations=$((violations+1))
    fi
fi
# ⚠ NOT PROVEN, and said so rather than claimed: _inv_class_hist's own rc=2 branch (the two readings of one
# population disagreeing) cannot be reached from a well-formed sidecar, because _inv_names refuses a
# malformed row before the histogram is ever counted. It is a defensive refusal against a future code
# change, not a behaviour this gate demonstrates.

# ARM 2 — ⭐⭐ THE LOAD-BEARING ARM. A program in NO bucket must REFUSE, and the refusal must name the
# delta. This is the 641-of-852 case, and a gate without it would pass an inventory that loses a package.
examined=$((examined+1))
out="$(run_inv 2 0)"; rc=$?
if [ "$rc" -ne 2 ] || ! printf '%s' "$out" | grep -q 'delta 1'; then
    echo "GATE FAIL: a shipped program in NO bucket was not refused with its delta named (rc=$rc): $out"
    violations=$((violations+1))
fi

# ARM 3 — over-counting refuses too: the sum is an identity, not a floor.
examined=$((examined+1))
out="$(run_inv 4 0)"; rc=$?
[ "$rc" -eq 2 ] || { echo "GATE FAIL: graded overshooting shipped was not refused (rc=$rc): $out"; violations=$((violations+1)); }

# ARM 4 — a declaration naming nothing shipped is STALE and refuses.
mkpkg 3; printf 'ghost.icn\tNEEDS_STDIN_FIXTURE\tnames no shipped file\n' > "$TD/p/UNGRADED.tsv"
examined=$((examined+1))
out="$(run_inv 2 0)"; rc=$?
if [ "$rc" -ne 2 ] || ! printf '%s' "$out" | grep -q 'declared but not shipped'; then
    echo "GATE FAIL: a stale declaration was not refused (rc=$rc): $out"; violations=$((violations+1))
fi

# ARM 5 — a program declared BOTH owed and impossible refuses: contradictory claims about one program.
mkpkg 3
printf 'f1.icn\tNEEDS_STDIN_FIXTURE\towed\n' > "$TD/p/UNGRADED.tsv"; printf 'f1.icn\tORACLE_REFUSES\timpossible\n' > "$TD/p/UNGRADABLE.tsv"
examined=$((examined+1))
out="$(run_inv 2 0)"; rc=$?
if [ "$rc" -ne 2 ] || ! printf '%s' "$out" | grep -q 'BOTH'; then
    echo "GATE FAIL: a name in both sidecars was not refused (rc=$rc): $out"; violations=$((violations+1))
fi

# ARM 6 — a declaration with NO REASON refuses. An inventory whose rows carry no reason is a number
# nobody can act on: the same failure one size down.
mkpkg 3; printf 'f1.icn\tNEEDS_STDIN_FIXTURE\t\n' > "$TD/p/UNGRADED.tsv"; rm -f "$TD/p/UNGRADABLE.tsv"
examined=$((examined+1))
out="$(run_inv 2 0)"; rc=$?
[ "$rc" -eq 2 ] || { echo "GATE FAIL: an unexplained declaration was not refused (rc=$rc): $out"; violations=$((violations+1)); }

# ARM 7 — ⛔ AN UNEXPLAINED NARROW BUCKET IS JUST A SMALLER LIE (hq_P). Claiming graded_narrow with no
# NARROW.tsv, or with a NARROW.tsv of the wrong size, must refuse: the count and the explanation are one
# population or the bucket is unfalsifiable.
mkpkg 3; rm -f "$TD/p"/*.tsv
examined=$((examined+1))
out="$(run_inv 2 1)"; rc=$?
if [ "$rc" -ne 2 ] || ! printf '%s' "$out" | grep -q 'NARROW.tsv'; then
    echo "GATE FAIL: graded_narrow claimed with no NARROW.tsv was not refused (rc=$rc): $out"; violations=$((violations+1))
fi
examined=$((examined+1))
printf 'f1.icn\tERRNO\terror compared by number only\nf2.icn\tERRNO\tsame\n' > "$TD/p/NARROW.tsv"
out="$(run_inv 2 1)"; rc=$?
if [ "$rc" -ne 2 ] || ! printf '%s' "$out" | grep -q 'same population'; then
    echo "GATE FAIL: graded_narrow disagreeing with NARROW.tsv's size was not refused (rc=$rc): $out"; violations=$((violations+1))
fi
examined=$((examined+1))
printf 'f1.icn\tERRNO\terror compared by number only\n' > "$TD/p/NARROW.tsv"
out="$(run_inv 2 1)"; rc=$?
if [ "$rc" -ne 0 ] || ! printf '%s' "$out" | grep -q 'graded_narrow=1'; then
    echo "GATE FAIL: a correctly explained narrow bucket did not pass (rc=$rc): $out"; violations=$((violations+1))
fi

# ARM 8 — ⛔⭐⭐ UNGRADABLE MUST NAME THE ORACLE'S REASON, NEVER OURS. hq_C measured the whole failure on
# prolog/swi_tests: EXCLUDED.md names 240 programs and 240 OF 240 give a SCRIP-side reason, zero give an
# oracle-side one. A program excluded because our own compiler fails it is A RED MOVED OUT OF THE
# DENOMINATOR -- the score cannot fall when we fail, because failing is what removes the entry, and the
# lockdown criterion becomes satisfiable BY failing. ⭐ This is an arm rather than a review note because
# every one of those 240 entries is individually honest and precisely documented: 240 true notes compose
# into a denominator that cannot fall, so entry-level diligence is exactly what hides it.
mkpkg 3; rm -f "$TD/p"/*.tsv
printf 'f3.icn\tORACLE_REFUSES\tscrip produces zero PASS/FAIL lines for this file today\n' > "$TD/p/UNGRADABLE.tsv"
examined=$((examined+1))
out="$(run_inv 2 0)"; rc=$?
if [ "$rc" -ne 2 ] || ! printf '%s' "$out" | grep -q 'OUR OWN COMPILER'; then
    echo "GATE FAIL: a scrip-side UNGRADABLE reason was not refused (rc=$rc): $out"; violations=$((violations+1))
fi
# and the control: an ORACLE-side reason for the same program is accepted, so the arm grades the REASON
# rather than merely rejecting the bucket.
examined=$((examined+1))
printf 'f3.icn\tNO_ORACLE_SHIPPED\tupstream ships no expected output for this program\n' > "$TD/p/UNGRADABLE.tsv"
out="$(run_inv 2 0)"; rc=$?
if [ "$rc" -ne 0 ]; then
    echo "GATE FAIL: an oracle-side UNGRADABLE reason was rejected (rc=$rc): $out"; violations=$((violations+1))
fi

# ARM 8b — ⭐⭐ THE ONE ADMITTED EXCEPTION, AND IT IS CONTROL-ARMED BOTH WAYS (ceo CEO-541, on hq_T's ask).
# icon/ipl's gincl/maccolor.icn names our compiler and is NOT a failure-as-reason: it states Arizona icont's
# own refusal verbatim, then upstream's control on the UNMODIFIED file, and only THEN that we refuse at the
# same line with the same class. That last clause is a CONTROL -- it strengthens the ruling by showing the
# row is not our own damage -- and the ruling passes the discriminator this arm has always used: IT STANDS
# UNCHANGED IF SCRIP WERE PERFECT AT EVERYTHING ELSE. ⛔ So the exception is granted BY A MARKER, never by a
# reader's judgement of the prose: `AGREEMENT-CONTROL:` prefixes our clause, and the text before it must name
# the oracle and must not name us. THE POSITIVE DIRECTION FIRST -- a properly-marked row is accepted.
mkpkg 3; rm -f "$TD/p"/*.tsv
examined=$((examined+1))
printf 'f3.icn\tORACLE_REFUSES\tArizona icont REFUSES IT AT COMPILE, rc=1, verbatim "Line 23 # \\"map16\\": invalid declaration", and upstream ships the identical refusal on the unmodified file. AGREEMENT-CONTROL: scrip refuses at the same line with the same class, so we agree.\n' > "$TD/p/UNGRADABLE.tsv"
out="$(run_inv 2 0)"; rc=$?
if [ "$rc" -ne 0 ]; then
    echo "GATE FAIL: a marked AGREEMENT-CONTROL row was refused (rc=$rc) -- CEO-541 admits it: $out"; violations=$((violations+1))
fi
# ⛔ AND THE NEGATIVE DIRECTION, WHICH IS THE HALF THAT KEEPS THE ARM HONEST. Three plants, each a way the
# marker could be used to smuggle a failure-as-reason past the check, and each must STILL refuse:
#   (a) the marker with NO oracle verdict before it -- the ruling rests on us and says so politely;
#   (b) the marker with our compiler named BEFORE it -- the oracle's verdict is no longer independent, which
#       is the exact tpp defect (a row citing BOTH), and CEO-541 explicitly did not weaken that precedent;
#   (c) the marker in the CLASS column rather than the reason -- admission by accident of spelling.
for _plant in \
  'f3.icn\tORACLE_REFUSES\tAGREEMENT-CONTROL: scrip produces zero PASS/FAIL lines for this file today\n' \
  'f3.icn\tORACLE_REFUSES\tscrip cannot compile it; icont refuses too. AGREEMENT-CONTROL: we agree with the oracle\n' \
  'f3.icn\tAGREEMENT-CONTROL\tscrip produces zero PASS/FAIL lines for this file today\n' ; do
    examined=$((examined+1))
    printf "$_plant" > "$TD/p/UNGRADABLE.tsv"
    out="$(run_inv 2 0)"; rc=$?
    # ⭐ THE ASSERTION IS "STILL REFUSED", NOT "REFUSED BY ARM 8" -- and plant (c) is why, measured on the
    # first run of this arm. The marker in the CLASS column is caught one check EARLIER, by the closed
    # vocabulary (AGREEMENT-CONTROL is not an UNGRADABLE class), so demanding ARM 8's own wording reported a
    # GATE FAIL for a row the body had correctly refused. ⛔ An arm that grades WHICH check fired, rather
    # than THAT the row was refused, fails whenever a second check gets there first -- and the second check
    # getting there first is a stronger outcome, not a weaker one.
    if [ "$rc" -ne 2 ]; then
        echo "GATE FAIL: a planted failure-as-reason row was ADMITTED by the marker (rc=$rc): $(printf "$_plant" | cut -c1-140)"
        echo "  ⛔ the marker must not be satisfiable by position alone -- the text before it must name the oracle and must not name us."
        violations=$((violations+1))
    fi
done

# ARM 8c — ⛔⭐ A COMMENT IS NOT A REASON, AND THE ARM MUST NOT FIRE ON ITS OWN DOCUMENTATION. Measured the
# moment CEO-541 was written into icon/ipl's header (hq_T 2026-09-10): the honesty scan read the WHOLE file,
# so a header sentence explaining that a program excluded because SCRIP fails it is a red moved out of the
# denominator REFUSED THE PACKAGE. ⭐ The cost of a check that answers a wider question than it was asked
# lands on the lane doing the right thing -- documenting the rule -- which is the worst possible place for it.
# Both directions here: the same text refuses as a data row and is ignored as a comment.
mkpkg 3; rm -f "$TD/p"/*.tsv
examined=$((examined+1))
{ printf '# a program excluded because SCRIP fails it is a RED MOVED OUT OF THE DENOMINATOR -- never write one\n'
  printf 'f3.icn\tNO_ORACLE_SHIPPED\tupstream ships no expected output for this program\n'; } > "$TD/p/UNGRADABLE.tsv"
out="$(run_inv 2 0)"; rc=$?
if [ "$rc" -ne 0 ]; then
    echo "GATE FAIL: a COMMENT naming our compiler refused the package (rc=$rc) -- the reason column is what this arm reads: $out"; violations=$((violations+1))
fi
# and the control: the identical sentence AS A ROW'S REASON still refuses, and names the row's true line number.
examined=$((examined+1))
{ printf '# header\n'
  printf 'f3.icn\tORACLE_REFUSES\ta program excluded because SCRIP fails it\n'; } > "$TD/p/UNGRADABLE.tsv"
out="$(run_inv 2 0)"; rc=$?
if [ "$rc" -ne 2 ] || ! printf '%s' "$out" | grep -q 'OUR OWN COMPILER'; then
    echo "GATE FAIL: the same sentence as a ROW's reason was not refused (rc=$rc): $out"; violations=$((violations+1))
fi
# ⛔ AND THE LINE NUMBER MUST BE THE FILE'S, NOT THE FILTERED STREAM'S -- the cure filters comments out before
# numbering would be the easy way to write this, and it renumbers every row a reader is then sent to look at.
examined=$((examined+1))
if ! printf '%s' "$out" | grep -qE '(^|[^0-9])2: *f3\.icn|(^|[^0-9])2:f3\.icn'; then
    echo "GATE FAIL: the refusal did not cite line 2, the row's real line in the file: $out"; violations=$((violations+1))
fi

# ARM 9 — an empty shipped population REFUSES rather than printing a clean zero. A percent over zero is
# not a score, and "0 ungraded" over 0 shipped would satisfy every lockdown criterion instantly.
rm -rf "$TD/p"; mkdir -p "$TD/p"; INV_DIR="$TD/p"
examined=$((examined+1))
out="$(run_inv 0 0)"; rc=$?
[ "$rc" -eq 2 ] || { echo "GATE FAIL: an empty package was not refused (rc=$rc): $out"; violations=$((violations+1)); }

# ARM 10 — a moved package REFUSES rather than reinterpreting.
INV_DIR="$TD/does-not-exist"
examined=$((examined+1))
out="$(run_inv 0 0)"; rc=$?
[ "$rc" -eq 2 ] || { echo "GATE FAIL: a missing package dir was not refused (rc=$rc): $out"; violations=$((violations+1)); }

# ARM 12 — ⛔⭐⭐ THE DECLARATION MATCHER MUST BE DETERMINISTIC, and it was not. Measured 2026-09-06 on
# icon/ipl: five runs of identical code over an identical tree reported 127, 137, 139, 125 and 138
# "declared but not shipped" programs, EVERY ONE OF THEM FALSE. The matcher was
# `printf '%s\n' "${found[@]}" | grep -qxF "$nm"`, and every package runner sets `pipefail`; `grep -q`
# exits at the first match, SIGPIPEs the printf, and the pipeline reports 141. Whether printf finishes
# first is a RACE, so the answer depended on scheduling.
# ⭐⭐ WHY THIS OUTRANKS THE WRONG COUNT: this is the arm that catches a STALE declaration — a ruling
# that no longer names a file. Under the race it accused 211 live files at once, so a real stale entry
# was indistinguishable from the noise, and the honest response to the refusal was to disbelieve it.
# ⛔ AND IT COULD NOT BE SEEN AT FIXTURE SCALE: with three files printf always wins, so every arm above
# passed on the day it landed. hq_I's rule, from the arizona determinism case the same morning: A CHECK
# THAT CANNOT FAIL FOR THE REASON YOU ARE ASKING ABOUT IS NOT A WEAK CHECK. ⭐ This arm was itself written
# wrong once and caught by that rule: at 600 short names it passed against the KNOWN-BAD body, because the
# defect needs the pipe to actually fill. Five INDEPENDENT runs are compared against each other — never a
# back-to-back pair inside one process, hq_I's other measured warning from the same morning.
# ⛔⭐ THE WITNESS HAS TWO INGREDIENTS AND NEITHER IS OPTIONAL: the name list must EXCEED THE 64K PIPE
# BUFFER (800 long names = 72000 bytes) and the declared name must match EARLY, so `grep -q` exits while
# `printf` is still writing. With three short names printf's whole output fits in one buffer, it never
# blocks, EPIPE never happens, and the arm silently grades nothing — which is why eleven arms passed over
# the defect on the day it landed. Measured 2026-09-06: 5/5 false refusals pre-cure, 5/5 clean post-cure.
rm -rf "$TD/big"; mkdir -p "$TD/big/sub"
_n='a_program_name_long_enough_that_eight_hundred_of_them_exceed_the_64k_pipe_buffer'
for i in $(seq -w 1 600); do echo 'procedure main(); end' > "$TD/big/${_n}_$i.icn"; done
for i in $(seq -w 1 200); do echo 'procedure main(); end' > "$TD/big/sub/${_n}_s$i.icn"; done
_first="$(basename "$(find "$TD/big" -type f -name '*.icn' | head -1)")"
printf '%s\tNEEDS_STDIN_FIXTURE\tthe name grep -q matches first, so printf is still writing when the pipe closes\n' "$_first" > "$TD/big/UNGRADED.tsv"
printf 'sub/%s_s001.icn\tNO_ORACLE_SHIPPED\tdeclared by package-relative path, in a subdirectory\n' "$_n" > "$TD/big/UNGRADABLE.tsv"
INV_PACKAGE=big; INV_DIR="$TD/big"; INV_EXT=".icn"
# ⛔⭐⭐ AND THE ARM ASSERTS AGREEMENT **AND** CORRECTNESS, because stability alone is satisfiable by
# being consistently wrong — which is exactly what the known-bad body does on this fixture: 5/5 IDENTICAL
# false refusals, so an agreement-only check goes green over the defect it was written for. (It is
# unstable at ipl's scale and stable here; both are the same bug, and only the correctness half sees both.)
# ⭐ This arm was written agreement-only first and caught by running it against the pre-cure body, which is
# the whole reason a new gate arm must be proven to fail once before it lands.
_want='PACKAGE_INVENTORY package=big shipped=800 graded=798 ungraded=1 ungradable=1 deferred=0 graded_stream=798 graded_narrow=0'
examined=$((examined+1))
first=""; unstable=0; wrong=0
for i in 1 2 3 4 5; do
    out="$(run_inv 798 0)"; rc=$?
    [ -n "$first" ] || first="$rc|$out"
    [ "$rc|$out" = "$first" ] || unstable=1
    { [ "$rc" -eq 0 ] && [ "$out" = "$_want" ]; } || wrong=1
done
[ "$unstable" -eq 0 ] || { echo "GATE FAIL: the declaration matcher is NONDETERMINISTIC over 800 files -- five runs did not agree"; violations=$((violations+1)); }
[ "$wrong" -eq 0 ]    || { echo "GATE FAIL: the declaration matcher is stably WRONG over 800 files -- $first"; violations=$((violations+1)); }

# ARM 13 — and the stable answer must be the RIGHT one. Two ways it was wrong at once: the race accused
# live files, and the census indexed BASENAMES, so ipl's 390 `procs/…`/`gprocs/…` declarations could
# never match anything and were reported missing wholesale even when printf won.
examined=$((examined+1))
out="$(run_inv 798 0)"; rc=$?
want='PACKAGE_INVENTORY package=big shipped=800 graded=798 ungraded=1 ungradable=1 deferred=0 graded_stream=798 graded_narrow=0'
if [ "$rc" -ne 0 ] || [ "$out" != "$want" ]; then
    echo "GATE FAIL: a package-relative declaration did not resolve (rc=$rc): $out"; violations=$((violations+1))
fi

# ARM 14 — ⛔ A BARE NAME IS ONLY A NAME WHILE IT IS UNIQUE. ipl ships four collisions across procs/ and
# progs/ (gener, morse, repeats, spokes); a bare `gener.icn` ruling would land on whichever the census
# reached first, which is the ambiguity the race above made invisible. Refuse and ask for the path.
rm -rf "$TD/dup"; mkdir -p "$TD/dup/a" "$TD/dup/b"
echo x > "$TD/dup/a/same.icn"; echo x > "$TD/dup/b/same.icn"; echo x > "$TD/dup/only.icn"
printf 'same.icn\tNO_ORACLE_SHIPPED\ta bare name that matches two shipped files\n' > "$TD/dup/UNGRADABLE.tsv"
INV_PACKAGE=dup; INV_DIR="$TD/dup"; INV_EXT=".icn"
examined=$((examined+1))
out="$(run_inv 2 0)"; rc=$?
if [ "$rc" -ne 2 ] || ! printf '%s' "$out" | grep -q 'BARE NAME'; then
    echo "GATE FAIL: an ambiguous bare declaration was not refused (rc=$rc): $out"; violations=$((violations+1))
fi

# ARM 15 — ⛔⭐ OUR OWN GENERATED RUNGS IS NOT A SHIPPED PROGRAM. Four packages carry an `ALL.<ext>`
# beside the vendor's files. Counting it inflates `shipped` by one and makes the SUM unreachable by one
# forever. ⭐ It was also the entire 851-vs-852 disagreement between hq_I's Icon runner and this body —
# two correct instruments answering different questions, neither able to say which.
rm -rf "$TD/gen"; mkdir -p "$TD/gen"
echo x > "$TD/gen/v1.icn"; echo x > "$TD/gen/v2.icn"; echo x > "$TD/gen/ALL.icn"
INV_PACKAGE=gen; INV_DIR="$TD/gen"; INV_EXT=".icn"
examined=$((examined+1))
out="$(run_inv 2 0)"; rc=$?
if [ "$rc" -ne 0 ] || ! printf '%s' "$out" | grep -q 'shipped=2 '; then
    echo "GATE FAIL: the generated ALL.icn rungs was counted as a shipped program (rc=$rc): $out"; violations=$((violations+1))
fi

# ARM 16 — THE VOCABULARY IS CLOSED (hq_T ruling 2026-09-06). An unknown class refuses; a legacy spelling
# is accepted with a warning so no lane's board breaks on the ruling and the debt stays countable.
mkpkg 3; rm -f "$TD/p"/*.tsv
printf 'f3.icn\tHANDWAVE\ta class nobody ruled\n' > "$TD/p/UNGRADED.tsv"
examined=$((examined+1))
out="$(run_inv 2 0)"; rc=$?
if [ "$rc" -ne 2 ] || ! printf '%s' "$out" | grep -q 'vocabulary is CLOSED'; then
    echo "GATE FAIL: an unruled reason code was accepted (rc=$rc): $out"; violations=$((violations+1))
fi
examined=$((examined+1))
printf 'f3.icn\tEMPTY\tthe pre-ruling spelling, still in 106 ipl rows\n' > "$TD/p/UNGRADED.tsv"
out="$(run_inv 2 0)"; rc=$?
if [ "$rc" -ne 0 ] || ! printf '%s' "$out" | grep -q 'LEGACY CLASS'; then
    echo "GATE FAIL: a legacy class did not warn-and-pass (rc=$rc): $out"; violations=$((violations+1))
fi
# ⛔ and the two vocabularies do not share members: UNGRADABLE names what the ORACLE did, UNGRADED names
# what is OWED, so a class may not drift between the files.
mkpkg 3; rm -f "$TD/p"/*.tsv
printf 'f3.icn\tNEEDS_STDIN_FIXTURE\ta task, filed as a ruling\n' > "$TD/p/UNGRADABLE.tsv"
examined=$((examined+1))
out="$(run_inv 2 0)"; rc=$?
if [ "$rc" -ne 2 ]; then
    echo "GATE FAIL: an UNGRADED class was accepted in UNGRADABLE (rc=$rc): $out"; violations=$((violations+1))
fi

# ⛔⭐⭐ ARM 18 — THE READER MUST JOIN THE RUNNER'S OWN `package=` TOKEN TO THE TABLE'S LABEL, AND IT DID NOT
# AT TWO OF THREE JOIN SITES (hq_T 2026-09-10, row package-shipped-per-lane-printed-by-the-runner-not-
# transcribed). Every arm above grades what the RUNNER writes. This one grades what the READER does with it,
# because carriage that nothing reads is not carriage. `inventory_clauses()` is keyed by the runner's token
# and `PROGRESS_COUNTED` by the display label, and three pairs differ today: pat/PAT, gnu_prolog/gnu,
# snoflake_suite/snoflake. A 2026-09-06 cure matched them for the DENOMINATOR and left `name in inv` spelled
# at the other two sites, so the reader printed "⚠ PAT carries NO PACKAGE_INVENTORY clause ... Retrofit the
# runner and paste its own line into the cell" about a clause sitting in the cell it had just parsed -- a
# work item for work already done, issued by the only instrument that could have reported it.
# ⛔ AND THE QUIETER HALF IS THE ONE THIS GATE EXISTS FOR: on a miss the shipped population fell through to
# the PACKAGE_SHIPPED dict, which holds no entry for those languages, so shipped read 0 and THE UNGRADED
# REMAINDER WAS NEVER BOOKED AS NOT-RUN. A package could ship 851 and grade 89 and contribute no inventory
# at all -- the never-graded business, hidden by a spelling, inside the function written to end it.
# ⭐ HERMETIC AND MUTATION-PROVED: the fixture is a V cell built here, never the live board, and the arm was
# confirmed to RED against an ablated reader (the matched join reverted to the spelled one) before landing.
examined=$((examined+1))
python3 - "$HERE" <<'ARM18'
import sys, os
sys.path.insert(0, sys.argv[1])
import util_score_row as U
bad = 0
# the three spellings measured on the live board, plus an exact match as the control
for lang, label, key, shipped, graded in (("pascal", "PAT", "pat", 427, 425),
                                          ("prolog", "gnu", "gnu_prolog", 62, 11),
                                          ("snobol4", "snoflake", "snoflake_suite", 180, 103),
                                          ("icon", "jcon", "jcon", 91, 78)):
    names = [n for n, _rx, _d in U.PROGRESS_COUNTED.get(lang, [])]
    if label not in names:
        print("    ARM 18 REFUSES(2): %s is no longer a %s package in PROGRESS_COUNTED (names=%s) -- the "
              "fixture describes a table that has moved, and a stale fixture must not pass" % (label, lang, names))
        sys.exit(2)
    cell = ("%s: m3 %d/%d graded · PACKAGE_INVENTORY package=%s shipped=%d graded=%d ungraded=0 "
            "ungradable=%d graded_stream=%d graded_narrow=0 (`test_%s_suite.sh`)"
            % (label, graded, graded, key, shipped, graded, shipped - graded, graded, key))
    got, work = U.counted_fractions(lang, cell)
    missing = [w for w in work if "carry NO PACKAGE_INVENTORY clause" in w and label in w]
    if missing:
        print("    ARM 18 FAIL: the reader says %s/%s carries no inventory clause while parsing a cell that "
              "carries `package=%s`. The join is spelled, not matched." % (lang, label, key))
        bad += 1
    booked = [n for n, _c in got.notrun if n.startswith(label + " (ungraded remainder")]
    if shipped > graded and not booked:
        print("    ARM 18 FAIL: %s/%s ships %d and grades %d, and the reader booked NO ungraded remainder -- "
              "%d programs in no bucket, which is the never-graded defect this gate exists to catch."
              % (lang, label, shipped, graded, shipped - graded))
        bad += 1
    transcribed = [w for w in work if "PACKAGE_SHIPPED" in w and label in w]
    if transcribed:
        print("    ARM 18 FAIL: %s/%s took its shipped population from the PACKAGE_SHIPPED dict while its own "
              "runner's clause was in the cell." % (lang, label))
        bad += 1
sys.exit(1 if bad else 0)
ARM18
_a18=$?
if [ "$_a18" -eq 2 ]; then
    echo "GATE REFUSES(2): ARM 18 could not measure (its fixture no longer describes PROGRESS_COUNTED)"; exit 2
elif [ "$_a18" -ne 0 ]; then
    violations=$((violations+1))
fi


# ARM 11 — THE CENSUS, WITH ITS DENOMINATOR PRINTED. Every package runner must reach the shared body.
# ⚠ REPORTED, NOT COUNTED, WHILE THE ROW RAMPS: the instrument landed before its callers, so naming them
# is the work list, not a verdict. ⭐ It prints the denominator rather than a boolean for the reason the
# stale-binary gate's census arm does: that arm caught THIS author shipping a gate with no freshness
# guard on the day it landed (gates=97 wired=96 uncovered=1), which a boolean could not have done.
# ⛔⭐⭐ AND IT COUNTS WHAT IT CAN PROVE, IN THREE TIERS, BECAUSE "WIRED" WAS A CLAIM THIS GATE COULD NOT
# SUPPORT (hq_I, 2026-09-06, and they were right). It greps for the stanza, so it counted runners that
# COULD emit a line, not runners that DO -- and those differed for EVERY runner wired so far. jcon is the
# worked case: it sourced the body and called it, the census said wired=1, and it could not emit a line at
# all, because its UNGRADED.tsv was 2-column and its call SWALLOWED the refusal into a warning. A number
# that is wrong for every member of its population is not a census, and the ceo has since made this report
# load-bearing under Lon's order, which is the worst moment to be carrying an unprovable claim.
# ⭐ STATIC ANALYSIS CANNOT PROVE EMISSION -- only running the runner does, and that is board_packages.sh's
# job, not a 2-second mktemp-only gate's. So the honest move is not a cleverer grep: it is to stop printing
# one number, print the three that ARE decidable from the source, and name the gap the gate cannot close.
runners=0; sources=0; calls=0; swallows=0; missing=""; partial=""; swallowed=""; notpkg=""
writers=0; carries=0; nocarry=""; blindcarry=""
for r in "$HERE"/test_*_suite.sh "$HERE"/raku_roast_scoreboard.sh "$HERE"/board_packages.sh; do
    [ -f "$r" ] || continue
    b="$(basename "$r")"
    # ⛔⭐ AN AGGREGATOR IS NOT AN EMITTER, and this census called one broken within minutes of landing.
    # board_packages.sh READS other runners' lines; it sets no stanza and emits none, correctly. Judged by
    # the emitter's checklist it read as "sources the body with an INCOMPLETE STANZA -- wired to REFUSE",
    # which is a false accusation against the one caller doing exactly what it should. ⭐ Same shape as the
    # defect this arm was rewritten to cure one commit earlier: a census that counts the wrong population
    # is wrong for every member of it, and it is loudest about the members that are most correct.
    case "$b" in board_*.sh) continue ;; esac
    # ⛔⭐ A CONSTRUCT-LADDER/STRESS RUNNER OVER OUR OWN CORPUS IS NOT A VENDORED-PACKAGE RUNNER EITHER
    # (seat12, 2026-09-06). This row's population is "every program a VENDORED PACKAGE SHIPS" (the task's
    # own GOAL text, row every-package-runner-prints-...) -- a ladder/stress suite over corpus/crosscheck
    # or a hand-built rung corpus has no vendor and nothing "shipped" to name shipped=/ungradable= against;
    # forcing one to grow a package-inventory line is the same category error CLAUDE.md names for running
    # an ALL.<ext> rungs whole ("both are artifacts of the wrong invocation, never findings"). Verified
    # structurally, not asserted: EVERY runner wired onto lib_inventory.sh (12/12 measured this sitting)
    # references corpus/packages/ literally; every runner that does not was individually read (not just
    # grepped) and confirmed to be a construct-ladder/stress suite: test_gc_stress_suite.sh (corpus/
    # crosscheck/gc/ GC torture matrix), test_icon_rung_suite.sh / test_prolog_rung_suite.sh (rung ladders,
    # GOAL-ICON-BB/GOAL-PROLOG-BB), test_snobol4_pat_rung_suite.sh (SNOBOL4 pattern rung suite). NAMED, not
    # silently shrunk -- see the report line below; a new runner earns inclusion by shipping a vendored
    # package, not by matching a glob.
    # ⛔ THE PATTERN MATCHES THE PATH SHAPE, NOT THE LITERAL STRING "corpus/packages" -- caught live:
    # test_csnobol4_budne_suite.sh builds its path as `$CORPUS/packages/snobol4/csnobol4_suite`, so the
    # literal substring "corpus/packages" never appears in the file and a naive grep misclassified a REAL
    # vendored-package runner (deliberately unwired for its own, different, already-ruled reason -- a
    # stale mode-2 (--run) duplicate of test_snobol4_csnobol4_suite.sh, modes 1/2 DELETED per CLAUDE.md,
    # see board_packages.sh's own comment) as if no vendor shipped it at all. /packages/<name>/ matches
    # both the literal and the variable-built form and was re-verified to still exclude all nine genuine
    # construct-ladder/stress runners (seat12, 2026-09-06).
    grep -qE '/packages/[a-z0-9_]+/' "$r" || { notpkg="$notpkg $b"; continue; }
    runners=$((runners+1))
    # ⛔⭐ GREP THE CODE, NOT THE COMMENTARY -- THIS ARM WAS FRAGILE TO THE DELETION IT EXISTS TO CATCH
    # (hq_P routed 2026-09-13 with the table; landed by hq_B, census re-measured here rather than relayed).
    # Every token below was matched against the RAW file, so a runner naming it in a COMMENT satisfied the arm
    # whether or not the code did. Delete the real `inventory_line` call from any of six runners --
    # test_icon_arizona_suite.sh, test_icon_jcon_suite.sh, test_pascal_pat_suite.sh,
    # test_snobol4_csnobol4_suite.sh, test_snobol4_gimpel_suite.sh, test_snobol4_spitbol_testpgms_suite.sh
    # (raw=2, non-comment=1 in each) -- and this arm stayed green on the surviving comment.
    # ⭐ WIDENED BEYOND THE TOKEN THAT WAS REPORTED, which is the half worth keeping: hq_P named
    # `inventory_line` (6 runners), but `lib_inventory.sh` -- the GATEKEEPER grep, the one that decides a
    # runner is wired at all -- is fragile in FOURTEEN of the fifteen. Curing only the reported token would
    # have left the weaker check guarding the stronger one. ✅ NOTHING IS INERT TODAY: measured across all
    # five tokens and all fifteen runners, no token appears ONLY in comments, so this is fragility to a
    # future deletion, not a live false green. Stripping is done ONCE per runner, not per grep.
    body="$(sed 's/^[[:space:]]*#.*$//' "$r")"
    grep -q 'lib_inventory.sh' <<<"$body" || { missing="$missing $b"; continue; }
    sources=$((sources+1))
    # a COMPLETE stanza: all three tokens plus the call. A missing INV_EXT refuses at run time, so a
    # runner that sources the body and sets two of three is wired to refuse, not wired to report.
    if grep -q 'inventory_line' <<<"$body" && grep -q 'INV_PACKAGE=' <<<"$body" && grep -q 'INV_DIR=' <<<"$body" && grep -q 'INV_EXT=' <<<"$body"; then
        calls=$((calls+1))
    else
        partial="$partial $b"; continue
    fi
    # ⛔ AND A SWALLOWED REFUSAL IS THE jcon CASE EXACTLY: `inventory_line ... || echo "warn"` turns rc=2
    # into a line nobody reads, so a package can refuse on every run while the board stays quiet.
    grep -qE 'inventory_line[^|&]*(\|\||&&|2>/dev/null)' <<<"$body" && { swallows=$((swallows+1)); swallowed="$swallowed $b"; }
    # ⛔⭐⭐ ARM 17 — THE CARRIAGE HALF, AND IT IS A VIOLATION, NOT A REPORT (row package-shipped-per-lane-
    # printed-by-the-runner-not-transcribed, hq_T 2026-09-10). ARM 11 above grades whether a runner can
    # PRINT its inventory; this arm grades whether the number REACHES THE LEADERBOARD. Printing it on a
    # board line that scrolls off a terminal is not carriage: util_score_row.py's inventory_clauses() reads
    # the V CELL, and a package whose cell carries no clause falls back to PACKAGE_SHIPPED -- three integers
    # typed into util_score_row.py by a reader of somebody else's board, which is the defect the row exists
    # to end. ⭐ THE MEASURED WITNESS, and it is why this is a violation: test_icon_jcon_suite.sh printed a
    # correct PACKAGE_INVENTORY line on every run for four days AND wrote a leaderboard cell that said
    # "of 91 shipped, 76 graded, 15 ungraded" in prose -- so the reader took jcon's shipped population from
    # the typed dict while the true number stood one line above in the same script's own output. A runner
    # that measures a number and then hands the leaderboard a hand-written restatement of it has done the
    # measuring and skipped the reporting, and nothing about the board line reveals that.
    # ⛔ THE SPLICE MUST BE CONDITIONAL ON THE CAPTURE (`${VAR:+ ...}`) AND THE ARM CHECKS THAT SEPARATELY:
    # an unconditional splice publishes an EMPTY clause when inventory_line REFUSED, which reads to the next
    # reader as a measured absence rather than a refusal -- the rc=2-as-zero collapse this gate rejects in
    # every other arm. So a runner is graded on two properties, and either one alone earns a name here.
    grep -qE 'util_score_row\.py"? +write' "$r" || continue
    writers=$((writers+1))
    _iv="$(grep -oE '[A-Za-z_][A-Za-z0-9_]*="\$\(inventory_line' "$r" | head -1 | sed 's/=.*//')"
    if [ -z "$_iv" ]; then
        nocarry="$nocarry $b"
    elif grep -qF "\${$_iv:+" "$r"; then
        carries=$((carries+1))
    else
        blindcarry="$blindcarry $b($_iv)"
    fi
done
echo "    package runners censused=$runners  sources=$sources  complete-stanza=$calls  unwired=$((runners-sources))  [aggregators excluded: they read lines, never emit one]"
echo "    ⚠ NOT DECIDABLE HERE: whether a runner actually EMITS a summing line. Only running it proves that (board_packages.sh)."
[ -z "$notpkg" ]    || { echo "    NOT A VENDORED-PACKAGE RUNNER (excluded from this population -- no /packages/<name>/ path, nothing a vendor ships, never wire):"; printf '      %s\n' $notpkg; }
[ -z "$missing" ]   || { echo "    NOT YET WIRED (the row's work list, not a verdict):"; printf '      %s\n' $missing; }
# ⛔⭐ AN INCOMPLETE STANZA IS A VIOLATION, NOT A REPORT -- AND MAKING IT ONE IS THE OTHER HALF OF THE
# COMMENT-STRIPPING CURE ABOVE, WITHOUT WHICH THAT CURE IS A NET LOSS (hq_B 2026-09-13, measured).
# ⭐ THE MEASUREMENT, WHICH INVERTED WHAT I EXPECTED AND IS THE REASON THIS BLOCK EXISTS: with the live
# `inventory_line` call deleted from test_icon_jcon_suite.sh and its comment left behind, the OLD body
# counted complete-stanza=15 -- the WRONG number, fooled by the comment exactly as hq_P reported -- and
# still exited rc=1 with 1 violation, because counting jcon complete let it fall through to a later arm
# that caught the missing call. The freshly comment-stripped body counted complete-stanza=14 -- the RIGHT
# number -- and exited rc=0, because a partial stanza `continue`s out of the loop before reaching that arm.
# So stripping the comments ALONE traded a wrong count for a MISSED VIOLATION: the fragile grep had been
# load-bearing for detection, and curing the number quietly removed the detection it was accidentally
# providing. ⛔ THE GENERAL SHAPE, worth more than this arm: when a check is wrong in a way that makes it
# OVER-count, something downstream may be depending on the over-count, and a cure that only fixes the
# number can subtract power while every report line looks better. Measure the CURED gate against the
# deletion, never just the census against the tree.
# ✅ SAFE TODAY, MEASURED: on the clean tree sources=15 and complete-stanza=15, so this books zero
# violations now; it is a floor against a future deletion, not a red being introduced.
if [ -n "$partial" ]; then
    echo "    ⛔ SOURCES THE BODY WITH AN INCOMPLETE STANZA -- wired to REFUSE, not to report:"; printf '      %s\n' $partial
    echo "GATE FAIL: a package runner sources lib_inventory.sh with an incomplete stanza (a comment naming a token is not the token):$partial"
    violations=$((violations+1))
fi
[ -z "$swallowed" ] || { echo "    ⛔ SWALLOWS THE REFUSAL (rc=2 becomes a warning nobody reads -- the jcon case):"; printf '      %s\n' $swallowed; }
echo "    leaderboard writers=$writers  carry their own inventory clause into the cell=$carries"
if [ -n "$nocarry" ]; then
    echo "GATE FAIL: $(set -- $nocarry; echo $#) package runner(s) write a SCORE.md row WITHOUT carrying their own"
    echo "    PACKAGE_INVENTORY clause into it -- the cell's shipped population is transcribed (or falls back to"
    echo "    util_score_row.py's PACKAGE_SHIPPED dict) while the runner's own measurement scrolls past on stdout."
    echo "    CURE: _iv=\"\$(inventory_line <graded> 0)\"; echo it; then splice \${_iv:+ · \$_iv (\`<runner>.sh\`)} into --text."
    printf '      %s\n' $nocarry
    violations=$((violations+1))
fi
if [ -n "$blindcarry" ]; then
    echo "GATE FAIL: $(set -- $blindcarry; echo $#) package runner(s) capture the inventory line but splice it"
    echo "    UNCONDITIONALLY -- when inventory_line REFUSES (rc=2) the cell publishes an empty clause, which the"
    echo "    next reader cannot tell from a measured absence. Guard the splice with \${VAR:+ ...}."
    printf '      %s\n' $blindcarry
    violations=$((violations+1))
fi

# ⛔⭐⭐ ARM 19 — THE LIVE BOARD, AND IT IS RATCHETED BY NAME (hq_T 2026-09-10, row package-shipped-per-lane-
# printed-by-the-runner-not-transcribed). ARM 17 grades the CARRIAGE (does the runner splice its clause) and
# ARM 18 grades the READER (does the join find it), and both are hermetic — ARM 18 builds its own V cell and
# deliberately never opens SCORE.md. That is right for a unit arm and it left exactly one thing ungraded:
# THE BOARD ITSELF. ⛔ THE MEASURED WITNESS, and it is why this arm exists: jcon's runner-written clause was
# cured onto the board at .github `9c5f53b5` and was GONE by `03c6ca3a` six hours later — a rebase-conflict
# resolution that took the older side restored the pre-cure prose verbatim, digits and all ("of 91 shipped,
# 76 graded, 15 ungraded"), on a cell whose true reading was 78 graded / 13 not. Every arm above stayed
# green through it: the runner still carried its clause, the reader still joined correctly, and the only
# instrument that could see the loss was the row's own DONE-WHEN, which lives in a baton and runs when a
# seat happens to read it. ⭐ THE GENERAL FORM: a cure that lands in a FILE is protected by the gate that
# grades the file; a cure that lands in a CELL of a file twelve seats rewrite all day is protected by
# nothing unless something re-reads the cell. Carriage that nothing reads is not carriage — and neither is
# carriage that arrives and is then overwritten.
# ⛔ WHY A PIN BY NAME AND NOT A COUNT. Seven of fifteen packages have no clause today and all seven are
# under a PARKED-LON-HOLD language, so a strict arm would red the whole fleet for work nobody is allowed to
# do. A count would also be a number typed into a script — the very defect this row is about — and a wrong
# one passes silently. A pinned NAME is checkable: every name is verified to still be a package of its lane
# in PROGRESS_COUNTED, so a stale pin REFUSES rc=2 instead of passing, and a lost clause is named directly.
# ⭐ The unpinned remainder is printed as the work list with its denominator, never counted into the verdict
# (ARM 11's doctrine: a gate that red-lights on work not yet done gets switched off by the first person it
# blocks for a good reason). A package that GAINS a clause prints the one-line raise instruction.
# ⭐ HERMETIC WHEN IT NEEDS TO BE: the board path is PKGINV_BOARD, defaulting to the live one, so the arm was
# mutation-proved against a doctored copy (jcon's clause deleted -> RED naming jcon; a pin renamed -> rc=2)
# before landing. ⛔ AND THE CURE IS NEVER A HAND EDIT: re-run the package's own runner, which rewrites the
# cell in place. Restoring a clause by typing it back is this row's defect wearing the cure's clothes.
examined=$((examined+1))
PKGINV_BOARD="${PKGINV_BOARD:-$ROOT/../.github/SCORE.md}"
if [ ! -f "$PKGINV_BOARD" ]; then
    echo "GATE REFUSES(2): ARM 19 found no board at $PKGINV_BOARD -- cannot measure whether a cell lost its clause"
    exit 2
fi
SCORE_MD="$PKGINV_BOARD" python3 - "$HERE" <<'ARM19'
import io, os, sys
sys.path.insert(0, sys.argv[1])
import util_score_row as U
# THE RATCHET, measured off the live board 2026-09-10 by hq_T and raised only by measurement.
PINNED = {"icon":    ["arizona", "ipl", "jcon"],
          "pascal":  ["fpc", "PAT"],
          "prolog":  ["gnu"],
          "snobol4": ["csnobol4", "snoflake"]}
# ⛔⭐⭐ THE TABLE IS FOUND BY THE ONE WRITER'S OWN FINDER, NOT BY A SECOND POSITIONAL COPY OF THE JOIN
# (coo 2026-09-20, measured). THIS ARM GRADED A TABLE NO RUNNER CAN WRITE, and it is the third instance of
# the shape util_score_row.py's own comments already record twice -- counted_fractions' "compute the join
# ONCE, name it, and leave no second way to spell it", and find_table's "Shape is the identity here, never
# position". What the two copies disagreed about, exactly:
#   * SCORE.md carries THREE '| icon |' rows in TWO grids. find_table() -- the ONE writer's finder -- takes
#     the grid that PROVES its shape (6 columns, index 4 headed "Vendor / package suites") and refuses to
#     write into any other; table_shape_error() rejects the 8-column M/L/V display outright. So `--column
#     vendor`, which every package runner passes, can land in ONE cell and one only.
#   * this arm selected `ln.count('|') >= 8` and then read `ln.split('|')[4]` WITHOUT stripping the outer
#     pipes -- so it bound to the 8-column display (the grid CEO-174 added ABOVE the standardized one on
#     2026-09-03, named in find_table's comment as the reason position is not identity) and read a cell the
#     one writer is forbidden to touch. Two errors that cancelled into a plausible-looking number.
# ⛔ THE MEASURED COST, and it is the arizona report this arm has been printing: arizona's clause is
# PRESENT, SUMMING (124 = graded 90 + ungraded 0 + ungradable 34) and written BY ITS OWN RUNNER into the only
# cell the writer may write -- and this arm called it ABSENT and told the reader to re-run the runner that had
# already done the work correctly. A diagnostic that names the wrong cure is worse than one that stays quiet,
# because the cure it names is expensive and its failure teaches nothing. The clauses this arm DID find
# (ipl, jcon) are in the unwritable display, i.e. hand-transcribed -- which is the very thing it exists to
# catch, and it was scoring them as the compliant case.
# ⭐ THE REUSABLE HALF: an arm that grades "did the writer write it" MUST locate the cell the way the
# writer locates it, by calling the writer's own finder. Any second spelling of that join grades a different
# board, and will do so silently, because a missing clause and a mis-addressed read look identical.
lines = io.open(os.environ['SCORE_MD'], encoding='utf-8').read().split('\n')
U.SCORE_MD = os.environ['SCORE_MD']          # find_table names this path in its refusals
_hdr, _rows, _skipped = U.find_table(lines)  # die()s rc=2 -- "could not measure", never a violation
cells = {}
for _lang, (_i, _c) in _rows.items():
    if _lang in U.PROGRESS_COUNTED:
        cells[_lang] = _c[U.COLUMNS['vendor'][0]]
print("    ARM 19 board grid=header line %d (found by util_score_row.find_table, the one writer's own finder)"
      "  rows=%d  counted langs=%s%s"
      % (_hdr + 1, len(_rows), ",".join(sorted(cells)),
         "  SKIPPED mis-shaped rows=%s" % ",".join(sorted(_skipped)) if _skipped else ""))
bad, gained, lacking, pinned_n = 0, [], [], 0
for lang in sorted(U.PROGRESS_COUNTED):
    names = [n for n, _rx, _d in U.PROGRESS_COUNTED[lang]]
    for want in PINNED.get(lang, []):
        if want not in names:
            print("    ARM 19 REFUSES(2): pinned package %s/%s is no longer in PROGRESS_COUNTED (names=%s) --"
                  " the ratchet describes a table that has moved, and a stale pin must not pass" % (lang, want, names))
            sys.exit(2)
    if lang not in cells:
        print("    ARM 19 REFUSES(2): no %s row on the board -- cannot measure" % lang)
        sys.exit(2)
    _got, work = U.counted_fractions(lang, cells[lang])
    def lost(n):
        return [w for w in work if ('PACKAGE_SHIPPED' in w or 'carry NO PACKAGE_INVENTORY clause' in w) and n in w]
    for want in PINNED.get(lang, []):
        pinned_n += 1
        why = lost(want)
        if why:
            print("    ARM 19 FAIL: %s/%s HAD a runner-written PACKAGE_INVENTORY clause on the board and no longer"
                  " does -- its shipped population is transcribed again." % (lang, want))
            print("        reader says: " + why[0][:200])
            bad += 1
    for n in names:
        if n in PINNED.get(lang, []):
            continue
        (lacking if lost(n) else gained).append("%s/%s" % (lang, n))
print("    ARM 19 board=%s  pinned packages holding their own clause=%d/%d"
      % (os.path.basename(os.environ['SCORE_MD']), pinned_n - bad, pinned_n))
if lacking:
    # ⛔ THIS LINE USED TO END "every one is PARKED-LON-HOLD" AND THAT WAS TWICE WRONG BY 2026-09-11. CEO-546
    # (2026-09-10 19:2x) reopened SNOBOL4 for the seats whose Icon rows closed, and four of the seven named
    # here are snobol4 -- so the clause that told a reader this list was unreachable had outlived its ruling.
    # ⭐ AND THE DEEPER ERROR IS THAT IT NAMED A CAUSE AT ALL: "no clause yet" has at least four causes, and
    # for those same four snobol4 packages the answer is that their carriage is CORRECT and pushed, and only
    # a suite pass is owed. A work list that states the wrong cause is worse than one that states none.
    print("    NO RUNNER-WRITTEN CLAUSE YET (the row's work list, not a verdict -- ⛔ this arm does NOT know"
          " why, and only one of the four causes is carriage work; run util_package_inventory_cause.sh"
          " <lang> <label> <regex>, or the reader that calls it per package): "
          + ", ".join(sorted(lacking)))
if gained:
    print("    ⭐ RAISE THE RATCHET: %s now carr%s a runner-written clause and %s not pinned. Add to PINNED in this"
          " arm so it can never be lost silently." % (", ".join(sorted(gained)),
                                                      "ies" if len(gained) == 1 else "y",
                                                      "is" if len(gained) == 1 else "are"))
if bad:
    print("    CURE: re-run that package's own suite runner, which rewrites the cell in place. NEVER type the")
    print("    clause back by hand -- a transcribed restatement of a measured number is this row's own defect.")
sys.exit(1 if bad else 0)
ARM19
_a19=$?
if [ "$_a19" -eq 2 ]; then
    echo "GATE REFUSES(2): ARM 19 could not measure the live board"; exit 2
elif [ "$_a19" -ne 0 ]; then
    violations=$((violations+1))
fi

# ⛔⭐⭐ ARM 20 — THE LIVE SIDECARS, AND THE ARMS ABOVE ALL GRADE FIXTURES (hq_T 2026-09-10, row package-
# shipped-per-lane-printed-by-the-runner-not-transcribed). ARMS 1-16 exercise every refusal in
# lib_inventory.sh against mktemp fixtures, exhaustively and correctly; ARM 11 counts which runners reach
# the body; ARM 17/18 grade carriage and reader; ARM 19 grades the board. NOT ONE of them ever points the
# body at the ELEVEN REAL SIDECAR PAIRS the runners actually read. So the body was gated and its data was
# not, and the gap is not theoretical: it swallowed a live defect for four hours on origin this very day.
# ⛔ THE MEASURED WITNESS. Two seats filed the same ceo ruling (CEO-527, cfuncs/extlvals) into
# arizona_tests/UNGRADABLE.tsv four hours apart, so the file held 38 rows for 36 distinct programs. The
# honesty arm fired first -- not on the duplicate but on the older copy's `SCRIP: 'cannot find ...'`
# evidence clause -- and `inventory_line` for arizona returned rc=2 AT ANY GRADED COUNT.
# ⭐ AND THE CONSEQUENCE IS SILENT BY CONSTRUCTION, which is the half worth understanding rather than
# fixing: every runner does `INV_LINE="$(inventory_line ...)"` and warns to stderr, because a bookkeeping
# failure must never red a board (gate_score_row's own doctrine, and it is right). An empty INV_LINE
# contributes nothing to the `--text` splice, so the cell reverts from a runner-written PACKAGE_INVENTORY
# clause to transcribed prose, and the runner's exit status never moves. ⛔ A DATA-FILE WORDING CHANGE
# THEREFORE STRIPS A LEADERBOARD CELL'S PROVENANCE WITH EVERY GATE GREEN. ARM 19 does catch it -- it is how
# arizona and ipl were found -- but only one board pass later, from another seat's tree, naming a symptom
# ("its shipped population is transcribed again") a lane away from the .tsv line that caused it.
# ⭐ THE GENERAL FORM, and it is ARM 19's own lesson one level down: ARM 19 says a cure landing in a CELL is
# protected by nothing unless something re-reads the cell. The sibling is that A REFUSAL DELIBERATELY MADE
# NON-FATAL IS PROTECTED BY NOTHING UNLESS SOMETHING CALLS IT ON PURPOSE. Non-fatal is the correct design
# and it converts a loud instrument into a quiet one at exactly the moment it fires; the cure is not to make
# it fatal in the runner, it is to call the same body somewhere a red is free -- here, hermetically, in <1s.
# ⛔ THIS ARM DELIBERATELY DOES NOT GRADE THE ARITHMETIC, and says so rather than letting a reader assume
# it: the bucket-sum identity needs a GRADED count, which only a real suite pass produces, and under ONE
# RUNNER ONE BOARD (CEO-523) this gate may not run one. So it feeds each package the graded count that makes
# its own sum hold, which lets every OTHER arm of the body speak -- honesty, internal duplicates, both-files,
# missing reason, closed vocabulary, stale name, moved package. The arithmetic stays the runner's to fail.
# ⭐ EXTENSION COMES FROM THE DATA, NEVER FROM A LANG->EXT MAP: each sidecar's own name column carries it
# (`general/cfuncs.icn`), all eleven self-describe exactly one, and each agrees with its runner's INV_EXT.
# A map in this script would be one more number typed into a gate, which is this row's whole subject; a
# package whose rows disagree about their extension REFUSES rc=2 rather than picking one.
# ⛔ RATCHETED BY NAME, for ARM 19's reasons verbatim. The backlog was MEASURED BEFORE WIRING (ARM 7 of
# test_gate_gate_wiring_ratchet.sh, ceo CEO-520: a live-tree arm is legitimate exactly when its red
# population is small enough that every red has a named author still in the room) and it is 1 of 11:
# icon/ipl, whose gincl/maccolor.icn row states the oracle's refusal AND upstream's control AND our
# agreement with both. That row is hq_R's lane and its mention of us is an AGREEMENT CONTROL, not a
# failure-as-reason -- an instrument limitation, not a lie -- so it is printed as the work list and never
# counted. Ten pinned; a pinned package that starts refusing is a FAIL naming the file and the arm.
examined=$((examined+1))
PKGINV_CORPUS="${PKGINV_CORPUS:-$ROOT/../corpus}"
if [ ! -d "$PKGINV_CORPUS/packages" ]; then
    echo "GATE REFUSES(2): ARM 20 found no package corpus at $PKGINV_CORPUS/packages -- cannot measure the live sidecars"
    exit 2
fi
# THE RATCHET, measured off the live sidecars 2026-09-10 by hq_T and raised only by measurement.
# ⭐ RAISED 2026-09-10 (hq_T, ceo CEO-541): icon/ipl joins the pinned set the moment its two agreement-control
# rows carry the marker. It was the ONE unpinned refusal this arm printed as its work list, and the reason it
# refused was the honesty arm reading `SCRIP refuses at the SAME line` as a failure-as-reason -- which it was
# not. ⛔ PINNING IS THE POINT OF CURING IT: the cure lives in a .tsv WORDING, and ARM 20 exists because a
# wording change reverts a board cell to prose with every gate green. Unpinned, this row could be un-cured by
# one careless edit and nothing would say so.
# ⭐ RE-PINNED 2026-09-27 (coo, ceo CEO-1306, the five-gates row): icon/jcon_tests LEAVES the set -- its UNGRADABLE.tsv and UNGRADED.tsv
# declare zero rows because every Jcon program is graded (SUITES.tsv jcon 86/86, PACKAGE_INVENTORY ungraded=0 ungradable=0), so the data
# the pin was taken over was emptied by the work the pin exists to protect, not by a wording edit; it re-enters with its next declared
# row. prolog/logtalk_iso (6 rows) and prolog/swi_tests (70 rows) JOIN it: this arm read both validating clean and unpinned.
# ⭐ RE-PINNED 2026-09-27 17:3x (coo COO-212/213, the same reading as icon/jcon_tests above): snobol4/spitbol_testpgms LEAVES the set -- its
# UNGRADABLE.tsv and UNGRADED.tsv declare zero rows since corpus cb91a43f2 (hq_snobol4, ceo CEO-1323) graded all eight programs (SUITES.tsv
# testpgms 8/8 on 162bb56ea); the data the pin was taken over was emptied by the grading work, not by a wording edit. It re-enters with
# its next declared row. Eleven pinned.
# ⭐ RE-PINNED 2026-09-28 (hq_snobol4, the same reading again): snobol4/aisnobol LEAVES the set -- its UNGRADABLE.tsv and UNGRADED.tsv declare
# zero rows since corpus 51d7c84ec (hq_snobol4, 09-27 17:10) graded BUILDLIB.sno, the eighth program, on its out_files answer (SUITES.tsv AIS
# 8/8 on 321a8ec4f); the data the pin was taken over was emptied by the grading work, not by a wording edit, and this arm read red on origin
# from that landing until this one (coo loop pass on 547e46e90). It re-enters with its next declared row. Ten pinned.
# ⭐ RE-PINNED 2026-10-01 (hq_icon, the same reading again): icon/arizona_tests LEAVES the set -- its UNGRADABLE.tsv and UNGRADED.tsv declare
# zero rows because special/keyboard (NEEDS_RUNNER_WIRING, the last row) is now graded: icn_keyboard_pty_drive.py wires a pty-timed 3-phase
# keystroke driver into test_icon_arizona_suite.sh's special-case (a redirected stdin cannot supply getch()/kbhit() a terminal, and
# script(1) cannot pace the Quit key to land inside test 3's poll -- CEO-1354, the coo's ask), special/keyboard.ref cut from the oracle
# (icont -s ... -x), special/keyboard.mask covers the two Quit-timing traceback lines (L28/L32, OS-scheduling-dependent, proven stable over
# 16 driver runs). The data the pin was taken over was emptied by the grading work, not by a wording edit. It re-enters with its next
# declared row. Nine pinned.
# ⭐ RE-PINNED 2026-10-02 (the coo, the same reading again): snobol4/gimpel LEAVES the set -- its UNGRADABLE.tsv and UNGRADED.tsv declare
# zero rows since corpus f2ae706da (the ceo, CEO-1412: sbl -bf answers all 145 drivers, balx and floorcei given drivers, refs cut for the 29
# drivers that had none; the Gimpel board reads scored=145 unscr=0 OUTSIDE 0). The data the pin was taken over was emptied by the grading work,
# not by a wording edit; this arm read red in the coo's blocking set at 7ff503611 from that landing until this one. It re-enters with its next
# declared row. Eight pinned.
PKGINV_PINNED="icon/ipl pascal/pat prolog/gnu_prolog prolog/logtalk_iso prolog/swi_tests snobol4/csnobol4_suite snobol4/dotnet snobol4/snoflake_suite"
_a20_bad=""; _a20_work=""; _a20_gain=""; _a20_n=0; _a20_empty=""; _a20_graded=0
for _sd in $(find "$PKGINV_CORPUS/packages" -maxdepth 3 \( -name UNGRADABLE.tsv -o -name UNGRADED.tsv \) 2>/dev/null \
             | while IFS= read -r _f; do dirname "$_f"; done | sort -u); do
    _a20_n=$((_a20_n+1))
    _rel="$(basename "$(dirname "$_sd")")/$(basename "$_sd")"
    # ⛔⭐⭐ AN EMPTY SIDECAR IS 'NOTHING DECLARED YET', NOT A REFUSAL (ceo CEO-604, on hq_R's find while building
    # the x64tests runner: snobol4/spitbol_x64_tests ships a header and no data row, and THE WHOLE GATE REFUSED
    # rc=2 for all thirteen seats on it -- every new package was RED AT BIRTH, and the one thing a package cannot
    # have on the day it is created is a declaration). ⭐ THE DEFECT IS NOT THE REFUSAL, IT IS WHAT THE ARM KEYED
    # ON: it derived the extensions and read `0 extensions` as ambiguity, when zero means TWO OPPOSITE THINGS --
    # no rows at all (nothing to be ambiguous about) and rows whose name column carries no extension (genuinely
    # malformed). So the row count is the fact that separates them and the extension count never could. That is
    # the same collapse as ARM 2 of outside_baseline_rows reading rc=0-with-no-diagnostic and rc=124-with-no-
    # diagnostic into one sentence, and hq_U's ladder ask one level up: WHENEVER AN INSTRUMENT'S OUTPUT SPACE IS
    # SMALLER THAN THE SPACE OF THINGS THAT CAN GO WRONG, the collapse is invisible AND it points the reader
    # somewhere specific and wrong -- here at an extension the package never claimed.
    _rows="$(cat "$_sd/UNGRADABLE.tsv" "$_sd/UNGRADED.tsv" 2>/dev/null | grep -v '^#' | grep -cv '^[[:space:]]*$')"
    if [ "$_rows" -eq 0 ]; then
        # ⛔ PINNED IS THE ONE PLACE THIS IS STILL A FAIL, and it is the arm's own pinning doctrine rather than a
        # new policy: a package is pinned BECAUSE the shared body accepted its own data, so emptying that data is
        # exactly the silent un-validation the pin exists to catch. A package that was never pinned cannot be
        # regressing -- it is being born.
        case " $PKGINV_PINNED " in
          *" $_rel "*)
            _a20_bad="$_a20_bad $_rel"
            echo "    ARM 20 FAIL: $_rel is PINNED and its sidecars now declare ZERO rows -- the data the pin was taken over is gone,"
            echo "      so its runner's inventory clause has nothing to report and its board cell reverts to prose" ;;
          *)
            _a20_empty="$_a20_empty $_rel" ;;
        esac
        continue
    fi
    # the extension the lane itself declared, from the name column of its own rows
    _ext="$(cat "$_sd/UNGRADABLE.tsv" "$_sd/UNGRADED.tsv" 2>/dev/null | grep -v '^#' | grep -v '^[[:space:]]*$' \
            | cut -f1 | sed -n 's/.*\(\.[A-Za-z0-9]*\)$/\1/p' | sort -u)"
    _nx="$(printf '%s\n' "$_ext" | grep -c .)"
    # ONE DIALECT, ITS SPELLINGS (Lon 2026-09-14, "Change the *.sno to *.inc", CEO-1274/1315; Lon 2026-09-27, Catspaw's SPITBOL form under
    # lower-case names, CEO-1319; coo COO-203/204): a SNOBOL4 package ships its include libraries as name.inc (NAME.INC the day before)
    # beside its programs, name.spt in the SPITBOL form and NAME.sno before it, so gimpel's rows name several. They are one extension
    # family, handed to the body together exactly as test_snobol4_gimpel_suite.sh hands them; any other mix still refuses below.
    if [ "$_nx" -gt 1 ] && [ -z "$(printf '%s\n' "$_ext" | grep -v -x -E '\.(sno|spt|INC|inc)')" ]; then _ext="$(printf '%s' "$_ext" | tr '\n' ' ')"; _nx=1; fi
    if [ "$_nx" -eq 0 ]; then
        echo "    ARM 20 REFUSES(2): $_rel declares $_rows row(s) and NOT ONE carries an extension in its name column -- this is a malformed name column, not an empty package, and the arm will not pick an extension the data never claimed"
        echo "GATE REFUSES(2): ARM 20 could not derive $_rel's extension from its $_rows declared row(s)"; exit 2
    fi
    if [ "$_nx" -ne 1 ]; then
        echo "    ARM 20 REFUSES(2): $_rel declares $_nx extensions in its own name column ($(printf '%s' "$_ext" | tr '\n' ' ')) over $_rows row(s) -- one package, one shipped extension, and this arm will not pick for it"
        echo "GATE REFUSES(2): ARM 20 could not derive $_rel's extension from its own rows"; exit 2
    fi
    # ⛔ ONE CALL PER PACKAGE, AND THE ARITHMETIC REFUSAL COUNTS AS CLEAN HERE -- deliberately, because this
    # arm does not grade the sum (it cannot: the graded count comes from a suite pass this gate may not run).
    # ⭐ THE FIRST VERSION PASSED graded=0 TO LEARN shipped, THEN CALLED AGAIN WITH A COUNT THAT MADE THE SUM
    # HOLD, so the arithmetic would stay quiet and the other arms would speak. It worked and it cost DOUBLE:
    # the shared body spends three subprocesses per row (`printf | cut` x3) and icon/ipl alone declares 851
    # rows, so the gate went from 0.41s to 25.8s against a Makefile comment promising ~1s. Reading the sum
    # refusal instead of engineering around it is both half the cost and the more honest shape -- an arm that
    # declares the arithmetic out of scope must not care that the arithmetic failed.
    _a20_graded=$((_a20_graded+1))
    _out="$(INV_PACKAGE="$(basename "$_sd")" INV_DIR="$_sd" INV_EXT="$_ext" inventory_line 0 0 2>&1)"; _rc=$?
    case "$_out" in *"buckets do not sum"*) _rc=0 ;; esac
    case " $PKGINV_PINNED " in
      *" $_rel "*)
        if [ "$_rc" -ne 0 ]; then
            _a20_bad="$_a20_bad $_rel"
            echo "    ARM 20 FAIL: $_rel is PINNED and its own sidecars now make the shared body REFUSE(rc=$_rc) --"
            echo "      its runner will emit no PACKAGE_INVENTORY clause and its board cell will silently revert to prose:"
            printf '%s\n' "$_out" | grep -v '^$' | head -3 | cut -c1-220 | sed 's/^/        /'
        fi ;;
      *)
        if [ "$_rc" -ne 0 ]; then _a20_work="$_a20_work $_rel"
        else _a20_gain="$_a20_gain $_rel"; fi ;;
    esac
done
[ "$_a20_n" -gt 0 ] || { echo "GATE REFUSES(2): ARM 20 found zero sidecar pairs under $PKGINV_CORPUS/packages -- an empty population is not a census"; exit 2; }
echo "    ARM 20 live sidecar pairs=$_a20_n  graded=$_a20_graded  declaring nothing yet=$(printf '%s' "$_a20_empty" | wc -w)  pinned packages whose own data the shared body accepts=$(( $(printf '%s' "$PKGINV_PINNED" | wc -w) - $(printf '%s' "$_a20_bad" | wc -w) ))/$(printf '%s' "$PKGINV_PINNED" | wc -w)"
[ -n "$_a20_empty" ] && echo "    DECLARING NOTHING YET, named and never a refusal:$_a20_empty -- a package with no rows has no extension to derive and no inventory to validate; it enters this arm's graded set with its first declared row"
[ -n "$_a20_work" ] && echo "    THE BODY STILL REFUSES THESE, UNPINNED (the work list, not a verdict):$_a20_work -- each one's runner emits no inventory clause today"
[ -n "$_a20_gain" ] && echo "    ⭐ RAISE THE RATCHET:$_a20_gain now validate(s) clean and are not pinned. Add to PKGINV_PINNED in this arm so a wording change can never quietly un-validate them."
if [ -n "$_a20_bad" ]; then
    echo "    CURE: read the refusal above and fix the .tsv ROW it names -- the arm is quoting lib_inventory.sh, which is"
    echo "    the same body the runner calls. ⛔ Do NOT silence it by rewording around the check: the honesty arm exists"
    echo "    to stop the lockdown being satisfiable by failing, and a synonym that dodges its regex is the defect it hunts."
    violations=$((violations+1))
fi

# ⛔⭐⭐ ARM 21 — THE CAUSE READER (hq_T 2026-09-11, same row). ARM 20 proves the shared body ACCEPTS each
# package's live data. It does not answer the question a reader actually arrives with when a board cell has
# no runner-written clause: WHY NOT. That question was answered by an ENUMERATION inside util_score_row.py
# -- a list of causes, maintained by hand -- and the list has now been wrong twice, in the same direction,
# each time after being cured: it named ONE cause on 2026-09-10 and was wrong for both packages it reported
# (arizona and ipl were wired; their bodies had REFUSED), was cured to TWO, and on 2026-09-11 both named
# causes were wrong for FOUR of the seven it reports -- snobol4's gimpel/aisnobol/dotnet/testpgms are wired
# AND validate, and are prose only because no suite pass has rewritten them since the carriage landed.
# ⭐⭐ THE GENERAL FORM: A DIAGNOSTIC THAT CAN ONLY OBSERVE AN ABSENCE MUST ENUMERATE EVERY CAUSE OF THE
# ABSENCE, AND ENUMERATING FROM MEMORY IS HOW YOU GET TWO OF FOUR. Every list was written by someone who had
# just measured the cause in front of them and generalised; each read as more rigorous than the last and
# stayed wrong. ⛔ A wrong cause is a WORK LIST, not a wording: this row's own baton sent its next reader to
# retrofit four runners whose carriage had been correct and pushed for days.
# ⭐ SO THE CURE WAS TO STOP ENUMERATING AND MEASURE -- util_package_inventory_cause.sh -- and THIS arm is
# what keeps that instrument honest. It is HERMETIC BY CONSTRUCTION and grades the reader's DISCRIMINATION,
# not the live tree: ARM 20 already grades the live sidecars, and the live causes are printed by
# util_package_shipped_is_runner_written.sh, which is this row's DONE-WHEN and where a red is already free.
# ⛔ DELIBERATELY NOT A LIVE SWEEP, and the number is why: calling the cause reader for all 15 declared
# packages costs 7.1s on this box at load ~4 (24.4s before its per-runner grep loop was collapsed to one
# pass), against a gate that already costs 7.7s. An arm that doubles a blocking gate to re-derive what two
# other instruments already print is not diligence.
examined=$((examined+1))
_cause="$HERE/util_package_inventory_cause.sh"
if [ ! -x "$_cause" ] && [ ! -f "$_cause" ]; then
    echo "GATE REFUSES(2): ARM 21 found no util_package_inventory_cause.sh beside it -- the cause reader it grades is gone, and this arm must not pass by its absence"; exit 2
fi
_a21_bad=""
_a21() {  # _a21 <want-cause> <want-rc> <lang> <label> <regex> <what-it-proves>
    local _w="$1" _wrc="$2" _o _r
    _o="$(PKGINV_CORPUS="$TD/cz" bash "$_cause" "$3" "$4" "$5" 2>&1)"; _r=$?
    case "$_o" in
      *"CAUSE=$_w"*) [ "$_r" -eq "$_wrc" ] || { echo "    ARM 21 FAIL: $6 -- cause $_w was named but rc=$_r, wanted rc=$_wrc"; _a21_bad="x$_a21_bad"; } ;;
      *) echo "    ARM 21 FAIL: $6 -- wanted CAUSE=$_w, got: $(printf '%s' "$_o" | tr '\n' ' ' | cut -c1-170)"; _a21_bad="x$_a21_bad" ;;
    esac
}
# A scratch corpus, never the real one: an in-place edit under corpus/ would rewrite the tree being graded.
rm -rf "$TD/cz"; mkdir -p "$TD/cz/packages/zlang/zwired" "$TD/cz/packages/zlang/zunwired"
echo 'procedure main(); end' > "$TD/cz/packages/zlang/zunwired/a.icn"
printf 'a.icn\tORACLE_REFUSES\tthe oracle refuses this program: unsupported extension\n' > "$TD/cz/packages/zlang/zwired/UNGRADABLE.tsv"
# A — the table declares a package this tree does not ship at all (raku/roast's live shape).
_a21 A 0 zlang nothing 'nothing' "a declared package with no vendored corpus must read A, not 'not retrofitted'"
# B — it ships, and no runner assigns INV_PACKAGE to a token its regex matches. THE ONLY CARRIAGE CAUSE.
_a21 B 0 zlang zunwired 'zunwired' "a shipped package no runner declares must read B (the one cause that IS carriage work)"
# ⛔ THE NEGATIVE CONTROL THE WHOLE ARM TURNS ON: a package that IS wired must NEVER read B. Without this,
# an instrument that answered B unconditionally would pass every arm above and reproduce the exact defect
# this row cured -- a work list telling its reader to retrofit runners that are already correct.
_o21="$(PKGINV_CORPUS="$TD/cz" bash "$_cause" snobol4 aisnobol 'aisnobol' 2>&1)"
case "$_o21" in
  *"CAUSE=B"*) echo "    ARM 21 FAIL: a WIRED package read CAUSE=B -- the cause reader is not discriminating, it is guessing"; _a21_bad="x$_a21_bad" ;;
esac
# C vs D on the SAME package, one row apart: the split between 'the data blocks the clause' and 'the
# carriage is correct and the cell merely awaits a pass'. Mutation-proven in both directions by construction.
mkdir -p "$TD/cz/packages/snobol4/aisnobol"
printf 'x.sno\tORACLE_REFUSES\tthe oracle refuses this program: unsupported extension\n' > "$TD/cz/packages/snobol4/aisnobol/UNGRADABLE.tsv"
echo 'x' > "$TD/cz/packages/snobol4/aisnobol/x.sno"; echo 'y' > "$TD/cz/packages/snobol4/aisnobol/y.sno"
_a21 D 0 snobol4 aisnobol 'aisnobol' "a wired package whose data validates must read D (awaits a runner pass, NOT carriage work)"
# ⛔⭐ AND THE `D` PREDICTION IS GRADED, NOT JUST ITS LETTER. The first version of this arm matched the
# string CAUSE=D and passed -- which is how the reader shipped telling the coo that one pass would fix
# gimpel's cell when no pass ever can: gimpel declares ungradable=174 against shipped=292, so its buckets
# sum only at a graded count of 118, and the pass graded 132 (coo, 2026-09-11: "I RAN THE PASS YOU SAID WAS
# OWED AND IT REFUSES"). ⭐ AN ARM THAT GRADES THE LETTER OF A VERDICT AND NOT ITS CONTENT PASSES EVERY TIME
# THE CONTENT IS WRONG. This fixture ships 2 programs and excludes 1, so the one honest answer is "exactly 1".
case "$(PKGINV_CORPUS="$TD/cz" bash "$_cause" snobol4 aisnobol 'aisnobol' 2>&1)" in
  *"GRADES EXACTLY 1 PROGRAM"*) : ;;
  *) echo "    ARM 21 FAIL: the D answer names no required graded count, or the wrong one -- a fixture shipping 2 and excluding 1 sums only at a graded count of 1. A D that does not state the count it depends on is a promise the next pass cannot keep"; _a21_bad="x$_a21_bad" ;;
esac
# ⛔⭐ NOT ARMED: the reader also reports an IMPOSSIBILITY (a required graded count <= 0, where declared
# exclusions already account for everything shipped) as C rather than as a forecast. MEASURED 2026-09-11 --
# that branch is UNREACHABLE from well-formed data, because over-declaring means naming a file the package
# does not ship and lib_inventory.sh's "declared but not shipped" arm refuses first. It stays in the reader
# as a guard and gets NO arm here, on this lane's own CEO-541 ruling: an arm that asserts WHICH check caught
# something fails exactly when a stronger check gets there first. The guard is cheap; an arm on it would be
# a test of the body's check order wearing the costume of a test of the reader.
printf 'y.sno\tSCRIP_REFUSES\tSCRIP cannot compile this program\n' >> "$TD/cz/packages/snobol4/aisnobol/UNGRADABLE.tsv"
_a21 C 0 snobol4 aisnobol 'aisnobol' "a wired package whose own row names our compiler as the reason must read C (the data, not the runner)"
# ⛔ AND AN AMBIGUOUS JOIN REFUSES rather than picking: two shipped directories match, both carrying the
# sidecars the body reads, so there is no fact that chooses between them. rc=2 is a THIRD answer, never a cause.
cp -r "$TD/cz/packages/snobol4/aisnobol" "$TD/cz/packages/snobol4/aisnobol_twin"
_a21 '?' 2 snobol4 aisnobol 'aisnobol' "two matching package directories must REFUSE rc=2, never pick one"
if [ -n "$_a21_bad" ]; then
    echo "    CURE: util_package_inventory_cause.sh must MEASURE the cause (a directory, a grep over the runners, one"
    echo "    call to the shared body) and REFUSE when it cannot. ⛔ Do not repair it by making a cause the default:"
    echo "    a reader that guesses is the defect this arm exists for, and it guesses most convincingly when it is right."
    violations=$((violations+${#_a21_bad}))
fi
echo "    ARM 21 cause reader: 6 discriminations graded hermetically (A/B/C/D, a wired-is-never-B control, an ambiguous join refusing rc=2)"

GATE_EXAMINED="$examined arms"
gate_verdict "$violations" "package-inventory violations"
