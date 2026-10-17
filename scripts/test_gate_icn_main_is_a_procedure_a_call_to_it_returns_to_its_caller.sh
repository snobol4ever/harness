#!/usr/bin/env bash
# test_gate_icn_main_is_a_procedure_a_call_to_it_returns_to_its_caller.sh -- MAIN IS AN ORDINARY ICON PROCEDURE (hq_icon 2026-10-05, row
# icon-a-call-to-main-from-another-procedure-reads-main-as-null-error-106). A call to main from another procedure -- by name, through a variable, by
# string invocation, through proc() or in a co-expression -- reaches main with its own arguments and RETURNS TO ITS CALLER, at its own &level; main's
# statics and initial clause are one per program; a procedure declared before main keeps its registry slot in mode 4; the runtime's call of main
# ends the program with status 0 whether main returns or fails. On the parent every call to main read &null (error 106) in both modes, and the
# value road (p := main; p(1)) died "has no stackless slab". Wants cut from icont/iconx 9.5.25a; each line "rc=N" is the program's exit status.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
command -v gcc >/dev/null || { echo "⛔ REFUSE(2): no gcc for mode 4"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/c1.icn" <<'ICN'
global depth
procedure main(a)
   if /depth then {
      depth := 1;
      f();
      g();
      write("done")
      }
   else write(image(a));
end
procedure f()
   main(1);
end
procedure g()
   main(2, 3, 4, 5, 6, 7, 8, 9, 10);
end
ICN
cat > "$T/c1.want" <<'WANT'
1
2
done
rc=0
WANT
cat > "$T/c2.icn" <<'ICN'
global n
procedure main(a)
   /n := 0;
   n +:= 1;
   if n = 1 then {
      write(args(main));
      write(image(proc("main")));
      "main"(7);
      proc("main")(8);
      c := create main(9);
      write("co ", image(@c));
      write("done ", n);
      }
   else { write("in main ", image(a), " level ", &level); return a };
end
ICN
cat > "$T/c2.want" <<'WANT'
1
procedure main
in main 7 level 2
in main 8 level 2
in main 9 level 2
co 9
done 4
rc=0
WANT
cat > "$T/c3.icn" <<'ICN'
global n
procedure main(a)
   static s;
   initial { s := 0; write("init") };
   s +:= 1;
   write("level ", &level, " s ", s, " a ", image(a));
   /n := 0;
   n +:= 1;
   if n < 4 then f(n);
   write("back at ", &level);
end
procedure f(k)
   write("f level ", &level);
   main(k * 10);
end
ICN
cat > "$T/c3.want" <<'WANT'
init
level 1 s 1 a list_1(0)
f level 2
level 3 s 2 a 10
f level 4
level 5 s 3 a 20
f level 6
level 7 s 4 a 30
back at 7
back at 5
back at 3
back at 1
rc=0
WANT
cat > "$T/c4.icn" <<'ICN'
global n
procedure a(x, y)
   write("a ", x, " ", y);
   if n < 3 then return main(x + 1);
   return b(x);
end
procedure b(x)
   write("b ", x);
   return c(x, x);
end
procedure main(z)
   /n := 0;
   n +:= 1;
   write("main ", image(z), " n=", n, " level=", &level);
   if n < 4 then write("got ", a(n, 2));
   return 7;
end
procedure c(p, q)
   write("c ", p + q);
   return p * q;
end
ICN
cat > "$T/c4.want" <<'WANT'
main list_1(0) n=1 level=1
a 1 2
main 2 n=2 level=3
a 2 2
main 3 n=3 level=5
a 3 2
b 3
c 6
got 9
got 7
got 7
rc=0
WANT
cat > "$T/c5.icn" <<'ICN'
global n
procedure main(a, b)
   /n := 0;
   n +:= 1;
   write(image(a), " ", image(b));
   if n = 1 then main(3) else if n = 2 then main(4, 5, 6) else if n = 3 then f();
end
procedure f()
   main("q", "r");
   write("back in f");
end
ICN
cat > "$T/c5.want" <<'WANT'
list_1(0) &null
3 &null
4 5
"q" "r"
back in f
rc=0
WANT
cat > "$T/c6.icn" <<'ICN'
global n
procedure main()
   /n := 0;
   n +:= 1;
   write("n ", n);
   if n = 1 then { main() | write("the inner main failed"); fail };
   fail;
end
ICN
cat > "$T/c6.want" <<'WANT'
n 1
n 2
the inner main failed
rc=0
WANT
fail=0
for w in c1 c2 c3 c4 c5 c6; do
  ( cd "$T" && timeout -k 5 60 "$SCRIP" "$w.icn" </dev/null > "$w.m3" 2>&1; echo "rc=$?" >> "$w.m3" )
  if cmp -s "$T/$w.m3" "$T/$w.want"; then echo "  PASS  m3 $w"; else echo "  FAIL  m3 $w"; diff "$T/$w.want" "$T/$w.m3" | head -10 | sed 's/^/        /'; fail=1; fi
  if ( cd "$T" && "$SCRIP" --compile "$w.icn" > "$w.s" 2>/dev/null && gcc -c "$w.s" -o "$w.o" 2>/dev/null && gcc "$w.o" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$w.bin" 2>/dev/null ); then
    ( cd "$T" && timeout -k 5 60 "./$w.bin" </dev/null > "$w.m4" 2>&1; echo "rc=$?" >> "$w.m4" )
    if cmp -s "$T/$w.m4" "$T/$w.want"; then echo "  PASS  m4 $w"; else echo "  FAIL  m4 $w"; diff "$T/$w.want" "$T/$w.m4" | head -10 | sed 's/^/        /'; fail=1; fi
  else echo "  FAIL  m4 $w: no binary"; fail=1; fi
done
if [ "$fail" = 0 ]; then echo "✅ PASS: a call to main reaches it with its own arguments and returns to its caller, in both modes (6 witnesses)"; exit 0; fi
echo "⛔ FAIL: a call to main does not reach main or does not return to its caller (see the FAIL rows)"; exit 1
