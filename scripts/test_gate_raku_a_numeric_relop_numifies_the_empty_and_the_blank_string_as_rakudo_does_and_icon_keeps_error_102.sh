#!/usr/bin/env bash
# test_gate_raku_a_numeric_relop_numifies_the_empty_and_the_blank_string_as_rakudo_does_and_icon_keeps_error_102.sh -- A RAKU NUMERIC RELOP NUMIFIES "" AND A BLANK STRING
# TO 0, A NON-NUMERIC STRING RAISES THE ONE SCRIP VOICE ON THE CATCHABLE ROAD, AND ICON'S RELOP ON THE SAME INPUTS IS ERROR 102 AS BEFORE (row
# raku-every-suite-to-100-under-nonet-ceo-1266, the master's scrip_test_rk_given18; the cto's answer A to re-ask-raku-relop-numifies-empty-string-shared-rt-jct-relop).
#
# THE DEFECT: "" == 0, " " == 0 and a when arm with a numeric literal on "" stopped the program with error 102 "numeric expected"; Rakudo numifies "" and a blank string to 0.
# THE CURE: the Raku lowerer marks its numeric relop nodes (== != < <= > >=, a when arm with a numeric literal included) with IR_STRICT_RELOP_NUMIFY_BLANK in the node's
# behaviour word; bb_binop_relop and bb_binop_relop_val OR BINOP_F_NUMIFY_BLANK into the op word they pass rt_jct_relop only when the node carries it, so no other language's asm
# moves; rtx_icnrel.s sends a flagged word to C before its dispatch; c_rt_jct_relop masks the bit off and relop_num_coerce numifies the empty and the blank string to 0 under it.
# A non-numeric string under the bit is the one voice, error 102: inside a Raku try it is the pending exception (X::Str::Numeric) and the relop leaves by omega, as die does;
# outside one the voice reports and the program exits 1.
# ARMS, each in m3 and m4:
#   1 relop: Rakudo's answers (ref cut by /usr/bin/raku) -- True True True for "" == 0, " " == 0 and "" < 1, a blank and a whitespace-padded number, the when arm on "" with
#     a numeric literal not taken (False), the when arm on " " with 0 taken, a caught non-numeric compare naming X::Str::Numeric with nothing printed in its statement, a try
#     whose value is a raising relop left undefined, and a numeric relop in an if condition
#   2 voice: an uncaught "abc" == 0 prints what came before it, then the one voice (error 102, numeric expected, offending value "abc") on stderr, and exits 1
#   3 icon: "" = 0 and " " = 0 in Icon are still error 102 with the offending value, exit 1, the line before printed
#   4 the flag rides only a Raku relop: the Raku witness's mode-4 asm passes rt_jct_relop an op word with BINOP_F_NUMIFY_BLANK set, and the Icon witness's never does
# FAILED ONCE, measured on SCRIP dbd4b7cf1 before the cure: arm 1 died at its first line with error 102 in both modes; arm 4 found no flagged op word; arms 2 and 3
# (the voice and Icon) passed there too, which is what "unchanged" means.
#
# EXIT: 0 every arm holds in both modes; 1 a mismatch or a crash; 2 REFUSED (stale binary, no gcc).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_a_numeric_relop_numifies_the_empty_and_the_blank_string_as_rakudo_does_and_icon_keeps_error_102"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/relop.raku" <<'EOF'
say "" == 0;
say " " == 0;
say "" < 1;
my $e = "";
say $e == 0;
say "\t\n" == 0;
say " 12 " == 12;
say "" != 0;
my $w = False;
given "" { when 1 { $w = True } }
say $w;
my $v = ' ';
given $v { when 0 { say "zero" }; default { say "other" } }
try { say "abc" == 0 };
say $!.^name;
my $z = try { "abc" < 1 };
say $z.defined;
if "" == 0 { say "cond-true" } else { say "cond-false" }
say "after";
EOF
cat > "$W/relop.ref" <<'EOF'
True
True
True
True
True
True
False
False
zero
X::Str::Numeric
False
cond-true
after
EOF
printf 'say "x";\nsay "abc" == 0;\nsay "not reached";\n' > "$W/voice.raku"
printf 'procedure main();\n  write("x");\n  write("" = 0);\n  write("y");\nend\n' > "$W/icon.icn"
printf 'procedure main();\n  write(" " = 0);\nend\n' > "$W/iconb.icn"
fails=0; GATE_EXAMINED=0
run() {
    local src="$1" m="$2" base="${1%.*}"
    if [ "$m" = m3 ]; then timeout -k 5 60 "$ROOT/scrip" --run "$W/$src" >"$W/$base.$m.out" 2>"$W/$base.$m.err" </dev/null; return $?; fi
    if ! timeout -k 5 60 "$ROOT/scrip" --compile --out="$W/$base.s" "$W/$src" </dev/null >"$W/$base.cerr" 2>&1 \
       || ! gcc -o "$W/$base.bin" "$W/$base.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >>"$W/$base.cerr" 2>&1; then
        printf '  FAIL %-7s %s: did not build (%s)\n' "$base" "$m" "$(head -1 "$W/$base.cerr" | cut -c1-110)"; return 255; fi
    timeout -k 5 60 "$W/$base.bin" >"$W/$base.$m.out" 2>"$W/$base.$m.err" </dev/null
}
for m in m3 m4; do
    GATE_EXAMINED=$((GATE_EXAMINED + 1)); run relop.raku "$m"; rc=$?
    if [ "$rc" -eq 0 ] && cmp -s "$W/relop.$m.out" "$W/relop.ref"; then printf '  ok   relop   %s\n' "$m"
    else printf '  FAIL relop   %s: rc=%s got [%s] want [%s]\n' "$m" "$rc" "$(tr '\n' ' ' < "$W/relop.$m.out" | cut -c1-110)" "$(tr '\n' ' ' < "$W/relop.ref" | cut -c1-110)"; fails=$((fails + 1)); fi
    GATE_EXAMINED=$((GATE_EXAMINED + 1)); run voice.raku "$m"; rc=$?
    if [ "$rc" -eq 1 ] && [ "$(cat "$W/voice.$m.out")" = "x" ] && grep -q 'error 102: numeric expected' "$W/voice.$m.err" && grep -q 'offending value: "abc"' "$W/voice.$m.err"; then
        printf '  ok   voice   %s\n' "$m"
    else printf '  FAIL voice   %s: rc=%s stdout [%s] stderr [%s]\n' "$m" "$rc" "$(tr '\n' ' ' < "$W/voice.$m.out")" "$(tr '\n' ' ' < "$W/voice.$m.err" | cut -c1-110)"; fails=$((fails + 1)); fi
    for t in icon:'""':x iconb:'" "':; do
        b="${t%%:*}"; r="${t#*:}"; ov="${r%:*}"; want="${r##*:}"
        GATE_EXAMINED=$((GATE_EXAMINED + 1)); run "$b.icn" "$m"; rc=$?
        if [ "$rc" -eq 1 ] && [ "$(cat "$W/$b.$m.out")" = "$want" ] && grep -q 'error 102: numeric expected' "$W/$b.$m.err" && grep -qF "offending value: $ov" "$W/$b.$m.err"; then
            printf '  ok   %-7s %s\n' "$b" "$m"
        else printf '  FAIL %-7s %s: rc=%s stdout [%s] stderr [%s]\n' "$b" "$m" "$rc" "$(tr '\n' ' ' < "$W/$b.$m.out")" "$(tr '\n' ' ' < "$W/$b.$m.err" | cut -c1-110)"; fails=$((fails + 1)); fi
    done
done
GATE_EXAMINED=$((GATE_EXAMINED + 1))
flag=$(( 0x100 ))
nr=$(grep -cE "mov +r8d, *($((flag | 5))|$((flag | 6))|$((flag | 7))|$((flag | 8))|$((flag | 9))|$((flag | 10)))\b" "$W/relop.s" 2>/dev/null)
ni=$(cat "$W/icon.s" "$W/iconb.s" 2>/dev/null | grep -cE "mov +r8d, *($((flag | 5))|$((flag | 6))|$((flag | 7))|$((flag | 8))|$((flag | 9))|$((flag | 10)))\b")
if [ "${nr:-0}" -gt 0 ] && [ "${ni:-0}" -eq 0 ]; then printf '  ok   flag    the Raku asm passes %s flagged op word(s), the Icon asm none\n' "$nr"
else printf '  FAIL flag    the Raku asm passes %s flagged op word(s) (want >0), the Icon asm %s (want 0)\n' "${nr:-0}" "${ni:-0}"; fails=$((fails + 1)); fi
gate_verdict "$fails" "arm-mode pair(s) wrong: a Raku relop that disagrees with Rakudo, a voice that moved, an Icon relop that changed, or a flag on the wrong language"
