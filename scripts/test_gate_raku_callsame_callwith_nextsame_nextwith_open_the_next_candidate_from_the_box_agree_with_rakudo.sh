#!/usr/bin/env bash
# test_gate_raku_callsame_callwith_nextsame_nextwith_open_the_next_candidate_from_the_box_agree_with_rakudo.sh -- THE REDISPATCH WORDS ARE AN OPEN ROAD, NOT A C ROAD INTO A BOX
# (row raku-every-suite-to-100-under-nonet-ceo-1266; CEO-1576, Lon 2026-10-09 verbatim: "It is easy to fix; instead of in C jumping to a BB, just return the address and have the BB that called
# the C function do the jump instead.").
#
# THE DEFECT: callsame / nextsame / callwith / nextwith inside a method were by-name builtins whose C arm built a redispatch record in its own C frame, found the next candidate in the MRO and
# entered it through invoke_method_proc -> rt_call_proc_descr. CEO-1576 deleted that C road into a box, so every redispatch died (rt_call_proc_descr: A__g reached a C road into a box, DELETED;
# rc 139): RakRungs class_method_say_replace_11 12 13 14 16 36.
# THE CURE, the meth_call open road of CEO-1552 widened to the four words: frame_layout.c grants a redispatch call site the argv plus RK_REDISP_REC_SLOTS (the record meth_call carries);
# bb_call_fn.cpp's open arm (bcfn_method_open_enter, now given its open function) calls by_name_dispatch.c rk_callsame_open / rk_callwith_open, which find the next candidate after the
# enclosing record's found_idx, fill the frame record (callwith keeps self in the record and its own arguments in the grant: skip_mname 2), chain it from g_redisp_cur and RETURN THE ADDRESS
# of the candidate's entry; the box enters it and lands through rk_method_land_gamma / _omega, which unchain the record. No candidate: the open declines and the C arm answers Nil (it answered
# a failure, so `(callsame) // "none"` printed nothing). A candidate that cannot be opened by address still meets the named bomb.
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku), with SCRIP_C2BB_TRACE on every run and the entry count required to be 0, then under
# SCRIP_GC_STRESS 1 3 5 in both modes: callsame through three classes, callwith with new arguments, nextsame and nextwith (which do not return), callsame as a statement, callsame with no next
# candidate, a three-level chain reading an attribute, callwith with two arguments, and 300 iterations of two chains so the collector runs while records are chained.
# FAILED ONCE, measured on SCRIP c5b26a2a8 before the cure: rc 139 at the first callsame in both modes.
#
# EXIT: 0 every witness matches in both modes with 0 entries; 1 a mismatch, a crash or an entry; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_callsame_callwith_nextsame_nextwith_open_the_next_candidate_from_the_box_agree_with_rakudo.sh   (~10s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_callsame_callwith_nextsame_nextwith_open_the_next_candidate_from_the_box_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/redisp.raku" <<'EOF'
class A { method g($x) { "A($x)" }; method h() { "A.h" } }
class B is A { method g($x) { "B($x)+" ~ callsame() }; method h() { "B.h>" ~ nextsame() } }
class C is B { method g($x) { "C($x)+" ~ callwith($x * 10) } }
say C.new.g(2);
say B.new.h;
class D is A { method g($x) { my $r = callsame; "D:" ~ $r } }
say D.new.g(7);
class E is A { method g($x) { "E" ~ nextwith($x + 1) } }
say E.new.g(1);
class F { method g() { (callsame) // "none" } }
say F.new.g;
class Base { has $.n; method describe() { "Base n=" ~ $!n } }
class Mid is Base { method describe() { "Mid/" ~ callsame() } }
class Top is Mid { method describe() { "Top/" ~ callsame() } }
say Top.new(n => 4).describe;
class Acc { method add($a, $b) { $a + $b } }
class Acc2 is Acc { method add($a, $b) { 100 + callwith($a * 2, $b * 2) } }
say Acc2.new.add(3, 4);
my $total = 0;
for 1..300 -> $i { $total += C.new.g($i).chars; $total += Top.new(n => $i).describe.chars }
say $total;
EOF
cat > "$W/redisp.ref" <<'EOF'
C(2)+B(20)+A(20)
A.h
D:A(7)
A(2)
none
Top/Mid/Base n=4
114
11568
EOF
fails=0; GATE_EXAMINED=0
ck() {
    local w="$1" m="$2" out rc ent
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(env ${ST:+SCRIP_GC_STRESS=$ST} SCRIP_C2BB_TRACE="$W/$w.$m.tr" timeout -k 5 120 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; rc=$?
    else
        if ! timeout -k 5 60 "$ROOT/scrip" --compile -o "$W/$w.s" "$W/$w.raku" </dev/null >"$W/$w.cerr" 2>&1 \
           || ! gcc -o "$W/$w.bin" "$W/$w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >>"$W/$w.cerr" 2>&1; then
            printf '  FAIL %-7s %s: did not build (%s)\n' "$w" "$m" "$(head -1 "$W/$w.cerr" | cut -c1-110)"; fails=$((fails + 1)); return; fi
        out="$(env ${ST:+SCRIP_GC_STRESS=$ST} SCRIP_C2BB_TRACE="$W/$w.$m.tr" timeout -k 5 120 "$W/$w.bin" 2>/dev/null </dev/null)"; rc=$?
    fi
    if [ "$rc" -ne 0 ]; then printf '  FAIL %-7s %s%s: died rc=%s\n' "$w" "$m" "${ST:+ stress=$ST}" "$rc"; fails=$((fails + 1)); return; fi
    ent=0; [ -s "$W/$w.$m.tr" ] && ent=$(grep -c . "$W/$w.$m.tr"); rm -f "$W/$w.$m.tr"
    if [ "$ent" != 0 ]; then printf '  FAIL %-7s %s: %s C-to-BB entries (want 0)\n' "$w" "$m" "$ent"; fails=$((fails + 1)); return; fi
    if [ "$out" = "$(cat "$W/$w.ref")" ]; then printf '  ok   %-7s %s%s\n' "$w" "$m" "${ST:+ stress=$ST}"
    else printf '  FAIL %-7s %s%s: got [%s] want [%s]\n' "$w" "$m" "${ST:+ stress=$ST}" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-110)" "$(tr '\n' ' ' < "$W/$w.ref" | cut -c1-110)"; fails=$((fails + 1)); fi
}
ST=""; for w in redisp; do for m in m3 m4; do ck "$w" "$m"; done; done
for ST in 1 3 5; do for w in redisp; do for m in m3 m4; do ck "$w" "$m"; done; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: a redispatch that disagrees with Rakudo, a crash, or a C-to-BB entry the redispatch still makes"
