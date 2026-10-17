%  WITNESS for HB_TRIE and HB_TRIEN (223-224) -- a trie's header and its nodes, held across allocation churn, then read back.
:- initialization(main).
ins(_, 0) :- !.
ins(T, N) :- trie_insert(T, k(N, g(N), [N, N], _), v(N)), M is N - 1, ins(T, M).
churn(0) :- !.
churn(N) :- findall(X-Y, (between(1, 30, X), Y = f(X, X)), _), M is N - 1, churn(M).
chk(_, 0) :- !.
chk(T, N) :- trie_lookup(T, k(N, g(N), [N, N], _), V), V == v(N), M is N - 1, chk(T, M).
main :- trie_new(T), ins(T, 40), churn(200), chk(T, 40), trie_delete(T, k(20, g(20), [20, 20], _), _), churn(100), findall(K, trie_gen(T, K, _), Ks), length(Ks, C), write('TRIE-'), write(C), nl.
