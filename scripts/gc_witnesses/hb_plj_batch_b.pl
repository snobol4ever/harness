%  WITNESS for HB_PLJ batch B -- the by_name_dispatch.c descriptor-cell sites: fresh vars, list cells, compound kids, parsed terms, Name=Var pairs, stream properties, a flag error term.
:- initialization(main).
churn(0).
churn(N) :- N > 0, T =.. [f, N, x, y], functor(T, _, _), copy_term(T-_, _), U = V, V = N, U == N, M is N - 1, churn(M).
main :- churn(400), length(L, 40), L = [a|_], T =.. [g, L, 1], T = g(_, _),
        term_to_atom(T2, 'h(X, Y, [1,2,3])'), T2 = h(_, _, [1|_]),
        atom_to_term('k(A, B, A)', T3, Bs), length(Bs, 2), T3 = k(_, _, _),
        catch(set_prolog_flag(double_quotes, bogus), _, true),
        current_output(S), stream_property(S, mode(Md)), write(Md), nl,
        atom_codes(W, [87,73,84,78,69,83,83]), write(W), nl.
