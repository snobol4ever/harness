#!/usr/bin/env bash
# test_gate_pl_a_cyclic_term_hashes_in_finite_time.sh -- A CYCLIC TERM HASHES IN FINITE TIME, IN BOTH MODES.
# hq_prolog 2026-10-03, the coo's red on swi_tests (CEO-1342 pass 33: core/test_acyclic.pl HANG in mode 4, every case): term_hash/2 (e161ff3b2) walked
# X = f(X) for ever in BOTH modes -- the mode-3 run showed its cases printed before the kill, the mode-4 binary's stdout was block-buffered and showed
# nothing, so the red read as mode 4 only. The walker now marks every compound on its path (pl_acyclic_walk's own mark) and a kid reaching a marked
# ancestor hashes one constant. Witness: X = f(X), term_hash(X, T), integer(T) answers in both modes within 10 s with swipl's text; an acyclic term's
# hash is unchanged by the mark (two equal terms hash equal, a different term differs).
# RED BEFORE on origin b1bee0c53: both modes rc=124 (timeout) on the first witness.
set -u
GATE_NAME=test_gate_pl_a_cyclic_term_hashes_in_finite_time
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
red=0
cat > "$TMPD/w_cyc.pl" <<'EOP'
main :- X = f(X), write(a), nl, term_hash(X, T), write(b), nl, ( integer(T) -> write(ok) ; write(no) ), nl,
        L = [a|L], term_hash(L, T2), ( integer(T2) -> write(ok2) ; write(no2) ), nl,
        Y = g(1, Z, h(Y)), Z = k(Y), term_hash(Y, T3), ( integer(T3) -> write(ok3) ; write(no3) ), nl.
:- initialization(main).
EOP
cat > "$TMPD/w_acyc.pl" <<'EOP'
main :- term_hash(f(a, [1, 2|g(x)], 3.5), H1), term_hash(f(a, [1, 2|g(x)], 3.5), H2), term_hash(f(a, [1, 2|g(y)], 3.5), H3),
        ( H1 == H2 -> write(same) ; write(differ) ), nl, ( H1 == H3 -> write(same) ; write(differ) ), nl, term_hash(_, U), ( var(U) -> write(unbound) ; write(bound) ), nl.
:- initialization(main).
EOP
want_w_cyc='a
b
ok
ok2
ok3'
want_w_acyc='same
differ
unbound'
for w in w_cyc w_acyc; do
    eval "want=\$want_$w"
    for mode in m3 m4; do
        if [ "$mode" = m3 ]; then got="$(cd "$TMPD" && timeout -k 5 10 "$SCRIP" "$w.pl" </dev/null 2>"$TMPD/err")"; rc=$?
        else
            timeout -k 5 120 "$SCRIP" --compile -o "$TMPD/$w.s" "$TMPD/$w.pl" </dev/null 2>"$TMPD/err" || { echo "  RED $w $mode: the compile refused: $(head -c 160 "$TMPD/err")"; red=$((red+1)); continue; }
            gcc -m64 -no-pie "$TMPD/$w.s" -o "$TMPD/$w.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || { echo "  RED $w $mode: the assembler or linker refused: $(grep -m1 -E 'Error|error' "$TMPD/err" | head -c 200)"; red=$((red+1)); continue; }
            got="$(cd "$TMPD" && timeout -k 5 10 "./$w.bin" </dev/null 2>"$TMPD/err")"; rc=$?
            rm -f "$TMPD/$w.s" "$TMPD/$w.bin"
        fi
        if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  $w $mode"
        else echo "  RED $w $mode: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|' | cut -c1-200)] err=[$(head -c 160 "$TMPD/err" | tr '\n' '|')] want [$(printf '%s' "$want" | tr '\n' '|' | cut -c1-120)]"; red=$((red+1)); fi
    done
done
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red arm(s) red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: a cyclic term (a self-referencing structure, a cyclic list, a two-cell cycle) hashes to an integer in finite time in both modes, and an acyclic term's hash is a function of the term"
exit 0
