#!/usr/bin/env bash
# test_gate_icn_a_trapped_substring_past_its_shrunk_subject_raises_205.sh -- hq_icon, 2026-09-24, MODE DECTET.
#
# WHAT WAS THERE. A substring trapped variable (s[i], !s, ?s) remembers its subject variable, position and length. When
# the subject shrank below it before the store -- s[5] := (s := "ab", "z") -- c_rt_assign_var_body's tvsubs arm and
# rt_swap_var both FAILED in silence, so the program carried on where Arizona iconx stops with run-time error 205.
#
# WHAT IS HERE. The two sides of iconx, measured in its source and reproduced: an ASSIGNMENT to a trapped substring past
# its subject is oasgn.r's ReturnErrNum(205), a CONVERTIBLE error (under &error it is failure with &errornumber 205), so
# the tvsubs arm raises core_icn_error(205) when the assignment is Icon's (strict); a SWAP dereferences both operands first,
# and cnv.r's deref of a trapped substring past its subject is fatalerr(205), which &error does NOT convert, so rt_swap_var
# (Icon-only: only lower_icon.c emits IR_SWAP) raises it through core_icn_fatal before either operand is read.
#
# ARM. Five witnesses graded against the LIVE oracle (icont/iconx 9.5.25a) on stdout AND exit status in both media: the
# assignment, a swap whose right operand shrinks the subject, a swap with a list element, a swap with a literal (111, a
# control that was already right), and the &error witness where the assignment converts and the swap does not. A mutual
# evaluation yielding its last operand's variable is the green control. RUN FIRST THEN WIRED (CEO-381): on SCRIP
# 8b6cb3607 the four 205 witnesses read RED in both media (stdout "failed", rc 0 where iconx exits 1).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
ICONT="$(icont_bin)" || { echo "⛔ GATE REFUSE(2) [$G]: the Icon oracle is missing"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/asg.icn" <<'EOF'
procedure main()
   local s;
   s := "abcdef";
   (s[5] := (s := "ab", "z")) | write("failed");
   write(s);
end
EOF
cat > "$T/swp.icn" <<'EOF'
procedure main()
   local s, t;
   s := "abcdef";
   t := "x";
   (s[5] :=: (s := "ab", t)) | write("failed");
   write(s, " ", t);
end
EOF
cat > "$T/lst.icn" <<'EOF'
procedure main()
   local s, L;
   s := "abcdef";
   L := ["x"];
   (s[5] :=: L[(s := "ab", 1)]) | write("failed");
   write(s, " ", L[1]);
end
EOF
cat > "$T/lit.icn" <<'EOF'
procedure main()
   local s;
   s := "abc";
   (s :=: "lit") | write("failed");
   write(s);
end
EOF
cat > "$T/err.icn" <<'EOF'
procedure main()
   local s, t;
   &error := -1;
   s := "abcdef";
   (s[5] := (s := "ab", "z")) | write("assign failed ", &errornumber);
   s := "abcdef";
   t := "x";
   (s[5] :=: (s := "ab", t)) | write("swap failed ", &errornumber);
   write(s, " ", t);
end
EOF
cat > "$T/mut.icn" <<'EOF'
procedure main()
   local s, t;
   t := "x";
   (s := "ab", t) := "q";
   write(t);
end
EOF
pass=0; fail=0; lines=""
for w in asg swp lst lit err mut; do
  ( cd "$T" && "$ICONT" -s -o "$w.x" "$w.icn" ) >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: icont refuses $w.icn"; exit 2; }
  want="$( cd "$T" && ./"$w.x" </dev/null 2>/dev/null )"; wrc=$?
  ( cd "$T" && "$SCRIP" --compile --out="$w.s" "$w.icn" </dev/null >/dev/null 2>&1 && gcc -no-pie -o "$w.4" "$w.s" -L"$ROOT/out" -lscrip_rt -lm -lstdc++ -lpthread -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ) \
    || { echo "  $w FAIL: does not build in mode 4"; fail=$((fail+1)); continue; }
  o3="$( cd "$T" && timeout -k 5 20 "$SCRIP" "$w.icn" </dev/null 2>/dev/null )"; r3=$?
  o4="$( cd "$T" && timeout -k 5 20 ./"$w.4" </dev/null 2>/dev/null )"; r4=$?
  if [ "$o3" = "$want" ] && [ "$r3" = "$wrc" ] && [ "$o4" = "$want" ] && [ "$r4" = "$wrc" ]; then pass=$((pass+1)); lines="$lines $w"
  else fail=$((fail+1)); echo "  $w FAIL: iconx rc=$wrc [$(printf '%s' "$want" | tr '\n' '|')] m3 rc=$r3 [$(printf '%s' "$o3" | tr '\n' '|')] m4 rc=$r4 [$(printf '%s' "$o4" | tr '\n' '|')]"; fi
done
echo "  HOLDS: a trapped substring stored past its shrunk subject is run-time error 205 as iconx raises it -- convertible on assignment, fatal on swap"
if [ "$fail" -eq 0 ]; then echo "  arm 1 PASS: $pass of 6 witnesses match iconx on stdout and exit status in both media:$lines"; echo "✅ GATE PASS [$G]"; exit 0; fi
echo "  arm 1 FAIL: $fail of 6 witnesses differ from iconx"; echo "⛔ GATE FAIL [$G]"; exit 1
