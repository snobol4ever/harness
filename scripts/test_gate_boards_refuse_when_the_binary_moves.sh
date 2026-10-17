#!/usr/bin/env bash
# test_gate_boards_refuse_when_the_binary_moves.sh -- A BOARD THAT STRADDLES A BINARY SWAP MUST REFUSE rc=2
# BEFORE IT PUBLISHES A NUMBER (ceo CEO-524 (1), to the coo as THE ONE RUNNER, 2026-09-10).
#
# THE WITNESS: hq_R's board straddled a binary swap and wrote m3 635/759 into SCORE.md WITH A CLEAN STAMP,
# while the correct 756/759 from the same sitting was refused as dirty. The dirty guard reads the tree at
# WRITE time; it has nothing to say about the window the board spent grading. Half a population on one build
# and half on another prints A COMPLETE, PLAUSIBLE TABLE -- this house's own recurring shape, an instrument
# that cannot fail printing exactly like one that passed.
#
# ⛔⭐ AND THE CURE ALREADY EXISTED. gate_bin_watch/gate_bin_unmoved have been in lib_gate.sh since
# 2026-09-06, hoisted by hq_S out of test_corpus_snobol4.sh after hq_S rebuilt under a live 1854-entry board.
# Census the day this gate was written: FIVE boards, ZERO callers of gate_bin_watch. Diagnosed, cured,
# hoisted, documented -- and wired to nothing. ⭐ THAT IS WHAT THIS GATE IS ACTUALLY DEFENDING: not the
# existence of the check, which nobody was ever going to delete, but the WIRING, which nobody had ever added.
#
#   ARM 1  the four boards MODE line 2 gives the one runner, plus the donor, each carry BOTH calls
#   ARM 2  ORDERING: the first gate_bin_unmoved precedes the first line that publishes a count. A refusal
#          that fires after the row is published is an annotation, not a refusal (the same lesson
#          test_gate_progress_rows_carry_the_start_fingerprint.sh was written for -- seat10's runner refused
#          at 14:23 a board whose 3736 rows the harness had already appended).
#   ARM 3  the authority REFUSES rc=2 when a watched artifact's bytes change, and names both fingerprints
#   ARM 4  CONTROL: it passes when nothing moves -- without this, arm 3 is satisfied by a check that always refuses
#   ARM 5  it refuses when a watched artifact is DELETED mid-run (the moved case in its loudest form)
#   ARM 6  it refuses AT WATCH TIME when the artifacts cannot be fingerprinted at all, so a board with no
#          baseline discovers that at the start rather than after paying for the whole run
#   ARM 7  PUBLICATION IS PREVENTED, NOT ANNOTATED: a stub board wired the sanctioned way exits 2 and its
#          board line NEVER REACHES STDOUT. This is the arm that grades the defect class rather than the call.
#   ARM 8  the RATCHET, with a printed denominator: over every board-shaped script in ../harness/scripts/, the number
#          carrying the guard may never fall below the floor pinned here. A new board without it lands red
#          here rather than in the next false row.
#   ARM 9  ONE COPY: no board re-spells the fingerprint rule privately (the donor's own copy was retired
#          onto the library in the landing this gate accompanies).
#   ARM 10 THE TREE PAIR, same three conditions asked of gate_tree_watch/gate_tree_unmoved. ⛔ A SECOND
#          GUARD AND NOT A SECOND SPELLING OF THE FIRST: gate_bin_watch answers "did the BINARY move" and is
#          SILENT AND CORRECT when the corpus moves under a board. The coo's own witness, 2026-09-10 18:42 --
#          a pass recorded one corpus hash and a background job moved corpus eight seconds later, and nothing
#          in the fleet asked. A board grading half its population against one corpus and half against another
#          prints a complete, plausible table.
#   ARM 11 the tree authority REFUSES on a moved HEAD, on UNCOMMITTED state that leaves HEAD alone (the
#          likelier accident on a seat root), and PASSES when neither moved -- with the stamp exported.
#   ARM 12 ONE SPELLING OF THE STAMP: no runner hand-writes `export S4E_TREE_AT_START`. It was written out in
#          three runners and ABSENT from the three Icon package boards, so three of four boards the one runner
#          runs stamped HEAD AT WRITE TIME -- CEO-524 (1)'s defect in its second form.
#
# HERMETIC: arms 3-7 run against scratch files under mktemp and never touch this tree's scrip, out/ or
# SCORE.md. Arms 1-2 and 8-9 are static reads. NO BUILD REQUIRED -- this gate grades wiring and a library
# function, not codegen, so it must not refuse on a stale binary it never executes.
# EXIT: 0 all arms · 1 an arm failed · 2 REFUSED (could not measure).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE_NAME="test_gate_boards_refuse_when_the_binary_moves"; export GATE_NAME
. "$HERE/lib_gate.sh" 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE rc=2 [$GATE_NAME]: lib_gate.sh unloadable"; exit 2; }
for _fn in gate_bin_watch gate_bin_unmoved gate_file_has_bin_watch_guard gate_tree_watch gate_tree_unmoved gate_file_has_tree_watch_guard gate_verdict gate_floor; do
    command -v "$_fn" >/dev/null 2>&1 || { echo "⛔ REFUSED-TO-GRADE rc=2 [$GATE_NAME]: lib_gate.sh carries no $_fn -- the rule under test is unreachable"; exit 2; }
done

# ⛔ THE ONE RUNNER'S BOARDS ARE NAMED, NOT GLOBBED. MODE line 2 (Lon 2026-09-10 16:3x, "one runner and one
# board") gives the coo exactly these four, and the fifth is the donor the library function came out of. A
# glob here would silently change what this gate asserts every time somebody adds a board_*.sh; the growing
# population is ARM 8's job, and it is a ratchet precisely so the two questions stay separate.
BOARDS=(test_icon_jcon_suite.sh test_icon_arizona_suite.sh test_icon_ipl_suite.sh board_icon_rungs.sh test_corpus_snobol4.sh)

fails=0; examined=0
red() { echo "  ⛔ $*"; fails=$((fails+1)); }
ok()  { echo "  ok    $*"; }

echo "── ARM 1-2: the one runner's boards carry the guard, and it precedes publication ──"
for b in "${BOARDS[@]}"; do
    f="$HERE/$b"
    [ -f "$f" ] || { echo "⛔ REFUSED-TO-GRADE rc=2 [$GATE_NAME]: named board missing: $b -- a renamed board must be renamed HERE too, never dropped"; exit 2; }
    examined=$((examined+1))
    gate_file_has_bin_watch_guard "$f"; rc=$?
    case "$rc" in
        0) ok "$b carries gate_bin_watch and gate_bin_unmoved, and the check precedes the first published count" ;;
        1) red "$b: no start/end binary fingerprint, or gate_bin_unmoved comes AFTER the first line that publishes a count -- this board can print a table graded on two builds" ;;
        *) echo "⛔ REFUSED-TO-GRADE rc=2 [$GATE_NAME]: could not read $b"; exit 2 ;;
    esac
done

W="$(mktemp -d "${TMPDIR:-/tmp}/gate_bin_moved.XXXXXX")" || { echo "⛔ REFUSED-TO-GRADE rc=2 [$GATE_NAME]: mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
printf 'AAAA' > "$W/a.bin"; printf 'BBBB' > "$W/b.so"

# ⛔ EACH ARM RUNS IN ITS OWN SUBSHELL because gate_bin_watch/gate_bin_unmoved `exit` on refusal -- that is
# their contract (a board must not be able to continue past one) and it is exactly why they cannot be probed
# in-process. The subshell's rc IS the measurement.
echo "── ARM 7 (MID-RUN REBUILD): the harness refuses when the binary is rebuilt under it, printing no board and recording no rows ──"
# (coo 2026-09-16; hq_raku's RakRungs 764/927 graded across a mid-run make; ceo CEO-802; row instruments-a-board-does-not-refuse-when-its-
# own-seat-rebuilds-the-binary-under-it-...). A 300-entry cut of the SNOBOL4 rungs under mktemp (several seconds of m3 grading); the harness runs against a SCRATCH COPY of ./scrip and out/ (SCRIP= and RT_DIR=) with the progress DB redirected; 0.6 s in,
# while the busy loop still runs, the scratch binary is mutated (a byte appended: same program, new fingerprint) -- the board must end in
# THE BINARY MOVED UNDER THIS BOARD, rc=2, no SUITE_BOARD, zero rows in the scratch DB. FAIL_ONCE=1 skips the mutation. (The verdict
# lines are printed after the board, so a poll for them cannot mark mid-run; the busy loop is what holds the run open.)
M="$HERE/../../corpus/tests/snobol4"; W7="$W/midrun"; mkdir -p "$W7/tests/snobol4" "$W7/out"
if [ -f "$M/ALL.sno" ] && [ -x "$HERE/../../SCRIP/scrip" ] && [ -f "$HERE/../../SCRIP/out/libscrip_rt.so" ]; then
    head -300 "$M/ALL.sno" > "$W7/tests/snobol4/ALL.sno"; head -300 "$M/ALL.ref" > "$W7/tests/snobol4/ALL.ref"   # ~300 entries in m3: several seconds of grading after the baseline is stated
    cp "$HERE/../../SCRIP/scrip" "$W7/scrip"; cp -L "$HERE/../../SCRIP/out/libscrip_rt.so" "$W7/out/libscrip_rt.so"; chmod +x "$W7/scrip"
    printf 'ts_utc\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome\tsecs\tnote\n' > "$W7/db.tsv"
    ( cd "$HERE/../../SCRIP" && env -u S4E_BIN_AT_START PYTHONUNBUFFERED=1 SCRIP="$W7/scrip" RT_DIR="$W7/out" S4E_PROGRESS_DB="$W7/db.tsv" timeout -k 5 300 python3 ../harness/scripts/corpus_suite_harness.py run "$W7/tests/snobol4/ALL.sno" "$W7/tests/snobol4/ALL.ref" --modes m3 > "$W7/out.txt" 2> "$W7/err.txt"; echo $? > "$W7/rc" ) &
    _p7=$!; _i=0
    # wait for the harness to STATE its baseline (BINARY_AT_START, printed after its startup work), then mutate while the busy loop runs
    while [ $_i -lt 1200 ] && ! grep -q '^BINARY_AT_START ' "$W7/out.txt" 2>/dev/null && kill -0 $_p7 2>/dev/null; do sleep 0.05; _i=$((_i+1)); done
    sleep 1
    if kill -0 $_p7 2>/dev/null; then
        # a rebuild REPLACES the file (the linker writes a new inode and renames it in) -- an in-place append is refused by the kernel
        # while the old binary executes ("text file busy"), so the mutation is a modified copy renamed over the original, as make does
        if [ -z "${FAIL_ONCE:-}" ]; then cp "$W7/scrip" "$W7/scrip.new"; printf '\n' >> "$W7/scrip.new"; chmod +x "$W7/scrip.new"; mv -f "$W7/scrip.new" "$W7/scrip"; fi
        wait $_p7; rc7="$(cat "$W7/rc" 2>/dev/null || echo ?)"
        rows7="$(( $(grep -c . "$W7/db.tsv") - 1 ))"
        if [ "$rc7" = 2 ] && grep -q 'THE BINARY MOVED UNDER THIS BOARD' "$W7/err.txt" && ! grep -q '^SUITE_BOARD ' "$W7/out.txt" && [ "$rows7" -eq 0 ]; then
            ok "ARM 7 MID-RUN: the scratch binary was rebuilt under the harness one second after it stated its baseline; it refused rc=2 naming both fingerprints, printed no SUITE_BOARD and recorded 0 rows"
        else red "ARM 7 MID-RUN: rc=$rc7 board=$(grep -c '^SUITE_BOARD ' "$W7/out.txt") rows=$rows7 -- $(grep -m1 'MOVED\|REFUSE' "$W7/err.txt" | cut -c1-140)"; fi
        examined=$((examined+1))
    else
        wait $_p7; red "ARM 7 MID-RUN: the harness finished within a second of stating its baseline, so nothing could be rebuilt under it -- the 300-entry cut did not hold the run open (rc=$(cat "$W7/rc" 2>/dev/null)); a fixture that cannot reproduce the defect proves nothing"
    fi
else
    echo "  ----  ARM 7 MID-RUN [UNBUILDABLE: no rungs at $M, no ./scrip or no out/libscrip_rt.so]"
fi
echo "── ARM 3-6: the authority itself ──"
out3="$( ( . "$HERE/lib_gate.sh"; GATE_NAME=probe gate_bin_watch "$W/a.bin" "$W/b.so"; printf 'CCCC' > "$W/a.bin"; GATE_NAME=probe gate_bin_unmoved; echo "PUBLISHED" ) 2>&1 )"; rc3=$?
if [ "$rc3" -eq 2 ] && grep -q 'THE BINARY MOVED UNDER THIS BOARD' <<<"$out3" && ! grep -q 'PUBLISHED' <<<"$out3"; then
    ok "ARM 3 a changed artifact refuses rc=2 and names both fingerprints: $(grep -o 'start \[[^]]*\] end \[[^]]*\]' <<<"$out3" | head -1)"
else red "ARM 3 a changed artifact did not refuse: rc=$rc3 out=$(head -2 <<<"$out3")"; fi
examined=$((examined+1))

printf 'AAAA' > "$W/a.bin"
out4="$( ( . "$HERE/lib_gate.sh"; GATE_NAME=probe gate_bin_watch "$W/a.bin" "$W/b.so"; GATE_NAME=probe gate_bin_unmoved; echo "PUBLISHED" ) 2>&1 )"; rc4=$?
if [ "$rc4" -eq 0 ] && grep -q 'PUBLISHED' <<<"$out4"; then ok "ARM 4 CONTROL: an unmoved pair passes and the board publishes"
else red "ARM 4 CONTROL failed -- a guard that always refuses would satisfy ARM 3: rc=$rc4 out=$(head -2 <<<"$out4")"; fi
examined=$((examined+1))

out5="$( ( . "$HERE/lib_gate.sh"; GATE_NAME=probe gate_bin_watch "$W/a.bin" "$W/b.so"; rm -f "$W/b.so"; GATE_NAME=probe gate_bin_unmoved; echo "PUBLISHED" ) 2>&1 )"; rc5=$?
if [ "$rc5" -eq 2 ] && ! grep -q 'PUBLISHED' <<<"$out5"; then ok "ARM 5 a DELETED artifact refuses rc=2 (the moved case in its loudest form)"
else red "ARM 5 a deleted artifact did not refuse: rc=$rc5 out=$(head -2 <<<"$out5")"; fi
examined=$((examined+1))
printf 'BBBB' > "$W/b.so"

out6="$( ( . "$HERE/lib_gate.sh"; GATE_NAME=probe gate_bin_watch "$W/nothing-here" ; echo "GRADED-ANYWAY" ) 2>&1 )"; rc6=$?
if [ "$rc6" -eq 2 ] && ! grep -q 'GRADED-ANYWAY' <<<"$out6"; then ok "ARM 6 an unfingerprintable artifact refuses AT WATCH TIME, before the run is paid for"
else red "ARM 6 watch accepted an artifact it could not fingerprint: rc=$rc6 out=$(head -2 <<<"$out6")"; fi
examined=$((examined+1))

echo "── ARM 7: publication is PREVENTED, not annotated ──"
# ⭐ THIS IS THE ARM THAT GRADES THE DEFECT CLASS. Arms 3-6 prove the check answers correctly; this one proves
# a board wired the sanctioned way cannot reach its own board line, which is the property hq_R's run lacked.
cat > "$W/stub_board.sh" <<STUB
#!/usr/bin/env bash
set -uo pipefail
. "$HERE/lib_gate.sh"
GATE_NAME=stub_board gate_bin_watch "$W/a.bin" "$W/b.so"
printf 'MOVED' > "$W/a.bin"          # somebody rebuilds while this board is grading
GATE_NAME=stub_board gate_bin_unmoved
echo "STUB_SUITE_BOARD total=759 m3_pass=635"
python3 -c "print('and here it would have written SCORE.md')"
STUB
chmod +x "$W/stub_board.sh"
out7="$(bash "$W/stub_board.sh" 2>&1)"; rc7=$?
if [ "$rc7" -eq 2 ] && ! grep -q 'STUB_SUITE_BOARD' <<<"$out7" && ! grep -q 'SCORE.md' <<<"$out7"; then
    ok "ARM 7 the stub board exited 2 and NEITHER its board line NOR its score write was reached"
else red "ARM 7 a board that straddled a swap still published: rc=$rc7 out=$(head -3 <<<"$out7")"; fi
examined=$((examined+1))

echo "── ARM 10-12: the TREE pair (did the CORPUS move under this board) ──"
for b in "${BOARDS[@]}"; do
    f="$HERE/$b"
    examined=$((examined+1))
    gate_file_has_tree_watch_guard "$f"; rc=$?
    case "$rc" in
        0) ok "$b carries gate_tree_watch and gate_tree_unmoved, and the check precedes the first published count" ;;
        1) red "$b: no start/end TREE fingerprint, or gate_tree_unmoved comes AFTER the first published count -- a corpus move under this board is invisible to it" ;;
        *) echo "⛔ REFUSED-TO-GRADE rc=2 [$GATE_NAME]: could not read $b"; exit 2 ;;
    esac
done

# ⛔ THE FIXTURE IS TWO REAL GIT REPOS named SCRIP and corpus under one scratch root, because gate_tree_watch
# asks git for HEAD and for uncommitted state and a mock would grade neither.
TR="$W/root"; mkdir -p "$TR/SCRIP" "$TR/corpus"
for r in SCRIP corpus; do
    ( cd "$TR/$r" && git init -q . && git -c user.email=lcherryh@yahoo.com -c user.name=LCherryholmes commit -q --allow-empty -m base ) >/dev/null 2>&1
done
out11a="$( ( . "$HERE/lib_gate.sh"; GATE_NAME=probe gate_tree_watch "$TR"; ( cd "$TR/corpus" && git -c user.email=lcherryh@yahoo.com -c user.name=LCherryholmes commit -q --allow-empty -m moved ); GATE_NAME=probe gate_tree_unmoved; echo "PUBLISHED" ) 2>&1 )"; rc11a=$?
if [ "$rc11a" -eq 2 ] && grep -q 'THE TREE MOVED UNDER THIS BOARD' <<<"$out11a" && ! grep -q 'PUBLISHED' <<<"$out11a"; then
    ok "ARM 11a a corpus COMMIT under the board refuses rc=2 and names both fingerprints"
else red "ARM 11a a moved corpus HEAD did not refuse: rc=$rc11a out=$(head -2 <<<"$out11a")"; fi
examined=$((examined+1))

# ⭐ THE UNCOMMITTED ARM IS THE ONE THAT MATTERS ON A SEAT ROOT: a ref edited and not committed moves the
# GRADED DATA without moving HEAD, and that is the likelier accident -- the coo hand-edited corpus refs four
# times on the day this landed. A HEAD-only fingerprint would read this as quiet.
out11b="$( ( . "$HERE/lib_gate.sh"; GATE_NAME=probe gate_tree_watch "$TR"; echo dirt > "$TR/corpus/uncommitted.txt"; GATE_NAME=probe gate_tree_unmoved; echo "PUBLISHED" ) 2>&1 )"; rc11b=$?
if [ "$rc11b" -eq 2 ] && ! grep -q 'PUBLISHED' <<<"$out11b"; then
    ok "ARM 11b UNCOMMITTED corpus state that leaves HEAD alone still refuses rc=2"
else red "ARM 11b an uncommitted corpus edit did not refuse: rc=$rc11b out=$(head -2 <<<"$out11b")"; fi
rm -f "$TR/corpus/uncommitted.txt"
examined=$((examined+1))

out11c="$( ( . "$HERE/lib_gate.sh"; GATE_NAME=probe gate_tree_watch "$TR"; GATE_NAME=probe gate_tree_unmoved; echo "PUBLISHED stamp=[$S4E_TREE_AT_START]" ) 2>&1 )"; rc11c=$?
if [ "$rc11c" -eq 0 ] && grep -q 'PUBLISHED' <<<"$out11c" && grep -qE 'stamp=\[SCRIP=[0-9a-f]+,corpus=[0-9a-f]+\]' <<<"$out11c"; then
    ok "ARM 11c CONTROL: an unmoved tree passes AND exports the stamp -- $(grep -o 'stamp=\[[^]]*\]' <<<"$out11c")"
else red "ARM 11c control failed -- a guard that always refuses would satisfy 11a/11b, and the stamp is what stops a row naming HEAD-at-write-time: rc=$rc11c out=$(head -2 <<<"$out11c")"; fi
examined=$((examined+1))

out11d="$( ( . "$HERE/lib_gate.sh"; GATE_NAME=probe gate_tree_unmoved; echo "PUBLISHED" ) 2>&1 )"; rc11d=$?
if [ "$rc11d" -eq 2 ] && ! grep -q 'PUBLISHED' <<<"$out11d"; then ok "ARM 11d unmoved without a prior watch refuses rather than answering from an empty baseline"
else red "ARM 11d answered with no baseline: rc=$rc11d"; fi
examined=$((examined+1))

echo "── ARM 12: ONE SPELLING OF THE STAMP ──"
# ⛔ lib_gate.sh IS EXCLUDED BECAUSE IT IS THE SPELLING -- gate_tree_watch exports the variable, which is the
# whole point of the arm. Convicting the authority for doing its job is how a census gets muted.
handspelt="$(grep -lE '^[[:space:]]*export S4E_TREE_AT_START=' "$HERE"/*.sh 2>/dev/null | grep -v '/lib_gate\.sh$' | xargs -r -n1 basename | tr '\n' ' ')"
if [ -z "$handspelt" ]; then ok "ARM 12 no runner hand-writes export S4E_TREE_AT_START -- gate_tree_watch is the one spelling"
else red "ARM 12 a hand-spelled stamp survives: $handspelt -- retire it onto gate_tree_watch, or the runners that lack it keep stamping HEAD at write time"; fi
examined=$((examined+1))

echo "── ARM 8: the RATCHET over every board-shaped script ──"
# ⛔ THE POPULATION IS SPELLED HERE AND ITS DENOMINATOR IS PRINTED. Board-shaped = a SUITE RUNNER or BOARD
# (test_*_suite.sh, test_corpus_*.sh, board_*.sh, raku_roast_scoreboard.sh) that publishes a count -- it echoes
# a *_BOARD line or writes a SCORE.md row. ⛔ NAME-SHAPE FIRST, THEN BEHAVIOUR, and the first draft of this arm
# had only the second half: it swept in handoff_status.sh, util_census_fpc_tests.sh, a seat-identity gate and
# six bench_* scripts, none of which grade a population, and then reported a coverage fraction over them. A
# denominator that includes things nobody will ever wire makes the ratchet unreadable in the direction that
# matters -- it can only ever go down as unrelated scripts are added.
# THE FLOOR is what was wired the day this gate landed; it may rise and may never fall. ⛔ NOT A FAIL=0 BAR:
# parked boards predate the guard, and a gate nobody can satisfy is worse than no gate (hq_P's standing ruling
# on the retired optbypass watermark). ⭐ The five the one runner actually runs are ARM 1's job and are already
# red-if-missing there; this arm exists so the SIXTH board to be wired can never quietly become unwired.
COVER_FLOOR=5
pop=0; covered=0; uncovered=""
while IFS= read -r f; do
    base="$(basename "$f")"
    case "$base" in
        test_*_suite.sh|test_corpus_*.sh|board_*.sh|raku_roast_scoreboard.sh) : ;;
        *) continue ;;
    esac
    body="$(grep -vE '^[[:space:]]*#' "$f" 2>/dev/null)" || continue
    grep -qE '_BOARD |util_score_row\.py' <<<"$body" || continue
    pop=$((pop+1))
    gate_file_has_bin_watch_guard "$f"; _b=$?; gate_file_has_tree_watch_guard "$f"; _t=$?
    if [ $_b -eq 0 ] && [ $_t -eq 0 ]; then covered=$((covered+1)); else uncovered="$uncovered $base"; fi
done < <(find "$HERE" -maxdepth 1 -name '*.sh' -type f | sort)
echo "    board-shaped scripts=$pop  carrying the guard=$covered  floor=$COVER_FLOOR"
[ "$pop" -ge 5 ] || { echo "⛔ REFUSED-TO-GRADE rc=2 [$GATE_NAME]: found only $pop board-shaped scripts -- zero-work-examined is indistinguishable from all-clean"; exit 2; }
if [ "$covered" -ge "$COVER_FLOOR" ]; then ok "ARM 8 ratchet holds: $covered of $pop board-shaped scripts carry the start/end fingerprint (floor $COVER_FLOOR)"
else red "ARM 8 RATCHET FELL: $covered of $pop carry the guard, floor is $COVER_FLOOR -- a board lost its start/end fingerprint"; fi
[ -n "$uncovered" ] && echo "    not yet wired (named, not counted as red -- raise COVER_FLOOR as these land):$uncovered"
examined=$((examined+1))

echo "── ARM 9: ONE COPY of the fingerprint rule ──"
# ⛔ THE DONOR KEPT ITS OWN COPY THROUGH THE 2026-09-06 HOIST and the fleet carried both for four days. A cure
# applied to one copy strengthens everyone's belief the class is dead while the other keeps the bug.
copies="$(grep -lE '_bin_fp\(\)|md5sum "\$SCRIP" "\$RT_DIR/libscrip_rt\.so"' "$HERE"/*.sh 2>/dev/null | grep -v '/lib_gate\.sh$' | xargs -r -n1 basename | tr '\n' ' ')"
if [ -z "$copies" ]; then ok "ARM 9 the fingerprint rule is spelled only in lib_gate.sh"
else red "ARM 9 a private copy of the fingerprint rule survives: $copies -- retire it onto gate_bin_watch/gate_bin_unmoved"; fi
examined=$((examined+1))

GATE_EXAMINED="$examined"
gate_verdict "$fails" "arm(s) failed (boards named ${#BOARDS[@]}, board-shaped population $pop, covered $covered)"
