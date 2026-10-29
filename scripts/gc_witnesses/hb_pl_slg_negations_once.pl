:- table p/0, q/0, r/0, s/0.
p :- tnot(s), q, tnot(r).
q :- r, tnot(p).
r :- p, tnot(q).
s :- tnot(p), tnot(q), tnot(r), write('negations once'), nl, fail.
main :- ( p -> write(p_true) ; write(p_false) ), nl, '$tbl_vt'(VT), '$trie_entries'(VT, L), forall(member(e(_,K,T), L), ('$trie_meta_get'(T, 0, S), '$trie_count'(T, N), write(K-S-N), nl)), write(asking_s), nl, ( s -> write(s_true) ; write(s_false) ), nl.
:- initialization(main).
