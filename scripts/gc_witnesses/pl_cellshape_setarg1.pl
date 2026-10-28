:- initialization(main).
churn(0) :- !.
churn(N) :- T = f(N, g(N), [N,N]), arg(1, T, _), N1 is N - 1, churn(N1).
main :- T = f(a, _, c), arg(2, T, Y), churn(60), Y = mid, churn(40), write(Y), nl,
        U = g(p, q, r), setarg(2, U, Z), churn(60), Z = zed, write(U), nl, arg(1, U, A), arg(3, U, C), write(A-C), nl.
