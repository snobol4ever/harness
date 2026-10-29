#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
NAME=icn_byname_generator_call_inherits_the_scanning_environment
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
. "$HERE/lib_gate.sh"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
cat > "$TD/direct.icn" <<'EOF'
procedure main()
   if "c" ? (s() & pos(0))
      then write("accepted")
      else write("rejected");
end
procedure s()
   suspend ="c";
end
EOF
cat > "$TD/byname.icn" <<'EOF'
procedure main()
   if try(s, "c")
      then write("accepted")
      else write("rejected");
end
procedure try(goal, text)
   return text ? (goal() & pos(0));
end
procedure s()
   suspend ="c";
end
EOF
cat > "$TD/advance.icn" <<'EOF'
procedure main()
   write(try(g, "abcdef"));
   write("xy" ? (g2() | "none"));
end
procedure try(goal, text)
   return text ? (goal() || "|" || &pos);
end
procedure g()
   suspend tab(4);
end
procedure g2()
   suspend move(1);
end
EOF
cat > "$TD/coexpr.icn" <<'EOF'
procedure main()
   local e;
   "hello" ? {
      e := create (&subject || "|" || &pos);
      write(@e);
      write(&subject || "|" || &pos);
   };
end
EOF
EXP_direct='accepted'
EXP_byname='accepted'
EXP_advance='abc|4
x'
EXP_coexpr='hello|1
hello|1'
GRADED=0; FAIL=0
for w in direct byname advance coexpr; do
  eval "want=\$EXP_$w"
  for m in 3 4; do
    if [ "$m" = 3 ]; then
      out="$(timeout -k 5 20s "$SCRIP" "$TD/$w.icn" </dev/null 2>&1)"; rc=$?
    else
      "$SCRIP" --compile --out="$TD/$w.s" "$TD/$w.icn" </dev/null >/dev/null 2>&1 || refuse "$w: mode-4 compile failed -- cannot measure"
      gcc -no-pie "$TD/$w.s" -o "$TD/$w.bin" -L "$ROOT/out" -lscrip_rt -lm -lpthread >/dev/null 2>&1 || refuse "$w: mode-4 link failed -- cannot measure"
      out="$(LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 20s "$TD/$w.bin" </dev/null 2>&1)"; rc=$?
    fi
    GRADED=$((GRADED+1))
    if [ "$rc" -ne 0 ]; then echo "  FAIL m$m $w: rc=$rc [$out]"; FAIL=$((FAIL+1)); continue; fi
    if [ "$out" != "$want" ]; then
      echo "  FAIL m$m $w: got [$(printf '%s' "$out" | tr '\n' '/')] want [$(printf '%s' "$want" | tr '\n' '/')]"
      FAIL=$((FAIL+1)); continue
    fi
    echo "  PASS m$m $w"
  done
done
[ "$GRADED" -eq 0 ] && refuse "graded zero witnesses"
echo "graded=$GRADED FAIL=$FAIL (byname+advance are the cured path, oracle-confirmed against iconx; coexpr is the control arm -- a user 'create' must still own its scanning environment; direct is the always-green sibling)"
if [ "$FAIL" -ne 0 ]; then echo "GATE FAIL(1) [$NAME]: FAIL=$FAIL of $GRADED"; exit 1; fi
echo "GATE PASS(0) [$NAME]: $GRADED/$GRADED"
exit 0
