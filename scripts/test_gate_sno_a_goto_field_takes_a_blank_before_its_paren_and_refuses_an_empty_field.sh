#!/usr/bin/env bash
# test_gate_sno_a_goto_field_takes_a_blank_before_its_paren_and_refuses_an_empty_field.sh
#
# THE ROW (ceo CEO-1449, found on the cfo's CODE row 302976d18): snobol4-the-goto-field-refuses-a-blank-before-its-paren-and-
# accepts-an-empty-field-the-reverse-of-spitbol. '        X = 1  :S (L1)' runs in sbl -bf and SCRIP refused the whole program;
# '        X = 1  :' is sbl's compile error 219 and SCRIP compiled and ran it -- both directions wrong under ONE PARSER, ONE DIALECT
# (CEO-1428 (2)). The CODE-only pair folded in: CODE('*comment') and CODE('') compile in sbl and failed in SCRIP.
#
# SPITBOL'S RULE (sbl.min cmp13-cmp31 and scngf; measured on sbl -bf): in a goto field S and F may be followed by blanks before
# their ( or <, and so may the ':' (': S(L1)'); a field ends at its close, so 'S(L1) F(L2)' is two fields; a ':' with no field
# after it is 219, whether a newline, a ';' or blanks follow. A goto continued on the next line ('+' in column 1) is one field.
# CODE of text with no statement ('', ' ', '*comment') compiles; jumping to it runs off its end, which ends the program as a
# CODE block's end always does, and it takes ONE statement number (the implicit end), as a k-statement CODE takes k + 1.
# THE CURE: snobol4.l -- the four S/F goto rules take [ \t]* in their trailing context, and the goto state reports 219 at its
# statement end when no field completed since the ':' (gt_have_operand, which a field's closing ) already set and its closing >
# now sets too: no new state); runtime_eval.c code_at -- CODE('') reaches the parser, a text that parses to no statement and
# captured no error compiles one empty statement, and a CODE whose statements are all empty is not counted.
#
# Every expectation is cut from sbl -bf AT RUN TIME. FAIL-ONCE, MEASURED with this gate on the parent (SCRIP 8f0d5fa04, the cure
# stashed): 11 of 21 arms RED -- the three blank-before-paren gotos (S (, F (, S <) refused; the three empty fields compiled and ran
# ('fell'); CODE('') and CODE('*comment') failed; CODE(' X = 1 :') compiled; &STNO after an empty CODE read 5 where sbl says 6.
# The continued goto and CODE(' ') were already green. On the cure 21/21. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- the expectations are cut from it at run time"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
RT="$B/out"; RC=0; n=0
words() { grep -o 'ERROR [0-9]*\|error [0-9]*\|trapped [0-9]*\|at L1\|at L2\|fell\|in C\|compiled CODE\|before\|ran\|stno [0-9]*' | sed 's/^error /ERROR /' | awk '!seen[$0]++' | tr '\n' '|'; }
m4run() { "$B/scrip" --compile --out="$D/$1.s" "$D/$1.sno" < /dev/null > "$D/$1.c" 2>&1 && gcc -no-pie -o "$D/$1.bin" "$D/$1.s" -L "$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" 2> /dev/null \
          && (cd "$D" && timeout -k 5 10 "./$1.bin" < /dev/null 2>&1) || cat "$D/$1.c"; }
arm() {
    n=$((n + 1)); local w; w=$(cd "$D" && timeout -k 5 10 "$SBL" -bf "$1.sno" < /dev/null 2>&1 | words)
    [ -n "$w" ] || refuse "sbl printed none of the arm's words for $2"
    local g3 g4; g3=$(cd "$D" && timeout -k 5 10 "$B/scrip" ${3:-} "$1.sno" < /dev/null 2>&1 | words); [ -z "${3:-}" ] && g4=$(m4run "$1" | words) || g4="$g3"
    if [ "$w" = "$g3" ] && [ "$w" = "$g4" ]; then echo "  ok    $2 -- $w"; else RC=1; echo "  RED   $2 -- sbl [$w] m3 [$g3] m4 [$g4]"; fi
}
tail_lines="L1      OUTPUT = 'at L1'  :(END)\nL2      OUTPUT = 'at L2'  :(END)\nEND\n"
k=0
while IFS= read -r g; do k=$((k + 1))
    printf "        C = CODE(' OUTPUT = \"in C\"')\n        Y = 'L1'\n        X = 1  %s\n        OUTPUT = 'fell'  :(END)\n$tail_lines" "$g" > "$D/g$k.sno"
    arm "g$k" "goto '$g'"
done <<'EOF'
:S (L1)
:F (L1)S (L2)
: S(L1)
:S(L1) F(L2)
:S(L1)F(L2)
:F(L1)
:S <C>
:<C>
:($Y)
:
:
:;
EOF
printf "        X = 1  :\n+               S(L1)\n        OUTPUT = 'fell'  :(END)\n$tail_lines" > "$D/cont.sno"; arm cont "a goto continued on the next line is one field"
k=0
for t in "''" "' '" "'*comment'"; do k=$((k + 1))
    printf "        C = CODE(%s)   :F(BAD)\n        OUTPUT = 'compiled ' DATATYPE(C)\n        OUTPUT = 'before'\n        :<C>\n        OUTPUT = 'after'  :(END)\nBAD     OUTPUT = 'failed'\nEND\n" "$t" > "$D/e$k.sno"
    arm "e$k" "CODE($t) compiles and running it ends the program"
done
printf "        &ERRLIMIT = 10\n        SETEXIT('h')\n        C = CODE(' X = 1 :')   :S(OK)\n        OUTPUT = 'ran'   :(END)\nOK      OUTPUT = 'fell'  :(END)\nh       OUTPUT = 'trapped ' &ERRTYPE   :(CONTINUE)\nEND\n" > "$D/ce.sno"
arm ce "CODE(' X = 1 :') raises 219"
for c in "-" "' X = 1'" "''" "'*comment'"; do k=$((k + 1))
    { [ "$c" = "-" ] || printf "        C1 = CODE(%s)\n" "$c"; printf "        C2 = CODE(' OUTPUT = \"stno \" &STNO')\n        :<C2>\nEND\n"; } > "$D/s$k.sno"
    arm "s$k" "&STNO in a CODE compiled after $([ "$c" = "-" ] && echo 'no other CODE' || echo "CODE($c)") (--stlimit)" --stlimit
done
[ $RC = 0 ] && echo "GATE PASS(0) [a_goto_field_takes_a_blank_before_its_paren_and_refuses_an_empty_field]: $n arms agree with sbl, both modes"
[ $RC = 0 ] || echo "GATE FAIL(1) [a_goto_field_takes_a_blank_before_its_paren_and_refuses_an_empty_field]: a goto field or an empty CODE differs from sbl"
exit $RC
