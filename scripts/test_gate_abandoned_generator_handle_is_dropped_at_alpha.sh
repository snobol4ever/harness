#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 1
SCRIP=./scrip
../harness/scripts/util_require_fresh.sh --gate "$(basename "$0" .sh)" || exit $?
[ -x "$SCRIP" ] || { echo "GATE ABANDONED-HANDLE: no ./scrip -- run make"; exit 1; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fail=0; pass=0
note() { echo "  $*"; }
cat > "$T/abandon.icn" <<'EOF'
procedure gen()
   suspend 1 | 2 | 3;
end
procedure main(a)
   local i, x, p, n;
   n := integer(a[1]);
   p := gen;
   every i := 1 to n do x := p();
   write(x);
end
EOF
cat > "$T/exhaust.icn" <<'EOF'
procedure gen()
   suspend 1 | 2 | 3;
end
procedure main(a)
   local i, x, p, n;
   n := integer(a[1]);
   p := gen;
   every i := 1 to n do every x := p();
   write(x);
end
EOF
cat > "$T/det.icn" <<'EOF'
procedure gen()
   return 1;
end
procedure main(a)
   local i, x, p, n;
   n := integer(a[1]);
   p := gen;
   every i := 1 to n do x := p();
   write(x);
end
EOF
build_m4() {
  "$SCRIP" --compile "$1" > "$T/p.s" 2>"$T/c.err" || return 1
  gcc -c "$T/p.s" -o "$T/p.o" 2>>"$T/c.err" || return 1
  gcc "$T/p.o" -Lout -lscrip_rt -lm -Wl,-rpath,"$PWD/out" -o "$2" 2>>"$T/c.err" || return 1
}
rss() { /usr/bin/time -f '%M' "$@" 2>"$T/t" >"$T/o"; local rc=$?; echo "$(tail -1 "$T/t")"; return $rc; }
slope() { echo "$1 $2 $3 $4" | awk '{printf "%.3f", ($2-$1)*1.0/($4-$3)}'; }
LO=500; HI=60000
for mode in m3 m4; do
  for prog in abandon exhaust det; do
    case $mode in
      m3) RUN=("$SCRIP" "$T/$prog.icn" --) ;;
      m4) build_m4 "$T/$prog.icn" "$T/$prog.bin" || { echo "GATE ABANDONED-HANDLE: m4 build of $prog FAILED"; cat "$T/c.err"; exit 1; }
          RUN=("$T/$prog.bin") ;;
    esac
    a=$(rss "${RUN[@]}" $LO); ra=$?
    oa=$(cat "$T/o")
    b=$(rss "${RUN[@]}" $HI); rb=$?
    ob=$(cat "$T/o")
    s=$(slope "$a" "$b" "$LO" "$HI")
    note "$mode $prog: rss ${a}K@${LO} ${b}K@${HI} slope ${s} kB/iter rc=$ra/$rb out=$oa/$ob"
    if [ "$ra" -ne 0 ] || [ "$rb" -ne 0 ]; then echo "  FAIL $mode $prog: nonzero exit (the abandoned-handle class died SIGABRT in pthread_create at n=$HI)"; fail=$((fail+1)); else pass=$((pass+1)); fi
    case $prog in
      abandon) want=1 ;;
      exhaust) want=3 ;;
      det)     want=1 ;;
    esac
    if [ "$oa" = "$want" ] && [ "$ob" = "$want" ]; then pass=$((pass+1)); else echo "  FAIL $mode $prog: answer drift, want $want got $oa/$ob"; fail=$((fail+1)); fi
    case $prog in
      abandon)
        if awk -v s="$s" 'BEGIN{exit !(s < 2.0)}'; then pass=$((pass+1)); else
          echo "  FAIL $mode abandon: ${s} kB/iter retained; a bounded caller's genp handle is being overwritten at alpha instead of dropped (pre-cure reading was 11.2)"; fail=$((fail+1)); fi ;;
      det)
        if awk -v s="$s" 'BEGIN{exit !(s < 0.05)}'; then pass=$((pass+1)); else
          echo "  FAIL $mode det: ${s} kB/iter on a DETERMINISTIC callee -- this arm is the instrument's own control and must stay flat"; fail=$((fail+1)); fi ;;
      exhaust)
        if awk -v s="$s" 'BEGIN{exit !(s < 2.0)}'; then pass=$((pass+1)); else
          echo "  FAIL $mode exhaust: ${s} kB/iter on a FULLY DRIVEN generator -- this arm never abandons a handle, so a red here is the separate exhaust-path residual growing, not this gate's class"; fail=$((fail+1)); fi ;;
    esac
  done
done
echo "GATE ABANDONED-HANDLE: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
