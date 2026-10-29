#!/usr/bin/env bash
# THE THIRD FACE OF THE UNBOUNDED/BOUNDED CONTRADICTION, found while curing the second (cto 2026-09-13,
# f0cb8f140 deleted the max_integer and min_integer FLAGS). `X is max_integer` still answers
# 9223372036854775807 and `X is min_integer` answers -9223372036854775808 -- a ceiling this implementation
# no longer has, published through a different mechanism than the flag table: pl_arith_names.h maps the two
# names to the maxi/mini arms of the arity-0 evaluable dispatch.
#
# ⭐ NEITHER NAME IS AN ISO EVALUABLE FUNCTOR. ISO 9.1.3 enumerates the evaluable functors and neither
# appears; the oracle agrees and is the discriminator -- swipl raises
# type_error(evaluable, max_integer/0), and our own engine ALREADY raises exactly that shape for an
# unknown name (`X is foo` gives type_error(evaluable, foo/0) here today), so the cured answer is a
# deletion and not a new error path.
#
# ⛔ WHAT THIS GATE MUST NOT DO IS PASS BY ACCIDENT. It demands the ERROR TERM, not merely a failure or
# a non-answer: a witness that merely failed would also be printed by an engine that cannot evaluate
# anything at all. The control arm is `X is foo`, which must keep raising type_error(evaluable, foo/0)
# in the same run -- if the control goes quiet the witness proves nothing about these two names.
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
[ -x ./scrip ] || { echo "⛔ REFUSE(2): ./scrip not built -- run make" >&2; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.pl" <<'EOF'
:- initialization(main).
t(N, G) :- catch(( G -> write(N-answered) ; write(N-failed) ), error(type_error(evaluable, F/A), _),
                 write(N-type_error(F/A))), nl.
main :- t(control, (_ is foo)), t(maxi, (_ is max_integer)), t(mini, (_ is min_integer)).
EOF
rc=0
for m in 3 4; do
  if [ "$m" = 3 ]; then out="$(timeout -k 5 20 ./scrip "$W/w.pl" </dev/null 2>&1)"; else
    timeout -k 5 20 ./scrip --compile --out="$W/w.s" "$W/w.pl" </dev/null >"$W/c.log" 2>&1 || { echo "⛔ m$m: compile failed"; cat "$W/c.log"; rc=1; continue; }
    gcc -no-pie "$W/w.s" -Lout -lscrip_rt -Wl,-rpath,"$PWD/out" -lm -lpthread -o "$W/w.bin" >>"$W/c.log" 2>&1 || { echo "⛔ m$m: link failed"; cat "$W/c.log"; rc=1; continue; }
    out="$(timeout -k 5 20 "$W/w.bin" </dev/null 2>&1)"; fi
  ctl="$(printf '%s\n' "$out" | sed -n 's/^control-//p')"
  mx="$(printf '%s\n'  "$out" | sed -n 's/^maxi-//p')"
  mn="$(printf '%s\n'  "$out" | sed -n 's/^mini-//p')"
  [ -n "$ctl" ] && [ -n "$mx" ] && [ -n "$mn" ] || { echo "⛔ REFUSE(2): m$m witness did not answer all three lines; out=[$out]" >&2; exit 2; }
  [ "$ctl" = "type_error(foo/0)" ] || { echo "⛔ REFUSE(2): m$m control arm reads [$ctl], not type_error(foo/0) -- the witness cannot speak about the other two" >&2; exit 2; }
  for pair in "maxi:$mx:max_integer" "mini:$mn:min_integer"; do
    nm="${pair%%:*}"; rest="${pair#*:}"; got="${rest%%:*}"; want="type_error(${rest#*:}/0)"
    if [ "$got" = "$want" ]; then echo "✅ m$m $nm: $want"
    else echo "⛔ m$m $nm reads $got, want $want -- ISO 9.1.3 has no such evaluable functor and this engine is unbounded"; rc=1; fi
  done
done
[ "$rc" = 0 ] && echo "GATE GREEN" || echo "GATE RED"
exit $rc
