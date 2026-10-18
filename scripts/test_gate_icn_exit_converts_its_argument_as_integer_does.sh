#!/usr/bin/env bash
# test_gate_icn_exit_converts_its_argument_as_integer_does.sh -- hq_icon, 2026-10-01 (the coo's red, found regenerating the
# Arizona container under CEO-1392, which grades rc: arizona_tests/general/checkc.icn line 187, exit(abs(3.0)), iconx rc 3).
#
# WHAT WAS THERE. by_name_dispatch.c took exit's status only from an INTEGER argument and exited 0 for anything else, so
# exit(3.0), exit(abs(3.0)) and exit("3") exited 0 where iconx exits 3, and exit("x") exited 0 where iconx raises error 101.
# The Arizona board grades text only and read checkc PASS. exit now converts as integer() does (core_icn_to_int_d): &null or
# no argument is 0, a real truncates, a numeric string converts, anything else is error 101; the status is taken mod 256.
#
# ARM. Each case is a three-line program writing "before", calling exit, writing "after". iconx gives each its stdout and
# exit status at run time (a missing oracle refuses the gate); SCRIP must give the same status and stdout in both media.
# RED on the parent 149cfdf16: every non-integer case exited 0.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
ICONT="$(icont_bin)" || { echo "⛔ GATE REFUSE(2) [$G]: the Icon oracle is missing"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
fail=0; n=0; nonzero=0
for call in 'exit(3)' 'exit(3.0)' 'exit(abs(3.0))' 'exit("3")' 'exit(3.9)' 'exit(" 7 ")' 'exit()' 'exit(&null)' 'exit("x")' 'exit(300)'; do
  n=$((n+1)); d="$T/c$n"; mkdir -p "$d"
  printf 'procedure main();\n   write("before");\n   %s;\n   write("after");\nend\n' "$call" > "$d/e.icn"
  ( cd "$d" && "$ICONT" -s -o e.x e.icn ) >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: icont refuses the $call witness"; exit 2; }
  ( cd "$d" && ./e.x </dev/null > want 2>/dev/null ); wrc=$?
  [ "$wrc" -ne 0 ] && nonzero=$((nonzero+1))
  ( cd "$d" && timeout -k 5 30 "$SCRIP" e.icn </dev/null > m3 2>/dev/null ); r3=$?
  ( cd "$d" && timeout -k 5 60 "$SCRIP" --compile -o e.s e.icn </dev/null >/dev/null 2>&1 && gcc -no-pie -o e.4 e.s -L"$ROOT/out" -lscrip_rt -lm -lstdc++ -lpthread -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ) \
    || { echo "⛔ GATE REFUSE(2) [$G]: mode-4 build of the $call witness failed -- cannot measure"; exit 2; }
  ( cd "$d" && timeout -k 5 30 ./e.4 </dev/null > m4 2>/dev/null ); r4=$?
  if [ "$r3" = "$wrc" ] && [ "$r4" = "$wrc" ] && cmp -s "$d/m3" "$d/want" && cmp -s "$d/m4" "$d/want"; then echo "  PASS $call: rc $wrc in both media, stdout as iconx's"
  else echo "  FAIL $call: iconx rc $wrc, m3 rc $r3, m4 rc $r4"; fail=1; fi
done
[ "$nonzero" -ge 6 ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle gave only $nonzero nonzero statuses -- the witnesses no longer discriminate"; exit 2; }
[ $fail = 0 ] && { echo "✅ GATE PASS [$G]: exit converts its argument as integer() does, $n cases, both media"; exit 0; }
echo "⛔ GATE FAIL [$G]"; exit 1
