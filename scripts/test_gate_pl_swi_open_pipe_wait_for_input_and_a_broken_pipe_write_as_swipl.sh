#!/bin/bash
# test_gate_pl_swi_open_pipe_wait_for_input_and_a_broken_pipe_write_as_swipl.sh -- open(pipe(Cmd), Mode, S [, Opts]), wait_for_input/3 and a write to a pipe whose reader has gone, as
# swipl 9.0.4 (the cqo, 2026-11-01, row prolog-swi-suite-to-100-r-1981; SWI files/test_pipe 0/4 -> 4/4 both modes).
# THE RULINGS, each measured on swipl: open(pipe(Cmd)) runs Cmd under popen in mode read or write; append and update raise existence_error(source_sink, pipe(Cmd)), an unbound Cmd
# instantiation_error, a non-atom Cmd type_error(atom, Cmd); a read pipe opened in text mode without bom(false) reads ahead at open (BOM detection), so it waits for the first byte; a write pipe
# ignores SIGPIPE so a write to a pipe whose reader has exited raises io_error(write, S) at the write that hits it; the flags pipe (true) and pid (the process id) are read-only;
# wait_for_input(Streams, Ready, Timeout) polls the streams' descriptors, a stream with buffered input is ready at once, Timeout is seconds (integer or float) or infinite, an unbound list or
# timeout is instantiation_error and a non-number type_error(float, T). NOT GRADED (DEBT): set_stream(S, timeout(T)) is accepted and has no effect, so a read never raises
# timeout_error(read, S): the timeout needs a per-stream field of the runtime stream table, a field Lon grants; the error context swipl fills (context(system:open/3, Msg)) is left unbound.
# Red on origin 42b683a99 (domain_error(source_sink, pipe(...)) at the first open). The ref was cut from swipl 9.0.4 -q -t halt twice, equal.
# rc 0 both modes equal the swipl-cut ref; rc 1 a mode differs; rc 2 cannot measure (no SCRIP beside the harness).
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../../.scratch/plpipe-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cat > "$T/plpipe.pl" <<'PL'
:- use_module(library(lists)).
:- initialization(main).
e(G) :- catch(G, error(E, _), true), ( var(E) -> writeq(no_error) ; E = io_error(K, St) -> ( is_stream(St) -> writeq(io_error(K, stream)) ; writeq(io_error(K, St)) ) ; writeq(E) ), nl.
main :-
    current_prolog_flag(pipe, P), writeq(pipe(P)), nl,
    current_prolog_flag(pid, Pid), ( integer(Pid), Pid > 0 -> writeq(pid) ; writeq(no_pid) ), nl,
    open(pipe('echo hello.'), read, S0), read_term(S0, T0, []), close(S0), writeq(T0), nl,
    open(pipe('cat'), write, W0), format(W0, 'x.~n', []), close(W0),
    open(pipe('sleep 1; echo late.'), read, S1, [bom(false)]),
    wait_for_input([S1], R1, 0), length(R1, N1), writeq(ready_now(N1)), nl,
    wait_for_input([S1], R2, infinite), length(R2, N2), writeq(ready_later(N2)), nl,
    read(S1, T1), writeq(T1), nl, close(S1),
    open(pipe('echo a. ; echo b.'), read, S2), read(S2, A), wait_for_input([S2], R3, 0), length(R3, N3), writeq(buffered(A, N3)), nl, close(S2),
    e((open(pipe(true), write, W), forall(between(1, 200000, _), format(W, '0123456789~n', [])), close(W))),
    e(open(pipe(ls), append, _)), e(open(pipe(ls), update, _)), e(open(pipe(_), read, _)), e(open(pipe(1), read, _)),
    e(wait_for_input(_, _, 0)), e((wait_for_input([], R6, 0.1), writeq(R6), nl)), e(wait_for_input([user_input], _, foo)).
PL
cat > "$T/plpipe.ref" <<'REF'
pipe(true)
pid
hello
x.
ready_now(0)
ready_later(1)
late
buffered(a,1)
io_error(write,stream)
existence_error(source_sink,pipe(ls))
existence_error(source_sink,pipe(ls))
instantiation_error
type_error(atom,1)
instantiation_error
[]
no_error
type_error(float,foo)
REF
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
out="$(bash "$HERE/test_witness_both_modes.sh" "$T/plpipe.pl" "$T/plpipe.ref" 2>&1)"; rc=$?
echo "$out" | tail -3
case $rc in 0) echo "GATE OK -- both modes open a pipe, poll it and raise io_error on a broken pipe write as swipl"; exit 0;; 2) echo "REFUSE(2): the witness runner could not measure"; exit 2;; *) echo "GATE FAIL -- a mode differs from swipl on open(pipe(_)), wait_for_input/3 or a broken pipe write"; exit 1;; esac
