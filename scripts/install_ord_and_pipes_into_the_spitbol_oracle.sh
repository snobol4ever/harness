#!/usr/bin/env bash
# install_ord_and_pipes_into_the_spitbol_oracle.sh -- compile ORD into our SPITBOL fork AND cure its ! command pipes, and swap
# the build in as the SNOBOL4 correctness oracle,
# under the ORACLE-SWAP PROCEDURE (RULES.md section Oracles). Lon 2026-10-02, in-chat to the ceo: "Add the ORD function." and "Finish ORD
# and test6." (ceo CEO-1415); and on the pipes: "I'm hoping we have the "!process" file I/O fake-out sub-process." and "You could use that
# instead of IPC COMM's. Better DEMO since it straight SNOBOL4 feature." (ceo CEO-1424). SUPERSEDES install_ord_into_the_spitbol_oracle_
# ceo_1415.sh, which was never run: one swap carries both changes.
# THE PIPE DEFECT (upstream 4.0f's too, measured on spitbol-pristine and the bench oracle): every INPUT/OUTPUT association whose file is
# !<delim>command reads EOF at once and writes nowhere, because the forked child dies with SIGSEGV before execl: osint/getshell.c calls
# findenv(SHELL_ENV_NAME, sizeof(SHELL_ENV_NAME)), sizeof counts the NUL, so make_c_str stores a NUL one byte past the string literal
# "SHELL", in read-only memory (gdb in the child: make_c_str <- findenv <- getshell <- doshell <- ospipe <- osopen). The cure is
# sizeof(...) - 1, which points make_c_str at the literal's own NUL, where it writes nothing. No graded corpus program opens a pipe
# (packages, tests, benchmarks, demos, include, library: 0); the 23 users are under programs/lon_cherryholmes, which no suite grades.
#
# WHY LON RUNS IT: every write under /home/resources is refused to the ceo seat by the harness classifier (Modify Shared Resources); the
# 2026-09-05 swap was a one-line ! bash for the same reason. Run it as:   ! bash .github/scripts/install_ord_and_pipes_into_the_spitbol_oracle.sh
#
# WHAT IT DOES, and nothing else:
#   1 refuses unless the fork is clean at 012d00e (SET) with the installed bin/sbl md5 ffda07f4..., the binary the ceo measured against;
#   2 copies the fork to a temp dir, applies ORD's 19 lines of sbl.min (below) and the one-line getshell.c cure, rebuilds, and refuses unless
#     the build's md5 is the one the ceo built twice and measured (5bd72ede...): the build is deterministic;
#   3 runs the ORD witness and the pipe witness on the new build and refuses unless both print the measured answers;
#   4 installs: a UTC-stamped backup bin/sbl.bak-<stamp>, then the new binary by atomic rename (a grader already running keeps the old one),
#     and the patched sbl.min;
#   5 commits sbl.min, osint/getshell.c and bin/sbl in the fork and pushes; appends one paragraph to ORACLES.md (insertion only, with a .bak).
# WHAT ORD IS: ORD(S) is the character code of S's first character, S taken as a string (an integer converts first: ORD(65) is 54), and it
# fails when S is null -- CSNOBOL4's ORD, the reference for the feature. Declared svfnn, not svfnp: a preevaluated function "must never cause
# failure", and ORD fails on null (svfnp gave ERROR 299 at compile time on ORD('')). A non-string argument is ERROR 333 "ord argument is not a
# string", the first unused number after 332.
# CENSUS (the ceo, 730 corpus SNOBOL4 programs, stdin /dev/null, 20 s, old against new): 717 identical; csnobol4_suite/ord.sno and
# snoflake_suite/csnobol4-extensions.sno change (they call ORD); the other 11 differ old against old too, or only in the post-mortem's
# execution-time line (timing, ASLR, EOF loops cut by the timeout).
# Usage: bash install_ord_and_pipes_into_the_spitbol_oracle.sh [--dry-run]     (--dry-run stops after step 3)
# Exit: 0 done · 1 a step failed after the install began · 2 REFUSED, nothing installed.
set -u
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
FORK=${FORK:-/home/resources/x64}
ORACLES=${ORACLES:-/home/resources/ORACLES.md}
BASE=012d00e
OLDMD5=ffda07f45ef31e9aacbd651d9c9a1c20
NEWMD5=5bd72edef3b4f23e123c474e2428e76e
refuse() { echo "⛔ REFUSE(rc=2): $*  -- nothing installed"; exit 2; }
fail()   { echo "⛔ FAIL(rc=1): $*"; exit 1; }
[ -d "$FORK/.git" ] || refuse "no git repo at $FORK"
[ "$(git -C "$FORK" rev-parse --short=7 HEAD)" = "$BASE" ] || refuse "the fork is not at $BASE (SET) -- the patch was cut against it"
[ -z "$(git -C "$FORK" status --porcelain -- sbl.min osint/getshell.c bin/sbl)" ] || refuse "sbl.min, osint/getshell.c or bin/sbl is modified in the fork"
[ "$(md5sum "$FORK/bin/sbl" | cut -d' ' -f1)" = "$OLDMD5" ] || refuse "the installed bin/sbl is not $OLDMD5, the binary the ceo measured against"
T="$(mktemp -d)" || refuse "no tmpdir"; trap 'rm -rf "$T"' EXIT
cp -a "$FORK/." "$T/x64" || refuse "cannot copy the fork"
cat > "$T/ord.patch" <<'PATCH'
--- a/sbl.min
+++ b/sbl.min
@@ -6879,6 +6879,12 @@
        dac  s_lne
        dac  2
 
+v_ord  dbc  svfnn            ord
+       dac  3
+       dtc  /ORD/
+       dac  s_ord
+       dac  1
+
 v_pos  dbc  svfnp            pos
        dac  3
        dtc  /POS/
@@ -15087,6 +15093,19 @@
        brn  exnul            return null string
        ejc
 
+*      ord
+
+s_ord  ent                   entry point
+       jsr  gtstg            load string argument
+       err  333,ord argument is not a string
+       bze  wa,exfal         fail if null string
+       plc  xr               point to first character
+       lch  wa,(xr)          load first character
+       zer  xr               clear character pointer
+       mti  wa               load character code as integer
+       brn  exint            exit with integer result
+       ejc
+
 *      pos
 
 s_pos  ent                   entry point
PATCH
(cd "$T/x64" && patch -p1 --quiet < "$T/ord.patch") || refuse "the ORD patch does not apply to $BASE's sbl.min"
sed -i 's/findenv(SHELL_ENV_NAME, sizeof(SHELL_ENV_NAME))/findenv(SHELL_ENV_NAME, sizeof(SHELL_ENV_NAME) - 1)/' "$T/x64/osint/getshell.c" || refuse "cannot edit getshell.c"
grep -q 'findenv(SHELL_ENV_NAME, sizeof(SHELL_ENV_NAME) - 1)' "$T/x64/osint/getshell.c" || refuse "the getshell.c cure did not apply to $BASE"
(cd "$T/x64" && make -B sbl > "$T/build.log" 2>&1) || refuse "the build failed: $(tail -3 "$T/build.log")"
have=$(md5sum "$T/x64/sbl" | cut -d' ' -f1)
[ "$have" = "$NEWMD5" ] || refuse "the build's md5 is $have, not the $NEWMD5 the ceo built and measured"
cat > "$T/w.sno" <<'SNO'
        OUTPUT = ORD('A')
        OUTPUT = ORD('AB')
        OUTPUT = ORD(CHAR(0))
        OUTPUT = ORD(CHAR(255))
        OUTPUT = ORD(65)
        X = ORD('')                     :S(BAD)
        OUTPUT = 'null fails'           :(END)
BAD     OUTPUT = 'BAD'
END
SNO
got=$(cd "$T" && timeout 10 "$T/x64/sbl" -bf w.sno </dev/null 2>&1 | tr '\n' ' ')
[ "$got" = "65 65 0 255 54 null fails " ] || refuse "the new build does not print CSNOBOL4's ORD answers: $got"
cat > "$T/p.sno" <<'SNO'
        INPUT(.FRM, 8, '!*echo hello')                 :F(NOPEN)
R       OUTPUT = 'read ' FRM                           :S(R)
        OUTPUT(.TO, 9, '!*cat > o9.txt')               :F(NOPEN)
        TO = 'line one'
        ENDFILE(9)
        INPUT(.BACK, 10, 'o9.txt')
        OUTPUT = 'back ' BACK                          :(END)
NOPEN   OUTPUT = 'a pipe did not open'
END
SNO
got=$(cd "$T" && timeout 10 "$T/x64/sbl" -bf p.sno </dev/null 2>&1 | tr '\n' ' ')
[ "$got" = "read hello back line one " ] || refuse "the new build's ! pipes do not carry data: $got"
echo "✅ built and measured: md5 $NEWMD5, ORD witness = 65 65 0 255 54 null fails, pipe witness = read hello back line one"
[ $DRY = 1 ] && { echo "dry run: nothing installed"; exit 0; }
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
cp -p "$FORK/bin/sbl" "$FORK/bin/sbl.bak-$STAMP" || refuse "cannot write the dated backup"
cp "$T/x64/sbl" "$FORK/bin/sbl.new-$STAMP" && chmod 755 "$FORK/bin/sbl.new-$STAMP" && mv -f "$FORK/bin/sbl.new-$STAMP" "$FORK/bin/sbl" || fail "the swap did not complete -- restore with: cp -p $FORK/bin/sbl.bak-$STAMP $FORK/bin/sbl"
cp "$T/x64/sbl.min" "$FORK/sbl.min" || fail "sbl.min was not copied"
[ "$(md5sum "$FORK/bin/sbl" | cut -d' ' -f1)" = "$NEWMD5" ] || fail "the installed binary is not $NEWMD5 -- restore with: cp -p $FORK/bin/sbl.bak-$STAMP $FORK/bin/sbl"
echo "✅ swapped at $STAMP: $FORK/bin/sbl is $NEWMD5; the previous binary is $FORK/bin/sbl.bak-$STAMP"
cp "$T/x64/osint/getshell.c" "$FORK/osint/getshell.c" || fail "getshell.c was not copied"
git -C "$FORK" add sbl.min osint/getshell.c bin/sbl && git -C "$FORK" commit -q -F - <<'MSG' || fail "the fork commit failed (the swap stands)"
ORD compiled in, and ! command pipes carry data again: getshell's findenv length counted the NUL

Lon 2026-10-02, in-chat to the ceo: "I'm hoping we have the "!process" file I/O fake-out sub-process." (ceo CEO-1424)
PIPES: every INPUT/OUTPUT association on !<delim>command read EOF at once and wrote nowhere, upstream 4.0f too: the forked
child died with SIGSEGV before execl, because getshell passed findenv sizeof(SHELL_ENV_NAME), which counts the NUL, and
make_c_str stored a NUL one byte past the literal "SHELL" in read-only memory. sizeof(...) - 1 points it at the literal's
own NUL, where it writes nothing. Witness: INPUT(.X, 8, '!*echo hello') reads hello; OUTPUT(.Y, 9, '!*cat > f') writes f;
a SPITBOL parent reads a SPITBOL child's answers through '!*sbl -bf eval.sno < batch'. No graded corpus program opens a pipe.

ORD(S): the character code of S's first character, S taken as a string, failing on null -- CSNOBOL4's ORD

Lon 2026-10-02, in-chat to the ceo: "Add the ORD function." and "Finish ORD and test6." (ceo CEO-1415)
v_ord in the three-character svblk list between LNE and POS, declared svfnn (fast call, NO preevaluation: a preevaluated
function must never fail, and ORD fails on null -- svfnp gave ERROR 299 at compile time on ORD('')); s_ord takes its
argument through gtstg, fails on a zero length, loads the first character, clears xr, and exits through exint.
ERROR 333 "ord argument is not a string" is the first number unused after 332.
Witness, byte-identical to csnobol4 -b: ORD('A')=65, ORD('AB')=65, ORD(CHAR(0))=0, ORD(CHAR(255))=255, ORD(CHAR(128))=128,
ORD(65)=54, ORD(1.5)=49, DATATYPE INTEGER, ORD('') fails, all 256 CHAR(I) round trips; ORD(ARRAY(1)) is ERROR 333.
Census: old vs new over 730 corpus SNOBOL4 programs (packages, benchmarks, demos, programs; stdin /dev/null, 20 s): 717 identical;
csnobol4_suite/ord.sno and snoflake_suite/csnobol4-extensions.sno change (they call ORD); 11 differ old-vs-old too or only in the
post-mortem's execution time. An unchanged rebuild reproduced the installed bin/sbl byte for byte (md5 ffda07f4) before the edit.
MSG
git -C "$FORK" push -q origin HEAD:main || fail "the push failed (the swap and the commit stand; push by hand)"
cp -p "$ORACLES" "$ORACLES.bak-$STAMP" && printf '\nLon, in-chat to the ceo 2026-10-02, verbatim: *"Add the ORD function."* and *"Finish ORD and test6."* `/home/resources/x64/bin/sbl` is the build of x64 fork commit `%s` since %s; the previous binary is `/home/resources/x64/bin/sbl.bak-%s`. WHAT CHANGED: `ORD(S)`, the character code of the first character of S taken as a string, failing on null (CSNOBOL4'"'"'s ORD), is compiled in; a non-string argument is ERROR 333; and `!`<delim>`command` pipes carry data (Lon, CEO-1424: *"I'"'"'m hoping we have the "!process" file I/O fake-out sub-process."*): the forked child no longer dies in getshell, whose findenv length counted the NUL (upstream 4.0f'"'"'s defect too); nothing else. WITNESS: `OUTPUT = ORD('"'"'AB'"'"')` -- old binary ERROR 022 undefined function called, new prints 65; `INPUT(.X, 8, '"'"'!*echo hello'"'"')` -- old reads EOF, new reads hello. CENSUS (the ceo, 730 corpus SNOBOL4 programs): 717 identical; changed only csnobol4_suite `ord.sno` and snoflake_suite `csnobol4-extensions.sno` (they call ORD); 11 differ old-vs-old too or only in the execution-time line. A live-oracle SNOBOL4 board stamped before %s is not compared with one stamped after it; the stamp travels on the row.\n' "$(git -C "$FORK" rev-parse --short=7 HEAD)" "$STAMP" "$STAMP" "$STAMP" >> "$ORACLES" || fail "ORACLES.md was not appended (the swap, commit and push stand)"
echo "✅ fork commit $(git -C "$FORK" rev-parse --short=7 HEAD) pushed; ORACLES.md appended (backup $ORACLES.bak-$STAMP)"
echo "Tell the ceo: ORD and pipes swapped at $STAMP."
exit 0
