#!/usr/bin/env bash
# stale-binary preflight
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_chain_entry_establishes_the_pend_top_cold_and_preserves_it_mid_match.sh
# -- a compiled chain entered from the C runtime gets the RIGHT r12 in BOTH directions.
# (hq_U 2026-09-13, concern 3 ZETA STORAGE / register planes; cold arms and their generator are hq_S's, from
#  FINDING-2026-09-13-hq_S-seeding-r12-from-the-base-cures-the-cold-chain-entry-and-silently-destroys-an-outer-pending-capture-mid-match.md)
#
# THE CLASS. r12 is the dcap PEND TOP -- the pending-capture/replacement stack that bb_match_end stores through.
# Generated code establishes it once, in the program prologue, from the cell at RT_DCAP_TOP; every box from then
# on treats it as a machine-wide invariant. Inside the C runtime r12 is an ORDINARY callee-saved register, so the
# two trampolines that jump into a compiled chain FROM C -- rt_chain_enter / rt_chain_enter_v -- hand the chain
# whatever C left there. That is wrong in TWO OPPOSITE DIRECTIONS and a cure that only knows one of them is worse
# than no cure:
#   COLD (no match live): r12 is C's own value (measured 0x68) and the chain's first replacement stores through
#     it and SIGSEGVs. Arms 1-3.
#   MID-MATCH (a match is live): r12 IS the live pend top, carried in by callee-save propagation. Seeding it
#     UNCONDITIONALLY from the cell resets the top to the base, the inner chain pends from there, and the OUTER
#     match's already-pending capture is overwritten -- a WRONG ANSWER AT rc=0. Arm 4.
# ⭐ ARM 4 IS WHY THIS GATE EXISTS SEPARATELY FROM A COLD-ONLY ONE. A gate whose whole population evaluates
# outside a live match cannot see the mid-match direction, and the unconditional seed passes all of arms 1-3.
#
# Every arm is graded against the ORACLE's own output in BOTH modes, refs cut on this run, and the oracle is run
# TWICE and diffed against ITSELF first (refuse rc=2 if it differs).
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
mk() {
    case "$2" in
      midmatch)
        { printf '\tDEFINE("PLAIN()W")\n\tSUBJ = "ABPCD"\n'
          printf '\tSUBJ LEN(2) . X *EVAL("PLAIN()") LEN(2) . Y\t:S(OK)F(NO)\n'
          printf 'NO\tOUTPUT = "NOMATCH"\t\t\t\t:(END)\n'
          printf 'OK\tOUTPUT = "X=[" X "]"\n\tOUTPUT = "Y=[" Y "]"\t\t\t:(END)\n'
          printf 'PLAIN\tW = ";+ tail"\n\tW POS(0) %s;%s  ANY(%s.+%s) = %s %s\n\tPLAIN = "P"\t\t\t:(RETURN)\nEND\n' \
                 "'" "'" "'" "'" "'" "'"; } > "$1" ;;
      *)
        { printf '\tDEFINE("PLAIN()W")\n'
          case "$2" in
            expr)   printf '\tS = CONVERT("PLAIN()","EXPRESSION")\t\t:F(B2)\n\tOUTPUT = "ev=" EVAL(S)\n' ;;
            string) printf '\tOUTPUT = "ev=" EVAL("PLAIN()")\n' ;;
            direct) printf '\tOUTPUT = "ev=" PLAIN()\n' ;;
          esac
          printf '\tOUTPUT = "done"\t\t\t\t\t:(END)\n'
          printf 'PLAIN\tW = ";+ tail"\n\tW POS(0) %s;%s  ANY(%s.+%s) = %s %s\n\tOUTPUT = "plain w=[" W "]"\n\tPLAIN = "P"\t\t\t:(RETURN)\n' \
                 "'" "'" "'" "'" "'" "'"
          printf 'B2\tOUTPUT = "convert failed"\t\t\t:(END)\nEND\n'; } > "$1" ;;
    esac
}
run_m3() { timeout -k 5 30 "$S" "$1" < /dev/null 2>&1; }
run_m4() {
    rm -f "$t/p.s" "$t/p.o" "$t/f.bin"
    timeout -k 5 60 "$S" --compile -o "$t/p.s" "$1" < /dev/null > "$t/c.log" 2>&1 \
      && gcc -c "$t/p.s" -o "$t/p.o" >> "$t/c.log" 2>&1 \
      && gcc "$t/p.o" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$t/f.bin" >> "$t/c.log" 2>&1 \
      || { echo "M4-BUILD-FAILED"; return; }
    timeout -k 5 30 "$t/f.bin" < /dev/null 2>&1
}
grade() {
    GRADED=$((GRADED + 1))
    if [ "$2" = "$3" ]; then PASS=$((PASS + 1)); return 0; fi
    FAIL=$((FAIL + 1)); echo "RED: $1"; echo "  oracle: $(echo "$2" | tr '\n' '|')"; echo "  scrip : $(echo "$3" | tr '\n' '|')"; return 1
}
for how in expr string direct midmatch; do
    w="$t/w_$how.sno"; mk "$w" "$how"
    o1="$("$ORACLE" -bf "$w" < /dev/null 2>&1)"; o2="$("$ORACLE" -bf "$w" < /dev/null 2>&1)"
    [ "$o1" = "$o2" ] || { echo "REFUSE(2): the oracle differs from ITSELF on the '$how' witness -- it cannot be a ref"; exit 2; }
    case "$o1" in *"convert failed"*|"") echo "REFUSE(2): the oracle itself did not run the '$how' witness: $o1"; exit 2;; esac
    case "$how" in
      midmatch) case "$o1" in *"X=[AB]"*) : ;; *) echo "REFUSE(2): the mid-match witness did not pend a capture in the ORACLE, so it grades nothing: $o1"; exit 2;; esac ;;
      *)        case "$o1" in *"plain w=[  tail]"*) : ;; *) echo "REFUSE(2): the '$how' witness never reached the replacement in the ORACLE, so it grades nothing: $o1"; exit 2;; esac ;;
    esac
    case "$how" in
      expr)     lbl="COLD WITNESS -- EVAL of a CONVERT'd EXPRESSION reaches a replacement" ;;
      string)   lbl="COLD CONTROL -- EVAL of a plain STRING reaches the same replacement" ;;
      direct)   lbl="COLD CONTROL -- the same function called directly, no chain entry" ;;
      midmatch) lbl="MID-MATCH WITNESS -- an outer pending capture survives a chain entered inside the match" ;;
    esac
    grade "$lbl (m3)" "$o1" "$(run_m3 "$w")"
    grade "$lbl (m4)" "$o1" "$(run_m4 "$w")"
done
[ "$GRADED" -gt 0 ] || { echo "REFUSE(2): graded zero witnesses"; exit 2; }
echo "test_gate_sno_chain_entry_establishes_the_pend_top_cold_and_preserves_it_mid_match: PASS=$PASS FAIL=$FAIL of $GRADED graded (4 witnesses x 2 modes)"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
