#!/usr/bin/env bash
export S4E_MINT_NO_CRITERION="gate fixture: the row under test exercises the bus, not work (CEO-1386)"
# test_gate_pl_print_1_honours_portray_and_costs_nothing_without_it.sh
# Row prolog-logtalk-write-term-print-and-write-canonical-family (hq_R, CEO-650); design approved by the
# cto 2026-09-13: the LOWERER MINTS A WRAPPER CLAUSE and the existing goal dispatch finds it -- no new goal
# machinery, no runtime-to-Prolog callback.
#
# print/1 is ( portray(X) -> true ; write(X) ), MINTED ONLY WHEN THE PROGRAM DEFINES portray/1. Otherwise
# print/1 stays the $write det leaf it is today (GNU Prolog is canonical for print/1's own quoting, Lon's
# word, SCRIP af74eb56e -- print/1 was $writeq at this gate's mint and moved to $write afterward; this gate
# is updated to the current, oracle-verified baseline rather than the compiler reverted to satisfy a stale
# gate, per CEO-589).
#
# ⛔⭐ ARM 1 IS THE POINT AND IT RUNS FIRST, BY ORDER, NOT BY CONVENTION. The cure's whole claim is that a
# program WITHOUT portray/1 pays nothing -- no proc, no dispatch, no emitted byte. That claim is easy to
# fake by measuring it after the fact, so the no-portray emission and stdout are captured BEFORE any
# portray-defining program is compiled in this script.
#
# ⛔⭐ ARM 1 WAS A PINNED WHOLE-EMISSION md5 AND THAT WAS A DEFECT OF MINE, NOW DELETED (hq_R 2026-09-13, on
# hq_U's report). RULES.md says .s byte-identity must never be wired into a gate, and this is exactly why:
# hq_U landed CEO-684 slice 1, which shrinks every activation frame by one 16-byte slot per call node, so
# every offset in the file moved and the pin necessarily reddened -- on a CORRECT landing, for a reason
# having nothing to do with portray. hq_U told me rather than bumping the constant, which is the right call:
# re-pinning another seat's constant is how a pin stops meaning anything. A second such landing (the
# cto's Lon-ordered IR_MOVE_LABEL delete) was already queued behind it.
#
# ⭐ THE CURE IS TO STATE THE CLAIM DIFFERENTIALLY, IN ONE BUILD, SO NO CONSTANT EXISTS TO GO STALE. The
# claim is not "this program emits these bytes"; it is "with no portray/1, print/1 IS the write det leaf".
# So emit the SAME program twice in the SAME build -- once written with print/1, once with write/1 -- and
# require the two path-normalised emissions to be IDENTICAL TO EACH OTHER. That is immune to every future
# emitter change by construction, because both sides move together. ARM 1c is its control and it is what
# gives the comparison teeth: with portray/1 DEFINED the same two programs must DIFFER, so a comparison
# that trivially passes (say both emissions empty, or the normaliser eating the difference) is caught.
# Arm 1b keeps the narrower claim: a program with no portray/1 mentions portray NOWHERE in its emission.
# ⛔ It deliberately does NOT grep for "print/1": that string is a startup predicate-name the compiler
# emitted long before this cure, so grepping it convicts the pre-cure compiler too -- an arm that reds on a
# clean tree is measuring the wrong thing.
#
# rc 0 green · 1 red · 2 could not measure.  Self-contained; run from anywhere.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; cd "$ROOT"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
D=$(mktemp -d) || { echo "⛔ REFUSE(2): no tmpdir"; exit 2; }
trap 'rm -rf "$D"' EXIT
PASS=0; FAIL=0; N=0
cat > "$D/noportray.pl" <<'PLEOF'
:- initialization(main).
main :- print(42), nl, print(foo), nl, print(a(b)), nl, print([1,2]), nl.
PLEOF
echo "=== ARM 1 (FIRST, and the one that can be faked by running it last): no portray/1 costs nothing ==="
sed 's/print(/write(/g' "$D/noportray.pl" > "$D/nowrite.pl"
gate_emit_md5() {   # $1 = .pl to compile, $2 = .s to write -- path- AND basename-normalised, so only CODE differs
  # Every program is compiled from ONE path, $D/prog.pl (cfo 2026-10-17, row prolog-gnu-semantics-leak-...-ceo-1810): the emission
  # carries the source path as .byte data in the atom table (a predicate's file/line properties), which the sed below cannot rewrite,
  # so two different file names made two equal programs differ by their name alone.
  cp "$1" "$D/prog.pl" || return 1
  timeout -k 5 60 "$SCRIP" --compile -o "$2" "$D/prog.pl" >/dev/null 2>&1 || return 1
  sed "s|$D|@|g; s|noportray|@PROG@|g; s|nowrite|@PROG@|g; s|yesportray|@PROG@|g; s|yeswrite|@PROG@|g" "$2" | md5sum | cut -d' ' -f1
}
N=$((N+1))
mp=$(gate_emit_md5 "$D/noportray.pl" "$D/np.s"); rcp=$?
mq=$(gate_emit_md5 "$D/nowrite.pl"  "$D/nq.s"); rcq=$?
if [ $rcp -ne 0 ] || [ $rcq -ne 0 ]; then
  echo "  RED  a no-portray program failed to compile (print rc=$rcp write rc=$rcq)"; FAIL=$((FAIL+1))
elif [ -z "$mp" ] || [ -z "$mq" ]; then
  echo "⛔ REFUSE(2): an emission md5 came back EMPTY, so arm 1 graded nothing -- a comparison of two blanks is not a pass"; exit 2
elif [ "$mp" = "$mq" ]; then PASS=$((PASS+1))
else
  echo "  RED  with NO portray/1 defined, print/1 did not emit identically to write/1, so the cure is not free:"
  echo "       print md5 $mp  vs  write md5 $mq"
  diff <(sed "s|$D|@|g; s|noportray|@PROG@|g" "$D/np.s") <(sed "s|$D|@|g; s|nowrite|@PROG@|g" "$D/nq.s") | head -12 | sed 's/^/       /'
  FAIL=$((FAIL+1))
fi
N=$((N+1))
cat > "$D/yesportray.pl" <<'PLEOF'
portray(A) :- atom(A), write(A), write(A).
:- initialization(main).
main :- print(42), nl, print(foo), nl, print(a(b)), nl, print([1,2]), nl.
PLEOF
sed 's/print(/write(/g' "$D/yesportray.pl" > "$D/yeswrite.pl"
yp=$(gate_emit_md5 "$D/yesportray.pl" "$D/yp.s"); yq=$(gate_emit_md5 "$D/yeswrite.pl" "$D/yq.s")
if [ -n "$yp" ] && [ -n "$yq" ] && [ "$yp" != "$yq" ]; then PASS=$((PASS+1))
else echo "  RED  ARM 1c CONTROL: with portray/1 DEFINED, print/1 emitted the SAME as write/1 ($yp vs $yq) -- so arm 1's comparison has no teeth and its pass means nothing"; FAIL=$((FAIL+1)); fi
N=$((N+1))
if grep -qE '(^|[^A-Za-z0-9_])portray([^A-Za-z0-9_]|$)' "$D/np.s" 2>/dev/null; then
  echo "  RED  a program with no portray/1 emitted a reference to portray"; FAIL=$((FAIL+1))
else PASS=$((PASS+1)); fi
N=$((N+1))
got=$(timeout -k 5 20 "$SCRIP" "$D/noportray.pl" </dev/null 2>&1)
want=$'42\nfoo\na(b)\n[1,2]'
if [ "$got" = "$want" ]; then PASS=$((PASS+1)); else printf '  RED  no-portray stdout changed: got [%s] want [%s]\n' "$got" "$want"; FAIL=$((FAIL+1)); fi
echo "=== ARM 2: with portray/1 defined, print/1 consults it -- both modes ==="
cat > "$D/portray.pl" <<'PLEOF'
portray(A) :- atom(A), write(A), write(A).
portray(F) :- float(F), I is truncate(F), write(I).
:- initialization(main).
main :- print(42), nl, print(3.14), nl, print(foo), nl, halt.
PLEOF
want2=$'42\n3\nfoofoo'
N=$((N+1))
got=$(timeout -k 5 20 "$SCRIP" "$D/portray.pl" </dev/null 2>/dev/null)
if [ "$got" = "$want2" ]; then PASS=$((PASS+1)); else printf '  m3 RED  portray goal: got [%s] want [%s]\n' "$got" "$want2"; FAIL=$((FAIL+1)); fi
N=$((N+1))
if timeout -k 5 60 "$SCRIP" --compile -o "$D/p.s" "$D/portray.pl" >/dev/null 2>&1 \
   && gcc -m64 -no-pie "$D/p.s" -o "$D/p.bin" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm >/dev/null 2>&1; then
  got=$(timeout -k 5 20 "$D/p.bin" 2>/dev/null)
  if [ "$got" = "$want2" ]; then PASS=$((PASS+1)); else printf '  m4 RED  portray goal: got [%s] want [%s]\n' "$got" "$want2"; FAIL=$((FAIL+1)); fi
else echo "  m4 RED  portray program failed to compile or link"; FAIL=$((FAIL+1)); fi
echo "=== ARM 3: a program that defines its OWN print/1 keeps it -- the wrapper never shadows the user ==="
cat > "$D/ownprint.pl" <<'PLEOF'
portray(A) :- atom(A), write(A), write(A).
print(X) :- write(mine(X)).
:- initialization(main).
main :- print(foo), nl, halt.
PLEOF
N=$((N+1))
got=$(timeout -k 5 20 "$SCRIP" "$D/ownprint.pl" </dev/null 2>/dev/null)
if [ "$got" = "mine(foo)" ]; then PASS=$((PASS+1)); else printf '  RED  user print/1 was shadowed: got [%s] want [mine(foo)]\n' "$got"; FAIL=$((FAIL+1)); fi
echo "=== ARM 4: format ~p consults portray, and operator and list notation SURVIVE the hook -- both modes ==="
cat > "$D/fp.pl" <<'PLEOF'
:- dynamic(portray/1).
portray(Atom) :- atom(Atom), write(Atom), write(Atom).
portray(Float) :- float(Float), Integer is truncate(Float), write(Integer).
:- initialization(main).
main :- format("[~p]~n", [3.14]), format("[~p]~n", [foo]), format("[~p]~n", [a(foo)]),
	format("[~p]~n", [a(foo,b(c(foo,3.14)))]), format("[~p]~n", [[foo,3.14]]), format("[~p]~n", [1+foo]), halt.
PLEOF
want4='[3]
[foofoo]
[a(foofoo)]
[a(foofoo,b(c(foofoo,3)))]
[[foofoo,3]]
[1+foofoo]'
N=$((N+1))
got=$(cd "$D" && timeout -k 5 20 "$SCRIP" "$D/fp.pl" </dev/null 2>/dev/null)
if [ "$got" = "$want4" ]; then PASS=$((PASS+1)); else printf '  m3 RED  format ~~p: got [%s]\n       want [%s]\n' "$got" "$want4"; FAIL=$((FAIL+1)); fi
N=$((N+1))
if (cd "$D" && timeout -k 5 60 "$SCRIP" --compile -o "$D/fp.s" "$D/fp.pl" >/dev/null 2>&1) && gcc -m64 -no-pie "$D/fp.s" -o "$D/fp.bin" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm >/dev/null 2>&1; then
  got=$(cd "$D" && timeout -k 5 20 "$D/fp.bin" 2>/dev/null)
  if [ "$got" = "$want4" ]; then PASS=$((PASS+1)); else printf '  m4 RED  format ~~p: got [%s]\n       want [%s]\n' "$got" "$want4"; FAIL=$((FAIL+1)); fi
else echo "  m4 RED  the ~~p program failed to compile or link"; FAIL=$((FAIL+1)); fi
echo "=== ARM 7: A COLLECTING portray/1 -- the hook allocates enough to collect several times inside ONE print, and every level re-reads its cell (the cfo's arm) -- both modes ==="
cat > "$D/fc.pl" <<'PLEOF'
:- initialization(main).
portray(x) :- numlist(1, 20000, L), sum_list(L, S), S > 0, write(xx).
main :- T = f(x, g(x, h(x)), k(x, x), x), format("~p~n", [T]), format("~p ~w ~p~n", [g(x), x, f(x, x)]),
        L = [x, f(x), x], format("~p~n", [L]), length(L, N), write(N), nl.
PLEOF
want7='f(xx,g(xx,h(xx)),k(xx,xx),xx)
g(xx) x f(xx,xx)
[xx,f(xx),xx]
3'
echo "=== ARM 8: A NESTED print INSIDE portray/1 -- the inner write's slots stack above the outer's and are popped before the outer re-reads (the cfo's arm) -- both modes ==="
cat > "$D/fn.pl" <<'PLEOF'
:- initialization(main).
portray(p(X)) :- format("<~p>", [X]).
portray(x) :- numlist(1, 5000, L), length(L, _), write(ex).
main :- format("~p~n", [f(p(x), p(g(x, p(x))), x)]), format("~p|~p~n", [p(p(x)), q(x)]).
PLEOF
want8='f(<ex>,<g(ex,<ex>)>,ex)
<<ex>>|q(ex)'
for a in fc:want7 fn:want8; do w=${a%%:*}; eval "want=\$${a#*:}"
  N=$((N+1)); got=$(cd "$D" && timeout -k 5 60 "$SCRIP" "$D/$w.pl" </dev/null 2>/dev/null)
  if [ "$got" = "$want" ]; then PASS=$((PASS+1)); else printf '  m3 RED  %s: got [%s]\n       want [%s]\n' "$w" "$got" "$want"; FAIL=$((FAIL+1)); fi
  N=$((N+1))
  if (cd "$D" && timeout -k 5 60 "$SCRIP" --compile -o "$D/$w.s" "$D/$w.pl" >/dev/null 2>&1) && gcc -m64 -no-pie "$D/$w.s" -o "$D/$w.bin" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm >/dev/null 2>&1; then
    got=$(cd "$D" && timeout -k 5 60 "$D/$w.bin" </dev/null 2>/dev/null)
    if [ "$got" = "$want" ]; then PASS=$((PASS+1)); else printf '  m4 RED  %s: got [%s]\n       want [%s]\n' "$w" "$got" "$want"; FAIL=$((FAIL+1)); fi
  else printf '  m4 RED  %s failed to compile or link\n' "$w"; FAIL=$((FAIL+1)); fi
done
echo "=== ARM 6: A THROWING portray/1 -- print/1 PROPAGATES, and format ~p's swallow is NAMED, not hidden ==="
cat > "$D/thr.pl" <<'PLEOF'
:- dynamic(portray/1).
portray(_) :- throw(portray_fired).
:- initialization(main).
main :- catch(print(baz(3)), E, (write(caught_print(E)), nl)),
	catch(format("~p", [qux(4)]), E2, (write(caught_format(E2)), nl)), halt.
PLEOF
N=$((N+1))
got=$(cd "$D" && timeout -k 5 20 "$SCRIP" "$D/thr.pl" </dev/null 2>&1)
case "$got" in
    caught_print\(portray_fired\)*) PASS=$((PASS+1)) ;;
    *) printf '  RED  a throwing portray/1 did not propagate through print/1: got [%s]\n' "$got"; FAIL=$((FAIL+1)) ;;
esac
# ⭐ THE GAP THIS ARM USED TO PIN IS CLOSED (hq_prolog 2026-09-25, CEO-1270): format("~p", [T]) with a THROWING portray/1 swallowed the
# ball -- plc_portray_hit recorded it in the writer's pthrown slot and plc_fb_term dropped it -- and printed the plain term where swipl raises.
# plc_fb_term now returns the ball and ~p raises it as format's own, so print/1 and print/2 (which now write through ~p) and
# write_term(T, [portray(true)]) all propagate a portray/1 throw, as swipl does (caught_format(portray_fired)).
N=$((N+1))
case "$got" in
    *caught_format\(portray_fired\)*) PASS=$((PASS+1)) ;;
    *qux\(4\)*) echo "  RED  format ~p SWALLOWED a throwing portray/1 and printed the plain term -- swipl raises caught_format(portray_fired)"; FAIL=$((FAIL+1)) ;;
    *) printf '  RED  format ~p with a throwing portray/1 did neither: got [%s]\n' "$got"; FAIL=$((FAIL+1)) ;;
esac
echo "=== ARM 5: THE PORTRAY HOOK RELEASES ITS ACTIVATION FRAME -- a slope, never a total ==="
cat > "$D/slope.pl" <<'PLEOF'
:- dynamic(portray/1).
portray(x) :- write(one).
portray(x) :- write(two).
loop(0) :- !.
loop(N) :- format("~p", [f(x,x,x,x,x)]), nl, M is N-1, loop(M).
:- initialization(main).
main :- loop(LOOPS), write(done), nl, halt.
PLEOF
slope_rss() {
  sed "s/loop(LOOPS)/loop($1)/" "$D/slope.pl" > "$D/s$1.pl"
  /usr/bin/time -f '%M' timeout -k 5 300 "$SCRIP" "$D/s$1.pl" </dev/null >/dev/null 2>"$D/s$1.rss" || { echo ""; return; }
  tail -1 "$D/s$1.rss"
}
N=$((N+1))
lo=$(slope_rss 3000); hi=$(slope_rss 12000)
case "$lo$hi" in
    *[!0-9]*|"") echo "  ⛔ ARM 5 UNPROVEN: could not read maxrss for both runs (lo=[$lo] hi=[$hi]) -- an arm that cannot measure is not an arm that passed"; FAIL=$((FAIL+1)) ;;
    *) kb=$(( (hi - lo) * 100 / 54000 ))
       echo "    slope: $lo kB at 3000 iterations, $hi kB at 12000 -> $((kb / 100)).$(printf '%02d' $((kb % 100))) kB per portray call (54000 calls between the two)"
       if [ "$kb" -le 200 ]; then PASS=$((PASS+1)); else echo "  RED  ARM 5: the portray hook retains its activation frame -- $((kb / 100)).$(printf '%02d' $((kb % 100))) kB per call exceeds the 2.00 kB/call fence"; FAIL=$((FAIL+1)); fi ;;
esac
[ "$N" -gt 0 ] || { echo "⛔ REFUSE(2): graded nothing"; exit 2; }
echo "PL PRINT/PORTRAY: PASS=$PASS FAIL=$FAIL / $N arms  verdict=$([ $FAIL = 0 ] && echo GREEN || echo RED)"
[ "$FAIL" = 0 ] || exit 1
exit 0
