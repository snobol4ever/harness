#!/usr/bin/env bash
# test_gate_raku_a_method_whose_first_statement_is_a_literal_is_compiled_not_read_as_a_parameter_agree_with_rakudo.sh -- A METHOD OR SUBMETHOD WHOSE FIRST BODY STATEMENT IS A NUMERIC LITERAL (`method m($x) { 5; $x }`) OR A LEXICAL REGEX DECLARATION CRASHED THE COMPILER (rc 139)
# (red reported by the coo's loop, pass 43: test_gate_raku_a_named_sub_nested_in_a_sub_reads_and_writes_the_enclosing_locals_through_a_reference.sh arm 4 FAIL regex.t "the compiler died (rc=139)"; bisected to the nested-class landing d86c798d4, which made classes declared below the top level reachable).
#
# THE DEFECT, measured against Rakudo: rk_stage2_core reads the parameter names of a method from the children of its tree. For a method the parameter count includes `self`, so the loop reads ONE NODE PAST THE PARAMETERS -- the first statement of the body -- and took that node's v.sval as a name. That is a string pointer
# for most nodes (so the first call statement of a method silently became a spurious extra parameter slot) but an INTEGER or a DOUBLE in the same union for a numeric literal and for a TT_REGEX_DECL: lp_strdup(0x5) segfaulted. `class A { method m($x) { 5; $x } }` and `method f($x) { 5.5; $x }` died at rc 139 (strlen on the literal); Roast S05-metasyntax/regex.t
# (`my regex anything { . }` as the first statement of a sub in a class, a method, a submethod) died the same way once the class was reachable; the earlier cure (137f4d712) had guarded only the capture pass.
# THE CURE: (lower_raku.c rk_stage2_core, the scope-building loop) only a TT_VAR can be a parameter name; every other node is skipped, so the spurious extra slot is gone and nothing reads a literal as a pointer.
# NOT HERE (own rows, measured): the lexical regex declaration in a sub or method is still REFUSED by the native emitter ("variable 'input' is read but never assigned": a plain sub inside a class does not see its own parameter), so S05-metasyntax/regex.t does not compile yet; it no longer crashes the compiler (arm 4 of the nested-sub gate).
#
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku; its "Useless use of constant" warnings are on stderr), then under SCRIP_GC_STRESS 1 3 5 in both modes.
# FAILED ONCE, measured on SCRIP 5a99db741 before the cure: every witness-mode pair red (the compiler died).
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_a_method_whose_first_statement_is_a_literal_is_compiled_not_read_as_a_parameter_agree_with_rakudo.sh   (~10s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_a_method_whose_first_statement_is_a_literal_is_compiled_not_read_as_a_parameter_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.raku" <<'EOF'
class A {
    method m($x) { 5; $x }
    method f($x) { 5.5; $x }
    method s($x) { "s"; $x }
    method t($x) { 7; $x * 2 }
    method u($x, $y) { 1; 2; $x + $y }
}
say A.new.m(3);
say A.new.f(4);
say A.new.s(5);
say A.new.t(6);
say A.new.u(1, 2);
class B {
    submethod BUILD { 9; }
    method z { 11; 12 }
}
say B.new.z;
EOF
cat > "$W/w.ref" <<'EOF'
3
4
5
12
3
12
EOF
fails=0; GATE_EXAMINED=0
ck() {
    local w="$1" m="$2" out rc
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(env ${ST:+SCRIP_GC_STRESS=$ST} timeout -k 5 120 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; rc=$?
    else
        if ! timeout -k 5 60 "$ROOT/scrip" --compile --out="$W/$w.s" "$W/$w.raku" </dev/null >"$W/$w.cerr" 2>&1 \
           || ! gcc -o "$W/$w.bin" "$W/$w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >>"$W/$w.cerr" 2>&1; then
            printf '  FAIL %-7s %s: did not build (%s)\n' "$w" "$m" "$(head -1 "$W/$w.cerr" | cut -c1-110)"; fails=$((fails + 1)); return; fi
        out="$(env ${ST:+SCRIP_GC_STRESS=$ST} timeout -k 5 120 "$W/$w.bin" 2>/dev/null </dev/null)"; rc=$?
    fi
    if [ "$rc" -ge 124 ]; then printf '  FAIL %-7s %s: died rc=%s\n' "$w" "$m" "$rc"; fails=$((fails + 1)); return; fi
        if [ "$out" = "$(cat "$W/$w.ref")" ]; then printf '  ok   %-7s %s%s\n' "$w" "$m" "${ST:+ stress=$ST}"
    else printf '  FAIL %-7s %s: got [%s] want [%s]\n' "$w" "$m" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-110)" "$(tr '\n' ' ' < "$W/$w.ref" | cut -c1-110)"; fails=$((fails + 1)); fi
}
ST=""; for w in w; do for m in m3 m4; do ck "$w" "$m"; done; done
for ST in 1 3 5; do for w in w; do for m in m3 m4; do ck "$w" "$m"; done; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: a method-with-leading-literal result that disagrees with Rakudo"
