#!/usr/bin/env bash
# test_gate_sno_mode4_code_call_inherits_the_scc_taint.sh -- A CODE()-COMPILED CALL TO A DEFINE'D FUNCTION INSIDE A
# MODE-4 BINARY REACHES THE FUNCTION WHEN THE PROGRAM WAS COMPILED ON THE NON-SCC PATH.
# Row snobol4-gimpel-class-diff-both-modes (coo, 2026-09-07), the mode-4 half of gimpel FRSORT_driver (MSORT's SEQ builds
# `N<I> = COUNT(S,C<I>)` through CODE(); the program carries a two-argument OPSYN, so every call is compiled on the
# non-SCC staged path -- optimizer/proc_collect.c scc_taint_graph). MEASURED BEFORE THE CURE (SCRIP 3c61eaae8): the
# nine-line witness below printed n=5 in mode 3 and stopped with ERROR 022 in mode 4; SCRIP_NO_TINY=1 cured it, so the
# in-process fragment JIT -- whose own graph carries no OPSYN and therefore reads scc_program_ok() -- took the staged
# template's TINY signature arm (bb_call_proc_staged.cpp) to a callee whose mode-4 alpha was compiled tainted and never
# carried the role-4 SIG shim, landing in rt_ab_undef_fn_stub. CURE: the mode-4 driver plants `call rt_scc_taint_inherit`
# in the program prologue when the compiler saw the taint (src/driver/scrip.c), and scc_program_ok() honours the
# inherited mark (src/optimizer/proc_collect.c), so fragments in that process are compiled the way its callees were.
# Arms (both modes against the live sbl -bf oracle unless said):
#   T   DEFINE CNT; a two-argument OPSYN; X = CODE("  N = CNT(2,3)  :(END_C)"); :<X>       -- n=5
#   S   SEQ-driven COUNT(S,C<I>) from the gimpel package with the OPSYN present              -- n=4,1
#   F   gimpel FRSORT_driver with its includes (SNO_LIB)                                     -- ISPM / ABRCD
#   U   the T program WITHOUT the OPSYN: its .s carries NO taint mark (emission unchanged), and runs -- n=5
# Population printed beside the verdict. Needs the built binary, gcc, the oracle and the gimpel package; UNPROVEN(2) otherwise.
# Fail-once (2026-09-07 13:1x CDT, coo, MEASURED by rebuilding with the pre-cure driver): 4 of 10 red -- T, S and F in mode 4 (ERROR 022)
# and the T assembly arm (no mark); mode 3 and the untainted U stay green, as they must.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
. "$HERE/lib_gate.sh"; gate_parse_args "$@"
G=sno_mode4_code_call_inherits_the_scc_taint
"$HERE/util_require_fresh.sh" --gate test_gate_$G "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" >/dev/null 2>&1 || { echo "GATE UNPROVEN(2) [$G]: this tree's binary is stale or unbuilt -- run make"; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "GATE UNPROVEN(2) [$G]: lib_oracle_flags.sh unloadable"; exit 2; }
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "GATE UNPROVEN(2) [$G]: sbl -bf oracle absent"; exit 2; }
GIM="$S4E/corpus/packages/snobol4/gimpel"
# gimpel's COUNT and SEQ ship as count.inc and seq.inc (Catspaw's SPITBOL form under lower-case names, CEO-1319; NAME.INC the day before,
# CEO-1315); the witness includes whichever the package ships, and grades the frequency-sort driver under its own spelling.
inc_of() { local n e; for n in "$(printf '%s' "$1" | tr 'A-Z' 'a-z')" "$1"; do for e in inc INC sno; do [ -f "$GIM/$n.$e" ] && { printf '%s' "$n.$e"; return 0; }; done; done; return 1; }
COUNT_F="$(inc_of COUNT)"; SEQ_F="$(inc_of SEQ)"; FRS_D=frsort_driver.sno; [ -f "$GIM/$FRS_D" ] || FRS_D=FRSORT_driver.sno
[ -f "$GIM/$FRS_D" ] && [ -n "$COUNT_F" ] && [ -n "$SEQ_F" ] || { echo "GATE UNPROVEN(2) [$G]: gimpel package (frsort_driver, count, seq) missing at $GIM"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_m4taint.XXXXXX")" || { echo "GATE UNPROVEN(2) [$G]: mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
SINK="$(sbl_listing_sink_flag "$W")" || { echo "GATE UNPROVEN(2) [$G]: no listing sink for the oracle"; exit 2; }
MS=$'\tDEFINE("MS(A,OP)")\t:(MS_END)\nMS\tOPSYN("Z","LT")\n\tMS = 1\t:(RETURN)\nMS_END\n'
CC=$'\tDEFINE("CNT(A,B)")\t:(CNT_END)\nCNT\tCNT = A + B\t:(RETURN)\nCNT_END\n'
TL=$'\tX = CODE("  N = CNT(2,3)  :(END_C)")\n\t:<X>\nEND_C\tOUTPUT = "n=" N\nEND\n'
printf '%s%s%s' "$CC" "$MS" "$TL" > "$W/T.sno"; printf '%s%s' "$CC" "$TL" > "$W/U.sno"
printf -- '-INCLUDE "%s"\n-INCLUDE "%s"\n%s\tS = "MISSISSIPPI"\n\tC = ARRAY(2)\n\tC[1] = "S"\n\tC[2] = "M"\n\tN = ARRAY(2)\n\tSEQ("  N[I]  =  COUNT(S,C[I]) ", .I)\n\tOUTPUT = "n=" N[1] "," N[2]\nEND\n' "$COUNT_F" "$SEQ_F" "$MS" > "$W/S.sno"
cp "$GIM/$FRS_D" "$W/F.sno"
PASS=0; FAIL=0; GRADED=0
grade() { local name="$1" dir="$2" rc4 o
    ( cd "$dir" && timeout -k 5 10s "$SBL" -bf $SINK "$W/$name.sno" < /dev/null > "$W/$name.oracle" 2>&1 )
    ( cd "$dir" && SNO_LIB="$GIM" timeout -k 5 10s "$ROOT/scrip" --run "$W/$name.sno" < /dev/null > "$W/$name.m3" 2>&1 )
    if ( cd "$dir" && SNO_LIB="$GIM" timeout -k 5 10s "$ROOT/scrip" --compile "$W/$name.sno" < /dev/null > "$W/$name.s" 2> "$W/$name.cerr" ) && gcc -c "$W/$name.s" -o "$W/$name.o" 2>/dev/null && gcc "$W/$name.o" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/$name.bin" 2>/dev/null; then
        ( cd "$dir" && timeout -k 5 10s "$W/$name.bin" < /dev/null > "$W/$name.m4" 2>&1 ); rc4=$?
    else rc4=NOBUILD; : > "$W/$name.m4"; fi
    for m in m3 m4; do GRADED=$((GRADED+1))
        if [ "$m" = m4 ] && [ "$rc4" = NOBUILD ]; then FAIL=$((FAIL+1)); echo "  ⛔ $name m4: NOBUILD -- $(head -c 100 "$W/$name.cerr")"
        elif cmp -s "$W/$name.$m" "$W/$name.oracle"; then PASS=$((PASS+1)); echo "  ✅ $name $m: $(tr '\n' ' ' < "$W/$name.oracle" | cut -c1-60)"
        else FAIL=$((FAIL+1)); echo "  ⛔ $name $m: got [$(tr '\n' ' ' < "$W/$name.$m" | cut -c1-80)] want [$(tr '\n' ' ' < "$W/$name.oracle" | cut -c1-60)]"; fi
    done; }
grade T "$W"; grade S "$GIM"; grade F "$GIM"; grade U "$W"
GRADED=$((GRADED+1)); if grep -q 'rt_scc_taint_inherit' "$W/U.s" 2>/dev/null; then FAIL=$((FAIL+1)); echo "  ⛔ U .s: the untainted program carries the taint mark -- emission changed where it must not"; else PASS=$((PASS+1)); echo "  ✅ U .s: no taint mark in an untainted program's assembly"; fi
GRADED=$((GRADED+1)); if grep -q 'rt_scc_taint_inherit' "$W/T.s" 2>/dev/null; then PASS=$((PASS+1)); echo "  ✅ T .s: the tainted program carries the taint mark in its prologue"; else FAIL=$((FAIL+1)); echo "  ⛔ T .s: no taint mark in the tainted program's assembly"; fi
echo "------------------------------------------------------------"
if [ "$FAIL" = 0 ]; then echo "GATE PASS(0) [$G]: $PASS of $GRADED gradings green (4 witnesses x 2 modes vs sbl -bf + 2 assembly arms)"; exit 0
else echo "GATE FAIL(1) [$G]: $FAIL red of $GRADED gradings"; exit 1; fi
