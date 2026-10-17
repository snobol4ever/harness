#!/usr/bin/env bash
# test_gate_sno_eval_inside_a_disjunction_pops_its_spine_record_before_the_result_lands.sh
#
# THE ROW: the coo's pass-42 RED, Gimpel infinip 144/145 (infinip.spt line 42, result = (APPLY(map[op],EVAL(a),EVAL(b)), "fail")).
# THE DEFECT (bisected by two scratch builds to bfedbba00, the EVAL record on the spine): the EVAL box carves a 112-byte record
# (sub rsp, 112) before rt_eval_open. The ZD road (_.op_zres) pops it at its join label; the FRAME road (every EVAL that is an operand
# of a DISJUNCTION or any other non-ZD site) did NOT, so the result landed at [rsp + resoff] with rsp 112 low -- an empty result in
# mode 3 and mode 4, a SIGSEGV at pc 0x3 inside a DEFINE'd function. The declined road (rt_eval_open answers 0) also handed the
# by-name call its argument address 112 low.
# ARMS, each both modes, expectations cut from sbl -bf AT RUN TIME: (A) a top-level disjunction whose first arm is an EVAL;
# (B) the same inside a DEFINE'd function, called twice (the spine must balance across calls); (C) the declined road (EVAL of a
# number and of a non-string) inside a disjunction; (D) the infinip shape -- APPLY of a name with two EVAL operands inside a function.
# FAIL-ONCE, MEASURED: arms A-D read RED on bfedbba00 (r= empty, SIGSEGV in B and D) and GREEN with the cure.
# rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- the expectations are cut from it at run time"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
RT="$B/out"; RC=0; n=0
m3() { (cd "$D" && timeout -k 5 60 "$B/scrip" "$1.sno" < /dev/null 2>&1); }
m4() { "$B/scrip" --compile -o "$D/$1.s" "$D/$1.sno" < /dev/null > /dev/null 2>&1 && gcc -no-pie -o "$D/$1.bin" "$D/$1.s" -L "$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" 2> /dev/null \
      || { echo "M4-BUILD-FAILED"; return; }; (cd "$D" && timeout -k 5 60 "./$1.bin" < /dev/null 2>&1); }
ok()  { n=$((n + 1)); echo "  ok    $*"; }
red() { n=$((n + 1)); RC=1; echo "  RED   $*"; }
arm() {
  local name="$1" want got
  want="$(cd "$D" && timeout -k 5 60 "$SBL" -bf "$name.sno" < /dev/null 2>&1)"
  [ -n "$want" ] || refuse "arm $name: the oracle printed nothing -- the expectation cannot be cut"
  for m in m3 m4; do
    got="$($m "$name")"
    if [ "$got" = "$want" ]; then ok "$name $m: $(printf '%s' "$want" | tr '\n' '|')"; else red "$name $m: want [$(printf '%s' "$want" | tr '\n' '|')] got [$(printf '%s' "$got" | head -n 3 | tr '\n' '|')]"; fi
  done
}
cat > "$D/a.sno" <<'SNO'
        big = 5
        r = (EVAL('big'), 'fail')
        OUTPUT = 'r=' r
        r = (EVAL('big + 1'), EVAL('big'))
        OUTPUT = 'r2=' r
        r = (DIFFER(1), EVAL('big * 2'))
        OUTPUT = 'r3=' r
END
SNO
cat > "$D/b.sno" <<'SNO'
        DEFINE('f(a,b)result')
        big = 5
        OUTPUT = f('big', 'big')
        OUTPUT = f('big', 'big')
        :(END)
f       result = (EVAL(a), 'fail')
        OUTPUT = 'r=' result :(RETURN)
END
SNO
cat > "$D/c.sno" <<'SNO'
        DEFINE('f(a)result')
        r = (EVAL(7), 'fail')
        OUTPUT = 'n=' r
        r = (EVAL(.NAME), 'fail')
        OUTPUT = 'nm=' DATATYPE(r)
        OUTPUT = f(3)
        :(END)
f       result = (EVAL(a), 'fail')
        f = 'got ' result :(RETURN)
END
SNO
cat > "$D/d.sno" <<'SNO'
        DEFINE('add(x,y)')
        DEFINE('f(op,a,b)result')
        big = 5
        small = 4
        map = TABLE()
        map['+'] = 'add'
        f('+', 'big', 'small')
        f('+', 'small', 'big')
        OUTPUT = 'done'
        :(END)
add     add = x + y :(RETURN)
f       result = (APPLY(map[op], EVAL(a), EVAL(b)), 'fail')
        OUTPUT = EVAL(a) ' ' op ' ' EVAL(b) ' = ' result :(RETURN)
END
SNO
for a in a b c d; do arm "$a"; done
[ "$RC" -eq 0 ] && echo "GREEN: $n arms" || echo "RED: a disjunction holding an EVAL lands its result with the spine record still carved"
exit "$RC"
