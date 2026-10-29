#!/usr/bin/env bash
# rt_goto_transfer()'s resolve failure is now EXPRESSIBLE, not silently absorbed as success (row
# rt-goto-transfer-is-failure-blind, hq_U 2026-09-05). Before this cure, rt_goto_transfer() returned
# void; core_runtime_error()'s SETEXIT trap arm read "returned at all" as "the handler ran" and fell
# into an unconditional exit(0). A SETEXIT(.LABEL) whose LABEL never resolves therefore ended the
# program mid-stream with ZERO output and rc=0, in BOTH modes, where SPITBOL survives the error (the
# trap attempt still consumes one &ERRLIMIT unit, but no handler runs, and the interrupted statement's
# own :S()/:F() takes over) and continues.
# MEASURED against the shared correctness oracle (/home/resources/x64/bin/sbl -bf, s189/s261): a
# program that SETEXIT(.NOSUCH)s (NOSUCH is never a label anywhere in the source) and then divides by
# zero prints "FAILEXIT\nAFTER" at rc=0 -- no HANDLER line, no error text, no crash. Proven non-vacuous
# by stash-and-rebuild (this row, 2026-09-05): the pre-cure tree prints NOTHING at rc=0 for this exact
# witness, in both modes; the identical demo-set control arm sweep (test_demo_descent_sweep.sh, RULES.md
# the DEMO-SET CONTROL ARM) was run stashed and unstashed and produced BYTE-IDENTICAL 14 DIFF/1
# COMPILE_FAIL/11 PASS buckets both times, proving those reds predate this row and are not this cure's.
# The cure: rt_goto_transfer() (src/runtime/runtime_eval.c) keeps its ORIGINAL error-reporting behaviour
# for its other two callers (the GOTO_DEFERRED codegen fallback arm, sno_setexit_fire_on_end) -- it still
# calls the reporting rt_goto_resolve() and now returns 1/0 for transferred/not. A NEW sibling,
# rt_goto_transfer_checked(), is the only caller of a new rt_goto_resolve_x(name,&undef) internal that can
# ask "would this resolve" WITHOUT recursing into core_runtime_error() -- core_runtime_error()'s own
# SETEXIT trap arm (src/runtime/core/core.c) is the only caller of THAT, because it is the one call site
# that cannot safely re-enter itself (the recursive call landed with _setexit_label already cleared,
# which made the original bug's silent double-absorption invisible instead of loud).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S="$ROOT/scrip"
[ -x "$S" ] || { echo "⛔ GATE REFUSES: no $S -- make first. A missing binary proves NOTHING about this defect."; exit 2; }
if ! . "$HERE/lib_gate.sh" 2>/dev/null || ! command -v gate_require_fresh >/dev/null 2>&1; then
    echo "⛔ GATE REFUSES: lib_gate.sh unavailable or missing gate_require_fresh -- cannot verify binary freshness" >&2; exit 2
fi
GATE_NAME=rt_goto_transfer_failure_is_expressible gate_require_fresh "$ROOT" src "$S" "$ROOT/out/libscrip_rt.so"
W="$(mktemp -d)" || exit 2
trap 'rm -rf "$W"' EXIT
rc=0
mk() { printf '%b' "$2" > "$W/$1.sno"; }
run() { ( cd "$W" && timeout -k 5 20s "$S" "$1.sno" </dev/null 2>&1 ); }
face() {
    local name="$1" want="$2" got
    got="$(run "$name")"
    if [ "$got" = "$want" ]; then echo "  PASS $name"; else
        echo "  FAIL $name"; echo "    want: $(printf '%s' "$want" | tr '\n' '|')"; echo "    got : $(printf '%s' "$got" | tr '\n' '|')"; rc=1
    fi
}
# The bug witness: SETEXIT names a label that is never defined anywhere in the program.
mk setexit_undef_survives "\t&ERRLIMIT = 10\n\tSETEXIT(.NOSUCH)\n\tD = 0\n\tOUTPUT = 1 / D\t\t:F(FL)S(SU)\n\tOUTPUT = 'FELL'\t\t:(NX)\nFL\tOUTPUT = 'FAILEXIT'\t:(NX)\nSU\tOUTPUT = 'SUCCESSEXIT'\t:(NX)\nNX\tOUTPUT = 'AFTER'\t:(END)\nEND\n"
# The contrast: the SAME shape, but the handler label DOES resolve -- proves this gate can tell
# "resolved" from "undef" apart, i.e. it is not vacuously green because every SETEXIT target now
# survives silently regardless of resolvability.
mk setexit_defined_still_fires "\t&ERRLIMIT = 10\n\tSETEXIT(.H)\n\tD = 0\n\tOUTPUT = 'BEFORE'\n\tOUTPUT = 1 / D\t\t:F(FL)S(SU)\n\tOUTPUT = 'FELL'\t\t:(NX)\nFL\tOUTPUT = 'FAILEXIT'\t:(NX)\nSU\tOUTPUT = 'SUCCESSEXIT'\t:(NX)\nNX\tOUTPUT = 'AFTER'\t:(END)\nH\tOUTPUT = 'HANDLER'\t:(CONTINUE)\nEND\n"
echo "rt_goto_transfer failure-expressible faces (undef face MEASURED against SPITBOL x64/bin/sbl -bf):"
face setexit_undef_survives   "FAILEXIT
AFTER"
face setexit_defined_still_fires "BEFORE
HANDLER
FAILEXIT
AFTER"
# ⛔ THE M4 FACE MUST STAY -- GOAL is explicit that the blindness fired "in BOTH modes."
m4build() {
    local n="$1"
    rm -f "$W/$n.s" "$W/$n.bin"
    ( cd "$W" && timeout -k 5 30s "$S" --compile --out="$n.s" "$n.sno" </dev/null >/dev/null 2>&1 ) || return 1
    gcc -m64 -no-pie "$W/$n.s" -Wl,-rpath,"$ROOT/out" -L"$ROOT/out" -lscrip_rt -lm -lpthread -o "$W/$n.bin" 2>/dev/null || return 1
    ( cd "$W" && timeout -k 5 20s "./$n.bin" </dev/null 2>&1 )
}
_m4="$(m4build setexit_undef_survives)" || { echo "⛔ GATE REFUSES: m4 build failed -- a gate that cannot BUILD proves nothing about m4"; exit 2; }
[ "$_m4" = "FAILEXIT
AFTER" ] && echo "  PASS m4 setexit_undef_survives" || { echo "  FAIL m4 setexit_undef_survives"; echo "    got : $(printf '%s' "$_m4" | tr '\n' '|')"; rc=1; }
[ "$rc" = 0 ] && echo "RT_GOTO_TRANSFER_FAILURE_EXPRESSIBLE_GATE ok" || echo "RT_GOTO_TRANSFER_FAILURE_EXPRESSIBLE_GATE red"
exit $rc
