#!/usr/bin/env bash
# util_gc_chain_matrix.sh -- THE CHAIN MATRIX (hq_collector 2026-10-11, ARCH-GC section 13): every gc_witness, mode 3 and mode 4, at the 64 KB window with a collection at every
# safe point, under SCRIP_GC_CHAIN_CHECK=3, one line per witness and mode from the [CHAIN-WALK] SUMMARY, then the totals. A BOARD: the coo runs it on a row that asks (CEO-1671); a seat runs one witness by hand.
# CLEAN means whole == runs and offchain-swept, missing, bad-link, frameless, nosite, no-link, cycle, unknown-depth, visitor differ all 0. rc 0 = every line clean, rc 1 = one or more not, rc 2 = could not measure.
#   usage: util_gc_chain_matrix.sh [witness-name-substring ...]     MATRIX_STRESS=1 (default) MATRIX_KB=64 (default)
#   MATRIX_PLANT="<KNOB>=<v>" runs every witness a second time under that plant and adds a PLANT-DIFF check (the planted run's output in each mode must equal the unplanted run's). The poison
#   falsifier SCRIP_GC_PLANT_POISON went with the marker scan (STEP B): naming it REFUSES rc 2, since a plant the runtime does not carry grades nothing. The fail-once of the chain is the
#   commit-before form test_gate_gc_the_chain_over_the_maps_finds_every_frame_by_return_pc.sh names (CEO-1680).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"; WD="$ROOT/../harness/scripts/gc_witnesses"
[ -x "$SCRIP" ] && [ -f "$ROOT/out/libscrip_rt.so" ] && [ -d "$WD" ] || { echo "REFUSE(2): no scrip, runtime library or gc_witnesses directory under $ROOT"; exit 2; }
ST="${MATRIX_STRESS:-1}"; KB="${MATRIX_KB:-64}"
case "${MATRIX_PLANT:-}" in *SCRIP_GC_PLANT_POISON*) echo "REFUSE(2): MATRIX_PLANT names SCRIP_GC_PLANT_POISON, a plant the runtime no longer carries (deleted with the marker scan, STEP B) -- it would grade nothing"; exit 2;; esac
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
num() { printf '%s\n' "$1" | sed -n "s/.* $2=\([0-9]*\).*/\1/p"; }
run_env() { env -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB -u SCRIP_HEAP_MAX_MB SCRIP_HEAP_KB="$KB" SCRIP_GC_CHAIN_CHECK=3 SCRIP_GC_STRESS="$ST" ${MATRIX_PLANT:-} "$@"; }
tot=0; bad=0; runs_all=0; whole_all=0; unclean=""
for f in "$WD"/*; do
  w="$(basename "$f")"; case "$w" in *.ref|*.in|*.heap|*.stack|*.tsv|*.txt) continue;; esac
  if [ $# -gt 0 ]; then keep=0; for p in "$@"; do case "$w" in *"$p"*) keep=1;; esac; done; [ $keep = 1 ] || continue; fi
  b="${w%.*}"; i=/dev/null; [ -f "$WD/$b.in" ] && i="$WD/$b.in"
  ( cd "$W" && run_env timeout -k 5 300 "$SCRIP" "$f" > "$b.o3" 2> "$b.e3" < "$i" )
  if ( cd "$W" && timeout -k 5 300 "$SCRIP" --compile -o "$b.s" "$f" > /dev/null 2> "$b.c4" < /dev/null ) && gcc "$W/$b.s" -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" -o "$W/$b.x" 2> "$W/$b.ld4"; then
    ( cd "$W" && run_env timeout -k 5 300 "./$b.x" > "$b.o4" 2> "$b.e4" < "$i" )
  else : > "$W/$b.e4"; fi
  if [ -n "${MATRIX_PLANT:-}" ]; then
    ( cd "$W" && env -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB -u SCRIP_HEAP_MAX_MB SCRIP_HEAP_KB="$KB" SCRIP_GC_STRESS="$ST" timeout -k 5 300 "$SCRIP" "$f" > "$b.u3" 2> /dev/null < "$i" )
    if [ -x "$W/$b.x" ]; then ( cd "$W" && env -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB -u SCRIP_HEAP_MAX_MB SCRIP_HEAP_KB="$KB" SCRIP_GC_STRESS="$ST" timeout -k 5 300 "./$b.x" > "$b.u4" 2> /dev/null < "$i" ); fi
    for m in 3 4; do
      [ -f "$W/$b.u$m" ] || continue
      ap="$(grep -a '^\[GC-[A-Z]*\] *plant' "$W/$b.e$m" | tail -1)"
      if cmp -s "$W/$b.o$m" "$W/$b.u$m"; then printf '%-72s m%s plant-same   %s\n' "$w" "$m" "${ap:-no-plant-banner}"
      else printf '%-72s m%s PLANT-DIFF   %s\n' "$w" "$m" "${ap:-no-plant-banner}"; bad=$((bad+1)); unclean="$unclean $w/plant-m$m"; fi
    done
  fi
  for m in 3 4; do
    s="$(grep -a '^\[CHAIN-WALK\] SUMMARY ' "$W/$b.e$m" | tail -1)"; tot=$((tot+1))
    if [ -z "$s" ]; then printf '%-72s m%s NO-SUMMARY\n' "$w" "$m"; bad=$((bad+1)); unclean="$unclean $w/m$m"; continue; fi
    r="$(num "$s" runs)"; wh="$(num "$s" whole)"; runs_all=$((runs_all+r)); whole_all=$((whole_all+wh))
    d=$(( $(num "$s" offchain-swept) + $(num "$s" missing) + $(num "$s" bad-link) + $(num "$s" frameless) + $(num "$s" nosite) + $(num "$s" no-link) + $(num "$s" cycle) + $(num "$s" unknown-depth) + $(num "$s" differ) ))
    if [ "$wh" = "$r" ] && [ "$d" = 0 ]; then printf '%-72s m%s clean   runs=%s\n' "$w" "$m" "$r"
    else printf '%-72s m%s UNCLEAN runs=%s whole=%s off=%s missing=%s bad-link=%s frameless=%s nosite=%s no-link=%s differ=%s\n' "$w" "$m" "$r" "$wh" "$(num "$s" offchain-swept)" "$(num "$s" missing)" "$(num "$s" bad-link)" "$(num "$s" frameless)" "$(num "$s" nosite)" "$(num "$s" no-link)" "$(num "$s" differ)"; bad=$((bad+1)); unclean="$unclean $w/m$m"; fi
  done
done
[ "$tot" -gt 0 ] || { echo "REFUSE(2): no witness selected"; exit 2; }
echo "MATRIX: $tot witness-mode line(s), $bad unclean; collections whole $whole_all of $runs_all (window ${KB} KB, stress $ST)"
[ "$bad" = 0 ] && exit 0
echo "UNCLEAN:$unclean"; exit 1
