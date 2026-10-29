#!/usr/bin/env bash
# test_gate_pl_a_program_with_more_than_64_dynamic_declarations_keeps_every_one.sh -- THE DYNAMIC TABLES GROW, AND SO DO THE ROOT CELLS: NO 257TH REFUSAL.
# hq_prolog 2026-10-04, the cfo's finding handed to the dynamic-database row: three tables capped at 64 (stage2.h pl_dyn_name/arity with pl_dyn_mark's silent
# return, lower_prolog.c g_pl_decl_dyn_name, and PL_DB_CELLS_MAX in the runtime) dropped the 64th user declaration silently (slot 0 is the registry's), so
# a program with 64 or more ":- dynamic" declarations printed nothing in both modes where swipl answers. Now the compile-time tables grow (ct_grow), every
# Prolog root frame carries PL_DB_FRAME_CELLS = 256 cells and every cell past them lives in the registry's overflow vector, which grows by doubling
# (ceo CEO-1522, Lon's no-fixed-limits law: the 257th used to refuse rc=2 at compile time and BOMB at run time, which is how the Logtalk demo died).
# Witnesses, all in both modes against swipl's text: N = 70 and N = 300 declarations asserted and read back; 300 predicates created at RUN TIME
# by assertz with no declaration (Logtalk's shape); 300 global variables set and read back.
# RED BEFORE on origin 689af8179: N = 70 prints nothing (rc 0) in both modes.
set -u
GATE_NAME=test_gate_pl_a_program_with_more_than_64_dynamic_declarations_keeps_every_one
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
gen() { local n=$1 f=$2; : > "$f"; for ((k = 0; k < n; k++)); do echo ":- dynamic(d$k/1)." >> "$f"; done
    printf 'main :- ' >> "$f"; for ((k = 0; k < n; k++)); do printf 'assertz(d%d(%d)), ' $k $k >> "$f"; done
    printf 'findall(X, d0(X), L0), write(L0), nl, findall(Y, d%d(Y), Ln), write(Ln), nl, d%d(Z), write(Z), nl.\n:- initialization(main).\n' $((n-1)) $((n/2)) >> "$f"; }
gen 70 "$TMPD/w70.pl"; gen 300 "$TMPD/w300.pl"
# the cfo's second witness (2026-10-04): a dynamic predicate whose FILE clause has 300 distinct variables must still match -- the seed road compiles the
# stored term into a fragment, so the seed term's renumbering table and the term-to-tree variable table are sized by the clause, never capped at 256.
genv() { local n=$1 f=$2 vs ns; vs=$(seq -s ", " 1 $n | sed "s/\([0-9]\+\)/V\1/g"); ns=$(seq -s ", " 1 $n); printf ':- dynamic(g/1).\ng(t(%s)).\nmain :- ( g(t(%s)) -> write(ok) ; write(no) ), nl.\n:- initialization(main).\n' "$vs" "$ns" > "$f"; }
genv 300 "$TMPD/v300.pl"
want="$(printf '[0]\n[69]\n35\n')"
red=0
got="$(cd "$TMPD" && timeout -k 5 30 "$SCRIP" w70.pl </dev/null 2>"$TMPD/err")"; rc=$?
if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  70 declarations m3"; else echo "  RED 70 declarations m3: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|' | cut -c1-80)] err=[$(head -c 120 "$TMPD/err" | tr '\n' '|')]"; red=$((red+1)); fi
if timeout -k 5 120 "$SCRIP" --compile --out="$TMPD/w70.s" "$TMPD/w70.pl" </dev/null 2>"$TMPD/err" && gcc -m64 -no-pie "$TMPD/w70.s" -o "$TMPD/w70.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err"; then
    got="$(cd "$TMPD" && timeout -k 5 30 ./w70.bin </dev/null 2>"$TMPD/err")"; rc=$?
    if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  70 declarations m4"; else echo "  RED 70 declarations m4: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|' | cut -c1-80)] err=[$(head -c 120 "$TMPD/err" | tr '\n' '|')]"; red=$((red+1)); fi
else echo "  RED 70 declarations m4: the compile or link refused: $(head -c 160 "$TMPD/err" | tr '\n' '|')"; red=$((red+1)); fi
got="$(cd "$TMPD" && timeout -k 5 30 "$SCRIP" v300.pl </dev/null 2>"$TMPD/err")"; rc=$?
if [ "$rc" = 0 ] && [ "$got" = ok ]; then echo "  ok  a file clause with 300 variables matches m3"; else echo "  RED 300-variable file clause m3: rc=$rc out=[$(printf '%s' "$got" | cut -c1-40)]"; red=$((red+1)); fi
if timeout -k 5 120 "$SCRIP" --compile --out="$TMPD/v300.s" "$TMPD/v300.pl" </dev/null 2>"$TMPD/err" && gcc -m64 -no-pie "$TMPD/v300.s" -o "$TMPD/v300.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err"; then
    got="$(cd "$TMPD" && timeout -k 5 30 ./v300.bin </dev/null 2>"$TMPD/err")"; rc=$?
    if [ "$rc" = 0 ] && [ "$got" = ok ]; then echo "  ok  a file clause with 300 variables matches m4"; else echo "  RED 300-variable file clause m4: rc=$rc out=[$(printf '%s' "$got" | cut -c1-40)]"; red=$((red+1)); fi
else echo "  RED 300-variable file clause m4: the compile or link refused"; red=$((red+1)); fi
printf ':- initialization(main).\nnm(P, K, F) :- number_codes(K, Cs), atom_codes(A, Cs), atom_concat(P, A, F).\nmain :- forall(between(0, 299, K), (nm(r, K, F), T =.. [F, K], assertz(T))), nm(r, 0, F0), G0 =.. [F0, A], call(G0), write(A), nl, nm(r, 299, F9), G9 =.. [F9, B], call(G9), write(B), nl, aggregate_all(count, (between(0, 299, K2), nm(r, K2, Fk), Gk =.. [Fk, _], call(Gk)), C), write(C), nl.\n' > "$TMPD/r300.pl"
printf ':- initialization(main).\nnm(P, K, F) :- number_codes(K, Cs), atom_codes(A, Cs), atom_concat(P, A, F).\nmain :- forall(between(0, 299, K), (nm(g, K, N), nb_setval(N, K))), nb_getval(g0, A), write(A), nl, nb_getval(g299, B), write(B), nl, nb_getval(g150, C), write(C), nl.\n' > "$TMPD/g300.pl"
want300="$(printf '[0]\n[299]\n150\n')"; wantr="$(printf '0\n299\n300\n')"; wantg="$(printf '0\n299\n150\n')"
for w in w300 r300 g300; do
    case "$w" in w300) wantw="$want300";; r300) wantw="$wantr";; g300) wantw="$wantg";; esac
    got="$(cd "$TMPD" && timeout -k 5 60 "$SCRIP" "$w.pl" </dev/null 2>"$TMPD/err")"; rc=$?
    if [ "$rc" = 0 ] && [ "$got" = "$wantw" ]; then echo "  ok  $w m3 keeps all 300"; else echo "  RED $w m3: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|' | cut -c1-80)] err=[$(head -c 160 "$TMPD/err" | tr '\n' '|')]"; red=$((red+1)); fi
    if timeout -k 5 120 "$SCRIP" --compile --out="$TMPD/$w.s" "$TMPD/$w.pl" </dev/null 2>"$TMPD/err" && gcc -m64 -no-pie "$TMPD/$w.s" -o "$TMPD/$w.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err"; then
        got="$(cd "$TMPD" && timeout -k 5 60 "./$w.bin" </dev/null 2>"$TMPD/err")"; rc=$?
        if [ "$rc" = 0 ] && [ "$got" = "$wantw" ]; then echo "  ok  $w m4 keeps all 300"; else echo "  RED $w m4: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|' | cut -c1-80)] err=[$(head -c 160 "$TMPD/err" | tr '\n' '|')]"; red=$((red+1)); fi
    else echo "  RED $w m4: the compile or link refused: $(head -c 160 "$TMPD/err" | tr '\n' '|')"; red=$((red+1)); fi
done
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red arm(s) red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: 70 and 300 dynamic declarations, 300 predicates created at run time and 300 global variables are all kept in both modes, and a 300-variable file clause of a dynamic predicate matches in both modes"
exit 0
