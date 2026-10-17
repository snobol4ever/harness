#!/usr/bin/env bash
# test_gate_gc_a_run_time_prolog_fragment_registers_its_frame_map_and_its_site_table.sh
#
# WHAT THIS GATE HOLDS (cto 2026-10-07, from the cfo's review of the assertz-reclaim design, row
# prolog-the-code-assertz-generates-is-reclaimed-once-nothing-can-reference-it-lon-2026-09-27, QA (1)): every
# fragment the Prolog run-time definer emits (pl_runtime_define_pred_x in lower_prolog.c -- assertz and every other
# Prolog run-time define) registers its frame map and its site table with the collector, as the driver, the
# SNOBOL4 CODE/EVAL roads, the Raku EVAL and the run-time pattern builder already did. Seven copies of the same two
# registration lines lived beside those emit_chain calls and the Prolog definer carried none, so an asserted rule
# whose body allocates was polled from a frame neither walk could name: under SCRIP_GC_CHAIN_CHECK=1 the witness read
# nosite=301 (one per cycle, the pcs a page apart, the marker scan's first frame the caller loop/1, because
# gc_walk_cell refuses a DT_MAP cell whose map is unregistered). Today the type field of each DESCR in that frame
# still saves the run; once ARCH-GC section 13 STEP B makes the chain the only walk, the first such poll is a fatal.
# The cure is ONE road: emit_gc_tables_register (emit.cpp) registers the last emission's map and site tables, and
# every installer calls it -- the seven copies are gone and the Prolog definer joined.
#
# ARMS: (1) mode 3, the witness under SCRIP_GC_CHAIN_CHECK=1 SCRIP_GC_STRESS=1: the answer is 5 and the check's
# SUMMARY reads nosite=0 mismatch=0 with polls checked; (2) the same in mode 4; (3) THE ONE ROAD: outside the
# collector (gc_heap.c/.h) only emit.cpp names rt_gc_frame_maps_add or rt_gc_frame_sites_add, so no installer can
# drift from the registration again. FAIL_ONCE=1 requires nosite=1 in arms 1 and 2 to prove they can say no.
# Red on SCRIP e5054a08a: arms 1 and 2 read nosite=301, arm 3 names the seven copies in three files.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
"$ROOT/../harness/scripts/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
SCRIP="$ROOT/scrip"
G="test_gate_gc_a_run_time_prolog_fragment_registers_its_frame_map_and_its_site_table"
refuse() { echo "⛔ GATE REFUSED(2) [$G]: $1"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- build before grading"
[ -f "$ROOT/out/libscrip_rt.so" ] || refuse "no runtime library at $ROOT/out/libscrip_rt.so -- build before grading"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
checks=0; fails=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then echo "  ok   $2"; else fails=$((fails+1)); echo "  FAIL $2"; fi; }
want=0; [ "${FAIL_ONCE:-0}" = 1 ] && want=1
cat > "$W/w.pl" <<'EOF'
:- initialization(main).
:- dynamic(r/2).
loop(0) :- !.
loop(N) :- retractall(r(_, _)), assertz((r(X, Y) :- atom_concat(X, abc, Z), atom_length(Z, Y))), r(hello, L), L =:= 8, N1 is N - 1, loop(N1).
main :- loop(300), r(hi, V), write(V), nl, halt.
EOF
run_env() { env -u SCRIP_HEAP_KB -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB -u SCRIP_HEAP_MAX_MB SCRIP_GC_CHAIN_CHECK=1 SCRIP_GC_STRESS=1 "$@"; }
grade() {
  local arm="$1" out="$2" err="$3" rc="$4" s ok ns mm
  s="$(grep -a '^\[CHAIN-CHECK\] SUMMARY ' "$err" | tail -1)"
  [ -n "$s" ] || { ck no "($arm) no [CHAIN-CHECK] SUMMARY line (rc $rc) -- the check did not run, so nothing was measured"; return; }
  ok="$(printf '%s\n' "$s" | sed -n 's/.* ok=\([0-9]*\).*/\1/p')"; ns="$(printf '%s\n' "$s" | sed -n 's/.* nosite=\([0-9]*\).*/\1/p')"; mm="$(printf '%s\n' "$s" | sed -n 's/.* mismatch=\([0-9]*\).*/\1/p')"
  if [ "$rc" = 0 ] && [ "$(cat "$out")" = 5 ] && [ "${ok:-0}" -gt 0 ] && [ "$ns" = "$want" ] && [ "$mm" = 0 ]; then
    ck ok "($arm) answer 5, $ok polls checked, nosite=$ns mismatch=$mm"
  else
    ck no "($arm) rc $rc answer '$(head -c 40 "$out" | tr '\n' ' ')', ok=$ok nosite=$ns (want $want) mismatch=$mm -- an asserted rule's frame is polled with its map or site table unregistered"
  fi
}
( cd "$W" && run_env timeout -k 5 120 "$SCRIP" w.pl > o3 2> e3 < /dev/null ); grade 1 "$W/o3" "$W/e3" $?
( cd "$W" && timeout -k 5 120 "$SCRIP" --compile w.pl > w.s 2> c4 < /dev/null ) || refuse "mode 4 could not compile the witness: $(head -c 200 "$W/c4")"
gcc -c "$W/w.s" -o "$W/w.o" 2> "$W/as4" || refuse "mode 4 assembly failed: $(head -c 200 "$W/as4")"
gcc "$W/w.o" -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" -o "$W/w4" 2> "$W/ld4" || refuse "mode 4 link failed: $(head -c 200 "$W/ld4")"
( cd "$W" && run_env timeout -k 5 120 ./w4 > o4 2> e4 < /dev/null ); grade 2 "$W/o4" "$W/e4" $?
others="$(grep -rlE 'rt_gc_frame_(maps|sites)_add[[:space:]]*\(' "$ROOT/src" | grep -vE '/src/runtime/rt/gc_heap\.(c|h)$|/src/emitter/emit\.cpp$' | sed "s#^$ROOT/##" | sort | tr '\n' ' ')"
if [ -z "$others" ]; then ck ok "(3) outside the collector only emit.cpp names rt_gc_frame_maps_add / rt_gc_frame_sites_add: every installer registers through emit_gc_tables_register"
else ck no "(3) registration copies outside the one road: $others-- call emit_gc_tables_register after emit_chain instead"; fi
echo "population: $checks arm(s) graded, $fails FAIL"
if [ "$fails" = 0 ]; then echo "GATE PASS(0) [$G]"; exit 0; fi
echo "⛔ GATE RED [$G]: $fails of $checks arms FAIL"; exit 1
