#!/usr/bin/env bash
# s4e_probe_consult_unify_fold.sh [--list] -- A CONSULTED CLAUSE'S LEADING HEAD UNIFICATIONS ARE MOVED INTO ITS HEAD AS swipl STORES THEM (CSR step 6
# rung 7a, the consulted road, CEO-2064; officer_02 2026-11-11). swipl 9.0.4 (flag optimise_unify, default true) moves each leading body goal
# V = T or T = V into the head when V is a variable that occurs exactly once in the head, T is not a variable and T does not contain V; it repeats
# over the next leading goal and stops at the first that does not qualify; a body left empty is true. So a consulted DCG rule g(W) --> [hello],
# n(W) is stored as g(A, [hello|B], C) :- n(A, B, C). The probe consults one file of fifteen clauses that measure the rule (folded, not folded,
# chained, stopped, DCG) under --dialect=swi and prints clause/2 of each, numbervar'd; swipl through util_oracle.sh is the oracle. MEASURED
# 2026-11-11 at SCRIP 106634f52 (officer_02): RED, SCRIP stores every clause as written.
# rc 0 GREEN, 1 RED naming the first differing line, 2 REFUSE. Writes only under /tmp/s4e/<seat>.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"
me="s4e_probe_consult_unify_fold"
refuse() { echo "REFUSE(2) [$me]: $*"; exit 2; }
[ "${1:-}" = "--list" ] && { sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0; }
scrip="$root/SCRIP/scrip"; [ -x "$scrip" ] || refuse "no binary at $scrip (make -j8 first)"
bash "$here/util_require_fresh.sh" --gate "$me" >/dev/null 2>&1 || { bash "$here/util_require_fresh.sh" --gate "$me"; exit 2; }
seat="${S4E_SEAT:-probe}"; mkdir -p "/tmp/s4e/$seat"; t="$(mktemp -d "/tmp/s4e/$seat/consult_fold.XXXXXX")" || refuse "no scratch"
trap 'rm -rf "$t"' EXIT
tree="$(git -C "$root/SCRIP" rev-parse --short=9 HEAD 2>/dev/null)"
cat > "$t/fold_lib.pl" <<'EOF'
c1(X, Y) :- X = a, Y = b, q.
c2(X, X) :- X = a, q.
c3(X) :- [a] = X, q.
c4(X) :- q, X = a.
c5(f(X)) :- X = a, q.
c6(X, Y) :- X = Y, q.
c7(X) :- X = a.
c8(X, Y) :- X = f(Y), q(Y).
c9(X) :- X = Z, Z = b, q.
d1(X, g(X)) :- X = a, q.
d2(X) :- X = f(X), q.
d3(X, Y) :- X = a, q, Y = b.
d6(X) :- X = 3, q.
g(W) --> [hello], n(W).
n(N) --> [N].
q.
q(_).
EOF
cat > "$t/fold_main.pl" <<'EOF'
:- initialization(main).
main :- consult(fold_lib), forall(member(P, [c1/2,c2/2,c3/1,c4/1,c5/1,c6/2,c7/1,c8/2,c9/1,d1/2,d2/1,d3/2,d6/1,g/3,n/3]), (P = N/A, functor(H, N, A), forall(clause(H, B), (copy_term((H:-B), T), numbervars(T, 0, _), print(T), nl)))).
EOF
w="$( cd "$t" && bash "$here/util_oracle.sh" swipl --timeout 60 -- -q -t halt fold_main.pl < /dev/null 2>&1 )"
[ "$(printf '%s\n' "$w" | grep -c ':-')" = 15 ] || refuse "swipl did not print fifteen clauses (got: $(printf '%s' "$w" | head -1 | cut -c1-80))"
o="$( cd "$t" && SCRIP_PL_PRELUDE_SO=0 bash "$here/util_run_slot.sh" timeout -k 5 120 "$scrip" --dialect=swi --run fold_main.pl < /dev/null 2>&1 )"
d="$(diff <(printf '%s\n' "$w") <(printf '%s\n' "$o") | grep -c '^>')"
echo "CONSULT_UNIFY_FOLD_BOARD clauses=15 differ=$d (tree $tree)"
[ "$d" = 0 ] && { echo "GATE OK [$me]: every consulted clause is stored as swipl stores it"; exit 0; }
paste -d'|' <(printf '%s\n' "$w") <(printf '%s\n' "$o") | awk -F'|' '$1 != $2 { print "  RED: swipl " $1 "   scrip " $2; exit }'
echo "GATE FAIL [$me]: $d of 15 clauses differ from swipl"; exit 1
