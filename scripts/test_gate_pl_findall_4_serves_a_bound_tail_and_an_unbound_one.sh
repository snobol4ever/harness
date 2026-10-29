#!/usr/bin/env bash
# findall/4's FOURTH ARGUMENT IS READ AS AN INPUT AND BOUND AS AN OUTPUT, and one operand kind serves both halves only
# because the runtime dereferences the tail WHEN IT IS BOUND and keeps the reference when it is not. Each half fails on
# its own, and THE TWO HALVES FAIL ON DIFFERENT WITNESSES, which is the whole reason this gate has two blocks:
#   the LOWERING half  -- a value read (IR_VAR) of an UNBOUND tail is detached from the slot, so the unification that
#                         should bind Tail binds a copy and Tail stays unbound. Fails on the STATIC shapes below.
#   the RUNTIME half   -- a raw reference consed onto the solutions keeps a pointer into the activation frame, so a
#                         BOUND tail reads back as whatever goal later reused that slot: a tail that spells itself 'nl'.
# ⛔ THE RUNTIME HALF IS INVISIBLE TO EVERY STATIC SHAPE, AND THIS GATE'S FIRST CUT PROVED IT THE HARD WAY -- it shipped
# with seven static witnesses, went GREEN against a tree with the deref removed, and was a false green for the exact
# defect it was written to pin. The frame slot is only reused early enough to be observed when the goal is META-CALLED
# THROUGH A VARIABLE (pl_meta_call_dyn): `run(G) :- call(G)`, `catch(G,_,true)`, or a goal built into a variable first.
# `call((findall(...), ...))` on a LITERAL conjunction is lowered statically and does NOT reproduce it -- which is also
# why the row that found this symptom mis-attributed it to the static meta path.
# ⛔ AND logtalk_iso CANNOT SEE THE RUNTIME HALF EITHER: --group findall_4 reads 15/15 with the tail consed raw, so the
# trade is invisible to the suite and a seat grading only the suite would land it.
# The expectation is CUT FROM THE ORACLE at run time, never from our own output, and both modes must print it.
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
[ -x ./scrip ] || { echo "⛔ REFUSE(2): ./scrip not built -- run make" >&2; exit 2; }
SWIPL=/usr/bin/swipl
[ -x "$SWIPL" ] || { echo "⛔ REFUSE(2): no oracle at $SWIPL -- this gate cuts its expectation from swipl, it cannot assert without one" >&2; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.pl" <<'EOF'
:- initialization(main).
run(G) :- call(G).
runc(G) :- catch(G,_,true).
main :- findall(X,(X=1;X=2),[A,B,3],T), write(unbound_tail(A,B,T)), nl,
        U = [9], findall(Y,(Y=1;Y=2),S,U), write(bound_tail(S)), nl,
        findall(Z,(Z=1;Z=2),S2,[3]), write(literal_tail(S2)), nl,
        findall(_,fail,S3,[7]), write(no_solutions(S3)), nl,
        findall(V,(V=1;V=2),S4,T4), write(open_tail(S4,T4)), nl,
        call((findall(W,(W=1;W=2),S5,[3]), write(static_meta(S5)), nl)),
        U2 = [9], run((findall(P,(P=1;P=2),S6,U2), write(dyn_call(S6)), nl)),
        U3 = [9], runc((findall(Q,(Q=1;Q=2),S7,U3), write(dyn_catch(S7)), nl)),
        U4 = [9], G4 = (findall(R,(R=1;R=2),S8,U4), write(dyn_var(S8)), nl), call(G4),
        U5 = [9], run((findall(N,(N=1;N=2),[1,2|U5],T5), write(dyn_unbound(T5)), nl)).
EOF
exp="$(timeout -k 5 30 "$SWIPL" -q -g halt "$W/w.pl" 2>/dev/null | sed -E 's/_[0-9]+/_V/g')"
[ -n "$exp" ] || { echo "⛔ REFUSE(2): the oracle printed nothing for the witness -- measured nothing, not a verdict" >&2; exit 2; }
rc=0
for m in 3 4; do
  if [ "$m" = 3 ]; then got="$(timeout -k 5 20 ./scrip "$W/w.pl" </dev/null 2>&1 | sed -E 's/_G[0-9]+/_V/g')"; else
    timeout -k 5 60 ./scrip --compile --out="$W/w.s" "$W/w.pl" </dev/null >"$W/c.log" 2>&1 || { echo "⛔ m$m: compile failed"; cat "$W/c.log"; rc=1; continue; }
    gcc -no-pie "$W/w.s" -Lout -lscrip_rt -Wl,-rpath,"$PWD/out" -lm -lpthread -o "$W/w.bin" >>"$W/c.log" 2>&1 || { echo "⛔ m$m: link failed"; cat "$W/c.log"; rc=1; continue; }
    got="$(timeout -k 5 20 "$W/w.bin" </dev/null 2>&1 | sed -E 's/_G[0-9]+/_V/g')"; fi
  if [ "$got" = "$exp" ]; then echo "✅ m$m agrees with the oracle on all ten findall/4 tail shapes, static and dynamically meta-called"
  else echo "⛔ m$m disagrees with the oracle on a findall/4 tail"; diff <(printf '%s\n' "$exp") <(printf '%s\n' "$got") | sed 's/^/       /'; rc=1; fi
done
if timeout -k 5 20 ./scrip "$W/w.pl" </dev/null 2>&1 | grep -qE '\[1,2\|[a-z]'; then
  echo "⛔ control arm: a tail printed as [1,2|<atom> -- the raw frame reference was consed without a deref and read back as a later goal, the exact defect this gate pins. NOTE an OPEN tail spells itself [1,2|_G<n> and is correct; only a lowercase tail is the dangling slot."; rc=1
else echo "✅ control arm: no bound tail read back as a dangling frame slot"; fi
[ "$rc" = 0 ] && echo "GATE GREEN" || echo "GATE RED"
exit $rc
