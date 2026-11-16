:- module(xpce_p_reader, []).
:- op(200, fy, @).
:- op(250, yfx, ?).
:- op(100, xf, *).
:- op(125, xf, ?).
:- op(150, xf, ...).
:- op(1200, xfx, :->).
:- dynamic seen/1.
:- volatile seen/1.
:- initialization writeln(prefix_initialization_ran).
:- initialization(main, main).
t(1, name*).
t(2, a*b).
t(3, x:name*).
t(4, [int]*).
t(5, - name*).
t(6, @receiver?selector).
t(7, int?).
t(8, a ...).
t(9, [ - = button(x), c = d ]).
t(10, (:- thread_initialization foo)).
t(11, (:- volatile foo/1)).
t(12, (:- initialization foo)).
t(13, [-, +, *, ?]).
t(14, f(-, *)).
t(15, (select(item) :-> item == -
       -> true ; fail)).
t(16, a*b*).
main :- forall(t(N, T), (write(N), write(': '), writeq(T), nl)),
        ( op(100, xf, *) -> writeln(op_again_ok) ; writeln(op_again_failed) ).
