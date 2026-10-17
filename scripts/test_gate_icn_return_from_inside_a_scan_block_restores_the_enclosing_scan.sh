#!/usr/bin/env bash
# test_gate_icn_return_from_inside_a_scan_block_restores_the_enclosing_scan.sh
#
# WHY THIS EXISTS (hq_R's witness .github b76ecb2e9, cured by hq_U on the ceo's scan/conjunction-resumption
# cut).  A RETURN executed from inside a string-scanning block leaves the ENCLOSING scan pointed at the INNER
# subject.  `"AB" ? (inner("zz") || move(1))` printed `zzz` in both modes where iconx prints `zzA`: inner
# returns `zz`, then the outer `move(1)` takes the second character of `zz` instead of the second character
# of `AB`.  TT_RETURN built an IR_RETURN and never unwound cx->scan_sp, while TT_SUSPEND, TT_LOOP_BREAK and
# TT_LOOP_NEXT all did -- the one exit out of a scan body that was not unwinding.
#
# ⭐ THE CONTROL ARM IS WHAT MADE IT CHEAP AND IT IS AN ARM HERE FOR THAT REASON (hq_R's, kept in their
# words): move the return OUT of the scan block and it was already GREEN.  So nested scanning worked, calling
# a scanning procedure from inside a scan worked, and the save-restore was correct on the block's NORMAL exit
# path.  Only the EARLY-RETURN path lacked it.  A defect with a green twin has its cure named by the twin --
# and the twin is also the arm that catches an over-broad cure, because a fix that unwinds too much breaks
# the case that was never broken.
#
# ⛔ GRADED AGAINST iconx, NEVER AGAINST A PINNED STRING.  Every expected value here comes from the oracle at
# run time; a hand-typed `zzA` in this file would be a self-pin wearing an oracle's clothes.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"
NAME=icn_return_from_inside_a_scan_block_restores_the_enclosing_scan
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
. "$HERE/lib_gate.sh"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || refuse "lib_oracle_flags.sh unloadable -- it is the one authority for the icont/iconx paths and this gate will not re-derive them"
ICONT="$(icont_bin 2>/dev/null || true)"
[ -n "$ICONT" ] && [ -x "$ICONT" ] || refuse "no icont at '${ICONT:-<empty>}' -- every expected value in this gate comes from the oracle, so with no oracle it CANNOT MEASURE (and MUST NOT fall back to a pinned string)"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
# W1 hq_R's own witness. W2 the same shape nested two scans deep. W3 a VALUELESS return out of a scan block.
# W4 THE CONTROL: the return is OUTSIDE the block, and it was green before the cure -- it must stay green.
# W5 two returns in one procedure, one inside the block and one outside, so the unwind cannot be a blanket
#    "always leave one level" that happens to fit the single-return case.
cat > "$TD/w1.icn" <<'EOF'
procedure inner(x);
   x ? { return tab(0); };
end
procedure main();
   write("AB" ? (inner("zz") || move(1)));
end
EOF
cat > "$TD/w2.icn" <<'EOF'
procedure inner(x);
   x ? { "z" ? { return tab(0); }; };
end
procedure main();
   write("AB" ? (inner("zz") || move(1)));
end
EOF
cat > "$TD/w3.icn" <<'EOF'
procedure bare(x);
   x ? { return; };
end
procedure main();
   write("AB" ? (bare("zz") & move(1)));
end
EOF
cat > "$TD/w4.icn" <<'EOF'
procedure inner(x);
   local r;
   x ? { r := tab(0); };
   return r;
end
procedure main();
   write("AB" ? (inner("zz") || move(1)));
end
EOF
cat > "$TD/w5.icn" <<'EOF'
procedure pick(x);
   x ? { if pos(0) then return "e"; };
   return "f";
end
procedure main();
   write("CD" ? (pick("") || move(1)));
   write("EF" ? (pick("g") || move(1)));
end
EOF
GRADED=0; FAIL=0
for w in w1 w2 w3 w4 w5; do
  ( cd "$TD" && "$ICONT" -s -o "$w.ib" "$w.icn" ) >/dev/null 2>&1 || refuse "$w: icont refused this witness -- the expected value CANNOT BE MEASURED, and a witness the oracle rejects is a broken witness, not a red"
  exp="$( cd "$TD" && timeout -k 5 20 "./$w.ib" </dev/null 2>&1 )"; erc=$?
  [ "$erc" -eq 0 ] || refuse "$w: the oracle itself exited $erc -- no expected value, cannot measure"
  [ -n "$exp" ] || refuse "$w: the oracle printed NOTHING, and two empty outputs compare equal -- this gate refuses to grade an empty cut"
  got3="$( timeout -k 5 20 "$SCRIP" "$TD/$w.icn" </dev/null 2>&1 )"; GRADED=$((GRADED+1))
  if [ "$got3" = "$exp" ]; then echo "  PASS $w m3: $(printf '%s' "$exp" | tr '\n' '/')"
  else echo "  FAIL $w m3: got '$(printf '%s' "$got3" | tr '\n' '/')' want '$(printf '%s' "$exp" | tr '\n' '/')' (iconx)"; FAIL=$((FAIL+1)); fi
  "$SCRIP" --compile -o "$TD/$w.s" "$TD/$w.icn" </dev/null >/dev/null 2>&1 || refuse "$w: --compile failed -- the m4 arm CANNOT MEASURE"
  gcc -no-pie "$TD/$w.s" -o "$TD/$w.bin" -L "$ROOT/out" -Wl,-rpath,"$ROOT/out" -lscrip_rt -lm -lpthread >/dev/null 2>&1 || refuse "$w: link failed -- the m4 arm CANNOT MEASURE"
  got4="$( timeout -k 5 20 "$TD/$w.bin" </dev/null 2>&1 )"; GRADED=$((GRADED+1))
  if [ "$got4" = "$exp" ]; then echo "  PASS $w m4: $(printf '%s' "$exp" | tr '\n' '/')"
  else echo "  FAIL $w m4: got '$(printf '%s' "$got4" | tr '\n' '/')' want '$(printf '%s' "$exp" | tr '\n' '/')' (iconx)"; FAIL=$((FAIL+1)); fi
done
[ "$GRADED" -eq 10 ] || refuse "graded $GRADED of the 10 expected arms -- a gate that silently grades a subset reports the population it reached as if it were the population it owns"
echo "graded=$GRADED FAIL=$FAIL (5 witnesses x 2 modes, every expected value cut from icont/iconx at run time; w4 is the CONTROL -- it was GREEN before the cure and a red there means the unwind went too wide, not that the defect returned)"
if [ "$FAIL" -ne 0 ]; then echo "GATE FAIL(1) [$NAME]: FAIL=$FAIL of $GRADED"; exit 1; fi
echo "GATE PASS(0) [$NAME]: $GRADED/$GRADED"
exit 0
