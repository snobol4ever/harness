#!/usr/bin/env bash
# test_gate_pl_a_run_time_compile_indexes_the_root_cells_through_the_roots_registry.sh -- A CLAUSE COMPILED AT RUN TIME NAMES THE SAME ROOT CELLS AS THE PROGRAM.
# hq_prolog 2026-10-04, row prolog-bb-a-run-time-compile-indexes-the-root-cells-through-the-roots-registry-never-a-fresh-compile-time-table
# (ARCH-PROLOG-C-OUT-OF-THE-BOX.md section 5.3). On origin a clause compiled at run time (an asserted clause's packet fragment, a meta-call
# wrapper) numbered the root cells it named -- a dynamic predicate's packet, a global variable's cell -- from a fresh compile-time table whose
# indices start at 0, so an asserted clause's nb_setval wrote another predicate's packet cell (core/test_arith.pl under the SWI shim SIGSEGVed
# in both modes; gdb watchpoint on pj_test/4's cell). Now every run-time compile resolves a name through the ROOT'S REGISTRY (cell 0 of the
# standing frame: rt_pl_db_cell_for finds the bound cell or allocates the next free one), the $db_decls table is emitted from the lowerer's
# FINAL state so every compile-time key and predicate is registered before main runs, a run-time ownership test reads the registry, the stale
# compile-time clause shortcuts are off inside a run-time compile, and a global-variable key that is an atom only at run time (a meta-called
# nb_setval) resolves through the same registry. The witnesses also pin the is/2 cold road's bind (found on the way: after the evaluator call
# the bind read its value through a register the call had clobbered).
# ARMS: three witnesses vs swipl in m3 AND m4 -- (1) root cells: two declared dynamics, an asserted clause's nb_setval and nb_getval, a
# meta-called nb_setval, a key first used at run time, a b_setval with a variable key; (2) fragments: an asserted clause calling a static
# predicate, an arithmetic one, a dynamic one it extends, and an undefined one under catch; (3) is/2 through the evaluator (cold road) in
# four shapes. The expected text is the oracle's, cut with /usr/bin/swipl -q -t halt at gate-writing time.
# RED BEFORE on origin 2fa1fcd5c: witness 1 answers existence_error(variable, z) in m4 and refuses the meta-called key in both modes;
# witness 3's second line faulted in m3 for the SWI shim's shape.
set -u
GATE_NAME=test_gate_pl_a_run_time_compile_indexes_the_root_cells_through_the_roots_registry
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
red=0
mkw() { cat > "$TMPD/$1.pl"; }
mkw w_cells <<'EOP'
:- dynamic(p/1).
:- dynamic(q/1).
main :- assertz(p(1)), assertz(q(2)), assertz((setk :- nb_setval(z, 42))), setk, p(X), q(Y), write(X-Y), nl,
        nb_getval(z, V), write(V), nl, assertz((getk(W) :- nb_getval(z, W))), getk(W2), write(W2), nl,
        G = nb_setval(z, 7), call(G), nb_getval(z, V3), write(V3), nl,
        assertz((fresh :- nb_setval(never_seen_at_compile_time, 5))), fresh, nb_getval(never_seen_at_compile_time, F), write(F), nl,
        assertz((bk(K, V4) :- b_setval(K, V4))), bk(bkey, 9), b_getval(bkey, B), write(B), nl.
:- initialization(main).
EOP
mkw w_frag <<'EOP'
:- dynamic(d/1).
d(1).
s(X) :- X = ok.
e(E) :- E is 3 * 7.
main :- assertz((t(Y) :- s(Y), d(Z), Z == 1)), t(R), write(R), nl,
        assertz((u(N) :- e(N))), u(M), write(M), nl,
        assertz((v :- d(A), A = 1, assertz(d(2)))), v, findall(Q, d(Q), L), write(L), nl,
        assertz((w(X2) :- nonexistent_dyn(X2))), catch((w(_), write(bad)), error(existence_error(procedure, PI), _), (write(PI), nl)).
:- initialization(main).
EOP
mkw w_is <<'EOP'
main :- X is 1 + 2, Y is X * 2.5, write(X-Y), nl, Z = f(W), W is 7 // 2, write(Z), nl, A is 2 ** 10, B is A - 1000, write(B), nl, C is max(3, 4.0), write(C), nl.
:- initialization(main).
EOP
want_w_cells='1-2
42
42
7
5
9'
want_w_frag='ok
21
[1,2]
nonexistent_dyn/1'
want_w_is='3-7.5
f(3)
24
4.0'
for w in w_cells w_frag w_is; do
    eval "want=\$want_$w"
    for mode in m3 m4; do
        if [ "$mode" = m3 ]; then got="$(cd "$TMPD" && timeout -k 5 60 "$SCRIP" "$w.pl" </dev/null 2>"$TMPD/err")"; rc=$?
        else
            timeout -k 5 120 "$SCRIP" --compile -o "$TMPD/$w.s" "$TMPD/$w.pl" </dev/null 2>"$TMPD/err" || { echo "  RED $w $mode: the compile refused: $(head -c 160 "$TMPD/err")"; red=$((red+1)); continue; }
            gcc -m64 -no-pie "$TMPD/$w.s" -o "$TMPD/$w.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || { echo "  RED $w $mode: the assembler or linker refused: $(grep -m1 -E 'Error|error' "$TMPD/err" | head -c 200)"; red=$((red+1)); continue; }
            got="$(cd "$TMPD" && timeout -k 5 60 "./$w.bin" </dev/null 2>"$TMPD/err")"; rc=$?
            rm -f "$TMPD/$w.s" "$TMPD/$w.bin"
        fi
        if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  $w $mode"
        else echo "  RED $w $mode: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|' | cut -c1-200)] err=[$(head -c 160 "$TMPD/err" | tr '\n' '|')] want [$(printf '%s' "$want" | tr '\n' '|' | cut -c1-120)]"; red=$((red+1)); fi
    done
done
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red arm(s) red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: a clause compiled at run time names the program's root cells through the root's registry, a run-time key resolves the same way, and the is/2 cold road binds its value, in both modes"
exit 0
