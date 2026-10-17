#!/usr/bin/env bash
# test_gate_s4e_donewhen_runs_the_whole_criterion.sh -- `done` RUNS THE WHOLE DONE-WHEN, NOT ITS FIRST PHYSICAL LINE.
# AUTHORS: Lon Jones Cherryholmes · Claude Opus 5   DATE: 2026-09-05
# Row s4e-msg-donewhen-truncation-false-closes-multiline-heredoc-batons (seat04 reproduced it end to end; ceo ranked
# the cure 0 in hq_T's lane 2026-09-05 14:38).
#
# ⛔⭐⭐ THE DEFECT, AND ITS DIRECTION IS WHAT MAKES IT LETHAL. The ONE extraction point was
# `sed -n 's/^DONE-WHEN:...//p' "$b" | head -1` -- one physical line. For the self-contained heredoc witness this
# project encourages, the captured text is `cat > /tmp/w.sno <<'EOF'` with no closing delimiter: bash WARNS, treats
# the body as EMPTY, writes a zero-byte file, and that cat -- the only command reached -- exits 0. The criterion
# exits 0 HAVING RUN NOTHING, so a broken tree and a fixed one are byte-identical in verdict. ⭐ MEASURED CLOSURE:
# snobol4-pattern-primitive-as-function-argument-always-fails-in-callee closed DONE 2026-09-05T15:33Z through
# exactly this path while its full text exits 1 on the same tree. 185 of 1128 live batons carry a multi-line
# DONE-WHEN, so this is a population, not an anecdote.
#
# FOUR ARMS against a THROWAWAY postoffice under mktemp -- never the live one:
#   (A) TWO-LINE CRITERION, SECOND LINE RED: line 1 passes, line 2 exits 1 -> rc=1 NOT DONE, row NOT closed.
#       This is the ceo's named fail-once shape and the minimal statement of the whole defect.
#   (B) HEREDOC WITNESS: writes a file, then greps it, then exits 1 -> rc=1, AND the file is non-empty, which is
#       what proves the BODY ran rather than the opener alone. ⛔ Arm A alone cannot prove that: a fix that read
#       two lines and stopped would pass A and still truncate every heredoc.
#   (C) UNTERMINATED HEREDOC (an author's mistake, or a future re-truncation) -> REFUSED rc=2, row NOT closed.
#       Never rc=0 and never rc=1: bash cannot finish reading it, so nobody measured anything.
#   (D) MULTI-LINE AND GENUINELY GREEN -> rc=0 and the row CLOSES. Without this the gate would pass on a `done`
#       that had simply stopped closing anything, which is the cheap way to satisfy A/B/C and cure nothing.
#   (E) ⛔ THE ARM THAT COST THE MOST TO LEARN: a COMPLETE one-line criterion followed by indented PROSE ANNOTATION
#       -- "⛔ DONE-WHEN REWRITTEN 2026-08-24 (seat04): the line above used to be prose..." -- must still close
#       green. 121 of the 122 DONE batons whose field spans lines are exactly that shape, so the obvious
#       continuation rule ("read to the next column-0 label", which is how GOAL: carries paragraphs) would have
#       fed their annotation to `bash -c` and broken 121 correctly-closing rows to fix one. The cure is that
#       continuation happens ONLY while bash says the text is UNFINISHED.
#   (F) A SECOND column-0 `DONE-WHEN:` whose text is a REAL COMMAND -> REFUSED rc=2, row NOT closed. Only the
#       first line has ever run, so such a baton closes on HALF its own contract while the other half sits in the
#       file where every reader counts it as part of the bar. ⭐ MEASURED on the ceo's seed: 39 live batons carry
#       more than one, 10 extras are real commands, 6 of those rows are DONE, and one of those six -- snobol4-
#       xfail-class-setexit-errlimit-composition-2-entries -- has a RED second half ("cross-ref=0 (want 2)").
#   (G) THE SAME SHAPE WITH A LEFTOVER MINT PLACEHOLDER beneath a real criterion -> still closes green. Untidy is
#       not ambiguous, and 4 of the 39 are exactly that; refusing them would block real rows for a cosmetic reason.
#   (H) A SECOND column-0 `DONE-WHEN:` BYTE-IDENTICAL TO THE FIRST -> still closes green. Arm F refuses because
#       "which line is the contract" is a question about intent; identical text asks no such question, the
#       extractor taking the first loses nothing, and no half of any bar went unrun. ⭐ MEASURED: 3 of the 10
#       extras that survive F's placeholder filters are exactly this, and all three were being refused for a
#       cosmetic reason -- the same mistake G exists to prevent, one shape over.
# EXIT 0 all arms hold on the live script AND each mutant goes red; 1 otherwise; 2 REFUSED (fixture cannot be built).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; MSG="$HERE/s4e_msg.sh"
ROOT="$(cd "$HERE/../.." && pwd)"
[ -f "$MSG" ] || { echo "⛔ REFUSED: $MSG missing"; exit 2; }
[ -f "$ROOT/harness/scripts/s4e_msg.sh" ] || { echo "⛔ REFUSED: sibling root not resolvable from $HERE (want $ROOT/SCRIP)"; exit 2; }
W="$(mktemp -d)" || { echo "⛔ REFUSED: mktemp failed"; exit 2; }; trap 'rm -rf "$W"' EXIT
PO="$W/po"; ME=hq_T; HD="$W/hd.txt"
# ⛔ EVERY criterion names a path or a `$` ON PURPOSE: done's vacuity probe skips a criterion containing `/` or `$`,
# and without that these fixtures would be refused as decorated no-ops -- a green gate proving something else.
mk_po() {
  rm -rf "$PO" "$HD"; mkdir -p "$PO/tasks" "$PO/claims" "$PO/released" "$PO/$ME/inbox" || return 2
  : > "$PO/BOARD.md"; : > "$PO/QUEUE.done.tsv"; printf "TRIO\n" > "$PO/MODE"
  { printf '# gate fixture queue\n'; for t in t-two t-heredoc t-unterm t-green t-prose t-receipt t-two-contracts t-stale-ph t-dup-contract; do printf '2\t%s\tunassigned\tFREE\n' "$t"; done; } > "$PO/QUEUE.tsv"
  for t in t-two t-heredoc t-unterm t-green t-prose t-receipt t-two-contracts t-stale-ph t-dup-contract; do
    { printf '# TASK %s\nGOAL: gate fixture.\n' "$t"
      case "$t" in
        t-two)     printf 'DONE-WHEN: test -f "$S4E_HOME/harness/scripts/s4e_msg.sh" \\\n'
                   printf '  && test -f /no-such-file-donewhen-whole-criterion-gate\n';;
        t-heredoc) printf "DONE-WHEN: cat > %s <<'HEOF'\n" "$HD"
                   printf 'hello-from-the-heredoc-body\nHEOF\n'
                   printf 'grep -q hello-from-the-heredoc-body %s || exit 3\n' "$HD"
                   printf 'test -f /no-such-file-donewhen-whole-criterion-gate || exit 1\n';;
        t-unterm)  printf "DONE-WHEN: cat > %s <<'HEOF'\n" "$W/unterm.txt"
                   printf 'a body whose delimiter never arrives\n';;
        t-green)   printf "DONE-WHEN: cat > %s.g <<'GEOF'\n" "$HD"
                   printf 'green-body\nGEOF\n'
                   printf 'grep -q green-body %s.g\n' "$HD";;
        t-two-contracts) printf 'DONE-WHEN: test -f "$S4E_HOME/harness/scripts/s4e_msg.sh"\n'
                   printf 'LINKS: none\nDONE-WHEN: test -f /no-such-file-donewhen-whole-criterion-gate\n';;
        t-dup-contract) printf 'DONE-WHEN: test -f "$S4E_HOME/harness/scripts/s4e_msg.sh"\n'
                   printf 'LINKS: none\nDONE-WHEN: test -f "$S4E_HOME/harness/scripts/s4e_msg.sh"\n';;
        t-stale-ph) printf 'DONE-WHEN: test -f "$S4E_HOME/harness/scripts/s4e_msg.sh"\n'
                   printf 'LINKS: none\nDONE-WHEN: ⛔ MUST BE MADE RUNNABLE BEFORE done CAN EVER PASS — minted with no executable acceptance test\n';;
        t-receipt) printf 'DONE-WHEN: test -f "$S4E_HOME/harness/scripts/s4e_msg.sh"\n'
                   printf '  ⛔ rewritten by the cto on claim 2026-09-17: the minted line hardcoded /home/claude_icon/SCRIP\n'
                   printf '  and graded whichever tree that seat happened to hold. Cured to $S4E_HOME.\n';;
        t-prose)   printf 'DONE-WHEN: test -f "$S4E_HOME/harness/scripts/s4e_msg.sh"\n'
                   printf '⛔ **DONE-WHEN REWRITTEN 2026-08-24 (seat04):** the line above used to be prose\n'
                   printf '(readable as a spec), but `done` runs it as literal `bash -c` and prose is not a command.\n';;
      esac
      printf 'LINKS: none\n## NEXT\n(none)\n## LEDGER\n'; } > "$PO/tasks/$t.task.md"
    S4E_POST="$PO" S4E_SEAT="$ME" S4E_HOME="$ROOT" S4E_NO_BANNER=1 bash "$MSG" claim "$t" >/dev/null 2>&1 || return 2
    [ "$(head -1 "$PO/claims/$t.claim")" = "$ME" ] || return 2
  done
}
RC=0
run() { S4E_POST="$PO" S4E_SEAT="$ME" S4E_HOME="$ROOT" S4E_NO_BANNER=1 bash "$1" done "$2" >"$W/out" 2>&1; RC=$?; }
say() { grep -m3 -E '⛔|NOT DONE|REFUSED|✅' "$W/out" | sed 's/^/      | /' || tail -3 "$W/out" | sed 's/^/      | /'; }
closed() { grep -q '^DONE$' "$PO/claims/$1.claim" 2>/dev/null; }
arm() {   # arm <label> <script> -> 0 iff all four contracts hold; 2 iff the fixture broke
  local lbl="$1" s="$2" ok=1
  mk_po || return 2
  run "$s" t-two
  [ "$RC" = 1 ] || { echo "  [$lbl] (A) two-line criterion whose SECOND line exits 1 returned $RC (want 1 -- measured red)"; say; ok=0; }
  closed t-two && { echo "  [$lbl] (A) ⛔ the row CLOSED -- the second line never ran"; ok=0; }
  run "$s" t-heredoc
  [ "$RC" = 1 ] || { echo "  [$lbl] (B) heredoc criterion returned $RC (want 1 -- measured red after the body ran)"; say; ok=0; }
  [ -s "$HD" ] || { echo "  [$lbl] (B) ⛔ the heredoc body did not reach the file -- the opener ran alone"; ok=0; }
  closed t-heredoc && { echo "  [$lbl] (B) ⛔ the row CLOSED on a criterion whose real check exits 1"; ok=0; }
  run "$s" t-unterm
  [ "$RC" = 2 ] || { echo "  [$lbl] (C) unterminated heredoc returned $RC (want 2 -- could not measure)"; say; ok=0; }
  closed t-unterm && { echo "  [$lbl] (C) ⛔ the row CLOSED on a criterion bash could not finish reading"; ok=0; }
  run "$s" t-green
  [ "$RC" = 0 ] || { echo "  [$lbl] (D) a genuinely green multi-line criterion returned $RC (want 0)"; say; ok=0; }
  closed t-green || { echo "  [$lbl] (D) ⛔ a green criterion did NOT close its row -- the cure stopped closing anything"; ok=0; }
  run "$s" t-two-contracts
  [ "$RC" = 2 ] || { echo "  [$lbl] (F) a baton with a SECOND real DONE-WHEN: returned $RC (want 2 -- refuse, do not guess which is the contract)"; say; ok=0; }
  closed t-two-contracts && { echo "  [$lbl] (F) ⛔ the row CLOSED on half its own contract"; ok=0; }
  run "$s" t-stale-ph
  [ "$RC" = 0 ] || { echo "  [$lbl] (G) a real criterion under a leftover MINT PLACEHOLDER line returned $RC (want 0) -- untidy is not ambiguous"; say; ok=0; }
  closed t-stale-ph || { echo "  [$lbl] (G) ⛔ a row with only a stale placeholder beneath it stopped closing"; ok=0; }
  run "$s" t-dup-contract
  [ "$RC" = 0 ] || { echo "  [$lbl] (H) a second DONE-WHEN: BYTE-IDENTICAL to the first returned $RC (want 0) -- identical text asks no intent question"; say; ok=0; }
  closed t-dup-contract || { echo "  [$lbl] (H) ⛔ a row whose duplicate line says exactly what the first says stopped closing -- refused for a cosmetic reason"; ok=0; }
  run "$s" t-prose
  [ "$RC" = 0 ] || { echo "  [$lbl] (E) a COMPLETE one-line criterion followed by prose annotation returned $RC (want 0) -- the annotation was swallowed into the command"; say; ok=0; }
  closed t-prose || { echo "  [$lbl] (E) ⛔ a correctly-closing annotated row stopped closing -- the continuation rule is eating prose"; ok=0; }
  # ---- ARM I: A CURE RECEIPT IS ANNOTATION AND MUST NEVER LEAVE THE EXTRACTOR (coo 2026-09-23, on the cto's
  # ruling). The live convention records a cure IN the annotation -- "the minted line hardcoded
  # /home/claude_icon/SCRIP" -- so any consumer that reads the field BLOCK instead of the executed text sees a
  # seat root that the shell never runs. util_donewhen_rc_census.py's class B is exactly such a consumer, and
  # the widening that landed this week would have called that receipt a defect and REWRITTEN IT: a false
  # clearance minted on top of the evidence that the pin was already cured. Two contracts, not one -- the row
  # closes green AND the extracted text does not contain the root.
  run "$s" t-receipt
  [ "$RC" = 0 ] || { echo "  [$lbl] (I) a criterion under a CURE RECEIPT annotation returned $RC (want 0)"; say; ok=0; }
  closed t-receipt || { echo "  [$lbl] (I) ⛔ a row annotated with its own cure receipt stopped closing"; ok=0; }
  _rx="$( ( . "$(dirname "$s")/lib_donewhen.sh" >/dev/null 2>&1 && s4e_donewhen_text "$PO/tasks/t-receipt.task.md" ) 2>/dev/null )"
  case "$_rx" in
    *"/home/claude_icon"*) echo "  [$lbl] (I) ⛔ THE RECEIPT REACHED THE CONSUMER: the extractor handed back annotation text naming a seat root"; ok=0;;
    "") echo "  [$lbl] (I) ⛔ the extractor returned NOTHING for t-receipt -- it is not readable from its lib"; ok=0;;
  esac
  [ "$ok" = 1 ]
}
echo "s4e done: the WHOLE DONE-WHEN runs, a heredoc body reaches its file, an unterminated one REFUSES (scratch postoffice under $W)"
if arm PASS "$MSG"; then echo "  [PASS] (A) continuation runs; (B) heredoc body runs; (C) unterminated -> rc=2, row open; (D) green multi-line closes; (E) annotated one-liner unaffected; (F) two real contracts refuse; (G) a stale placeholder does not; (H) nor does a byte-identical duplicate; (I) a cure-receipt annotation closes green and never reaches a consumer"; pass=1
else pass=$?; [ "$pass" = 2 ] && { echo "⛔ REFUSED: fixture could not be built (rc=2)"; exit 2; }; pass=0; fi
# FAIL-ONCE, one mutant per part of the cure. M1 restores the head -1 truncation (A and B must red -- the rows
# close on criteria that never ran). M2 removes the unterminated-heredoc refusal (C must red -- rc=0 on an unreadable
# one). M3 removes the ambiguous-contract refusal (F must red -- a row closes on half its own contract).
# ⛔⭐⭐ A MUTANT IS A WHOLE SCRIPT DIRECTORY NOW, NOT A LONE FILE, and the reason is a landing: the DONE-WHEN
# EXTRACTOR MOVED OUT OF THE BUS INTO lib_donewhen.sh (cto's ruling, 2026-09-23 -- one implementation, no second
# reader to drift). A mutant written to $W/mN.sh resolves `dirname "${BASH_SOURCE[0]}"` to $W, so it would find
# NO lib beside it; the bus used to warn and carry on, and now REFUSES rc=2 because the missing function is the
# extractor itself. ⛔ M2's target string moved with it, so M2 must mutate THE LIB and leave the bus alone --
# patching $MSG for it would silently produce an IDENTICAL script and a mutant that cannot red is a green arm
# proving nothing. Each mutant therefore gets its own directory holding every lib the bus sources.
mut_dir() {   # $1 = mutant name -> builds $W/$1 with the real libs beside it; prints nothing, rc 2 on failure
  mkdir -p "$W/$1" || return 2
  cp "$HERE"/lib_*.sh "$W/$1/" || return 2
}
for m in m1 m2 m3 m4; do mut_dir "$m" || { echo "⛔ REFUSED: could not stage mutant dir $m"; exit 2; }; done
sed 's|dw="$(s4e_donewhen_text "$tf")"|dw="$(sed -n '"'"'s/^DONE-WHEN:[[:space:]]*//p'"'"' "$tf" \| head -1)"|' "$MSG" > "$W/m1/s4e_msg.sh"
cp "$MSG" "$W/m2/s4e_msg.sh"
sed 's/here-document\.\*delimited by end-of-file/a-warning-string-that-never-appears-90124/' "$HERE/lib_donewhen.sh" > "$W/m2/lib_donewhen.sh"
# M3 removes the ambiguous-contract refusal: arm F must then CLOSE a row on half its own contract.
sed 's/^s4e_donewhen_multiple_contracts() {   # \$1 = baton path/s4e_donewhen_multiple_contracts() { return 1; } \nunused_multiple_contracts() {/' "$MSG" > "$W/m3/s4e_msg.sh"
grep -q 'head -1' "$W/m1/s4e_msg.sh" || { echo "⛔ REFUSED: could not build mutant M1 (the done-site extraction moved?)"; exit 2; }
grep -q 'never-appears-90124' "$W/m2/lib_donewhen.sh" || { echo "⛔ REFUSED: could not build mutant M2 (the heredoc guard moved out of lib_donewhen.sh?)"; exit 2; }
cmp -s "$MSG" "$W/m2/s4e_msg.sh" || { echo "⛔ REFUSED: M2 must leave the bus byte-identical -- it mutates the LIB"; exit 2; }
grep -q 'unused_multiple_contracts' "$W/m3/s4e_msg.sh" || { echo "⛔ REFUSED: could not build mutant M3 (the ambiguous-contract guard moved?)"; exit 2; }
# M4 removes ONLY the byte-identical exclusion, leaving the rest of F intact: arm H must then refuse a row that
# asks no intent question. ⛔ It is a separate mutant from M3 on purpose -- M3 deletes the whole guard, so it can
# never show that the narrow exclusion is load-bearing, and a cure whose own arm no mutant reds is untested.
sed 's/txt == ENVIRON\["_DWM_FIRST"\]/txt == "no-such-first-90126"/' "$MSG" > "$W/m4/s4e_msg.sh"
grep -q 'no-such-first-90126' "$W/m4/s4e_msg.sh" || { echo "⛔ REFUSED: could not build mutant M4 (the identical-duplicate exclusion moved?)"; exit 2; }
red=1
for m in m1 m2 m3 m4; do
  if arm "FAIL-ONCE:$m" "$W/$m/s4e_msg.sh" >"$W/fo.$m" 2>&1; then echo "  [FAIL-ONCE:$m] ⛔ STAYED GREEN with that half of the cure removed -- it cannot detect the defect it exists for"; red=0
  else echo "  [FAIL-ONCE:$m] red as required: $(grep -m1 '  \[' "$W/fo.$m" | sed 's/^ *//' | cut -c1-110)"; fi
done
if [ "$pass" = 1 ] && [ "$red" = 1 ]; then echo "✅ GATE OK: done runs the whole criterion, heredoc bodies included, and refuses one it cannot finish reading."; exit 0; fi
echo "⛔ GATE FAILED (pass=$pass fail-once-red=$red)"; exit 1
