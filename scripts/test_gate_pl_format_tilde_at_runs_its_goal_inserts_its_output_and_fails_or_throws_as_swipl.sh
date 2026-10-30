#!/usr/bin/env bash
# test_gate_pl_format_tilde_at_runs_its_goal_inserts_its_output_and_fails_or_throws_as_swipl.sh -- format's ~@ RUNS THE GOAL (ceo CEO-1930, hq_icon on the SWI umbrella; swipl 9.0.4).
# SWI's format/2,3 directive ~@ takes the next argument as a goal, runs it once with current_output redirected, inserts what it wrote at that point of the line (the column stops ~t ~| see it),
# and fails when the goal fails or raises its exception, AFTER the text so far and the goal's own output are written. SCRIP read the directive as an unknown one and ignored it, so
# core/test_format fail#1 (format('~@', [fail]) must fail) and fail#2 (format('~@', [throw(error(42))]) must throw) read red in both modes, and format('~@', [write(hi)]) printed nothing.
# THE WITNESS (SWI dialect, selected by the use_module line as the suite's files are): 17 shapes -- a failing goal, a throwing goal, a goal that writes and then fails or throws, two ~@
# in one line, a column fill around one, format(atom(A),...), the unbound goal (instantiation_error), the non-callable goal (type_error(callable,3)), a goal that leaves a choice (once), an
# unknown procedure, a nested format, format(atom(_)) over a failing goal, with_output_to over one -- each answered as `Text => succeeded|failed|raised(F)|threw(B)`.
# ARMS: the expected text is RE-CHECKED against live swipl on every run (an oracle that cannot answer REFUSES rc 2, one that disagrees reds the gate), then mode 3 and mode 4 each equal it.
# RED BEFORE (measured 2026-10-29 on the commit before the cure): the suite's two cases read red in both modes; this witness differs from swipl in m3 and m4.
# rc 0 every arm holds; 1 an arm is red; 2 cannot measure.
GATE_NAME=test_gate_pl_format_tilde_at_runs_its_goal_inserts_its_output_and_fails_or_throws_as_swipl
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SCRIP="$ROOT/SCRIP/scrip"
RT="${RT_DIR:-$ROOT/SCRIP/out}"
SWIPL=/usr/bin/swipl
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -x "$SWIPL" ] || refuse "no swipl oracle at $SWIPL"
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
red=0; total=0
cat > "$TMPD/w.pl" <<'EOP'
:- use_module(library(lists)).
:- initialization(main).
t(G) :- catch(( call(G) -> R = succeeded ; R = failed ), E, ( E = error(F, _) -> R = raised(F) ; R = threw(E) )), write(' => '), write(R), nl.
main :-
    t(format('a~@b', [fail])),
    t(format('a~@b', [throw(oops)])),
    t(format('a~@b', [(write(x), fail)])),
    t(format('a~@b', [(write(x), throw(oops))])),
    t(format('a~@b~@c', [write(1), write(2)])),
    t(format('~a~t~@~20|~a', [ab, write(mid), z])),
    t(format('~t~@~10|', [write(right)])),
    t(format(atom(A), 'p~@q', [write(zz)])), write(A), nl,
    t(format(atom(_), 'p~@q', [fail])),
    t(format('~@', [_])),
    t(format('~@', [3])),
    t(format('~@', [(member(Y,[1,2]), write(Y))])), nl,
    t(format('~@~@', [write(a), nofunc_here])),
    t(format('~@ ~w ~@~n', [write(1), two, write(3)])),
    t(format('~@~n', [format('~a-~a', [in, ner])])),
    t(format('~@', [format('~@', [fail])])),
    with_output_to(string(S), format('x~@y', [write(1)])), write(S), nl,
    halt.
EOP
WANT="$(printf '%s\n' 'a => failed' 'a => threw(oops)' 'ax => failed' 'ax => threw(oops)' 'a1b2c => succeeded' 'ab               midz => succeeded' '     right => succeeded' ' => succeeded' 'pzzq' ' => failed' ' => raised(instantiation_error)' ' => raised(type_error(callable,3))' '1 => succeeded' '' 'a => raised(existence_error(procedure,nofunc_here/0))' '1 two 3' ' => succeeded' 'in-ner' ' => succeeded' ' => failed' 'x1y')"
check() {
    local name="$1" got="$2"
    total=$((total+1))
    if [ "$got" = "$WANT" ]; then echo "  ok  $name"
    else echo "  RED $name: differs from the expected text:"; diff <(printf '%s\n' "$WANT") <(printf '%s\n' "$got") | head -8 | sed 's/^/      /'; red=$((red+1)); fi
}
got_swi="$(timeout -k 5 30 "$SWIPL" -q "$TMPD/w.pl" </dev/null 2>&1)" || refuse "swipl could not run the witness"
check "the expected text is what live swipl prints" "$got_swi"
got_m3="$(timeout -k 5 60 "$SCRIP" "$TMPD/w.pl" </dev/null 2>&1)"
check "mode 3 equals swipl" "$got_m3"
if timeout -k 5 60 "$SCRIP" --compile --out="$TMPD/w.s" "$TMPD/w.pl" </dev/null 2> "$TMPD/err" > /dev/null && gcc -m64 -no-pie "$TMPD/w.s" -o "$TMPD/w.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2> "$TMPD/err"; then
    got_m4="$(timeout -k 5 60 "$TMPD/w.bin" </dev/null 2>&1)"
else
    refuse "the mode-4 compile or link failed: $(head -c 200 "$TMPD/err")"
fi
check "mode 4 equals swipl" "$got_m4"
if [ "$red" = 0 ]; then echo "✅ GATE PASS [$GATE_NAME]: $total of $total arms hold"; exit 0; fi
echo "⛔ GATE FAIL [$GATE_NAME]: $red of $total arm(s) red"; exit 1
