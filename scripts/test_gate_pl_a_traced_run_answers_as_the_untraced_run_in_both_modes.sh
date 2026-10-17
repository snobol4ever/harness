#!/usr/bin/env bash
# test_gate_pl_a_traced_run_answers_as_the_untraced_run_in_both_modes.sh -- THE PORT TRACE IS AN OBSERVER: A TRACED RUN ANSWERS AS THE UNTRACED RUN.
# hq_prolog 2026-10-04, row prolog-bb-the-mode-4-port-trace-instrument-emits-from-the-block-protocol-call-road-not-the-staged-road-the-compiler-no-longer-takes
# (CEO-1502). MEASURED on origin 351fa1dc9: the choice-words landing (35ed4e649) gave x86_pl_disj_open the internal labels 240/241 in the
# disjunction, to and bound boxes, and the trace road defines a 240 of its own in the same box when SCRIP_PL_TRACE=1 -- mode 4's assembler
# refused the duplicate (`symbol .Ldisjunction_α_23_240 is already defined`, so the oracle-diff gate read ZERO call_proc_staged lines and
# refused rc=2), and MODE 3 SILENTLY WIRED THE WRONG LANDING: the traced canary printed red green blue red green blue blue blue ... until
# the timeout where the untraced run prints red green blue. Cure: the opener's labels are 226/227. This gate keeps the observer honest:
# for three witnesses (a backtracking disjunction, a negation and a findall, a bounded if-then-else chain) the traced run's stdout equals
# the untraced run's stdout in m3 and m4, the traced mode-4 text assembles, and the trace names the user predicates' call boxes.
# RED BEFORE on origin 351fa1dc9: w_disj m3 traced diverges (the loop), w_disj m4 traced does not assemble.
set -u
GATE_NAME=test_gate_pl_a_traced_run_answers_as_the_untraced_run_in_both_modes
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
red=0
mkw() { cat > "$TMPD/$1.pl"; }
mkw w_disj <<'EOP'
color(red).
color(green).
color(blue).
main :- color(C), write(C), nl, fail ; true.
:- initialization(main).
EOP
mkw w_neg <<'EOP'
p(1). p(2). p(3).
q(2).
main :- findall(X, (p(X), \+ q(X)), L), write(L), nl, ( \+ p(4) -> write(none) ; write(some) ), nl, forall(p(Y), (Y > 0)), write(all), nl.
:- initialization(main).
EOP
mkw w_ite <<'EOP'
cls(X, small) :- X < 10, !.
cls(X, mid) :- X < 100, !.
cls(_, big).
main :- ( cls(5, A), A == small -> write(a) ; write(b) ), nl, ( member(Z, [1, 2, 3]), Z > 1 -> write(Z) ; write(no) ), nl, findall(K, (member(N, [3, 50, 500]), cls(N, K)), Ks), write(Ks), nl.
:- initialization(main).
EOP
for w in w_disj w_neg w_ite; do
    plain3="$(cd "$TMPD" && timeout -k 5 30 "$SCRIP" "$w.pl" </dev/null 2>/dev/null)"; rc3=$?
    traced3="$(cd "$TMPD" && SCRIP_PL_TRACE=1 timeout -k 5 30 "$SCRIP" "$w.pl" </dev/null 2>"$TMPD/$w.m3.trace")"; rct3=$?
    if [ "$rc3" = 0 ] && [ "$rct3" = 0 ] && [ "$plain3" = "$traced3" ] && grep -q '_call_proc_staged ' "$TMPD/$w.m3.trace"; then echo "  ok  $w m3: traced == untraced, the trace names the call boxes"
    else echo "  RED $w m3: plain rc=$rc3 [$(printf '%s' "$plain3" | tr '\n' '|' | cut -c1-60)] traced rc=$rct3 [$(printf '%s' "$traced3" | tr '\n' '|' | cut -c1-60)] call_proc_staged lines=$(grep -c '_call_proc_staged ' "$TMPD/$w.m3.trace")"; red=$((red+1)); fi
    timeout -k 5 120 "$SCRIP" --compile -o "$TMPD/$w.s" "$TMPD/$w.pl" </dev/null 2>/dev/null && gcc -m64 -no-pie "$TMPD/$w.s" -o "$TMPD/$w.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>/dev/null || { echo "  RED $w m4: the untraced compile or link refused"; red=$((red+1)); continue; }
    plain4="$(cd "$TMPD" && timeout -k 5 30 "./$w.bin" </dev/null 2>/dev/null)"; rc4=$?
    if ! SCRIP_PL_TRACE=1 timeout -k 5 120 "$SCRIP" --compile -o "$TMPD/$w.t.s" "$TMPD/$w.pl" </dev/null 2>"$TMPD/err"; then echo "  RED $w m4: the traced compile refused: $(head -c 160 "$TMPD/err")"; red=$((red+1)); continue; fi
    if ! gcc -m64 -no-pie "$TMPD/$w.t.s" -o "$TMPD/$w.t.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err"; then echo "  RED $w m4: the traced text does not assemble: $(grep -m1 -E 'Error|error' "$TMPD/err" | head -c 200)"; red=$((red+1)); continue; fi
    traced4="$(cd "$TMPD" && SCRIP_PL_TRACE=1 timeout -k 5 30 "./$w.t.bin" </dev/null 2>"$TMPD/$w.m4.trace")"; rct4=$?
    if [ "$rc4" = 0 ] && [ "$rct4" = 0 ] && [ "$plain4" = "$traced4" ] && [ "$plain4" = "$plain3" ] && grep -q '_call_proc_staged ' "$TMPD/$w.m4.trace"; then echo "  ok  $w m4: traced == untraced == m3, the trace names the call boxes"
    else echo "  RED $w m4: plain rc=$rc4 [$(printf '%s' "$plain4" | tr '\n' '|' | cut -c1-60)] traced rc=$rct4 [$(printf '%s' "$traced4" | tr '\n' '|' | cut -c1-60)] call_proc_staged lines=$(grep -c '_call_proc_staged ' "$TMPD/$w.m4.trace")"; red=$((red+1)); fi
done
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red arm(s) red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: three traced runs answer as their untraced runs in m3 and m4, the traced mode-4 text assembles, and the trace names the user predicates' call boxes"
exit 0
