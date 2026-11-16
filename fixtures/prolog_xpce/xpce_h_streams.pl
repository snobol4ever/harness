:- use_module(library(pce)).
:- initialization(main, main).
lines(S, L) :- read_line_to_string(S, X), ( X == end_of_file -> L = [] ; L = [X|T], lines(S, T) ).
bye(N) :- write(prolog_exit_message(N)), nl.
main :-
  new(TB, text_buffer),
  pce_open(TB, write, W), format(W, "line one~n", []), atom_codes(U, [0'z, 228, 8364]), format(W, "~w ~d~n", [U, 42]), close(W),
  get(TB, size, N1), write(size(N1)), nl,
  pce_open(TB, read, R), lines(R, L), close(R), atom_codes(U2, [0'z, 228, 8364]), print(L), nl, ( L = [_, X], sub_string(X, 0, 3, _, Y), atom_string(U2, Y) -> write(wide_ok) ; write(wide_bad) ), nl,
  pce_open(TB, append, A), write(A, tail), nl(A), close(A),
  get(TB, contents, C), get(C, value, CV), atom_length(CV, CL), write(contents_length(CL)), nl,
  new(TB2, text_buffer), pce_open(TB2, write, W2), format(W2, "f(x, [1,2], 'A b').~n", []), close(W2),
  pce_open(TB2, read, R2), read_term(R2, T, []), read_term(R2, T2, []), close(R2), print(terms(T, T2)), nl,
  catch((pce_open(TB, read, R3), close(R3), close(R3)), E3, true), ( var(E3) -> write(double_close_ok) ; E3 = error(F3, _), functor(F3, FN3, _), print(double_close(FN3)) ), nl,
  send(@pce, write_ln, kernel, says, hello),
  send(@pce, format, 'kernel format %d and %s\n', 7, word),
  flush_output,
  send(@pce, exit_message, message(@prolog, bye, 1)),
  send(@pce, exit_message, message(@prolog, bye, 2)),
  at_halt((write(prolog_at_halt), nl)),
  new(M, message(@prolog, halt, 3)),
  write(before_halt), nl,
  send(M, execute),
  write(not_reached), nl.
