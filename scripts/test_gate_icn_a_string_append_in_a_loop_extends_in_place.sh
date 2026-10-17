#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
command -v gcc >/dev/null || { echo "⛔ REFUSE(2): no gcc for mode 4"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
# test_gate_icn_a_string_append_in_a_loop_extends_in_place.sh -- s ||:= x in a loop appends in place, as iconx does (row
# icon-a-string-append-in-a-loop-copies-the-whole-string-each-time-quadratic-ipl-noise-hangs; IPL progs/noise, graded under Lon CEO-1474).
# Two causes, both cured: every Icon prologue set the string-extension latch (off = 1), so no append in a procedure ever extended in place;
# and ?x on a variable built an assignable cell even where its value is read at once, an allocation that ends extension at the heap top.
# ARM 1 (speed, generous): a million ||:= appends of ?s must finish in 20 s in m3 and m4 (iconx 0.1 s; quadratic, minutes).
# ARM 2 (aliases, the latch's own reason, c8701b17e): a string held by a second variable, a list or a resumed generator keeps its value when
# the first is extended -- wants cut from icont/iconx 9.5.25a. ARM 3: ?s as a value follows iconx's random sequence and ?s := x still assigns.
cat > "$T/al.icn" <<'ICN'
procedure main()
   local x, y, L;
   x := "a" || "b";
   y := x;
   x ||:= "c";
   write(y, " ", x, " ", *y, " ", *x);
   L := [];
   x := "p" || "q";
   put(L, x);
   x ||:= "r";
   write(L[1], " ", x);
   every write(starseq("ab"));
end
procedure starseq(s)
   local t;
   t := "";
   every 1 to 3 do
      suspend t ||:= s[1];
end
ICN
cat > "$T/al.want" <<'WANT'
ab abc 2 3
pq pqr
a
aa
aaa
WANT
cat > "$T/rv.icn" <<'ICN'
procedure main()
   local s, t, i;
   &random := 7;
   s := "abcdefgh";
   every 1 to 6 do writes(?s);
   write();
   t := s;
   every 1 to 3 do ?t := "Z";
   write(s, " ", t);
   i := 0;
   every 1 to 4 do writes(?string(&lcase));
   write();
end
ICN
cat > "$T/rv.want" <<'WANT'
gacech
abcdefgh ZbcdZfgZ
uchg
WANT
printf 'procedure main()\n   local buf, cs;\n   cs := string(&cset);\n   buf := "";\n   every 1 to 1000000 do buf ||:= ?cs;\n   write(*buf);\nend\n' > "$T/big.icn"
printf '1000000\n' > "$T/big.want"
fail=0
for w in al rv big; do
  ( cd "$T" && timeout -k 5 20 "$SCRIP" "$w.icn" </dev/null > "$w.m3" 2>&1 ); rc3=$?; python3 "$ROOT/../harness/scripts/util_render_error_voice.py" icon < "$T/$w.m3" > "$T/$w.m3.r" && mv "$T/$w.m3.r" "$T/$w.m3"
  if cmp -s "$T/$w.m3" "$T/$w.want"; then echo "  PASS  m3 $w (rc=$rc3)"; else echo "  FAIL  m3 $w rc=$rc3"; diff "$T/$w.want" "$T/$w.m3" | head -6 | sed 's/^/        /'; fail=1; fi
  if ( cd "$T" && "$SCRIP" --compile "$w.icn" > "$w.s" 2>/dev/null && gcc -c "$w.s" -o "$w.o" 2>/dev/null && gcc "$w.o" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$w.bin" 2>/dev/null ); then
    ( cd "$T" && timeout -k 5 20 "./$w.bin" </dev/null > "$w.m4" 2>&1 ); rc4=$?; python3 "$ROOT/../harness/scripts/util_render_error_voice.py" icon < "$T/$w.m4" > "$T/$w.m4.r" && mv "$T/$w.m4.r" "$T/$w.m4"
    if cmp -s "$T/$w.m4" "$T/$w.want"; then echo "  PASS  m4 $w (rc=$rc4)"; else echo "  FAIL  m4 $w rc=$rc4"; diff "$T/$w.want" "$T/$w.m4" | head -6 | sed 's/^/        /'; fail=1; fi
  else echo "  FAIL  m4 $w: no binary"; fail=1; fi
done
if [ "$fail" = 0 ]; then echo "✅ PASS: s ||:= x appends in place -- a million appends inside 20 s, aliases keep their values, ?s follows iconx and still assigns, both modes"; exit 0; fi
echo "⛔ FAIL: an append in a loop copies, or an alias or ?s disagrees with iconx (see the FAIL rows)"; exit 1
