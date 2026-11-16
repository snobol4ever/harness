:- use_module(cmp_expand).
foo(1).
baz(2).
emit(3).
:- G = initialization(writeln(called_initialization)), call(G).
p :- hello.
hello :- writeln(unexpanded_hello).
t(N, G) :- write(N), write(': '), ( catch(G, error(F, _), (print(caught(F)), nl, fail)) -> true ; write(no), nl ).
main :-
    t(1, (bar(X1), print(X1), nl)),
    t(2, (qux(X2), print(X2), nl)),
    t(3, p),
    t(4, (current_op(_, _, ===>) -> writeln(op_before) ; writeln(no_op_before))),
    t(5, (push_operators([op(700, xfx, ===>)]), current_op(P, T, ===>), print(pushed(P, T)), nl)),
    t(6, (term_to_atom(Tm, 'a ===> b'), Tm =.. [Op, A, B], print(read(Op, A, B)), nl)),
    t(7, (pop_operators, ( current_op(_, _, ===>) -> writeln(op_after) ; writeln(no_op_after) ))).
:- initialization(main, main).
