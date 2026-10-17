#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_icn_generator_regime_calls_the_runtime_at_c_parity.sh — row icon-a-suspend-plus-a-call-through-a-procedure-value-segfaults-and-diffn-diffu-now-reach-it (cto 2026-09-10).
#
# A generator body rests at the same stack parity as every other box (0 mod 16 since CFO-36 / the N-2 word), so a
# runtime call made from inside it needs NO pad. bb_call_value.cpp padded its two runtime calls by 8 in the generator
# regime (5f4b2d4c2, 2026-08-29, when the body rested at 8 mod 16); once the body moved, the pad entered the runtime
# at 0 mod 16, rt_proc_enter's seven pushes handed the callee a frame at 8 mod 16, and glibc's first movaps faulted.
# The claim spans two sites (the generator carve in emit.cpp, the call sites in the templates) and is held here by
# measurement, not memory: four witnesses, both modes, against icont's own output. v1 = suspend + call through a
# procedure value (the crash); v2 = procedure value, no suspend; v3 = suspend, direct call; v4 = suspend + apply
# through a procedure value + a co-expression created inside the generator (the 2026-08-29 row's shape).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
command -v gcc >/dev/null || { echo "⛔ REFUSE(2): no gcc for mode 4"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/v1.icn" <<'ICN'
procedure helper(m);
   return *string(m);
end
procedure v1(g, n);
   local i, r;
   every i := 1 to n do { r := g(i); suspend r };
end
procedure main();
   local x;
   every x := v1(helper, 2) do write("v1 ", x);
   write("done");
end
ICN
cat > "$T/v2.icn" <<'ICN'
procedure helper(m);
   return *string(m);
end
procedure v2(g, n);
   local i, r;
   every i := 1 to n do { r := g(i); write("v2 ", r) };
   return;
end
procedure main();
   v2(helper, 2); write("done");
end
ICN
cat > "$T/v3.icn" <<'ICN'
procedure helper(m);
   return *string(m);
end
procedure v3(n);
   local i, r;
   every i := 1 to n do { r := helper(i); suspend r };
end
procedure main();
   local x;
   every x := v3(2) do write("v3 ", x);
   write("done");
end
ICN
cat > "$T/v4.icn" <<'ICN'
procedure helper(m);
   return *string(m * 111);
end
procedure v4(g, n);
   local i, r, c;
   every i := 1 to n do { c := create g ! [i]; r := @c; suspend r };
end
procedure main();
   local x;
   every x := v4(helper, 3) do write("v4 ", x);
   write("done");
end
ICN
printf 'v1 1\nv1 1\ndone\n' > "$T/v1.want"
printf 'v2 1\nv2 1\ndone\n' > "$T/v2.want"
printf 'v3 1\nv3 1\ndone\n' > "$T/v3.want"
printf 'v4 3\nv4 3\nv4 3\ndone\n' > "$T/v4.want"
fail=0
for w in v1 v2 v3 v4; do
  ( cd "$T" && timeout -k 5 60 "$SCRIP" "$w.icn" </dev/null > "$w.m3" 2>&1 ); rc3=$?
  if [ "$rc3" = 0 ] && cmp -s "$T/$w.m3" "$T/$w.want"; then echo "  PASS  m3 $w"; else echo "  FAIL  m3 $w rc=$rc3"; head -3 "$T/$w.m3" | sed 's/^/        /'; fail=1; fi
  if ( cd "$T" && "$SCRIP" --compile "$w.icn" > "$w.s" 2>/dev/null && gcc -c "$w.s" -o "$w.o" 2>/dev/null && gcc "$w.o" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$w.bin" 2>/dev/null ); then
    ( cd "$T" && timeout -k 5 60 "./$w.bin" </dev/null > "$w.m4" 2>&1 ); rc4=$?
    if [ "$rc4" = 0 ] && cmp -s "$T/$w.m4" "$T/$w.want"; then echo "  PASS  m4 $w"; else echo "  FAIL  m4 $w rc=$rc4"; head -3 "$T/$w.m4" | sed 's/^/        /'; fail=1; fi
  else echo "  FAIL  m4 $w: no binary"; fail=1; fi
done
if [ "$fail" = 0 ]; then echo "✅ PASS: a generator body calls the runtime at C parity -- suspend + procedure value, apply, create, direct: 4 witnesses x 2 modes"; exit 0; fi
echo "⛔ FAIL: a runtime call from inside a generator body is off by 8 (see the FAIL rows)"; exit 1
