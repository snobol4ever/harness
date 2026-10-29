#!/usr/bin/env bash
# stale-binary preflight (same convention as test_gate_sno_stcount_counts_statements_inside_code_fragments.sh)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_eval_of_a_converted_expression_keeps_the_replacement_pointer.sh -- a function reached through
# EVAL of a CONVERT(...,'EXPRESSION') object may perform a match WITH REPLACEMENT without dying.
# (hq_S 2026-09-13, row snobol4-aisnobol-dextern-loading-a-library-function-with-a-continuation-line-sigsegvs.)
#
# THE CLASS, and it is a register-plane invariant, not a pattern bug. r12 is THE CAS POINTER -- the pending-
# replacement stack that bb_match_end stores the replacement length through. Generated code treats it as a
# MACHINE-WIDE INVARIANT established exactly once, in the program's own prologue (mode 4 emits
# `mov r12, qword ptr [0x70000000]` into main; mode 3 does the same two instructions in icn_zf_main_call).
# ⛔ BUT INSIDE THE C RUNTIME r12 IS AN ORDINARY CALLEE-SAVED REGISTER, so any C function may keep its own
# value there. The two trampolines that enter a compiled chain FROM C -- rt_chain_enter and rt_chain_enter_v
# in src/runtime/runtime_eval.c -- push and pop r12 correctly for their own caller, and used to jump into
# generated code WITHOUT re-establishing it. So the chain ran with C's r12 (measured: 0x68, a 104) and the
# first `subject pattern = replacement` inside it stored through it and SIGSEGV'd.
#
# ⭐ WHY THIS WITNESS AND NOT A PATTERN ONE. The corrupt pointer is carried by EVERY chain entered from C;
# only a statement that performs a REPLACEMENT ever dereferences it. Everything else runs correctly over the
# same corruption, which is why the class hid inside one vendor program for so long: the two aisnobol entries
# that crashed were the only ones whose loaded library body reached a successful replacement.
#
# THE ARMS. Arm 1 is the witness: EVAL of a CONVERT'd EXPRESSION reaching a function that performs a
# replacement. Arms 2 and 3 are the CONTROL PAIR, and they are not decoration -- each is one ingredient
# removed from arm 1 (EVAL of a plain STRING; the same function called directly), each PASSED before the cure,
# and a "cure" that seeded r12 wrongly or unconditionally would red them while arm 1 went green. One arm alone
# is passed by over-correcting.
#
# Every arm compares against the ORACLE's own output, in BOTH modes, with refs cut from it on this run -- and
# the oracle is run TWICE and diffed against ITSELF first, refusing rc=2 if it differs
# (FINDING-2026-09-13-hq_S-a-done-when-that-byte-compares-a-program-printing-a-clock-reading-is-unsatisfiable).
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; root="$(cd "$here/../../SCRIP" && pwd)"
. "$here/lib_oracle_flags.sh" 2>/dev/null || true
S="$root/scrip"; RT="$root/out"
ORACLE="$( { sbl_correctness_bin 2>/dev/null || true; } )"; [ -n "${ORACLE:-}" ] || ORACLE=/home/resources/x64/bin/sbl
[ -x "$S" ]      || { echo "REFUSE(2): no $S -- run make"; exit 2; }
[ -x "$ORACLE" ] || { echo "REFUSE(2): no SNOBOL4 oracle at $ORACLE"; exit 2; }
command -v gcc >/dev/null 2>&1 || { echo "REFUSE(2): no gcc, mode 4 cannot be graded"; exit 2; }
t="$(mktemp -d)" || { echo "REFUSE(2): mktemp"; exit 2; }
trap 'rm -rf "$t"' EXIT
PASS=0; FAIL=0; GRADED=0
body() {   # the function under test: it performs a match WITH REPLACEMENT
    printf 'PLAIN\tW = ";+ tail"\n\tW POS(0) %s;%s  ANY(%s.+%s) = %s %s\n\tOUTPUT = "plain w=[" W "]"\n\tPLAIN = "P"\t\t\t:(RETURN)\n' \
           "'" "'" "'" "'" "'" "'"
}
mk() {     # mk <file> <how the function is reached>
    { printf '\tDEFINE("PLAIN()W")\n'
      case "$2" in
        expr)   printf '\tS = CONVERT("PLAIN()","EXPRESSION")\t\t:F(B2)\n\tOUTPUT = "ev=" EVAL(S)\n' ;;
        string) printf '\tOUTPUT = "ev=" EVAL("PLAIN()")\n' ;;
        direct) printf '\tOUTPUT = "ev=" PLAIN()\n' ;;
      esac
      printf '\tOUTPUT = "done"\t\t\t\t\t:(END)\n'
      body
      printf 'B2\tOUTPUT = "convert failed"\t\t\t:(END)\nEND\n'; } > "$1"
}
run_m3() { timeout -k 5 30 "$S" "$1" < /dev/null 2>&1; }
run_m4() {
    rm -f "$t/p.s" "$t/p.o" "$t/f.bin"
    timeout -k 5 60 "$S" --compile --out="$t/p.s" "$1" < /dev/null > "$t/c.log" 2>&1 \
      && gcc -c "$t/p.s" -o "$t/p.o" >> "$t/c.log" 2>&1 \
      && gcc "$t/p.o" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$t/f.bin" >> "$t/c.log" 2>&1 \
      || { echo "M4-BUILD-FAILED"; return; }
    timeout -k 5 30 "$t/f.bin" < /dev/null 2>&1
}
grade() {  # grade <label> <expected> <actual>
    GRADED=$((GRADED + 1))
    if [ "$2" = "$3" ]; then PASS=$((PASS + 1)); return 0; fi
    FAIL=$((FAIL + 1)); echo "RED: $1"; echo "  oracle: $(echo "$2" | tr '\n' '|')"; echo "  scrip : $(echo "$3" | tr '\n' '|')"; return 1
}
for how in expr string direct; do
    w="$t/w_$how.sno"; mk "$w" "$how"
    o1="$("$ORACLE" -bf "$w" < /dev/null 2>&1)"; o2="$("$ORACLE" -bf "$w" < /dev/null 2>&1)"
    [ "$o1" = "$o2" ] || { echo "REFUSE(2): the oracle differs from ITSELF on the '$how' witness -- it cannot be a ref"; exit 2; }
    case "$o1" in *"convert failed"*|"") echo "REFUSE(2): the oracle itself did not run the '$how' witness: $o1"; exit 2;; esac
    case "$o1" in *"plain w=[  tail]"*) : ;; *) echo "REFUSE(2): the '$how' witness never reached the replacement in the ORACLE, so it grades nothing: $o1"; exit 2;; esac
    case "$how" in
      expr)   lbl="THE WITNESS -- EVAL of a CONVERT'd EXPRESSION reaches a replacement" ;;
      string) lbl="CONTROL -- EVAL of a plain STRING reaches the same replacement" ;;
      direct) lbl="CONTROL -- the same function called directly" ;;
    esac
    grade "m3 $lbl" "$o1" "$(run_m3 "$w")"
    grade "m4 $lbl" "$o1" "$(run_m4 "$w")"
done
echo "graded $GRADED witness-modes: PASS=$PASS FAIL=$FAIL (oracle $ORACLE, refs cut from it this run)"
[ "$GRADED" -gt 0 ] || { echo "REFUSE(2): graded zero witnesses"; exit 2; }
[ "$FAIL" -eq 0 ] || exit 1
echo "GREEN: a chain entered from the C runtime carries the CAS pointer, so a replacement inside it stores where it should"
