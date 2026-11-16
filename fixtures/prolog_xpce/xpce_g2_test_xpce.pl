% G2: XPCE's own test file, the 71 cases that need no display (DISPLAY is removed before the run).
:- initialization(main, main).
main :- unsetenv('DISPLAY'), load_files('/home/resources/xpce-V9.0.4/test_xpce.pl', [silent(true)]),
    ( test_xpce:test_xpce -> halt(0) ; halt(1) ).
