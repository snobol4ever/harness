#!/usr/bin/env bash
# test_gate_pl_iso_rung8_an_unbounded_integer_literal_reads_writes_and_computes.sh -- PROLOG ISO LADDER, RUNG 8 (cto, CEO-617/650, 2026-09-13).
# THE RUNG: a Prolog integer literal wider than 64 bits is READ as an unbounded integer, not silently wrapped.
# It writes back as its own digits, answers integer/1, unifies and compares as an integer, and carries through
# + - * // and unary minus; current_prolog_flag(bounded, B) answers false, as ISO 7.11.1.1 requires of an
# implementation with unbounded integers. The oracle is swipl 9 (gprolog 1.4.5 is a BOUNDED implementation and
# is not an oracle for this rung); the Logtalk floors below carry ISO/IEC 13211-1's own cited expectations.
# ⛔ THE SHARED BIGNUM CORE IS NOT NEW: src/runtime/bignum.c (DT_BIG, rt_big_from_str/add/sub/mul/div/neg/str)
# already serves Icon and SNOBOL4 through arithmetic.c's big_str_operand. This rung wires the Prolog reader onto
# it; a SECOND bignum would be the duplication Lon ruled out on 2026-09-02 ("No need to create a new BB that
# does exactly what one already does").
# RED BEFORE on the clean origin build 71b32337f: a(-1) b(yes) c(0) d(-3) e(-2) f(1) g(no) h(yes) i(yes) j(0)
# -- the literal wraps to -1 at the reader and every line downstream is decided by that; Logtalk unbounded 29/111.
set -u
GATE_NAME=test_gate_pl_iso_rung8_an_unbounded_integer_literal_reads_writes_and_computes
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SUITE="${S4E_CORPUS:-$ROOT/corpus}/packages/prolog/logtalk_iso"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -d "$SUITE" ] || refuse "no vendored suite at $SUITE"
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
MODES="${PL_RUNG_MODES:-m3,m4}"
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
red=0; total=0
floor() {
    local group="$1" want="$2" line pass
    line="$(python3 "$HERE/util_logtalk_grade.py" --suite "$SUITE" --scrip "$SCRIP" --modes "$MODES" --jobs "${PL_RUNG_JOBS:-8}" --group "$group" 2>/dev/null | grep -m1 '^LOGTALK_ISO_BOARD ')"
    [ -n "$line" ] || { echo "  ⛔ $group: the grader printed no LOGTALK_ISO_BOARD line"; red=$((red+1)); total=$((total+1)); return; }
    pass="$(printf '%s\n' "$line" | sed -n 's/.*m3_pass=\([0-9]*\).*/\1/p')"
    total=$((total+1))
    if [ "${pass:-0}" -ge "$want" ]; then echo "  ok  $group m3_pass=$pass (floor $want)  $line"
    else echo "  RED $group m3_pass=$pass < floor $want  $line"; red=$((red+1)); fi
    case "$MODES" in *m4*)
        local p4; p4="$(printf '%s\n' "$line" | sed -n 's/.*m4_pass=\([0-9]*\).*/\1/p')"
        if [ -n "$p4" ] && [ "$p4" -lt "$want" ]; then echo "  RED $group m4_pass=$p4 < floor $want (modes may diverge as an optimization, never here)"; red=$((red+1)); fi ;;
    esac
}
run_m3() { timeout -k 5 20 "$SCRIP" "$1" </dev/null 2>"$TMPD/err"; }
run_m4() {
    local src="$1" s="$TMPD/w.s" b="$TMPD/w.bin"
    timeout -k 5 60 "$SCRIP" --compile --out="$s" "$src" </dev/null 2>"$TMPD/err" || { echo "  (m4: compile failed: $(head -c 160 "$TMPD/err"))"; return 97; }
    gcc -m64 -no-pie "$s" -o "$b" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || { echo "  (m4: link failed: $(head -c 160 "$TMPD/err"))"; return 98; }
    timeout -k 5 20 "$b" </dev/null 2>"$TMPD/err"
}
arm() {
    local name="$1" src="$2" want_out="$3" want_rc="$4" mode got rc
    for mode in m3 m4; do
        case "$MODES" in *"$mode"*) : ;; *) continue ;; esac
        total=$((total+1))
        got="$("run_$mode" "$src")"; rc=$?
        if [ "$got" = "$want_out" ] && [ "$rc" = "$want_rc" ]; then echo "  ok  $name $mode"
        else echo "  RED $name $mode: rc=$rc want $want_rc; out=[$got] want [$want_out] $(head -c 200 "$TMPD/err" 2>/dev/null)"; red=$((red+1)); fi
    done
}
cat > "$TMPD/big.pl" <<'EOP'
:- initialization(main).
main :-
    X = 123456789012345678901234567890, write(a(X)), nl,
    ( integer(X) -> write(b(yes)) ; write(b(no)) ), nl,
    Y is 123456789012345678901234567890 + 1, write(c(Y)), nl,
    Z is 123456789012345678901234567890 * 3, write(d(Z)), nl,
    S is 123456789012345678901234567891 - 1, write(e(S)), nl,
    N is -(123456789012345678901234567890), write(f(N)), nl,
    ( 123456789012345678901234567890 > 999999999999999999 -> write(g(yes)) ; write(g(no)) ), nl,
    ( X == 123456789012345678901234567890 -> write(h(yes)) ; write(h(no)) ), nl,
    ( X = 123456789012345678901234567890 -> write(i(yes)) ; write(i(no)) ), nl,
    Q is 123456789012345678901234567890 // 3, write(j(Q)), nl,
    ( current_prolog_flag(bounded, B) -> write(k(B)) ; write(k(noflag)) ), nl,
    ( 7 =:= 7 -> write(l(yes)) ; write(l(no)) ), nl,
    M is 2 + 3, write(m(M)), nl,
    halt.
EOP
arm an_unbounded_integer_literal_reads_writes_and_computes "$TMPD/big.pl" "$(printf '%s\n' 'a(123456789012345678901234567890)' 'b(yes)' 'c(123456789012345678901234567891)' 'd(370370367037037036703703703670)' 'e(123456789012345678901234567890)' 'f(-123456789012345678901234567890)' 'g(yes)' 'h(yes)' 'i(yes)' 'j(41152263004115226300411522630)' 'k(false)' 'l(yes)' 'm(5)')" 0
floor unbounded 82
echo "$GATE_NAME: arms=$total red=$red modes=$MODES"
[ "$red" -eq 0 ] || { echo "⛔ $GATE_NAME RED"; exit 1; }
echo "✅ $GATE_NAME GREEN"
