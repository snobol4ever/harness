#!/usr/bin/env bash
# test_gate_pl_a_thousand_asserted_clauses_cost_a_thousand_clause_compilations_not_a_million.sh -- AN ASSERTZ COMPILES ONE CLAUSE, NOT THE WHOLE PREDICATE.
# hq_prolog 2026-10-04, row prolog-bb-the-dynamic-database-is-a-packet-of-clause-boxes-compiled-once-at-assertz-... (ARCH-PROLOG-C-OUT-OF-THE-BOX section 5).
# Today every assertz recompiles the whole predicate (pl_db_store recompile=1 -> rt_pl_db_recompile -> pl_runtime_define_pred over every clause), so 1,000
# asserted clauses cost ~500,000 clause compilations: the coo's swi_tests db/test_jit.pl (test_index_1/2) times out at 120 s in both modes at a87e4fd35 and
# at 464179dae alike. Witness: 1,000 assertz of d/2 (string keys, then float keys) + 1,000 first-argument lookups answer done1/done2 within 20 s in each mode --
# an order of magnitude above the cured cost (a 200-clause run costs 3 s today and grows quadratically), never beside it.
# RED BEFORE on origin 464179dae: rc=124 in both modes (120 s+); PASS on the packet landing: 0.3 s (m3) and 0.5 s (m4) per witness.
set -u
GATE_NAME=test_gate_pl_a_thousand_asserted_clauses_cost_a_thousand_clause_compilations_not_a_million
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
BOUND="${PL_ASSERT_GATE_BOUND:-20}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
red=0
cat > "$TMPD/w_str.pl" <<'EOP'
:- dynamic d/2.
main :- forall(between(1, 1000, I), (string_concat("a", I, D), assertz(d(D, I)))), write(done1), nl, forall(between(1, 1000, I), (string_concat("a", I, D), d(D, I2), I2 == I)), write(done2), nl.
:- initialization(main).
EOP
cat > "$TMPD/w_flt.pl" <<'EOP'
:- dynamic d/2.
main :- forall(between(1, 1000, I), (F is float(I), assertz(d(F, I)))), write(done1), nl, forall(between(1, 1000, I), (F is float(I), d(F, I2), I2 == I)), write(done2), nl, retractall(d(_, _)), ( d(_, _) -> write(left) ; write(empty) ), nl.
:- initialization(main).
EOP
want_w_str='done1
done2'
want_w_flt='done1
done2
empty'
for w in w_str w_flt; do
    eval "want=\$want_$w"
    for mode in m3 m4; do
        t0=$(date +%s.%N)
        if [ "$mode" = m3 ]; then got="$(cd "$TMPD" && timeout -k 5 "$BOUND" "$SCRIP" "$w.pl" </dev/null 2>"$TMPD/err")"; rc=$?
        else
            timeout -k 5 120 "$SCRIP" --compile -o "$TMPD/$w.s" "$TMPD/$w.pl" </dev/null 2>"$TMPD/err" || { echo "  RED $w $mode: the compile refused: $(head -c 160 "$TMPD/err")"; red=$((red+1)); continue; }
            gcc -m64 -no-pie "$TMPD/$w.s" -o "$TMPD/$w.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || { echo "  RED $w $mode: the assembler or linker refused: $(grep -m1 -E 'Error|error' "$TMPD/err" | head -c 200)"; red=$((red+1)); continue; }
            got="$(cd "$TMPD" && timeout -k 5 "$BOUND" "./$w.bin" </dev/null 2>"$TMPD/err")"; rc=$?
            rm -f "$TMPD/$w.s" "$TMPD/$w.bin"
        fi
        dur=$(awk -v a="$t0" -v b="$(date +%s.%N)" 'BEGIN{printf "%.1f", b-a}')
        if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  $w $mode (${dur}s)"
        else echo "  RED $w $mode: rc=$rc after ${dur}s (bound ${BOUND}s) out=[$(printf '%s' "$got" | tr '\n' '|' | cut -c1-80)] err=[$(head -c 120 "$TMPD/err" | tr '\n' '|')]"; red=$((red+1)); fi
    done
done
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red arm(s) red -- an assertz still recompiles the whole predicate (or the lookup road is quadratic)"; exit 1; }
echo "GATE PASS [$GATE_NAME]: 1,000 asserted clauses with string and float keys, 1,000 lookups and a retractall answer within ${BOUND}s in both modes"
exit 0
