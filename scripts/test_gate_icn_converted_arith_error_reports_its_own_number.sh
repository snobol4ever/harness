#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_icn_converted_arith_error_reports_its_own_number.sh -- THE INVARIANT GATE for the &error := -1
# CONVERSION CLASS in shared arithmetic (CEO-532, hq_U 2026-09-10).  Under error conversion an arithmetic
# operation that cannot produce a value must RAISE ITS OWN error before it fails, so that &errornumber,
# &errortext and &errorvalue describe THIS operation.  The measured defect: a DT_I fast block that returns
# FAILDESCR ahead of the frame's own setjmp raises nothing at all, and the three keywords keep whatever the
# PREVIOUS error left in them -- 1 / 0 reached by-name reported 102 "numeric expected" with errorvalue "a".
#
# ⛔⭐ WHY EVERY WITNESS CARRIES A PRIMER, AND WHY THE PRIMER'S NUMBER IS DELIBERATELY NOT THE ANSWER.
# A silent failure is invisible to any gate that only reads the RESULT: the expression fails either way, so
# result-only grading calls the defect green.  It is equally invisible to a gate that runs the cases in one
# process in an order where neighbouring cases expect the SAME number -- the stale value is then the right
# value by accident.  So each witness runs ALONE, preceded by a primer error whose number (102) is not the
# answer to any case in the population.  A case that raises nothing therefore reads 102, and 102 is never
# correct here.  That is what turns "did it report a number" into "did it report ITS OWN number", which is
# the whole claim.  ⭐ THE DENOMINATOR DESCRIBES THE DEFECT SPACE, NOT THE ARMS: the population is every
# arithmetic shape whose zero divisor is reachable through a DIFFERENT dispatch route -- static (rt_div),
# dynamic (rt_num_arith via by-name invocation), integer and real -- because the defect was route-specific
# and a gate holding only the static route would have printed a full green over it (hq_T, 2026-09-10).
#
# ⛔ THE ORACLE CUTS EVERY ANSWER ON EVERY RUN -- never a stored .ref.  A .ref is a photograph of what SCRIP
# printed the day it was cut, and this class was WRONG on the day any such .ref would have been cut.
#
# ⛔ ARM B IS A MUTATION ARM AND IT IS NOT OPTIONAL.  It grades a witness that deliberately does NOT raise
# against the oracle answer for one that does, and REFUSES rc=2 if the comparator calls that agreement.  A
# criterion nobody has watched say NO is not a criterion.  ⛔ ARM C names a timeout as TIMEOUT: an rc=124
# cannot distinguish "needed one more second" from "never finishes", and a gate that grades only values
# calls a hang green.
#
# EXIT: 0 every witness agrees with the oracle in both modes · 1 any disagreement · 2 REFUSED (cannot measure).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S4E="$(cd "$ROOT/.." && pwd)"
RT="$ROOT/out"
# ⭐ FAIL-ONCE HOOK: the ONLY override this gate honours -- point it at a binary with the cure backed out and
# the gate must go RED (DIFF>0, rc=1).  Proven that way before wiring.
SCRIP="${ICNARITH_SCRIP:-$ROOT/scrip}"
T="${TIMEOUT:-20}"
NAME=icn_converted_arith_error_reports_its_own_number
refuse() { echo "⛔ GATE REFUSE(2) [$NAME]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "cannot source lib_oracle_flags.sh"
ICONT="$(icont_bin)" || refuse "no icont oracle (lib_oracle_flags icont_bin) -- a missing oracle prints a full, plausible, entirely false all-FAIL table"
ICONX="$(iconx_bin)" || refuse "no iconx oracle (lib_oracle_flags iconx_bin)"
[ -x "$SCRIP" ] || refuse "$SCRIP is not built -- run make"
[ -f "$RT/libscrip_rt.so" ] || refuse "$RT/libscrip_rt.so missing -- run make"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
# THE POPULATION.  name|expression -- one witness per DISPATCH ROUTE reaching a zero divisor, integer and
# real, static and by-name.  The primer is fixed and its number (102) answers none of them.
POP='int_div_static|1 / 0
int_mod_static|1 % 0
real_div_both|1.0 / 0.0
real_mod_both|1.0 % 0.0
int_over_real_zero|1 / 0.0
real_over_int_zero|1.0 / 0
str_div_str_zero|"1" / "0"
int_div_byname|"/"(1, 0)
int_mod_byname|"%"(1, 0)'
PRIMER='("a" + 1) | &null;'
emit() {   # $1 = expression, $2 = out path
    { echo 'procedure main()'
      echo "   &error := -1;"
      echo "   $PRIMER"
      echo "   write(\"r=\", image($1) | \"FAIL\");"
      echo '   write("n=", (&errornumber) | "-");'
      echo '   write("t=", image(&errortext) | "-");'
      echo '   write("v=", image(&errorvalue) | "-");'
      echo 'end'
    } > "$2"
}
run_oracle() {   # $1 = src -> stdout, or empty on refusal
    ( cd "$W" && "$ICONT" -s -o oracle_bin "$1" >/dev/null 2>&1 ) || return 1
    ( cd "$W" && timeout -k 5 "$T" ./oracle_bin < /dev/null 2>/dev/null ); return 0
}
run_m3() { timeout -k 5 "$T" "$SCRIP" "$1" < /dev/null 2>/dev/null; }
run_m4() {
    "$SCRIP" --compile -o "$W/w.s" "$1" < /dev/null > /dev/null 2>&1 || return 1
    gcc -m64 -no-pie "$W/w.s" -o "$W/w_m4" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm -lpthread > /dev/null 2>&1 || return 1
    timeout -k 5 "$T" "$W/w_m4" < /dev/null 2>/dev/null; return 0
}
one_line() { tr '\n' ' ' | sed 's/  */ /g; s/ $//'; }
echo "=== Icon converted-arithmetic-error gate (oracle-cut every run, both modes) ==="
echo "oracle: $ICONT / $ICONX"
echo "binary: $SCRIP"
echo "primer: an error numbered 102, which is the answer to NO witness below"
printf '%-22s | %-3s | %s\n' witness mode verdict
fail=0; graded=0; timeouts=0
while IFS='|' read -r nm expr; do
    [ -n "$nm" ] || continue
    src="$W/w.icn"; emit "$expr" "$src"
    orac="$(run_oracle "$src" | one_line)" || { echo "REFUSE: icont will not compile witness $nm"; exit 2; }
    [ -n "$orac" ] || refuse "oracle produced no output for $nm -- it has not graded this witness"
    case "$orac" in *"n=102"*) refuse "oracle itself reports the primer's number for $nm -- the primer is not a control, rewrite it" ;; esac
    for mode in m3 m4; do
        if [ "$mode" = m3 ]; then got="$(run_m3 "$src")"; rc=$?; else got="$(run_m4 "$src")"; rc=$?; fi
        got="$(printf '%s' "$got" | one_line)"
        graded=$((graded + 1))
        if [ "$rc" = 124 ]; then timeouts=$((timeouts + 1)); fail=$((fail + 1)); printf '%-22s | %-3s | TIMEOUT after %ss -- a hang, not a wrong value\n' "$nm" "$mode" "$T"; continue; fi
        if [ "$got" = "$orac" ]; then printf '%-22s | %-3s | ok   %s\n' "$nm" "$mode" "$orac"
        else fail=$((fail + 1)); printf '%-22s | %-3s | DIFF want[%s] got[%s]\n' "$nm" "$mode" "$orac" "$got"; fi
    done
done <<< "$POP"
[ "$graded" -gt 0 ] || refuse "graded ZERO witnesses -- a runner that cannot measure must never print the success shape"
# ARM B -- THE MUTATION ARM.  A witness that raises nothing, graded against the answer for one that does.
emit '1 / 1' "$W/neg.icn"; emit '1 / 0' "$W/pos.icn"
neg_got="$(run_m3 "$W/neg.icn" | one_line)"
pos_want="$(run_oracle "$W/pos.icn" | one_line)" || refuse "icont will not compile the mutation witness"
[ -n "$pos_want" ] || refuse "mutation arm has no oracle answer to grade against"
case "$neg_got" in *"n=102"*) : ;; *) refuse "mutation arm: a non-raising witness did not read the primer's 102 (got [$neg_got]) -- the primer is not doing its job" ;; esac
[ "$neg_got" != "$pos_want" ] || refuse "mutation arm: the comparator called a non-raising witness equal to a raising one -- this gate cannot say NO and its greens mean nothing"
echo "mutation arm: ok -- a non-raising witness reads the primer's 102 and the comparator calls it DIFF"
echo "$NAME: graded=$graded DIFF=$fail TIMEOUT=$timeouts over $(printf '%s\n' "$POP" | grep -c .) witnesses x 2 modes"
if [ "$fail" -gt 0 ]; then echo "❌ GATE FAIL(1) [$NAME]: $fail of $graded arms disagree with the oracle"; exit 1; fi
echo "✅ GATE PASS(0) [$NAME]: $graded/$graded -- every converted arithmetic error reports its own number in both modes"
exit 0
