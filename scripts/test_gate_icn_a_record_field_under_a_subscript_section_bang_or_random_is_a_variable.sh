#!/usr/bin/env bash
# test_gate_icn_a_record_field_under_a_subscript_section_bang_or_random_is_a_variable.sh -- hq_icon, 2026-09-24, MODE DECTET.
#
# WHAT WAS THERE. The Icon lowerer lowers the operand of s[i], s[i:j], !s and ?s in an assignable position through one of
# four sites, and each sent only a plain variable, a keyword, a subscript or a section down the variable path; a record
# field went down the value path. So r.f[1] := "S", r.f[2:4] := "--", every !r.f := "z", ?r.f := "Q" and r.f[1] :=: r.f[5]
# raised run-time error 111 ("variable expected") where iconx assigns into the field's string, and the ? site sent even a
# subscript down the value path, so ?L[1] := "#" raised 111 too. Found beside the substring-swap cure (the swap witness
# could not reach a record field at all).
#
# WHAT IS HERE. All four sites send a record field (and the ? site a keyword, a subscript or a section) through
# lower_lvalue_var, which already lowers a field to IR_FIELD_VAR; the runtime's trapped substring over a field variable
# was already correct.
#
# ARMS. (1) STRUCTURE: the four sites name TT_FIELD (the ? site read as statements, whitespace folded, so a re-flow of its lines
# cannot blind it, CEO-1565). (2) BEHAVIOUR, both media, against the LIVE oracle (icont/iconx
# 9.5.25a): a ten-line witness of subscript, section, swap, !, ? and nested-list assignments through record fields and
# list elements -- stdout byte-identical and exit status 0. A witness the oracle does not run refuses the gate.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
ICONT="$(icont_bin)" || { echo "⛔ GATE REFUSE(2) [$G]: the Icon oracle is missing"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
LI="$ROOT/src/lower/lower_icon.c"; [ -f "$LI" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing $LI"; exit 2; }
echo "  HOLDS: a record field under a subscript, a section, ! or ? in an assignable position is a variable, as iconx has it"
sites=$(grep -c 'b0->t == TT_SECTION_MINUS.*b0->t == TT_FIELD' "$LI")
rnd=$(sed -n '/if (t->t == TT_RANDOM && t->n > 0 && t->c\[0\]) {/,/return ae;/p' "$LI" | tr -s ' \n' '  ' | grep -o 'b0->t == TT_FIELD) { IR_t \* e2 = lower_lvalue_var(cx, b0, ω, &ar);' | wc -l)
if [ "$sites" = 4 ] && [ "$rnd" = 1 ]; then echo "  arm 1 PASS: the subscript, section, ! and ? sites all send a record field down the variable path"
else echo "  arm 1 FAIL: sites_naming_a_field=$sites random_site=$rnd (want 4 1)"; RC=1; fi
cat > "$T/w.icn" <<'EOF'
record R(f, g)
procedure main()
   local r, L, x;
   &random := 3;
   r := R("stack", ["ab", "cd"]);
   r.f[1] := "S";
   write(r.f);
   r.f[2:4] := "--";
   write(r.f);
   write(r.f[1] :=: r.f[5], " ", r.f);
   every !r.f := "z";
   write(r.f);
   r.f := "abcdef";
   ?r.f := "Q";
   write(r.f);
   L := ["hello", "world"];
   ?L[1] := "#";
   write(L[1]);
   every !L[2] := "o";
   write(L[2]);
   r.g[1][2] := "Y";
   write(r.g[1]);
   ?r.g := "zz";
   write(r.g[1], r.g[2]);
   x := r.f[3];
   write(x);
end
EOF
( cd "$T" && "$ICONT" -s -o w.x w.icn ) >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: icont refuses the witness"; exit 2; }
want="$( cd "$T" && timeout -k 5 20 ./w.x </dev/null 2>/dev/null )" || { echo "⛔ GATE REFUSE(2) [$G]: the oracle did not run the witness"; exit 2; }
[ -n "$want" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle printed nothing"; exit 2; }
( cd "$T" && "$SCRIP" --compile --out=w.s w.icn </dev/null >/dev/null 2>&1 && gcc -no-pie -o w.4 w.s -L"$ROOT/out" -lscrip_rt -lm -lstdc++ -lpthread -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ) \
  || { echo "⛔ GATE REFUSE(2) [$G]: the witness does not build in mode 4"; exit 2; }
o3="$( cd "$T" && timeout -k 5 20 "$SCRIP" w.icn </dev/null 2>"$T/e3" )"; r3=$?; o4="$( cd "$T" && timeout -k 5 20 ./w.4 </dev/null 2>"$T/e4" )"; r4=$?
if [ "$o3" = "$want" ] && [ "$o4" = "$want" ] && [ "$r3" = 0 ] && [ "$r4" = 0 ]; then echo "  arm 2 PASS: $(printf '%s\n' "$want" | wc -l) lines match iconx byte for byte, rc=0, in both media"
else echo "  arm 2 FAIL: m3 rc=$r3 $( [ "$o3" = "$want" ] && echo same || echo DIFF ) [$(head -c 120 "$T/e3" | tr '\n' ' ')], m4 rc=$r4 $( [ "$o4" = "$want" ] && echo same || echo DIFF )"; RC=1; fi
[ "$RC" = 0 ] && echo "✅ GATE PASS [$G]: 2 of 2 arms hold" || echo "⛔ GATE FAIL [$G]"
exit $RC
