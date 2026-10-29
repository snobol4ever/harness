#!/usr/bin/env bash
# test_gate_sno_a_function_call_trace_names_the_formals_and_never_the_locals.sh
#
# THE ROW (cto mint 2026-10-09, found witnessing the role-4 shim's trace hooks): snobol4-a-function-call-trace-prints-the-locals-as-arguments-
# f-7-reads-f-7-empty-empty. DEFINE('F(X)T,U'), &TRACE = 100, TRACE('F', 'FUNCTION'), OUTPUT = F(7): sbl prints F(7); SCRIP printed F(7,'','').
# THE DEFECT: rt_trace_call_hook, the shim's call-trace hook, sized the traced argument list by rt_proc_nparams -- the whole save list, formals
# then locals -- where the call image stops at nformals. THE CURE: it asks rt_proc_nformals (which answers nparams for a record that records none).
# ARMS, each both modes, every line of the trace (call and return) graded against sbl -bf cut AT RUN TIME: (A) one formal, two locals -- the cto's
# witness; (B) two formals, one local; (C) no formal and one local; (D) a function whose only parameters are locals-free, as the control; (E) a
# function called with FEWER arguments than formals (the missing formal prints null in both) and a nested call, so the trace depth column agrees.
# FAIL-ONCE, MEASURED: arms A B C E read RED on 0b8e936c0 (F(7,'','') for F(X)T,U) and GREEN with the cure.
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
m3() { (cd "$D" && timeout -k 5 60 "$B/scrip" --stlimit "$1.sno" < /dev/null 2>&1); }
m4() { "$B/scrip" --stlimit --compile --out="$D/$1.s" "$D/$1.sno" < /dev/null > /dev/null 2>&1 && gcc -no-pie -o "$D/$1.bin" "$D/$1.s" -L "$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" 2> /dev/null \
      || { echo "M4-BUILD-FAILED"; return; }; (cd "$D" && timeout -k 5 60 "./$1.bin" < /dev/null 2>&1); }
ok()  { n=$((n + 1)); echo "  ok    $*"; }
red() { n=$((n + 1)); RC=1; echo "  RED   $*"; }
arm() {
  local name="$1" want got
  want="$(cd "$D" && timeout -k 5 60 "$SBL" -bf "$name.sno" < /dev/null 2>&1)"
  [ -n "$want" ] || refuse "arm $name: the oracle printed nothing -- the expectation cannot be cut"
  printf '%s' "$want" | grep -q 'F(\|G(\|H(' || refuse "arm $name: the oracle traced no call -- the arm would grade nothing"
  for m in m3 m4; do
    got="$($m "$name")"
    if [ "$got" = "$want" ]; then ok "$name $m: $(printf '%s' "$want" | head -n 1)"; else red "$name $m: want [$(printf '%s' "$want" | head -n 3 | tr '\n' '|')] got [$(printf '%s' "$got" | head -n 3 | tr '\n' '|')]"; fi
  done
}
cat > "$D/a.sno" <<'SNO'
        &TRACE = 100
        DEFINE('F(X)T,U')
        TRACE('F', 'FUNCTION')
        OUTPUT = F(7)
        :(END)
F       T = X + 1
        F = T * 2 :(RETURN)
END
SNO
cat > "$D/b.sno" <<'SNO'
        &TRACE = 100
        DEFINE('F(X,Y)T')
        TRACE('F', 'FUNCTION')
        OUTPUT = F(3, 4)
        :(END)
F       T = X + Y
        F = T * 2 :(RETURN)
END
SNO
cat > "$D/c.sno" <<'SNO'
        &TRACE = 100
        DEFINE('G()T')
        TRACE('G', 'FUNCTION')
        OUTPUT = G()
        :(END)
G       T = 5
        G = T :(RETURN)
END
SNO
cat > "$D/d.sno" <<'SNO'
        &TRACE = 100
        DEFINE('F(X,Y)')
        TRACE('F', 'FUNCTION')
        OUTPUT = F(3, 4)
        :(END)
F       F = X + Y :(RETURN)
END
SNO
cat > "$D/e.sno" <<'SNO'
        &TRACE = 100
        DEFINE('F(X,Y)T,U')
        DEFINE('H(Z)W')
        TRACE('F', 'FUNCTION')
        TRACE('H', 'FUNCTION')
        OUTPUT = F(1)
        :(END)
F       T = H(X)
        F = T :(RETURN)
H       W = Z + 1
        H = W :(RETURN)
END
SNO
for a in a b c d e; do arm "$a"; done
[ "$RC" -eq 0 ] && echo "GREEN: $n arms" || echo "RED: a function call trace names a local as an argument"
exit "$RC"
