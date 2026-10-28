#!/usr/bin/env bash
# test_gate_icn_a_spent_limit_releases_the_generator_slots_it_cut_so_the_chain_over_the_maps_walks.sh -- A SPENT LIMITATION'S GATE RELEASES WHAT IT CUT
# (hq_icon 2026-10-28, row icon-the-collectors-chain-over-the-maps-stops-short-bad-link-in-ipl-fstartbl-ceo-2006; hq_collector's bisect, first bad SCRIP e80dc7d0e).
#
# e80dc7d0e made a homed limitation gate leave through its beta, which restores the rsp it marked at its alpha: the frame of the generator the limit cut is
# popped. The caller's generator slot (a PTR_FRAME_H word of the call that produced it) kept the dead header, and the next collection's walk of the chain over
# the maps refused it ("the generator's resume cell names no generator graph", then BOMB: the chain over the maps stopped short, bad-link) -- IPL gprocs/fstartbl
# bombed in both modes. A bounded expression already nulls every activation slot that points below the restored rsp (x86_release_acts); the gate now does the same
# at its beta (kinds 5 and 4), and the planner gives IR_LIMIT_GATE the release lists the emitter reads (plan_facts.cpp).
#
# ARMS (mktemp fixtures outside corpus/, CEO-547; the real SCRIP, mode 3 and mode 4; expected output cut live from Arizona icont/iconx):
#   1 witness A (hq_collector's twelve lines: every p := gen(2,3) \ 3, then a second every over the same generator) prints iconx's answer plain, both modes
#   2 witness A under SCRIP_GC_STRESS=1 and =3 (a collection at every allocation / every third) prints it too, both modes
#   3 witness B (limits over a generator in a procedure, a scan, allocation between the limits, a limit conjoined with a plain generator) equals iconx plain and at stress 3, both modes
#   4 witness C (two limited procedure generators in ONE conjunction, and the same under a nested every) equals iconx plain and at stress 3, both modes -- the homed gate's third record word
#     (limit.mark) was granted outside its slot and aliased the next literal's slot, so the second limit read a garbage count (error 101)
# FAIL-ONCE: arms 2 and 3 read red (the collector BOMB, no answer) and arm 4 reads red (error 101) on SCRIP 22e10e4a6, the commit before the cure -- a worktree of <cure>^.
set -uo pipefail
GATE_NAME=test_gate_icn_a_spent_limit_releases_the_generator_slots_it_cut_so_the_chain_over_the_maps_walks
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
. "$HERE/lib_gate.sh"
. "$HERE/lib_oracle_flags.sh"
gate_parse_args "$@"
ICONT="$(icont_bin)"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
[ -x "$ICONT" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no icont at $ICONT -- the expected output is cut from Arizona Icon"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
command -v gcc >/dev/null || { echo "⛔ REFUSED(2) [$GATE_NAME]: no gcc -- the mode-4 arms cannot be linked"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0
ok() { echo "  ok   $1"; }
bad() { echo "  FAIL $1"; fail=1; }
cat > "$T/a.icn" <<'EOF'
procedure gen(a, b);
   local i;
   every i := 1 to 40 do suspend [i, a * i + b];
end
procedure main();
   local p, n;
   n := 0;
   every p := gen(2, 3) \ 3 do n +:= 1;
   write(n);
   every gen(2, 3) do n +:= 1;
   write(n);
end
EOF
cat > "$T/b.icn" <<'EOF'
procedure gen(a, b);
   local i;
   every i := 1 to 40 do suspend [i, a * i + b];
end
procedure fill(k);
   local l, i;
   l := [];
   every i := 1 to k do put(l, repl("x", i));
   return *l;
end
procedure main();
   local p, n, s, t;
   n := 0;
   every p := gen(2, 3) \ 3 do n +:= 1;
   write(n);
   every gen(2, 3) do n +:= 1;
   write(n);
   every p := gen(2, 3) \ 2 do { n +:= 10; fill(20) };
   every p := gen(1, 1) \ 4 do { n +:= 100; fill(30) };
   write(n);
   "abcdefghij" ? every s := tab(upto('de') | many(&lcase)) \ 1 do { n +:= 1000; fill(20) };
   write(n);
   t := 0;
   every p := (gen(3, 1) \ 2) & gen(5, 2) do { t +:= 1; fill(10) };
   write(t);
   every gen(1, 1) do fill(5);
   write(fill(3));
end
EOF
cat > "$T/c.icn" <<'EOF'
procedure g(n);
   suspend 1 to n;
end
procedure gen(a, b);
   local i;
   every i := 1 to 40 do suspend [i, a * i + b];
end
procedure main();
   local p, t, u;
   t := 0;
   every (g(5) \ 2) & (g(5) \ 2) do t +:= 1;
   write(t);
   every p := (gen(3, 1) \ 2) & (gen(5, 2) \ 2) do t +:= 1;
   write(t);
   u := 0;
   every p := gen(3, 1) \ 2 do { every (g(4) \ 3) & (g(2) \ 2) do u +:= 1 };
   write(u);
end
EOF
for w in a b c; do
    ( cd "$T" && "$ICONT" -s -o "$w.ix" "$w.icn" > "$w.cerr" 2>&1 && "./$w.ix" < /dev/null > "$w.ref" 2> /dev/null ) || { echo "⛔ REFUSED(2) [$GATE_NAME]: icont could not build or run witness $w"; exit 2; }
    ( cd "$T" && "$SCRIP" --compile -o "$w.s" "$w.icn" < /dev/null > /dev/null 2>&1 && gcc -m64 -no-pie "$w.s" -Wl,-rpath,"$RT" -L"$RT" -lscrip_rt -lm -lpthread -o "$w.bin" 2> /dev/null ) || { echo "⛔ REFUSED(2) [$GATE_NAME]: SCRIP could not compile and link witness $w in mode 4"; exit 2; }
done
# run <witness> <mode> <stress>: prints PASS when the program's stdout equals the oracle's and it exits 0
run() {
    local w="$1" m="$2" st="$3" rc
    if [ "$m" = m3 ]; then ( cd "$T" && SCRIP_GC_STRESS="$st" timeout -k 5 120 "$SCRIP" "$w.icn" < /dev/null > "$w.$m.$st.out" 2> "$w.$m.$st.err" ); rc=$?
    else ( cd "$T" && SCRIP_GC_STRESS="$st" timeout -k 5 120 "./$w.bin" < /dev/null > "$w.$m.$st.out" 2> "$w.$m.$st.err" ); rc=$?; fi
    if [ "$rc" = 0 ] && cmp -s "$T/$w.$m.$st.out" "$T/$w.ref"; then echo PASS; else echo "rc=$rc $(grep -m1 -o 'chain over the maps[^;]*' "$T/$w.$m.$st.err" | head -1)"; fi
}
for m in m3 m4; do
    r="$(run a $m 0)"; if [ "$r" = PASS ]; then ok "(1) witness A, $m, plain: iconx's answer"; else bad "(1) witness A, $m, plain: $r"; fi
done
for m in m3 m4; do for st in 1 3; do
    r="$(run a $m $st)"; if [ "$r" = PASS ]; then ok "(2) witness A, $m, SCRIP_GC_STRESS=$st: iconx's answer"; else bad "(2) witness A, $m, SCRIP_GC_STRESS=$st: $r"; fi
done; done
for m in m3 m4; do for st in 0 3; do
    r="$(run b $m $st)"; if [ "$r" = PASS ]; then ok "(3) witness B, $m, SCRIP_GC_STRESS=$st: iconx's answer"; else bad "(3) witness B, $m, SCRIP_GC_STRESS=$st: $r"; fi
done; done
for m in m3 m4; do for st in 0 3; do
    r="$(run c $m $st)"; if [ "$r" = PASS ]; then ok "(4) witness C, $m, SCRIP_GC_STRESS=$st: iconx's answer"; else bad "(4) witness C, $m, SCRIP_GC_STRESS=$st: $r"; fi
done; done
[ "$fail" = 0 ] && { echo "✅ GATE PASS [$GATE_NAME]: a spent limitation releases the generator slots it cut, and the chain over the maps walks the caller's frame"; exit 0; }
echo "⛔ GATE RED [$GATE_NAME]"; exit 1
