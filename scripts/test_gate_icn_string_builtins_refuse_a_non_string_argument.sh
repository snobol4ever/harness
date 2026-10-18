#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
ICONT="${ICONT_BIN:-/home/resources/icon-master/bin/icont}"; [ -x "$ICONT" ] || { echo "⛔ REFUSE(2): no icont at $ICONT -- the ref is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
CASES=( 'trim(B)' 'map(B)' 'reverse(B)' 'left(B,25)' 'right(B,25)' 'center(B,25)' 'repl(B,2)' 'detab(B)' 'entab(B)'
        'upto("1",B)' 'find("8",B)' 'match("1",B)' 'any("1",B)' 'many("1",B)' 'bal("(",")","(",B)'
        'trim(L)' 'map(L)' 'reverse(L)' 'left(L,3)' 'right(L,3)' 'center(L,3)' 'repl(L,2)' 'detab(L)' 'entab(L)'
        'trim(main)' 'reverse(main)' 'left(main,3)' 'map("ab",L,"cd")' 'left("a",3,L)'
        'trim("ab",L)' 'left("a",L)' 'repl("a",L)' 'detab("a",L)' 'left(L,L)' 'trim(L,L)'
        'any("a",L)' 'many("a",L)' 'match("a",L)' 'bal("a","b","c",L)' 'any("a","abc",L)' 'match("a","abc",L)'
        'trim(12)' 'reverse(3)' 'left(12,4)' 'map(12)' 'trim("ab ")' 'map("abc","ab","xy")' 'left("a",3)' 'repl("ab",2)' 'reverse("abc")'
        'upto("a","abc")' 'any("a","abc")' 'many("a","abc")' 'find("a","abc")' 'match("a","abc")' 'bal("(",")","(","(a)")' 'upto("a","abc",1,3)' 'find("a","abca",2)' )
n103=0; n101=0; n104=0; nok=0
for x in "${CASES[@]}"; do
  printf 'procedure main()\n  L := [1,2]; B := 18446744073709551616;\n  write(%s);\nend\n' "$x" > "$T/w.icn"
  ( cd "$T" && "$ICONT" -s w.icn -x ) >"$T/w.ref" 2>&1
  case "$(sed -n 's/.*Run-time error \([0-9]*\).*/\1/p' "$T/w.ref" | head -1)" in
    103) n103=$((n103+1));; 101) n101=$((n101+1));; 104) n104=$((n104+1));; '') nok=$((nok+1));;
  esac
done
[ "$n103" -ge 16 ] && [ "$n101" -ge 5 ] && [ "$n104" -ge 1 ] && [ "$nok" -ge 30 ] || {
  echo "⛔ REFUSE(2): the oracle's own stream no longer carries all four outcomes this gate exists to tell apart"
  echo "   measured 103=$n103 (want >=12)  101=$n101 (want >=3)  104=$n104 (want >=1)  no-error=$nok (want >=30)"
  echo "   a gate that cannot see a 101, a 104 and a CLEAN conversion (small AND large integers) beside its 103s is satisfiable by a builtin that raises 103 unconditionally"; exit 2; }
RC=0; PASS=0; FAIL=0
for x in "${CASES[@]}"; do
  printf 'procedure main()\n  L := [1,2]; B := 18446744073709551616;\n  write(%s);\nend\n' "$x" > "$T/w.icn"
  ( cd "$T" && "$ICONT" -s w.icn -x ) >"$T/w.ref" 2>&1
  ( cd "$T" && timeout -k 5 20 "$SCRIP" w.icn </dev/null ) >"$T/m3.out" 2>&1
  ( cd "$T" && timeout -k 5 20 "$SCRIP" --compile -o w.s w.icn </dev/null && gcc -m64 -no-pie w.s -o w.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ REFUSE(2): mode-4 witness '$x' did not build"; exit 2; }
  ( cd "$T" && LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 20 ./w.bin </dev/null ) >"$T/m4.out" 2>&1
  for _o in m3 m4; do python3 "$ROOT/../harness/scripts/util_render_error_voice.py" icon < "$T/$_o.out" > "$T/$_o.out.r" && mv "$T/$_o.out.r" "$T/$_o.out"; done
  if [ -n "${FAIL_ONCE:-}" ]; then sed -i 's/^Run-time error 103$/Run-time error 999/' "$T/m3.out" "$T/m4.out"; fi
  for M in m3 m4; do
    if diff -q "$T/w.ref" "$T/$M.out" >/dev/null; then PASS=$((PASS+1))
    else FAIL=$((FAIL+1)); RC=1; echo "  FAIL $M  $x"; diff -u "$T/w.ref" "$T/$M.out" | sed -n '3,9p' | sed 's/^/      /'; fi
  done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$(basename "${BASH_SOURCE[0]}" .sh)]: ${#CASES[@]} witness(es) x 2 modes = $PASS gradings byte-identical to icont -- 9 string builtins and the 6 scanning builtins refuse a non-string argument with the oracle's own code (103), keep 101 for an integer slot and 104 for a cset slot, and still convert a number -- SMALL AND LARGE, 15 arms pass a bignum because a large integer is an integer"
else echo "GATE FAIL(1) [$(basename "${BASH_SOURCE[0]}" .sh)]: $FAIL of $((PASS+FAIL)) gradings differ from icont -- a string builtin is answering where the oracle refuses, or refusing with the wrong code"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $ICONT  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
