% An image read from a GIF whose local colormap is cut short: the kernel's reader makes its pixel buffer
% with malloc and releases it through its own free layer on this one error path (img/gifread.c). The load
% fails, nothing is printed by the kernel (pce_catch_error), and the kernel goes on. Needs a display.
:- module(xpce_b_badgif, []).
:- use_module(library(pce)).

gif_bytes(good,
          [0'G,0'I,0'F,0'8,0'9,0'a, 2,0, 2,0, 0x80,0,0,
           0,0,0, 255,255,255,
           0',, 0,0, 0,0, 2,0, 2,0, 0,
           2, 2, 0x4C, 0x01, 0,
           0';]).
gif_bytes(cut,
          [0'G,0'I,0'F,0'8,0'9,0'a, 2,0, 2,0, 0x80,0,0,
           0,0,0, 255,255,255,
           0',, 0,0, 0,0, 2,0, 2,0, 0x81,
           9,9,9, 8]).

write_gif(Kind, File) :-
    gif_bytes(Kind, Bs),
    setup_call_cleanup(open(File, write, S, [type(binary)]),
                       forall(member(B, Bs), put_byte(S, B)),
                       close(S)).

try(Kind, Tag) :-
    atomic_list_concat([xpce_b_badgif_, Tag, '.gif'], File),
    write_gif(Kind, File),
    (   pce_catch_error(_, new(I, image(File)))
    ->  get(I, size, size(W, H)),
        format("~w: loaded ~wx~w~n", [Tag, W, H])
    ;   format("~w: not loaded~n", [Tag])
    ),
    delete_file(File).

main :-
    try(good, g1),
    try(cut, c1),
    try(cut, c2),
    try(good, g2),
    new(C, chain(a, b, c)),
    get(C, size, N),
    format("chain ~w~n", [N]),
    free(C),
    try(cut, c3),
    format("done~n").

:- initialization((main -> halt ; halt(1))).
