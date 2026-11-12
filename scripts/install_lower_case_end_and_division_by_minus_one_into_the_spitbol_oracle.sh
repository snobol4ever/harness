#!/usr/bin/env bash
# install_lower_case_end_and_division_by_minus_one_into_the_spitbol_oracle.sh -- TWO cures in the SNOBOL4 correctness oracle, one
# swap, under the ORACLE-SWAP PROCEDURE (RULES.md section Oracles). SUPERSEDES install_division_by_minus_one_into_the_spitbol_oracle.sh,
# which was never run: both patches sit on fork commit 9a70e79, and one swap carries both.
# (1) Lon 2026-10-03, in-chat to the ceo, verbatim: "So fix the SPITBOL oracle to accept END as upper-case, and end as lower-case." and
#     "Ensure that SCRIP only accepts upper-case END." (ceo CEO-1452). Under -f the end statement was found only by the predefined
#     variable END (v_end); sbl.min gains a second system-label block v_enl spelled end beside it, and the label scan (cmp07) accepts
#     either, so a program ending in end runs and :(end) ends it; End stays an ordinary label; a VARIABLE named end is unchanged
#     (end = 5 still assigns). SCRIP keeps accepting only END -- a ruled divergence, so a vendored CSNOBOL4 program ending in end runs
#     under the oracle (the 32 the corpus holds were made END at corpus 733e90de3 anyway).
# (2) Lon 2026-10-02: "Have lowest intger also so - 1 will do overflow." (ceo CEO-1445). With m = -9223372036854775807 - 1, m / -1 and
#     REMDR(m, -1) killed sbl with SIGFPE (int.dcl's do_dvi and do_rmi tested only a zero divisor before idiv): a divisor of -1 now
#     negates (ERROR 14 on the smallest integer) or leaves remainder 0, as SCRIP already answers.
# WHY LON RUNS IT: every write under /home/resources is refused to the ceo seat by the harness classifier (Modify Shared Resources).
# Run it as:   ! bash .github/scripts/install_lower_case_end_and_division_by_minus_one_into_the_spitbol_oracle.sh   (--dry-run stops after step 3)
# WHAT IT DOES, and nothing else:
#   1 refuses unless the fork is clean at 9a70e79 with the installed bin/sbl md5 5bd72ede..., the binary the ceo measured against;
#   2 copies the fork to a temp dir, applies the patch below (sbl.min 8 lines, int.dcl 15 lines), rebuilds, and refuses unless the build's
#     md5 is the one the ceo built twice (cac7dec6...): the build is deterministic;
#   3 runs the end witnesses and the division witnesses on the new build and refuses unless they print the measured answers;
#   4 installs: a UTC-stamped backup bin/sbl.bak-<stamp>, then the new binary by atomic rename (a grader already running keeps the old one);
#   5 commits sbl.min, int.dcl and bin/sbl in the fork and pushes; appends one paragraph to ORACLES.md (insertion only, with a .bak).
# CENSUS (the ceo, 581 corpus SNOBOL4 programs -- packages, benchmarks, demos; stdin the program's .in or /dev/null, 10 s; old against
# new): 573 identical; the other 8 are nondeterministic (timing lines, random seeds, Test2's EOF loop cut by the timeout).
# Exit: 0 done · 1 a step failed after the install began · 2 REFUSED, nothing installed.
set -u
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
FORK=${FORK:-/home/resources/x64}
ORACLES=${ORACLES:-/home/resources/ORACLES.md}
BASE=9a70e79
OLDMD5=5bd72edef3b4f23e123c474e2428e76e
NEWMD5=cac7dec6e2db82e6ee82f0281446f044
refuse() { echo "⛔ REFUSE(rc=2): $*  -- nothing installed"; exit 2; }
fail()   { echo "⛔ FAIL(rc=1): $*"; exit 1; }
[ -d "$FORK/.git" ] || refuse "no git repo at $FORK"
[ "$(git -C "$FORK" rev-parse --short=7 HEAD)" = "$BASE" ] || refuse "the fork is not at $BASE (ORD and pipes) -- the patch was cut against it"
[ -z "$(git -C "$FORK" status --porcelain -- sbl.min int.dcl bin/sbl)" ] || refuse "sbl.min, int.dcl or bin/sbl is modified in the fork"
[ "$(md5sum "$FORK/bin/sbl" | cut -d' ' -f1)" = "$OLDMD5" ] || refuse "the installed bin/sbl is not $OLDMD5, the binary the ceo measured against"
T="$(mktemp -d)" || refuse "no tmpdir"; trap 'rm -rf "$T"' EXIT
cp -a "$FORK/." "$T/x64" || refuse "cannot copy the fork"
cat > "$T/both.patch" <<'PATCH'
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
diff --git a/sbl.min b/sbl.min
index b2ca593..48e0e2f 100644
--- a/sbl.min
+++ b/sbl.min
@@ -6825,6 +6825,11 @@ v_end  dbc  svlbl            end
        dac  3
        dtc  /END/
        dac  l_end
+
+v_enl  dbc  svlbl            end in lower case (lon 2026-10-03: end and END are both the end statement)
+       dac  3
+       dtc  /end/
+       dac  l_end
 .if    .cmth
 
 v_exp  dbc  svfnp            exp
@@ -19290,11 +19295,12 @@ cmp07  mov  scnpt,wa         save updated scan offset
        ppm                   dummy (impossible) error return
        mov  cmlbl(xs),xr     store label pointer
        bnz  vrlen(xr),cmp11  jump if not system label
-       bne  vrsvp(xr),=v_end,cmp11 jump if not end label
+       beq  vrsvp(xr),=v_end,cmp7e jump if end label
+       bne  vrsvp(xr),=v_enl,cmp11 jump if not end label in lower case
 
 *      here for end label scanned out
 
-       add  stage,=stgnd     adjust stage appropriately
+cmp7e  add  stage,=stgnd     adjust stage appropriately
        jsr  scane            scan out next element
        beq  xl,=t_smc,cmp10  jump if end of image
        bne  xl,=t_var,cmp08  else error if not variable
PATCH
(cd "$T/x64" && patch -p1 --quiet < "$T/both.patch") || refuse "the patch does not apply to $BASE"
(cd "$T/x64" && make -B sbl > "$T/build.log" 2>&1) || refuse "the build failed: $(tail -3 "$T/build.log")"
have=$(md5sum "$T/x64/sbl" | cut -d' ' -f1)
[ "$have" = "$NEWMD5" ] || refuse "the build's md5 is $have, not the $NEWMD5 the ceo built and measured"
r() { printf "$1" > "$T/w.sno"; (cd "$T" && timeout 10 "$T/x64/sbl" -bf w.sno </dev/null 2>&1 | grep -v '^$' | grep -iv 'spitbol vers\|x86-64\|page ' | head -2 | tr '\n' ' '); }
got="$(r "        OUTPUT = 'one'      :(end)\n        OUTPUT = 'never'\nend\n")|$(r "        OUTPUT = 'upper'\nEND\n")|$(r "        end = 5\n        OUTPUT = 'var ' end\nEND\n")|$(r "        OUTPUT = 'x'\nEnd\n" | cut -c1-24)"
[ "$got" = "one |upper |var 5 |No END statement found i" ] || refuse "the new build does not read end as the end statement as measured: $got"
w() { printf "        &ERRLIMIT = 100\n        SETEXIT('err')\n        m = -9223372036854775807 - 1\n        k = -1\n        OUTPUT = 'value ' (%s)       :(END)\nerr     OUTPUT = 'ERROR ' &ERRTYPE\nEND\n" "$1" > "$T/w.sno"; (cd "$T" && timeout 10 "$T/x64/sbl" -bf w.sno </dev/null 2>&1 | tr '\n' ' '); }
got="$(w 'm / -1')|$(w 'REMDR(m, -1)')|$(w 'm / k')|$(w '7 / -1')|$(w 'REMDR(7, -1)')|$(w 'm / 0')|$(w 'REMDR(m, 0)')|$(w '-7 / 2')"
[ "$got" = "ERROR 14 |value 0 |ERROR 14 |value -7 |value 0 |ERROR 14 |ERROR 167 |value -3 " ] || refuse "the new build does not print the measured division answers: $got"
echo "✅ built and measured: md5 $NEWMD5; end and :(end) end the program, END unchanged, End refused; m / -1 ERROR 14, REMDR(m, -1) 0"
[ $DRY = 1 ] && { echo "dry run: nothing installed"; exit 0; }
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
cp -p "$FORK/bin/sbl" "$FORK/bin/sbl.bak-$STAMP" || refuse "cannot write the dated backup"
cp "$T/x64/sbl" "$FORK/bin/sbl.new-$STAMP" && chmod 755 "$FORK/bin/sbl.new-$STAMP" && mv -f "$FORK/bin/sbl.new-$STAMP" "$FORK/bin/sbl" || fail "the swap did not complete -- restore with: cp -p $FORK/bin/sbl.bak-$STAMP $FORK/bin/sbl"
[ "$(md5sum "$FORK/bin/sbl" | cut -d' ' -f1)" = "$NEWMD5" ] || fail "the installed binary is not $NEWMD5 -- restore with: cp -p $FORK/bin/sbl.bak-$STAMP $FORK/bin/sbl"
echo "✅ swapped at $STAMP: $FORK/bin/sbl is $NEWMD5; the previous binary is $FORK/bin/sbl.bak-$STAMP"
cp "$T/x64/sbl.min" "$FORK/sbl.min" && cp "$T/x64/int.dcl" "$FORK/int.dcl" || fail "sbl.min or int.dcl was not copied"
git -C "$FORK" add sbl.min int.dcl bin/sbl && git -C "$FORK" commit -q -F - <<'MSG' || fail "the fork commit failed (the swap stands)"
end in lower case is the end statement beside END; division and REMDR by -1 no longer die of SIGFPE on the smallest integer

Lon 2026-10-03, in-chat to the ceo: "So fix the SPITBOL oracle to accept END as upper-case, and end as lower-case." (ceo CEO-1452)
Under -f the end statement was found only through the predefined variable END (v_end). A second system-label block v_enl,
spelled end, sits beside it and the label scan at cmp07 accepts either: a program ending in end runs, :(end) ends it, End
stays an ordinary label, and a variable named end is unchanged. SCRIP keeps accepting only END (Lon's word the same hour).
Lon 2026-10-02: "Have lowest intger also so - 1 will do overflow." (ceo CEO-1445)
With m = -9223372036854775807 - 1, m / -1 and REMDR(m, -1) killed sbl with SIGFPE: int.dcl's do_dvi and do_rmi tested only
a zero divisor before idiv. A divisor of -1 now negates in do_dvi (OF on the smallest integer -> ERROR 14) and leaves
remainder 0 in do_rmi, as SCRIP already answers.
Census: old vs new over 581 corpus SNOBOL4 programs: 573 identical, 8 nondeterministic (timing, random seeds, an EOF loop).
MSG
git -C "$FORK" push -q origin HEAD:main || fail "the push failed (the swap and the commit stand; push by hand)"
cp -p "$ORACLES" "$ORACLES.bak-$STAMP" && printf '\nLon, in-chat to the ceo 2026-10-03, verbatim: *"So fix the SPITBOL oracle to accept END as upper-case, and end as lower-case."* and 2026-10-02: *"Have lowest intger also so - 1 will do overflow."* `/home/resources/x64/bin/sbl` is the build of x64 fork commit `%s` since %s; the previous binary is `/home/resources/x64/bin/sbl.bak-%s`. WHAT CHANGED: (1) a statement labelled `end` (lower case) is the end statement beside `END`, and `:(end)` ends the program; `End` stays an ordinary label and a variable named `end` is unchanged -- SCRIP accepts only `END`, a ruled divergence (CEO-1452); (2) integer division and REMDR by -1 no longer kill sbl with SIGFPE on the smallest integer: `m / -1` is ERROR 14 and `REMDR(m, -1)` is 0 (CEO-1445); nothing else. CENSUS (the ceo, 581 corpus SNOBOL4 programs): 573 identical; 8 nondeterministic. A live-oracle SNOBOL4 board stamped before %s is not compared with one stamped after it; the stamp travels on the row.\n' "$(git -C "$FORK" rev-parse --short=7 HEAD)" "$STAMP" "$STAMP" "$STAMP" >> "$ORACLES" || fail "ORACLES.md was not appended (the swap, commit and push stand)"
echo "✅ fork commit $(git -C "$FORK" rev-parse --short=7 HEAD) pushed; ORACLES.md appended (backup $ORACLES.bak-$STAMP)"
echo "Tell the ceo: lower-case end and division by -1 swapped at $STAMP."
exit 0
