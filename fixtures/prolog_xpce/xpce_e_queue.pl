:- use_module(library(pce)).
:- initialization(main, main).
w(X) :- write(X), nl, flush_output.
boom :- throw(queued_ball).
show(V) :- ( var(V) -> write(unbound) ; write(V) ).
main :-
    in_pce_thread(w(a)), w(b),
    sleep(0.4), w(c),
    pce_dispatch, w(d),
    in_pce_thread(X = 1), pce_dispatch, show(X), nl,
    in_pce_thread(boom), sleep(0.4), w(e),
    catch(( pce_dispatch, pce_dispatch ), E, w(caught(E))),
    w(f),
    in_pce_thread_sync(Y = 2), show(Y), nl,
    catch(in_pce_thread_sync(boom), E2, w(caught2(E2))),
    ( in_pce_thread_sync(fail) -> w(yes) ; w(no) ),
    ( in_pce_thread_sync(member(Z, [1,2,3])), w(z(Z)), fail ; w(g) ),
    set_pce_thread, w(h).
