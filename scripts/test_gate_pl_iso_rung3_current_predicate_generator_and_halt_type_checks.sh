#!/usr/bin/env bash
# test_gate_pl_iso_rung3_current_predicate_generator_and_halt_type_checks.sh -- PROLOG ISO LADDER, RUNG 3 (cto, CEO-617, 2026-09-12).
# THE RUNG: current_predicate/1 (ISO 8.8.2) is a RUN-TIME GENERATOR over the Prolog predicate registry -- every file-defined
# static predicate and every multifile/discontiguous/dynamic declaration is registered at program start by the $db_decl/0
# graph, a predicate created by assert at run time joins the registry when its store is made, an abolished one leaves it,
# builtins and $-helpers are never in it -- with a run-time guard ($pl_cp_guard) raising type_error(predicate_indicator, S)
# for a bound spec that is not Name/Arity with an atom-or-var name and a non-negative-int-or-var arity; halt/1 raises
# instantiation_error on a variable and type_error(integer, X) on a non-integer instead of exiting.
# TWO ENGINE DEFECTS FOUND UNDER IT, BOTH LANGUAGE-BLIND AND BOTH WITNESSED HERE:
#   (1) a REWRITTEN NESTED CONJUNCTION lost its redo point: the ','/2 case of the goal lowerer returned the inner
#       conjunction's first node, so the goals after it wired their failure port to the clause's fail instead of back
#       into the inner generator -- every count/nth rewrite (current_op/3, stream_property/2, current_stream/3,
#       current_predicate/1) yielded exactly ONE solution under backtracking. Now the case returns a GOTO trampoline
#       and reports the inner redo through cx->meta_redo, the same protocol call/1 already used.
#   (2) the per-alternative _retN trampoline (emit.cpp, PL CLAUSE SUCCESS) banked the youngest resumable beta into
#       F.RES through RAX and jumped to the graph gamma, which forwards RAX as the result descriptor; whenever that CODE
#       ADDRESS ended in byte 0x68 (= DT_FAIL) the caller's landing `cmp al, 104` read a success as a failure and the
#       program exited 1 with correct output (ladder witness rung03_disjunction_with_rule, mode 4 only, after any
#       change that shifted the text addresses). The trampoline now uses RCX, which every gamma epilogue reloads.
# WITNESS: the Logtalk ISO groups this rung moves, graded one --group at a time in BOTH modes against the floors
# measured at landing (RED BEFORE, m3: current_predicate_1 7/23 [10/23 after the grader's ball-list fix], halt_1 0/2),
# plus three engine arms compiled in BOTH modes: (a) a generator rewrite enumerates every solution, (b) statics,
# declarations and run-time predicates are current and abolished ones are not, (c) no _retN trampoline in the mode-4
# emission touches RAX (an EMISSION arm: mode 4 named). A later rung may only raise a floor.
set -u
GATE_NAME=test_gate_pl_iso_rung3_current_predicate_generator_and_halt_type_checks
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
cat > "$TMPD/enum.pl" <<'EOF'
p1. p2. p3(_).
:- dynamic(dq/1).
:- multifile(mf/2).
q :- \+ current_predicate(nope/7), \+ current_predicate(assertz/1), \+ current_predicate(current_predicate/1).
:- initialization(main).
main :-
    findall(N, current_op(_, _, N), Ops), length(Ops, LO), ( LO > 20 -> write(ops_ok) ; write(ops_short(LO)) ), nl,
    findall(N/A, current_predicate(N/A), Ps),
    ( memberchk(p1/0, Ps), memberchk(p2/0, Ps), memberchk(p3/1, Ps), memberchk(q/0, Ps), memberchk(dq/1, Ps), memberchk(mf/2, Ps) -> write(statics_ok) ; write(statics_missing(Ps)) ), nl,
    ( current_predicate(p3/X), X == 1 -> write(arity_ok) ; write(arity_bad) ), nl,
    ( q -> write(builtins_hidden) ; write(builtins_leak) ), nl,
    assertz(rt_new(1)), ( current_predicate(rt_new/1) -> write(runtime_ok) ; write(runtime_missing) ), nl,
    retractall(rt_new(_)), ( current_predicate(rt_new/1) -> write(retracted_still_current) ; write(retracted_gone) ), nl,
    abolish(rt_new/1), ( current_predicate(rt_new/1) -> write(abolished_still_current) ; write(abolished_gone) ), nl,
    catch(current_predicate(4), error(E1, _), (write(E1), nl)),
    catch(current_predicate(0/dog), error(E2, _), (write(E2), nl)),
    catch(current_predicate(f/ -1), error(E3, _), (write(E3), nl)),
    S = zz/2, ( current_predicate(S) -> write(var_spec_bad) ; write(var_spec_ok) ), nl,
    catch(halt(a), error(E4, _), (write(E4), nl)),
    catch(halt(_), error(E5, _), (write(E5), nl)).
memberchk(X, [Y|T]) :- ( X == Y -> true ; memberchk(X, T) ).
EOF
arm generator_enumerates_and_registry_is_current "$TMPD/enum.pl" "$(printf '%s\n' ops_ok statics_ok arity_ok builtins_hidden runtime_ok retracted_still_current abolished_gone 'type_error(predicate_indicator,4)' 'type_error(predicate_indicator,0/dog)' 'type_error(predicate_indicator,f/ -1)' var_spec_ok 'type_error(integer,a)' instantiation_error)" 0
cat > "$TMPD/ret0.pl" <<'EOF'
:- initialization(main).
combo :- write(a), (write(x) ; write(y)), write(b).
main :- combo, nl.
EOF
arm nondeterministic_success_exits_zero "$TMPD/ret0.pl" "axb" 0
case "$MODES" in *m4*)
    total=$((total+1))
    if timeout -k 5 60 "$SCRIP" --compile -o "$TMPD/ret0.s" "$TMPD/ret0.pl" </dev/null 2>/dev/null; then
        bad="$(awk '/^[^ ]*_ret[0-9]+:/{getline; print}' "$TMPD/ret0.s" | grep -c 'rax')"
        if [ "$bad" = "0" ]; then echo "  ok  emission(m4): no _retN trampoline touches RAX"
        else echo "  RED emission(m4): $bad _retN trampoline(s) load RAX -- the result register the gamma epilogue forwards"; red=$((red+1)); fi
    else echo "  RED emission(m4): --compile failed"; red=$((red+1)); fi ;;
esac
floor current_predicate_1 23
floor halt_1 2
echo "$GATE_NAME: arms=$total red=$red modes=$MODES"
[ "$red" -eq 0 ] || { echo "⛔ $GATE_NAME RED"; exit 1; }
echo "✅ $GATE_NAME GREEN"
exit 0
