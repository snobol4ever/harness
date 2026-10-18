#!/usr/bin/env bash
# test_gate_icn_the_cset_registry_is_weak_so_a_dead_computed_cset_leaves_the_collector.sh -- hq_icon, 2026-09-24, MODE DECTET.
#
# WHAT WAS THERE. The cset registry (keywords.c) keeps a cset's length and bits keyed by its pointer, and kw_cset_intern
# appends every DISTINCT computed cset to it. kw_cset_gc_roots rooted every entry, so a computed cset never died: deal
# -h 1000 m4 on 8b6cb3607 ended with about 3000 of them, and at the shipped 128 KB window each of about 3600 collections
# visited, marked, slot-registered and slid all of them -- 1248 ms of CPU against iconx's 38, 40 percent of it under
# kw_cset_gc_roots (perf, the generic-kernel binary).
#
# WHAT IS HERE. The unnamed entries are WEAK. kw_cset_gc_roots roots only the named keyword csets; once per collection,
# after the mark drain and before forwarding, gc_collect_ex calls kw_cset_gc_weak, which keeps and slot-registers an
# entry whose block is marked (or is not in the heap) through rt_gc_weak_keep and tombstones the rest (ptr NULL, so no
# forwarding, index rebuild or content probe ever reads it); the registry compacts and re-indexes on its next lookup.
# A cset is a value: an unnamed interned result no root reaches is unobservable, and the next intern of the same content
# makes a fresh block holding the same value (the cto's ruling on the ASK, CEO-812 permits it: no conservative visit).
#
# ARMS. (1) deal -h 1000 answers byte-identical to iconx in both media at the shipped window. (2) The plant
# SCRIP_GC_PLANT_CSET_STRONG=1 restores the strong rooting, proves it applied by its once-per-process line, and still
# answers identically. (3) RETENTION DOES NOT GROW WITH WORK: under SCRIP_GC_STRESS=1 (a collection at every opportunity, so the
# live set at exit is exact and no pacing enters it) the weak run's live blocks at exit are EQUAL at -h 50 and -h 100 and the
# plant's GROW (ceo 2026-09-25, CEO-1264: this arm read the plant's collection count against 3x the weak run's, and that was the
# half-window pacing's thrash -- since the collector spends a window before collecting it and grows one that a collection leaves
# under 15 percent free, a retaining registry gets a larger window instead of more collections: 230 weak vs 384 plant at 128 KB,
# 823 vs 428 at 64 KB, while the stress-1 reading is 524 blocks weak at both hands vs 1065 -> 1410 plant, identical on the
# pre-pacing tree d566528fa), and (4) its live bytes at exit are
# higher -- both deterministic, read off the [GC-EXERCISE] line. (5) Its CPU (user+sys, bench_rusage) is at least 1.5x (2x until
# CEO-1265, ceo 2026-09-25: since the pacing landing CEO-1264 ended the plant's thrash a retaining registry costs 2.18-2.51x the weak
# run's CPU at load 1.5 -- 33-38 ms against 83-84 -- where it cost ~15x, and the loaded blocking set read it red once while it passed
# alone on both trees; arms 3 and 4 measure the retention itself, so this arm is the cost signal and its bound is WEAKENED AND NAMED).
# Measured at landing (load 30-47, so CPU is quoted for its ratio only): weak 434 collections, 49856 live bytes, ~180 ms;
# plant 3020 collections, 172464 live bytes, ~2800 ms. Arms 3-5 are the plant proving the gate can see the regression.
# (6) THE TOMBSTONE IS NEVER READ: a witness that keeps some computed csets live in a list and a table, lets the rest die,
# and holds a NUL-carrying complement whose length only the registry knows, runs in both media under
# SCRIP_GC_PLANT_FLIP=1 at stress 1 -- every live block copied to disjoint ground and all old ground PROT_NONE, so a
# dangling registry entry read by forwarding, the index rebuild or a content probe FAULTS where it is used. Its answers
# must equal iconx's, the flip plant's proof line must print, and no [ZGC-STALE] report may appear (the cto's condition).
# Measured at landing: 11765 collections, 529 compactions that removed tombstones, about 3 s a medium.
# RUN FIRST THEN WIRED (CEO-381): on the control tree 8b6cb3607 (strong registry, no plant) arms 2-5 read RED.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
ICONT="$(icont_bin)" || { echo "⛔ GATE REFUSE(2) [$G]: the Icon oracle is missing"; exit 2; }
K="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}/corpus/benchmarks/icon/deal.icn"
[ -f "$K" ] || { echo "⛔ GATE REFUSE(2) [$G]: the deal kernel is missing at $K"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cp "$K" "$T/deal.icn"
gcc -O0 -o "$T/ru" "$ROOT/tools/bench_rusage.c" >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: bench_rusage does not build"; exit 2; }
( cd "$T" && "$ICONT" -s -o deal.x deal.icn ) >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: icont refuses deal.icn"; exit 2; }
( cd "$T" && ./deal.x -h 1000 </dev/null >want 2>/dev/null ); [ -s "$T/want" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle printed nothing"; exit 2; }
( cd "$T" && "$SCRIP" --compile -o d.s deal.icn </dev/null >/dev/null 2>&1 && gcc -no-pie -o d4 d.s -L"$ROOT/out" -lscrip_rt -lm -lstdc++ -lpthread -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ) \
  || { echo "⛔ GATE FAIL [$G]: deal does not build in mode 4"; exit 1; }
run() { ( cd "$T" && env -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB -u SCRIP_HEAP_MAX_MB -u SCRIP_GC_STRESS -u SCRIP_GC_PLANT_FLIP \
            SCRIP_HEAP_KB=128 SCRIP_GC_EXERCISE=1 SCRIP_GC_PLANT_CSET_STRONG="$1" timeout -k 5 120 ./ru ./d4 -h 1000 </dev/null >"out.$1" 2>"err.$1" ); }
field() { sed -n "s/.*\[GC-EXERCISE\].* $2=\([0-9]*\).*/\1/p" "$T/err.$1" | tail -1; }
cpu() { sed -n 's/.*user_us=\([0-9]*\) sys_us=\([0-9]*\).*/\1 \2/p' "$T/err.$1" | awk '{print int(($1+$2)/1000)}' | tail -1; }
run 0; run 1
rx() { ( cd "$T" && env -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB -u SCRIP_HEAP_MAX_MB -u SCRIP_GC_PLANT_FLIP \
            SCRIP_HEAP_KB=128 SCRIP_GC_STRESS=1 SCRIP_GC_EXERCISE=1 SCRIP_GC_PLANT_CSET_STRONG="$1" timeout -k 5 120 ./d4 -h "$2" </dev/null 2>&1 >/dev/null ) \
        | sed -n 's/.*\[GC-EXERCISE\].* blocks=\([0-9]*\).*/\1/p' | tail -1; }
rw50=$(rx 0 50); rw100=$(rx 0 100); rs50=$(rx 1 50); rs100=$(rx 1 100)
[ -n "$rw50" ] && [ -n "$rw100" ] && [ -n "$rs50" ] && [ -n "$rs100" ] || { echo "⛔ GATE REFUSE(2) [$G]: no [GC-EXERCISE] blocks= reading from the stress-1 retention runs"; exit 2; }
cat > "$T/w.icn" <<'EOF'
procedure main()
   local keep, t, i, c, n, s, k, total;
   keep := [];
   t := table(0);
   every i := 1 to 120 do {
      c := cset(string(i * 7919)) ++ cset(char(i % 26 + 97));
      if i % 20 = 0 then put(keep, c);
      t[c] +:= 1;
      n := ~cset(char(i % 256));
      if *n ~= 255 then write("bad complement size ", i, " ", *n);
      s := repl("abcxyz0123", 20);
      total := 0;
      s ? while tab(upto(c)) do { total +:= 1; move(1) };
      if i % 37 = 0 then write(i, " ", image(c), " ", *c, " ", total)
   };
   every c := !keep do write("kept ", image(c), " ", *c, " ", *(c ** &digits), " ", *(~c));
   k := 0;
   every c := key(t) do k +:= t[c];
   write("table keys ", *t, " sum ", k);
   n := ~'abc';
   every i := 1 to 90 do c := cset(string(i));
   write("complement ", *n, " ", (any(n, char(0)) & "nul") | "no", " ", *(n -- &ascii), " ", image(n ** 'abcdef'));
   write("done");
end
EOF
( cd "$T" && "$ICONT" -s -o w.x w.icn ) >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: icont refuses the flip witness"; exit 2; }
wwant="$( cd "$T" && ./w.x </dev/null 2>/dev/null )"; [ -n "$wwant" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle printed nothing for the flip witness"; exit 2; }
( cd "$T" && "$SCRIP" --compile -o w.s w.icn </dev/null >/dev/null 2>&1 && gcc -no-pie -o w4 w.s -L"$ROOT/out" -lscrip_rt -lm -lstdc++ -lpthread -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ) \
  || { echo "⛔ GATE FAIL [$G]: the flip witness does not build in mode 4"; exit 1; }
flip() { ( cd "$T" && env -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB -u SCRIP_HEAP_MAX_MB -u SCRIP_GC_PLANT_CSET_STRONG \
             SCRIP_HEAP_KB=128 SCRIP_GC_PLANT_FLIP=1 SCRIP_GC_STRESS=1 timeout -k 5 120 "$@" </dev/null ); }
fo3="$(flip "$SCRIP" w.icn 2>"$T/f3.err")"; fo4="$(flip ./w4 2>"$T/f4.err")"
o3="$( cd "$T" && env -u SCRIP_GC_STRESS -u SCRIP_GC_PLANT_CSET_STRONG SCRIP_HEAP_KB=128 timeout -k 5 120 "$SCRIP" deal.icn -- -h 1000 </dev/null 2>/dev/null )"
cw=$(field 0 collections); cs=$(field 1 collections); bw=$(field 0 bytes); bs=$(field 1 bytes); pw=$(cpu 0); ps=$(cpu 1)
[ -n "$cw" ] && [ -n "$cs" ] && [ -n "$bw" ] && [ -n "$bs" ] || { echo "⛔ GATE REFUSE(2) [$G]: no [GC-EXERCISE] line to read the collection count from"; exit 2; }
[ -n "$pw" ] && [ -n "$ps" ] || { echo "⛔ GATE REFUSE(2) [$G]: no CPU reading from bench_rusage"; exit 2; }
echo "  HOLDS: a computed cset no root reaches leaves the registry and the heap; the strong-rooting plant brings the churn back"
echo "  weak : collections=$cw live_bytes=$bw cpu_ms=$pw    plant: collections=$cs live_bytes=$bs cpu_ms=$ps"
bad=0
if cmp -s "$T/want" "$T/out.0" && [ "$o3" = "$(cat "$T/want")" ]; then echo "  arm 1 PASS: deal -h 1000 answers identically to iconx in both media"; else echo "  arm 1 FAIL: deal -h 1000 differs from iconx (m4 $(cmp -s "$T/want" "$T/out.0" && echo same || echo DIFFERS), m3 $([ "$o3" = "$(cat "$T/want")" ] && echo same || echo DIFFERS))"; bad=1; fi
if grep -q '\[GC-CSET\] plant' "$T/err.1" && cmp -s "$T/want" "$T/out.1"; then echo "  arm 2 PASS: the plant applied (its line printed) and still answers identically"; else echo "  arm 2 FAIL: the plant $(grep -q '\[GC-CSET\] plant' "$T/err.1" && echo applied || echo 'DID NOT APPLY') and the answer $(cmp -s "$T/want" "$T/out.1" && echo matches || echo DIFFERS)"; bad=1; fi
if [ "$rw50" -eq "$rw100" ] && [ "$rs100" -gt "$rs50" ] && [ "$rs100" -gt "$rw100" ]; then echo "  arm 3 PASS: retention does not grow with work -- live blocks at exit under stress 1: weak $rw50 at -h 50 and $rw100 at -h 100, plant $rs50 -> $rs100"
else echo "  arm 3 FAIL: live blocks at exit under stress 1: weak $rw50 at -h 50 and $rw100 at -h 100, plant $rs50 -> $rs100 -- a weak registry holds a constant live set as the work doubles, so a growing one is rooting what it should let die"; bad=1; fi
if [ "$bs" -gt "$bw" ]; then echo "  arm 4 PASS: live bytes at exit $bw weak vs $bs strong"; else echo "  arm 4 FAIL: live bytes at exit $bw weak vs $bs strong"; bad=1; fi
if [ $((2 * ps)) -ge $((3 * pw)) ]; then echo "  arm 5 PASS: CPU ${pw} ms weak vs ${ps} ms strong (>= 1.5x)"; else echo "  arm 5 FAIL: CPU ${pw} ms weak vs ${ps} ms strong -- under 1.5x"; bad=1; fi
fl3=$(grep -c '\[GC-FLIP\] plant: every live block' "$T/f3.err"); fl4=$(grep -c '\[GC-FLIP\] plant: every live block' "$T/f4.err"); st=$(cat "$T/f3.err" "$T/f4.err" | grep -c 'ZGC-STALE')
if [ "$fo3" = "$wwant" ] && [ "$fo4" = "$wwant" ] && [ "$fl3" -ge 1 ] && [ "$fl4" -ge 1 ] && [ "$st" -eq 0 ]; then echo "  arm 6 PASS: the flip witness answers as iconx in both media under SCRIP_GC_PLANT_FLIP=1 stress 1, plant applied, no stale read"
else echo "  arm 6 FAIL: flip witness m3 $([ "$fo3" = "$wwant" ] && echo same || echo DIFFERS) m4 $([ "$fo4" = "$wwant" ] && echo same || echo DIFFERS), flip proof lines $fl3/$fl4, ZGC-STALE reports $st"; bad=1; fi
[ "$bad" -eq 0 ] && { echo "✅ GATE PASS [$G]"; exit 0; }
echo "⛔ GATE FAIL [$G]"; exit 1
