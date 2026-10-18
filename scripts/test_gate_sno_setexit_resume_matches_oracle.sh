#!/usr/bin/env bash
# SETEXIT/ERRLIMIT resume mechanism, pinned against BOTH oracles' agreed contract (hq_P 2026-09-04,
# row setexit-not-invoked-under-errlimit-survival). Every face below was measured on SPITBOL
# (/home/resources/x64/bin/sbl -bf) AND CSNOBOL4 (/home/claude/csnobol4/snobol4) and the two AGREE;
# faces where they disagree (error NUMBERING, and the CSNOBOL4-only END trap) are deliberately absent.
# Non-vacuous by construction: SCRIP_SETEXIT=0 must turn the resume faces RED (proven at the tail).
set -u
# ⛔⭐ TWO PREFLIGHT DEFECTS CURED HERE 2026-09-05 (hq_P), BOTH FOUND BY ceo READING THIS GATE 5-OF-6 RED ON A TREE
# THAT CONTAINED THE CURE. Neither was a compiler question and both produced the same symptom -- a full, plausible,
# entirely false red board -- which is why this preamble is now the canonical one and not a hand-rolled pair of lines.
#   (1) THE ROOT FALLBACK NAMED A SEAT. It read ${S4E_HOME:-/home/claude_P}, so with S4E_HOME unset in any OTHER
#       root this gate reached across the box and graded hq_P's binary rather than the caller's -- a census found
#       it was THE ONLY script of 642 in ../harness/scripts/ that hardcoded a seat root, against D-17 PORTABLE-HOME's rule
#       that every script derives its paths from $0 or S4E_HOME. It now derives from BASH_SOURCE like every sibling.
#   (2) NO STALENESS PREFLIGHT. It graded whatever ./scrip was lying in the tree, so a binary built before the cure
#       reds exactly 5 of these 6 faces -- every resume face plus the &ERRLIMIT one, with handler_falls_off passing
#       because that face ALREADY worked pre-cure. That is precisely the reported signature, and it is the class
#       FINDING-2026-08-30-hq_C-the-snobol4-board-grades-whatever-scrip-exists-and-labels-that-verdict-with-git-head.md
#       names. ⭐ THE GALLING PART, AND THE REASON THIS COMMENT IS LONG: hq_T cured that class across every suite
#       runner on 2026-09-04 and put the rule in lib_gate.sh as ONE copy -- and this gate was written the same day
#       and did not inherit it. A cure that lands as a shared helper still has to be ADOPTED by each new instrument,
#       and the newest instrument is the one least likely to know the helper exists.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
H="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
S="$ROOT/scrip"
[ -x "$S" ] || { echo "⛔ GATE REFUSES: no $S -- make first. A missing binary proves NOTHING about this defect."; exit 2; }
if ! . "$HERE/lib_gate.sh" 2>/dev/null || ! command -v gate_require_fresh >/dev/null 2>&1; then
    echo "⛔ GATE REFUSES: lib_gate.sh unavailable or missing gate_require_fresh -- cannot verify binary freshness" >&2; exit 2
fi
GATE_NAME=sno_setexit_resume gate_require_fresh "$ROOT" src "$S" "$ROOT/out/libscrip_rt.so"
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
mk continue_failure_exit "\t&ERRLIMIT = 10\n\tSETEXIT(.H)\n\tD = 0\n\tOUTPUT = 'BEFORE'\n\tOUTPUT = 1 / D\t\t:F(FL)S(SU)\n\tOUTPUT = 'FELL'\t\t:(NX)\nFL\tOUTPUT = 'FAILEXIT'\t:(NX)\nSU\tOUTPUT = 'SUCCESSEXIT'\t:(NX)\nNX\tOUTPUT = 'AFTER'\t:(END)\nH\tOUTPUT = 'HANDLER'\t:(CONTINUE)\nEND\n"
mk continue_fallthrough  "\t&ERRLIMIT = 10\n\tSETEXIT(.H)\n\tD = 0\n\tOUTPUT = 1 / D\n\tOUTPUT = 'AFTER'\t:(END)\nH\tOUTPUT = 'HANDLER'\t:(CONTINUE)\nEND\n"
mk continue_oneshot      "\t&ERRLIMIT = 10\n\tSETEXIT(.H)\n\tD = 0\n\tX = 1 / D\t\t:F(S5)\nS5\tOUTPUT = 'MID'\n\tY = 1 / D\t\t:F(S7)\nS7\tOUTPUT = 'AFTER'\t:(END)\nH\tOUTPUT = 'HANDLER'\t:(CONTINUE)\nEND\n"
mk continue_rearm        "\t&ERRLIMIT = 10\n\tSETEXIT(.H)\n\tD = 0\n\tX = 1 / D\t\t:F(S5)\nS5\tOUTPUT = 'MID'\n\tY = 1 / D\t\t:F(S7)\nS7\tOUTPUT = 'AFTER'\t:(END)\nH\tOUTPUT = 'HANDLER'\n\tSETEXIT(.H)\t\t:(CONTINUE)\nEND\n"
mk handler_falls_off     "\t&ERRLIMIT = 10\n\tSETEXIT(.H)\n\tD = 0\n\tOUTPUT = 1 / D\n\tOUTPUT = 'AFTER'\t:(END)\nH\tOUTPUT = 'HANDLER'\n\tOUTPUT = 'FELLOFF'\nEND\n"
mk end_trap_needs_errlimit "\tSETEXIT(.H)\n\tOUTPUT = 'MAIN'\t\t:(FIN)\nH\tOUTPUT = 'TRAP'\t\t:(END)\nFIN\tOUTPUT = 'FIN'\nEND\n"
echo "SETEXIT resume faces (contract agreed by SPITBOL and CSNOBOL4):"
face continue_failure_exit   "BEFORE
HANDLER
FAILEXIT
AFTER"
face continue_fallthrough    "HANDLER
AFTER"
face continue_oneshot        "HANDLER
MID
AFTER"
face continue_rearm          "HANDLER
MID
HANDLER
AFTER"
face handler_falls_off       "HANDLER
FELLOFF"
face end_trap_needs_errlimit "MAIN
FIN"
n=0
for f in continue_failure_exit continue_fallthrough continue_oneshot continue_rearm; do
    a="$( cd "$W" && SCRIP_SETEXIT=0 timeout -k 5 20s "$S" "$f.sno" </dev/null 2>&1 )"
    b="$( cd "$W" && timeout -k 5 20s "$S" "$f.sno" </dev/null 2>&1 )"
    [ "$a" != "$b" ] && n=$((n+1))
done
if [ "$n" -lt 4 ]; then
    echo "⛔ GATE REFUSES: killswitch SCRIP_SETEXIT=0 moved only $n/4 resume faces -- this gate cannot fail, so it is not evidence"
    exit 2
fi
echo "  killswitch SCRIP_SETEXIT=0 moves $n/4 resume faces (NON-VACUOUS)"
# ⛔⭐ THE M4 COMPOSITION FACE (hq_P 2026-09-05, ceo CEO-286 audit). Everything above this line runs mode 3 ONLY,
# which is exactly why the 09-04 closure of this row was green and BLIND to a mode-4 defect that printed ZERO bytes
# at rc=0. The pair below is ONE INGREDIENT APART -- same program, same handler, the only difference being whether
# the handler's label is ALSO a DEFINE'd function name -- so a red here names the composition, not "m4 is broken".
# Both oracles AGREE on caught/after/fin for BOTH shapes (measured: /home/resources/x64/bin/sbl -bf and csnobol4).
# ⛔ THIS BLOCK MUST STAY ABOVE THE CLOSING `exit $rc`: appended below it, it is dead code that reports GREEN, which
# is the .PHONY-with-no-recipe shape inside a gate. It reported green exactly once that way before being caught.
m4build() {
    local n="$1" envk="${2:-}"
    rm -f "$W/$n.s" "$W/$n.bin"
    if [ -n "$envk" ]; then ( cd "$W" && env "$envk" timeout -k 5 30s "$S" --compile -o "$n.s" "$n.sno" </dev/null >/dev/null 2>&1 )
    else ( cd "$W" && timeout -k 5 30s "$S" --compile -o "$n.s" "$n.sno" </dev/null >/dev/null 2>&1 ); fi || return 1
    gcc -m64 -no-pie "$W/$n.s" -Wl,-rpath,"$ROOT/out" -L"$ROOT/out" -lscrip_rt -lm -lpthread -o "$W/$n.bin" 2>/dev/null || return 1
    ( cd "$W" && timeout -k 5 20s "./$n.bin" </dev/null 2>&1 )
}
mk lblhandler_bare   "\t&ERRLIMIT = 1000\nSTART\tSETEXIT(.H)\n\tX = NOSUCHFN(1)\n\tOUTPUT = 'after'\n\t:(FIN)\nH\tOUTPUT = 'caught'\n\t:(CONTINUE)\nFIN\tOUTPUT = 'fin'\nEND\n"
mk lblhandler_define "\t&ERRLIMIT = 1000\n\tDEFINE('H()')\t:(START)\nH\tOUTPUT = 'caught'\n\t:(CONTINUE)\nSTART\tSETEXIT(.H)\n\tX = NOSUCHFN(1)\n\tOUTPUT = 'after'\nFIN\tOUTPUT = 'fin'\nEND\n"
_want="caught
after
fin"
echo "m4 composition -- SETEXIT handler label that is ALSO a DEFINE'd name (contract agreed by SPITBOL and CSNOBOL4):"
for _f in lblhandler_bare lblhandler_define; do
    _m3="$(run "$_f")"
    _m4="$(m4build "$_f")" || { echo "⛔ GATE REFUSES: m4 build of $_f failed -- a gate that cannot BUILD proves nothing about m4"; exit 2; }
    [ "$_m3" = "$_want" ] && echo "  PASS m3 $_f" || { echo "  FAIL m3 $_f"; echo "    want: $(printf '%s' "$_want" | tr '\n' '|')"; echo "    got : $(printf '%s' "$_m3" | tr '\n' '|')"; rc=1; }
    [ "$_m4" = "$_want" ] && echo "  PASS m4 $_f" || { echo "  FAIL m4 $_f"; echo "    want: $(printf '%s' "$_want" | tr '\n' '|')"; echo "    got : $(printf '%s' "$_m4" | tr '\n' '|')"; rc=1; }
done
_ks="$(m4build lblhandler_define SCRIP_DEFINE_LBL_ALIAS=0)" || { echo "⛔ GATE REFUSES: killswitch build failed -- cannot prove this face is non-vacuous"; exit 2; }
_on="$(m4build lblhandler_define)" || { echo "⛔ GATE REFUSES: re-build failed -- cannot prove this face is non-vacuous"; exit 2; }
if [ "$_ks" = "$_on" ]; then
    echo "⛔ GATE REFUSES: killswitch SCRIP_DEFINE_LBL_ALIAS=0 did NOT move the m4 composition -- this face cannot fail, so it is not evidence"
    exit 2
fi
echo "  killswitch SCRIP_DEFINE_LBL_ALIAS=0 moves the m4 composition (NON-VACUOUS)"
[ "$rc" = 0 ] && echo "SETEXIT_RESUME_GATE ok" || echo "SETEXIT_RESUME_GATE red"
exit $rc
