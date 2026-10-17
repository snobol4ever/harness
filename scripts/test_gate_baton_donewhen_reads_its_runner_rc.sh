#!/usr/bin/env bash
# test_gate_baton_donewhen_reads_its_runner_rc.sh -- hq_B 2026-09-13.
# GATE: no live baton DONE-WHEN may (A) capture a runner's output without being able to tell that runner's
# REFUSAL from its RED, or (B) pin a SEAT ROOT in the text the bus actually runs -- as an ${S4E_HOME:-...}
# fallback OR BARE (`cd /home/claude_ceo/SCRIP && ...`), which grades whichever tree that seat happens to
# hold instead of origin HEAD. Class B's bare half is coo 2026-09-23 (CEO-1163, RULES.md THE INSTRUMENT
# LAWS thirty-fourth batch clause 3: a criterion that names a seat root names a tree). MEASURED AT THAT
# LANDING: 46 defective, and 28 of them pin a root that HAS NOT EXISTED SINCE CEO-767 -- so they grade no
# tree at all, and `rung-gate-false-green-audit` is a PROVEN FALSE GREEN because its `! grep -qi ... 
# /home/claude10/.github/FINDING-...md` inverts grep's rc=2-on-a-missing-file into rc=0 DONE.
# Both classes come from the ceo's own audit: FINDING-2026-09-11-ceo-a-done-when-that-captures-a-board-turns-
# could-not-measure-into-failed.md. Under ONE RUNNER, ONE BOARD a runner answers any seat but the coo with
# rc=2; a criterion that greps the captured TEXT and never looks at the rc turns that refusal into rc=1
# FAILED -- so precisely the rows that most need auditing cannot be audited by hand by anyone but the coo.
# ⛔ THE CENSUS IS NOT IN THIS FILE. It is util_donewhen_rc_census.py, the one authority, so that the gate and
# the cure can never drift apart -- the four-copies-of-one-extractor defect lib_donewhen.sh was written to end.
# --self-test PROVES THE GATE RED rather than asserting it, and proves the CLASS behaviourally: it stands up a
# stub runner that exits 2 the way a real runner refuses, runs a criterion of the bad shape and of the cured
# shape against it, and shows the bad one answering rc=1 FAILED where the cured one answers rc=2 REFUSE.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CENSUS="$HERE/util_donewhen_rc_census.py"
[ -f "$CENSUS" ] || { echo "⛔ REFUSE(2): $CENSUS missing -- cannot measure"; exit 2; }
if [ "${1:-}" = "--self-test" ]; then
    T="$(mktemp -d)" || exit 2; trap 'rm -rf "$T"' EXIT
    mkdir -p "$T/tasks" "$T/scripts"
    # a runner that REFUSES the way ONE RUNNER, ONE BOARD makes every runner refuse a non-coo seat
    printf '#!/usr/bin/env bash\necho "⛔ REFUSE(2): seat hq_B is not the coo -- ONE RUNNER, ONE BOARD"\nexit 2\n' \
        > "$T/scripts/board_stub.sh"; chmod +x "$T/scripts/board_stub.sh"
    BAD_PLAIN='out=$(bash '"$T"'/scripts/board_stub.sh 2>&1); printf "%s" "$out" | grep -q "^STUB_BOARD ok"'
    BAD_PIPED='out=$(bash '"$T"'/scripts/board_stub.sh 2>&1 | tail -1); printf "%s" "$out" | grep -q "^STUB_BOARD ok"'
    CURED_PLAIN='{ out=$(bash '"$T"'/scripts/board_stub.sh 2>&1); _dwrc=$?; if [ "$_dwrc" = 2 ]; then echo "REFUSE(2): the runner could not measure (rc=2) -- this is not a red"; exit 2; fi; [ "$_dwrc" = 0 ]; } && printf "%s" "$out" | grep -q "^STUB_BOARD ok"'
    HONEST='out=$(bash '"$T"'/scripts/board_stub.sh 2>&1); printf "%s" "$out" | grep -q "^STUB_BOARD " || { echo "REFUSE(2): runner printed no STUB_BOARD line"; exit 2; }; printf "%s" "$out" | grep -q "ok"'
    fail=0
    # ---- ARM 1: the behavioural witness. This is what makes the class real rather than asserted.
    bash -c "$BAD_PLAIN"  >/dev/null 2>&1; rb=$?
    bash -c "$BAD_PIPED"  >/dev/null 2>&1; rp=$?
    bash -c "$CURED_PLAIN">/dev/null 2>&1; rc_=$?
    bash -c "$HONEST"     >/dev/null 2>&1; rh=$?
    echo "SELF-TEST arm 1 (behaviour against a runner that exits 2):"
    echo "   bad  plain criterion -> rc=$rb   (expect 1: a REFUSAL read as a RED)"
    echo "   bad  piped criterion -> rc=$rp   (expect 1: same, and rc=\$? here would read the pipe)"
    echo "   cured      criterion -> rc=$rc_   (expect 2: the refusal propagates)"
    echo "   honest     criterion -> rc=$rh   (expect 2: marker absent, refuses without ever reading rc)"
    [ "$rb" = 1 ] && [ "$rp" = 1 ] && [ "$rc_" = 2 ] && [ "$rh" = 2 ] || { echo "⛔ arm 1 FAILED"; fail=1; }
    # ---- ARM 2: the census must SEE each shape, and must not call the honest one defective.
    mk() { printf '# TASK %s\nGOAL: self-test fixture\nDONE-WHEN: %s\n## NEXT\nx\n' "$1" "$2" > "$T/tasks/$1.task.md"; }
    mk selftest_bad_plain  "$BAD_PLAIN"
    mk selftest_bad_piped  "$BAD_PIPED"
    mk selftest_cured      "$CURED_PLAIN"
    mk selftest_honest     "$HONEST"
    mk selftest_classb     'R="${S4E_HOME:-/home/claude_cfo}"; [ -x "$R/SCRIP/scrip" ] || exit 2'
    # ---- the BARE half and, more importantly, its NEGATIVE CONTROLS. Each of the four below was a real
    # false positive the whole-block reader produced on the live tree on 2026-09-23, not an invented case.
    mk selftest_bare       'cd /home/claude_ceo/SCRIP && test -f scrip'
    mk selftest_bare_dead  'bash /home/claude16/harness/scripts/test_gate_x.sh'
    mk selftest_bare_cmt   'test -f scrip   # audited by hand from /home/claude_coo on 2026-09-01'
    mk selftest_bare_subj  'for r in /home/claude03 /home/claude04; do [ -r "$r/CLAUDE.md" ] || continue; grep -q X "$r/CLAUDE.md" || exit 1; done'
    # ⛔ THE SELF-MATCH CONTROL. This census's OWN detector spelling is a string that LOOKS like a seat root
    # and is not one; a reader that matched it would make every row about seat-root pins unclosable BY ITS
    # OWN EXISTENCE. Pinned here rather than left to the luck of the next character.
    mk selftest_bare_regex 'n=$(grep -lE "^DONE-WHEN:.*/home/claude_[A-Za-z0-9_]+" /home/resources/postoffice/tasks/*.task.md | wc -l); [ "$n" = 0 ]'
    # an ANNOTATION line under a COMPLETE first line is prose the bus never runs (s4e_field_criterion_text)
    printf '# TASK %s\nGOAL: self-test fixture\nDONE-WHEN: test -f scrip\n  (rewritten 2026-09-01: the line above used to read cd /home/claude_T/SCRIP)\n## NEXT\nx\n' \
        selftest_bare_annot > "$T/tasks/selftest_bare_annot.task.md"
    out="$(S4E_TASKS="$T/tasks" python3 "$CENSUS" 2>&1)"; crc=$?
    echo "SELF-TEST arm 2 (the census over 11 crafted fixtures), rc=$crc:"; printf '%s\n' "$out" | sed 's/^/   /'
    printf '%s' "$out" | grep -q "defective (captures a runner, cannot tell a refusal from a red): 2" || { echo "⛔ arm 2: expected exactly 2 defective"; fail=1; }
    printf '%s' "$out" | grep -q "pipe: 1\]" || { echo "⛔ arm 2: expected exactly 1 piped"; fail=1; }
    printf '%s' "$out" | grep -q "absent): 1" || { echo "⛔ arm 2: expected exactly 1 honest (the cured one checks rc, so it is neither)"; fail=1; }
    printf '%s' "$out" | grep -q "fallback or bare): 3$" || { echo "⛔ arm 2: expected exactly 3 class B defective (1 fallback + 2 bare), count LAST on the line"; fail=1; }
    printf '%s' "$out" | grep -q "of those 3: bare 2, fallback 1, pinning a root that NO LONGER EXISTS 1" || { echo "⛔ arm 2: expected bare=2 fallback=1 dead=1"; fail=1; }
    # ⛔ THE LIVE CRITERION'S OWN PARSE IS AN ARM, not an assumption: exactly one line may match `^ +CLASS B `
    # or the row's diagnostic reports two numbers, and the green test must be able to MATCH at zero.
    [ "$(printf '%s\n' "$out" | grep -cE '^ +CLASS B ')" = 1 ] || { echo "⛔ arm 2: exactly one line may match the criterion's ^ +CLASS B  anchor"; fail=1; }
    printf '%s' "$out" | grep -q "B-SUBJECT.*the roots ARE the question):     1" || { echo "⛔ arm 2: expected exactly 1 class B subject"; fail=1; }
    [ "$crc" = 1 ] || { echo "⛔ arm 2: census must exit 1 when it finds defects (got $crc)"; fail=1; }
    # ---- ARM 2b: THE NEGATIVE CONTROLS ARE NAMED, not merely absent from a count. A count of 3 is also
    # what a reader that saw the comment and missed a real pin would print.
    lst="$(S4E_TASKS="$T/tasks" python3 "$CENSUS" --list 2>&1)"
    for good in selftest_bare selftest_bare_dead selftest_classb; do
        printf '%s' "$lst" | grep -qE "^ +B +$good\b" || { echo "⛔ arm 2b: $good must be listed as class B"; fail=1; }; done
    for bad in selftest_bare_cmt selftest_bare_annot selftest_bare_regex; do
        printf '%s' "$lst" | grep -qE "^ +B +$bad\b" && { echo "⛔ arm 2b: $bad is NOT a defect and must not be listed"; fail=1; }; done
    printf '%s' "$lst" | grep -qE "^ +B\|subj +selftest_bare_subj\b" || { echo "⛔ arm 2b: the roster sweep must be listed as a subject"; fail=1; }
    echo "SELF-TEST arm 2b (negative controls named, not merely uncounted): ok"
    # ---- ARM 2c: FAIL-ONCE. Restore the pre-widening reader and REQUIRE the bare arms to go red, so a
    # future edit that quietly narrows the detector cannot leave this gate printing green.
    fo="$(S4E_DWRC_FAIL_ONCE=1 S4E_TASKS="$T/tasks" python3 "$CENSUS" 2>&1)"
    if printf '%s' "$fo" | grep -q "fallback or bare): 1$"; then
        echo "SELF-TEST arm 2c (FAIL_ONCE: the narrow reader misses both bare pins): ok"
    else echo "⛔ arm 2c: FAIL_ONCE did not restore the narrow reader -- the bare arm is not load-bearing"; fail=1; fi
    # ---- ARM 2d: THE CURE IS PROVEN ON A COPY, both directions. Red once over the fixtures, green once
    # after --cure, and the three non-defects BYTE-IDENTICAL afterwards (a cure that edits a cure receipt
    # or a comment is this row's own lesson inverted).
    cp -a "$T/tasks" "$T/tasks_cure"
    S4E_TASKS="$T/tasks_cure" python3 "$CENSUS" --cure >/dev/null 2>&1
    S4E_TASKS="$T/tasks_cure" python3 "$CENSUS" >/dev/null 2>&1; acrc=$?
    d2fail=0
    { [ "$acrc" = 0 ] && S4E_TASKS="$T/tasks_cure" python3 "$CENSUS" 2>&1 | grep -q "fallback or bare): 0"; } \
        || { echo "⛔ arm 2d: the census must read class B 0 and exit 0 after --cure (rc=$acrc)"; fail=1; d2fail=1; }
    # the row's OWN green test, run verbatim against the cured output -- the only proof that a zero is readable
    S4E_TASKS="$T/tasks_cure" python3 "$CENSUS" 2>&1 | grep -qE "^ +CLASS B .*: +0$" \
        || { echo "⛔ arm 2d: the DONE-WHEN's green test ^ +CLASS B .*: +0\$ cannot match a cured census"; fail=1; d2fail=1; }
    for keep in selftest_bare_cmt selftest_bare_annot selftest_bare_regex selftest_bare_subj; do
        cmp -s "$T/tasks/$keep.task.md" "$T/tasks_cure/$keep.task.md" \
            || { echo "⛔ arm 2d: --cure REWROTE $keep, which is not a defect"; fail=1; d2fail=1; }; done
    # ⛔ THE SUBSTITUTION IS LOCAL AND KEEPS THE AUTHOR'S QUOTING: `cd /home/claude_ceo/SCRIP` becomes
    # `cd ${S4E_HOME:-$PWD}/SCRIP`, unquoted exactly as it was found. A cure that also re-quotes is editing
    # shell it was not asked to edit, and the diff stops being reviewable.
    grep -qF 'cd ${S4E_HOME:-$PWD}/SCRIP && test -f scrip' "$T/tasks_cure/selftest_bare.task.md" \
        || { echo "⛔ arm 2d: the cured bare pin does not read \${S4E_HOME:-\$PWD} in place"; fail=1; d2fail=1; }
    [ "$d2fail" = 0 ] && echo "SELF-TEST arm 2d (--cure proven on a COPY: red once, green once, non-defects untouched): ok"
    # ---- ARM 3: the census must REFUSE, never print 0, when it cannot see its population.
    S4E_TASKS="$T/nowhere" python3 "$CENSUS" >/dev/null 2>&1
    [ $? = 2 ] || { echo "⛔ arm 3: census must exit 2 on an unreachable tasks dir"; fail=1; }
    echo "SELF-TEST arm 3 (unreachable population refuses rc=2): ok"
    # ---- ARM 4: THE TWO READERS MUST AGREE ON THE LIVE TREE. The census reads the executed span with its
    # OWN copy of s4e_msg.sh's rule (first line, whole block only when that line is incomplete shell); a
    # second reader of a rule that lives in another file goes stale SILENTLY, which is the four-copies
    # defect lib_donewhen.sh was written to end. This arm re-derives both readings over every live baton
    # that mentions a seat root anywhere in its DONE-WHEN block and REDS on any disagreement, so the
    # divergence announces itself instead of being discovered by a wrong close.
    mkdir -p "$T/po/coo/inbox" "$T/po/tasks" "$T/po/claims"
    printf 'DECTET\n' > "$T/po/MODE"; printf '# index\n' > "$T/po/QUEUE.tsv"
    bus_seen="$(S4E_POST="$T/po" S4E_SEAT=coo S4E_NO_BANNER=1 bash -c '
        . '"$HERE"'/s4e_msg.sh >/dev/null 2>&1
        for b in /home/resources/postoffice/tasks/*.task.md; do
          t="$(s4e_donewhen_text "$b" 2>/dev/null)"
          printf "%s" "$t" | sed -E "s/\\\$\{S4E_HOME:-[^}]*\}//g" \
            | grep -qE "/home/claude(_[A-Za-z0-9]+|[0-9]{2})" && basename "$b" .task.md
        done' 2>/dev/null | sort)"
    if [ -z "$bus_seen" ]; then
        echo "⛔ arm 4: could not read the bus extractor at all -- not a green"; fail=1
    else
        cen_seen="$(python3 "$CENSUS" --json 2>/dev/null | python3 -c 'import json,sys
d=json.load(sys.stdin)
for k in ("B","B_subject"):
    for x in d[k]: print(x["baton"])' | sort -u)"
        only_bus="$(comm -23 <(printf '%s\n' "$bus_seen") <(printf '%s\n' "$cen_seen"))"
        only_cen="$(comm -13 <(printf '%s\n' "$bus_seen") <(printf '%s\n' "$cen_seen"))"
        # the census EXEMPTS a root that sits in a shell COMMENT; the crude bus-side grep above cannot see
        # comments, so bus-only names are re-checked for exactly that and are not a disagreement.
        real_dis=""
        for n in $only_bus; do
          hit="$(S4E_POST="$T/po" S4E_SEAT=coo S4E_NO_BANNER=1 bash -c '
            . '"$HERE"'/s4e_msg.sh >/dev/null 2>&1
            s4e_donewhen_text "/home/resources/postoffice/tasks/'"$n"'.task.md" 2>/dev/null' 2>/dev/null \
            | sed -E 's/#.*$//' | grep -cE '/home/claude(_[A-Za-z0-9]+|[0-9]{2})')"
          [ "${hit:-0}" -gt 0 ] && real_dis="$real_dis $n"
        done
        if [ -n "$real_dis" ] || [ -n "$only_cen" ]; then
            echo "⛔ arm 4: THE TWO READERS DISAGREE -- bus-only:$real_dis  census-only: $(printf '%s' "$only_cen" | tr '\n' ' ')"; fail=1
        else
            echo "SELF-TEST arm 4 (census reader == s4e_msg.sh reader over $(printf '%s\n' "$bus_seen" | grep -c . ) live candidates): ok"
        fi
    fi
    [ "$fail" = 0 ] && { echo "✅ SELF-TEST GREEN: the gate proves red against a criterion of each bad shape."; exit 0; }
    echo "⛔ SELF-TEST FAILED"; exit 1
fi
out="$(python3 "$CENSUS" --list 2>&1)"; rc=$?
printf '%s\n' "$out"
case "$rc" in
  2) echo "⛔ REFUSE(2): the census could not measure its population -- not a red"; exit 2 ;;
  0) echo "✅ GATE GREEN: every baton DONE-WHEN can tell a runner's refusal from its red, and none pins a seat root in the text the bus runs."; exit 0 ;;
  *) echo "⛔ GATE RED: the classes above are open. Cure with: python3 ../harness/scripts/util_donewhen_rc_census.py --cure"; exit 1 ;;
esac
