#!/usr/bin/env bash
# test_gate_pl_iso_rung7_a_cut_inside_a_findall_bagof_setof_goal_has_its_own_barrier.sh -- PROLOG ISO LADDER, RUNG 7 (cto, CEO-617/650, 2026-09-13).
# THE RUNG (ISO 7.8.4 cut, 8.10.1/8.10.2/8.10.3 findall/bagof/setof): the Goal of findall/3, bagof/3 and setof/3 is
# called AS BY call/1, so a `!` anywhere inside it is LOCAL to that goal -- it prunes the goal's remaining choice
# points, the collection then completes with the solutions gathered so far, and the CALLER's choice points are
# untouched (the `opaque` arm below proves the caller survives). `call/1` has always set this barrier
# (lower_prolog.c: save cutomega, set it to the call's own barrier, bump cut_scope); findall/bagof/setof never did,
# so a `!` nested inside a control construct in their Goal was wired to the ENCLOSING CLAUSE's barrier and pruned
# nothing. A bare top-level `!` in the goal was accidentally correct, which is why this survived to rung 7.
# ⛔ THE CURE MUST NOT OVER-CUT: `\+ \+ !` inside the goal is its own call barrier and must still read [1,2].
# THE EXPECTATIONS ARE ORACLE-AGREED: swipl 9 and gprolog 1.4.5 return all twelve lines below identically.
# RED BEFORE on a clean origin build c2a902ed8: 8 of the 12 lines wrong (a/b/d/e/i/j read [1,2] for [1],
# c read [1,1,2,2] for [1,1], j read [1,2] for [2]) AND the bagof-with-a-free-variable line CORE DUMPED.
set -u
GATE_NAME=test_gate_pl_iso_rung7_a_cut_inside_a_findall_bagof_setof_goal_has_its_own_barrier
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SUITE="${S4E_CORPUS:-$ROOT/corpus}/packages/prolog/logtalk_iso"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -d "$SUITE" ] || refuse "no vendored suite at $SUITE"
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
MODES="${PL_RUNG_MODES:-m3,m4}"
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
red=0; total=0
floor() {
    local group="$1" want="$2" line pass
    line="$(python3 "$HERE/util_logtalk_grade.py" --suite "$SUITE" --scrip "$SCRIP" --modes "$MODES" --jobs "${PL_RUNG_JOBS:-8}" --group "$group" 2>/dev/null | grep -m1 '^LOGTALK_ISO_BOARD ')"
    [ -n "$line" ] || { echo "  ⛔ $group: the grader printed no LOGTALK_ISO_BOARD line"; red=$((red+1)); total=$((total+1)); return; }
    pass="$(printf '%s\n' "$line" | sed -n 's/.*m3_pass=\([0-9]*\).*/\1/p')"
    total=$((total+1))
    if [ "${pass:-0}" -ge "$want" ]; then echo "  ok  $group m3_pass=$pass (floor $want)  $line"
    else echo "  RED $group m3_pass=$pass < floor $want  $line"; red=$((red+1)); fi
    case "$MODES" in *m4*)
        local p4; p4="$(printf '%s\n' "$line" | sed -n 's/.*m4_pass=\([0-9]*\).*/\1/p')"
        if [ -n "$p4" ] && [ "$p4" -lt "$want" ]; then echo "  RED $group m4_pass=$p4 < floor $want (modes may diverge as an optimization, never here)"; red=$((red+1)); fi ;;
    esac
}
run_m3() { timeout -k 5 20 "$SCRIP" "$1" </dev/null 2>"$TMPD/err"; }
run_m4() {
    local src="$1" s="$TMPD/w.s" b="$TMPD/w.bin"
    timeout -k 5 60 "$SCRIP" --compile -o "$s" "$src" </dev/null 2>"$TMPD/err" || { echo "  (m4: compile failed: $(head -c 160 "$TMPD/err"))"; return 97; }
    gcc -m64 -no-pie "$s" -o "$b" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || { echo "  (m4: link failed: $(head -c 160 "$TMPD/err"))"; return 98; }
    timeout -k 5 20 "$b" </dev/null 2>"$TMPD/err"
}
arm() {
    local name="$1" src="$2" want_out="$3" want_rc="$4" mode got rc
    for mode in m3 m4; do
        case "$MODES" in *"$mode"*) : ;; *) continue ;; esac
        total=$((total+1))
        got="$("run_$mode" "$src")"; rc=$?
        if [ "$got" = "$want_out" ] && [ "$rc" = "$want_rc" ]; then echo "  ok  $name $mode"
        else echo "  RED $name $mode: rc=$rc want $want_rc; out=[$got] want [$want_out] $(head -c 200 "$TMPD/err" 2>/dev/null)"; red=$((red+1)); fi
    done
}
cat > "$TMPD/cut.pl" <<'EOP'
:- initialization(main).
member(M,[M|_]).
member(M,[_|T]) :- member(M,T).
q(a). q(b).
opaque :- findall(X, ((X=1;X=2), !), _), fail.
opaque :- write(outer_alive), nl.
main :-
    findall(X1, ((X1=1;X1=2), (true -> !)), A), write(a(A)), nl,
    findall(X2, ((X2=1;X2=2), (true *-> !)), B), write(b(B)), nl,
    findall(X3, ((X3=1;X3=2), (true;!)), C), write(c(C)), nl,
    findall(X4, ((X4=1;X4=2), (!;true)), D), write(d(D)), nl,
    findall(X5, ((X5=1;X5=2), (fail;!)), E), write(e(E)), nl,
    findall(X6, ((X6=1;X6=2), !), F), write(f(F)), nl,
    findall(X7, (member(X7,[1,2,3]), !), G), write(g(G)), nl,
    findall(X8, ((X8=1;X8=2), \+ \+ !), H), write(h(H)), nl,
    bagof(X9, ((X9=1;X9=2), (fail;!)), I), write(i(I)), nl,
    setof(XA, ((XA=2;XA=1), (fail;!)), J), write(j(J)), nl,
    bagof(XB-Y, (q(Y), (XB=1;XB=2), (fail;!)), K), write(k(K)), nl,
    opaque,
    halt.
EOP
arm a_cut_inside_a_collection_goal_is_local_to_that_goal "$TMPD/cut.pl" "$(printf '%s\n' 'a([1])' 'b([1])' 'c([1,1])' 'd([1])' 'e([1])' 'f([1])' 'g([1])' 'h([1,2])' 'i([1])' 'j([2])' 'k([1-a])' 'outer_alive')" 0
floor if_then_2 11
floor soft_cut_2_3 21
floor cut_0 19
# findall_3's floor follows its population, 14 -> 13 (cto 2026-09-26): 97ade7cf7 (ceo CEO-1235 (3)) declares coinduction
# unsupported, as gprolog's adapter does, so lgt_findall_3_11 -- a cyclic-term (STO) case under
# :- if(current_logtalk_flag(coinduction, supported)), not a cut barrier -- leaves the graded population and is named
# on the grader's board as GUARDED OUT; its debt stays on the rational-trees row. The 13 that remain pass in m3 and m4.
floor findall_3 13
floor if_3 12
echo "$GATE_NAME: arms=$total red=$red modes=$MODES"
[ "$red" -eq 0 ] || { echo "⛔ $GATE_NAME RED"; exit 1; }
echo "✅ $GATE_NAME GREEN"
