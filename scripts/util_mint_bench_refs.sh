#!/usr/bin/env bash
# util_mint_bench_refs.sh -- MINT AND VERIFY THE .ref FILES OF THE STANDALONE BENCHMARK PROGRAMS.
#
#   bash ../harness/scripts/util_mint_bench_refs.sh            # verify only: report every disagreement, write nothing
#   bash ../harness/scripts/util_mint_bench_refs.sh --write    # (re)mint each .ref from the ORACLE, then verify
#   bash ../harness/scripts/util_mint_bench_refs.sh --dir <d>  # restrict to one directory
#
# ⭐ WHY (Lon s265): after the standalone revamp a benchmark .sno IS the application, so it HAS a real
#   answer and that answer is gradeable.  Before, sixteen .ref files pinned the harness artifact
#   "check: <n>" and two programs (ident_call1, ident_call2) had no .ref at all -- they were graded
#   against nothing and read as passing.
#
# ⛔ SMALL INPUT, NOT THE BENCHMARK CORPUS (Lon s265, verbatim: *"Do not use the HUGE files for the REF
#   files.  Use the INPUT versions which are small for that reason."*).  stdin for a ref run is, in order:
#     <prog>.input  ->  <family>.input  ->  /dev/null          family = prog minus -match/-match-fence
#   The big <family>.dat stays what the TIMED arm feeds.  Correctness is graded on the small input;
#   throughput is measured on the large one.  A .ref minted from the .dat would be a 163 KB pin that
#   nobody reads and every diff drowns in.
#
# ⛔ THE ORACLE MINTS, SCRIP IS GRADED -- never the reverse.  sbl -bf is the correctness authority
#   (RULES.md § Oracles, s189: -bf ALWAYS, folding manufactures phantom duplicate labels).  A .ref
#   captured from SCRIP would pin SCRIP's own bugs and the suite would grade itself.
set -u
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
# The oracle cuts each ref at the size the kernel declares for it, <stem>.oracle_args (ceo CEO-1353, RULES.md clause 8 (g)(3)), never a size
# typed here: MEASURED 2026-10-03 (the coo, sbl fd9b552b) every corpus/benchmarks/snobol4 kernel answers its ref at sbl's own defaults, two readings.
. "$HERE/lib_declared_arena.sh" || { echo "REFUSE(2): cannot load lib_declared_arena.sh"; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_oracle_flags.sh -- the ONE oracle-flag authority (s200)." >&2; exit 3; }
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"; SBL="${SBL:-$S4A/x64/bin/sbl}"
T="${TIMEOUT:-60}"; WRITE=0; DIRS=""
while [ $# -gt 0 ]; do case "$1" in
  --write) WRITE=1; shift ;;
  --dir)   DIRS="$DIRS $2"; shift 2 ;;
  *) echo "usage: util_mint_bench_refs.sh [--write] [--dir <d>]" >&2; exit 2 ;;
esac; done
[ -n "$DIRS" ] || DIRS="$S4E/corpus/benchmarks/snobol4 $S4E/corpus/benchmarks/demo"
[ -x "$SBL" ] || { echo "⛔ ORACLE MISSING: $SBL -- refusing to mint or grade (absent-oracle false-FAIL class)." >&2; exit 3; }
[ -x "$SCRIP" ] || { echo "⛔ scrip not built at $SCRIP" >&2; exit 3; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
# stdin for a REF run: the SMALL input, never the .dat  (Lon s265)
ref_stdin() { local p="$1" d n f; d="$(dirname "$p")"; n="$(basename "${p%.sno}")"
  [ -f "$d/$n.input" ] && { echo "$d/$n.input"; return; }
  f="$(sed 's/-match\(-fence\)\?$//' <<<"$n")"
  [ -f "$d/$f.input" ] && { echo "$d/$f.input"; return; }
  echo /dev/null; }
tot=0; minted=0; ok3=0; bad3=0; ok4=0; bad4=0; orfail=0; BAD3=""; BAD4=""; ORF=""
for d in $DIRS; do
  [ -d "$d" ] || continue
  for sno in "$d"/*.sno; do
    [ -e "$sno" ] || continue
    b="$(basename "${sno%.sno}")"; ref="${sno%.sno}.ref"; in="$(ref_stdin "$sno")"
    tot=$((tot+1))
    orc="$W/$b.orc"
    # ⛔ CAPTURE THE STATUS, THEN TEST IT -- never read `$?` inside `if ! cmd; then`, where it is the status of the
    # NEGATION and not of the command (RULES/CLAUDE.md: `$?` after a pipeline or a compound answers a narrower
    # question than you think you asked). MEASURED 2026-09-04 with a synthetic oracle that prints output and then
    # SIGSEGVs: this arm correctly REFUSED to mint all 23 refs, and printed `ORACLE-FAIL rc=0` for every one of
    # them -- a refusal whose own diagnostic said the oracle had succeeded. ⭐ The REFUSAL was never wrong; only
    # the sentence explaining it was, which is the shape that survives review indefinitely because the behaviour
    # under it is correct (row every-ref-cutting-path-refuses-when-the-oracle-dies-mid-cut, ceo -> hq_T, on
    # seat07's finding that `sbl -bf` SIGSEGVs on ~half its ERROR 212 runs while still printing a diagnostic).
    oa="$(declared_oracle_args_beside "$sno")" || { printf '%-26s ⛔ ORACLE-FAIL %s\n' "$b" "its .oracle_args is refused"; orfail=$((orfail+1)); ORF="$ORF $b"; continue; }
    timeout -k 5 "$T" "$SBL" $(sbl_lang_flags) $oa "$sno" >"$orc" 2>"$W/$b.orcerr" <"$in"; orc_rc=$?
    if [ "$orc_rc" -ne 0 ]; then
      orc_why="rc=$orc_rc"; [ "$orc_rc" -ge 128 ] && orc_why="KILLED BY SIGNAL $((orc_rc-128)) (rc=$orc_rc) -- output is TRUNCATED, never a ref"
      printf '%-26s ⛔ ORACLE-FAIL %s  %s\n' "$b" "$orc_why" "$(head -1 "$W/$b.orcerr")"; orfail=$((orfail+1)); ORF="$ORF $b"; continue
    fi
    if [ "$WRITE" = 1 ]; then cp "$orc" "$ref"; minted=$((minted+1)); fi
    [ -f "$ref" ] || { printf '%-26s ⛔ NO .ref (run --write to mint)\n' "$b"; continue; }
    m3="$W/$b.m3"; timeout -k 5 "$T" "$SCRIP" "$sno" >"$m3" 2>/dev/null <"$in"
    v3=DIFF; cmp -s "$m3" "$ref" && { v3=PASS; ok3=$((ok3+1)); } || { bad3=$((bad3+1)); BAD3="$BAD3 $b"; }
    v4=DIFF
    if "$SCRIP" --compile "$sno" >"$W/$b.s" 2>/dev/null && [ -s "$W/$b.s" ] \
       && gcc -no-pie "$W/$b.s" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$W/$b.prog" 2>/dev/null; then
      timeout -k 5 "$T" "$W/$b.prog" >"$W/$b.m4" 2>/dev/null <"$in"
      cmp -s "$W/$b.m4" "$ref" && { v4=PASS; ok4=$((ok4+1)); } || { bad4=$((bad4+1)); BAD4="$BAD4 $b"; }
    else v4=BUILD-ERR; bad4=$((bad4+1)); BAD4="$BAD4 $b"; fi
    printf '%-26s ref=%-7s in=%-16s m3=%-4s m4=%s\n' "$b" "$(wc -c <"$ref")B" "$(basename "$in")" "$v3" "$v4"
  done
done
echo
echo "programs: $tot   minted: $minted   m3 PASS $ok3 / FAIL $bad3   m4 PASS $ok4 / FAIL $bad4   oracle-fail: $orfail"
[ -n "$BAD3" ] && echo "⛔ m3 DIFF:$BAD3"
[ -n "$BAD4" ] && echo "⛔ m4 DIFF/BUILD-ERR:$BAD4"
[ -n "$ORF"  ] && echo "⛔ ORACLE-FAIL:$ORF"
[ "$bad3" -eq 0 ] && [ "$bad4" -eq 0 ] && [ "$orfail" -eq 0 ]
