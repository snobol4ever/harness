#!/usr/bin/env bash
# test_gate_mint_refuses_a_prose_donewhen.sh -- `mint` REFUSES a DONE-WHEN that is not a runnable
# criterion, at mint time, instead of letting a permanently-uncloseable row reach the queue.
# Row mint-refuses-a-done-when-whose-first-word-is-not-a-command (hq_T's mint 2026-09-13, hq_B cured).
#
# THE SHAPE, and it is the whole argument for curing this at the MINT rather than on the rows: `done`
# EXECUTES the DONE-WHEN, so a criterion that is prose can never exit 0 -- the row can be cured
# PERFECTLY and still record no flip. ⛔ THE COST LANDS ON WHOEVER LATER CURES THE ROW, NOT ON WHOEVER
# MINTED IT, which is exactly the shape that does not self-correct. test_gate_baton_donewhen_runnable.sh
# already knows the rule and says so in its own failure text ("if you minted one, make it a command
# before you push") -- at the wrong end of the pipeline, hours later, as a blocking arm on somebody else.
# hq_T walked into it three times in one hour and only found out when that arm went red.
#
# ⛔⭐ THIS GATE NEVER EXECUTES A CRITERION, and neither does the guard it grades. mint runs before any
# work exists, so a criterion that legitimately REDS today is the normal case; the only questions asked
# are the two static ones -- does it PARSE as shell, and does its first command word RESOLVE.
#
# SEVEN ARMS, hermetic under a scratch postoffice per mktemp -- never the live one:
#   (1) PROSE-REFUSED     the row's own witness: `the thing works and the board is green.` is REFUSED
#                          rc=2, the message names DONE-WHEN, and NEITHER a QUEUE.tsv row NOR a baton
#                          is written -- a refusal after the row is appended is not a refusal.
#   (2) NOOP-REFUSED      `true` is REFUSED. The row's minter asked for this arm in so many words:
#                          "the guard must not be satisfiable by typing true, or the cure hands
#                          everyone a bypass." A guard whose cheapest escape is one word is a ramp.
#   (3) STUB-REFUSED      the hand-rolled self-refusing stub (`echo "⛔ no computable DONE-WHEN yet";
#                          false`) is REFUSED. It PARSES and its first word RESOLVES, so the sibling
#                          gate's first-word arm cannot see it -- 11 live rows carry this shape today.
#   (4) REAL-ACCEPTED     an ordinary criterion (`bash ../harness/scripts/test_gate_x.sh`) MINTS, and the baton
#                          carries EXACTLY ONE DONE-WHEN line, the caller's.
#   (5) HEREDOC-ACCEPTED  the multi-line heredoc witness shape this project actively encourages MINTS.
#                          ⭐ THE ARM MOST LIKELY TO HAVE BEEN OMITTED: the lint judges the FIRST line
#                          unless that line is incomplete shell, and a heredoc opener is incomplete --
#                          a lint that judged only line 1 would refuse every heredoc criterion, i.e.
#                          exactly the shape the project tells seats to write.
#   (6) UNRESOLVABLE-OK   a criterion opening on `"$SCRIP"` MINTS. No static check can resolve a word
#                          carrying an expansion, and convicting it is the measured false positive
#                          lib_donewhen.sh exists to end (hq_S 2026-09-11: two CURED rows called
#                          PERMANENTLY UNCLOSEABLE, and the seat rewrote their criteria to please the
#                          instrument). A checker that cannot measure says so; it does not convict.
#   (7) NO-DONEWHEN-UNCHANGED  a mint supplying NO DONE-WHEN still writes the placeholder baton exactly
#                          as before. ⛔ THIS CURE DELIBERATELY DOES NOT WIDEN INTO THAT PATH -- the
#                          placeholder has its own companion refusal at DISPATCH
#                          (test_gate_dispatch_refuses_placeholder_donewhen.sh) and closing the
#                          mint-without-a-criterion path is a ruling, not a free extra. See ## QA.
# FAIL-ONCE: one mutant removes the guard's call site; arms 1, 2 and 3 must go RED under it. EXIT 0 iff
# all seven arms hold on the real tool AND the mutant reds; 1 otherwise; 2 REFUSED (fixture unbuildable).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; MSG="$HERE/s4e_msg.sh"
[ -f "$MSG" ] || { echo "⛔ REFUSED(2): $MSG missing -- cannot measure"; exit 2; }
W="$(mktemp -d)" || { echo "⛔ REFUSED(2): mktemp failed"; exit 2; }
# ⛔ $BASHPID, not $$: a bare EXIT trap fires inside forked children too, and bash keeps $$ at the
# original shell's pid in a subshell, so the obvious guard compares equal and deletes the fixture
# mid-run (measured while building test_gate_s4e_one_process_per_identity.sh).
MAINPID=$$; trap '[ "$BASHPID" = "$MAINPID" ] && rm -rf "$W"' EXIT
PO="$W/po"; ME=hq_B
# ⛔⭐ env -u S4E_PID_LOCK AND S4E_NO_DISPATCH_PROBE: this gate is itself a DONE-WHEN, so it may run
# INSIDE a `done` that `next` invoked as its own dispatch probe. Both variables leak in from that parent
# and would silently change what the fixture measures -- scrubbed, always (same guard as the siblings).
FIX() { env -u S4E_PID_LOCK -u S4E_NO_DISPATCH_PROBE S4E_HOME="$W" S4E_POST="$PO" S4E_SEAT="$ME" \
        S4E_NO_BANNER=1 "$@"; }
mk_po() {
  rm -rf "$PO"; mkdir -p "$PO/tasks" "$PO/claims" "$PO/$ME/inbox" "$PO/ceo/inbox" || return 2
  : > "$PO/BOARD.md"; : > "$PO/QUEUE.done.tsv"; printf 'NONET\n' > "$PO/MODE"
  printf '5\n' > "$PO/PROTOCOL-VERSION"; printf 'ceo\n' > "$PO/$ME/HQ"
  printf '# gate fixture queue\n' > "$PO/QUEUE.tsv"; }
# rowcount <topic> -> number of QUEUE.tsv rows naming it (expected 0 on a refusal, 1 on a mint)
rowcount() { grep -cP "^[0-9]+\t\Q$1\E\t" "$PO/QUEUE.tsv" 2>/dev/null || true; }

# refuses <script> <topic> <criterion> -- rc=2, message names DONE-WHEN, NOTHING written
refuses() {
  local s="$1" topic="$2" dw="$3" out rc
  out="$(printf 'GOAL: fixture.\nDONE-WHEN: %s\n' "$dw" | FIX bash "$s" mint "$topic" 5 --owner hq_T --stdin 2>&1)"; rc=$?
  [ "$rc" = 2 ]                                  || { echo "    ✗ $topic: rc=$rc, expected 2 (a refusal, not a red)"; return 1; }
  printf '%s' "$out" | grep -qi 'done-when'      || { echo "    ✗ $topic: refused but never names DONE-WHEN, so the author cannot tell what to fix"; return 1; }
  [ ! -f "$PO/tasks/$topic.task.md" ]            || { echo "    ✗ $topic: REFUSED but wrote a baton anyway"; return 1; }
  [ "$(rowcount "$topic")" = 0 ]                 || { echo "    ✗ $topic: REFUSED but appended a QUEUE.tsv row anyway"; return 1; }
  return 0; }
# accepts <script> <topic> <criterion> -- mints, and the baton carries exactly one DONE-WHEN line
accepts() {
  local s="$1" topic="$2" dw="$3" out rc n
  out="$(printf 'GOAL: fixture.\nDONE-WHEN: %s\n' "$dw" | FIX bash "$s" mint "$topic" 5 --owner hq_T --stdin 2>&1)"; rc=$?
  [ "$rc" = 0 ]                       || { echo "    ✗ $topic: rc=$rc, expected 0 -- a legitimate criterion was REFUSED:"; printf '%s\n' "$out" | head -3 | sed 's/^/        /'; return 1; }
  [ -f "$PO/tasks/$topic.task.md" ]   || { echo "    ✗ $topic: reported success but wrote no baton"; return 1; }
  n="$(grep -c '^DONE-WHEN:' "$PO/tasks/$topic.task.md")"
  [ "$n" = 1 ]                        || { echo "    ✗ $topic: baton carries $n DONE-WHEN lines, expected exactly 1"; return 1; }
  grep -q '^DONE-WHEN: ⛔ MUST BE MADE RUNNABLE' "$PO/tasks/$topic.task.md" \
     && { echo "    ✗ $topic: the caller's criterion was replaced by the placeholder"; return 1; }
  return 0; }

arms() {   # arms <label> <script> -> 0 iff all seven contracts hold on <script>
  local lbl="$1" s="$2" ok=1
  mk_po || return 2
  echo "  -- $lbl"
  refuses "$s" t-prose 'the thing works and the board is green.'                  || ok=0
  refuses "$s" t-noop  'true'                                                     || ok=0
  refuses "$s" t-stub  'echo "⛔ no computable DONE-WHEN yet — write one"; false'  || ok=0
  accepts "$s" t-real  'bash ../harness/scripts/test_gate_x.sh'                              || ok=0
  accepts "$s" t-unres '"$SCRIP" --run w.icn | grep -q ok'                        || ok=0
  # ⭐ THE HEREDOC ARM, fed through the same --stdin path a real minter uses, so the criterion really is
  # multi-line in the baton rather than a one-line imitation of one.
  local out rc
  out="$(printf 'GOAL: fixture.\nDONE-WHEN: cat > /tmp/w.sno <<%sEOF%s\n OUTPUT = 1\nEND\nEOF\nout=$(./scrip /tmp/w.sno); [ "$out" = 1 ] || exit 1\n' "'" "'" \
        | FIX bash "$s" mint t-heredoc 5 --owner hq_T --stdin 2>&1)"; rc=$?
  if [ "$rc" != 0 ]; then echo "    ✗ t-heredoc: rc=$rc, expected 0 -- the encouraged multi-line witness shape was REFUSED:"; printf '%s\n' "$out" | head -3 | sed 's/^/        /'; ok=0
  elif [ ! -f "$PO/tasks/t-heredoc.task.md" ]; then echo "    ✗ t-heredoc: reported success but wrote no baton"; ok=0; fi
  # ⛔⭐ ARM 7 (rewritten 2026-10-01, CEO-1386 -- Lon: "a row exists only while a measurement says the problem exists"):
  # a mint supplying NO DONE-WHEN is REFUSED rc=2 with nothing written. The old arm asserted the opposite (rc=0 and a
  # placeholder baton); that ruling is RETIRED: 80 placeholder rows were live at the zero-base, none of them work.
  out="$(printf 'GOAL: fixture with no criterion at all.\n' | S4E_MINT_NO_CRITERION= FIX bash "$s" mint t-none 5 --owner hq_T --stdin 2>&1)"; rc=$?
  if [ "$rc" != 2 ]; then echo "    ✗ t-none: rc=$rc, expected 2 -- a mint supplying NO DONE-WHEN must be REFUSED (CEO-1386)"; ok=0
  elif [ -f "$PO/tasks/t-none.task.md" ]; then echo "    ✗ t-none: REFUSED but wrote a baton anyway"; ok=0
  elif [ "$(rowcount t-none)" != 0 ]; then echo "    ✗ t-none: REFUSED but appended a QUEUE.tsv row anyway"; ok=0
  elif ! printf '%s' "$out" | grep -q 'DONE-WHEN'; then echo "    ✗ t-none: refused but never names DONE-WHEN, so the author cannot tell what to fix"; ok=0; fi
  # ⭐ ARM 8: the ONE sanctioned exception -- a bus gate's FIXTURE row names itself in S4E_MINT_NO_CRITERION. The mint
  # then writes the placeholder (which must PARSE as shell and EXIT NON-ZERO, so the row is closeable once a real
  # criterion replaces it and can never close while wearing it) and a MINTED-WITHOUT-CRITERION: line naming the reason.
  out="$(printf 'GOAL: fixture with no criterion, named as such.\n' | S4E_MINT_NO_CRITERION="gate fixture" FIX bash "$s" mint t-fixture 5 --owner hq_T --stdin 2>&1)"; rc=$?
  if [ "$rc" != 0 ]; then echo "    ✗ t-fixture: rc=$rc, expected 0 -- a named fixture mint must still work:"; printf '%s\n' "$out" | head -3 | sed 's/^/        /'; ok=0
  elif ! _dw="$(sed -n 's/^DONE-WHEN: //p' "$PO/tasks/t-fixture.task.md" 2>/dev/null | head -1)" || [ -z "$_dw" ]; then
      echo "    ✗ t-fixture: the placeholder baton was not written at all"; ok=0
  elif ! bash -n -c "$_dw" 2>/dev/null; then
      echo "    ✗ t-fixture: mint's placeholder does not PARSE as shell -- a fresh row would be permanently uncloseable: $_dw"; ok=0
  elif bash -c "$_dw" >/dev/null 2>&1; then
      echo "    ✗ t-fixture: mint's placeholder EXITS 0 -- a fresh row would close VACUOUSLY, worse than the prose it replaced: $_dw"; ok=0
  elif ! grep -q '^MINTED-WITHOUT-CRITERION: gate fixture' "$PO/tasks/t-fixture.task.md"; then
      echo "    ✗ t-fixture: the baton does not record WHY it was minted without a criterion"; ok=0
  fi
  [ "$ok" = 1 ]; }

RC=0
arms "REAL TOOL (all seven arms must hold)" "$MSG" || RC=1
# ⛔⭐ FAIL-ONCE. A gate nobody has seen go red is a gate nobody has tested. The mutant removes the guard's
# CALL SITE -- not the helper -- because a cure can be present and unwired, which is the failure mode the
# sibling next-runs-done-when-at-dispatch cure actually shipped with on one of its two paths.
# ⛔⭐⭐ THE MUTANT IS STAGED WITH ITS SIBLINGS, and the direction this failed in is why it is spelled out.
# A mutant at $W/mutant.sh resolves `dirname "${BASH_SOURCE[0]}"` to $W and finds no lib beside it. That was
# survivable until 2026-09-23, when the DONE-WHEN EXTRACTOR MOVED INTO lib_donewhen.sh (cto's ruling: one
# implementation) and the bus began REFUSING rc=2 without it. ⛔ THE REFUSAL LOOKS LIKE THE CURE: arms 1-3
# assert the mutant FAILS TO REFUSE a prose criterion, so a mutant that refuses EVERYTHING for a staging
# reason reads as "the guard still works" and the gate printed "mutant stayed green on 3 of 3". A fixture
# fault wearing a verdict, in the one arm built to tell a cure from its absence.
MUTD="$W/mut"; MUT="$MUTD/s4e_msg.sh"
mkdir -p "$MUTD" || { echo "⛔ REFUSED(2): cannot stage the mutant directory"; exit 2; }
cp "$HERE"/lib_*.sh "$MUTD/" || { echo "⛔ REFUSED(2): cannot stage the sibling lib_*.sh the mutant sources"; exit 2; }
sed 's/^\( *\)_dw_why="\$(s4e_donewhen_unrunnable_why/\1_dw_why="" \&\& false \&\& _dw_why="$(s4e_donewhen_unrunnable_why/' "$MSG" > "$MUT"
if ! bash -n "$MUT" 2>/dev/null; then echo "⛔ REFUSED(2): the mutant does not parse -- the sed no longer matches the call site, so FAIL-ONCE proves nothing"; exit 2; fi
if cmp -s "$MSG" "$MUT"; then echo "⛔ REFUSED(2): the mutant is byte-identical to the real script -- the call site moved and this gate would pass vacuously"; exit 2; fi
echo "  -- MUTANT (guard unwired; arms 1-3 MUST go red)"
mk_po || exit 2
MUT_RED=0
refuses "$MUT" t-prose 'the thing works and the board is green.'                 >/dev/null 2>&1 || MUT_RED=$((MUT_RED+1))
refuses "$MUT" t-noop  'true'                                                    >/dev/null 2>&1 || MUT_RED=$((MUT_RED+1))
refuses "$MUT" t-stub  'echo "⛔ no computable DONE-WHEN yet — write one"; false' >/dev/null 2>&1 || MUT_RED=$((MUT_RED+1))
if [ "$MUT_RED" = 3 ]; then echo "    ✓ mutant red on all 3 refusal arms -- the guard is load-bearing"
else echo "    ✗ mutant stayed green on $((3-MUT_RED)) of 3 refusal arms -- this gate cannot tell the cure from its absence"; RC=1; fi
MUT2="$MUTD/s4e_msg_nocrit.sh"
sed "s/^\( *\)if ! printf '%s\\\\n' \"\$goal\" | grep -q '^DONE-WHEN:'; then/\1if false; then/" "$MSG" > "$MUT2"
if ! bash -n "$MUT2" 2>/dev/null; then echo "⛔ REFUSED(2): the no-criterion mutant does not parse -- the sed no longer matches the call site"; exit 2; fi
if cmp -s "$MSG" "$MUT2"; then echo "⛔ REFUSED(2): the no-criterion mutant is byte-identical to the real script -- the guard moved and ARM 7 would pass vacuously"; exit 2; fi
echo "  -- MUTANT 2 (the missing-criterion refusal unwired; ARM 7 MUST go red)"
mk_po || exit 2
out="$(printf 'GOAL: fixture with no criterion at all.\n' | S4E_MINT_NO_CRITERION= FIX bash "$MUT2" mint t-none 5 --owner hq_T --stdin 2>&1)"; rc=$?
if [ "$rc" = 2 ]; then echo "    ✗ mutant 2 still refused the no-criterion mint -- ARM 7 cannot tell the cure from its absence"; RC=1
else echo "    ✓ mutant 2 accepted the no-criterion mint (rc=$rc) -- the CEO-1386 guard is load-bearing"; fi
echo ""
if [ "$RC" = 0 ]; then echo "✅ GATE PASS [mint_refuses_a_prose_donewhen]: mint refuses prose, true, the self-refusing stub AND a missing criterion (rc=2, nothing written); mints real, heredoc, unresolvable-word and no-criterion rows unchanged; mutant reds"
else echo "⛔ GATE FAIL [mint_refuses_a_prose_donewhen]: see the arms above"; fi
exit $RC
