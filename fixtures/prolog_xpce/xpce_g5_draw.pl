% G5: one still window, graded by its screen line; the hold is a read of standard input (DESIGN J4).
:- use_module(library(pce)).
:- initialization((main, read(user_input, _)), main).
main :-
    new(P, picture('xpce draw')), send(P, size, size(300, 200)),
    send(P, display, new(B, box(120, 60)), point(20, 20)), send(B, fill_pattern, colour(red)),
    send(P, display, new(_, circle(50)), point(180, 40)),
    send(P, display, new(_, line(10, 150, 290, 150)), point(0, 0)),
    send(P, display, new(T, text('Hello XPCE')), point(40, 110)), send(T, font, font(helvetica, bold, 14)),
    send(P, open, point(0, 0)).
