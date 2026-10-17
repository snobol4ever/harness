#!/usr/bin/env bash
# test_gate_icn_errorvalue_is_absent_when_the_error_carries_none.sh -- hq_C 2026-09-10,
# row icon-jcon-errors-red-both-modes-diagnosed-to-its-first-divergence-and-cured (errors.icn line 180, both copies).
#
# WHAT IT PINS. Icon has TWO independent facts after a converted error, and only one keyword is gated by each:
# "an error was recorded" gates &errornumber and &errortext, and "that error carried an OFFENDING VALUE" gates
# &errorvalue ALONE. An error raised without a value leaves &errorvalue FAILING -- not null, not the operand --
# and the fatal report for such an error prints no "offending value:" line. SCRIP already carries the mechanism:
# core_icn_error(code, FAILDESCR) means "no value", core_icn_report suppresses the line on DT_FAIL, and
# keywords.c returns the descriptor as-is so the read fails. Every always-value-less raise site in
# src/runtime/arithmetic.c already used it EXCEPT 206, which handed core_icn_error the left operand.
#
# ⭐ WHY ONE SITE OUT OF TWELVE IS THE WHOLE CLASS, and how the class was bounded without guessing. The
# authority is the oracle's OWN source, not a witness: `runerr(N)` with no second argument in
# /home/resources/icon-master/src/runtime/*.r is Arizona saying "this number carries no value". Twelve numbers
# are value-less at EVERY Arizona site (141 143 146 201 203 204 206 208 216 305 306 402) while 101/103/205
# appear both ways, so the property is per-SITE, not per-NUMBER, and a gate keyed on the number alone would be
# wrong for the very numbers it most wants to cover. Of our own sites for the always-value-less twelve, exactly
# two deviated: 206 (cured here) and 203 (NOT cured here -- it sits in the rt_big_* large-integer path, which is
# the cto's lane, and no witness for it exists on this tree; named, not taken).
#
# ⛔ THE OLD BEHAVIOUR IS INVISIBLE TO A DIFF THAT ONLY READS THE LAST RECORD. &errorvalue holds its previous
# value, so "the error carried no value" and "the error carried the value from an EARLIER error" render
# identically wherever a value-bearing error ran first. Arm STALE exists for exactly that: it raises 102 (which
# DOES carry "q"), then 206, and demands the read FAIL. Reading &errorvalue after the value-less error alone
# would have gone green on a build that simply never cleared it, if the program's first error happened to be
# value-less. Same family as the &errornumber trap in this row's baton.
#
# ⛔⭐ PROVENANCE, CORRECTED THE SAME SITTING AND LEFT HERE BECAUSE THE MISTAKE IS THE MORE USEFUL HALF.
# THE CURE IS THE cfo's `118fe2e4a`, NOT THIS GATE'S COMMIT. hq_C diagnosed 206 and cut the identical one-line
# change on a tree measured at `3e68226ea`; while that was being built and control-armed, the cfo landed
# `118fe2e4a` carrying the SAME line (plus the list()/reads() size gates), so `git pull --rebase` silently
# DROPPED hq_C's hunk as an already-applied patch and the commit that shipped this gate contains NO source
# change at all -- while its message still claimed the cure and a 57 -> 56 delta measured on the vanished tree.
# ⭐ THE REBASE-BASELINE COROLLARY IS USUALLY QUOTED FOR A/B NUMBERS; THIS IS ITS SHARPER FORM. A rebase that
# drops your patch is SILENT and looks exactly like a rebase that kept it: it is not a conflict, there is no
# warning, the build is green, the gate you wrote passes, and every arm you re-measure afterwards is TRUE --
# because someone else's identical cure is holding them up. The only instrument that separates "my change did
# this" from "my change is gone" is `git show <sha> --stat` on the pushed commit, read AFTER the push. Re-running
# the tests cannot do it, and re-running them is what diligence feels like.
# ⛔⛔ AND THE CORRECTION ABOVE ITSELF OVER-CORRECTED, WHICH IS THE THIRD LESSON AND THE ONE WORTH THE MOST.
# In retracting my numbers I also retracted a REAL defect: I had reported an m4-only crossing at errors.icn's
# last line, where the digits of `180` are split around `stop(&output,'testing stop')`'s output, and then wrote
# it off as an artifact of a mis-linked witness. It was NOT an artifact -- the run that first showed it was
# linked correctly with an absolute -L, the defect was genuinely on `3e68226ea`, and it was CURED by `e7e916e14`
# (stop() honours a leading file argument and flushes before exit) which arrived in the same rebase. A LATER,
# SEPARATE run of mine WAS mis-linked with a relative -L, and I let that one instrument fault explain away an
# observation it had nothing to do with. ⭐ ONCE YOU CATCH YOURSELF IN ONE INSTRUMENT ERROR, THE CHEAPEST STORY
# FOR EVERY OTHER SURPRISE IS THAT SAME ERROR -- and it is wrong exactly as often as it is right. A retraction
# needs its own evidence; "I was sloppy over there" is not evidence about over here. Attribute each observation
# to the run that produced it, and check what that particular run's command actually was.
# ⭐ WHAT IS ACTUALLY THIS SEAT'S IS WHAT YOU ARE READING: the class bounded from Arizona's own source rather
# than from the witness, the STALE arm below, and the fact that a cured behaviour with no gate is one refactor
# from being un-cured. `118fe2e4a` shipped the fix with no gate; this pins it in both modes against a freshly
# built oracle.
# ⛔ ARMS HASVALUE and NOVALUE_204 ARE CONTROLS THAT MUST NOT MOVE: a cure that made &errorvalue fail too eagerly
# would green the new arms and silently break every error that legitimately reports its operand -- which is most
# of them, and which is what errors.icn spends 500 lines checking.
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
R="$PWD"
[ -x "$R/scrip" ] || { echo "GATE UNPROVEN(2) [icn_errorvalue_absent_when_none]: scrip not built -- measured nothing."; exit 2; }
[ "$R/scrip" -nt "$R/src/runtime/arithmetic.c" ] || { echo "GATE UNPROVEN(2) [icn_errorvalue_absent_when_none]: ./scrip is older than src/runtime/arithmetic.c -- a stale binary measures the previous tree. Run make."; exit 2; }
ICONT=/home/resources/icon-master/bin/icont
ICONX=/home/resources/icon-master/bin/iconx
[ -x "$ICONT" ] && [ -x "$ICONX" ] || { echo "GATE UNPROVEN(2): no Arizona oracle at $ICONT / $ICONX -- measured nothing."; exit 2; }
T=$(mktemp -d) || exit 2
trap 'rm -rf "$T"' EXIT
cat > "$T/g.icn" <<'ICN'
procedure main();
   &error := -1;
   (1 + "q");
   write("HASVALUE n=", &errornumber, " t=", image(&errortext), " v=", image(&errorvalue)) |
      write("HASVALUE n=", &errornumber, " VALUE-FAILED");
   &error := -1;
   (-36. ^ -9.);
   write("NOVALUE_206 n=", &errornumber, " t=", image(&errortext), " v=", image(&errorvalue)) |
      write("NOVALUE_206 n=", &errornumber, " t=", image(&errortext), " VALUE-FAILED");
   &error := -1;
   (0 ^ -1);
   write("NOVALUE_204 n=", &errornumber, " t=", image(&errortext), " v=", image(&errorvalue)) |
      write("NOVALUE_204 n=", &errornumber, " t=", image(&errortext), " VALUE-FAILED");
   &error := -1;
   (1 + "q");
   &error := -1;
   (-36. ^ -9.);
   write("STALE n=", &errornumber, " v=", image(&errorvalue)) |
      write("STALE n=", &errornumber, " VALUE-FAILED");
   &error := -1;
   pull(&null);
   write("NULLVALUE n=", &errornumber, " v=", image(&errorvalue)) |
      write("NULLVALUE n=", &errornumber, " VALUE-FAILED");
end
ICN
cat > "$T/f206.icn" <<'ICN'
procedure main();
   write(-36. ^ -9.);
end
ICN
cat > "$T/f102.icn" <<'ICN'
procedure main();
   write(1 + "q");
end
ICN
build_oracle() { rm -f "$T/$1.u1" "$T/$1.u2" "$T/orc_$1"
  ( cd "$T" && "$ICONT" -s -o "orc_$1" "$1.icn" ) > "$T/icont_$1.log" 2>&1
  [ -x "$T/orc_$1" ] || { echo "GATE UNPROVEN(2): icont refused $1.icn -- measured nothing:"; sed 's/^/    /' "$T/icont_$1.log"; exit 2; }
  "$ICONX" "$T/orc_$1" < /dev/null > "$T/want_$1" 2>&1 || true; }
run_scrip() { timeout -k 5 60 "$R/scrip" "$T/$1.icn" < /dev/null > "$T/m3_$1" 2>&1
  rm -f "$T/$1.s" "$T/bin_$1"
  timeout -k 5 60 "$R/scrip" --compile -o "$T/$1.s" "$T/$1.icn" < /dev/null > "$T/cc_$1.log" 2>&1
  [ -s "$T/$1.s" ] && gcc -m64 -no-pie "$T/$1.s" -o "$T/bin_$1" -L"$R/out" -lscrip_rt -Wl,-rpath,"$R/out" -lm -lpthread >> "$T/cc_$1.log" 2>&1
  [ -x "$T/bin_$1" ] || { echo "GATE UNPROVEN(2): mode 4 produced no binary for $1.icn -- measured nothing:"; tail -3 "$T/cc_$1.log" | sed 's/^/    /'; exit 2; }
  timeout -k 5 60 "$T/bin_$1" < /dev/null > "$T/m4_$1" 2>&1; }
for p in g f206 f102; do build_oracle "$p"; run_scrip "$p"; done
grep -q '^HASVALUE ' "$T/want_g" || { echo "GATE UNPROVEN(2): the oracle printed no HASVALUE row -- measured nothing:"; sed 's/^/    /' "$T/want_g"; exit 2; }
bad=0
for key in HASVALUE NOVALUE_206 NOVALUE_204 STALE NULLVALUE; do
  w=$(grep -F "$key " "$T/want_g" | head -1)
  [ -n "$w" ] || { echo "  ⛔ UNPROVEN  $key: the oracle named no such row"; bad=$((bad + 1)); continue; }
  for m in m3 m4; do
    g=$(grep -F "$key " "$T/${m}_g" | head -1)
    if [ "$g" = "$w" ]; then printf '  ✅ %-4s %-12s %s\n' "$m" "$key" "$w"
    else printf '  ⛔ %-4s %-12s want: %s\n              got:  %s\n' "$m" "$key" "$w" "${g:-<absent>}"; bad=$((bad + 1)); fi
  done
done
# THE FATAL REPORT. Not a value comparison -- the presence or absence of the "offending value:" line, which is
# the same DT_FAIL fact read by core_icn_report instead of by the keyword. f206 must have none; f102 must have one.
for p in f206 f102; do
  w=$(grep -c '^offending value:' "$T/want_$p")
  for m in m3 m4; do
    g=$(python3 "$R/../harness/scripts/util_render_error_voice.py" icon < "$T/${m}_$p" | grep -c '^offending value:')
    if [ "$g" = "$w" ]; then printf '  ✅ %-4s %-12s offending-value lines = %s (oracle %s)\n' "$m" "FATAL_$p" "$g" "$w"
    else printf '  ⛔ %-4s %-12s offending-value lines = %s, oracle prints %s\n' "$m" "FATAL_$p" "$g" "$w"; bad=$((bad + 1)); fi
  done
done
echo "gate: $bad divergence(s) from the Arizona oracle, over 5 recorded shapes + 2 fatal reports x 2 modes."
[ "$bad" -eq 0 ] || { echo "GATE FAIL [icn_errorvalue_is_absent_when_the_error_carries_none]: &errorvalue does not match the oracle for an error that carries no value."; exit 1; }
echo "GATE PASS [icn_errorvalue_is_absent_when_the_error_carries_none]"
exit 0
