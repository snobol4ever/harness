#!/usr/bin/env bash
# test_gate_sno_error_voice_statement_number_from_a_code_map_no_per_statement_store.sh -- DONE-WHEN for the row
# error-voice-statement-number-from-a-code-map-no-per-statement-store (ceo CEO-1385, minted 2026-09-30, handed to
# hq_snobol4 2026-10-01 09:2x). Since 18f22388e (diagnostics off by default, CEO-1243) a SNOBOL4/Snocone fatal error
# prints no "; statement N" where sbl -bf's post-mortem always does. THE CURE (not yet landed): the emitter writes a
# code-to-statement map beside the emitted code in both media and core_error_voice recovers stno from the faulting
# return address through it -- never a per-statement store on the execution path (TRACE's existing --stlimit-gated
# store, bb_stmt_mark/rt_stmt_enter, is UNCHANGED and stays off by default; --stlimit/TRACE are CEO-1243's business,
# not this row's).
# FOUR WITNESSES, INLINE (re-measured here against sbl -bf at run time, never a frozen number): until 2026-10-02 they
# were packages/snobol4/spitbol_testpgms test4/test5/test7/test8 themselves (the coo, 2026-09-30 19:22), which ended in a
# SPITBOL post-mortem because each opened with a Macro SPITBOL 360/370 statement SPITBOL x64 refuses. Lon modernized
# those four on 2026-10-02 (ceo CEO-1401: "fix the I/O associations to be modern", "Change the CHAR to CHR") and they
# now run to completion, so the gate carries the four refused statements itself, each a few statements deep -- two
# INPUT(.INPUT,,72) (ERROR 116), the DATA field CHAR (ERROR 248), an OUTPUT with a FORTRAN format (ERROR 160) -- the
# same error classes the vendored programs raised, and a gate anchored on a found witness dies when the witness is
# cured (ceo CEO-554). "in line"/"in statement" are read from the oracle's own post-mortem through
# util_spitbol_post_mortem.py, never hardcoded.
# TWO ARITHMETIC WITNESSES (ceo CEO-1572, the coo's audit 2026-10-08: the nine arms above were all BUILTIN faults and the GOAL was red on an
# arithmetic one): arith1  X = N + "q"  at top level (sbl: statement 1) and arith2  the same statement inside a DEFINEd function G (sbl: statement
# 2). The arithmetic boxes call an asm leaf (rt_add_sno ...) that sets up no rbp frame, so the frame-pointer walk skipped the return address
# into the statement and the voice read statement 0; the cure walks the stack by its unwind CFI (_Unwind_Backtrace) and takes the innermost
# frame whose pc the code map knows.
# ARM shape per witness per mode: run SCRIP with NO --stlimit, render its stderr through util_render_error_voice.py
# spitbol (the one renderer, RULES.md SS ONE ERROR VOICE) and read "in statement <n>" from the rendered text -- the
# renderer prints stno 0 when SCRIP's voice carried none, so arm `loc` is RED on today's tree by construction.
# ARM `nostore`: a trivial 3-statement program's default --compile .s carries zero occurrences of g_stno -- a
# regression guard that the cure adds a compile-time side table, never a runtime store (grep the .s, zero hits);
# true today already (IR_STMT_MARK is not emitted without --stlimit) and must stay true after the cure.
# EXIT: 0 every arm passes (the row may close) . 1 an arm is red (today: every `loc` arm) . 2 REFUSED (no oracle,
# stale binary, no scrip, the premise moved -- re-measure before trusting this gate).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
GATE_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
. "$HERE/lib_oracle_flags.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: lib_oracle_flags.sh unavailable"; exit 2; }
. "$HERE/lib_gate.sh"          || { echo "GATE UNPROVEN(2) [$GATE_NAME]: lib_gate.sh unavailable"; exit 2; }
SBL="$(sbl_correctness_bin)" || exit 2
gate_require_exec "$ROOT/scrip" "the scrip binary"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
PM="$HERE/util_spitbol_post_mortem.py"; RV="$HERE/util_render_error_voice.py"
[ -f "$PM" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: $PM missing"; exit 2; }
[ -f "$RV" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: $RV missing"; exit 2; }
T="$(mktemp -d)" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: mktemp failed"; exit 2; }
trap 'rm -rf "$T"' EXIT
TPGM="$T/w"; mkdir -p "$TPGM" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: could not make the witness directory"; exit 2; }
printf '         &FULLSCAN = 1\n         EOF =\n         N = 3\n         INPUT(.INPUT,,72)\n         OUTPUT = N\nEND\n' > "$TPGM/test4.spt"
printf '         DATA = ARRAY(24)\n         J = 1\n         INPUT(.INPUT,,72)\n         OUTPUT = J\nEND\n' > "$TPGM/test5.spt"
printf '         X = 1\n         DATA(\047SYMB(CHAR,LINK,ALT,ASSOC,SUCC)\047)\n         OUTPUT = X\nEND\n' > "$TPGM/test7.spt"
printf '         DATA(\047CARD(NUM,NEXT)\047)\n         OUTPUT(\047TITLE\047,6,\047(14H1THIS IS HAND ,110A1)\047)\n         TITLE = 1\nEND\n' > "$TPGM/test8.spt"
printf '        X = N + "q"\nEND\n' > "$TPGM/arith1.spt"
printf "        DEFINE('G()')              :(START)\nG       X = N + \"q\"                :(RETURN)\nSTART   G()\nEND\n" > "$TPGM/arith2.spt"
red=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   $1"; else echo "  RED  $1 -- $3"; red=$((red+1)); fi; }

stno_of() { python3 "$PM" "$1" /dev/null 2>/dev/null | awk -F'\t' '$1=="STATEMENT"{print $2; exit}'; }
rendered_stno() { python3 "$RV" spitbol 2>/dev/null | grep -o 'in statement [0-9]*' | head -1 | awk '{print $3}'; }

for w in test4 test5 test7 test8 arith1 arith2; do
    [ -f "$TPGM/$w.spt" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: $TPGM/$w.spt missing -- the witness moved"; exit 2; }
    ( cd "$TPGM" && timeout -k 5 20 "$SBL" -bf "$w.spt" < /dev/null > "$T/$w.ora" 2>/dev/null )
    want="$(stno_of "$T/$w.ora")"
    [ -n "$want" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: sbl's post-mortem for $w named no STATEMENT -- the premise moved, re-measure"; exit 2; }

    ( cd "$TPGM" && timeout -k 5 20 "$ROOT/scrip" "$w.spt" < /dev/null > "$T/$w.m3.out" 2> "$T/$w.m3.err" )
    got3="$(rendered_stno < "$T/$w.m3.err")"
    [ "$got3" = "$want" ] && arm "$w m3 loc" ok || arm "$w m3 loc" red "sbl wants statement $want, rendered SCRIP (no --stlimit) said ${got3:-<none>}"

    ( cd "$TPGM" && "$ROOT/scrip" --compile -o "$T/$w.s" "$w.spt" < /dev/null > /dev/null 2>&1 ) \
      && ( as -o "$T/$w.o" "$T/$w.s" 2>/dev/null ) \
      && ( gcc -o "$T/$w.bin" "$T/$w.o" "$ROOT/out/libscrip_rt.so" -lm -Wl,-rpath,"$ROOT/out" 2>/dev/null ) \
      || { echo "GATE UNPROVEN(2) [$GATE_NAME]: could not build the m4 arm of $w -- a toolchain failure, not a verdict"; exit 2; }
    ( cd "$TPGM" && timeout -k 5 20 "$T/$w.bin" < /dev/null > "$T/$w.m4.out" 2> "$T/$w.m4.err" )
    got4="$(rendered_stno < "$T/$w.m4.err")"
    [ "$got4" = "$want" ] && arm "$w m4 loc" ok || arm "$w m4 loc" red "sbl wants statement $want, rendered SCRIP (no --stlimit) said ${got4:-<none>}"
done

printf ' X = 1\n Y = 2\n OUTPUT = X + Y\nEND\n' > "$T/three.sno"
"$ROOT/scrip" --compile -o "$T/three.s" "$T/three.sno" < /dev/null > /dev/null 2>&1
hits="$(grep -c 'g_stno' "$T/three.s" 2>/dev/null || true)"
[ "${hits:-1}" = 0 ] && arm "nostore" ok || arm "nostore" red "the default --compile .s carries $hits reference(s) to g_stno, want 0"

if [ "$red" = 0 ]; then echo "GATE PASS(0) [$GATE_NAME]: $n arms"; exit 0; fi
echo "GATE FAIL(1) [$GATE_NAME]: $red of $n arms red"; exit 1
