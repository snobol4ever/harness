#!/usr/bin/env bash
# test_gate_sno_subscripted_replacement_does_not_leak_the_spine.sh
#
# ⛔⭐ THE CLASS (hq_S 2026-09-13, measured; cure site is hq_U's ζ-SPINE depth planner, NOT this seat's files):
# a match WITH REPLACEMENT whose SUBJECT is a SUBSCRIPTED reference (an array element) leaks exactly 64 bytes of
# ζ-SPINE (RSP) every time the statement executes. The statement trailer's whack constant -- op_zgpop, staged from
# g_zd_gpop and stamped by zd_plan (src/emitter/emit.cpp:2620 -- NOT src/planner/zeta_depth.c, see below), emitted on the X86H_JMP gamma hook arm at
# x86_asm.h:1910 -- does not account for the FOUR 16-byte value-stack slots pushed by the store chain that exists
# ONLY for an indexed target: var -> call (rt_call_arr_bl, the SNO$NAME lvalue store) -> var -> assign_var.
# MEASURED, not inferred: RSP falls 0x40 per iteration across five consecutive iterations of the loop form, and in
# the function form the γ/ω continuation pair the RETURN box pops sits at rsp+0x40 while the trailer whacked 96.
#
# ⭐ TWO SYMPTOMS, ONE DEFECT, AND THE ARMS ARE WRITTEN AGAINST THE LEAK RATHER THAN AGAINST EITHER SYMPTOM.
#   (1) inside a function the RETURN box does `pop rcx; add rsp,8; jmp rcx`, reads leaked DATA instead of γ, and
#       jumps to it -- SIGSEGV in BOTH modes (the measured wild target was 0x0000000200008b28, a descriptor half).
#   (2) in a loop the drift is monotonic and eventually exhausts the stack, so the program reports ERROR 246 where
#       the oracle prints its answer -- the guard fires correctly on a bogus overflow.
# ARM 3 is the LEAK arm and it is the one that matters: it asserts the INVARIANT (the spine does not drift) rather
# than the crash that motivated the row. A cure that repaired only the function-return symptom would leave arm 3
# red. This is hq_U's own lesson from the r12 plane, applied here deliberately: a gate written against a plane must
# assert the plane's invariant at the site that establishes it, not the symptom that led you to it.
#
# ⛔ THE FOUR CONTROL ARMS ARE NOT DECORATION -- each removes ONE ingredient and each PASSES on today's broken tree,
# so a cure that over-corrects (whacking the spine somewhere it was already balanced) reds them while arms 1-3 go
# green. plain-variable subject in a function · array element with a MATCH but no replacement in a function · array
# element with a PLAIN ASSIGNMENT in a function · the IDENTICAL replacement statement at TOP LEVEL. That last one is
# the sibling that pins the activation as the discriminator: the statement is not wrong, its context is.
#
# ⛔⭐ THE CLASS IS WIDER THAN AN ARRAY ELEMENT AND ARM 7 IS WHY THIS MATTERS (hq_S 2026-09-13, measured after hq_U
# took the cure). An INDIRECT REFERENCE subject -- `$NM  LEN(1) . S1  REM . S2  =  S2  S1` inside a function -- has the
# IDENTICAL signature: SIGSEGV where the oracle prints BCA, and green at top level. So the discriminator is a COMPUTED
# LVALUE (subscripted OR indirect), not a subscript. A cure that keys on the subscript node alone passes arms 1-2 and
# leaves gimpel PEEL_driver.sno dead -- PEEL.sno:26 is `$NAME.  LEN(K1.) . PEEL  =` inside a function, the indirect
# spelling. Arm 7 exists so that cure cannot read as complete.
#
# ⛔ COVERAGE NOTE, measured and worth more than the gate: corpus/tests/snobol4/ALL.sno contains ZERO entries whose
# replacement subject is subscripted, which is exactly why the SNOBOL4 rungs reads clean while gimpel PERMS_driver
# SIGSEGVs. A green board is necessary, never sufficient. Adding a rung suite witness is hq_S's suite-gap row and waits
# on the cure -- a red entry in the rungs is not a cure and must not land as one.
#
# Every arm compares against the ORACLE's own output, refs cut from it ON THIS RUN, never from our output; the
# oracle is run TWICE per witness and diffed against ITSELF first, refusing rc=2 if it differs.
# EXIT: 0 all arms · 1 an arm failed · 2 REFUSED (cannot measure).
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; root="$(cd "$here/../../SCRIP" && pwd)"
. "$here/lib_oracle_flags.sh" 2>/dev/null || true
S="$root/scrip"; RT="$root/out"
ORACLE="$( { sbl_correctness_bin 2>/dev/null || true; } )"; [ -n "${ORACLE:-}" ] || ORACLE=/home/resources/x64/bin/sbl
[ -x "$S" ]      || { echo "REFUSE(2): no $S -- run make"; exit 2; }
[ -x "$ORACLE" ] || { echo "REFUSE(2): no SNOBOL4 oracle at $ORACLE"; exit 2; }
command -v gcc >/dev/null 2>&1 || { echo "REFUSE(2): no gcc, mode 4 cannot be graded"; exit 2; }
command -v as  >/dev/null 2>&1 || { echo "REFUSE(2): no as, mode 4 cannot be graded"; exit 2; }
t="$(mktemp -d)" || { echo "REFUSE(2): mktemp"; exit 2; }
trap 'rm -rf "$t"' EXIT
PASS=0; FAIL=0; GRADED=0
# ⛔ THE LOOP COUNT IS A MEASUREMENT, NOT A PREFERENCE: 400000 iterations SURVIVE on the broken tree (the leak has
# not yet reached the stack limit) and 1000000 trip ERROR 246 in ~1.4s. A count chosen below the threshold would
# make arm 3 green on a broken tree -- a gate that cannot fail for its own reason.
LEAKN=1000000
w_witness() { printf "\tDEFINE('F()')\t\t\t\t:(F_END)\nF\tA[2]  LEN(1) . S1  REM . S2  =  S2  S1\t:(RETURN)\nF_END\tA = ARRAY(2, 'ABC')\n\tF()\n\tOUTPUT = A[2]\nEND\n" > "$1"; }
w_leak()    { printf "\tA = ARRAY(2, 'ABC')\n\tN = 0\nL\tN = N + 1\n\tA[2]  LEN(1) . S1  REM . S2  =  S2  S1\n\tLT(N, %s)\t\t\t\t:S(L)\n\tOUTPUT = 'SURVIVED ' N\nEND\n" "$LEAKN" > "$1"; }
c_plainvar(){ printf "\tDEFINE('F()')\t\t\t\t:(F_END)\nF\tV  LEN(1) . S1  REM . S2  =  S2  S1\t:(RETURN)\nF_END\tV = 'ABC'\n\tF()\n\tOUTPUT = V\nEND\n" > "$1"; }
c_matchonly(){ printf "\tDEFINE('F()')\t\t\t\t:(F_END)\nF\tA[2]  LEN(1) . S1  REM . S2\t\t:(RETURN)\nF_END\tA = ARRAY(2, 'ABC')\n\tF()\n\tOUTPUT = A[2]\nEND\n" > "$1"; }
c_plainassign(){ printf "\tDEFINE('F()')\t\t\t\t:(F_END)\nF\tA[2] = 'ZZZ'\t\t\t\t:(RETURN)\nF_END\tA = ARRAY(2, 'ABC')\n\tF()\n\tOUTPUT = A[2]\nEND\n" > "$1"; }
w_indirect(){ printf "\tDEFINE('F()')\t\t\t\t:(F_END)\nF\t\$NM  LEN(1) . S1  REM . S2  =  S2  S1\t:(RETURN)\nF_END\tNM = 'V'\n\tV = 'ABC'\n\tF()\n\tOUTPUT = V\nEND\n" > "$1"; }
c_indirect_top(){ printf "\tNM = 'V'\n\tV = 'ABC'\n\t\$NM  LEN(1) . S1  REM . S2  =  S2  S1\n\tOUTPUT = V\nEND\n" > "$1"; }
c_toplevel(){ printf "\tA = ARRAY(2, 'ABC')\n\tA[2]  LEN(1) . S1  REM . S2  =  S2  S1\n\tOUTPUT = A[2]\nEND\n" > "$1"; }
oracle_ref() {  # $1=src $2=out-ref  -- run the oracle TWICE, refuse if it is not deterministic
    ( cd "$t" && timeout -k 5 120 "$ORACLE" -bf "$1" < /dev/null > "$2.a" 2>&1 ); local ra=$?
    ( cd "$t" && timeout -k 5 120 "$ORACLE" -bf "$1" < /dev/null > "$2.b" 2>&1 ); local rb=$?
    [ "$ra" = "$rb" ] || { echo "REFUSE(2): oracle rc differs between two runs of $1 ($ra vs $rb)"; exit 2; }
    cmp -s "$t/$2.a" "$t/$2.b" || { echo "REFUSE(2): oracle output is not deterministic for $1 -- cannot be a ref"; exit 2; }
    mv "$t/$2.a" "$t/$2"; rm -f "$t/$2.b"; printf '%s' "$ra"
}
grade() {   # grade <label> <writer> <modes>
    local label="$1" writer="$2" modes="$3" src="$t/w.sno" ref want got rc
    rm -f "$src"; $writer "$src"
    want="$(oracle_ref w.sno w.ref)"
    for m in $modes; do
        GRADED=$((GRADED+1))
        if [ "$m" = m3 ]; then
            got="$( cd "$t" && timeout -k 5 200 "$S" --run w.sno < /dev/null 2>&1 )"; rc=$?
        else
            rm -f "$t/p.s" "$t/p.o" "$t/p.bin"
            if ! ( cd "$t" && timeout -k 5 200 "$S" --compile -o p.s w.sno >/dev/null 2>&1 ) \
               || ! as --64 "$t/p.s" -o "$t/p.o" 2>/dev/null \
               || ! gcc "$t/p.o" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$t/p.bin" 2>/dev/null; then
                FAIL=$((FAIL+1)); printf '  FAIL %-52s %s  mode-4 compile/link failed\n' "$label" "$m"; continue
            fi
            got="$( cd "$t" && timeout -k 5 200 ./p.bin < /dev/null 2>&1 )"; rc=$?
        fi
        if [ "$rc" = "$want" ] && [ "$got" = "$(cat "$t/w.ref")" ]; then
            PASS=$((PASS+1)); printf '  ok   %-52s %s\n' "$label" "$m"
        else
            FAIL=$((FAIL+1)); printf '  FAIL %-52s %s  rc=%s(want %s) got=[%s] want=[%s]\n' \
                "$label" "$m" "$rc" "$want" "$(printf '%s' "$got" | head -1 | cut -c1-40)" "$(head -1 "$t/w.ref" | cut -c1-40)"
        fi
    done
}
echo "== THE WITNESS: a replacement whose subject is an array element, inside a function =="
grade "1 subscripted replacement in a function"        w_witness      "m3 m4"
echo "== THE LEAK ARM: the same statement in a loop must not drift the spine =="
grade "2 no spine drift over $LEAKN executions"        w_leak         "m3"
echo "== THE CONTROL ARMS: each removes ONE ingredient and each is green on the broken tree =="
grade "3 CONTROL plain-variable subject in a function" c_plainvar     "m3 m4"
grade "4 CONTROL array element, match but no replace"  c_matchonly    "m3 m4"
grade "5 CONTROL array element, plain assignment"      c_plainassign  "m3 m4"
grade "6 CONTROL same replacement at TOP LEVEL"        c_toplevel     "m3 m4"
echo "== THE WIDTH ARM: the class is a COMPUTED lvalue, not an array element =="
grade "7 indirect-reference subject in a function"     w_indirect     "m3 m4"
grade "8 CONTROL same indirect replacement TOP LEVEL"  c_indirect_top "m3 m4"
echo "graded $GRADED witness-modes: PASS=$PASS FAIL=$FAIL (oracle $ORACLE, refs cut from it this run)"
[ "$GRADED" -gt 0 ] || { echo "REFUSE(2): graded nothing"; exit 2; }
if [ "$FAIL" -eq 0 ]; then echo "GREEN: a replacement through a COMPUTED LVALUE (subscripted or indirect) leaves the spine where it found it"; exit 0; fi
echo "RED: a replacement through a COMPUTED LVALUE leaks ζ-SPINE inside an activation -- cure is hq_U's (CONCERN 3); the FILENAME says subscripted and UNDERSTATES it, arm 7 is the indirect spelling"; exit 1
