#!/usr/bin/env bash
export SCRIP_SNO_STMTKW=1   # this grader asks for the SNOBOL4 statement instrumentation (the --stlimit switch; Lon 2026-09-24 16:0x: the feature is off by default and never inferred from the source, the correctness graders turn it on because the oracle always has it)
# stale-binary preflight (same convention as test_gate_sno_port_trace_oracle_diff.sh)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_stcount_counts_statements_inside_code_fragments.sh -- &STCOUNT counts the statements
# executed inside a CODE()-compiled fragment, and counts the SAME number of them as SPITBOL does, in BOTH
# modes. (hq_S 2026-09-13, row snobol4-stcount-diverges-in-m4-from-m3-and-the-oracle-inside-code-eval-
# compiled-statements.)
#
# THE CLASS. A CODE() fragment is parsed and lowered AT RUN TIME. The lowerer chooses between the counted
# SNO$STMT hook and the cheap inline statement mark from g_sno_uses_stmtkw, which it seeds from the
# SCRIP_SNO_STMTKW environment variable. In mode 3 the main program was lowered in the SAME process, so
# that seed is already set when the fragment is lowered; in mode 4 it was set in the compiler's process
# and died with it, so every statement executed inside CODE() went UNCOUNTED and &STCOUNT drifted low.
# It surfaced in AIS ATN as a WRONG ANSWER rather than as a counter reading, because ATN's own GENNAME
# mints generated node names out of &STCOUNT -- the program encodes the statement counter into its output.
#
# ⛔ WHY THIS GATE PINS VALUES AND NOT A DIFF. The row's symptom was an m3-vs-m4 diff, and a build that had
# simply stopped counting statements ALTOGETHER would make that diff vanish too -- both modes agreeing on a
# wrong number is not a cure. So every arm here compares SCRIP's &STCOUNT against the ORACLE's own reading
# of the same program, and arm 2 sweeps the amount of work inside the fragment so the count has to TRACK
# the oracle across a range rather than match it at one point. That is the boundary shape CEO-678 named for
# limit, size and depth rows, applied to a counter: a verdict arm asks "did it count?", a boundary arm asks
# "did it count the right number, everywhere?".
#
# REFS ARE CUT FROM THE ORACLE on every run (sbl -bf, the shared correctness oracle) and never from our own
# output. The witnesses are deterministic -- no TIME(), no DATE(), no input -- so the oracle is its own ref;
# that is checked, not assumed, by running the oracle twice and diffing it against itself before any
# comparison is made (the prophylactic from
# FINDING-2026-09-13-hq_S-a-done-when-that-byte-compares-a-program-printing-a-clock-reading-is-unsatisfiable-and-the-oracle-differs-from-itself.md).
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; root="$(cd "$here/../../SCRIP" && pwd)"
. "$here/lib_oracle_flags.sh" 2>/dev/null || true
S="$root/scrip"; RT="$root/out"
# ⛔ sbl_CORRECTNESS_bin, not sbl_clean_bin: the latter is the BENCH face (/home/resources/spitbol-bench-oracle/sbl)
# and this is a correctness gate. Measured 2026-09-13: both faces agree on these witnesses, which is exactly why
# taking the wrong one would have gone unnoticed here and bitten a later witness where they do not.
ORACLE="$( { sbl_correctness_bin 2>/dev/null || true; } )"; [ -n "${ORACLE:-}" ] || ORACLE=/home/resources/x64/bin/sbl
[ -x "$S" ]      || { echo "REFUSE(2): no $S -- run make"; exit 2; }
[ -x "$ORACLE" ] || { echo "REFUSE(2): no SNOBOL4 oracle at $ORACLE"; exit 2; }
command -v gcc >/dev/null 2>&1 || { echo "REFUSE(2): no gcc, mode 4 cannot be graded"; exit 2; }
t="$(mktemp -d)" || { echo "REFUSE(2): mktemp"; exit 2; }
trap 'rm -rf "$t"' EXIT
PASS=0; FAIL=0; GRADED=0
# --- the witness: N statements executed inside a CODE()-compiled, DEFINE'd function ------------------
mk() {  # mk <file> <loop-count>
    cat > "$1" <<EOF
	BODY = "F N = GT(N,0) N - 1 :S(F) ;F1 F = N :(RETURN) ;"
	CODE(BODY)						:F(BAD)
	DEFINE("F(N)")
	OUTPUT = "A " &STCOUNT
	Z = F($2)
	OUTPUT = "B " &STCOUNT
	Z = F($2)
	OUTPUT = "C " &STCOUNT
	:(END)
BAD	OUTPUT = "compile failed"
END
EOF
}
run_m3() { timeout -k 5 30 "$S" "$1" < /dev/null 2>&1; }
run_m4() { # compile once per witness, then run
    timeout -k 5 60 "$S" --compile --out="$t/p.s" "$1" < /dev/null > "$t/c.log" 2>&1 \
      && gcc -c "$t/p.s" -o "$t/p.o" >> "$t/c.log" 2>&1 \
      && gcc "$t/p.o" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$t/f.bin" >> "$t/c.log" 2>&1 \
      || { echo "M4-BUILD-FAILED"; return; }
    timeout -k 5 30 "$t/f.bin" < /dev/null 2>&1
}
grade() { # grade <label> <expected-from-oracle> <actual>
    GRADED=$((GRADED + 1))
    if [ "$2" = "$3" ]; then PASS=$((PASS + 1)); return 0; fi
    FAIL=$((FAIL + 1)); echo "RED: $1"; echo "  oracle: $(echo "$2" | tr '\n' '|')"; echo "  scrip : $(echo "$3" | tr '\n' '|')"; return 1
}
# --- arm 1: the counter's VALUE at three points, against the oracle, in both modes -------------------
mk "$t/w5.sno" 5
o1="$("$ORACLE" -bf "$t/w5.sno" < /dev/null 2>&1)"; o2="$("$ORACLE" -bf "$t/w5.sno" < /dev/null 2>&1)"
[ "$o1" = "$o2" ] || { echo "REFUSE(2): the oracle differs from ITSELF on the witness -- it is not deterministic and cannot be a ref"; exit 2; }
case "$o1" in *"compile failed"*|"") echo "REFUSE(2): the oracle itself did not run the witness: $o1"; exit 2;; esac
grade "arm1 m3 -- &STCOUNT across two calls into a CODE()-compiled function" "$o1" "$(run_m3 "$t/w5.sno")"
grade "arm1 m4 -- &STCOUNT across two calls into a CODE()-compiled function" "$o1" "$(run_m4 "$t/w5.sno")"
# --- arm 2: the BOUNDARY -- sweep the work inside the fragment and require the count to track ---------
for n in 1 3 7 12; do
    mk "$t/w$n.sno" "$n"
    ow="$("$ORACLE" -bf "$t/w$n.sno" < /dev/null 2>&1)"
    case "$ow" in *"compile failed"*|"") echo "REFUSE(2): the oracle did not run the sweep witness n=$n"; exit 2;; esac
    grade "arm2 m3 n=$n -- the count tracks the oracle as the fragment's work grows" "$ow" "$(run_m3 "$t/w$n.sno")"
    grade "arm2 m4 n=$n -- the count tracks the oracle as the fragment's work grows" "$ow" "$(run_m4 "$t/w$n.sno")"
done
echo "graded $GRADED witness-modes: PASS=$PASS FAIL=$FAIL (oracle $ORACLE, refs cut from it this run)"
[ "$GRADED" -gt 0 ] || { echo "REFUSE(2): graded zero witnesses"; exit 2; }
[ "$FAIL" -eq 0 ] || exit 1
echo "GREEN: &STCOUNT counts CODE()-compiled statements, and counts the oracle's number of them, in both modes"
