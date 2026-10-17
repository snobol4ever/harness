#!/usr/bin/env bash
# test_gate_icn_cset_operations_and_a_substring_assignment_follow_iconx.sh -- hq_icon, 2026-09-24, MODE DECTET; row
# icon-deal-the-shuffle-and-random-path-is-twenty-times-slower-than-iconx-in-both-modes (found profiling deal's own compute).
#
# WHAT WAS THERE. The cset operators ++ -- ** and the complement ~ measured a STRING operand with strlen(), so "a\x00b" -- ' '
# was the one-member cset 'a' where iconx answers '\x00ab'; they ran every operand through the numeric pre-pass first, so a
# numeric string too big for a machine integer became a large integer and then raised error 120 ("two csets expected"), and a
# large integer operand raised it too where iconx takes its digits; and each result was re-canonicalized after cset_from_bits
# had already interned it canonical (four registry probes per operation, 4.2% of deal's instructions). Separately, a trapped
# substring took a CSET's length marker (0xFFFFFFFF) as a real length: s[2] := 'yx' asked the heap for 4 GB and died with
# error 306 where iconx gives "axycdef"; subscripting a variable that holds a cset made a trapped substring over it, so
# s[1] := "x" on s := 'cab' asked for 4 GB too where iconx raises error 111 (a subscripted cset is a value, not a variable);
# a large-integer value assigned into a substring printed an [IDX] diagnostic and failed; and every substring assignment
# copied its right-hand string only to return the copy.
#
# WHAT IS HERE. rt_num_arith_body sends the three cset operators to rt_cset_arith before any numeric pre-pass; one reader,
# rt_cset_operand_chars, gives a cset's registry length, a string's CARRIED length, an integer's, a real's or a large
# integer's digits, and ~ reads its operand through it too; the interned result is returned as it is (the empty cset is the
# one static "" and no longer appends a registry entry per operation). The subscript and section trap sites exclude a cset
# base, as the ! and ? sites already did; the substring assignment reads a cset value through its registry length and a
# large integer through its digits, and returns a string right-hand side itself instead of a copy.
#
# ARMS. Arm 1's counts read statements with whitespace folded (stmts), so a re-flow of the source lines cannot blind them (CEO-1565).
# (1) STRUCTURE: the cset operators route before big_str_operand; the operand reader carries a string's length; the
# subscript and section trap sites exclude a cset; the substring assignment has a cset arm. (2) BEHAVIOUR, both media, graded
# against the LIVE oracle (icont/iconx 9.5.25a) on five witnesses: stdout byte-identical, the same exit status, and the same
# run-time error number. A witness the oracle does not run refuses the gate rather than passing it.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
ICONT="$(icont_bin)" || { echo "⛔ GATE REFUSE(2) [$G]: the Icon oracle is missing"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
AR="$ROOT/src/runtime/arithmetic.c"; PM="$ROOT/src/runtime/pattern_match.c"
for f in "$AR" "$PM"; do [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing $f"; exit 2; }; done
echo "  HOLDS: ++ -- ** ~ read a string's carried length and a large integer's digits, and a cset in a substring assignment is read as iconx reads it"
body="$(sed -n '/^static DESCR_t rt_num_arith_body(DESCR_t a, DESCR_t b, int op, int strict) {/,/^}/p' "$AR")"
route=$(printf '%s\n' "$body" | grep -n 'return rt_cset_arith(a, b, op);' | head -1 | cut -d: -f1)
bigpre=$(printf '%s\n' "$body" | grep -n 'big_str_operand(a)' | head -1 | cut -d: -f1)
stmts() { tr -s ' \n\t' '   ' < "$2" | grep -oF -- "$1" | wc -l; }
carried=$(stmts 'if (d.v == DT_S || d.v == DT_SNUL) { *len = (int)descr_slen(d);' "$AR")
guards=$(stmts '&& !IS_CSET_fn(base) && IS_VARREF_fn(bvar)) {' "$PM")
csval=$(stmts 'if (IS_CSET_fn(val)) { src = val.s ? val.s : ""; srclen = (long)descr_slen(val); owned = 0; }' "$PM")
if [ -n "$route" ] && [ -n "$bigpre" ] && [ "$route" -lt "$bigpre" ] && [ "$carried" = 1 ] && [ "$guards" = 2 ] && [ "$csval" = 1 ]; then
  echo "  arm 1 PASS: the cset operators route before the numeric pre-pass, the operand reader carries a string's length, both trap sites exclude a cset base, the substring assignment has a cset arm"
else echo "  arm 1 FAIL: route_line=${route:-none} bigpre_line=${bigpre:-none} carried_len_reader=$carried cset_trap_guards=$guards cset_value_arm=$csval (want route<bigpre 1 2 1)"; RC=1; fi
cat > "$T/w1.icn" <<'EOF'
procedure main()
   local s, c;
   s := "a\x00b";
   c := s -- ' ';
   write(*c, " ", image(c));
   c := s ++ 'z';
   write(*c, " ", image(c));
   c := s ** 'ab\x00';
   write(*c, " ", image(c));
   c := 'xy' ++ s;
   write(*c, " ", image(c));
   c := "hello world" -- ' ';
   write(*c, " ", image(c));
   c := 12345678901234567890123 ++ '';
   write(*c, " ", image(c));
   c := "+007" ++ '';
   write(*c, " ", image(c));
   c := "" -- 'abc';
   write(*c, " ", image(c));
   c := 3.5 ++ 'x';
   write(*c, " ", image(c));
end
EOF
cat > "$T/w2.icn" <<'EOF'
procedure main()
   local s, c;
   s := "a\x00b";
   write(*(~s), " ", *(~'ab'), " ", *(~""), " ", *(~12));
   c := cset(s);
   write(*c, " ", image(c));
   c := "12345678901234567890123" ++ '';
   write(*c, " ", image(c));
   c := 'abc' -- 'abc';
   write(*c, " ", image(c), " ", image(c ++ 'q'));
   every c := ("xyz" | "\x00\x00" | 'pq') ** ('zq\x00') do write(*c, " ", image(c));
end
EOF
cat > "$T/w3.icn" <<'EOF'
procedure main()
   local s, t, r;
   s := "abcdef";
   r := (s[2] := 'yx');
   write(s, " ", image(r));
   s[1] := "";
   write(s);
   r := (s[1:3] := 42);
   write(s, " ", image(r));
   r := (s[-1] := 2.5);
   write(s, " ", image(r));
   t := "p\x00q";
   r := (s[2:4] := t);
   write(image(s), " ", image(r), " ", *r);
   s := "abcd";
   every !s :=: ?s;
   write(*s);
   s := "abcd";
   r := (s[1] :=: s[4]);
   write(s, " ", image(r));
   s := "abcd";
   r := (s[1:3] :=: s[2:4]);
   write(s, " ", image(r));
end
EOF
cat > "$T/w4.icn" <<'EOF'
procedure main()
   local s, r;
   &error := -1;
   s := 'cab';
   r := s[2:4];
   write(image(r));
   (s[1:2] := "x") | write("fail ", &errornumber);
   write(image(s));
   s := "abc";
   r := (s[2] := 12345678901234567890123);
   write(image(s), " ", image(r));
   s := "abc";
   r := (s[2] := &digits);
   write(image(s), " ", image(r), " ", type(r));
end
EOF
cat > "$T/w5.icn" <<'EOF'
procedure main()
   local s, r;
   s := 'cab';
   r := s[2];
   write(image(r));
   s[1] := "x";
   write(image(s));
end
EOF
beh=""; bad=0
errno_of() { grep -oE '(Run-time )?error [0-9]+' "$1" | head -1 | grep -oE '[0-9]+$'; }
for w in w1 w2 w3 w4 w5; do
  ( cd "$T" && "$ICONT" -s -o "$w.x" "$w.icn" ) >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: icont refuses witness $w"; exit 2; }
  ( cd "$T" && timeout -k 5 20 "./$w.x" </dev/null >"$w.io" 2>"$w.ie" ); ir=$?
  [ "$ir" -le 1 ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle did not run witness $w (rc=$ir)"; exit 2; }
  ( cd "$T" && timeout -k 5 20 "$SCRIP" "$w.icn" </dev/null >"$w.3o" 2>"$w.3e" ); r3=$?
  ( cd "$T" && "$SCRIP" --compile -o "$w.s" "$w.icn" </dev/null >/dev/null 2>&1 && gcc -no-pie -o "$w.4" "$w.s" -L"$ROOT/out" -lscrip_rt -lm -lstdc++ -lpthread -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ) \
    || { echo "⛔ GATE REFUSE(2) [$G]: witness $w does not build in mode 4"; exit 2; }
  ( cd "$T" && timeout -k 5 20 "./$w.4" </dev/null >"$w.4o" 2>"$w.4e" ); r4=$?
  ie="$(errno_of "$T/$w.ie")"; e3="$(errno_of "$T/$w.3e")"; e4="$(errno_of "$T/$w.4e")"
  if cmp -s "$T/$w.io" "$T/$w.3o" && cmp -s "$T/$w.io" "$T/$w.4o" && [ "$r3" = "$ir" ] && [ "$r4" = "$ir" ] && [ "$e3" = "$ie" ] && [ "$e4" = "$ie" ]; then beh="$beh $w:ok(rc=$ir${ie:+,err=$ie})"
  else beh="$beh $w:RED(iconx rc=$ir err=${ie:-none}; m3 rc=$r3 err=${e3:-none} out=$(cmp -s "$T/$w.io" "$T/$w.3o" && echo same || echo DIFF); m4 rc=$r4 err=${e4:-none} out=$(cmp -s "$T/$w.io" "$T/$w.4o" && echo same || echo DIFF))"; bad=1; fi
done
if [ "$bad" = 0 ]; then echo "  arm 2 PASS: five witnesses match the live oracle's stdout, exit status and error number in both media --$beh"
else echo "  arm 2 FAIL: a cset operation or a substring assignment does not behave as iconx's --$beh"; RC=1; fi
[ "$RC" = 0 ] && echo "✅ GATE PASS [$G]: 2 of 2 arms hold" || echo "⛔ GATE FAIL [$G]"
exit $RC
