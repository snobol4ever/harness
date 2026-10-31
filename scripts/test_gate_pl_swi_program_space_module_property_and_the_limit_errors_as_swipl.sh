#!/usr/bin/env bash
# test_gate_pl_swi_program_space_module_property_and_the_limit_errors_as_swipl.sh -- SWI program space, relations only (never swipl's absolute sizes): the eight
# cases of swipl's tests/core/test_limit.pl in their order in one small module (module_property(M, program_size/program_space), set_module(M:program_space(N)),
# permission_error(limit, program_space, user) below the current size, resource_error(program_space) when an assert would pass the limit, retract and abolish
# returning the size, 100 rounds of assert and retractall leaving it) plus the database roads that must take M:G as data in the SWI dialect: dynamic, assertz,
# asserta, retract, retractall and abolish with a literal module, a nested module (the innermost wins), user:, a clause with a qualified head, and every one of
# them called through call/1 (the run-time leaves). Before this the lowering stripped a literal M: and the run-time leaves read the functor (:)/2, so the
# counter charged user and assertz(mm:foo) raised permission_error(modify, static_procedure, (:)/2) (CEO-2030, rule 2 of ARCH-PROLOG-DATABASE section 6).
# The probe is cut from swipl in THIS run (swipl_bin); SCRIP's m3 and m4 are compared byte for byte; the self-test feeds the comparison a corrupted reference.
set -u
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP"; exit 2; }
BIN="${SCRIP_BIN:-$ROOT/scrip}"; LIB="$(dirname "$BIN")/out"; [ -d "$LIB" ] || LIB="$ROOT/out"
[ -x "$BIN" ] || { echo "GATE REFUSED(2) [$G]: no $BIN -- run make"; exit 2; }
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$G" "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" || exit 2
command -v gcc >/dev/null 2>&1 || { echo "GATE REFUSED(2) [$G]: gcc absent"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || { echo "GATE REFUSED(2) [$G]: lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"; exit 2; }
SW="$(swipl_bin)"; [ -x "$SW" ] || { echo "GATE REFUSED(2) [$G]: no swipl at $SW -- the oracle (swipl_bin)"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/plspace.XXXXXX")" || { echo "GATE REFUSED(2) [$G]: no workdir"; exit 2; }; trap 'rm -rf "$W"' EXIT
cat > "$W/z.pl" <<'EOF'
:- use_module(library(lists)).
sz(M, S) :- module_property(M, program_size(S)).
c(N, G) :- ( catch(G, E, (( E = error(F, _) -> true ; F = E ), format("~w: error ~q~n", [N, F]), fail)) -> format("~w: yes~n", [N]) ; format("~w: no~n", [N]) ).
t_too_low :- set_module(user:program_space(1000)).
t_retract :- set_module(psl:program_space(0)), dynamic(psl:test/0), sz(psl, S0), assertz(psl:test), retract(psl:test), sz(psl, S), S == S0.
t_abolish :- set_module(psl:program_space(0)), sz(psl, S0), assertz(psl:test), abolish(psl:test/0), sz(psl, S), S == S0.
t_assert :- set_module(psl:program_space(1000)), module_property(psl, program_space(Sp)), Sp == 1000, assertz(psl:test).
t_overflow :- abolish(psl:test/0), set_module(psl:program_space(1000)), forall(between(1, 100, X), assertz(psl:test(X))).
t_repeat :- abolish(psl:test/1), set_module(psl:program_space(100000)), sz(psl, S0), forall(between(1, 100, _), (forall(between(1, 100, X), assertz(psl:test(X))), retractall(psl:test(_)), sz(psl, S), S0 == S)).
t_called :- assertz(qm:t2(1)), qm:t2(1), \+ qm:t2(2).
t_user_untouched :- sz(user, S0), assertz(qm:t3(1)), sz(user, S), S == S0.
t_user_assert :- assertz(user:t9(1)), t9(1).
t_inner_module :- assertz(qm:qm2:t7(1)), qm2:t7(1).
t_asserta_order :- assertz(qm:t8(2)), asserta(qm:t8(1)), findall(X, qm:t8(X), L), L == [1, 2].
t_rule :- assertz((qm:t15(X) :- X > 1)), qm:t15(2), \+ qm:t15(0).
t_retract_binds :- assertz(qm:t14(a, b)), retract(qm:t14(X, Y)), X == a, Y == b.
t_meta_assertz :- G = assertz(qm:t6(1)), call(G), qm:t6(1).
t_meta_dynamic :- G = dynamic(qm:t10/1), call(G), \+ qm:t10(_).
t_meta_retract :- assertz(qm:t11(1)), G = retract(qm:t11(X)), call(G), X == 1, \+ qm:t11(_).
t_meta_retractall :- assertz(qm:t12(1)), G = retractall(qm:t12(_)), call(G), \+ qm:t12(_).
t_meta_abolish :- assertz(qm:t13(1)), G = abolish(qm:t13/1), call(G), \+ catch(qm:t13(_), _, fail).
t_var_module :- M = qm, assertz(M:t16(1)), M:t16(1).
:- initialization((c(too_low, t_too_low), c(retract, t_retract), c(abolish, t_abolish), c(assert, t_assert), c(overflow, t_overflow), c(repeat, t_repeat),
   c(called, t_called), c(user_untouched, t_user_untouched), c(user_assert, t_user_assert), c(inner_module, t_inner_module), c(asserta_order, t_asserta_order),
   c(rule, t_rule), c(retract_binds, t_retract_binds), c(meta_assertz, t_meta_assertz), c(meta_dynamic, t_meta_dynamic), c(meta_retract, t_meta_retract),
   c(meta_retractall, t_meta_retractall), c(meta_abolish, t_meta_abolish), c(var_module, t_var_module))).
EOF
timeout -k 5 60 "$SW" -q -t halt "$W/z.pl" < /dev/null > "$W/ref" 2> "$W/ref.err"
[ "$(grep -c '^[a-z_]*: yes$' "$W/ref")" -ge 17 ] || { echo "GATE REFUSED(2) [$G]: swipl did not answer the probe as designed ($(head -c 200 "$W/ref.err"))"; cat "$W/ref" | head -30; exit 2; }
timeout -k 5 120 "$BIN" "$W/z.pl" < /dev/null > "$W/m3" 2>&1
"$BIN" --compile --out="$W/z.s" "$W/z.pl" < /dev/null > "$W/c.err" 2>&1 || { echo "GATE REFUSED(2) [$G]: the witness does not compile ($(head -c 160 "$W/c.err"))"; exit 2; }
gcc -no-pie -o "$W/z.bin" "$W/z.s" -L"$LIB" -lscrip_rt -Wl,-rpath,"$LIB" -lm -lpthread > "$W/link.err" 2>&1 || { echo "GATE REFUSED(2) [$G]: the witness does not link ($(head -c 160 "$W/link.err"))"; exit 2; }
timeout -k 5 60 "$W/z.bin" < /dev/null > "$W/m4" 2>&1
sed '1s/.*/corrupted/' "$W/ref" > "$W/z.bad"
if cmp -s "$W/m3" "$W/z.bad"; then echo "GATE REFUSED(2) [$G]: the comparison accepted a corrupted reference -- the gate could not fail"; exit 2; fi
bad=0
for m in m3 m4; do
  if cmp -s "$W/$m" "$W/ref"; then echo "  ok  $m: the $(grep -c . "$W/ref") program-space and module-qualified database answers as swipl"; else echo "  RED $m: output differs from swipl:"; diff "$W/ref" "$W/$m" | head -10; bad=1; fi
done
TREE="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)"
if [ $bad -eq 0 ]; then echo "GATE PASS(0) [$G]: the program-space counter, its limit errors and the six database roads taking M:G as data answer as swipl, in both modes (self-test: a corrupted reference is seen; tree SCRIP=$TREE)"; exit 0; fi
echo "GATE FAIL(1) [$G]: a program-space or module-qualified database answer differs from swipl in one mode (tree SCRIP=$TREE)"; exit 1
