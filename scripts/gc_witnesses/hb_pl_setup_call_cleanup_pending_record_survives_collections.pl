garbage(N) :- numlist(1, N, G), msort(G, _), length(G, _).
cleanup(Tag, I, _, L, A) :- sum_list(L, S), write(cleanup(Tag, I, S, A)), nl.
pend(I, X) :- numlist(1, 50, L), atom_codes(A, "abc"), setup_call_cleanup(true, member(X, [a,b,c]), cleanup(callee, I, X, L, A)).
cut_here(I) :- numlist(1, 40, L), atom_codes(A, "xyz"), setup_call_cleanup(true, member(X, [a,b,c]), cleanup(here, I, X, L, A)), X == b, garbage(300), !.
cut_caller(I) :- pend(I, X), X == b, garbage(300), !.
exhaust(I) :- numlist(1, 30, L), atom_codes(A, "ex"), ( setup_call_cleanup(true, member(X, [a,b,c]), cleanup(exhaust, I, X, L, A)), garbage(100), fail ; true ).
ball(I) :- catch(( pend(I, X), X == b, garbage(300), throw(t(I)) ), t(J), (write(caught(J)), nl)).
loop(I) :- I > 3, !.
loop(I) :- cut_here(I), cut_caller(I), exhaust(I), ball(I), I1 is I + 1, loop(I1).
:- initialization((loop(1), halt)).
