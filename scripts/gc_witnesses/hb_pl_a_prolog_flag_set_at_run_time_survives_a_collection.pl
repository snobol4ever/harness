main :- set_prolog_flag(double_quotes, atom), create_prolog_flag(hb_flag_one, a_value_made_at_run_time, []), create_prolog_flag(hb_flag_two, another_value_made_at_run_time, []), churn(6000), current_prolog_flag(double_quotes, D), write(D), nl, current_prolog_flag(hb_flag_one, V1), write(V1), nl, current_prolog_flag(hb_flag_two, V2), write(V2), nl.
churn(0) :- !.
churn(N) :- atom_codes(A, [0'x, 0'y, 0'z]), atom_length(A, _), length(L, 8), msort(L, _), N1 is N - 1, churn(N1).
:- initialization(main).
