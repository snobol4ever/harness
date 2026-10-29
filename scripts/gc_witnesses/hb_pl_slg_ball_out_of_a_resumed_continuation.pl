:- op(1050, fy, import).
:- op(1100, fx, export).
:- op(1040, xfx, from).
:- op(1100, fy, index).
:- op(1150, xfy, do_all).
:- op(1150, fx, do_all).
:- op(1150, xfy, if_none).
:- op(1100, fx, use_variant_tabling).
:- op(1100, fx, use_subsumptive_tabling).
:- op(1100, fx, use_incremental_tabling).
:- op(1100, fx, use_incremental_dynamic).
:- op(1100, fx, use_opaque_tabling).
:- op(1100, fx, thread_shared).
:- op(1100, fx, thread_private).
:- op(1100, fx, edb).
:- op(1100, fy, ti).
:- op(1100, fy, ti_off).
:- op(1100, fx, mode).
:- op(1100, fx, mode_on_success).
:- op(1100, fx, annotation).
:- op(1100, fx, document_export).
:- op(1100, fx, parallel).
:- op(1100, fx, local).
:- op(1100, fx, foreign_pred).
:- op(1100, fx, private_foreign_pred).
:- op(1100, fx, compile_command).
:- op(1100, fx, attribute).
:- op(1050, fy, document_import).
:- op(1045, xfx, as).
:- op(900, fy, tnot).
:- op(500, yfx, ><).
:- compiler_options([]).
:- table p/1, q/1.
p(X) :- q(X).
p(1).
q(X) :- p(X), X > 0, throw(boom(X)).
test :- catch(p(X), E, (write(caught(E)), nl)), write(after(X)), nl, fail.
test :- table_state(p(_), S1, T1, U1), write(p_state(S1,T1,U1)), nl, table_state(q(_), S2, T2, U2), write(q_state(S2,T2,U2)), nl, fail.
test :- catch(p(Y), E2, (write(caught2(E2)), nl)), write(second(Y)), nl, fail.
test.
:- initialization((test, halt)).
