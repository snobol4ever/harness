#!/usr/bin/env bash
# test_gate_pl_the_integer_flags_answer_from_the_dialects_row_xsb_and_gnu_bounded_swi_unbounded.sh -- ARCH-PROLOG-DIALECTS.md sec 6 step 4, THE FLAG TABLE IS PER DIALECT:
# current_prolog_flag/2 answers max_integer, min_integer and bounded from the dialect's row -- XSB 9223372036854775807 / -9223372036854775807
# / true, GNU 1152921504606846975 / -1152921504606846976 / true (measured: GNU's min is NOT the negative of its max), SWI bounded false and no
# max_integer or min_integer (the query fails). Integer ARITHMETIC stays SCRIP's bignums in every dialect (CEO-1710).
#
# THE REFS ARE THE ORACLES' OUTPUT, cut when the gate was written: XSB 5.0.0 (xsb_bin), GNU Prolog 1.6.0 through gplc (gplc_bin), swipl 9;
# each is re-cut when its oracle is on the box and the gate refuses rc=2 on disagreement. Each flag is named as a constant: with the name
# bound only at run time, a domain_error raised inside catch/3 hangs SCRIP today (a catch-of-a-generator defect, telegrammed to its row).
#
# RED BEFORE (measured on SCRIP 72fa0fa1b, hq_icon 2026-10-25): the XSB and GNU arms raised domain_error(prolog_flag, max_integer) and
# answered bounded(false) (xsb_tests prolog_tests_arith_op stopped at evl3). GREEN AFTER: the three dialects, m3 and m4, byte-identical to
# their oracle's ref.
#
# Usage: bash ../harness/scripts/test_gate_pl_the_integer_flags_answer_from_the_dialects_row_xsb_and_gnu_bounded_swi_unbounded.sh
set -uo pipefail
GATE_NAME=test_gate_pl_the_integer_flags_answer_from_the_dialects_row_xsb_and_gnu_bounded_swi_unbounded
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
. "$HERE/lib_gate.sh"
. "$HERE/lib_oracle_flags.sh"
gate_parse_args "$@"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
command -v gcc >/dev/null || { echo "⛔ REFUSED(2) [$GATE_NAME]: no gcc -- the mode-4 arm cannot be linked"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cat > "$T/w.pl" <<'PL'
main :- catch((current_prolog_flag(max_integer, A) -> (write(max_integer(A)), nl) ; (write(max_integer(failed)), nl)), E1, (E1 = error(R1, _), write(max_integer(caught(R1))), nl)),
        catch((current_prolog_flag(min_integer, B) -> (write(min_integer(B)), nl) ; (write(min_integer(failed)), nl)), E2, (E2 = error(R2, _), write(min_integer(caught(R2))), nl)),
        current_prolog_flag(bounded, C), write(bounded(C)), nl, current_prolog_flag(integer_rounding_function, D), write(rounding(D)), nl.
PL
cat > "$T/xsb.ref" <<'REF'
max_integer(9223372036854775807)
min_integer(-9223372036854775807)
bounded(true)
rounding(toward_zero)
REF
cat > "$T/gnu.ref" <<'REF'
max_integer(1152921504606846975)
min_integer(-1152921504606846976)
bounded(true)
rounding(toward_zero)
REF
cat > "$T/swi.ref" <<'REF'
max_integer(failed)
min_integer(failed)
bounded(false)
rounding(toward_zero)
REF
recut() { cmp -s "$T/$1.out" "$T/$1.ref" || { echo "⛔ REFUSED(2) [$GATE_NAME]: $2 no longer prints the carried $1.ref -- re-cut it from the oracle, never from SCRIP"; diff "$T/$1.ref" "$T/$1.out" | head -4; exit 2; }; }
if xb="$(xsb_bin 2>/dev/null)"; then ( cd "$T" && timeout -k 5 60 "$xb" --noprompt --quietload --nobanner -e "consult(w), main, halt." < /dev/null 2>/dev/null | grep -v '^\[' > xsb.out ); recut xsb "XSB 5.0.0"; fi
if gc="$(gplc_bin 2>/dev/null)"; then
    ( cd "$T" && { cat w.pl; echo ':- initialization((main, halt)).'; } > wg.pl && timeout -k 5 120 "$gc" -o wg wg.pl > /dev/null 2>&1 && timeout -k 5 20 ./wg < /dev/null > gnu.out 2>/dev/null )
    recut gnu "GNU Prolog 1.6.0 (gplc)"
fi
if command -v swipl > /dev/null; then ( cd "$T" && timeout -k 5 60 swipl -g main -t halt w.pl < /dev/null > swi.out 2>/dev/null ); recut swi "swipl"; fi
{ echo ':- compiler_options([]).'; cat "$T/w.pl"; echo ':- initialization((main, halt)).'; } > "$T/x.pl"
{ cat "$T/w.pl"; echo ':- initialization((main, halt)).'; } > "$T/g.pl"
{ echo ':- use_module(library(lists)).'; cat "$T/w.pl"; echo ':- initialization((main, halt)).'; } > "$T/s.pl"
fail=0
arm() {
    local name=$1 src=$2 ref=$3 sw=$4
    ( cd "$T" && timeout -k 5 20 "$SCRIP" $sw "$src" < /dev/null > "$name.m3" 2>&1 ); local rc3=$?
    if cmp -s "$T/$name.m3" "$T/$ref"; then echo "  ok   ($name m3) 4 flags as $ref"; else echo "  FAIL ($name m3) rc=$rc3, first difference:"; diff "$T/$ref" "$T/$name.m3" | head -6 | sed 's/^/         /'; fail=1; fi
    if ( cd "$T" && "$SCRIP" $sw --compile -o "$name.s" "$src" < /dev/null > /dev/null 2>&1 && gcc -o "$name.bin" "$name.s" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2> /dev/null ); then
        ( cd "$T" && timeout -k 5 20 "./$name.bin" < /dev/null > "$name.m4" 2>&1 ); local rc4=$?
        if cmp -s "$T/$name.m4" "$T/$ref"; then echo "  ok   ($name m4) the same, from the standalone build"; else echo "  FAIL ($name m4) rc=$rc4, first difference:"; diff "$T/$ref" "$T/$name.m4" | head -6 | sed 's/^/         /'; fail=1; fi
    else echo "  FAIL ($name m4) the witness did not compile or link in mode 4"; fail=1; fi
}
arm xsb x.pl xsb.ref ""
arm gnu g.pl gnu.ref "--dialect=gnu"
arm swi s.pl swi.ref ""
[ "$fail" = 0 ] && { echo "✅ GATE PASS [$GATE_NAME]: m3 and m4 answer max_integer, min_integer and bounded from the dialect's row"; exit 0; }
echo "⛔ GATE RED [$GATE_NAME]"; exit 1
