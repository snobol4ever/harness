#!/usr/bin/env bash
# test_gate_pl_portray_reaches_every_subterm_of_print_and_write_term.sh -- print/1, print/2 AND write_term/2,3 WITH portray(true) OR portrayed(true) CALL portray/1 ON EVERY SUBTERM (as swipl; Logtalk print_1, print_2, portray_1, write_term_3 137-145).
# hq_prolog 2026-09-25, CEO-1270. THE DEFECTS: print/1 consulted portray/1 at the top term only (print(A) :- portray(A) -> true ; writeq(A)), so
# print(a(foo)) printed a(foo) where the hook doubles foo; print/2 never consulted it; write_term refused portrayed(true) with domain_error; and
# predicate_property(portray(_), dynamic / multifile) failed where portray/1 is predeclared. THE CURE routes all three writers through format's ~p,
# the C writer path that already calls portray/1 on every subterm from a plain leaf (lower_prolog.c pl_cc_print_via_format; write_term takes it when
# its option list is known at compile time to be portray/portrayed(true), optionally with numbervars(true)). Calling the hook from write_term's own
# context-carrying leaf re-entered Prolog and corrupted its trail (SIGSEGV in rt_pl_tr_unwind) -- measured, and not the route taken. A portray/1
# THROW now propagates (plc_portray_hit takes the pending ball; ~p raises it), which closes the named gap in
# test_gate_pl_print_1_honours_portray_and_costs_nothing_without_it.sh. NO MONITOR BRACKET: output divergences, compared line for line with swipl.
# RED BEFORE on origin, m3 AND m4: seven of eight lines.
set -u
GATE_NAME=test_gate_pl_portray_reaches_every_subterm_of_print_and_write_term
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
cat > "$TMPD/w.pl" <<'EOP'
portray(Atom) :- atom(Atom), Atom \== [], write(Atom), write(Atom).
portray(Float) :- float(Float), Integer is truncate(Float), write(Integer).
main :- print(a(foo, b(c(foo, 3.14)))), nl, print([x, 2.5]), nl, current_output(S), print(S, f(bar)), nl,
        write_term(g(baz, 1.5), [portray(true)]), nl, write_term(S, h(qux), [portray(true), numbervars(true)]), nl,
        write_term(k(foo), [quoted(true)]), nl,
        ( predicate_property(portray(_), dynamic) -> write(dynamic) ; write(not_dynamic) ), nl,
        ( predicate_property(portray(_), multifile) -> write(multifile) ; write(not_multifile) ), nl.
:- initialization(main).
EOP
want='a(foofoo,b(c(foofoo,3)))
[xx,2]
f(barbar)
g(bazbaz,1)
h(quxqux)
k(foo)
dynamic
multifile'
red=0
for mode in m3 m4; do
    if [ "$mode" = m3 ]; then got="$(cd "$TMPD" && timeout -k 5 20 "$SCRIP" w.pl </dev/null 2>"$TMPD/err")"; rc=$?
    else
        timeout -k 5 60 "$SCRIP" --compile -o "$TMPD/w.s" "$TMPD/w.pl" </dev/null 2>"$TMPD/err" || refuse "m4 compile failed: $(head -c 160 "$TMPD/err")"
        gcc -m64 -no-pie "$TMPD/w.s" -o "$TMPD/w.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || refuse "m4 link failed: $(head -c 160 "$TMPD/err")"
        got="$(cd "$TMPD" && timeout -k 5 20 ./w.bin </dev/null 2>"$TMPD/err")"; rc=$?
        rm -f "$TMPD/w.s" "$TMPD/w.bin"
    fi
    if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  $mode"
    else echo "  RED $mode: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|' | cut -c1-200)] want [$(printf '%s' "$want" | tr '\n' '|')]"; red=$((red+1)); fi
done
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red mode(s) red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: portray/1 reaches every subterm of print and portray-writing write_term, both modes as swipl"
exit 0
