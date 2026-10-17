#!/usr/bin/env bash
# test_gate_no_language_discriminator_in_the_runtime.sh -- the runtime must not decide LANGUAGE IDENTITY
# from the VALUE of a global, and the Icon errors that identity currently gates must keep raising.
#
# WHY THIS EXISTS (row icon-a-language-discriminator-in-the-runtime-gates-whether-errors-are-raised-at-all,
# hq_I census, ceo-verified, hq_U co-signing). src/runtime/core/core.c carries:
#     int core_icn_active(void) { extern long g_stno; extern long g_line; return g_stno == 0 && g_line > 0; }
# and 22 sites across six runtime files branch on it to decide whether Icon run-time errors 201 202 204
# 101 103 110 113 114 are RAISED AT ALL. That is language identity smuggled through two unrelated globals'
# values, past the frontend/lower boundary.
#
# ⛔ THE FAILURE MODE IS WHY THIS IS A GATE AND NOT A CLEANUP. If the discriminator ever reads false under
# Icon, nothing crashes and no board blanks: the errors simply stop being raised and programs return wrong
# values with rc=0. hq_U MEASURED it rather than predicting it -- with the discriminator forced false,
# `pos("a")` under `&error := -1` prints "pos SUCCEEDED", &error stays -1, &errornumber is never recorded,
# and the program exits 0 with a full plausible output.
#
# ⛔ AND THE GUARDS OVERLAP UNEVENLY (hq_U, measured): `tab`/`move` are checked in BOTH icn_argtype_gate
# (NOT guarded by core_icn_active) and core_icn_builtin_argcheck (guarded), so a regression here would not
# break cleanly -- it would shift SOME error numbers and not others, which on a counting file like
# errors.icn reads as mysterious partial drift rather than a switch being off. That is exactly why ARM B
# is BEHAVIOURAL AND PER-ERROR-NUMBER rather than a count: a count cannot tell those two apart.
#
# ⭐ THE SHARPER REASON, EARNED ON THIS GATE'S OWN AUTHOR (hq_I 2026-09-12): a first attempt at the cure
# regressed 202 to 201 and made 204 vanish. To a COUNT that reads "2 of 8 wrong", which sends the next
# author hunting two raises that went missing. What actually happened is that MOD COLLAPSED ONTO DIV --
# one raise was ABSORBED by its neighbour, not lost. A count cannot distinguish a raise that VANISHED
# from one that was ABSORBED, and those two want opposite cures. Per-number arms can, and did, in one run.
#
# ⛔ ON WHAT IS DELIBERATELY *NOT* PINNED: freezing a live defect into a criterion makes fixing it look
# like a regression. The string-builtin route to 103 is a known open defect with its own row, so ARM B
# grades the SCAN route and this header names the gap instead of the gate asserting it.
#
# ⭐ ANCHORED ON THE ORACLE, NOT ON OUR OWN OUTPUT (CEO-554). Every ARM B witness is run through iconx in
# the same invocation and SCRIP is compared against THAT, so curing anything moves both sides together and
# no cure can invalidate this instrument. hq_U lost an open gate this week to exactly that trap.
#
# ⛔ WHAT THIS GATE CAN AND CANNOT DETECT, stated because the gate it replaces did not say so and was
# believed to cover this. test_gate_emit_no_lang.sh scopes to src/emitter and src/templates and greps for
# language-identity NAMES; it is structurally blind here on both counts. ARM A looks in src/runtime and
# matches a PREDICATE SHAPE, which is stronger -- but it is still a source scan, and a discriminator
# spelled a third way would pass it. ARM B is the part that cannot be fooled by spelling.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
NAME=no_language_discriminator_in_the_runtime
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
. "$HERE/lib_gate.sh"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || refuse "lib_oracle_flags.sh unloadable -- cannot reach the Icon oracle"
ICONT="$(icont_bin 2>/dev/null || true)"
[ -n "$ICONT" ] && [ -x "$ICONT" ] || refuse "no icont oracle -- ARM B compares against iconx and REFUSES rather than grading against our own output"
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
fails=0; checks=0
say() { printf '%s\n' "$*"; }
say "=== ARM A -- src/runtime carries no predicate deciding language identity from a global's VALUE ==="
# The known shape, and the general one: a boolean expression combining the SNOBOL4 statement counter with
# the line cursor is a language test however it is spelled or named.
hits="$(grep -rnE 'g_stno[^;]*(==|!=|<|>)[^;]*&&[^;]*g_line|g_line[^;]*&&[^;]*g_stno' "$ROOT/src/runtime" --include=*.c --include=*.h 2>/dev/null || true)"
named="$(grep -rnE '\b(core_icn_active|core_sno_active|core_pl_active)\s*\(\s*void\s*\)\s*\{' "$ROOT/src/runtime" --include=*.c --include=*.h 2>/dev/null || true)"
checks=$((checks+1))
if [ -n "$hits" ] || [ -n "$named" ]; then
    fails=$((fails+1))
    say "  ⛔ RED -- a language discriminator over global VALUES is still live in src/runtime:"
    printf '%s\n%s\n' "$named" "$hits" | grep -v '^$' | sort -u | sed 's/^/    /'
    say "     NOTE the predicate is spelled TWICE -- core_icn_active(), and again INLINE at core.c:2630."
    say "     Both must go; curing only the named one leaves the inline copy deciding identity the same way."
    say "     Replace it with a behavioural predicate carried from lower, never a test over g_stno/g_line."
else
    say "  ✅ no global-value language predicate found in src/runtime"
fi
say ""
say "=== ARM B -- the eight Icon errors it gates still RAISE, one witness per class, graded against iconx ==="
mkw() { printf 'procedure main()\n   %s;\nend\n' "$2" > "$TD/e$1.icn"; }
mkw 201 'write(1 / 0)'
mkw 202 'write(1 % 0)'
mkw 204 'write(1.0 / 0.0)'
mkw 101 'write(repl("a", "q"))'
mkw 103 '[1, 2] ? write(move(1))'
mkw 110 'write((&null)[1:2])'
mkw 113 'write(?main)'
mkw 114 'write(main[1])'
for n in 101 103 110 113 114 201 202 204; do
    src="$TD/e$n.icn"
    ( cd "$TD" && IPATH="$(dirname "$ICONT")" "$ICONT" -s -o "$TD/e$n.oracle" "$src" ) >/dev/null 2>&1
    [ -x "$TD/e$n.oracle" ] || { echo "  ⛔ REFUSE: icont could not build the error-$n witness"; rm -rf "$TD"; exit 2; }
    orc="$(timeout -k 5 20 "$TD/e$n.oracle" </dev/null 2>&1 | grep -oE 'Run-time error [0-9]+' | grep -oE '[0-9]+' | head -1)"
    [ -n "$orc" ] || { echo "  ⛔ REFUSE: the error-$n witness raises nothing under iconx -- the witness is wrong, not the tree"; rm -rf "$TD"; exit 2; }
    m3="$(timeout -k 5 20 "$SCRIP" "$src" </dev/null 2>&1 | grep -oE 'scrip: error [0-9]+' | grep -oE '[0-9]+' | head -1)"
    ( cd "$TD" && "$SCRIP" --compile -o "$TD/e$n.s" "$src" ) >/dev/null 2>&1
    m4=""
    if [ -s "$TD/e$n.s" ] && gcc -no-pie "$TD/e$n.s" -o "$TD/e$n.bin" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1; then
        m4="$(timeout -k 5 20 "$TD/e$n.bin" </dev/null 2>&1 | grep -oE 'scrip: error [0-9]+' | grep -oE '[0-9]+' | head -1)"
    else
        echo "  ⛔ REFUSE: could not build the error-$n witness in m4 -- cannot measure that mode"; rm -rf "$TD"; exit 2
    fi
    for mode in m3 m4; do
        got="$m3"; [ "$mode" = m4 ] && got="$m4"
        checks=$((checks+1))
        if [ "$got" = "$orc" ]; then
            printf '  ✅ %-4s %s  %s\n' "$n" "$mode" "$got"
        else
            fails=$((fails+1))
            printf '  ⛔ RED %-4s %s  iconx="%s" scrip="%s"\n' "$n" "$mode" "$orc" "${got:-<no error raised>}"
        fi
    done
done
say ""
say "⭐ KNOWN GAP, NAMED AND DELIBERATELY NOT AN ARM (hq_I 2026-09-11, measured): the STRING-BUILTIN route to"
say "   error 103 does not raise at all -- trim/reverse/map/upto/repl/left given a list return a wrong answer"
say "   with rc=0 where iconx raises 103. ARM B's 103 witness uses the SCAN route, which is guarded today."
say "   Pinning the builtin route here would freeze a live defect into this gate's criterion; it has its own row."
if [ "$fails" -gt 0 ]; then
    echo "GATE FAIL(1) [$NAME]: $fails of $checks checks red."
    gate_stamp 2>/dev/null || true
    exit 1
fi
echo "GATE PASS(0) [$NAME]: $checks/$checks checks."
gate_stamp 2>/dev/null || true
exit 0
