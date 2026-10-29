#!/usr/bin/env bash
# test_demo_repeat_at_scale.sh <demo> [N] -- one SNOBOL4 demo (a DEMO-SCALE.tsv family) run N times (default 30) in mode 3 and mode 4 at its
# DEMO-SCALE.tsv scale and its declared sizes, every run's stdout held to SPITBOL's answer on the same input (cut once, in a directory holding
# corpus/include/*.inc, where SPITBOL resolves -INCLUDE). A defect that shows on a fraction of runs (ceo CEO-1987, 2026-10-26: treebank-match-fence
# at x1024 SIGSEGVs at a jump into unmapped memory on 7-9 of 30 m3 runs and 3-4 of 30 m4 runs; its x1 test input passes 30 of 30) is RED here.
# EXIT 0 every run of both modes printed SPITBOL's answer; 1 at least one did not; 2 REFUSED (no demo, no scrip, no oracle answer).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; S4E="$(cd "$ROOT/.." && pwd)"
D="$S4E/corpus/demos/snobol4"; SCRIP="$ROOT/scrip"; N="${2:-30}"; FAM="${1:-}"
. "$HERE/lib_oracle_flags.sh" || { echo "⛔ REFUSED: cannot load lib_oracle_flags.sh" >&2; exit 2; }
. "$HERE/lib_declared_arena.sh" || { echo "⛔ REFUSED: cannot load lib_declared_arena.sh" >&2; exit 2; }
[ -n "$FAM" ] || { echo "usage: $0 <demo-family> [N]" >&2; exit 2; }
[ -x "$SCRIP" ] || { echo "⛔ REFUSED: scrip not built ($SCRIP)" >&2; exit 2; }
row="$(awk -F'\t' -v f="$FAM" '$1==f' "$D/DEMO-SCALE.tsv")"; [ -n "$row" ] || { echo "⛔ REFUSED: no DEMO-SCALE.tsv row named $FAM" >&2; exit 2; }
P="$D/$(cut -f2 <<<"$row")"; SRC="$D/$(cut -f3 <<<"$row")"; SCALE="$(cut -f4 <<<"$row")"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "⛔ REFUSED: no SPITBOL ($SBL)" >&2; exit 2; }
SWD="$(declared_switches_beside "$P")" && OAD="$(declared_oracle_args_beside "$P")" || { echo "⛔ REFUSED: $FAM's declared sizes are refused" >&2; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/cwd" && cp -p "$S4E/corpus/include/"*.inc "$W/cwd/"
for ((i=0;i<SCALE;i++)); do cat "$SRC"; done > "$W/in"
(cd "$W/cwd" && timeout -k 5 120 "$SBL" $(sbl_lang_flags) $OAD "$P" < "$W/in" > "$W/want" 2> /dev/null); orc=$?
[ "$orc" = 0 ] && [ -s "$W/want" ] || { echo "⛔ REFUSED: SPITBOL gave no answer for $FAM at x$SCALE (rc=$orc)" >&2; exit 2; }
"$SCRIP" --compile --out="$W/p.s" "$P" < /dev/null 2> "$W/c.err" && gcc "$W/p.s" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/p4" 2>> "$W/c.err" || { echo "⛔ $FAM m4 does not build: $(head -1 "$W/c.err")"; exit 1; }
bad3=0; bad4=0; first=""
for ((i=1;i<=N;i++)); do
  (cd "$W/cwd" && timeout -k 5 120 "$SCRIP" --run $SWD "$P" < "$W/in" > "$W/o3" 2> "$W/e3"); cmp -s "$W/o3" "$W/want" || { bad3=$((bad3+1)); [ -n "$first" ] || first="m3 run $i: $(head -1 "$W/e3" | cut -c1-200)"; }
  (cd "$W/cwd" && timeout -k 5 120 "$W/p4" $SWD < "$W/in" > "$W/o4" 2> "$W/e4"); cmp -s "$W/o4" "$W/want" || { bad4=$((bad4+1)); [ -n "$first" ] || first="m4 run $i: $(head -1 "$W/e4" | cut -c1-200)"; }
done
echo "DEMO_REPEAT demo=$FAM scale=x$SCALE runs=$N m3_bad=$bad3 m4_bad=$bad4 oracle=$SBL tree=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)"
[ -z "$first" ] || echo "  first bad: $first"
[ "$bad3" = 0 ] && [ "$bad4" = 0 ]
