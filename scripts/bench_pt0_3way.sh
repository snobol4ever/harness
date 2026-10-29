#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_pt0_3way.sh — PT-0: the 3-way (sbl / m3 / m4) same-moment interleaved baseline.
# Extends the bench_sno_match4.sh 2-way (sbl/m4) protocol with the m3 --run arm, because the PT
# front's question is where match wall-clock goes in BOTH shipped modes, not just the compiled one.
# ⛔ WHY THIS EXISTS AND bench_sno_match4.sh COULD NOT BE REUSED (s168, measured): that script's
# mkrep regex is '^(\s*)src\s+(\S+)\s+:F\((\w+)\)$' — it predates the 'src ? pat :F(lbl)' line
# shape every *-match.sno in the corpus carries today, so mkrep raises NameError on ind for EVERY
# program and the run dies at 'claws5-match BUILD FAIL'.  The tape below accepts the '?' form.
# LAWS CARRIED OVER UNCHANGED (s143/s141/s108):
#   * interleaved SAME-MOMENT samples only — one iteration runs all three engines back to back;
#   * odd sample count, median = middle of the sorted samples; RATIOS are the deliverable, absolute
#     ms are NOT (s143: identical bytes measured 51ms and 71ms on treebank minutes apart);
#   * identity gate first — an engine whose stdout differs is not timed, it is a bug report.
# ⛔ THE 1x WINDOW IS BELOW THE NOISE FLOOR (s168, measured): one pass over the 100KB treebank
# input is 4-10ms, of which scrip's own COMPILE is ~7ms, so a 1x m3 number times the compiler and
# not the pattern engine.  --reps N mounts the standard tape (match re-run N+1 times on one loaded
# subject) to lift the match into a measurable window; --reps 0 keeps the raw 1x program.
# ⛔ ORACLE AUTHORITY: `-bf`, NEVER `-b` (RULES.md, s189 row `scorecard-oracle-case`).  `-f` is the oracle's LANGUAGE
# SWITCH (manual v3.7 p.162/p.266 note 10) -- SPITBOL CASE-FOLDS NAMES BY DEFAULT and RULES.md declares SCRIP CASE-SENSITIVE,
# so under plain `-b` the identity gate grades SCRIP against an answer it is FORBIDDEN to produce.  This is not academic for
# this script: folding MANUFACTURES phantom duplicate labels, and `treebank.sno`'s five Init_list/init_list-style pairs made
# the oracle report `ERROR 217 x5` -- which s168 recorded as "the workhorse trio is a DUO, the allocating half does not run".
# It runs.  Converted s193 (seat3, row `treebank-allocating`), and the conversion is MEASURED INERT for the two rows that
# predate it: `treebank-match` and `treebank-match-fence` are BYTE-IDENTICAL under -b and -bf on VBGinTASA.dat, so the s168
# baseline numbers are not invalidated by this change.
# ⛔ ASYMMETRY, STATED NOT HIDDEN: m3 and sbl both COMPILE-THEN-RUN inside the timed window; the m4
# arm times a PREBUILT binary.  --compile-cost prints scrip's compile-only wall so the reader can
# bound it.  RT_OPT is whatever out/libscrip_rt.so was built with — LABEL REPORTED NUMBERS WITH IT.
# Usage: bash ../harness/scripts/bench_pt0_3way.sh [--progs "a b c"] [--reps N] [--samples N] [--compile-cost]
set -uo pipefail
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"; RT="${RT_DIR:-$HERE/../../SCRIP/out}"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_oracle_flags.sh -- the ONE oracle-flag authority (s200/s255)." >&2; exit 3; }
SBL="${SBL:-$(sbl_clean_bin)}"; CORPUS="${CORPUS:-$S4E/corpus}"; D="$CORPUS/demos"   # BENCHMARK oracle (s255)
W="${W:-$(mktemp -d)}"; N="${SAMPLES:-7}"; REPS="${REPS:-2000}"; CCOST=0
PROGS="${PROGS:-treebank-match treebank-match-fence}"
while [ $# -gt 0 ]; do case $1 in --progs) PROGS="$2"; shift 2;; --reps) REPS="$2"; shift 2;; --samples) N="$2"; shift 2;; --compile-cost) CCOST=1; shift;; *) echo "unknown arg $1"; exit 2;; esac; done
input_of() { case $1 in treebank|treebank-alloc|treebank-match|treebank-match-fence) echo "$D/VBGinTASA.dat";; claws5-match) echo "$D/CLAWS5inTASA.dat";; json-match) echo "$D/twitter.json";; *) echo "$D/$1.input";; esac; }
mktape() { python3 - "$1" "$2" "$3" << 'PYEOF'
import re, sys
src_path, out_path, reps = sys.argv[1], sys.argv[2], int(sys.argv[3])
lines = open(src_path).read().splitlines(); mi = None
for i, l in enumerate(lines):
    m = re.match(r'^(\s*)(\S+)\s+\?\s+(\S+)\s+:F\((\w+)\)\s*$', l)
    if m: mi, ind, subj, pat, flab = i, m.group(1), m.group(2), m.group(3), m.group(4)
if mi is None: sys.exit("no 'subject ? pattern :F(label)' line in " + src_path)
tail = [ind+'ZN             =  %d'%reps, ind+'ZI             =  0',
 'benchloop'.ljust(max(len(ind),10))+subj+'            ?  '+pat+'   :F('+flab+')',
 ind+'ZI             =  ZI + 1',
 ind+'LT(ZI, ZN)                                  :S(benchloop)',
 ind+"OUTPUT         =  'matched bytes=' SIZE("+subj+") :(END)",
 flab.ljust(max(len(ind),10))+"OUTPUT         =  'Pattern match failed'", 'END']
open(out_path,'w').write('\n'.join(lines[:mi]+tail)+'\n')
PYEOF
}
med() { printf '%s\n' "$@" | sort -n | sed -n "$(( (N+1)/2 ))p"; }
[ -x "$SBL" ] || { echo "⛔ ORACLE ABSENT: $SBL — every ratio below would be fiction. Build /home/resources/spitbol-bench-oracle (see RULES.md Oracles) -- seats do not clone x64 (s255)."; exit 3; }
RTO=$(grep -o '\-O[0-9]' "$HERE/../../SCRIP/Makefile" 2>/dev/null | head -1)
echo "# PT-0 3-way baseline · reps=$REPS · samples=$N · median-of-$N · RT_OPT=${RTO:-unknown} · $(date -u +%Y-%m-%dT%H:%M:%SZ)"
for p in $PROGS; do
  IN="$(input_of "$p")"; SRC="$D/$p.sno"
  [ -f "$SRC" ] || { echo "$p: NO SOURCE $SRC"; continue; }
  [ -f "$IN" ]  || { echo "$p: NO INPUT $IN";  continue; }
  RUN="$SRC"
  if [ "$REPS" != 0 ]; then mktape "$SRC" "$W/$p-rep.sno" "$REPS" || { echo "$p: TAPE FAIL"; continue; }; RUN="$W/$p-rep.sno"; fi
  "$SCRIP" --compile --out="$W/$p.s" "$RUN" < /dev/null > /dev/null 2>&1
  gcc -no-pie "$W/$p.s" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$W/$p.m4" 2>/dev/null || { echo "$p: M4 BUILD FAIL"; continue; }
  so="$(timeout -k 5 600 "$SBL" $(sbl_lang_flags) "$RUN" < "$IN" 2>/dev/null)"
  o3="$(timeout -k 5 600 "$SCRIP" "$RUN" < "$IN" 2>/dev/null)"
  o4="$(timeout -k 5 600 "$W/$p.m4" < "$IN" 2>/dev/null)"
  [ "$so" = "$o3" ] && [ "$so" = "$o4" ] || { echo "$p: IDENTITY FAIL sbl=[$so] m3=[$o3] m4=[$o4]"; continue; }
  s=(); m3=(); m4=()
  for i in $(seq 1 "$N"); do
    t0=$(date +%s%N); timeout -k 5 600 "$SBL" $(sbl_lang_flags) "$RUN" < "$IN" > /dev/null 2>&1; t1=$(date +%s%N); s+=( $(( (t1-t0)/1000000 )) )
    t0=$(date +%s%N); timeout -k 5 600 "$SCRIP" "$RUN" < "$IN" > /dev/null 2>&1; t1=$(date +%s%N); m3+=( $(( (t1-t0)/1000000 )) )
    t0=$(date +%s%N); timeout -k 5 600 "$W/$p.m4" < "$IN" > /dev/null 2>&1;      t1=$(date +%s%N); m4+=( $(( (t1-t0)/1000000 )) )
  done
  sm=$(med "${s[@]}"); m3m=$(med "${m3[@]}"); m4m=$(med "${m4[@]}")
  r3=$(python3 -c "print(f'{$m3m/$sm:.2f}')" 2>/dev/null); r4=$(python3 -c "print(f'{$m4m/$sm:.2f}')" 2>/dev/null)
  cc=""
  if [ "$CCOST" = 1 ]; then c=(); for i in $(seq 1 "$N"); do t0=$(date +%s%N); "$SCRIP" --compile --out=/dev/null "$RUN" < /dev/null > /dev/null 2>&1; t1=$(date +%s%N); c+=( $(( (t1-t0)/1000000 )) ); done; cc=" compile_only=$(med "${c[@]}")ms"; fi
  echo "$p: sbl=${sm}ms m3=${m3m}ms m4=${m4m}ms  m3/sbl=${r3}x m4/sbl=${r4}x  identity=OK$cc"
done
