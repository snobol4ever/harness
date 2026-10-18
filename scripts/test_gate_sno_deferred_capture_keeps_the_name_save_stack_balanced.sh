#!/usr/bin/env bash
# test_gate_sno_deferred_capture_keeps_the_name_save_stack_balanced.sh -- A DEFERRED `*expr` CAPTURE EVALUATED BY THE
# RUNTIME PATTERN ENGINE LEAVES THE NAME-SAVE STACK WHERE IT FOUND IT, SO THE ENCLOSING FUNCTION RESTORES ITS OWN
# FORMALS AND LOCALS ON RETURN.
# Row snobol4-gimpel-class-diff-both-modes (coo, 2026-09-07), found under gimpel FRSORT_driver (MISP vs the oracle's ISPM).
# MEASURED BEFORE THE CURE (SCRIP 657fb70ee, both modes): on the non-SCC call path -- taken by EVERY call once any
# two-argument OPSYN or UNLOAD appears in the program (optimizer/proc_collect.c scc_taint_graph), or under
# SCRIP_SCC_OFF=1 -- a callee whose pattern carried `*F<I>` (an array-element capture) left its caller's variables
# holding the callee's values: the formal S that shadowed the global S came back as the argument, locals I and PAT
# came back as the callee's. Each evaluation of the capture calls its synthetic EXPRNM$ proc through
# rt_call_proc_descr's unnamed enter, whose prologue pushed name-saves and whose epilogue (rt_proc_call_epilogue_γ)
# never popped them, so the enclosing function's count-based restore was shifted by one entry per evaluation. On the
# SCC path the template restores formals itself, which hid the leak (it still grew the stack). CURE (rt.c):
# rt_call_proc_descr marks the stack before the open and unwinds to the mark after the unnamed enter.
# Arms, each in BOTH modes against the live sbl -bf oracle:
#   P   formal shadowing a global, `*F<I>` capture, exit on match failure     -- tainted by a 2-arg OPSYN
#   R   locals I/PAT and the result F, globals pre-set, all printed after     -- tainted
#   W   CRACK-then-COUNT, the FRSORT shape (the count must read 4)             -- tainted
#   N   one, two and zero evaluations of the capture before return             -- tainted
#   U   the P witness UNTAINTED, run under SCRIP_SCC_OFF=1                     -- the switch, not the OPSYN, is the path
# Population printed beside the verdict. Needs the built binary and the oracle; UNPROVEN(2) without either.
# Fail-once (2026-09-07 12:3x CDT, coo, MEASURED by rebuilding the pre-cure rt.c): 9 of 10 gradings red -- P, R, W, N in both modes
# and U in mode 3; U in mode 4 stays green because SCRIP_SCC_OFF is a mode-3 switch and the mode-4 binary compiled on the direct path.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_gate.sh"; gate_parse_args "$@"
G=sno_deferred_capture_keeps_the_name_save_stack_balanced
"$HERE/util_require_fresh.sh" --gate test_gate_$G "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" >/dev/null 2>&1 || { echo "GATE UNPROVEN(2) [$G]: this tree's binary is stale or unbuilt -- run make"; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "GATE UNPROVEN(2) [$G]: lib_oracle_flags.sh unloadable"; exit 2; }
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "GATE UNPROVEN(2) [$G]: sbl -bf oracle absent"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_nsave.XXXXXX")" || { echo "GATE UNPROVEN(2) [$G]: mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
MS=$'\tDEFINE("MS(A,OP)")\t:(MS_END)\nMS\tOPSYN("Z","LT")\n\tMS = 1\t:(RETURN)\nMS_END\n'
FP=$'\tDEFINE("F(S)I,PAT")\t:(F_END)\nF\tF = ARRAY(SIZE(S))\n\tPAT = LEN(1) . *F[I]\nF_L\tI = I + 1\n\tS PAT =\t:S(F_L)F(RETURN)\nF_END\n'
printf '%s%s\tS = "MISSISSIPPI"\n\tC = F("MISP")\n\tOUTPUT = "S=[" S "]"\nEND\n' "$MS" "$FP" > "$W/P.sno"
printf '%s\tS = "MISSISSIPPI"\n\tC = F("MISP")\n\tOUTPUT = "S=[" S "]"\nEND\n' "$FP" > "$W/U.sno"
printf '%s%s\tS = "MISSISSIPPI"\n\tI = "gi"\n\tPAT = "gp"\n\tF = "gf"\n\tC = F("MISP")\n\tOUTPUT = "S=[" S "] I=[" I "] PAT=[" PAT "] F=[" DATATYPE(F) "]"\nEND\n' "$MS" "$FP" > "$W/R.sno"
CR=$'\tDEFINE("CRACK(S,B)I,PAT")\t:(CRACK_END)\nCRACK\tCRACK = ARRAY(SIZE(S))\n\tPAT = LEN(1) . *CRACK[I]\nCRACK_2\tI = I + 1\n\tS PAT =\t:S(CRACK_2)F(RETURN)\nCRACK_END\n'
CN=$'\tDEFINE("COUNT(S1,S2)FIRST,REST,P")\t:(COUNT_END)\nCOUNT\tS2 LEN(1) . FIRST REM . REST\t:F(RETURN)\n\tP = POS(0) BREAKX(FIRST) S2\nCOUNT_1\tS1 P = REST\t:F(RETURN)\n\tCOUNT = COUNT + 1\t:(COUNT_1)\nCOUNT_END\n'
printf '%s%s%s\tS = "MISSISSIPPI"\n\tC = CRACK("MISP")\n\tOUTPUT = "a=" COUNT(S,"S")\nEND\n' "$CR" "$CN" "$MS" > "$W/W.sno"
FN=$'\tDEFINE("F(S,N)I,PAT")\t:(F_END)\nF\tF = ARRAY(10)\n\tPAT = LEN(1) . *F[I]\nF_L\tI = I + 1\n\tLE(I,N)\t:F(RETURN)\n\tS PAT\t:S(F_L)F(RETURN)\nF_END\n'
printf '%s%s\tS = "MISSISSIPPI"\n\tC = F("MISP", 1)\n\tOUTPUT = "1:" S\n\tS = "MISSISSIPPI"\n\tC = F("MISP", 2)\n\tOUTPUT = "2:" S\n\tS = "MISSISSIPPI"\n\tC = F("MISP", 0)\n\tOUTPUT = "0:" S\nEND\n' "$MS" "$FN" > "$W/N.sno"
PASS=0; FAIL=0; GRADED=0
grade() { local name="$1" env="$2" o rc3 rc4
    ( cd "$W" && timeout -k 5 5s "$SBL" -bf "$name.sno" < /dev/null > "$name.oracle" 2>&1 )
    ( cd "$W" && env $env timeout -k 5 5s "$ROOT/scrip" --run "$name.sno" < /dev/null > "$name.m3" 2>&1 ); rc3=$?
    if ( cd "$W" && timeout -k 5 5s "$ROOT/scrip" --compile "$name.sno" < /dev/null > "$name.s" 2> "$name.cerr" ) && gcc -c "$W/$name.s" -o "$W/$name.o" 2>/dev/null && gcc "$W/$name.o" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$W/$name.bin" 2>/dev/null; then
        ( cd "$W" && env $env timeout -k 5 5s "./$name.bin" < /dev/null > "$name.m4" 2>&1 ); rc4=$?
    else rc4=NOBUILD; : > "$W/$name.m4"; fi
    for m in m3 m4; do GRADED=$((GRADED+1))
        if [ "$m" = m4 ] && [ "$rc4" = NOBUILD ]; then FAIL=$((FAIL+1)); echo "  ⛔ $name m4: NOBUILD -- $(head -c 100 "$W/$name.cerr")"
        elif cmp -s "$W/$name.$m" "$W/$name.oracle"; then PASS=$((PASS+1)); echo "  ✅ $name $m: $(tr '\n' ' ' < "$W/$name.oracle" | cut -c1-70)"
        else FAIL=$((FAIL+1)); echo "  ⛔ $name $m: got [$(tr '\n' ' ' < "$W/$name.$m" | cut -c1-70)] want [$(tr '\n' ' ' < "$W/$name.oracle" | cut -c1-70)]"; fi
    done; }
grade P ""; grade R ""; grade W ""; grade N ""; grade U "SCRIP_SCC_OFF=1"
echo "------------------------------------------------------------"
if [ "$FAIL" = 0 ]; then echo "GATE PASS(0) [$G]: $PASS of $GRADED gradings green (5 witnesses x 2 modes vs sbl -bf; U under SCRIP_SCC_OFF=1)"; exit 0
else echo "GATE FAIL(1) [$G]: $FAIL red of $GRADED gradings"; exit 1; fi
