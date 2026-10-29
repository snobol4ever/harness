#!/usr/bin/env bash
# test_gate_pl_clause_2_reads_static_code_on_every_road_and_obeys_the_iso_and_protect_flags.sh -- clause/2 ON A STATIC USER PROCEDURE ANSWERS THROUGH ALL THREE ROADS, AND THE FLAGS RULE WHEN IT RAISES.
# hq_prolog 2026-10-03, ceo CEO-1467 (method approved in-chat: seed in the startup block the static predicates a clause/2 or clause/3 term names,
# goal OR data, and all static ones when such a head is a variable). THE THREE ROADS: a literal head at a call site, a head built at run time
# (T =.. [h3, _], clause(T, B)), and a goal reached as DATA through call/1 (core/test_call's two clause tests run as pj_test bodies). Before the cure the
# last two FAILED on a static procedure (no clause terms in the db: only a literal-head site seeded them) while the first answered.
# THE RULE (ruled CEO-1467, the superset): the DEFAULT answers like swipl; under set_prolog_flag(iso, true) AND under protect_static_code true a head that
# resolves to a user static procedure raises permission_error(access, private_procedure, PI) (ISO 8.8.1.3 e, gprolog's reading); a builtin or control
# head raises on every road under every flag; a dynamic procedure always answers; an unknown one fails. Each variant is run in m3 AND m4.
# RED BEFORE on origin c0fbd4343, m3 AND m4 (measured, a stashed-cure rebuild): the default variant RAISED on every static row (the flag defaulted true), and
# protect_static_code=false read `no` on the run-time-head, call/1 and call1_a rows (the plunit shim's own setting, core/test_call 32 of 34); iso/protect=true rows already raised.
set -u
GATE_NAME=test_gate_pl_clause_2_reads_static_code_on_every_road_and_obeys_the_iso_and_protect_flags
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
cat > "$TMPD/body.pl" <<'EOP'
h3(2).
h3(3).
call1_a(X) :- X.
:- dynamic d1/1.
d1(5).
r(G) :- catch((call(G) -> write(yes) ; write(no)), error(permission_error(A, B, PI), _), (write(perm(A, B, PI)))), nl.
t :- T = atom(_), r(clause(T, _)),
     r(clause(atom(_), _)),
     r(call(clause(atom(_), _))),
     r((clause(h3(X), B), X == 2, B == true)),
     Y = h3, U =.. [Y, _], r(clause(U, _)),
     r(call(clause(h3(_), _))),
     r((G = clause(call1_a(Z), Body), call(G), Body == call(Z))),
     r(call(clause(d1(_), _))),
     r(call(clause(nosuch(_), _))),
     r(call(clause((a, b), _))).
:- initialization(t).
EOP
want_builtin='perm(access,private_procedure,atom/1)
perm(access,private_procedure,atom/1)
perm(access,private_procedure,atom/1)'
want_tail='yes
no
perm(access,private_procedure,(,)/2)'
want_open="$want_builtin
yes
yes
yes
yes
$want_tail"
want_shut="$want_builtin
perm(access,private_procedure,h3/1)
perm(access,private_procedure,h3/1)
perm(access,private_procedure,h3/1)
perm(access,private_procedure,call1_a/1)
$want_tail"
red=0; n=0
run_one() {
    local variant="$1" directive="$2" want="$3" mode got rc
    { [ -n "$directive" ] && printf ':- set_prolog_flag(%s).\n' "$directive"; cat "$TMPD/body.pl"; } > "$TMPD/w.pl"
    for mode in m3 m4; do
        n=$((n+1))
        if [ "$mode" = m3 ]; then got="$(cd "$TMPD" && timeout -k 5 20 "$SCRIP" w.pl </dev/null 2>"$TMPD/err")"; rc=$?
        else
            timeout -k 5 60 "$SCRIP" --compile --out="$TMPD/w.s" "$TMPD/w.pl" </dev/null 2>"$TMPD/err" || refuse "m4 compile failed: $(head -c 160 "$TMPD/err")"
            gcc -m64 -no-pie "$TMPD/w.s" -o "$TMPD/w.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || refuse "m4 link failed: $(head -c 160 "$TMPD/err")"
            got="$(cd "$TMPD" && timeout -k 5 20 ./w.bin </dev/null 2>"$TMPD/err")"; rc=$?
            rm -f "$TMPD/w.s" "$TMPD/w.bin"
        fi
        if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  $variant $mode"
        else echo "  RED $variant $mode: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|' | cut -c1-330)] want [$(printf '%s' "$want" | tr '\n' '|' | cut -c1-330)]"; red=$((red+1)); fi
    done
}
run_one "default (answers like swipl)" "" "$want_open"
run_one "protect_static_code=false" "protect_static_code, false" "$want_open"
run_one "iso=true (raises)" "iso, true" "$want_shut"
run_one "protect_static_code=true (raises)" "protect_static_code, true" "$want_shut"
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red of $n variant-mode runs red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: clause/2 answers a static user procedure on the literal, run-time-head and call/1 roads by default and raises under iso or protect_static_code, a builtin or control head always raises, $n runs, both modes"
exit 0
