#!/usr/bin/env bash
export SCRIP_SNO_STMTKW=1   # this grader asks for the instrumentation switch (--stlimit): Icon &trace rides the call/return hooks that are off by default since SCRIP 2026-09-24 (Lon: monitor hooks behind the switch)
# test_gate_icn_a_procedure_returns_its_variable_when_its_result_is_one.sh -- hq_icon, 2026-09-24, MODE DECTET.
#
# WHAT WAS THERE. TT_RETURN lowered its operand as a VALUE, so a procedure that executes `return t` for a global t handed
# back "x" and not the variable t: f() := "q" and f() :=: y raised run-time error 111 (variable expected) in both media,
# where Arizona iconx 9.5.25a assigns through the returned variable. suspend already passed a variable (its operand went
# through lower_trace_operand), which is why only return was wrong.
#
# WHAT IS HERE (lower_icon.c). The return operand goes through lower_result_operand: an operand in variable form is lowered
# with lower_lvalue_var, so the result is the variable -- a global or static name, a keyword, a record field, a subscript,
# a section / !x / ?x of a global, \x and /x of those, a call of a procedure that itself yields a variable. A LOCAL is
# still a value (Icon dereferences locals at return), and a subscript of a local base lowers that base AS A VALUE (the
# ret_lv context flag, read by lower_idx_var): a list element of a local list stays a variable (the list outlives the
# frame), a substring of a local string is a value -- exactly iconx's rule. Every value consumer was already guarded: a
# named user-proc call in value position is wrapped in IR_DEREF; the two calls THROUGH A VALUE (p() and f!L, string
# invocation included) now are too, because without it a returned variable would reach write() as a name.
#
# ARM. Six witnesses against the LIVE oracle (icont/iconx 9.5.25a) in both media: return/suspend/field/element/substring
# variables assigned and swapped (stdout and exit status), a returned local substring and a returned local each raising
# 111 (the controls that must stay errors), a PARAMETER SHADOWING A GLOBAL returned and assigned (111: it is the
# parameter, a local -- Arizona's tracer caught the first cut treating it as the global), calls through a value used as values, and the &trace lines of a returned and a
# suspended variable ("(variable = ...)") compared on stderr. RUN FIRST THEN WIRED (CEO-381): RED 2 of 6 on SCRIP 3e50bcf2d.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
ICONT="$(icont_bin)" || { echo "⛔ GATE REFUSE(2) [$G]: the Icon oracle is missing"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/rv.icn" <<'EOF'
global t, G, S
record R(a, b)
procedure main()
   local r, x, L, y;
   t := "x";
   f() := "q";
   write("return global: ", t);
   every s() := "w";
   write("suspend global: ", t);
   r := R(1, 2);
   fr(r) := 5;
   write("return field: ", r.a);
   x := f();
   write("rvalue: ", x, " ", f(), " ", *f());
   G := [10, 20, 30];
   fg(2) := 99;
   write("return global element: ", G[2]);
   L := [1, 2, 3];
   fl(L) := 7;
   write("return local-list element: ", L[1]);
   S := "abcdef";
   fs() := "Z";
   write("return global substring: ", S);
   y := "k";
   f() :=: y;
   write("swap: ", t, " ", y);
   write("local string subscript: ", fsl());
   write(image(floc()));
   write("done");
end
procedure f()
   return t;
end
procedure s()
   suspend t;
end
procedure fr(r)
   return r.a;
end
procedure fg(i)
   return G[i];
end
procedure fl(L)
   return L[1];
end
procedure fs()
   return S[3];
end
procedure fsl()
   local z;
   z := "hello";
   return z[2];
end
procedure floc()
   local z;
   z := 1;
   return z;
end
EOF
cat > "$T/e1.icn" <<'EOF'
procedure main()
   fsl() := "no";
   write("not reached");
end
procedure fsl()
   local z;
   z := "hello";
   return z[2];
end
EOF
cat > "$T/e2.icn" <<'EOF'
procedure main()
   floc() := 2;
   write("not reached");
end
procedure floc()
   local z;
   z := 1;
   return z;
end
EOF
cat > "$T/cv.icn" <<'EOF'
global t
procedure main()
   local p, x, q;
   t := "x";
   p := f;
   write(p(), " ", f![], " ", "f"());
   x := p();
   write(x);
   every write(g());
   every write(q := !(["a", "b"]));
   write(*p(), " ", p() || "!", " ", image(p()));
   write("done");
end
procedure f()
   return t;
end
procedure g()
   suspend t | "lit";
end
EOF
cat > "$T/sh.icn" <<'EOF'
global s
procedure main()
   s := "g";
   write(foo("p"));
   (foo("p") := "x") | write("failed");
   write(s);
end
procedure foo(s)
   return s;
end
EOF
cat > "$T/tr.icn" <<'EOF'
global t
record R(a)
procedure main()
   local r;
   t := "x";
   r := R(3);
   &trace := -1;
   f();
   fr(r);
   every g();
   write("done");
end
procedure f()
   return t;
end
procedure fr(r)
   return r.a;
end
procedure g()
   suspend t;
end
EOF
fail=0; pass=0; names=""
for w in rv e1 e2 cv sh tr; do
  ( cd "$T" && "$ICONT" -s -o "$w.x" "$w.icn" ) >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: icont refuses $w.icn"; exit 2; }
  want="$( cd "$T" && ./"$w.x" </dev/null 2>"$w.ix.err" )"; wrc=$?
  ( cd "$T" && "$SCRIP" --compile -o "$w.s" "$w.icn" </dev/null >/dev/null 2>&1 && gcc -no-pie -o "$w.4" "$w.s" -L"$ROOT/out" -lscrip_rt -lm -lstdc++ -lpthread -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ) \
    || { echo "  $w FAIL: does not build in mode 4"; fail=$((fail+1)); continue; }
  o3="$( cd "$T" && timeout -k 5 20 "$SCRIP" "$w.icn" </dev/null 2>"$w.m3.err" )"; r3=$?
  o4="$( cd "$T" && timeout -k 5 20 ./"$w.4" </dev/null 2>"$w.m4.err" )"; r4=$?
  ok=1; [ "$o3" = "$want" ] && [ "$r3" = "$wrc" ] && [ "$o4" = "$want" ] && [ "$r4" = "$wrc" ] || ok=0
  if [ "$w" = tr ]; then cmp -s "$T/tr.ix.err" "$T/tr.m3.err" && cmp -s "$T/tr.ix.err" "$T/tr.m4.err" || ok=0; fi
  if [ "$ok" = 1 ]; then pass=$((pass+1)); names="$names $w"
  else fail=$((fail+1)); echo "  $w FAIL: iconx rc=$wrc m3 rc=$r3 m4 rc=$r4 (stdout m3 $([ "$o3" = "$want" ] && echo same || echo DIFFERS), m4 $([ "$o4" = "$want" ] && echo same || echo DIFFERS))"; fi
done
echo "  HOLDS: return and suspend hand back the variable when the result is one, a local is a value, and every value consumer dereferences it"
if [ "$fail" -eq 0 ]; then echo "  arm 1 PASS: $pass of 6 witnesses match iconx in both media:$names"; echo "✅ GATE PASS [$G]"; exit 0; fi
echo "  arm 1 FAIL: $fail of 6 witnesses differ from iconx"; echo "⛔ GATE FAIL [$G]"; exit 1
