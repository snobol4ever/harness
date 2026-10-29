#!/usr/bin/env bash
# test_gate_icn_a_one_character_substring_swap_builds_one_string.sh -- hq_icon, 2026-09-24, MODE DECTET; row
# icon-deal-the-shuffle-and-random-path-is-twenty-times-slower-than-iconx-in-both-modes (step 2, deal's own compute).
#
# WHAT WAS THERE. deal's shuffle is every !x :=: ?x, and rt_swap_var did it as two full substring assignments: dereference
# both sides (each a fresh one-character string), rebuild the whole subject for the first side, rebuild it again for the
# second, copy each right-hand side only to return it, then dereference the left side once more -- nine heap blocks and
# about 1900 instructions per swap, 29% of deal's instructions at a 256 MB arena. Separately, the swap's same-variable test
# looked only through a trap-form variable reference, so two sections of one local of unequal length (s[1:3] :=: s[4:5])
# never had the second position shifted by the first assignment, and the result differed from iconx's.
#
# WHAT IS HERE. A one-character trapped substring reads as the constant one-character string for its byte (a 256-entry
# static table; a trap of any other length still copies). Two one-character traps over the same variable cell -- a local,
# a global, a list slot, reached through either form of variable reference -- are swapped by building ONE new
# subject with the two bytes exchanged and storing it once; every other shape takes the two-assignment path, whose
# same-variable test now reads the base cell through either form too.
#
# ARMS. Arm 1 reads statements with whitespace folded (stmts), so a re-flow of the source lines cannot blind it (CEO-1565).
# (1) STRUCTURE: the one-character read, the same-cell fast path and the widened same-variable test are present.
# (2) BEHAVIOUR, both media, against the LIVE oracle (icont/iconx 9.5.25a): a witness of 30 swaps over locals, a global, list
# elements, a table element, sections of unequal length, a NUL-carrying subject, equal positions, swaps between two
# variables, a shuffle procedure and a seeded random loop -- stdout byte-identical. (3) ALLOCATION, both media: the heap's
# own block count (no collection in a 256 MB arena) grows by exactly 3 per swap of ?s :=: ?s -- the two traps and the one
# new subject; it was 9 before.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
ICONT="$(icont_bin)" || { echo "⛔ GATE REFUSE(2) [$G]: the Icon oracle is missing"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
PM="$ROOT/src/runtime/pattern_match.c"; [ -f "$PM" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing $PM"; exit 2; }
echo "  HOLDS: a swap of two one-character substrings of one variable builds one new string, and every substring swap answers as iconx does"
stmts() { tr -s ' \n\t' '   ' < "$2" | grep -oF -- "$1" | wc -l; }
one=$(stmts 'if (vc->len == 1) return (DESCR_t){ .v = DT_S, .slen = 1, .s = (char *)&k_one_char_str[2 * (unsigned char)sp[vc->pos - 1]] };' "$PM")
fast=$(stmts 'DESCR_t *cx_cell = swap_base_cell(xc->sv), *cy_cell = swap_base_cell(yc->sv);' "$PM")
wide=$(stmts 'DESCR_t *bx = swap_base_cell(xc->sv); if (bx && bx == swap_base_cell(yc->sv)' "$PM")
if [ "$one" = 1 ] && [ "$fast" = 1 ] && [ "$wide" = 1 ]; then echo "  arm 1 PASS: the one-character read, the same-cell fast path and the widened same-variable test are present"
else echo "  arm 1 FAIL: one_char_read=$one same_cell_fast_path=$fast widened_same_variable=$wide (want 1 1 1)"; RC=1; fi
cat > "$T/w.icn" <<'EOF'
global G
procedure sw(x)
   every !x :=: ?x;
   return x;
end
procedure main()
   local s, t, L, T, i, v;
   &random := 7;
   s := "abcdef";
   write(s[1] :=: s[6], " ", s);
   write(s[3] :=: s[3], " ", s);
   write(s[2] :=: s[-1], " ", s);
   t := "XYZ";
   write(s[1] :=: t[2], " ", s, " ", t);
   write(s[1:3] :=: s[4:5], " ", s);
   write(s[1:3] :=: t[1:3], " ", s, " ", t);
   write(s[5:7] :=: s[1:2], " ", s);
   s := "a\x00b";
   write(image(s[1] :=: s[2]), " ", image(s));
   L := ["hello", "world"];
   write(L[1][1] :=: L[1][5], " ", L[1]);
   write(L[1][1] :=: L[2][1], " ", L[1], " ", L[2]);
   T := table();
   T["k"] := "table";
   write(T["k"][1] :=: T["k"][5], " ", T["k"]);
   G := "global";
   write(G[1] :=: G[6], " ", G);
   s := "abcdef";
   every i := 1 to 6 do s[i] :=: s[7 - i];
   write(s);
   s := "0123456789";
   every 1 to 100 do ?s :=: ?s;
   write(s);
   every write(sw("deal" | "shuffle" | "x" | ""));
   s := "abc";
   v := s;
   s[1] :=: s[3];
   write(s, " ", v);
end
EOF
( cd "$T" && "$ICONT" -s -o w.x w.icn ) >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: icont refuses the witness"; exit 2; }
want="$( cd "$T" && timeout -k 5 20 ./w.x </dev/null 2>/dev/null )" || { echo "⛔ GATE REFUSE(2) [$G]: the oracle did not run the witness"; exit 2; }
[ -n "$want" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle printed nothing"; exit 2; }
build4() { ( cd "$T" && "$SCRIP" --compile --out="$1.s" "$1.icn" </dev/null >/dev/null 2>&1 && gcc -no-pie -o "$1.4" "$1.s" -L"$ROOT/out" -lscrip_rt -lm -lstdc++ -lpthread -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ); }
build4 w || { echo "⛔ GATE REFUSE(2) [$G]: the witness does not build in mode 4"; exit 2; }
o3="$( cd "$T" && timeout -k 5 20 "$SCRIP" w.icn </dev/null 2>/dev/null )"; o4="$( cd "$T" && timeout -k 5 20 ./w.4 </dev/null 2>/dev/null )"
if [ "$o3" = "$want" ] && [ "$o4" = "$want" ]; then echo "  arm 2 PASS: $(printf '%s\n' "$want" | wc -l) lines of swaps match iconx byte for byte in both media"
else echo "  arm 2 FAIL: the swaps differ from iconx -- m3 $( [ "$o3" = "$want" ] && echo same || echo DIFF ), m4 $( [ "$o4" = "$want" ] && echo same || echo DIFF )"
  diff <(printf '%s\n' "$want") <(printf '%s\n' "$o3") | head -8 | sed 's/^/      m3 /'; RC=1; fi
for n in 1000 3000; do printf 'procedure main()\n   local s;\n   s := repl("ab", 50);\n   every 1 to %s do ?s :=: ?s;\n   write(*s);\nend\n' "$n" > "$T/n$n.icn"; build4 "n$n" || { echo "⛔ GATE REFUSE(2) [$G]: the allocation witness does not build in mode 4"; exit 2; }; done
blocks() { grep -oE 'collections=[0-9]+ blocks=[0-9]+' "$1" | head -1; }
al=""; abad=0
for md in m3 m4; do
  for n in 1000 3000; do
    if [ "$md" = m3 ]; then ( cd "$T" && env SCRIP_GC_EXERCISE=1 SCRIP_HEAP_KB=262144 timeout -k 5 60 "$SCRIP" "n$n.icn" </dev/null >/dev/null 2>"$md.$n" )
    else ( cd "$T" && env SCRIP_GC_EXERCISE=1 SCRIP_HEAP_KB=262144 timeout -k 5 60 "./n$n.4" </dev/null >/dev/null 2>"$md.$n" ); fi
  done
  r1="$(blocks "$T/$md.1000")"; r2="$(blocks "$T/$md.3000")"
  c1=$(printf '%s' "$r1" | sed -n 's/collections=\([0-9]*\).*/\1/p'); c2=$(printf '%s' "$r2" | sed -n 's/collections=\([0-9]*\).*/\1/p')
  b1=$(printf '%s' "$r1" | sed -n 's/.*blocks=\([0-9]*\)/\1/p'); b2=$(printf '%s' "$r2" | sed -n 's/.*blocks=\([0-9]*\)/\1/p')
  [ -n "$b1" ] && [ -n "$b2" ] || { echo "⛔ GATE REFUSE(2) [$G]: no heap report in $md (SCRIP_GC_EXERCISE printed no blocks=)"; exit 2; }
  [ "$c1" = 0 ] && [ "$c2" = 0 ] || { echo "⛔ GATE REFUSE(2) [$G]: a collection ran in $md, so blocks= is not an allocation count"; exit 2; }
  per=$(( (b2 - b1) / 2000 )); rem=$(( (b2 - b1) % 2000 ))
  if [ "$per" = 3 ] && [ "$rem" = 0 ]; then al="$al $md:3/swap"; else al="$al $md:RED($(( b2 - b1 )) blocks over 2000 swaps)"; abad=1; fi
done
if [ "$abad" = 0 ]; then echo "  arm 3 PASS: each ?s :=: ?s allocates exactly the two traps and one new subject --$al"
else echo "  arm 3 FAIL: a swap allocates more than the two traps and one subject --$al"; RC=1; fi
[ "$RC" = 0 ] && echo "✅ GATE PASS [$G]: 3 of 3 arms hold" || echo "⛔ GATE FAIL [$G]"
exit $RC
