#!/usr/bin/env bash
# install_division_by_minus_one_into_the_spitbol_oracle.sh -- the SNOBOL4 correctness oracle stops dying of SIGFPE on the
# smallest integer divided by -1, under the ORACLE-SWAP PROCEDURE (RULES.md section Oracles: when the oracle is broken we stop and fix it).
# Lon 2026-10-02, in-chat to the ceo, building the SCRIPtix program's variables: "Have lowest intger also so - 1 will do overflow." With
# m = -9223372036854775807 - 1, every overflow agrees between sbl and SCRIP (m - 1 ERROR 34, -m 11, m * -1 28, n + 1 3) EXCEPT that
# m / -1 and REMDR(m, -1) kill sbl with SIGFPE (rc 136; CSNOBOL4 dies the same way): int.dcl's do_dvi and do_rmi test only for a zero
# divisor before idiv, and x86 idiv faults (#DE) when the quotient overflows. sbl.min's own design wants an overflow there -- s_rmd checks
# iov after rmi (ERROR 167) and division iov is ERROR 14 -- so the cure is one test before each idiv: a divisor of -1 negates (do_dvi;
# neg sets OF exactly for the smallest integer, so m / -1 is ERROR 14) or leaves remainder 0 (do_rmi; exact for every integer, no
# overflow). SCRIP already answers ERROR 14 and 0, so after this swap the two agree on every case.
#
# WHY LON RUNS IT: every write under /home/resources is refused to the ceo seat by the harness classifier (Modify Shared Resources).
# Run it as:   ! bash .github/scripts/install_division_by_minus_one_into_the_spitbol_oracle.sh       (--dry-run stops after step 3)
#
# WHAT IT DOES, and nothing else:
#   1 refuses unless the fork is clean at 9a70e79 (ORD and pipes) with the installed bin/sbl md5 5bd72ede..., the binary the ceo measured;
#   2 copies the fork to a temp dir, applies the 15 lines of int.dcl below, rebuilds, and refuses unless the build's md5 is the one the
#     ceo built twice (9285c385...): the build is deterministic;
#   3 runs the division witness on the new build and refuses unless it prints the measured answers;
#   4 installs: a UTC-stamped backup bin/sbl.bak-<stamp>, then the new binary by atomic rename (a grader already running keeps the old one);
#   5 commits int.dcl and bin/sbl in the fork and pushes; appends one paragraph to ORACLES.md (insertion only, with a .bak).
# CENSUS (the ceo, 581 corpus SNOBOL4 programs -- packages, benchmarks, demos; stdin the program's .in or /dev/null, 10 s; old against
# new): 574 identical; the other 7 (gimpel timegc_driver, timer_driver, poker_driver, snoflake recursive-yz-pattern, gimpel-day-of-week,
# gimpel-random-poem, x64 gcbuster) differ old against old too, or match on a rerun -- timing, the clock, random seeds.
# Exit: 0 done · 1 a step failed after the install began · 2 REFUSED, nothing installed.
set -u
[ "${CEO_1452_ALLOW:-}" = 1 ] || { echo "⛔ REFUSE(rc=2): superseded by install_lower_case_end_and_division_by_minus_one_into_the_spitbol_oracle.sh, which carries this patch too -- run that one"; exit 2; }
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
FORK=${FORK:-/home/resources/x64}
ORACLES=${ORACLES:-/home/resources/ORACLES.md}
BASE=9a70e79
OLDMD5=5bd72edef3b4f23e123c474e2428e76e
NEWMD5=9285c385275f5a797b8d92e67b356bd6
refuse() { echo "⛔ REFUSE(rc=2): $*  -- nothing installed"; exit 2; }
fail()   { echo "⛔ FAIL(rc=1): $*"; exit 1; }
[ -d "$FORK/.git" ] || refuse "no git repo at $FORK"
[ "$(git -C "$FORK" rev-parse --short=7 HEAD)" = "$BASE" ] || refuse "the fork is not at $BASE (ORD and pipes) -- the patch was cut against it"
[ -z "$(git -C "$FORK" status --porcelain -- int.dcl bin/sbl)" ] || refuse "int.dcl or bin/sbl is modified in the fork"
[ "$(md5sum "$FORK/bin/sbl" | cut -d' ' -f1)" = "$OLDMD5" ] || refuse "the installed bin/sbl is not $OLDMD5, the binary the ceo measured against"
T="$(mktemp -d)" || refuse "no tmpdir"; trap 'rm -rf "$T"' EXIT
cp -a "$FORK/." "$T/x64" || refuse "cannot copy the fork"
cat > "$T/div.patch" <<'PATCH'
diff --git a/int.dcl b/int.dcl
index de14957..21a6416 100644
--- a/int.dcl
+++ b/int.dcl
@@ -211,6 +211,15 @@ mxcsr       dd      0       ; used to test mxcsr exceptions
 do_dvi:
     test    r10,r10         ; check for divide by zero
     jz      do_dvi_over     ; set overflow
+    cmp     r10,-1          ; idiv traps on the smallest integer over -1
+    jne     do_dvi_idiv
+    mov     w0,ia
+    neg     w0              ; the quotient is the negation, OF set when ia is the smallest integer
+    jo      do_dvi_over     ; set overflow
+    mov     ia,w0
+    xor     w0,w0
+    ret
+do_dvi_idiv:
     mov     w0,ia
     cdq
     idiv    r10
@@ -228,6 +237,12 @@ do_dvi_over:
 do_rmi:
     test    r10,r10         ; check for divide by zero
     jz      do_rmi_over     ; set overflow
+    cmp     r10,-1          ; idiv traps on the smallest integer over -1
+    jne     do_rmi_idiv
+    xor     ia,ia           ; every integer over -1 leaves remainder 0
+    xor     w0,w0
+    ret
+do_rmi_idiv:
     mov     w0,ia
     cdq
     idiv    r10
PATCH
(cd "$T/x64" && patch -p1 --quiet < "$T/div.patch") || refuse "the int.dcl patch does not apply to $BASE"
(cd "$T/x64" && make -B sbl > "$T/build.log" 2>&1) || refuse "the build failed: $(tail -3 "$T/build.log")"
have=$(md5sum "$T/x64/sbl" | cut -d' ' -f1)
[ "$have" = "$NEWMD5" ] || refuse "the build's md5 is $have, not the $NEWMD5 the ceo built and measured"
w() { printf "        &ERRLIMIT = 100\n        SETEXIT('err')\n        m = -9223372036854775807 - 1\n        k = -1\n        OUTPUT = 'value ' (%s)       :(END)\nerr     OUTPUT = 'ERROR ' &ERRTYPE\nEND\n" "$1" > "$T/w.sno"; (cd "$T" && timeout 10 "$T/x64/sbl" -bf w.sno </dev/null 2>&1 | tr '\n' ' '); }
got="$(w 'm / -1')|$(w 'REMDR(m, -1)')|$(w 'm / k')|$(w '7 / -1')|$(w 'REMDR(7, -1)')|$(w 'm / 0')|$(w 'REMDR(m, 0)')|$(w '-7 / 2')"
[ "$got" = "ERROR 14 |value 0 |ERROR 14 |value -7 |value 0 |ERROR 14 |ERROR 167 |value -3 " ] || refuse "the new build does not print the measured division answers: $got"
echo "✅ built and measured: md5 $NEWMD5, m / -1 ERROR 14, REMDR(m, -1) 0, the zero divisor and the ordinary cases unchanged"
[ $DRY = 1 ] && { echo "dry run: nothing installed"; exit 0; }
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
cp -p "$FORK/bin/sbl" "$FORK/bin/sbl.bak-$STAMP" || refuse "cannot write the dated backup"
cp "$T/x64/sbl" "$FORK/bin/sbl.new-$STAMP" && chmod 755 "$FORK/bin/sbl.new-$STAMP" && mv -f "$FORK/bin/sbl.new-$STAMP" "$FORK/bin/sbl" || fail "the swap did not complete -- restore with: cp -p $FORK/bin/sbl.bak-$STAMP $FORK/bin/sbl"
[ "$(md5sum "$FORK/bin/sbl" | cut -d' ' -f1)" = "$NEWMD5" ] || fail "the installed binary is not $NEWMD5 -- restore with: cp -p $FORK/bin/sbl.bak-$STAMP $FORK/bin/sbl"
echo "✅ swapped at $STAMP: $FORK/bin/sbl is $NEWMD5; the previous binary is $FORK/bin/sbl.bak-$STAMP"
cp "$T/x64/int.dcl" "$FORK/int.dcl" || fail "int.dcl was not copied"
git -C "$FORK" add int.dcl bin/sbl && git -C "$FORK" commit -q -F - <<'MSG' || fail "the fork commit failed (the swap stands)"
Division and REMDR by -1 no longer die of SIGFPE on the smallest integer: do_dvi negates, do_rmi leaves 0

Lon 2026-10-02, in-chat to the ceo: "Have lowest intger also so - 1 will do overflow." (ceo CEO-1445)
With m = -9223372036854775807 - 1, m / -1 and REMDR(m, -1) killed sbl with SIGFPE (rc 136): do_dvi and do_rmi tested only
for a zero divisor before idiv, and x86 idiv faults when the quotient overflows. A divisor of -1 now negates in do_dvi (neg
sets OF exactly for the smallest integer, so m / -1 is ERROR 14, as sbl.min's iov wants) and leaves remainder 0 in do_rmi
(exact for every integer). Witness: m / -1 ERROR 14, REMDR(m, -1) 0, 7 / -1 -7, m / 0 ERROR 14, REMDR(m, 0) ERROR 167.
Census: old vs new over 581 corpus SNOBOL4 programs: 574 identical, 7 differ old vs old too or match on a rerun.
MSG
git -C "$FORK" push -q origin HEAD:main || fail "the push failed (the swap and the commit stand; push by hand)"
cp -p "$ORACLES" "$ORACLES.bak-$STAMP" && printf '\nLon, in-chat to the ceo 2026-10-02, verbatim: *"Have lowest intger also so - 1 will do overflow."* `/home/resources/x64/bin/sbl` is the build of x64 fork commit `%s` since %s; the previous binary is `/home/resources/x64/bin/sbl.bak-%s`. WHAT CHANGED: integer division and REMDR by -1 no longer kill sbl with SIGFPE when the dividend is the smallest integer (int.dcl do_dvi/do_rmi tested only a zero divisor before idiv): m / -1 is ERROR 14 and REMDR(m, -1) is 0; nothing else. WITNESS: m = -9223372036854775807 - 1; OUTPUT = m / -1 -- old binary SIGFPE rc 136, new ERROR 14 under SETEXIT. CENSUS (the ceo, 581 corpus SNOBOL4 programs): 574 identical; 7 differ old-vs-old too or match on a rerun. A live-oracle SNOBOL4 board stamped before %s is not compared with one stamped after it; the stamp travels on the row.\n' "$(git -C "$FORK" rev-parse --short=7 HEAD)" "$STAMP" "$STAMP" "$STAMP" >> "$ORACLES" || fail "ORACLES.md was not appended (the swap, commit and push stand)"
echo "✅ fork commit $(git -C "$FORK" rev-parse --short=7 HEAD) pushed; ORACLES.md appended (backup $ORACLES.bak-$STAMP)"
echo "Tell the ceo: division by -1 swapped at $STAMP."
exit 0
