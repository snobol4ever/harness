#!/usr/bin/env bash
# test_gate_pl_a_cut_redo_reaches_its_own_barrier.sh -- A CUT INSIDE AN IF-THEN-ELSE, A SOFT-CUT, A DISJUNCTION OR A catch/3 ARM (ISO 7.8.4, 7.8.7,
# 7.8.8, 7.8.9) cuts the CLAUSE and nothing more, and a cut that is not at the top of an arm leaves that arm's redo alive (hq_prolog 2026-09-25,
# CEO-1266; the cure is lower_prolog.c at 412be71e1).
# THE DEFECT. The arm's redo pointed at the clause's cut barrier, a bare IR_FAIL, which the gate's redo dispatch resolved to the GATE'S own omega,
# so backtracking resumed mem/2 in a frame the cut had already torn down: c1 below SIGSEGV'd in both modes. And any cut ANYWHERE inside an arm
# forfeited the arm's whole redo, so (true -> (X = 1 ; X = 2, !) ; true) never produced X = 2.
# THE EXPECTATIONS ARE THE ORACLE'S: gprolog prints the six lines below byte for byte (2026-09-25).
# RED BEFORE on a clean origin build 62a21f70f: rc=139 SIGSEGV in m3 AND m4 on the first line.
set -u
GATE_NAME=test_gate_pl_a_cut_redo_reaches_its_own_barrier
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
cat > "$TMPD/cut.pl" <<'EOP'
:- initialization(main).
mem(M,[M|_]).
mem(M,[_|T]) :- mem(M,T).
c1 :- mem(X,[1,2]), write(X), (true -> ! ; true), fail.
c1 :- write(c1b).
c2 :- mem(X,[1,2]), write(X), (! ; true), fail.
c2 :- write(c2b).
c3(X) :- (true -> (X = 1 ; X = 2, !) ; true).
c4(X) :- catch((mem(X,[1,2,3]), (X >= 2, ! ; true)), _, true).
c5(X) :- (mem(X,[1,2,3]) *-> (X >= 2, ! ; true) ; true).
c6 :- mem(X,[a,b]), write(X), (fail ; !), fail.
c6 :- write(c6b).
t(G) :- ( catch(G, E, (write(ex(E)), fail)) -> true ; write(' no') ), nl.
main :- t(c1), t(c2), findall(X, c3(X), L3), write(L3), nl,
        findall(X, c4(X), L4), write(L4), nl,
        findall(X, c5(X), L5), write(L5), nl, t(c6).
EOP
want='1 no
1 no
[1,2]
[1,2]
[1,2]
a no'
red=0
for mode in m3 m4; do
    if [ "$mode" = m3 ]; then got="$(timeout -k 5 20 "$SCRIP" "$TMPD/cut.pl" </dev/null 2>"$TMPD/err")"; rc=$?
    else
        timeout -k 5 60 "$SCRIP" --compile -o "$TMPD/cut.s" "$TMPD/cut.pl" </dev/null 2>"$TMPD/err" || refuse "m4 compile failed: $(head -c 160 "$TMPD/err")"
        gcc -m64 -no-pie "$TMPD/cut.s" -o "$TMPD/cut.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || refuse "m4 link failed: $(head -c 160 "$TMPD/err")"
        got="$(timeout -k 5 20 "$TMPD/cut.bin" </dev/null 2>"$TMPD/err")"; rc=$?
        rm -f "$TMPD/cut.s" "$TMPD/cut.bin"
    fi
    if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  $mode"
    else echo "  RED $mode: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|')] want [$(printf '%s' "$want" | tr '\n' '|')]"; red=$((red+1)); fi
done
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red mode(s) red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: a cut in an arm cuts the clause only, a nested cut leaves the arm's redo alive, both modes equal gprolog"
exit 0
