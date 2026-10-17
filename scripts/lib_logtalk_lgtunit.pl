% lib_logtalk_lgtunit.pl -- THE PLAIN-PROLOG SHIM FOR lgtunit'S TEST-HARNESS PREDICATES.
% Row prolog-logtalk-iso-3268-conformance-cases-have-no-runner (hq_R, 2026-09-12). Read by
% test_prolog_logtalk_suite.sh and prepended to every generated case program.
%
% WHY IT EXISTS. corpus/packages/prolog/logtalk_iso grades a Prolog system against ISO/IEC 13211-1 without
% needing Logtalk installed, because every tested goal sits inside {...}, Logtalk's escape to plain Prolog.
% ⛔ BUT THE SURROUNDING SCAFFOLDING IS NOT PLAIN PROLOG: 1141 of the 3617 cases call an lgtunit framework
% predicate as ^^name(...), and 450 of those BIND the variable that the case's own expectation then calls:
%
%     test(iso_cut_0_04, true(Assertion)) :-
%         ^^set_text_output(''), \+ {(twice(_), !, write('Forwards '), fail)},
%         ^^text_output_assertion('C Forwards ', Assertion).
%
% Strip the ^^ calls (the obvious move, and the one the spike made) and Assertion is unbound, so the
% expectation raises instantiation_error and the case grades RED. ⭐ THAT RED IS MANUFACTURED BY THE
% HARNESS AND IS INDISTINGUISHABLE ON THE BOARD FROM A REAL ISO DEFECT -- 450 of them, 12% of the suite,
% every one of them in the stream and term-output families we are least sure of. So the helpers are
% re-implemented here in plain ISO Prolog rather than deleted.
%
% ⛔⭐ EVERY SHIM CALL IS WRAPPED IN lgt_h/1 AND A FAILURE OR ERROR INSIDE THE SHIM IS NOT THE CASE'S FAULT.
% lgt_h/1 converts both into throw('$lgt_harness'(Why)), which the runner buckets as UNGRADED AND NAMES --
% never PASS, never FAIL. This is the whole discipline of the file: a harness that cannot set a case up
% must say so in its own voice, because a harness defect wearing the case's name is a false measurement of
% the language, and a false measurement is worse than a missing one (ARCH-PROGRAM-LEDGER: UNKNOWN is not
% ZERO). ⭐ The reverse direction matters just as much and is easy to miss: the shim must never SUCCEED
% vacuously either, which is why lgt_h/1 treats a silent failure as a harness error rather than letting
% the conjunction fail into a plausible `false` verdict.
%
% ⛔ WHAT IS DELIBERATELY NOT HERE, and why naming it beats faking it: set_binary_input/1,2,
% create_binary_file/2, check_binary_input/1,2, binary_output_assertion/2,3 and stream_position/1. Their
% cases are reported UNGRADED with the helper named, so the work owed is readable off the board instead of
% being buried in a red count. ⭐ set_binary_output/1,2 and clean_binary_output/0 WERE on this list and are
% now implemented below (hq_R 2026-09-13) -- implemented because four cases needed only that a stream BE
% binary, not that anything read binary back. The rest of the family stays absent: writing helpers nothing
% grades is how a shim grows an unmeasured surface.
%
% ⛔ THE CAPTURE IS A FILE, NOT A MEMORY BUFFER, and the restore is via a saved handle, NEVER via the alias
% `user_output`. Measured on scrip 2026-09-12: set_output(user_output) did NOT restore the default sink, so
% every later write -- including the runner's own verdict line -- went on landing in the capture file and
% the case scored fail with an empty board line. flush_output/1 called on an ALIAS likewise fails silently
% (not an error, a failure), which took a working shim to a silent no-output run. Both are why lgt_cap_out/1
% and lgt_prev_out/1 hold real stream handles.

:- dynamic(lgt_prev_out/1).
:- dynamic(lgt_prev_in/1).
:- dynamic(lgt_cap_out/1).
:- dynamic(lgt_cap_in/1).

% lgt_h(+Goal) -- run one harness step. Failure and error alike become a NAMED harness refusal.
lgt_h(G) :- ( catch(G, E, throw('$lgt_harness'(error(G, E)))) -> true ; throw('$lgt_harness'(failed(G))) ).

% Logtalk LIBRARY objects a case uses as a HELPER, never as the subject: list::member/2 is the standard
% library's member/2 and nothing about it is under test, so it is provided here and the message is rewritten
% to it. A message this shim does NOT provide leaves the case UNGRADED-and-named rather than parse-error RED.
% ⛔ current_logtalk_flag/2 -- UNDEFINED here until 2026-09-13, and that was an INSTRUMENT defect wearing a
% language defect's clothes. 26 cases of write_term_3 alone carry a condition(...) whose body asks this
% flag, so the call raised existence_error, the condition failed, and the case was filed UNGRADED -- i.e.
% NOT MEASURED -- when nothing about SCRIP was in question. The suite asks it two ways and ONE clause
% answers both honestly: current_logtalk_flag(prolog_dialect, swi) must FAIL because we are not swi, and
% current_logtalk_flag(prolog_dialect, D), D \== b, D \== cx, ... must SUCCEED because we are none of
% them. coinduction answers supported, the value util_logtalk_extract.py decides its guards by (Lon via the ceo, CEO-1518: "We
% expect to have ALL features."; it answered unsupported under CEO-1235 (3) option (a), withdrawn, and the cto found it still did at
% run time beside the extractor's supported); every other flag FAILS cleanly rather than raising.
current_logtalk_flag(prolog_dialect, scrip).
current_logtalk_flag(coinduction, supported).
% '$lgt_load_prolog_file'/1 -- "defined in the backend adapter files and abstracts how to load a Prolog file" (the suite's own words, encoding_1):
% SCRIP has no run-time consult/1 (consult is a load-time splice), so this adapter loads a file the way a minimal one would: read each
% term, run a directive, assert a clause. The stream's own BOM detection and encoding apply; a :- encoding/1 directive is honoured by them.
'$lgt_load_prolog_file'(File) :- open(File, read, S), catch(lgt_load_terms(S), E, (close(S), throw(E))), close(S).
lgt_load_terms(S) :- read_term(S, T, []), ( T == end_of_file -> true ; lgt_load_term(T), lgt_load_terms(S) ).
lgt_load_term((:- encoding(_))) :- !.
lgt_load_term((:- D)) :- !, call(D).
lgt_load_term(T) :- assertz(T).
lgt_member(X, [X| _]).
lgt_member(X, [_| T]) :- lgt_member(X, T).
% More library objects, each clause as upstream writes it for the GNU Prolog backend (cfo 2026-10-11, CEO-1689, the coo's terms:
% upstream only, never a stand-in for a SCRIP builtin). GNU is the ISO-strict backend whose builtins SCRIP answers as gprolog
% does -- environ/2, shell/1,2, file_exists/1, file_property/2, call_det/2, between/3 -- so a red these reach is SCRIP's, not
% this shim's. library/os/os.lgt: operating_system_type/1, shell/1,2, file_exists/1, ensure_file/1 (its directory step,
% make_directory_path of decompose_file_name's directory, is left out: every path here is a bare name in the case's own
% directory, lgt_file_path/2). tools/lgtunit/lgtunit.lgt: deterministic/2. library/types/integer.lgt: between/3, which
% upstream hands to the backend's own between/3 when it has one.
lgt_os_operating_system_type(Type) :- ( environ('COMSPEC', _) -> Type = windows ; Type = unix ).
lgt_os_shell(Command) :- shell(Command).
lgt_os_shell(Command, Status) :- shell(Command, Status).
lgt_os_file_exists(File) :- absolute_file_name(File, Path), file_exists(Path), file_property(Path, type(regular)).
lgt_os_ensure_file(File) :- ( lgt_os_file_exists(File) -> true ; open(File, append, Stream), close(Stream) ).
lgt_lgtunit_deterministic(Goal, Deterministic) :- call_det(Goal, Deterministic), !.
lgt_integer_between(Lower, Upper, Integer) :- between(Lower, Upper, Integer).

lgt_read_chars(S, L) :- get_char(S, C), ( C == end_of_file -> L = [] ; L = [C|T], lgt_read_chars(S, T) ).
lgt_file_to_atom(F, A) :- open(F, read, S), lgt_read_chars(S, Cs), close(S), atom_chars(A, Cs).
lgt_file_to_atom(F, Opts, A) :- open(F, read, S, Opts), lgt_read_chars(S, Cs), close(S), atom_chars(A, Cs).
% ⛔ A LIST ARGUMENT IS A SEQUENCE OF TEXT ITEMS, NOT A TERM TO PRINT. set_text_input/1 takes either one
% atom or a list of pieces, and writing the list with write/2 puts `[a,b,c]` on the stream -- which is a
% perfectly well-formed Prolog term, so the case under test then reports a syntax error about ITS OWN
% subject and reads as a frontend defect. Two cases in the suite settle the semantics on their own:
% double_quoted_terms 01-06 spell a parenthesised disjunction one line per element, and atoms 17 spells
% 'enchanted evening' as ['\'', enchanted, '\\', '\n', ' evening''. '] -- neither is readable any other way.
lgt_write_pieces(_, []).
lgt_write_pieces(S, [P|Ps]) :- ( integer(P) -> put_char(S, P) ; write(S, P) ), lgt_write_pieces(S, Ps).
lgt_atom_to_file(F, A) :- open(F, write, S), ( A = [_|_] -> lgt_write_pieces(S, A) ; write(S, A) ), close(S).
lgt_atom_to_file(F, Opts, A) :- open(F, write, S, Opts), ( A = [_|_] -> lgt_write_pieces(S, A) ; write(S, A) ), close(S).

% ---- output capture ---------------------------------------------------------------------------------
lgt_close_out :- ( retract(lgt_cap_out(S)) -> catch(close(S), _, true) ; true ),
                 ( retract(lgt_prev_out(P)) -> catch(set_output(P), _, true) ; true ).
lgt_set_text_output(Contents) :-
    current_output(Prev), assertz(lgt_prev_out(Prev)),
    open('lgt_capture_out.txt', write, S), assertz(lgt_cap_out(S)),
    ( Contents == '' -> true ; write(S, Contents) ), set_output(S).
lgt_set_text_output(Alias, Contents) :- lgt_set_text_output(Alias, Contents, []).
lgt_set_text_output(Alias, Contents, Opts) :-
    open('lgt_capture_out.txt', write, S, [alias(Alias)|Opts]), assertz(lgt_cap_out(S)),
    ( Contents == '' -> true ; write(S, Contents) ).
% lgtunit's text_output_contents/1 yields a LIST OF CHARACTERS, not an atom -- every caller in the suite
% asserts over it with subsumes(['1','.','0'| _], Contents), which an atom can never satisfy. The atom form
% belongs to the ASSERTION helpers, which compare against the expected atom, so the two are kept apart here.
lgt_text_output_chars(Cs) :- lgt_close_out, open('lgt_capture_out.txt', read, S), lgt_read_chars(S, Cs), close(S).
lgt_text_output_contents(Contents) :- lgt_text_output_chars(Contents).
lgt_text_output_contents(_Alias, Contents) :- lgt_text_output_chars(Contents).
lgt_text_output_assertion(Expected, Assertion) :-
    lgt_text_output_chars(Cs), atom_chars(Text, Cs), Assertion = (Text == Expected).
lgt_text_output_assertion(Alias, Expected, Assertion) :-
    lgt_text_output_contents(Alias, Cs), atom_chars(Text, Cs), Assertion = (Text == Expected).
lgt_text_output_assertion(_Alias, Expected, Opts, Assertion) :-
    lgt_close_out, lgt_file_to_atom('lgt_capture_out.txt', Opts, Text), Assertion = (Text == Expected).
lgt_check_text_output(Expected) :- lgt_text_output_chars(Cs), atom_chars(Text, Cs), Text == Expected.
lgt_check_text_output(Alias, Expected) :- lgt_text_output_contents(Alias, Cs), atom_chars(Text, Cs), Text == Expected.
lgt_suppress_text_output :- lgt_set_text_output('').
lgt_clean_text_output :- lgt_close_out, catch(lgt_delete('lgt_capture_out.txt'), _, true).

% ---- binary output ---------------------------------------------------------------------------------
% ⛔ THE BINARY SINK IS A SEPARATE FILE FROM THE TEXT ONE, on purpose: lgt_clean_binary_output must not
% delete a text capture some other case is still asserting over, and a shared name made the two cleanups
% order-dependent. It reuses lgt_cap_out/1 and lgt_prev_out/1 so lgt_close_out restores the real handle
% exactly as the text path does -- never via the user_output alias, which was measured not to restore.
% ⛔ THE ARGUMENT IS THE STREAM'S INITIAL BYTES, NOT ITS OPTIONS (lgtunit: set_binary_output(Bytes),
% set_binary_output(Alias, Bytes), set_binary_output(Alias, Bytes, Options)): they are written THROUGH the
% stream the case then uses, so its position starts after them. Never a write-then-reopen-for-append: under
% append every put lands at the end whatever set_stream_position/2 said, and lgt_set_stream_position_2_10
% (reposition to 0, then put_byte) expects the byte to overwrite. An earlier shim read the list as options,
% which only agreed with lgtunit while every list was [].
lgt_put_bytes(_, []).
lgt_put_bytes(S, [B|Bs]) :- put_byte(S, B), lgt_put_bytes(S, Bs).
lgt_read_bytes(S, L) :- get_byte(S, B), ( B == -1 -> L = [] ; L = [B|T], lgt_read_bytes(S, T) ).
lgt_bytes_to_file(F, Bytes) :- open(F, write, S, [type(binary)]), lgt_put_bytes(S, Bytes), close(S).
lgt_file_to_bytes(F, Bytes) :- open(F, read, S, [type(binary)]), lgt_read_bytes(S, Bytes), close(S).
lgt_set_binary_output(Bytes) :-
    current_output(Prev), assertz(lgt_prev_out(Prev)),
    open('lgt_capture_out.bin', write, S, [type(binary)]), assertz(lgt_cap_out(S)), lgt_put_bytes(S, Bytes), set_output(S).
lgt_set_binary_output(Alias, Bytes) :- lgt_set_binary_output(Alias, Bytes, []).
lgt_set_binary_output(Alias, Bytes, Opts) :-
    open('lgt_capture_out.bin', write, S, [type(binary), alias(Alias)|Opts]), assertz(lgt_cap_out(S)), lgt_put_bytes(S, Bytes).
lgt_binary_output_assertion(Expected, Assertion) :-
    lgt_close_out, lgt_file_to_bytes('lgt_capture_out.bin', Got), Assertion = (Got == Expected).
lgt_binary_output_assertion(_Alias, Expected, Assertion) :- lgt_binary_output_assertion(Expected, Assertion).
lgt_clean_binary_output :- lgt_close_out, catch(lgt_delete('lgt_capture_out.bin'), _, true).

% ---- binary input ----------------------------------------------------------------------------------
% lgtunit: set_binary_input(Bytes) makes a binary stream over the bytes the current input; the Alias forms
% open it under that alias with the case's extra options. check_binary_input reads what is LEFT, exactly as
% check_text_input does -- it asserts how far the reader under test consumed.
lgt_set_binary_input(Bytes) :-
    lgt_bytes_to_file('lgt_capture_in.bin', Bytes),
    current_input(Prev), assertz(lgt_prev_in(Prev)),
    open('lgt_capture_in.bin', read, S, [type(binary)]), assertz(lgt_cap_in(S)), set_input(S).
lgt_set_binary_input(Alias, Bytes) :- lgt_set_binary_input(Alias, Bytes, []).
lgt_set_binary_input(Alias, Bytes, Opts) :-
    lgt_clean_alias(Alias, 'lgt_capture_in.bin'),
    lgt_bytes_to_file('lgt_capture_in.bin', Bytes),
    open('lgt_capture_in.bin', read, S, [type(binary), alias(Alias)|Opts]), assertz(lgt_cap_in(S)).
lgt_check_binary_input(Expected) :- current_input(S), lgt_read_bytes(S, Got), Got == Expected.
lgt_check_binary_input(Alias, Expected) :- lgt_read_bytes(Alias, Got), Got == Expected.
lgt_clean_binary_input :- lgt_close_in, catch(lgt_delete('lgt_capture_in.bin'), _, true).

% ---- input ------------------------------------------------------------------------------------------
% lgtunit's set_text_input/3 and set_binary_input/3 begin with clean_file(Alias, File, Path) (upstream tools/lgtunit/lgtunit.lgt):
% close the stream holding Alias ("the alias may be associated with a stream opened for a different file"), then every stream
% open on the file. So a case may set the same alias twice: sics_at_end_of_stream_1_10 does, and its second open raised
% permission_error(open, source_sink, alias(st_i)) here before (cfo 2026-10-11, CEO-1689). The file itself is rewritten next.
lgt_clean_alias(Alias, File) :-
    ( catch(stream_property(S, alias(Alias)), _, fail) -> close(S) ; true ),
    absolute_file_name(File, Path),
    forall(catch(stream_property(T, file_name(Path)), _, fail), close(T)).
lgt_close_in :- ( retract(lgt_cap_in(S)) -> catch(close(S), _, true) ; true ),
                ( retract(lgt_prev_in(P)) -> catch(set_input(P), _, true) ; true ).
lgt_set_text_input(Contents) :-
    lgt_atom_to_file('lgt_capture_in.txt', Contents),
    current_input(Prev), assertz(lgt_prev_in(Prev)),
    open('lgt_capture_in.txt', read, S), assertz(lgt_cap_in(S)), set_input(S).
lgt_set_text_input(Alias, Contents) :- lgt_set_text_input(Alias, Contents, []).
lgt_set_text_input(Alias, Contents, Opts) :-
    lgt_clean_alias(Alias, 'lgt_capture_in.txt'),
    lgt_atom_to_file('lgt_capture_in.txt', Opts, Contents),
    open('lgt_capture_in.txt', read, S, [alias(Alias)|Opts]), assertz(lgt_cap_in(S)).
% ⛔ check_text_input reads what is LEFT on the stream -- it is the suite's way of asserting how far a
% reader consumed, so it must NOT re-open the file from the start.
lgt_check_text_input(Expected) :- current_input(S), lgt_read_chars(S, Cs), atom_chars(Text, Cs), Text == Expected.
lgt_check_text_input(Alias, Expected) :- lgt_read_chars(Alias, Cs), atom_chars(Text, Cs), Text == Expected.
lgt_text_input_assertion(Expected, Assertion) :-
    current_input(S), lgt_read_chars(S, Cs), atom_chars(Text, Cs), Assertion = (Text == Expected).
lgt_text_input_assertion(Alias, Expected, Assertion) :-
    lgt_read_chars(Alias, Cs), atom_chars(Text, Cs), Assertion = (Text == Expected).
lgt_clean_text_input :- lgt_close_in, catch(lgt_delete('lgt_capture_in.txt'), _, true).

% ---- files ------------------------------------------------------------------------------------------
% ⛔ file_path/2 resolves against the CASE'S OWN DIRECTORY, which the runner copies into the per-case
% working directory -- so the plain name IS the path. Never an absolute path built here: a case that
% creates a file must not be able to write outside its own scratch directory.
lgt_file_path(Name, Name).
lgt_create_text_file(File, Contents) :- lgt_atom_to_file(File, Contents).
lgt_create_binary_file(File, Bytes) :- lgt_bytes_to_file(File, Bytes).
lgt_check_text_file(File, Expected) :- lgt_file_to_atom(File, Text), Text == Expected.
lgt_clean_file(File) :- catch(lgt_delete(File), _, true).
lgt_delete(File) :- ( catch(delete_file(File), _, fail) -> true ; true ).

% ---- streams ----------------------------------------------------------------------------------------
% A CLOSED stream handle, which is what the permission_error/existence_error cases need to be handed.
lgt_closed_output_stream(S, Opts) :- open('lgt_closed.txt', write, S, Opts), close(S).
lgt_closed_input_stream(S, Opts) :- lgt_atom_to_file('lgt_closed.txt', ''), open('lgt_closed.txt', read, S, Opts), close(S).
% lgtunit: a position term this system accepts, read off a freshly opened stream.
lgt_stream_position(P) :- open('lgt_position.txt', write, S), stream_property(S, position(P)), close(S), lgt_delete('lgt_position.txt').

% ---- term relations ---------------------------------------------------------------------------------
% ⛔ NOT subsumes_term/2 AND NOT =@=/2 -- neither exists in this engine (existence_error, measured
% 2026-09-12), and a shim that leans on a builtin the system under test is missing grades the HARNESS.
% Both are defined here from copy_term/2 + numbervars/3, which are present, so the relation the suite
% asserts is computed the same way whatever the engine is missing.
lgt_variant(A, B) :- copy_term(A, A1), copy_term(B, B1), numbervars(A1, 0, N), numbervars(B1, 0, M), N == M, A1 == B1.
lgt_subsumes(General, Specific) :- \+ \+ ( copy_term(Specific, S1), numbervars(S1, 0, _), General = S1 ).
lgt_assertion(G) :- call(G).
lgt_assertion(_Label, G) :- call(G).

% ⛔⭐ '=~='/2 -- lgtunit's APPROXIMATE EQUALITY, AND IT WAS IMPLEMENTED NOWHERE. 103 expectations across 27
% of the suite's files are written `true(X =~= <constant>)`, and with no operator declaration every one of
% them was a PARSE ERROR in the generated program -- reported as `nooutput`, which reads as the arithmetic
% function under test producing nothing. Measured 2026-09-13: it is every float-valued case in the
% arithmetic families, acos_1 01/02 among them, and it was invisible precisely because those groups also
% had real defects beside it.
%
% ⛔ THE TOLERANCE IS FIXED BY THE SUITE'S OWN CASES, NOT CHOSEN -- and it is lgtunit's own: an absolute
% bound of 100*epsilon first (meaningful near zero), then a RELATIVE bound of 1.0e-5. The cases set the floor:
% iso_tan_1_01 asserts tan(0.5) =~= 0.5463 (true value 0.5463024898..., relative 8.8e-6 off the constant),
% lgt_asinh_1_01, lgt_cosh_1_01 and lgt_acosh_1_01 sit at 2.7e-6, 2.5e-6 and 1.6e-6, iso_integer_power_2_09
% at 1.1e-6 -- all green on every conforming system under lgtunit, all red here while this bound was 1.0e-6,
% which an earlier revision of this comment called lgtunit's value -- the suite's own cases show it cannot be,
% since lgtunit runs them green. ⭐ Name what the bound costs:
% five significant digits, while the suite's constants often carry six -- a real false-green surface, forced
% by the corpus and by lgtunit itself, named here rather than left implicit.
:- op(700, xfx, =~=).
'=~='(A, B) :- number(A), number(B), !, lgt_near(A, B).
'=~='([], []) :- !.
'=~='([A|As], [B|Bs]) :- !, '=~='(A, B), '=~='(As, Bs).
'=~='(A, B) :- A == B.
lgt_near(A, B) :- A =:= B, !.
lgt_near(A, B) :- D is abs(A - B), E is 100 * epsilon, D < E, !.
lgt_near(A, B) :- D is abs(A - B), M is max(abs(A), abs(B)), R is 1.0e-5 * M, D < R.
