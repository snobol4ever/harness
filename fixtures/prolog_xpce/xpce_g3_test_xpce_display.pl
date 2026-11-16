% G3: XPCE's own test file with the display: all 75 cases, the 4 that need a display (bom, selection, image) among them.
:- initialization(main, main).
main :- load_files('/home/resources/xpce-V9.0.4/test_xpce.pl', [silent(true)]),
    ( test_xpce:test_xpce -> halt(0) ; halt(1) ).
