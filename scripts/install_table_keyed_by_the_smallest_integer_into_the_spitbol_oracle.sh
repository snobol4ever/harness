#!/usr/bin/env bash
# install_table_keyed_by_the_smallest_integer_into_the_spitbol_oracle.sh -- the SNOBOL4 correctness oracle no longer dies when a
# TABLE is subscripted by the smallest integer, under the ORACLE-SWAP PROCEDURE (RULES.md section Oracles: when the oracle is broken we
# stop and fix it). Found by the ceo's millions-run of the SCRIPtix program on Lon's a..z layout, where m = -9223372036854775807 - 1 is
# a preset and a batch line (h(s) =RPOS(0)) after (s = m) assigned through t[m]: the SPITBOL child died with SIGSEGV (CEO-1461). The
# cause is sbl.min tfind: an integer key is negated to make it positive before the remainder that picks the bucket, and the most negative
# integer has no positive twin, so the bucket offset went negative and the oracle read or wrote wild. The cure hashes that one value as
# zero (tfn0a). t[m] = 1 and OUTPUT = t[m] both died before; SCRIP and CSNOBOL4 answer them.
# WHY LON RUNS IT: every write under /home/resources is refused to the ceo seat by the harness classifier (Modify Shared Resources).
# Run it as:   ! bash /home/claude_ceo/.github/scripts/install_table_keyed_by_the_smallest_integer_into_the_spitbol_oracle.sh   (--dry-run stops after step 3)
# WHAT IT DOES, and nothing else:
#   1 refuses unless the fork is clean at c545d25 (the CEO-1452 swap) with the installed bin/sbl md5 cac7dec6..., the binary the ceo measured;
#   2 copies the fork to a temp dir, applies the 10-line sbl.min patch below, rebuilds, and refuses unless the build's md5 is the one the
#     ceo built twice (fd9b552b...): the build is deterministic;
#   3 runs the table witnesses on the new build and refuses unless they print the measured answers;
#   4 installs: a UTC-stamped backup bin/sbl.bak-<stamp>, then the new binary by atomic rename (a grader already running keeps the old one);
#   5 commits sbl.min and bin/sbl in the fork and pushes; appends one paragraph to ORACLES.md (insertion only, with a .bak).
# CENSUS (the ceo, 581 corpus SNOBOL4 programs -- packages, benchmarks, demos; stdin the program's .in or /dev/null, 10 s; old against
# new): 574 identical; the other 7 differ only in timing lines, random seeds or an EOF loop cut by the timeout.
# Exit: 0 done · 1 a step failed after the install began · 2 REFUSED, nothing installed.
set -u
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
FORK=${FORK:-/home/resources/x64}
ORACLES=${ORACLES:-/home/resources/ORACLES.md}
BASE=c545d25
OLDMD5=cac7dec6e2db82e6ee82f0281446f044
NEWMD5=fd9b552baed52d06c152c167257d69e2
refuse() { echo "⛔ REFUSE(rc=2): $*  -- nothing installed"; exit 2; }
fail()   { echo "⛔ FAIL(rc=1): $*"; exit 1; }
[ -d "$FORK/.git" ] || refuse "no git repo at $FORK"
[ "$(git -C "$FORK" rev-parse --short=7 HEAD)" = "$BASE" ] || refuse "the fork is not at $BASE -- the patch was cut against it"
[ -z "$(git -C "$FORK" status --porcelain -- sbl.min bin/sbl)" ] || refuse "sbl.min or bin/sbl is modified in the fork"
[ "$(md5sum "$FORK/bin/sbl" | cut -d' ' -f1)" = "$OLDMD5" ] || refuse "the installed bin/sbl is not $OLDMD5, the binary the ceo measured against"
T="$(mktemp -d)" || refuse "no tmpdir"; trap 'rm -rf "$T"' EXIT
cp -a "$FORK/." "$T/x64" || refuse "cannot copy the fork"
cat > "$T/tbl.patch" <<'PATCH'
diff --git a/sbl.min b/sbl.min
index 48e0e2f..14a27aa 100644
--- a/sbl.min
+++ b/sbl.min
@@ -27292,7 +27292,14 @@ tfn01  mti  wa               convert to integer
 tfn02  ldi  1(xr)            load value as hash source
        ige  tfn06            ok if positive or zero
        ngi                   make positive
-       iov  tfn06            clear possible overflow
+       iov  tfn0a            most negative integer has no positive twin
+       brn  tfn06            merge
+*      here for the most negative integer: hash it as zero rather
+*      than remainder a negative value into a bucket index
+*      (lon 2026-10-03, ceo: a table keyed by the smallest integer
+*      read or wrote through a negative bucket offset and died)
+tfn0a  zer  wa               zero hash source
+       mti  wa               as integer
        brn  tfn06            merge
 
 *      for pattern, use first word (pcode) as source
PATCH
(cd "$T/x64" && patch -p1 --quiet < "$T/tbl.patch") || refuse "the patch does not apply to $BASE"
(cd "$T/x64" && make -B sbl > "$T/build.log" 2>&1) || refuse "the build failed: $(tail -3 "$T/build.log")"
have=$(md5sum "$T/x64/sbl" | cut -d' ' -f1)
[ "$have" = "$NEWMD5" ] || refuse "the build's md5 is $have, not the $NEWMD5 the ceo built and measured"
printf "        t = TABLE()\n        m = -9223372036854775807 - 1\n        t[m] = 1\n        t[0] = 2\n        OUTPUT = 'ok ' t[m] ' ' t[0] ' ' t[-5]\n        OUTPUT = 'read ' t[9223372036854775807] t[-9223372036854775807]\nEND\n" > "$T/w.sno"
got=$(cd "$T" && timeout 10 "$T/x64/sbl" -bf w.sno </dev/null 2>&1 | tr '\n' '|')
[ "$got" = "ok 1 2 |read |" ] || refuse "the new build does not answer the table witnesses as measured: $got"
echo "✅ built and measured: md5 $NEWMD5; a table keyed by the smallest integer reads and writes"
[ $DRY = 1 ] && { echo "dry run: nothing installed"; exit 0; }
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
cp -p "$FORK/bin/sbl" "$FORK/bin/sbl.bak-$STAMP" || refuse "cannot write the dated backup"
cp "$T/x64/sbl" "$FORK/bin/sbl.new-$STAMP" && chmod 755 "$FORK/bin/sbl.new-$STAMP" && mv -f "$FORK/bin/sbl.new-$STAMP" "$FORK/bin/sbl" || fail "the swap did not complete -- restore with: cp -p $FORK/bin/sbl.bak-$STAMP $FORK/bin/sbl"
[ "$(md5sum "$FORK/bin/sbl" | cut -d' ' -f1)" = "$NEWMD5" ] || fail "the installed binary is not $NEWMD5 -- restore with: cp -p $FORK/bin/sbl.bak-$STAMP $FORK/bin/sbl"
echo "✅ swapped at $STAMP: $FORK/bin/sbl is $NEWMD5; the previous binary is $FORK/bin/sbl.bak-$STAMP"
cp "$T/x64/sbl.min" "$FORK/sbl.min" || fail "sbl.min was not copied"
git -C "$FORK" add sbl.min bin/sbl && git -C "$FORK" commit -q -F - <<'MSG' || fail "the fork commit failed (the swap stands)"
A table keyed by the smallest integer no longer dies: tfind hashes the most negative integer as zero

Found by the ceo's millions-run of the SCRIPtix program on Lon's a..z layout (ceo CEO-1461): with m = -9223372036854775807 - 1
a preset, t[m] = 1 and OUTPUT = t[m] killed sbl with SIGSEGV. tfind negates an integer key to make it positive before the
remainder that picks the bucket; the most negative integer has no positive twin, so the bucket offset went negative. The one
value now hashes as zero (tfn0a); every other key is unchanged. Witness: t[m] = 1; t[0] = 2; t[m] t[0] t[-5] print 1 2 and
null, as SCRIP and CSNOBOL4 do. Census: old vs new over 581 corpus SNOBOL4 programs: 574 identical, 7 nondeterministic.
MSG
git -C "$FORK" push -q origin HEAD:main || fail "the push failed (the swap and the commit stand; push by hand)"
cp -p "$ORACLES" "$ORACLES.bak-$STAMP" && printf '\nceo CEO-1461, 2026-10-03: `/home/resources/x64/bin/sbl` is the build of x64 fork commit `%s` since %s; the previous binary is `/home/resources/x64/bin/sbl.bak-%s`. WHAT CHANGED: a TABLE subscripted by the smallest integer (-9223372036854775807 - 1) no longer kills sbl with SIGSEGV -- tfind hashes the most negative integer as zero instead of remaindering a negative value into a bucket offset; nothing else. WITNESS: t = TABLE(); m = -9223372036854775807 - 1; t[m] = 1 -- old binary SIGSEGV, new prints t[m] as 1. CENSUS (the ceo, 581 corpus SNOBOL4 programs): 574 identical; 7 nondeterministic. A live-oracle SNOBOL4 board stamped before %s is not compared with one stamped after it; the stamp travels on the row.\n' "$(git -C "$FORK" rev-parse --short=7 HEAD)" "$STAMP" "$STAMP" "$STAMP" >> "$ORACLES" || fail "ORACLES.md was not appended (the swap, commit and push stand)"
echo "✅ fork commit $(git -C "$FORK" rev-parse --short=7 HEAD) pushed; ORACLES.md appended (backup $ORACLES.bak-$STAMP)"
echo "Tell the ceo: the smallest-integer table key swapped at $STAMP."
exit 0
