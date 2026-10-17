#!/bin/bash
# test_demo_full_3way.sh  claws5 + treebank FULL-corpus tri-identity gate (sbl == m3 == m4).
# Encodes the s107 recipe: oracle temp-prepend (-CASE 0 control card + tab &TRIM = 0  never patch corpus).
# ⛔ NO SIZE IS TYPED HERE (ceo CEO-1353, RULES.md clause 8 (g)(3)-(4)): each demo's own <stem>.heap/.stack reach SCRIP in both modes
# and its <stem>.oracle_args reaches sbl, through lib_declared_arena.sh. MEASURED 2026-10-03 (the coo) on these full inputs: treebank
# dies ERROR 246 at sbl's default stack and answers from -s8m (two readings), which treebank.oracle_args declares; claws5 answers at sbl's
# defaults; SCRIP at each demo's declared -d131072k -s4096k is tri-identical in both modes under the shell's own 8 MB ulimit -- the
# s107 "-d512m -i64m, -s256m, ulimit -s unlimited" recipe is no longer a need.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.
set -u
SC=${SC:-$S4E/SCRIP}; D=${D:-$S4E/corpus/demos}
. "$(dirname "${BASH_SOURCE[0]}")/lib_oracle_flags.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_oracle_flags.sh -- the ONE oracle-flag authority (s200/s255)." >&2; exit 3; }
SBL=${SBL:-$S4A/x64/bin/sbl}   # CORRECTNESS oracle -- tri-identity gate, not timing
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
. "$(dirname "${BASH_SOURCE[0]}")/lib_declared_arena.sh" || { echo "⛔ GATE REFUSES (rc=2): cannot load lib_declared_arena.sh"; exit 2; }
fail=0
# ⛔⭐ A MISSING INPUT IS A REFUSAL, NEVER AN ORACLE FAILURE. Until 2026-09-06 this gate named the two
# programs at $D/claws5.sno and $D/treebank.sno, paths the corpus re-grid retired (they are per-program
# subdirectories now). cat printed "No such file or directory", sbl was then handed a file holding only the
# two-line control-card prepend, exited non-zero, and the script printed "claws5: sbl FAILED" and DEMO-FULL
# 3WAY: FAIL. That reads as a correctness verdict about the ORACLE on a run that never happened -- and it was
# quoted as one, in a landing commit message, by an HQ (hq_S, SCRIP 0fc3302b9: "the sbl oracle fails claws5
# and treebank; not SCRIP"). seat04 found it by looking at the script rather than its exit status.
# ⭐ The general form is this house's own: an instrument that cannot measure must REFUSE (rc=2), because a
# script that refuses and a script that ran look identical from the outside if you only read a status.
one() {
  local nm=$1 src=$2 inp=$3 sw oa
  [ -s "$src" ] || { echo "⛔ GATE REFUSES (rc=2): $nm source missing at $src -- this gate cannot measure, and must not report an oracle verdict"; exit 2; }
  [ -s "$inp" ] || { echo "⛔ GATE REFUSES (rc=2): $nm input missing at $inp -- this gate cannot measure, and must not report an oracle verdict"; exit 2; }
  sw="$(declared_switches_beside "$src")" && oa="$(declared_oracle_args_beside "$src")" || { echo "⛔ GATE REFUSES (rc=2): $nm's declared sizes are refused"; exit 2; }
  printf -- '-CASE 0
	&TRIM = 0
' > "$W/$nm.sbl.sno"; cat "$src" >> "$W/$nm.sbl.sno"
  "$SBL" $(sbl_lang_flags) $oa "$W/$nm.sbl.sno" < "$inp" > "$W/$nm.sbl" 2>/dev/null || { echo "$nm: sbl FAILED"; fail=1; return; }
  "$SC/scrip" --run $sw "$src" < "$inp" > "$W/$nm.m3" 2>/dev/null || { echo "$nm: m3 FAILED rc=$?"; fail=1; return; }
  "$SC/scrip" --compile "$src" > "$W/$nm.s" 2>/dev/null && gcc -no-pie "$W/$nm.s" -L"$SC/out" -lscrip_rt -lm -Wl,-rpath,"$SC/out" -o "$W/$nm.prog" 2>/dev/null || { echo "$nm: m4 build FAILED"; fail=1; return; }
  "$W/$nm.prog" $sw < "$inp" > "$W/$nm.m4" 2>/dev/null || { echo "$nm: m4 run FAILED rc=$?"; fail=1; return; }
  if cmp -s "$W/$nm.sbl" "$W/$nm.m3" && cmp -s "$W/$nm.sbl" "$W/$nm.m4"; then echo "$nm: TRI-IDENTICAL ($(wc -l < "$W/$nm.sbl") lines)"; else echo "$nm: DIVERGES"; fail=1; fi
}
one claws5   "$D/snobol4/claws5/claws5.sno"     "$D/snobol4/claws5/CLAWS5inTASA.dat"
one treebank "$D/snobol4/treebank/treebank.sno" "$D/snobol4/treebank/VBGinTASA.dat"
[ "$fail" -eq 0 ] && echo "DEMO-FULL 3WAY: PASS" || echo "DEMO-FULL 3WAY: FAIL"
exit "$fail"
