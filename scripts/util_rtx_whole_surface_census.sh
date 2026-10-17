#!/usr/bin/env bash
# util_rtx_whole_surface_census.sh — 0(d) OVER THE *WHOLE* STILL-C RUNTIME SURFACE.
#
# Minted s227 (2026-07-30) on the s226 rule: "0(d) IS NOT A FILTER OVER A STATIC
# SHORTLIST — run it over the WHOLE still-C surface or the symbols it would
# promote are never candidates."  s226 measured rt_flat_wire_adopt at static
# rank 16/46 and dynamic rank 4/20 — a FALSE NEGATIVE, the silent direction.
# Three sessions running, static call-site rank has been anti-correlated with
# dynamic hotness.  This script removes the static shortlist from the loop.
#
# SURFACE DERIVATION (from the TREE, never a checked-in list — the phantom class):
#   every T symbol defined by an object compiled from src/runtime/**.c,
#   MINUS the already-ported RTX_FUNC names in src/runtime/rtx/*.s,
#   MINUS their c_* fallbacks,
#   MINUS the rtx scaffolding itself.
# What remains is exactly "C runtime code that could still be replaced by asm".
#
# MEASUREMENT: util_rtx_count_syms.sh per program (it counts arbitrary,
# still-pure-C symbols, which util_rtx_arm_census.sh structurally cannot).
# Totals are summed across the corpus and ranked by ENTRIES.
#
# Usage: bash ../harness/scripts/util_rtx_whole_surface_census.sh [corpus_dir] [out_tsv]
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -u
ROOT="$(cd "$(dirname "$0")/../../SCRIP" && pwd)"
CORPUS="${1:-$S4E/corpus/benchmarks/snobol4}"
OUT="${2:-/tmp/whole_surface_census.tsv}"
SO="$ROOT/out/libscrip_rt.so"
# ⛔ THE .so MUST BE CURRENT OR THIS VERDICT IS ABOUT A BUILD NOBODY SHIPS (row stale-binary-preflight-also-
# covers-out-libscrip_rt-so). A stale OLDER .so still exports what src/ deleted and cannot show what src/
# added, so a clean nm surface here is a FALSE GREEN. Shared authority -- sourced, never copied.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_build_currency.sh"
assert_so_current "$SO" "$ROOT" || exit 2
[ -f "$SO" ] || { echo "FATAL: $SO missing — run make libscrip_rt first"; exit 1; }
[ -x "$ROOT/scrip" ] || { echo "FATAL: $ROOT/scrip missing"; exit 1; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
# ---- 1. runtime-defined T symbols, straight off the objects -------------------
: > "$TMP/rt_syms.txt"
for o in $(find "$ROOT/out" -name '*.o' -newermt '1970-01-01' 2>/dev/null); do
  b="$(basename "$o" .o)"
  find "$ROOT/src/runtime" -name "$b.c" -o -name "$b.cpp" 2>/dev/null | grep -q . || continue
  nm --defined-only "$o" 2>/dev/null | awk '$2=="T"{print $3}' >> "$TMP/rt_syms.txt"
done
sort -u "$TMP/rt_syms.txt" -o "$TMP/rt_syms.txt"
# ---- 2. subtract what is already assembly ------------------------------------
grep -rhoP 'RTX_FUNC\(\s*\K[A-Za-z0-9_]+' "$ROOT"/src/runtime/rtx/*.s 2>/dev/null | sort -u > "$TMP/ported.txt"
nm -D --defined-only "$SO" | awk '$2=="T"{print $3}' | sort -u > "$TMP/dyn.txt"
: > "$TMP/cand.txt"
while read -r s; do
  case "$s" in c_*|rtx_*|_*) continue ;; esac
  grep -qx "$s" "$TMP/ported.txt" && continue          # already asm
  grep -qx "$s" "$TMP/dyn.txt"    || continue          # must be dynamically visible to interpose
  echo "$s" >> "$TMP/cand.txt"
done < "$TMP/rt_syms.txt"
N=$(wc -l < "$TMP/cand.txt")
echo "STILL-C RUNTIME SURFACE: $N symbols (ported: $(wc -l < "$TMP/ported.txt"))"
[ "$N" -gt 0 ] || { echo "FATAL: derived zero candidates"; exit 1; }
# ---- 3. count every candidate on every program -------------------------------
: > "$TMP/tot.txt"
progs=$(ls "$CORPUS"/*.sno 2>/dev/null)
[ -n "$progs" ] || { echo "FATAL: no .sno in $CORPUS"; exit 1; }
for p in $progs; do
  nm_p="$(basename "$p" .sno)"
  inp=""; [ -f "${p%.sno}.input" ] && inp="${p%.sno}.input"
  COUNTSYMS_IN="${inp:-/dev/null}" \
    bash "$ROOT/../harness/scripts/util_rtx_count_syms.sh" "$p" $(cat "$TMP/cand.txt") \
    > "$TMP/r.txt" 2>"$TMP/r.err"
  if ! grep -q 'DYNAMIC CALL COUNT' "$TMP/r.txt"; then
    echo "  $nm_p: NO DATA (see stderr)"; continue
  fi
  # ⛔ THE `/^--- program stdout/{exit}` GUARD IS LOAD-BEARING (added s228, on the
  # script's FIRST EVER RUN).  util_rtx_count_syms.sh deliberately appends the
  # measured program's own stdout after a `---` banner so a broken run cannot
  # masquerade as a measurement — but this awk consumed those lines too, and any
  # benchmark line of the shape `<word>: <number>` parses as a symbol with a huge
  # entry count.  Uncaught, it put `result:` (153,885,529) and `iterations:`
  # (101,000,000) at ranks 1 and 2 of the port queue, above every real symbol.
  # The contaminants are not exported text symbols at all, so the correct filter
  # is also available structurally: intersect with the derived candidate list.
  awk -v CAND="$TMP/cand.txt" '
    BEGIN { while ((getline s < CAND) > 0) ok[s]=1 }
    /^--- program stdout/ { exit }
    NR>2 && NF>=2 && $2+0>0 && ($1 in ok) { print $1"\t"$2 }' "$TMP/r.txt" >> "$TMP/tot.txt"
  n_hot=$(awk '/^--- program stdout/{exit} NR>2 && NF>=2 && $2+0>0' "$TMP/r.txt" | wc -l)
  echo "  $nm_p: $n_hot symbols with nonzero entries"
done
# ---- 4. rank ------------------------------------------------------------------
awk -F'\t' '{e[$1]+=$2; p[$1]++} END{for(k in e) printf "%s\t%d\t%d\n", k, e[k], p[k]}' "$TMP/tot.txt" \
  | sort -t$'\t' -k2,2nr > "$OUT"
echo
echo "=== WHOLE-SURFACE 0(d) RANK — still-C runtime symbols, $CORPUS ==="
printf "%-40s %16s %8s\n" SYMBOL ENTRIES PROGS
head -40 "$OUT" | while IFS=$'\t' read -r s e n; do printf "%-40s %16s %8s\n" "$s" "$e" "$n"; done
echo "(full ranking: $OUT)"
