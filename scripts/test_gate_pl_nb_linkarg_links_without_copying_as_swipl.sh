#!/usr/bin/env bash
# test_gate_pl_nb_linkarg_links_without_copying_as_swipl.sh -- nb_linkarg/3 STORES ITS VALUE WITHOUT COPYING AND WITHOUT TRAILING, AS
# swipl 9.0.4 DOES (cfo 2026-10-14, row prolog-swi-library-test-pio-every-case-agrees-with-swipl-in-both-modes-ceo-1664, CEO-1698).
#
# a78d3f64e answered nb_linkarg/3 with nb_setarg/3, which COPIES the value. library(pure_input) caches its freshly read list with
# nb_linkarg(4, State, NewList) so the list's tail stays the attributed lazy variable; the copy's tail was a fresh plain variable, so on
# backtracking the cached list matched anything (phrase_from_file((...,"c",...), F) succeeded on "aba"). nb_linkarg/3 is now a C leaf
# beside nb_setarg (by_name_dispatch.c rt_pl_setarg_cell mode 2: setarg's no-copy word, nb_setarg's no-trail store; rtx_plunify.s
# PL_CTX_LEAF_BALL, the lowerer's and the emitter's leaf tables, the clobber and allocating tables regenerated).
#
# THE ARM: one program, five shapes (a linked value shares its variables; nb_setarg's copy does not; the link survives backtracking;
# setarg/3 is undone; arity 0 fails; a non-integer index is type_error), cut against swipl, mode 3 and mode 4. FAIL-ONCE, measured on
# the parent a78d3f64e rebuilt: line 1 differs in both modes (linked(g(_)) for linked(g(1))); with the cure 6 of 6 as swipl.
# rc=0 both modes agree with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build).  ~3 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_nb_linkarg_links_without_copying_as_swipl
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"
SW="$(swipl_bin)"; [ -x "$SW" ] || refuse "no swipl at $SW -- the oracle (swipl_bin)"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- initialization(main).
main :- T = f(_), V = g(X), nb_linkarg(1, T, V), X = 1, arg(1, T, A), writeq(linked(A)), nl,
  T2 = f(_), V2 = g(Y), nb_setarg(1, T2, V2), Y = 1, arg(1, T2, A2), ( A2 = g(Z), var(Z) -> writeq(setarg_copied) ; writeq(setarg_shared(A2)) ), nl,
  T3 = f(a), ( nb_linkarg(1, T3, v), fail ; true ), arg(1, T3, A3), writeq(survives(A3)), nl,
  T4 = f(a), ( setarg(1, T4, v), fail ; true ), arg(1, T4, A4), writeq(setarg_undone(A4)), nl,
  ( nb_linkarg(0, f(a), x) -> writeq(zero_yes) ; writeq(zero_no) ), nl, catch(nb_linkarg(x, f(a), y), error(E2, _), true), writeq(bad(E2)), nl.
PL
want="$(cd "$D" && timeout -k 5 20 "$SW" -q w.pl -t halt < /dev/null 2>/dev/null | sed '/^$/d')"
[ "$(printf '%s\n' "$want" | grep -c .)" = 6 ] || refuse "swipl did not answer the six lines: [$want]"
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=w.s w.pl < /dev/null > /dev/null 2>&1 ) || refuse "mode 4 compile failed"
( cd "$D" && gcc -m64 -no-pie w.s -o w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || refuse "mode 4 link failed"
red=0
for m in m3 m4; do
    if [ "$m" = m3 ]; then got="$(cd "$D" && timeout -k 5 20 "$B/scrip" --run w.pl < /dev/null 2>/dev/null | sed '/^$/d')"; else got="$(cd "$D" && timeout -k 5 20 ./w.bin < /dev/null 2>/dev/null | sed '/^$/d')"; fi
    if [ "$got" = "$want" ]; then echo "  $m GREEN: 6 of 6 lines as swipl"
    else echo "  $m RED: $(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^>') line(s) differ from swipl"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
done
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
