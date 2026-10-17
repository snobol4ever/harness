#!/usr/bin/env bash
# update_icon_bench_asm.sh — produce + MAINTAIN side-by-side x86 .s artifacts for the Icon
# benchmark corpus.
#
# For each <bench>.icn matching GLOB, compile it with the CURRENT SCRIP emitter
# (--compile --target=x86). If it compiles to non-empty output that ASSEMBLES cleanly with
# `as`, write/update the sibling <bench>.s. The .s is rewritten ONLY when its CANONICALIZED
# content actually changes — address-derived bb<NNNNN> labels (which vary run-to-run under
# ASLR but keep a stable order of appearance) are renumbered to a deterministic bb<00001>
# sequence, so a git diff reflects a REAL emitter change, never run-to-run churn.
#
# Programs that REFUSE (native arm pending), fail to compile, or fail to assemble are
# REPORTED and their existing .s is left untouched (legacy artifact retained until the
# emitter covers them; a later run regenerates it automatically).
#
# Usage:
#   ../harness/scripts/update_icon_bench_asm.sh [GLOB]
#     GLOB defaults to '*.icn' (the whole Icon benchmark corpus).
#   ICON_CORPUS=<dir>   override the corpus icon dir (default /home/claude/corpus/benchmarks/icon)
#   CHECK=1             dry-run: report what WOULD change, write nothing (exit 1 if any drift)
#
# Exit: 0 normally; with CHECK=1, 0 if every .s is already current, 1 if any would change.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
CORPUS="${ICON_CORPUS:-$S4E/corpus/benchmarks/icon}"
GLOB="${1:-*.icn}"
# ⛔⭐ $1 IS A GLOB, NOT A COMMIT LABEL, AND THE SIBLING REGENS TAKE A LABEL THERE (coo 2026-09-11).
# util_regen_benchmark_s_artifacts.sh, util_regen_demo_s_artifacts.sh and util_regen_prolog_bench_s_artifacts.sh
# are all invoked as `<script> "<rung>"` and the handoff cure line in util_verify_s_artifacts_owed.sh prints them
# that way, side by side with this one. So the obvious call `update_icon_bench_asm.sh "COO-55 handoff regen"`
# sets GLOB to that sentence, matches ZERO files, and this script PRINTS total=0 AND EXITS 0 -- a green that
# examined nothing, while the verifier one line over still says 20 artifacts are owed.
# ⛔ I MADE EXACTLY THAT MISTAKE TWICE, A DAY APART, AND READ total=0 AS "nothing owed" BOTH TIMES. The .s debt
# then sat in every seat's handoff_status for a day with a green regen behind it. THE INSTRUMENT LAWS: an
# instrument that reports success while doing nothing is the recurring failure, and a missing population is
# rc=2, never green.
CHECK="${CHECK:-0}"
[ -x "$SCRIP" ] || { echo "FATAL: $SCRIP not built (run ../harness/scripts/build_scrip.sh)"; exit 2; }
[ -d "$CORPUS" ] || { echo "FATAL: corpus dir $CORPUS not found"; exit 2; }
case "$CORPUS" in
  */corpus/icon|*/corpus/tests/icon/*)
    echo "REFUSED: $CORPUS is the Icon rung TEST-PROGRAM suite, not a .s-artifact tree."
    echo "         Lon directive 2026-07-11: .s artifacts are maintained for the DEMO and BENCHMARK"
    echo "         corpora ONLY, never for the ~299 rung test programs. Pointing ICON_CORPUS here is"
    echo "         what minted 294 stale artifacts that then LIED about the compiler's real output."
    echo "         Sweep the COMPILER (scrip --compile), not the artifacts. See PROC-ICON-BENCH-ASM.md."
    exit 2 ;;
esac
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
canon_pl="$TMP/canon.pl"
cat > "$canon_pl" <<'PERL'
my %m; my $i = 0;
local $/; my $s = <>;
$s =~ s/(?<=[A-Za-z])(\d{3,})_/ (exists $m{$1} ? $m{$1} : ($m{$1} = sprintf("%05d", ++$i))) . "_" /ge;
$s =~ s{"/[^"\n]*/([^/"\n]+\.icn)"}{"$1"}g;
print $s;
PERL
# ⛔⭐ THE SECOND CANONICALISATION LINE ABOVE IS NOT COSMETIC -- IT IS WHY THIS CHECK CAN EVER READ
# GREEN TWICE IN A ROW. `--compile` writes the source path it was HANDED into the .file directive and
# into every line-mark .string, and this loop hands it an ABSOLUTE path, so the committed artifact
# recorded the absolute path of whichever root last regenerated it. Measured 2026-09-10 (hq_B): all 20
# owed icon bench artifacts differed from HEAD by NOTHING BUT `/home/claude_U/` -> `/home/claude_B/`
# -- zero content lines across all 20. ⭐ SO THE DEBT WAS NEVER PAYABLE: every seat that ran the regen
# to clear a blocking handoff handed the NEXT seat the identical 20-file debt, in the other direction,
# for ever. A check whose green state no tree can hold is the cry-wolf shape this file's own LIB note
# already names, one level up: there the false positives hid the true ones, here the artifact churn
# does. Stripping the directory leaves the basename, which is all a debugger resolves anyway (it
# resolves relative to the compilation directory), and makes the artifact describe the PROGRAM instead
# of the seat. Do NOT "fix" this by passing a relative path instead: that works (measured -- scrip
# emits "version.icn" when handed "version.icn"), but it silently changes what a CERR line means when
# a program `link`s a sibling by relative path, which is the trap the jcon demos already sprang once.
upd=0; new=0; same=0; exc=0; cerr=0; aerr=0; nd=0; total=0; drift=0; lib=0
for icn in "$CORPUS"/$GLOB; do
  [ -f "$icn" ] || continue
  total=$((total + 1))
  base="${icn%.icn}"; s="$base.s"; name="$(basename "$base")"
  # ⛔⭐ A LINK-ONLY LIBRARY IS NOT A FAILING PROGRAM. An .icn with no `procedure main` is a link
  # input (Icon `link options` / `post` / `shuffle`), never a standalone program -- compiling it
  # alone CANNOT succeed, so classifying it CERR "genuine compile error" reports a permanent,
  # unfixable false positive. Measured 2026-08-29 (hq_B): options/post/shuffle each have zero
  # `procedure main` (queens.icn has 1, for contrast), and those three were 3 of the 23 items this
  # script's consumer reported as OWED -- inside handoff_status.sh, the ONE sanctioned source of
  # "HANDOFF COMPLETE". ⭐ THE COST IS NOT THE THREE LINES, IT IS THE OTHER TWENTY: a check that
  # always cries wolf trains every seat to discount its output, so the REAL owed artifacts sitting
  # beside them stay unread. The false positives are what make the true positives invisible.
  if ! grep -qE '^[[:space:]]*procedure[[:space:]]+main[[:space:]]*\(' "$icn"; then
    echo "LIB      $name"; lib=$((lib + 1)); continue
  fi
  raw="$TMP/$name.raw"; can="$TMP/$name.s"
  if ! timeout -k 5 30 "$SCRIP" --compile --target=x86 "$icn" < /dev/null > "$raw" 2>"$TMP/err"; then
    if grep -q '\[SMX\]' "$TMP/err"; then echo "REFUSED  $name"; exc=$((exc + 1));
    else echo "CERR     $name"; cerr=$((cerr + 1)); fi
    continue
  fi
  if grep -q '\[SMX\]' "$TMP/err" || [ ! -s "$raw" ]; then echo "REFUSED  $name"; exc=$((exc + 1)); continue; fi
  raw2="$TMP/$name.raw2"; raw3="$TMP/$name.raw3"
  timeout -k 5 30 "$SCRIP" --compile --target=x86 "$icn" < /dev/null > "$raw2" 2>/dev/null
  timeout -k 5 30 "$SCRIP" --compile --target=x86 "$icn" < /dev/null > "$raw3" 2>/dev/null
  perl "$canon_pl" < "$raw"  > "$can"
  perl "$canon_pl" < "$raw2" > "$TMP/$name.s2"
  perl "$canon_pl" < "$raw3" > "$TMP/$name.s3"
  if ! diff -q "$can" "$TMP/$name.s2" >/dev/null 2>&1 || ! diff -q "$can" "$TMP/$name.s3" >/dev/null 2>&1; then
    echo "NONDET   $name  (emission order varies run-to-run — not maintainable until deterministic)"; nd=$((nd + 1)); continue
  fi
  asmnote=""
  if ! as "$can" -o "$TMP/$name.o" 2>"$TMP/aserr"; then asmnote="  [ASMWARN: not standalone-assemblable]"; aerr=$((aerr + 1)); fi
  if [ -f "$s" ] && diff -q "$s" "$can" >/dev/null 2>&1; then
    same=$((same + 1)); continue
  fi
  if [ -f "$s" ]; then label="UPDATED"; upd=$((upd + 1)); else label="NEW"; new=$((new + 1)); fi
  drift=$((drift + 1))
  if [ "$CHECK" = "1" ]; then echo "WOULD-$label  $name$asmnote";
  else cp "$can" "$s"; echo "$label  $name$asmnote"; fi
done
if [ "${total:-0}" -eq 0 ] 2>/dev/null; then
    echo "⛔ REFUSED-TO-REGENERATE rc=2: the glob '$GLOB' matched ZERO .icn files under $CORPUS" >&2
    echo "   Nothing was examined, so this run proves nothing about whether the artifacts are current." >&2
    echo "   ⛔ \$1 IS A GLOB, NOT A COMMIT LABEL -- the sibling regen scripts take a label there and this one does not." >&2
    echo "   cure: run it with NO argument for the whole Icon benchmark corpus, or pass a glob that matches, e.g. 'deal*.icn'." >&2
    exit 2
fi
echo "--- icon bench .s: total=$total new=$new updated=$upd unchanged=$same refused=$exc nondet=$nd lib=$lib compile-err=$cerr asm-warn=$aerr ---"   # lib = link-only inputs with no `procedure main`; not programs, never a compile error
if [ "$CHECK" = "1" ] && [ "$drift" -gt 0 ]; then
  echo "CHECK: $drift artifact(s) out of date — run ../harness/scripts/update_icon_bench_asm.sh to refresh."; exit 1
fi
exit 0
