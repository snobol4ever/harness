#!/usr/bin/env bash
# test_gate_gc_the_chain_over_the_maps_finds_every_frame_by_return_pc.sh -- THE CHAIN OVER THE MAPS IS THE COLLECTOR'S ONLY WALK (hq_collector 2026-10-11, ARCH-GC-COMPILE-TIME-FRAME-MAPS.md
# section 13.9 SIX, the DONE-WHEN of the row gc-one-stack-all-descriptors-no-marker-no-map-no-ledger-...; the cto's six conditions of 2026-10-11 on STEP B).
#
# WHAT THIS GATE HOLDS. A frame is found by its return PC and its link word through the per-site table, never by a marker on the stack, never by a scan, never by a second stack
# (Lon 2026-09-30 and 2026-10-03, CEO-1368/1492). The marker machinery is deleted -- the frame-marker tag, the map's offset field, the cell walkers, the ceiling, the stale-frame plant, the
# 16-byte sweep census -- and the collector walks only the frames the chain names; a chain that stops short is a fatal that names the PC (13.9 ONE), never a skip.
#
# ARMS. (1) THE DELETIONS: the five files the row names carry zero lines of the marker machinery. (2) NO MARKER IN EMITTED CODE: the mode-4 text of a witness per front end names a map only
# through its data (the table and the site blocks), by no `lea` and no store. (3) THE WALK IS THE CHAIN AND REFUSES BY NAME: gc_visit_segment_cap resolves the chain list and calls
# gc_chain_refuse on any stop short of ROOT, the refusal prints the entry PC and aborts through rt_bomb, and no fixed hop bound is declared in the walk (13.9 THREE). (4) LIVE, per front
# end and per mode: seven witnesses and the cross-language gc_witnesses, at the 64 KB window with a collection at every safe point, answer exactly as their plain run (or their ref), and
# the walk summary prints frames >= 1 with every stop short of root at zero (nosite, frameless, unknown-depth, cycle, no-link, no-rise, bad-link) and no refusal. (5) THE REAL PROGRAMS, the
# CEO-1691 finish line: SnoRungs demo_porter and SncBench parser_pascal print their ref in both modes, demo_porter also under a collection at every fifth safe point over 300 input lines
# (the stressed run is the one the marker scan answered wrongly: it read a dead sibling thunk's marker as the live frame in about a third of the collections and skipped the c2bb glue's
# subject cell, so a spine change that moved a collection crashed it in mode 4). The proof that these arms can fail is the commit before STEP B: the same programs under the marker scan
# (ea957ffc5 on that tree: demo_porter mode 4 SIGSEGV after collection 10, parser_pascal mode 3 'Parse Error').
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
G=test_gate_gc_the_chain_over_the_maps_finds_every_frame_by_return_pc
SCRIP="$ROOT/scrip"; RT="$ROOT/out"; WD="$HERE/gc_witnesses"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"; CORPUS="$S4E/corpus"
refuse() { echo "⛔ GATE REFUSED(2) [$G]: $1"; exit 2; }
[ -x "$SCRIP" ] && [ -f "$RT/libscrip_rt.so" ] || refuse "no scrip binary or runtime library under $ROOT -- build before grading"
[ -d "$CORPUS/tests/snobol4" ] || refuse "no corpus checkout beside SCRIP at $CORPUS"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
checks=0; fails=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then echo "  ok   $2"; else fails=$((fails+1)); echo "  FAIL $2"; fi; }
num() { printf '%s\n' "$1" | sed -n "s/.* $2=\([0-9]*\).*/\1/p"; }
GCH="$ROOT/src/runtime/rt/gc_heap.c"

n=$(grep -cE 'DT_MAP|map_off|gc_walk_cell|gc_walk_interior|rt_gc_emit_ceiling_adopt|gc_emit_ceiling_resolve|g_gc_emit_ceiling|SCRIP_GC_PLANT_STALE_FRAME|SCRIP_GC_SWEEP16' \
  "$GCH" "$ROOT/src/emitter/emit.cpp" "$ROOT/src/ir/descr_tags.inc" "$ROOT/src/ir/descr.h" "$ROOT/src/ir/gc_frame_map.h" | awk -F: '{s+=$2} END{print s+0}')
if [ "$n" = 0 ]; then ck ok "(1) the marker machinery is gone from the five files the row names (0 lines)"; else ck no "(1) $n line(s) of marker machinery (DT_MAP, map_off, the cell walkers, the ceiling, the stale-frame plant, SWEEP16) remain in src"; fi

printf 'procedure q(n)\n  local i;\n  every i := 1 to n do write(i * i);\nend\nprocedure main()\n  q(3);\nend\n' > "$W/w.icn"
printf 'p(1).\np(2).\nq(X, Y) :- p(X), Y is X * 2.\n:- q(X, Y), write(Y), nl, fail.\n:- true.\n' > "$W/w.pl"
printf '        DEFINE("F(X)")             :(START)\nF       F = X * 2                   :(RETURN)\nSTART   OUTPUT = F(21)\n        S = "abc" ; S "b" = "B"\n        OUTPUT = S\nEND\n' > "$W/w.sno"
printf 'sub sq($n) { return $n * $n }\nsay sq(7);\n' > "$W/w.raku"
printf 'program w;\nfunction sq(n: integer): integer;\nbegin sq := n * n end;\nbegin writeln(sq(9)) end.\n' > "$W/w.pas"
sc="$(ls "$CORPUS/benchmarks/snocone" 2>/dev/null | grep '\.sc$' | head -1)"; [ -n "$sc" ] && cp "$CORPUS/benchmarks/snocone/$sc" "$W/w.sc"
rb="$(ls "$CORPUS/benchmarks/rebus" 2>/dev/null | grep '\.reb$' | head -1)"; [ -n "$rb" ] && cp "$CORPUS/benchmarks/rebus/$rb" "$W/w.reb"
bad2=0; seen2=0
for f in "$W"/w.*; do
  [ -f "$f" ] || continue
  timeout -k 5 120 "$SCRIP" --compile -o "$W/a.s" "$f" > /dev/null 2>&1 < /dev/null || continue
  seen2=$((seen2+1))
  lea=$(grep -cE 'lea +[a-z0-9]+, *\[rip *\+ *\.Lgcmap_' "$W/a.s")
  [ "$lea" = 0 ] || { bad2=$((bad2+1)); echo "       $(basename "$f"): $lea lea of a map label in emitted code"; }
done
if [ "$seen2" -ge 5 ] && [ "$bad2" = 0 ]; then ck ok "(2) $seen2 front-end witnesses compile and name their maps through data only (no lea of a map label)"; else ck no "(2) $seen2 witnesses compiled, $bad2 name a map from code"; fi

if grep -q 'gc_chain_refuse(&s, ent, lo0, hi0)' "$GCH" && grep -q 'rt_bomb("gc: the chain over the maps stopped short' "$GCH" && grep -q 'REFUSED: the chain over the maps stops short' "$GCH"; then ck ok "(3a) a chain that stops short is refused by name: the entry PC is printed and the collector aborts through rt_bomb"
else ck no "(3a) gc_visit_segment no longer refuses a chain that stops short by name"; fi
hb=$(grep -nE '(hops?|HOPS?)[A-Za-z_0-9]*(\+\+|--)? *(<|>|<=|>=|==|!=) *[0-9]+|[0-9]+ *(<|>|<=|>=|==|!=) *(\+\+|--)?(hops?|HOPS?)[A-Za-z_0-9]*|#define +[A-Z_]*HOP' "$GCH" | grep -vE 'roadhops|fnhops|landhops|g_gc_chain_' | wc -l)
if [ "$hb" = 0 ]; then ck ok "(3b) no fixed hop bound is declared in the walk (ARCH-GC 13.9 THREE)"; else ck no "(3b) $hb line(s) declare a fixed hop bound in gc_heap.c"; fi

run_env() { env -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB -u SCRIP_HEAP_MAX_MB SCRIP_HEAP_KB=64 SCRIP_GC_CHAIN_CHECK=3 SCRIP_GC_STRESS=1 "$@"; }
live() {
  local name="$1" src="$2" in="${3:-/dev/null}" ref="${4:-}" b; b="$W/L.$name"
  ( cd "$W" && timeout -k 5 300 "$SCRIP" "$src" > "$b.plain" 2> /dev/null < "$in" ); local r0=$?
  [ -n "$ref" ] && [ -f "$ref" ] && cp "$ref" "$b.ref" || cp "$b.plain" "$b.ref"
  ( cd "$W" && run_env timeout -k 5 300 "$SCRIP" "$src" > "$b.o3" 2> "$b.e3" < "$in" ); local r3=$?
  if ( cd "$W" && timeout -k 5 300 "$SCRIP" --compile -o "$b.s" "$src" > /dev/null 2> "$b.c4" < /dev/null ) && gcc "$b.s" -L"$RT" -lscrip_rt -lm -lpthread -Wl,-rpath,"$RT" -o "$b.x" 2> "$b.ld4"; then
    ( cd "$W" && run_env timeout -k 5 300 "$b.x" > "$b.o4" 2> "$b.e4" < "$in" ); local r4=$?
  else r4=build; : > "$b.o4"; : > "$b.e4"; fi
  local m rc o s fr stops
  for m in 3 4; do
    if [ $m = 3 ]; then rc=$r3; else rc=$r4; fi
    s="$(grep -a '^\[CHAIN-WALK\] SUMMARY ' "$b.e$m" | tail -1)"
    if [ "$rc" = build ]; then ck no "(4) $name mode $m: the witness did not build in mode 4: $(head -c 160 "$b.c4" "$b.ld4" 2>/dev/null | tr '\n' ' ')"; continue; fi
    if grep -aq 'REFUSED: the chain over the maps' "$b.e$m"; then ck no "(4) $name mode $m: the chain was refused: $(grep -a -m1 'REFUSED' "$b.e$m" | cut -c1-200)"; continue; fi
    if ! cmp -s "$b.o$m" "$b.ref" || [ "$rc" != "$r0" ]; then ck no "(4) $name mode $m: rc=$rc (plain $r0) or the output differs from the ref under a collection at every safe point"; continue; fi
    fr="$(num "$s" frames)"; stops=$(( $(num "$s" nosite) + $(num "$s" frameless) + $(num "$s" unknown-depth) + $(num "$s" cycle) + $(num "$s" no-link) + $(num "$s" no-rise) + $(num "$s" bad-link) ))
    if [ -n "$s" ] && [ "${fr:-0}" -ge 1 ] && [ "$stops" = 0 ]; then ck ok "(4) $name mode $m: output as plain, $(num "$s" runs) collection(s) walked $fr frame(s), no stop short of root"
    else ck no "(4) $name mode $m: summary '${s:-none}' -- frames=${fr:-?} stops-short=$stops"; fi
  done
}
for f in "$W"/w.*; do [ -f "$f" ] && live "$(basename "$f")" "$f"; done
for w in hb_arr.sno hb_wsb_eval_define.sno hb_coexpr_create.icn hb_coexpr_parked.icn hb_pl_findall.pl hb_wsb_raku_sprintf_multi.raku hb_concat_slot_capture_across_a_collection.sc \
         hb_sno_a_poll_inside_a_match_nested_in_a_function_body_called_from_a_deferred_pattern_call_is_found_by_the_chain.sno hb_shim_rt_names_past_the_hidden_island_slots.sno; do
  [ -f "$WD/$w" ] || { ck no "(4) the witness $WD/$w is missing"; continue; }
  b="${w%.*}"; in=/dev/null; [ -f "$WD/$b.in" ] && in="$WD/$b.in"
  live "$w" "$WD/$w" "$in" "$WD/$b.ref"
done

printf ':- initialization(main).\np :- write(before), nl, shift(ball1), write(after), nl, shift(ball2), write(end), nl.\nmain :- reset(p, B1, C1), writeq(B1), nl,\n        reset(C1, B2, C2), writeq(B2), nl,\n        reset(C2, B3, C3), ( var(B3) -> writeq(no_ball) ; writeq(B3) ), writeq(C3), nl,\n        reset(true, B4, C4), ( var(B4) -> writeq(no_ball) ; writeq(B4) ), writeq(C4), nl.\n' > "$W/cont.pl"
live cont.pl "$W/cont.pl"
for m in 3 4; do
  cs="$(num "$(grep -a '^\[CHAIN-WALK\] SUMMARY ' "$W/L.cont.pl.e$m" | tail -1)" coroutine-start)"
  if [ "${cs:-0}" -gt 0 ]; then ck ok "(4) cont.pl mode $m: $cs parked continuation segment(s) end at the named coroutine start (rt_genp_conts, the cto's reset/3 and shift/1)"; else ck no "(4) cont.pl mode $m: coroutine-start=${cs:-?} -- a parked continuation's chain no longer ends at its coroutine start"; fi
done

H="$ROOT/../harness/scripts/corpus_suite_harness.py"
if python3 "$H" extract "$CORPUS/tests/snobol4/ALL.sno" "$CORPUS/tests/snobol4/ALL.ref" demo_porter "$W/dp.sno" --out-ref "$W/dp.ref" --out-in "$W/dp.in" > /dev/null 2>&1; then
  head -300 "$W/dp.in" > "$W/dp.small.in"
  ( cd "$W" && timeout -k 5 300 "$SCRIP" -d131072k -s4096k --stlimit dp.sno < dp.in > dp.o3 2> dp.e3 ); r3=$?
  ( cd "$W" && "$SCRIP" --compile -o dp.s dp.sno > /dev/null 2>&1 < /dev/null && gcc dp.s -L"$RT" -lscrip_rt -lm -lpthread -Wl,-rpath,"$RT" -o dp.x 2> /dev/null && timeout -k 5 300 ./dp.x -d131072k -s4096k --stlimit -- < dp.in > dp.o4 2> dp.e4 ); r4=$?
  if cmp -s "$W/dp.o3" "$W/dp.ref" && [ "$r3" = 0 ]; then ck ok "(5) demo_porter mode 3 prints its ref"; else ck no "(5) demo_porter mode 3 rc=$r3 or the output differs from the ref"; fi
  if cmp -s "$W/dp.o4" "$W/dp.ref" && [ "$r4" = 0 ]; then ck ok "(5) demo_porter mode 4 prints its ref"; else ck no "(5) demo_porter mode 4 rc=$r4 or the output differs from the ref"; fi
  ( cd "$W" && env SCRIP_GC_STRESS=5 timeout -k 5 300 "$SCRIP" -d131072k -s4096k --stlimit dp.sno < dp.small.in > dp.s3 2> dp.se3 ); s3=$?
  ( cd "$W" && env SCRIP_GC_STRESS=0 timeout -k 5 300 "$SCRIP" -d131072k -s4096k --stlimit dp.sno < dp.small.in > dp.u3 2> /dev/null )
  if [ "$s3" = 0 ] && cmp -s "$W/dp.s3" "$W/dp.u3"; then ck ok "(5) demo_porter mode 3 over 300 lines, a collection at every fifth safe point, answers its unstressed run"; else ck no "(5) demo_porter mode 3 stress 5 rc=$s3 or the output differs from the unstressed run: $(grep -a -m1 -E 'REFUSED|ZGC-STALE|fatal signal' "$W/dp.se3" | cut -c1-200)"; fi
else ck no "(5) demo_porter is not extractable from $CORPUS"; fi
K="$CORPUS/benchmarks/snocone/parsers/parser_pascal"
if [ -f "$K.sc" ] && [ -f "$K.input" ] && [ -f "$K.ref" ]; then
  ( cd "$CORPUS" && SNO_LIB="$CORPUS/include" timeout -k 5 600 "$SCRIP" -d4194304k -s2097152k --run "$K.sc" < "$K.input" > "$W/pp.o3" 2> "$W/pp.e3" ); r3=$?
  ( cd "$CORPUS" && "$SCRIP" --compile -o "$W/pp.s" "$K.sc" > /dev/null 2>&1 < /dev/null && gcc "$W/pp.s" -L"$RT" -lscrip_rt -lm -lpthread -Wl,-rpath,"$RT" -o "$W/pp.x" 2> /dev/null && SNO_LIB="$CORPUS/include" timeout -k 5 600 "$W/pp.x" -d4194304k -s2097152k < "$K.input" > "$W/pp.o4" 2> "$W/pp.e4" ); r4=$?
  if cmp -s "$W/pp.o3" "$K.ref" && [ "$r3" = 0 ]; then ck ok "(5) parser_pascal mode 3 prints its ref"; else ck no "(5) parser_pascal mode 3 rc=$r3 or the output differs from the ref ($(head -c 20 "$W/pp.o3" | head -1))"; fi
  if cmp -s "$W/pp.o4" "$K.ref" && [ "$r4" = 0 ]; then ck ok "(5) parser_pascal mode 4 prints its ref"; else ck no "(5) parser_pascal mode 4 rc=$r4 or the output differs from the ref: $(grep -a -m1 -E 'REFUSED|fatal signal' "$W/pp.e4" | cut -c1-200)"; fi
else ck no "(5) parser_pascal is missing from $CORPUS/benchmarks/snocone/parsers"; fi
K="$CORPUS/benchmarks/snocone/parsers/parser_snobol4"
if [ -f "$K.sc" ] && [ -f "$K.input" ] && [ -f "$K.ref" ]; then
  sed 's/MATCHAT()/VDIFFER()/g' "$K.sc" > "$W/k0.sc"
  if grep -q 'VDIFFER()' "$W/k0.sc"; then
    ( cd "$W" && SCRIP_GC_CHAIN_CHECK=1 timeout -k 5 600 "$SCRIP" -d4194304k -s2097152k k0.sc < "$K.input" > k0.o3 2> k0.e3 ); r0=$?
    if [ "$r0" = 0 ] && cmp -s "$W/k0.o3" "$K.ref" && ! grep -aq 'GC-CHAIN\] REFUSED' "$W/k0.e3"; then ck ok "(6) parser_snobol4 with its MATCHAT() stamps as the zero-argument unknown callee VDIFFER() prints its ref in mode 3 under the chain check: a Snocone procedure's frame is hopped by its own SIG record, never by a leftover tiny-glue word above its top (CEO-1746; rc 139 on 0e4313bfc)"
    else ck no "(6) parser_snobol4/VDIFFER() mode 3 rc=$r0 $(grep -ao 'stops short ([a-z-]*)' "$W/k0.e3" | head -1) -- the walker took a word above the frame top as the tiny-glue road"; fi
  else ck no "(6) the parser_snobol4 copy carries no MATCHAT() stamp to replace"; fi
else ck no "(6) parser_snobol4 is missing from $CORPUS/benchmarks/snocone/parsers"; fi
echo "population: $checks arm(s) graded, $fails FAIL"
if [ "$fails" = 0 ]; then echo "GATE PASS(0) [$G]"; exit 0; fi
echo "⛔ GATE RED [$G]: $fails of $checks arms FAIL"; exit 1
