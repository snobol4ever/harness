% G4: graphicals drawn into an off-screen image and read back as colour names (the Icon witnesses' Pixel-as-letters form).
:- use_module(library(pce)).
:- initialization(main, main).
cname(C, N) :- ( C == @on -> N = on ; C == @off -> N = off ; get(C, name, N) ).
probe(I, Pts) :- forall(member(X-Y, Pts),
    ( get(I, pixel, X, Y, C) -> cname(C, N), format("~w ~w ~w~n", [X, Y, N]) ; format("~w ~w none~n", [X, Y]) )).
main :-
    new(I, image(@nil, 100, 60, pixmap)), send(I, background, colour(white)),
    new(B, box(30, 20)), send(B, fill_pattern, colour(red)), send(B, pen, 0), send(B, move, point(10, 10)),
    send(I, draw_in, B), writeln(box), probe(I, [15-15, 5-5, 39-29, 40-30, 10-10, 9-9]),
    new(L, line(0, 50, 99, 50)), send(L, colour, colour(blue)), send(I, draw_in, L), writeln(line), probe(I, [0-50, 50-50, 99-50, 50-49]),
    new(Ci, circle(20)), send(Ci, fill_pattern, colour(green)), send(Ci, pen, 0), send(Ci, move, point(60, 5)),
    send(I, draw_in, Ci), writeln(circle), probe(I, [70-15, 60-5, 79-24]),
    get(I, size, Sz), get(Sz, width, W), get(Sz, height, H), format("size ~w ~w~n", [W, H]),
    halt.
