#!/usr/bin/env bash
# ONE MALFORMED CLAUSE MUST COST ITS OWN CLAUSE AND NOTHING ELSE (cto 2026-09-13, routed from the coo's
# prolog group board 62bad32d9). The swi suite lost 82 cases to hq_C's quoted-token tightening 077a4e9dd, and
# the SHAPE of the loss is what this gate is about: test_yall 0 of 42, test_syntax 0 of 38, test_answer 0 of
# 14, queue_gc 0 of 8 -- four WHOLE FILES, not eighty-one cases that use the construct. One offending token
# anywhere in a file aborts the file, so the other forty-one cases in it are never read, never run, and never
# counted. THE TIGHTENING WAS RIGHT AND ITS BLAST RADIUS IS THE DEFECT: until a syntax error is local, the
# cost of every correct lexer tightening is measured in whole files, which is an argument against making the
# reader more correct.
#
# ⭐ THE ORACLE IS THE DISCRIMINATOR AND IT IS NOT CLOSE. On the identical four-clause witness, swipl -q
# prints ONE syntax error naming line 2 and then answers p(one) / q(two) / r(three); we print THREE parse
# errors -- one real and two cascaded from a reader that never resynchronised -- and answer nothing at all,
# because the file is abandoned before any clause reaches the database.
#
# ⛔ THE m4 ARM DELETES ITS OWN ARTIFACTS BEFORE EACH COMPILE, AND THAT IS NOT HYGIENE, IT IS THE VERDICT.
# Without the rm, a subject compile that REFUSES leaves the CONTROL arm's .s and binary in place, the gate
# links and runs those instead, and the subject arm reports three answers from a program it never built --
# which is exactly what this gate did on its first red run, reading m4 answers=3 for a tree where mode 4
# produced nothing at all. A stale artifact under a refusing compile is indistinguishable from success.
#
# ⛔ WHAT IS COUNTED IS THE PER-SITE DIAGNOSTIC -- a line carrying a source line number and `parse error` or
# `lex error` -- and NOT the driver's one-line summary of how many there were. Counting both was this gate's
# own first reading and it made a correct cure read as 2 want 1. In mode 4 the diagnostics are emitted at
# COMPILE time and the answers at RUN time, so the arm grades the compile log and the program output
# CONCATENATED; grading only what the binary printed made the m4 subject arm read 0 diagnostics for a file
# that had just reported one -- the same instrument failure from the opposite side.
#
# ⛔ THE ERROR COUNT IS GRADED, NOT JUST THE ANSWERS, and that is deliberate: a reader could be made to
# limp to the end of the file while emitting a cascade of invented errors, which would answer all three and
# still leave every diagnostic after the first one useless. One bad clause, one diagnostic, naming its line.
# THE CONTROL ARM IS A CLEAN FILE that must load with ZERO diagnostics and all three answers -- if it ever
# goes quiet, the subject arm proves nothing, since a reader that reports nothing and runs nothing would
# otherwise look like progress.
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
[ -x ./scrip ] || { echo "⛔ REFUSE(2): ./scrip not built -- run make" >&2; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/body.pl" <<'EOF'
a2(two).
a3(three).
:- initialization(( ( catch(a1(P), _, fail) -> write(p(P)) ; write(no_a1) ), nl,
                    ( catch(a2(Q), _, fail) -> write(q(Q)) ; write(no_a2) ), nl,
                    ( catch(a3(R), _, fail) -> write(r(R)) ; write(no_a3) ), nl )).
EOF
{ echo 'a1(one).'; echo 'bad(X :- .'; cat "$W/body.pl"; } > "$W/subject.pl"
{ echo 'a1(one).'; echo 'ok(zero).';  cat "$W/body.pl"; } > "$W/control.pl"
rc=0
for m in 3 4; do
  for arm in control subject; do
    src="$W/$arm.pl"
    if [ "$m" = 3 ]; then out="$(timeout -k 5 20 ./scrip "$src" </dev/null 2>&1)"; else
      rm -f "$W/a.s" "$W/a.bin"
      timeout -k 5 20 ./scrip --compile -o "$W/a.s" "$src" </dev/null >"$W/c.log" 2>&1
      if [ -s "$W/a.s" ] && gcc -no-pie "$W/a.s" -Lout -lscrip_rt -Wl,-rpath,"$PWD/out" -lm -lpthread -o "$W/a.bin" >>"$W/c.log" 2>&1
      then out="$(cat "$W/c.log"; timeout -k 5 20 "$W/a.bin" </dev/null 2>&1)"
      else out="$(cat "$W/c.log")"; fi
    fi
    ans="$(printf '%s\n' "$out" | grep -c '^[pqr](\(one\|two\|three\))$')"
    errs="$(printf '%s\n' "$out" | grep -c ':[0-9][0-9]*: \(parse\|lex\) error')"
    if [ "$arm" = control ]; then
      if [ "$ans" = 3 ] && [ "$errs" = 0 ]; then echo "✅ m$m control: 3 answers, 0 diagnostics"
      else echo "⛔ REFUSE(2): m$m control arm reads answers=$ans diagnostics=$errs, want 3 and 0 -- the subject arm cannot speak; out=[$out]" >&2; exit 2; fi
    else
      if [ "$ans" = 3 ] && [ "$errs" = 1 ]; then echo "✅ m$m subject: 3 answers survive, exactly 1 diagnostic"
      else echo "⛔ m$m subject: answers=$ans (want 3) diagnostics=$errs (want 1) -- one malformed clause cost more than itself"; rc=1; fi
    fi
  done
done
[ "$rc" = 0 ] && echo "GATE GREEN" || echo "GATE RED"
exit $rc
