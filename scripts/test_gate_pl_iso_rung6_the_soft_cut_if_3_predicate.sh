#!/usr/bin/env bash
# test_gate_pl_iso_rung6_the_soft_cut_if_3_predicate.sh -- PROLOG ISO LADDER, RUNG 6 (cto, CEO-617/650, 2026-09-12).
# THE RUNG: the soft-cut if/3 predicate (Logtalk control/if_3; SICStus/YAP/ECLiPSe/Ciao if(:C,:T,:E)): if(C,T,E) is
# (call(C) *-> call(T) ; call(E)) -- the condition is opaque to cut (`if((!,fail),true,fail)` fails into the NEXT
# clause of its caller), every solution of the condition drives the then-branch, the else-branch runs only when the
# condition has no solution, and a non-callable in ANY of the three arms raises type_error(callable, Arm) -- as a
# compile-time body goal AND as a term built at run time and reaching call/1 (the run-time wrapper if/3 is minted
# beside ,/2 ;/2 ->/2 *->/2). A program that defines its OWN if/3 keeps it: if/3 is not an ISO control construct,
# so the builtin is admitted only when the program has no clauses for if/3 (no corpus program defines one).
# THE SECOND DEFECT THE RUNG UNCOVERED, in the shared soft cut itself: `(a(X) *-> call(b(Y)) ; E)` with a
# nondeterministic then-branch entered through call/1 looped on the LAST solution forever (1-6 1-6 1-6 ...): the
# call/1 barrier is an IR_GOTO whose gamma edge the then-branch conjunction wired to the condition's redo point as a
# fresh alpha entry, so exhausting b(Y) re-RAN a(1) instead of resuming a/1; pl_lower_softcut now marks gamma edges
# into the condition's redo point beta as it already did omega edges. Both shapes are witness lines below.
# RED BEFORE on a clean origin build 43638b186: Logtalk if_3 1/12 both modes (11 x existence_error(procedure,if/3));
# the witness's first arm did not run at all; the bare soft-cut shape overflowed the stack under findall/3.
set -u
GATE_NAME=test_gate_pl_iso_rung6_the_soft_cut_if_3_predicate
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
    timeout -k 5 60 "$SCRIP" --compile -o "$s" "$src" </dev/null 2>"$TMPD/err" || { echo "  (m4: compile failed: $(head -c 160 "$TMPD/err"))"; return 97; }
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
cat > "$TMPD/if3.pl" <<'EOP'
:- initialization(main).
a(1). a(2). a(3).
b(4). b(5). b(6).
c(7). c(8). c(9).
coc :- if((!, fail), true, fail).
coc.
coc(1) :- if(!, true, fail).
coc(2).
three(3).
chk(N, G, Want) :- catch((call(G) -> R = yes ; R = no), error(E, _), R = E), ( R == Want -> write(ok(N)) ; write(bad(N, R)) ), nl.
main :-
    ( if(true, true, fail) -> write(ok(a)) ; write(bad(a)) ), nl,
    ( if(fail, true, true) -> write(ok(b)) ; write(bad(b)) ), nl,
    ( if(true, fail, fail) -> write(bad(c)) ; write(ok(c)) ), nl,
    ( if(fail, true, fail) -> write(bad(d)) ; write(ok(d)) ), nl,
    findall(X-Y, if(a(X), b(Y), c(_)), L1), write(L1), nl,
    findall(Z, if(fail, b(_), c(Z)), L2), write(L2), nl,
    findall(Z, if((!, fail), b(_), c(Z)), L3), write(L3), nl,
    ( coc -> write(ok(e)) ; write(bad(e)) ), nl,
    findall(W, coc(W), L4), write(L4), nl,
    three(T),
    chk(f, if(T, true, true), type_error(callable, 3)),
    chk(g, if(true, T, true), type_error(callable, 3)),
    chk(h, if(fail, true, T), type_error(callable, 3)),
    G1 = if(a(P), b(Q), c(_)), findall(P-Q, call(G1), L5), write(L5), nl,
    G2 = if(fail, true, 3), chk(i, G2, type_error(callable, 3)),
    G3 = if((!, fail), true, fail), chk(j, G3, no),
    catch((if(T, true, true), write(bad(k))), error(E1, _), write(E1)), nl,
    catch((if(true, T, true), write(bad(l))), error(E2, _), write(E2)), nl,
    findall(X-Y, (a(X) *-> call(b(Y)) ; c(_)), L6), write(L6), nl,
    ( p(M-N), write(M-N), nl, fail ; true ),
    halt.
p(X-Y) :- ( a(X) *-> call(b(Y)) ; true ).
EOP
arm the_soft_cut_if_3_predicate_compile_time_and_run_time "$TMPD/if3.pl" "$(printf '%s\n' 'ok(a)' 'ok(b)' 'ok(c)' 'ok(d)' '[1-4,1-5,1-6,2-4,2-5,2-6,3-4,3-5,3-6]' '[7,8,9]' '[7,8,9]' 'ok(e)' '[1,2]' 'ok(f)' 'ok(g)' 'ok(h)' '[1-4,1-5,1-6,2-4,2-5,2-6,3-4,3-5,3-6]' 'ok(i)' 'ok(j)' 'type_error(callable,3)' 'type_error(callable,3)' '[1-4,1-5,1-6,2-4,2-5,2-6,3-4,3-5,3-6]' '1-4' '1-5' '1-6' '2-4' '2-5' '2-6' '3-4' '3-5' '3-6')" 0
cat > "$TMPD/own.pl" <<'EOP'
:- initialization(main).
if(a, b, c).
main :-
    ( if(a, b, c) -> write(ok(u)) ; write(bad(u)) ), nl,
    ( if(x, y, z) -> write(bad(v)) ; write(ok(v)) ), nl,
    G = if(a, b, c), ( call(G) -> write(ok(w)) ; write(bad(w)) ), nl,
    halt.
EOP
arm a_program_that_defines_its_own_if_3_keeps_it "$TMPD/own.pl" "$(printf '%s\n' 'ok(u)' 'ok(v)' 'ok(w)')" 0
floor if_3 12
echo "$GATE_NAME: arms=$total red=$red modes=$MODES"
[ "$red" -eq 0 ] || { echo "⛔ $GATE_NAME RED"; exit 1; }
echo "✅ $GATE_NAME GREEN"
