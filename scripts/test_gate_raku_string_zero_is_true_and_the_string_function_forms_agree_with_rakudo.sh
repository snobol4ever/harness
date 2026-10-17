#!/usr/bin/env bash
# test_gate_raku_string_zero_is_true_and_the_string_function_forms_agree_with_rakudo.sh -- THE STRING "0" IS TRUE, lc / uc / split / comb / first / words / not / hash / slip / sleep / val AS FUNCTIONS, AND substr WITH WhateverCode ARGUMENTS
# (row raku-every-suite-to-100-under-nonet-ceo-1266; found by reading the 100 failing assertions of S32-str and the 114 "undefined function called" aborts across the 900 Roast files that compile).
#
# THE DEFECTS, each measured against Rakudo: ?'0', so '0' and '0'.Bool were False (the runtime kept Perl's rule; Raku's only false strings are the empty one -- ?'00' was already True); lc("ÅÄÖ") and uc("åäö") as FUNCTIONS went to an
# ASCII builtin and returned the argument unchanged while the methods were right; split(",", $s), comb(2, $s), first(&f, @l), words($s), not($x), hash(a => 1), slip(...), sleep(n) and val($s) had no function form ("undefined function called" in 114 Roast aborts, 8 of them
# `sleep`, 5 `hash`); and substr($s, *-4, *-1) handed the WhateverCode closure to a string routine that wanted an Int (S32-str/substr.t failed 17).
# THE CURE (by_name_dispatch.c, lower_raku.c): the three truthiness entries (rk_is_truthy, __rk_bool / __rk_bool_val, __rk_mkbool) treat any non-empty string as true; lc / uc / samecase join rk_is_str_subform (function to method on the first argument); the lowerer
# rewrites split / comb / first / roll (arguments swapped) and words to the method on their string or list, not() to the negation node, hash() and slip() to the array constructor behind __rk_to_hash / .Slip, the named form hash(a => 1) in __rk_named_call, and
# sleep / val are builtins; a .substr / .substr-rw whose argument is a hoisted WhateverCode block calls it with the receiver's .chars (the length argument with the characters remaining after the start), an emitted call, never one from C.
# Also here: the match literals m{...}, m(...), m[...], m<...> and m!...! were strings handed to the smartmatch (S05-match/non-capturing.t passed test 4 by accident, both sides empty); they are regexes now.
# NOT HERE (own rows): X / Z returning nested lists, zip() as a function, .roll, .encode (Buf), IntStr / RatStr allomorphs (val gives Int / Num), gcd / lcm as functions, unival / chrs / bytes.
#
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku), then under SCRIP_GC_STRESS 1 3 5 in both modes.
# FAILED ONCE, measured on SCRIP 8de60be25 before the cure: 8 of 8 witness-mode pairs red (the first undefined function aborts the program).
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_string_zero_is_true_and_the_string_function_forms_agree_with_rakudo.sh   (~8s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_string_zero_is_true_and_the_string_function_forms_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/ff.raku" <<'EOF'
say ?'0'; say ?'00'; say ?''; say so '0'; say '0'.Bool; say ('0' ?? "t" !! "f"); say !'0'; say (not '0'); say not(0); say not(1);
say lc("ÅÄÖ"); say uc("åäö"); say lc("ABC"); say uc("abc"); say uc("ß");
my $str = "foobar";
say substr($str, *-1); say substr($str, *-4, 2); say substr($str, 0, *-2); say substr($str, 2, *-2); say substr($str, *-4, *-1);
say $str.substr(*-3); say $str.substr(1, 3); say substr($str, 3); say $str;
say split(",", "a,b,c").join("|"); say comb(2, "abcdef").join("|"); say first({ $_ > 1 }, (1,2,3)); say words("a b  c").join(",");
say hash(a=>1,b=>2).elems; say hash(a=>1,b=>2){"b"}; say hash((c=>3)).keys;
say slip(1,2,3).elems;
say sleep(0); say sleep 0.001;
say val("3") + 1; say val("abc");
my $ms = "abbc"; say ($ms ~~ m{a(b+)c}) ?? "brace" !! "no"; say $/[0];
EOF
cat > "$W/ff.ref" <<'EOF'
True
True
False
True
True
t
False
False
True
False
åäö
ÅÄÖ
abc
ABC
SS
r
ob
foob
ob
oba
bar
oob
bar
foobar
a|b|c
ab|cd|ef
2
a,b,c
2
2
(c)
3
Nil
Nil
4
abc
brace
｢bb｣
EOF
fails=0; GATE_EXAMINED=0
ck() {
    local w="$1" m="$2" out rc
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(env ${ST:+SCRIP_GC_STRESS=$ST} timeout -k 5 120 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; rc=$?
    else
        if ! timeout -k 5 60 "$ROOT/scrip" --compile -o "$W/$w.s" "$W/$w.raku" </dev/null >"$W/$w.cerr" 2>&1 \
           || ! gcc -o "$W/$w.bin" "$W/$w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >>"$W/$w.cerr" 2>&1; then
            printf '  FAIL %-7s %s: did not build (%s)\n' "$w" "$m" "$(head -1 "$W/$w.cerr" | cut -c1-110)"; fails=$((fails + 1)); return; fi
        out="$(env ${ST:+SCRIP_GC_STRESS=$ST} timeout -k 5 120 "$W/$w.bin" 2>/dev/null </dev/null)"; rc=$?
    fi
    if [ "$rc" -ge 124 ]; then printf '  FAIL %-7s %s: died rc=%s\n' "$w" "$m" "$rc"; fails=$((fails + 1)); return; fi
        if [ "$out" = "$(cat "$W/$w.ref")" ]; then printf '  ok   %-7s %s%s\n' "$w" "$m" "${ST:+ stress=$ST}"
    else printf '  FAIL %-7s %s: got [%s] want [%s]\n' "$w" "$m" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-110)" "$(tr '\n' ' ' < "$W/$w.ref" | cut -c1-110)"; fails=$((fails + 1)); fi
}
ST=""; for w in ff; do for m in m3 m4; do ck "$w" "$m"; done; done
for ST in 1 3 5; do for w in ff; do for m in m3 m4; do ck "$w" "$m"; done; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: a truthiness, string-function-form or substr result that disagrees with Rakudo"
