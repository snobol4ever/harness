#!/usr/bin/env bash
# test_gate_sno_goto_special_transfer_target.sh -- A RUN-TIME-RESOLVED GOTO TARGET MAY NAME A SPECIAL TRANSFER.
#
# WHAT THIS IS: the end state of row snobol4-a-by-name-goto-target-may-be-the-special-transfer-return
# (hq_P 2026-09-06, rank 0, co-signed hq_U). A SNOBOL4 goto whose target is chosen at RUN time may name one
# of RETURN / FRETURN / NRETURN and not only a user label. Published contract of gimpel STATEF.inc, whose
# every state function returns via `:(RET(label))` where `RET = .RETURN :(NRETURN)`: the NAME returned is
# RETURN, meaning "return from the state function", not "jump to a label called RETURN". Before the cure
# every arm below died `ERROR 038 -- transfer to undefined label: RETURN`.
#
# ⛔ THE ROW WAS WRITTEN FOR THE BY-NAME PATH AND THE DEFECT WAS WIDER, WHICH IS WHY ARM 1 IS HERE AT ALL:
# the PLAIN computed goto `:($WHERE)` with WHERE = 'RETURN' failed identically to the by-name form. Two
# lowering sites reach this -- sgoto()/sno_goto_target for `:($VAR)`, sno_goto_computed_target for the
# call form -- so a gate that pinned only the by-name arm would stay green while the commoner form was red.
#
# ⭐ ARM 3 IS THE CONTROL AND IT MUST STAY: a LITERAL `:(RETURN)` reached dynamically from a main-program
# label (fallen into from a DEFINE'd function's statements) already worked before the cure and must keep working. It is the
# arm that proves the landing is ACTIVATION-DYNAMIC rather than lexical, so a future cure that binds RETURN
# to the graph it is written in reds here instead of passing.
#
# ⛔ WHAT THIS GATE DOES NOT CLAIM: that `:(RETURN)` with NO activation on the stack behaves. It does not --
# SCRIP dies on a signal (m3 SIGSEGV, m4 SIGILL) where SPITBOL raises ERROR 242 "function return from level
# zero". That is a separate, pre-existing defect with its own row
# (snobol4-literal-return-with-no-activation-segvs-where-the-oracle-raises-error-242, hq_S). Pinning it here
# would make this gate red for a defect it does not test.
#
# NON-VACUOUS BY CONSTRUCTION: SCRIP_GOTO_SPECIAL_TRANSFER=0 restores the pre-cure behaviour, and every arm
# below is RED under it. Prove that before trusting a green: SCRIP_GOTO_SPECIAL_TRANSFER=0 bash <this file>
#
# EXIT: 0 all arms match SPITBOL. 1 an arm regressed. 2 UNPROVEN (no built scrip / no oracle).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT"
. "$HERE/lib_gate.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_gate.sh -- the ONE gate-honesty authority." >&2; exit 3; }
gate_parse_args "$@"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"
gate_require_exec "$SCRIP" "scrip binary"
gate_require "$RT/libscrip_rt.so" "runtime library"
gate_require_fresh "$ROOT" src "$SCRIP" "$RT/libscrip_rt.so"
T="$(mktemp -d)" || exit 2; trap 'rm -rf "$T"' EXIT
printf "        DEFINE('F()')                   :(MAIN)\nF       OUTPUT  =  'in F'\n        WHERE  =  'RETURN'              :(\$WHERE)\nMAIN    OUTPUT  =  'before'\n        F()\n        OUTPUT  =  'after'\nEND\n"       > "$T/a1.sno"
printf "        DEFINE('F()')                   :(MAIN)\nF       OUTPUT  =  'in F'\n        WHERE  =  'FRETURN'             :(\$WHERE)\nMAIN    OUTPUT  =  'before'\n        F()\n        OUTPUT  =  'after'\nEND\n"      > "$T/a2.sno"
printf "        DEFINE('F()')                   :(MAIN)\nF       OUTPUT  =  'in F'                 :(SHARED)\nSHARED  OUTPUT  =  'shared'              :(RETURN)\nMAIN    OUTPUT  =  'before'\n        F()\n        OUTPUT  =  'after'\nEND\n" > "$T/a3.sno"
printf "        DEFINE('RET(NEXT)')             \n        DEFINE('G()')                   :(MAIN)\nRET     RET  =  .RETURN                  :(NRETURN)\nG       OUTPUT  =  'in G'                 :(RET('X'))\nMAIN    OUTPUT  =  'before'\n        G()\n        OUTPUT  =  'after'\nEND\n" > "$T/a4.sno"
ORACLE="$(command -v true >/dev/null && echo /home/resources/x64/bin/sbl)"
[ -x "$ORACLE" ] || { echo "UNPROVEN(2): correctness oracle absent at $ORACLE -- this gate grades against SPITBOL, never against SCRIP's own output"; exit 2; }
bad=0
for a in a1 a2 a3 a4; do
    want="$("$ORACLE" -bf "$T/$a.sno" < /dev/null 2>&1 | tr '\n' '/')"
    for m in m3 m4; do
        if [ "$m" = m3 ]; then
            got="$(timeout -k 5 20s "$SCRIP" "$T/$a.sno" < /dev/null 2>&1 | tr '\n' '/')"
        else
            "$SCRIP" --compile -o "$T/$a.s" "$T/$a.sno" < /dev/null >/dev/null 2>&1
            gcc -no-pie "$T/$a.s" -o "$T/$a.x" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm -lpthread >/dev/null 2>&1 || { echo "  RED  $a $m -- link failed"; bad=1; continue; }
            got="$(timeout -k 5 20s "$T/$a.x" < /dev/null 2>&1 | tr '\n' '/')"
        fi
        if [ "$got" = "$want" ]; then echo "  ok   $a $m -- matches SPITBOL [$want]"
        else echo "  RED  $a $m -- got [$got] want [$want]"; bad=1; fi
    done
done
if [ "$bad" -ne 0 ]; then echo "GATE RED(1) [sno-goto-special-transfer-target]: a run-time-resolved goto target does not reach the special transfer it names"; exit 1; fi
echo "GATE GREEN(0) [sno-goto-special-transfer-target]: RETURN/FRETURN reached through \$-indirect and by-name gotos, and the dynamic literal control holds, both modes"
