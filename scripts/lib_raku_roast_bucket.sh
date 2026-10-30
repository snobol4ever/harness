#!/bin/bash
# ../harness/scripts/lib_raku_roast_bucket.sh -- THE ONE BUCKET AUTHORITY FOR THE RAKU ROAST TREE (hq_raku 2026-09-16).
# Extracted VERBATIM from raku_roast_scoreboard.sh's --inventory arm on the lib_ladder.sh / lib_port_trace.sh
# precedent: one body, sourced, never a second copy. It exists because the ABLATION RANKER must decide
# "did this file move into a GRADED bucket" using the SAME rule the inventory used to say it was dark --
# and a ranker carrying its own private copy of that rule would be free to disagree with the census it is
# ranking, silently and in the flattering direction.
# ⛔ WHY AN EXTRACTION AND NOT A REIMPLEMENTATION: the measurement this feeds is "files moved into a graded
# bucket", which is a DIFFERENCE between two classifications. A difference taken across two copies of a
# classifier measures the copies as much as the cure -- so the two arms must be the same bytes, not merely
# the same intent (CLAUDE.md § Testing: shared authorities are sourced rather than reimplemented).
# Contract: classify <stdout> <stderr> <rc> -> PASS|FAIL|PARSE-FAIL|CRASH|NO-TAP  (the TAP verdict)
#           roast_bucket <stdout> <stderr> <rc> -> GRADED-PASS|GRADED-FAIL|UNGRADED-PARSE|UNGRADED-LEX|UNGRADED-EMITTER|
#                                                  UNGRADED-NO-TAP|UNGRADED-OTHER|UNGRADABLE-TIMEOUT
classify() {
  # $1=stdout file  $2=stderr file  $3=rc  -> echoes one of PASS/FAIL/PARSE-FAIL/CRASH/NO-TAP
  local so="$1" se="$2" rc="$3"
  if grep -q "parse error" "$se" 2>/dev/null; then echo "PARSE-FAIL"; return; fi
  # The native emitter's refusal ("[SMX] --run: mode-3 native emitter does not yet cover this program: ...") stops the program before it
  # runs, as a parse error does: it is a REJECT, not a run that printed no TAP (hq_raku 2026-10-14: 270 roast files read UNPROVEN in mode 3
  # and REJECT in mode 4 for the same refusal, so the class hid behind two names).
  if grep -q '^\[SMX\] ' "$se" 2>/dev/null && ! grep -qE '^(ok|not ok) [0-9]+|^1\.\.[0-9]+' "$so" 2>/dev/null; then echo "PARSE-FAIL"; return; fi
  # A test file that reports its failures exits with the NUMBER of failures (Rakudo's Test, capped at 254), so a high status with TAP on stdout and no signal message is a FAIL the TAP
  # shows, not a crash (hq_raku 2026-10-04: 46 files with 128 to 254 failures were read as crashes). A signal death leaves "fatal signal" on stderr or no TAP at all.
  if [ "$rc" -ge 124 ] && ! { [ "$rc" -ne 124 ] && grep -qE '^(ok|not ok) [0-9]+|^1\.\.[0-9]+' "$so" 2>/dev/null && ! grep -qE 'fatal signal|core dumped' "$se" 2>/dev/null; }; then echo "CRASH"; return; fi
  local plan ok notok
  plan=$(grep -cE '^1\.\.[0-9]+' "$so" 2>/dev/null)
  ok=$(grep -cE '^ok [0-9]+' "$so" 2>/dev/null)
  notok=$(grep -cE '^not ok [0-9]+' "$so" 2>/dev/null)
  if [ "$plan" -eq 0 ] && [ "$ok" -eq 0 ] && [ "$notok" -eq 0 ]; then echo "NO-TAP"; return; fi
  if [ "$notok" -gt 0 ]; then echo "FAIL"; return; fi
  if [ "$rc" -ne 0 ]; then echo "FAIL"; return; fi
  echo "PASS"
}
# THE BUCKET. GRADED means our compiler ran the file and TAP came out; everything else is a reason it did not.
# ⛔⭐ THE PARSER SAYING SO, IN ITS OWN WORDS, AND THE ONE PLACE THAT KNOWS THEM (hq_raku 2026-09-27, ceo CEO-1318).
# The hand-written parser that replaced flex/bison (SCRIP 2d9817261, 2026-09-26) refuses with a POSITIONED first
# line, `<file>:<line>:<col>: raku syntax error: <why>`, and the driver's bare `raku: parse error in <file>` comes
# SECOND. Every test here read line 1 for `parse error`, the old parser's first-line wording, so from the swap on a
# file the parser refused read as OTHER in the parse census and fell through to UNGRADED-NO-TAP here: the census
# gate's own unparseable fixture read other=1 parse_fail=0 for a day. Line 1 stays the rule (see the lex arm below
# for why a whole-stderr grep is wrong); what changes is that line 1 is matched against BOTH parsers' wording, in
# this one function, so the census, the bucket and the ranker cannot drift apart again.
roast_parser_refused() { printf '%s' "$1" | grep -qE ': raku syntax error: |parse error'; }
roast_bucket() {
  local so="$1" se="$2" rc="$3" err1
  err1=$(head -1 "$se" 2>/dev/null)
  if roast_parser_refused "$err1"; then echo UNGRADED-PARSE; return; fi
  # ⛔⭐⭐ A LEX FAILURE IS A FRONT-END FAILURE AND THIS FUNCTION HAD NO NAME FOR IT, SO 61 FILES SAT IN
  # BUCKETS THAT DESCRIBED A LATER STAGE (hq_raku 2026-09-16, found by the parse census this landed beside:
  # its OTHER class -- rc!=0 with no "parse error" text -- came back 61 files, and every one of them has
  # `raku lex error` on the first line of stderr).
  # ⛔ WHERE THEY WERE AND WHY THE NAME LIES. MEASURED over exactly those 61 under --run, before and after
  # this arm: all 61 read UNGRADED-OTHER, and all 61 now read UNGRADED-LEX. UNGRADED-OTHER reads "it failed
  # some way we have no name for" about a class we can name exactly, so a reader triaging that bucket goes
  # looking for a defect in a stage the file never reached.
  # ⛔⭐⭐ AND THE NUMBER IN THIS COMMENT WAS WRONG ONCE BEFORE IT WAS RIGHT, FOR A REASON WORTH MORE THAN
  # THE CURE. It first read "53 UNGRADED-OTHER and 8 UNGRADED-NO-TAP", measured by sourcing this file into
  # the measuring session's OWN shell and calling roast_bucket there. That shell had a `grep` SHELL FUNCTION
  # (the agent harness routes grep to ugrep -I), and ugrep -I calls a line carrying an invalid UTF-8 byte
  # BINARY and answers NO MATCH -- so seven lex diagnostics about invalid bytes silently failed to match the
  # ASCII words `lex error`. A child process never sees a shell function: every script here gets /usr/bin/grep
  # (GNU 3.11), which matches them all. The split was an artifact of the measuring environment and existed
  # nowhere in the tree; re-measured through `bash <probe>` the answer is 61 and 0.
  # ⭐ THE REUSABLE PART: SOURCING A LIBRARY INTO YOUR OWN SHELL IS NOT RUNNING IT. It inherits your
  # functions, aliases and locale, so it can answer differently than it ever will in production -- and it
  # answers plausibly, which is why nothing looked wrong. Measure a script the way the script runs: in a
  # child process. This was nearly landed as a 20-line `grep -a` cure with a fabricated witness attached.
  # ⭐ THIS IS THE CTO'S OWN RULING BITING THE FUNCTION THAT PROVOKED IT (2026-09-16): a bucket named for a
  # stage names what it CAN RECOGNISE, not what the program REACHED. The same shape is already recorded two
  # comments down (`rc -ge 124` filing every SIGSEGV under a bucket named for the clock) and it is recorded
  # in the baton as the reason parse coverage was published as 143 when it was 66 -- because the complement
  # of UNGRADED-PARSE counted as "parsed" every file that failed for a reason this rule had no name for.
  # Three instances, one function: the cure is always to give the unnamed class its own name.
  # ⛔ IT MOVES NO TOTAL AND NO FRACTION: UNGRADED-LEX carries the UNGRADED- prefix, so the inventory's
  # graded/ungraded/ungradable split, its closing identity and every published number are byte-for-byte what
  # they were. Only the 61 files' NAME changes, which is the whole point -- they were never miscounted, they
  # were misdescribed, and a misdescribed file is one nobody can triage.
  # ⛔ IT IS TESTED ON head -1 DELIBERATELY, like the parse arm above it: these files carry `lex error` on
  # line 1 and a bare `parse error in <file>` on line 2, so a whole-stderr grep would file them as parse
  # failures and hand the ablation ranker 61 files whose dying line is not a construct it can ablate.
  if printf '%s' "$err1" | grep -q 'lex error'; then echo UNGRADED-LEX; return; fi
  if printf '%s' "$err1" | grep -q 'does not yet cover'; then echo UNGRADED-EMITTER; return; fi
  # ⛔⭐⭐ A CRASH IS NOT A TIMEOUT, AND THIS LINE CALLED EVERY SIGNAL DEATH A TIMEOUT (hq_raku
  # 2026-09-16, found by doing what the baton said: TIME the three UNGRADABLE-TIMEOUT files before
  # classifying them). `rc -ge 124` is true for 124 (timeout fired) AND for 134 (SIGABRT) AND 139 (SIGSEGV),
  # so every crash landed in a bucket named for the clock. THE MEASUREMENT: all three "timeout" files finish
  # in ~1.4s -- rc=134, rc=139, rc=139. None of them was ever slow. Our front end crashes on them.
  # ⛔ THE CONSEQUENCE IS THE WHOLE POINT, NOT THE LABEL: UNGRADABLE- reads as "not our problem, out of
  # the numerator honestly" (the oracle refuses it, it needs input we do not ship). A compiler that SIGSEGVs
  # is our defect and belongs in the DARK count where it is owed, not in the excused one. Three files were
  # sitting in the excused column with a SIGSEGV behind them.
  # ⭐ AND THE INFORMATION WAS ALREADY IN THE BUILDING: classify() below returns "CRASH" for exactly this
  # condition. The bucket layer re-tested the same rc and overwrote a correct name with a worse one -- which
  # also made classify()'s CRASH arm dead code on the roast path. When two layers classify the same fact,
  # the outer one silently wins, so they must not both decide.
  if [ "$rc" -eq 124 ]; then echo UNGRADABLE-TIMEOUT; return; fi
  # ⛔ 255 IS NOT A SIGNAL DEATH: Rakudo's Test exits 255 when the plan is not met, and SCRIP's Test emulation now does the same (hq_raku 2026-10-04, found when the
  # honest exit status moved 315 files into UNGRADED-CRASH). A signal death is 128 plus the signal (at most 159 here); 255 falls through to classify, which reads the TAP.
  if [ "$rc" -ge 128 ] && ! { grep -qE '^(ok|not ok) [0-9]+|^1\.\.[0-9]+' "$so" 2>/dev/null && ! grep -qE 'fatal signal|core dumped' "$se" 2>/dev/null; }; then echo UNGRADED-CRASH; return; fi
  if [ "$rc" -ge 125 ] && [ "$rc" -le 127 ]; then echo UNGRADED-OTHER; return; fi
  case "$(classify "$so" "$se" "$rc")" in
    PASS)   echo GRADED-PASS ;;
    FAIL)   echo GRADED-FAIL ;;
    NO-TAP) echo UNGRADED-NO-TAP ;;
    *)      echo UNGRADED-OTHER ;;
  esac
}
# ⛔⭐ THE STORED FIRST CAUSE OF A RED (hq_raku 2026-10-30, ceo CEO-2030, the cto's ARCH-FLEET-PLAN-TO-100 section 2.5). A FAIL, CRASH or HANG reading carried the program's
# FIRST stderr line, and for 148 programs that line was the Test epilogue `# You planned N tests, but ran M` -- the symptom of dying, never the death -- so 157 reds had no class
# a rewrite step could claim. This answers one line, never empty, tab-free: the first test that did not pass (the first `not ok N - desc`, else the first test the plan promised and
# the run never reached, with the last test that did pass beside it), the program's rc, and the LAST stderr line that is not the Test epilogue (the die message, the signal, the diagnostic a timeout never printed).
# Contract: roast_first_cause <stdout> <stderr> <rc> -> "first red: test N <what> | rc R | stderr: <line>"
roast_first_cause() {
  local so="$1" se="$2" rc="$3" first plan last ran what err
  first=$(grep -m1 -E '^not ok [0-9]+' "$so" 2>/dev/null)
  plan=$(grep -m1 -oE '^1\.\.[0-9]+' "$so" 2>/dev/null | cut -c4-)
  last=$(grep -E '^ok [0-9]+' "$so" 2>/dev/null | tail -1 | awk '{print $2}')
  ran=$(grep -cE '^(ok|not ok) [0-9]+' "$so" 2>/dev/null)
  if [ -n "$first" ]; then what="test $(printf '%s' "$first" | awk '{print $3}') not ok$(printf '%s' "$first" | sed -n 's/^not ok [0-9]\+ \+-\? *\(.\{1,60\}\).*/ - \1/p' | sed 's/ - $//')"
  elif [ -n "$plan" ] && [ "${ran:-0}" -lt "$plan" ]; then
    what="test $(( ${last:-0} + 1 )) not reached (ran ${ran:-0} of $plan$(grep -E '^ok [0-9]+' "$so" 2>/dev/null | tail -1 | sed -n 's/^ok [0-9]\+ \+-\? *\(.\{1,50\}\).*/, last ok: \1/p' | tr '\t' ' '))"
  elif [ "${ran:-0}" -eq 0 ]; then what="none, no TAP"
  else what="none, every test ran ok"; fi
  err=$(grep -vE '^[[:space:]]*$|^# You (planned|failed) ' "$se" 2>/dev/null | tail -1 | tr '\t' ' ' | cut -c1-160)
  printf 'first red: %s | rc %s | stderr: %s\n' "$what" "$rc" "${err:-(none)}"
}
# THE CONSTRUCT KEY: the source line the parse died on, literals and numbers folded, so a histogram and a
# ranker name CONSTRUCTS and not line numbers -- and so both name them THE SAME WAY.
roast_fold_construct() { sed "s/'[^']*'/'STR'/g; s/\"[^\"]*\"/\"STR\"/g; s/[0-9][0-9]*/N/g"; }
# The line the parse died on: the positioned `<file>:<line>:<col>: raku syntax error:` form FIRST, because its message
# can itself say `line N` about somewhere else ("corresponding starter was at line 1"); then the old `line N` form.
roast_err_line() { printf '%s' "$1" | sed -n 's/^[^:]*:\([0-9]\+\):[0-9]\+: raku syntax error: .*/\1/p; t; s/.*line \([0-9]\+\).*/\1/p'; }
# ⛔⭐ THE POPULATION RESOLVER, SHARED FOR THE SAME REASON THE BUCKET RULE IS (hq_raku 2026-09-16):
# an instrument that RANKS a census must grade the same files the census graded. Resolution order is
# per-root refs/ FIRST (a root still carrying its own gitignored copy keeps grading that copy, so this
# moves no existing measurement), then the shared read-only tree under /home/resources, then an explicit
# env override. ⛔ REFUSES naming every candidate tried, rather than grading a population nobody chose.
resolve_pop() {  # $1=env override  $2..=candidates, first that exists wins
  # ⛔ AN EXPLICIT OVERRIDE IS CHECKED LIKE ANY OTHER CANDIDATE (hq_raku 2026-09-16, caught by this lib's
  # own fail-once arm). It used to be returned unvalidated, so RAKU_ROAST_TREE=/nonexistent resolved happily
  # and the caller refused several steps later with "censused ZERO files" -- a true refusal naming the wrong
  # cause, which is the shape that sends the next seat to look at the census loop instead of at their env.
  local ov="$1"; shift
  if [ -n "$ov" ]; then
    [ -e "$ov" ] || { printf '%s\n' ""; return 1; }
    printf '%s\n' "$ov"; return 0
  fi
  local c; for c in "$@"; do [ -e "$c" ] && { printf '%s\n' "$c"; return 0; }; done
  printf '%s\n' ""; return 1
}
roast_resolve_population() {  # $1=ROOT -> sets ROAST and MANIFEST, or refuses rc=2
  local root="$1"
  MANIFEST=$(resolve_pop "${RAKU_ROAST_MANIFEST:-}" "$root/refs/rakudo-main/t/spectest.data.6.c" /home/resources/rakudo-main/t/spectest.data.6.c) || {
    echo "⛔ REFUSE(2) [roast]: no spectest manifest -- tried \$RAKU_ROAST_MANIFEST, $root/refs/rakudo-main/t/spectest.data.6.c, /home/resources/rakudo-main/t/spectest.data.6.c" >&2; return 2; }
  ROAST=$(resolve_pop "${RAKU_ROAST_TREE:-}" "$root/refs/roast" /home/resources/roast-master) || {
    echo "⛔ REFUSE(2) [roast]: no roast tree -- tried \$RAKU_ROAST_TREE, $root/refs/roast, /home/resources/roast-master" >&2; return 2; }
  return 0
}
