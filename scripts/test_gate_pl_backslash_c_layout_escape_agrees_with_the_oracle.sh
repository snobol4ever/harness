#!/usr/bin/env bash
# The Edinburgh/SWI layout-skip escape \c inside a quoted atom or a double-quoted token: the backslash and EVERY
# layout character after it produce nothing, so a long quoted string may be continued across a line break. ISO/IEC
# 13211-1 6.4.2.1 names only backslash-newline as the continuation escape, so \c is an EXTENSION -- but no case in
# logtalk_iso, inriasuite, gnu_prolog or gnu_fd contains one (censused hq_C 2026-09-13), while ten shipped swi_tests
# files do, and the swi suite grades by AGREEMENT WITH SWIPL. Rejecting \c cost three whole files at load time
# (queue_gc 0/8, test_yall 0/42, test_syntax 0/38) with no ISO case bought in exchange.
# ⛔ THE EXPECTATION IS CUT FROM THE ORACLE AT RUN TIME, never from our own output: this gate runs swipl on its own
# witness and requires scrip to print the SAME BYTES in m3 and m4. Its last arm is the control in the other
# direction -- an escape the oracle REFUSES (\q) must still be a lex error here, so a cure for \c cannot pass by
# accepting every unknown escape, which is the failure this gate exists to catch.
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
[ -x ./scrip ] || { echo "⛔ REFUSE(2): ./scrip not built -- run make" >&2; exit 2; }
SWIPL=/usr/bin/swipl
[ -x "$SWIPL" ] || { echo "⛔ REFUSE(2): no oracle at $SWIPL -- this gate cuts its expectation from swipl, it cannot assert without one" >&2; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.pl" <<'EOF'
:- initialization(main).
main :- X = '\c ', write(empty(X)), nl,
        Y = 'x\c y', write(inline(Y)), nl,
        Z = 'a\c
             b', write(across_lines(Z)), nl,
        W = 'p\c	q', write(across_tab(W)), nl,
        V = "d\c q", atom_string(A, V), write(double_quoted(A)), nl.
EOF
exp="$(timeout -k 5 30 "$SWIPL" -q -g halt "$W/w.pl" 2>/dev/null)"
[ -n "$exp" ] || { echo "⛔ REFUSE(2): the oracle printed nothing for the witness -- measured nothing, not a verdict" >&2; exit 2; }
rc=0
for m in 3 4; do
  if [ "$m" = 3 ]; then got="$(timeout -k 5 20 ./scrip "$W/w.pl" </dev/null 2>&1)"; else
    timeout -k 5 60 ./scrip --compile --out="$W/w.s" "$W/w.pl" </dev/null >"$W/c.log" 2>&1 || { echo "⛔ m$m: compile failed"; cat "$W/c.log"; rc=1; continue; }
    gcc -no-pie "$W/w.s" -Lout -lscrip_rt -Wl,-rpath,"$PWD/out" -lm -lpthread -o "$W/w.bin" >>"$W/c.log" 2>&1 || { echo "⛔ m$m: link failed"; cat "$W/c.log"; rc=1; continue; }
    got="$(timeout -k 5 20 "$W/w.bin" </dev/null 2>&1)"; fi
  if [ "$got" = "$exp" ]; then echo "✅ m$m agrees with the oracle on \\c, all five forms"
  else echo "⛔ m$m disagrees with the oracle on \\c"; diff <(printf '%s\n' "$exp") <(printf '%s\n' "$got") | sed 's/^/       /'; rc=1; fi
done
cat > "$W/bad.pl" <<'EOF'
:- initialization(main).
main :- X = 'a\q b', write(accepted(X)), nl.
EOF
if timeout -k 5 20 ./scrip "$W/bad.pl" </dev/null 2>&1 | grep -q '^accepted('; then
  echo "⛔ control arm: '\\q' was ACCEPTED -- the oracle refuses it (Unknown character escape), so \\c must be an arm of its own and never a blanket pass for unknown escapes"; rc=1
else echo "✅ control arm: '\\q' still refused, as the oracle refuses it"; fi
[ "$rc" = 0 ] && echo "GATE GREEN" || echo "GATE RED"
exit $rc
