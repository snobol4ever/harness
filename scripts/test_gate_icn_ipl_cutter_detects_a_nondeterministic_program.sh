#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: the ipl ref cutter invoked as an instrument fixture over a SCRATCH package, not a board (CEO-523)"
export S4E_MINT_NO_CRITERION="gate fixture: the row under test exercises the bus, not work (CEO-1386)"
# test_gate_icn_ipl_cutter_detects_a_nondeterministic_program.sh -- proves util_cut_icon_ipl_refs.sh's flake
# detector ACTUALLY DETECTS. Instrument side of row icon-ipl-qei-nested-icont-nondeterminism-neither-cutter-
# detects (ceo mint CEO-516 -> hq_R): "the cutter's flake detector (an N-rep arm) fails once against a planted
# nondeterministic program."
#
# ⛔⭐ WHY THIS GATE EXISTS AT ALL. The cutter already HAD a determinism arm -- four sub-second runs plus a
# minute-crossing second pass -- and nothing anywhere proved it could fail. An undetected-flake mints a .ref
# from one arbitrary run, and a ref pinned off a flaky run is the worst artifact this project produces: a
# plausible-looking pin that grades every future run against a lie, indistinguishable downstream from a good
# one. That is the same class the sibling gate test_gate_ref_cutters_refuse_a_dead_oracle.sh was built for,
# and this file deliberately follows its shape. ⭐ The cutter's own header already records the reject-
# everything trap in its own words: "its validation against four known-bad programs PASSED, because a
# reject-everything bug rejects the known-bad too." ARM 3 below is the control that makes ARMS 1 and 2 mean
# something -- agreement counts only when the arms CAN disagree (RULES.md THE INSTRUMENT LAWS).
#
# ⛔⛔ THE DETECTOR IS TWO MECHANISMS, NOT ONE, AND A GATE THAT EXERCISED ONLY ONE WOULD READ GREEN WITH THE
# OTHER DELETED. They are independent and are planted against separately:
#   (a) the RUN arm    -- four sub-second runs must agree, then a minute-crossing re-run must agree again.
#                         Planted by flaky_run.icn, which reads 8 bytes from /dev/urandom. ⛔ It must NOT
#                         read the clock, or mechanism (b) would classify it before (a) ever ran and the arm
#                         would pass while proving nothing about the thing it names.
#   (b) the SOURCE arm -- greps the source for &dateline/&date/&clock/&now/&time and refuses WITHOUT running,
#                         because a date-valued output is byte-stable across every window anyone watches and
#                         goes red at midnight (the cutter's own gftrace.ref witness). Planted by
#                         flaky_date.icn, which is otherwise perfectly well-behaved.
# ⛔⭐ THE SOURCE-ARM WITNESS MUST USE &date, NOT &clock, AND THE FIRST DRAFT OF THIS GATE USED &clock AND
# PASSED FOR THE WRONG REASON. &clock has SECOND granularity, so whether the cutter's four sub-second runs
# straddle a second boundary is luck: the draft's witness was caught by the RUN arm ("disagreed on
# confirmation run 1/3"), mechanism (b) was never reached, and ARM 2 would have reported the source arm
# working on a tree where it was deleted -- while ALSO being intermittent, since on a different second it
# would have fallen through. &date has DAY granularity, so it is byte-stable across four sub-second runs AND
# across a minute boundary, and ONLY the source arm can refuse it. ⭐ The general form is the one this
# package keeps re-learning: an arm that can be satisfied by a mechanism other than the one it names is not
# a test of that mechanism. ARM 2 therefore asserts the REASON, not just the verdict.
#
# ⛔⭐ EVERY ARM HERE ASSERTS THE REASON, NOT ONLY THE VERDICT, AND BOTH OF THE FIRST TWO DRAFTS NEEDED IT.
# The detector is REDUNDANT for a per-run flake -- the four-run arm and the minute-crossing second pass both
# catch it -- which is good news about the cutter and fatal to a naive arm. MEASURED, by re-running this gate
# against a copy of the cutter with the four-run comparison replaced by `if false`: the gate still read 6/6,
# because flaky_run fell through to the minute pass and was refused there. So ARM 1 now requires the reason to
# name a "confirmation run" and ARM 2 requires it to name the clock marker; each arm can now only be satisfied
# by the mechanism it is planted against. ⭐ Two arms, two drafts, one lesson, and it is the lesson this whole
# gate exists to enforce one level down: AN INSTRUMENT THAT CANNOT FAIL FOR THE REASON IT NAMES IS NOT MEASURING
# THAT REASON. Re-prove falsifiability the same way before trusting any edit to this file -- neuter one
# mechanism in a COPY of the cutter and confirm the matching arm, and only that arm, goes red.
#
# ISOLATION: the cutter derives its package from S4E_HOME, so this gate points S4E_HOME at a scratch tree and
# the REAL corpus is never read, walked, or written. Nothing here can mint into the tracked package.
# FALSIFIABILITY, MEASURED not asserted (2026-09-10, hq_R), each against a COPY of the cutter with ONE
# mechanism removed: four-run comparison -> `if false` reds ARM 1 ALONE, 5/6, and its message names the
# minute-crossing backstop that caught the flake instead; the clock grep -> a never-matching pattern reds
# ARM 2 **and** ARM 4, 4/6, because flaky_date is then LIVE and MINTED -- a date-valued ref pinned as ground
# truth, which is the gftrace.ref incident reproduced on demand. The real cutter reads 6/6.
# ARMS: 1 the run-arm flake is classified NONDETERMINISTIC · 2 the source-arm flake is classified
# NONDETERMINISTIC and names its marker · 3 CONTROL: the well-behaved program is still classified LIVE and
# minted (so the arms can disagree) · 4 neither flake left a .ref behind under --apply · 5 the control's
# minted .ref holds the program's exact bytes · 6 the printed denominator covers the whole planted population.
# EXIT: 0 all arms · 1 an arm failed · 2 REFUSED (could not measure: no oracle, cutter missing, mktemp failed).
# RUNTIME ~70s, dominated by the cutter's own minute-crossing sleep -- one sleep for the whole population, so
# all three witnesses go through a SINGLE cutter invocation rather than one run each.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CUTTER="$HERE/util_cut_icon_ipl_refs.sh"
[ -f "$CUTTER" ] || { echo "⛔ REFUSED-TO-GRADE rc=2: cutter under test missing: $CUTTER"; exit 2; }
# shellcheck source=/dev/null
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE rc=2: lib_oracle_flags.sh not sourceable"; exit 2; }
ICONT="$(icont_bin)" || { echo "⛔ REFUSED-TO-GRADE rc=2: no icont oracle -- this gate grades a cutter that cannot run without one"; exit 2; }
[ -x "$ICONT" ] || { echo "⛔ REFUSED-TO-GRADE rc=2: icont at $ICONT is not executable"; exit 2; }
[ -r /dev/urandom ] || { echo "⛔ REFUSED-TO-GRADE rc=2: /dev/urandom unreadable -- the run-arm witness cannot be made nondeterministic"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_iplflake.XXXXXX")" || { echo "⛔ REFUSED-TO-GRADE rc=2: mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
fails=0; checks=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
PKG="$W/home/corpus/packages/icon/ipl"
for sub in progs gprogs procs gprocs incl gincl; do mkdir -p "$PKG/$sub"; done
# ── the three planted witnesses. Quoted heredoc delimiters throughout: an UNQUOTED one hands the shell every
# backtick and $ in the body (this lane has filed that three times in one sitting).
cat > "$PKG/progs/flaky_run.icn" <<'EOF'
procedure main()
   local f, s, c;
   f := open("/dev/urandom","r") | stop("no urandom");
   s := reads(f, 8) | stop("no bytes");
   every c := !s do writes(ord(c), " ");
   write();
   close(f);
end
EOF
cat > "$PKG/progs/flaky_date.icn" <<'EOF'
procedure main()
   write("built on ", &date);
end
EOF
cat > "$PKG/progs/steady.icn" <<'EOF'
procedure main()
   write("steady one");
   write("steady two");
end
EOF
printf 'steady one\nsteady two\n' > "$W/steady.expected"
echo "── planted population: $(cd "$PKG/progs" && ls -1 *.icn | tr '\n' ' ')"
echo "── running the cutter ONCE with --apply over all three (its minute-crossing pass sleeps up to 62s) ──"
LOG="$W/cut.log"
S4E_HOME="$W/home" timeout -k 5 400 bash "$CUTTER" --apply --only flaky_run --only flaky_date --only steady > "$LOG" 2>"$W/cut.err"
crc=$?
if [ "$crc" -eq 2 ]; then
    echo "⛔ REFUSED-TO-GRADE rc=2: the cutter itself refused (rc=2) -- this gate cannot measure a detector that did not run:"
    sed -n '1,6p' "$W/cut.err"; exit 2
fi
if [ "$crc" -eq 124 ]; then echo "⛔ REFUSED-TO-GRADE rc=2: the cutter timed out at 400s; a duration-based verdict needs its own measurement"; exit 2; fi
grep -vE '^[[:space:]]*$' "$LOG" | sed 's/^/    /'
cls() { awk -F'\t' -v w="$1.icn" '$2==w{print $1; found=1} END{if(!found) print "NO-ROW"}' "$LOG" | tail -1; }
c_run="$(cls flaky_run)"; c_clk="$(cls flaky_date)"; c_std="$(cls steady)"
r_run="$(awk -F'\t' '$2=="flaky_run.icn"{print $5}' "$LOG" | tail -1)"
r_clk="$(awk -F'\t' '$2=="flaky_date.icn"{print $5}' "$LOG" | tail -1)"
echo "── arms ──"
if [ "$c_run" != NONDETERMINISTIC ]; then
    ck FAIL "ARM 1 run-arm flake classified '$c_run', expected NONDETERMINISTIC -- the detector did not detect a program whose output provably changes every run"
elif printf '%s' "$r_run" | grep -aq 'confirmation run'; then
    ck ok "ARM 1 run-arm flake refused BY THE FOUR-RUN ARM, naming the run it broke on: ${r_run#*-- }"
else
    ck FAIL "ARM 1 run-arm flake was classified NONDETERMINISTIC but NOT by the four-run arm (reason: ${r_run:-none}) -- the minute-crossing backstop caught it, and this arm would read green with the four-run comparison deleted"
fi
if [ "$c_clk" != NONDETERMINISTIC ]; then
    ck FAIL "ARM 2 source-arm flake classified '$c_clk', expected NONDETERMINISTIC"
elif printf '%s' "$r_clk" | grep -aq 'source reads the clock'; then
    ck ok "ARM 2 source-arm flake refused BY THE SOURCE ARM, naming its marker: ${r_clk#*-- }"
else
    ck FAIL "ARM 2 source-arm flake was classified NONDETERMINISTIC but by the RUN arm, not the source arm it is planted against (reason: ${r_clk:-none}) -- the arm would read green with the source arm deleted"
fi
[ "$c_std" = LIVE ] && ck ok "ARM 3 CONTROL: the well-behaved program is still LIVE (the arms can disagree)" \
    || ck FAIL "ARM 3 CONTROL: the well-behaved program classified '$c_std', expected LIVE -- a cutter that refuses EVERYTHING passes arms 1 and 2 while detecting nothing"
nostd=1
for b in flaky_run flaky_date; do [ -f "$PKG/progs/$b.ref" ] && { nostd=0; ck FAIL "ARM 4 --apply MINTED $b.ref for a planted flake -- a ref pinned off a varying run, which is the gftrace.ref harm itself: either the classification never reached the mint path, or the flake was never classified at all (see ARM 1/2 for which)"; }; done
[ "$nostd" -eq 1 ] && ck ok "ARM 4 neither flake left a .ref behind under --apply"
if [ -f "$PKG/progs/steady.ref" ]; then
    if cmp -s "$PKG/progs/steady.ref" "$W/steady.expected"; then ck ok "ARM 5 the control's minted .ref holds the program's exact bytes"
    else ck FAIL "ARM 5 steady.ref was minted but its bytes differ from the program's real output"; fi
else ck FAIL "ARM 5 the control was classified LIVE but --apply minted no steady.ref"; fi
tot="$(grep -c . <(cd "$PKG/progs" && ls -1 *.icn))"
seen="$(awk -F'\t' 'NF>1 && $2 ~ /\.icn$/{print $2}' "$LOG" | sort -u | grep -c .)"
[ "$seen" -eq "$tot" ] && ck ok "ARM 6 census covers the printed denominator: $seen of $tot planted entries named" \
    || ck FAIL "ARM 6 census named $seen of $tot planted entries -- a census predicate cannot report its own false negatives"
echo "────"
printf 'GATE %s [%s]: %d/%d checks, planted population=%d (run-arm + source-arm flakes, one control)\n' \
    "$([ "$fails" -eq 0 ] && echo PASS || echo FAIL)" "${0##*/}" "$((checks-fails))" "$checks" "$tot"
[ "$fails" -eq 0 ] || exit 1
