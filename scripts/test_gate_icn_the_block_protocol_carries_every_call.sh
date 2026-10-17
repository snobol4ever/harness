#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; CORPUS="${CORPUS:-$(cd "$ROOT/../corpus" 2>/dev/null && pwd)}"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
command -v gcc >/dev/null || { echo "⛔ REFUSE(2): no gcc for mode 4"; exit 2; }
[ -d "$CORPUS/benchmarks/icon" ] || { echo "⛔ REFUSE(2): no corpus/benchmarks/icon beside $ROOT"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
fail=0; n=0; hits=0
for k in "$CORPUS"/benchmarks/icon/*.icn "$CORPUS"/benchmarks/icon/*/*.icn; do
  [ -f "$k" ] || continue
  ( cd "$(dirname "$k")" && timeout -k 5 120 "$SCRIP" --compile -o "$T/k.s" "$k" < /dev/null > /dev/null 2>&1 ) || continue
  n=$((n + 1)); c=$(grep -cE 'call[[:space:]]+(rt_jmp_frame_lexprep2|rt_icn_zframe_args_install|rt_arg_stage|rt_proc_drop_frame_h|rt_proc_call_open_det[0-4]?|rt_nret_fix_tiny)\b' "$T/k.s"); hits=$((hits + c))
  [ "$c" -gt 0 ] && echo "  FAIL  arm 1 $(basename "$k"): $c call sites into the six frame helpers"
done
[ "$n" -ge 1 ] || { echo "⛔ REFUSE(2): no Icon kernel compiled"; exit 2; }
if [ "$hits" -eq 0 ]; then echo "  PASS  arm 1: $n Icon kernels' mode-4 text names none of the six frame helpers"; else fail=1; fi
cat > "$T/w1.icn" <<'ICN'
procedure main(args)
   local p, c, L;
   write(f2(1), " ", f2(1, 2), " ", f2(1, 2, 3));
   write(v(1), " ", v(1, 2), " ", v(1, 2, 3, 4));
   every writes(upto3(1), " "); write();
   p := upto3; every writes(p(2), " "); write();
   p := sq; write(p(7));
   write("sq"(5), " ", proc("sq")(6), " ", sq ! [8]);
   c := create upto3(1); write(@c, @c, @c);
   write(six(1, 2, 3, 4, 5, 6));
   write(ack(2, 3));
   write(*args);
   L := [];
   every put(L, gv(3, 4));
   write(*L, " ", L[1], " ", L[2]);
   write(vv ! [1, 2, 3]);
end
procedure f2(a, b)
   return image(a) || "," || image(b);
end
procedure v(a, rest[])
   return a || ":" || *rest;
end
procedure vv(a, rest[])
   return a + rest[1] + rest[2];
end
procedure upto3(k)
   local i;
   i := k;
   while i <= 3 do {
      suspend i;
      i +:= 1;
   };
end
procedure gv(x, y)
   suspend x | y;
end
procedure sq(x)
   return x * x;
end
procedure six(a, b, c, d, e, f)
   return a + b + c + d + e + f;
end
procedure ack(m, n)
   if m = 0 then return n + 1;
   if n = 0 then return ack(m - 1, 1);
   return ack(m - 1, ack(m, n - 1));
end
ICN
cat > "$T/w1.want" <<'WANT'
1,&null 1,2 1,2
1:0 1:1 1:3
1 2 3 
2 3 
49
25 36 64
123
21
9
0
2 3 4
6
WANT
cat > "$T/w2.icn" <<'ICN'
procedure main()
   write(g(3, "x"));
end
procedure g(n, s)
   local t;
   t := n * 2;
   write(variable("n"), " ", variable("s"), " ", variable("t"));
   display(1);
   return h(n, s);
end
procedure h(a, b)
   return a + b;
end
ICN
cat > "$T/w2.want" <<'WANT'
3 x 6
co-expression_1(1)

g local identifiers:
   n = 3
   s = "x"
   t = 6

global identifiers:
   display = function display
   g = procedure g
   h = procedure h
   main = procedure main
   variable = function variable
   write = function write

Run-time error 102
File w2.icn; Line 12
numeric expected
offending value: "x"
Traceback:
main()
g(3,"x") from line 2 in w2.icn
h(3,"x") from line 9 in w2.icn
{3 + "x"} from line 12 in w2.icn
WANT
cat > "$T/w3.icn" <<'ICN'
procedure main()
   every write(gen(2, 5));
end
procedure gen(a, b)
   local i;
   every i := a to b do {
      if i = 4 then suspend i + [];
      suspend i;
   };
end
ICN
cat > "$T/w3.want" <<'WANT'
2
3

Run-time error 102
File w3.icn; Line 7
numeric expected
offending value: list_1 = []
Traceback:
main()
gen(2,5) from line 2 in w3.icn
{4 + list_1 = []} from line 7 in w3.icn
WANT
cat > "$T/t1.icn" <<'ICN'
procedure main()
   &trace := -1;
   write(f(2, "a"));
   every write(g(1, 2));
   write(v(1, 2, 3));
end
procedure f(n, s)
   return n || s;
end
procedure g(a, b)
   suspend a | b;
end
procedure v(x, y[])
   return x + *y;
end
ICN
cat > "$T/t1.want" <<'WANT'
t1.icn       :    3  | f(2,"a")
t1.icn       :    8  | f returned "2a"
2a
t1.icn       :    4  | g(1,2)
t1.icn       :   11  | g suspended 1
1
t1.icn       :    4  | g resumed
t1.icn       :   11  | g suspended 2
2
t1.icn       :    4  | g resumed
t1.icn       :   12  | g failed
t1.icn       :    5  | v(1,list_1 = [2,3])
t1.icn       :   14  | v returned 3
3
t1.icn       :    6  main failed
WANT
cat > "$T/w5.icn" <<'ICN'
record node(v, sub)
procedure main()
   local t;
   t := node(1, [node(2, []), node(3, [node(4, [])])]);
   every writes(walk(t).v, " ");
   write();
   every write(gsum(1, 2, 3, 4, 5, 6));
end
procedure walk(r)
   suspend r | walk(!r.sub);
end
procedure gsum(a, b, c, d, e, f)
   suspend six(a, b, c, d, e, f) | six(f, e, d, c, b, a) * 2;
end
procedure six(a, b, c, d, e, f)
   return a + b * 10 + c * 100 + d * 1000 + e * 10000 + f * 100000;
end
ICN
cat > "$T/w5.want" <<'WANT'
1 2 3 4 
654321
246912
WANT
cat > "$T/w6.icn" <<'ICN'
procedure lrev(L)
   local L1, i;
   L1 := [];
   every i := *L to 1 by -1 do put(L1, L[i]);
   return L1;
end
procedure flip(L)
   flip := lrev;
   return flip(L);
end
procedure main()
   every writes(" ", !flip([1, 2, 3])); write();
end
ICN
cat > "$T/w6.want" <<'WANT'
 3 2 1
WANT
cat > "$T/w7.icn" <<'ICN'
procedure main()
   local c;
   c := mk(5);
   every write(@c | @c | @c);
end
procedure mk(n)
   local k;
   k := n * 10;
   return create n to n + k / 25;
end
ICN
cat > "$T/w7.want" <<'WANT'
5
6
7
WANT
for w in w1 w2 w3 w5 w6 w7 t1; do
  sw=""; [ "$w" = t1 ] && sw="SCRIP_SNO_STMTKW=1"
  ( cd "$T" && env $sw timeout -k 5 60 "$SCRIP" "$w.icn" </dev/null > "$w.m3" 2>&1 ); rc3=$?; python3 "$ROOT/../harness/scripts/util_render_error_voice.py" icon < "$T/$w.m3" > "$T/$w.m3.r" && mv "$T/$w.m3.r" "$T/$w.m3"
  if cmp -s "$T/$w.m3" "$T/$w.want"; then echo "  PASS  m3 $w (rc=$rc3)"; else echo "  FAIL  m3 $w rc=$rc3"; diff "$T/$w.want" "$T/$w.m3" | head -10 | sed 's/^/        /'; fail=1; fi
  if ( cd "$T" && env $sw "$SCRIP" --compile "$w.icn" > "$w.s" 2>/dev/null && gcc -c "$w.s" -o "$w.o" 2>/dev/null && gcc "$w.o" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$w.bin" 2>/dev/null ); then
    ( cd "$T" && timeout -k 5 60 "./$w.bin" </dev/null > "$w.m4" 2>&1 ); rc4=$?; python3 "$ROOT/../harness/scripts/util_render_error_voice.py" icon < "$T/$w.m4" > "$T/$w.m4.r" && mv "$T/$w.m4.r" "$T/$w.m4"
    if cmp -s "$T/$w.m4" "$T/$w.want"; then echo "  PASS  m4 $w (rc=$rc4)"; else echo "  FAIL  m4 $w rc=$rc4"; diff "$T/$w.want" "$T/$w.m4" | head -10 | sed 's/^/        /'; fail=1; fi
  else echo "  FAIL  m4 $w: no binary"; fail=1; fi
done
if [ "$fail" = 0 ]; then echo "✅ PASS: every Icon call carries its arguments in a block on the caller's spine -- no frame helper in the kernels' text, and arity mismatch, a variadic tail, generators resumed and called by value, a co-expression, string invocation, !, six arguments, deep recursion, a recursive generator fed by a generator and a six-argument call from a generator frame, a call through a procedure name reassigned inside the procedure, a co-expression created inside a procedure reading its parameter, variable(), display(), tracebacks and &trace all agree with iconx, both modes"; exit 0; fi
echo "⛔ FAIL: the Icon block protocol is broken (see the FAIL rows)"; exit 1
