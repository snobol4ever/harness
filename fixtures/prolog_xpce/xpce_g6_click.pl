% G6: a click gesture and a key handler driven by the road's scripted events (xpce_g6_click.events); ends itself on q.
:- use_module(library(pce)).
:- initialization((main, read(user_input, _)), main).
main :-
    new(P, picture('click')), send(P, size, size(200, 100)),
    send(P, recogniser, click_gesture(left, '', single, message(@prolog, clicked, @event?x, @event?y))),
    send(P, recogniser, new(handler(keyboard, message(@prolog, typed, @event?id)))),
    send(P, open, point(0, 0)), writeln(ready), flush_output.
clicked(X, Y) :- format("clicked ~w ~w~n", [X, Y]), flush_output.
typed(K) :- format("typed ~w~n", [K]), flush_output, ( K == 113 -> halt ; true ).
