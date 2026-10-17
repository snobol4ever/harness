#!/usr/bin/env bash
# DEMO/BEAUTY DESCENT SWEEP — the descent instrument for stdin-driven demos.
# test_rsp_descent_sweep.sh runs every program with </dev/null, which is correct for the rung/regression
# suites but VACUOUS for the corpus demos: claws5/json/treebank/calculator all read their corpus from
# stdin ("sbl -b -P 34000 claws5.sno < claws5.input") and produce a pinned sibling .ref.  Graded with an
# empty stdin they emit nothing, agree with an oracle that also emits nothing, and score green while
# testing zero lines of the program (the s59 "empty==empty is not agreement" conviction).
# This runner feeds <prog>.input when present and grades against the pinned <prog>.ref when present,
# falling back to a live oracle run with the same stdin.  Classification vocabulary is IDENTICAL to
# test_rsp_descent_sweep.sh so the two boards concatenate.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.
cd "$(dirname "$0")/../../SCRIP"
ROOT=$PWD
OUT=${1:-/tmp/demo_sweep.txt}; : > "$OUT"
. "$(dirname "${BASH_SOURCE[0]}")/lib_oracle_flags.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_oracle_flags.sh -- the ONE oracle-flag authority (s200/s255)." >&2; exit 3; }
: "${SWEEP_ORACLE:=$S4A/x64/bin/sbl}"   # CORRECTNESS oracle -- generates/verifies .ref, not timing
: "${DEMO_DIRS:=$S4E/corpus/demos $S4E/corpus/tests/snobol4/beauty_suite}"
: "${DEMO_TIMEOUT:=60}"
for src in $(find $DEMO_DIRS -name '*.sno' 2>/dev/null | sort); do
  d=$(dirname "$src"); b=${src%.sno}
  IN=/dev/null; [ -f "$b.input" ] && IN=$b.input
  tag=$(printf '%s' "$src" | md5sum | cut -c1-10)
  S=/tmp/ddw.$tag.s; X=/tmp/ddw.$tag.x; RE=/tmp/ddw.$tag.rerr
  # ⛔ NOT -P: this sbl build rejects it ("Illegal option -P"), which silently makes the oracle emit
  # NOTHING and grades every no-.ref program DIFF against an empty string.  Caught by the hello.sno
  # control row.  The demo header comments quote -P 34000 from a DIFFERENT spitbol build; do not restore it.
  if [ -f "$b.ref" ]; then ORA=$(cat "$b.ref"); else ORA=$(cd "$d" && timeout -k 5 $DEMO_TIMEOUT "$SWEEP_ORACLE" $(sbl_lang_flags) "$src" < "$IN" 2>/dev/null); fi
  if ! SNO_LIB="$d" timeout -k 5 $DEMO_TIMEOUT "$ROOT/scrip" --compile "$src" </dev/null > $S 2>/dev/null; then st=COMPILE_FAIL
  elif ! gcc -no-pie $S -L "$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -o $X 2>/dev/null; then st=ASM_FAIL
  else
    RO=$(cd "$d" && timeout -k 5 $DEMO_TIMEOUT $X < "$IN" 2>$RE); rc=$?
    if   grep -q "BOMB-RETURN"  $RE; then case "$ORA" in "$RO"*) st=DESCENT_OK;; *) st=BOMB_RETURN_BAD;; esac
    elif grep -q "BOMB-FRETURN" $RE; then st=BOMB_FRETURN
    elif grep -q "BOMB-NRETURN" $RE; then st=BOMB_NRETURN
    elif [ $rc -eq 124 ]; then st=TIMEOUT
    elif [ $rc -ge 128 ]; then st=SIG$((rc-128))
    elif [ "$RO" = "$ORA" ]; then st=PASS
    else st=DIFF; fi
  fi
  rm -f $S $X $RE
  echo "$st ${src#$S4E/corpus/tests/snobol4/}" >> "$OUT"
done
sort -o "$OUT" "$OUT"
awk '{print $1}' "$OUT" | sort | uniq -c | sort -rn
echo "detail: $OUT"
