#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_snobol4_list_listing_matches_sbl.sh -- THE -LIST LISTING IS SPITBOL'S LISTING, BYTE FOR BYTE, IN BOTH MODES (row
# snobol4-the-list-control-line-prints-spitbols-listing-comments-pages-and-banner-included; Lon 2026-10-03 to the ceo, CEO-1459: "We need to
# implement the -LIST feature, since statement numbers are unknown. The DEBUG.sno program depends on a listing."; the cut at the END line is
# CEO-1739: the run-time error report after it is the one error voice's, not this gate's). Every witness is run by the correctness oracle
# (sbl -bf) and by SCRIP's mode 3 and mode 4; each output drops the 'x86-64 ' banner lines and stops at the END statement line of the listing.
# WITNESSES: SourceLines001 (dotnet), hide (csnobol4_suite), debug.sno with -LIST in place of its -NOLIST, and generated probes: -TITLE -STITL
# -SPACE -EJECT -DOUBLE -SINGLE, -PRINT/-NOPRINT/-NOLIST, a comma chain, a tab-indented line, and programs of 119 and 1199 statements that cross
# the 49-53 line page boundary and the 1200 line mark. AN -INCLUDEd FILE'S IMAGES (statements, comments, control cards, continuation lines, a blank statement)
# are listed with their include depth in column 6, and the main file's statements after it keep their images (p_inc, p_inc2 nested two deep, p_inc3).
# KNOWN GAPS (not witnessed here, each its own landing): a blank statement with a whitespace-only continuation lists the continuation; -SPACE x is
# ERROR 247; includes nested past nine are ERROR 284 in sbl (SCRIP nests to 64).
# FAIL_ONCE (recorded 2026-10-14, a worktree of 2bbadd1c9^ = 539cc4a3d, the commit before the cure): 16 of 16 listings RED (banner 1.0, comments and page
# breaks missing, debug_list 273 and 214 lines against sbl's 619); this tree reads 16 of 16 SAME.
# FAIL_ONCE for the include witnesses (recorded 2026-10-14, the tree before the include-depth cure, src stashed): p_inc, p_inc2, p_inc3 RED in both modes (the
# placeholder where the image belongs, the continuation line and the depth column missing); with the cure all 22 listings SAME.
# FAIL_ONCE p_inc4 (2026-10-15, src stashed): RED in both modes (the nested include's first statement listed at the parent file's depth); with the cure all 24 listings SAME.
# EXIT 0 every witness in both modes; 1 a red (named, with the first differing line); 2 REFUSED (oracle, build, or sbl printed no listing).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "REFUSED(2): correctness oracle missing ($SBL)"; exit 2; }
[ -x "$ROOT/scrip" ] && [ -f "$ROOT/out/libscrip_rt.so" ] || { echo "REFUSED(2): $ROOT/scrip or out/libscrip_rt.so not built"; exit 2; }
C="$S4E/corpus"
for f in packages/snobol4/dotnet/SourceLines001.sno packages/snobol4/csnobol4_suite/hide.sno programs/lon_cherryholmes/sno/debug.sno; do
    [ -f "$C/$f" ] || { echo "REFUSED(2): witness $C/$f missing"; exit 2; }
done
W="$(mktemp -d)" || exit 2; trap 'rm -rf "$W"' EXIT
cd "$W" || exit 2
cp "$C/packages/snobol4/dotnet/SourceLines001.sno" "$C/packages/snobol4/csnobol4_suite/hide.sno" . || exit 2
sed '1s/^-NOLIST/-LIST/' "$C/programs/lon_cherryholmes/sno/debug.sno" > debug_list.sno || exit 2
grep -q '^-LIST' debug_list.sno || { echo "REFUSED(2): debug.sno no longer opens with -NOLIST, the witness is not cut"; exit 2; }
cat > p_title.sno <<'SNO'
-LIST
-TITLE A title here
-STITL a sub title
 X = 1
-EJECT
 Y = 2
-SPACE 3
 Z = 3
-DOUBLE
 W = 4
-SINGLE
 OUTPUT = X + Y
END
SNO
cat > p_print.sno <<'SNO'
-LIST
 A = 1
-NOPRINT
 B = 2
-PRINT
 C = 3
-NOLIST
 D = 4
-LIST
 E = 5
* a comment
 OUTPUT = A + C + E
END
SNO
printf -- '-LIST,-EJECT\n A = 1\n-TITLE x,-LIST\n\tB = 2\n OUTPUT = A + B\nEND\n' > p_chain.sno
{ echo '-LIST'; for i in $(seq 1 119); do echo " V$i = $i"; done; printf ' OUTPUT = V1\nEND\n'; } > p_page50.sno
{ echo '-LIST'; for i in $(seq 1 1199); do echo " V = $i"; done; printf ' OUTPUT = V\nEND\n'; } > p_page1200.sno
printf '* inc comment\n Y = 2\n Z = Y + 1\n' > inc1.sno
printf -- '-LIST\n X = 1\n-INCLUDE '"'"'inc1.sno'"'"'\n OUTPUT = X + Y + Z\nEND\n' > p_inc.sno
printf '* deep comment\n B = '"'"'deep'"'"'\n' > inc_b.sno
printf '* top of a\n-EJECT\n A = '"'"'a'"'"'\n-INCLUDE '"'"'inc_b.sno'"'"'\n C = A +\n+  1\n-TITLE in a\n D = 1\n\n E = 2\n' > inc_a.sno
printf -- '-LIST\n X = 1\n-INCLUDE '"'"'inc_a.sno'"'"'\n OUTPUT = X\n OUTPUT = B\nEND\n' > p_inc2.sno
printf ' C = 1 +\n+  2\n D = 3\n' > inc_c.sno
printf -- '-LIST\n-INCLUDE '"'"'inc_c.sno'"'"'\n OUTPUT = 1\nEND\n' > p_inc3.sno
printf '* nested pol\nPOL\tOUTPUT = '"'"'pol'"'"'\n' > inc_d.sno
printf '* before nested\n-INCLUDE '"'"'inc_d.sno'"'"'\n' > inc_e.sno
printf -- '* before include\n-LIST\n-INCLUDE '"'"'inc_e.sno'"'"'\n OUTPUT = 1\nEND\n' > p_inc4.sno
cut_at_end() { grep -v '^x86-64 ' | awk '{print} /^[0-9]+ +END( |$)/{exit}'; }
rc=0; n=0
for src in SourceLines001 hide debug_list p_title p_print p_chain p_page50 p_page1200 p_inc p_inc2 p_inc3 p_inc4; do
    timeout -k 5 60 "$SBL" -bf $src.sno < /dev/null 2>/dev/null | cut_at_end > $src.o
    [ "$(grep -c 'spitbol version' $src.o)" -ge 1 ] || { echo "REFUSED(2): sbl printed no listing for $src"; exit 2; }
    timeout -k 5 60 "$ROOT/scrip" --stlimit $src.sno < /dev/null 2>/dev/null | cut_at_end > $src.m3
    timeout -k 5 60 "$ROOT/scrip" --compile -o $src.s $src.sno < /dev/null > /dev/null 2>&1 \
        && gcc -m64 -no-pie $src.s -Wl,-rpath,"$ROOT/out" -L"$ROOT/out" -lscrip_rt -lm -lpthread -o $src.bin > /dev/null 2>&1 \
        && timeout -k 5 60 ./$src.bin --stlimit < /dev/null 2>/dev/null | cut_at_end > $src.m4 || : > $src.m4
    for m in m3 m4; do
        n=$((n+1))
        if cmp -s $src.o $src.$m; then continue; fi
        echo "RED $src $m: $(wc -l < $src.o) sbl lines, $(wc -l < $src.$m) scrip lines, first difference: $(diff $src.o $src.$m | sed -n 2p | cut -c1-70)"
        rc=1
    done
done
[ $rc = 0 ] && echo "PASS: $n listings (12 witnesses x 2 modes) byte-identical to sbl through the END line"
exit $rc
