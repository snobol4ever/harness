#!/usr/bin/env bash
# test_gate_sno_the_capture_pump_walks_its_fast_entries_in_asm_and_agrees_with_sbl.sh
#
# THE ROW (the speed row string_pattern, 0.82x SPITBOL in the README of 2026-09-26: rt_dcap_pump was 37-41 percent of its instructions): rt_dcap_pump is the C walk of the pending
# conditional captures at a match's success; its fast arm -- a plain-variable target whose cell the 16-slot cache holds, a slice of the subject, two sxt-owner breaks, one 16-byte
# store -- cost about 134 Ir per capture at -O0. THE CURE: rt_dcap_fast_run (rtx_match.s, Intel syntax, the rtcc four preserved by using callee-saved scratch) runs the leading
# fast entries of the walk -- the same tests in the same order, the same cache arrays (now hidden globals) -- and returns the cursor of the first entry that needs the slow arm, a
# star (deferred) target, an empty capture, a cache miss or a corrupt length; rt_dcap_pump takes that entry itself and calls the leaf again after it. MEASURED: string_pattern
# 293.3 M to 232.0 M Ir (300 reps x 1000 matches x 3 captures; the pump region 134 M to 72 M).
# ARMS (expectations cut from sbl -bf AT RUN TIME): one program of eight capture shapes -- the kernel's three BREAK captures, empty captures, twenty distinct targets (the 16-slot
# cache collides), one variable captured twice in a match, a conditional capture backed out by alternation, a deferred star capture, a capture whose target is its own subject, and
# captures after a heap churn that collects -- in mode 3 and mode 4, plain and under SCRIP_GC_STRESS=1.
# rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
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
ok()  { n=$((n + 1)); echo "  ok    $*"; }
red() { n=$((n + 1)); RC=1; echo "  RED   $*"; }
cat > "$D/c.sno" <<'SNO'
        rec = 'alpha,beta,gamma,delta,epsilon'
        pat = BREAK(',') . f1 ',' BREAK(',') . f2 ',' BREAK(',') . f3
        i = 1
loop    rec ? pat
        i = LT(i, 50) i + 1                             :S(loop)
        OUTPUT = 'fields = ' f1 ' ' f2 ' ' f3
* empty captures take the slow arm
        'abc' ? LEN(0) . e1 LEN(1) . e2 LEN(0) . e3
        OUTPUT = '[' e1 '][' e2 '][' e3 ']'
* twenty distinct targets: the 16-slot cache collides
        s = 'abcdefghijklmnopqrst'
        s ? LEN(1) . a1 LEN(1) . a2 LEN(1) . a3 LEN(1) . a4 LEN(1) . a5 LEN(1) . a6 LEN(1) . a7 LEN(1) . a8 LEN(1) . a9 LEN(1) . a10 LEN(1) . a11 LEN(1) . a12 LEN(1) . a13 LEN(1) . a14 LEN(1) . a15 LEN(1) . a16 LEN(1) . a17 LEN(1) . a18 LEN(1) . a19 LEN(1) . a20
        OUTPUT = a1 a2 a3 a4 a5 a6 a7 a8 a9 a10 a11 a12 a13 a14 a15 a16 a17 a18 a19 a20
* the same variable captured twice in one match
        'xyz' ? LEN(1) . dup LEN(1) . dup
        OUTPUT = 'dup=' dup
* a conditional capture that is later backed out
        'abab' ? (LEN(1) . back 'x' | 'ab') LEN(2) . after
        OUTPUT = 'back=' back ' after=' after
* a deferred (star) capture
        w = 'mid'
        'aaa' ? 'a' *IDENT(w, 'mid') . star
        OUTPUT = 'star=' star
* the subject is itself a capture target
        sub = 'hello world'
        sub ? BREAK(' ') . sub
        OUTPUT = 'sub=' sub
* captures keep working after a collection-sized churn
        j = 0
churn   big = DUPL('x', 1000) j
        j = LT(j, 300) j + 1                            :S(churn)
        'one two' ? BREAK(' ') . q1 ' ' REM . q2
        OUTPUT = q1 '|' q2
END
SNO
want="$(cd "$D" && timeout -k 5 60 "$SBL" -bf c.sno < /dev/null 2>&1)"
[ -n "$want" ] || refuse "the oracle printed nothing for the witness"
"$B/scrip" --compile -o "$D/c.s" "$D/c.sno" < /dev/null > /dev/null 2>&1 && gcc -no-pie -o "$D/c.bin" "$D/c.s" -L "$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" 2> /dev/null || refuse "the witness does not build in mode 4"
for env in "" "SCRIP_GC_STRESS=1"; do
  got3="$(cd "$D" && env $env timeout -k 5 120 "$B/scrip" c.sno < /dev/null 2>&1)"
  got4="$(cd "$D" && env $env timeout -k 5 120 ./c.bin < /dev/null 2>&1)"
  if [ "$got3" = "$want" ]; then ok "m3${env:+ ($env)}: $(printf '%s' "$want" | tr '\n' '|' | cut -c1-60)"; else red "m3${env:+ ($env)}: want [$(printf '%s' "$want" | tr '\n' '|' | cut -c1-100)] got [$(printf '%s' "$got3" | tr '\n' '|' | cut -c1-100)]"; fi
  if [ "$got4" = "$want" ]; then ok "m4${env:+ ($env)}: same"; else red "m4${env:+ ($env)}: want [$(printf '%s' "$want" | tr '\n' '|' | cut -c1-100)] got [$(printf '%s' "$got4" | tr '\n' '|' | cut -c1-100)]"; fi
done
nm -D "$RT/libscrip_rt.so" 2>/dev/null | grep -q ' T rt_dcap_fast_run$' && ok "the leaf rt_dcap_fast_run is exported by the runtime" || red "rt_dcap_fast_run is not in the runtime's dynamic symbols"
[ "$RC" -eq 0 ] && echo "GREEN: $n arms" || echo "RED: the capture pump disagrees with sbl, or its asm leaf is missing"
exit "$RC"
