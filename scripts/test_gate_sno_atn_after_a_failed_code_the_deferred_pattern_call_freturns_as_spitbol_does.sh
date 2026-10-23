#!/usr/bin/env bash
# test_gate_sno_atn_after_a_failed_code_the_deferred_pattern_call_freturns_as_spitbol_does.sh
#
# THE WITNESS (ceo 2026-10-17, CEO-1811; found through the coo's AIS ATN red of 2026-10-15, bisected by hq_runtime to 1a36cb772): aisnobol's ATN compiles each FUNCTION of its network source with
# CODE() from inside a pattern match -- S_ is the deferred target of NULL $ *S_('F') in a pattern built by EVAL, S_ reaches S_F by the computed goto :($('S_' NA)), and when CODE fails S_F
# calls ERROR and leaves by FRETURN. This gate feeds ATN its own ATN.IN with one FUNCTION body made a syntax error that sbl -bf also rejects (LEXICAL_FEATURES[X) for LEXICAL_FEATURES[X]):
# sbl -bf prints Compilation error, Compilation failed and FATAL ERROR and exits 0; SCRIP stops after Compilation error with SIGSEGV, a jump to an address inside the live GC heap (ZGC-STALE).
# The answer is cut from sbl -bf at run time; the two wall-clock lines ATN prints are masked as ALL.mask masks them. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
# THE REGRESSION (cfo 2026-10-23, row snobol4-atn-segfaults-again-...-ceo-1926): ATN read red again from e53f5dcd6 (THE SPINE FLIP; bisected from e71e5253b), and two smaller witnesses carry the two
# defects it exposed. sto: a FENCE'd capture stored as its own pattern, A = (LEN(1) $ V) FENCE, then 'xyz' A 'q' -- the outer 'q' fails, re-enters the stored blob at its beta, and that entry jumped
# to the on-spine MATCH_ABORT without popping the capture's save cell its gamma had kept, so the abort's exit read the blob frame's DT_P word as its continuation. two: P = (LEN(1) $ V) FENCE
# (LEN(1) $ W) 'q' -- the second capture's inner beta was folded through its save's beta (the ZPOP fold) with the save's own cell but not its fence whack-pop (zd_wp), 16 bytes short; red on
# 2f03e45cf too. Both answer failed under sbl -bf; both SIGSEGV'd into the GC heap in both modes before the cure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
C="${CORPUS:-$B/../corpus}"
P="$C/packages/snobol4/aisnobol"
SBL="${SBL:-/home/resources/x64/bin/sbl}"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
[ -x "$SBL" ] || refuse "the SNOBOL4 oracle $SBL is absent -- the answer cannot be cut"
[ -f "$P/ATN.sno" ] && [ -f "$P/ATN.IN" ] || refuse "$P/ATN.sno or ATN.IN is absent"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cp "$P/ATN.sno" "$D/ATN.sno"
sed 's/LEXICAL_FEATURES[<[]X[]>]/LEXICAL_FEATURES[X)/' "$P/ATN.IN" > "$D/in"
grep -q 'LEXICAL_FEATURES\[X)' "$D/in" || refuse "ATN.IN no longer carries GETF's LEXICAL_FEATURES subscript -- the witness was not formed"
mask() { sed -E 's/^[0-9]+ milliseconds (compile time|used)$/N milliseconds \1/' "$1"; }
( cd "$D" && timeout -k 5 60 "$SBL" -bf ATN.sno < in > want.raw 2>&1; echo $? > want.rc )
mask "$D/want.raw" > "$D/want"
grep -q 'FATAL ERROR' "$D/want" || refuse "sbl -bf did not reach the lines after the failed CODE -- the oracle's answer does not measure the continuation"
red=0
arm() { if [ "$2" = ok ]; then echo "  ok   $1"; else echo "  FAIL $1: $2"; red=$((red + 1)); fi; }
( cd "$D" && timeout -k 5 60 "$B/scrip" -d131072k -s4096k --stlimit ATN.sno < in > m3.raw 2> m3.err; echo $? > m3.rc )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --stlimit -o m4.s ATN.sno < /dev/null 2> m4.cerr && gcc m4.s -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o m4.bin 2>> m4.cerr \
  && timeout -k 5 60 ./m4.bin -d131072k -s4096k < in > m4.raw 2> m4.err; echo $? > m4.rc )
for m in m3 m4; do
    mask "$D/$m.raw" > "$D/$m"
    if cmp -s "$D/want" "$D/$m" && [ "$(cat "$D/$m.rc")" = "$(cat "$D/want.rc")" ]; then arm "ATN $m equals sbl -bf ($(wc -l < "$D/want") lines, rc $(cat "$D/want.rc"))" ok
    else arm "ATN $m" "rc $(cat "$D/$m.rc") (sbl $(cat "$D/want.rc")), $(wc -l < "$D/$m") of $(wc -l < "$D/want") lines, first divergence: $(diff "$D/want" "$D/$m" | head -3 | tr '\n' '|' | cut -c1-160) $(head -1 "$D/$m.err" | cut -c1-120)"; fi
done
printf "        P = ('' \$ *V) FENCE 'q'\n        'xyz' P                         :S(Y)F(N)\nY       OUTPUT = 'ok'                   :(END)\nN       OUTPUT = 'failed'\nEND\n" > "$D/val.sno"
printf "        'xyz' ('' \$ *V) FENCE 'q'        :S(Y)F(N)\nY       OUTPUT = 'ok'                   :(END)\nN       OUTPUT = 'failed'\nEND\n" > "$D/inl.sno"
printf "        P = (LEN(1) \$ V) FENCE (LEN(1) \$ W) 'q'\n        'xyz' P                         :S(Y)F(N)\nY       OUTPUT = 'ok'                   :(END)\nN       OUTPUT = 'failed'\nEND\n" > "$D/two.sno"
printf "        A = (LEN(1) \$ V) FENCE\n        'xyz' A 'q'                     :S(Y)F(N)\nY       OUTPUT = 'ok'                   :(END)\nN       OUTPUT = 'failed'\nEND\n" > "$D/sto.sno"
desc() { case "$1" in val) echo "P = ('' \$ *V) FENCE 'q'";; inl) echo "inline ('' \$ *V) FENCE 'q'";; two) echo "P = (LEN(1) \$ V) FENCE (LEN(1) \$ W) 'q'";; sto) echo "A = (LEN(1) \$ V) FENCE then A 'q'";; esac; }
for w in val inl two sto; do
    ( cd "$D" && timeout -k 5 10 "$SBL" -bf $w.sno < /dev/null > $w.want 2>&1 )
    [ "$(cat "$D/$w.want")" = failed ] || refuse "sbl -bf answered [$(tr '\n' '|' < "$D/$w.want")] for the $w witness, not failed"
    ( cd "$D" && timeout -k 5 10 "$B/scrip" $w.sno < /dev/null > $w.m3 2> $w.m3.err )
    ( cd "$D" && timeout -k 5 60 "$B/scrip" --compile -o $w.s $w.sno < /dev/null 2> $w.cerr && gcc $w.s -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o $w.bin 2>> $w.cerr && timeout -k 5 10 ./$w.bin < /dev/null > $w.m4 2> $w.m4.err )
    for m in m3 m4; do
        if cmp -s "$D/$w.want" "$D/$w.$m"; then arm "the $w witness $(desc $w) $m prints failed as sbl -bf does" ok
        else arm "the $w witness $m" "got [$(tr '\n' '|' < "$D/$w.$m")] $(head -1 "$D/$w.$m.err" | cut -c1-100)"; fi
    done
done
if [ "$red" -eq 0 ]; then echo "GATE PASS(0) [sno_atn_failed_code_deferred_freturn]: 10 of 10 arms equal sbl -bf (ATN, the pattern-value witness and its inline control, the two-capture and stored-fence witnesses, both modes)"; exit 0; fi
echo "GATE FAIL(1) [sno_atn_failed_code_deferred_freturn]: $red of 10 arms diverge from sbl -bf"; exit 1
