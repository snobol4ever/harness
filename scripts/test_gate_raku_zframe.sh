#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_raku_zframe.sh — RK-ZC-8: Raku ζ-frame regime pin gate.
#
# DOCTRINE: lower_raku.c sets zframe_graph=1 on every Raku IR graph (RK-ZC-2, mirrors ICN-FR-2).
# This gate asserts two invariants so a future regime migration cannot silently leave Raku behind:
#
#   INVARIANT A — THE REGIME IS DERIVED AND LOAD-BEARING (RECUT 2026-09-16, hq_raku).
#   ⛔ THE KILLSWITCH FORM OF THIS ARM IS DEAD BY LAW, NOT BY CHOICE. It read: with SCRIP_RK_ZFRAME=0
#   both witnesses must exit nonzero. That switch was DELETED on 2026-09-09 by `709a755df` (CEO-447,
#   Lon 09-09 09:2x: "Get rid of enumerated shape class now!!!") along with the other 28 frame-placement
#   switches, and `test_gate_no_zeta_frame_switches.sh` was wired BLOCKING in the same commit to keep
#   every such name out of src/ forever. So the old arm could only be greened by re-adding a getenv that
#   a blocking gate exists to forbid: the two gates were in direct contradiction and the law wins.
#   ⭐ MEASURED, AND THE REASON THIS IS WRITTEN DOWN: with nothing reading the name, `SCRIP_RK_ZFRAME=0`
#   is an ordinary default-regime run. The witness ran CORRECTLY and exited 0, and the arm read that as
#   "zframe_graph not disabling correctly" — so this gate has been RED ON A CLEAN TREE since 2026-09-09,
#   for the seven days nobody ran it. An env switch is a TERRIBLE thing to pin a gate to: when the switch
#   is deleted, the gate does not refuse and does not go dark, it goes RED while the tree is perfectly
#   healthy, and it accuses the code of the instrument's own obsolescence.
#   WHAT REPLACES IT, keeping the content and dropping the switch: A1 is BEHAVIOURAL — the class-b witness
#   (a user sub called with an argument, the shape that needs the ζ-frame entry's γ/ω wires) must print
#   the right answer in BOTH modes; A2 is a SOURCE CENSUS — lower_raku.c must put every Raku graph on the
#   zframe regime UNCONDITIONALLY, with no getenv between the decision and the graph. A1 proves the regime
#   carries the construct; A2 proves it is derived, never selected. Neither can be satisfied by a switch.
#   Witness 1 (class a — ζ-cell ret-pop): `say 42;`  — correct output then SIGSEGV (rc nonzero).
#   Witness 2 (class b — no-return-wires): `sub f($a){return $a*2} say f(21);` — dies rc=1.
#
#   INVARIANT B — FULL SUITE CLEAN: with the default (zframe_graph=1), test_smoke_raku.sh exits 0.
#   This re-runs the suite rather than trusting the watermark so drift is caught the same session it
#   is introduced.
#
# Usage: bash ../harness/scripts/test_gate_raku_zframe.sh
# Exit 0 = gate PASS.  Exit 1 = gate FAIL with reason.
#
# AUTHORS: Lon Jones Cherryholmes · Jeffrey Cooper M.D. · Claude Sonnet  DATE: 2026-08-08
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${HERE}/../../SCRIP/scrip"
FAIL=0
echo "=== RK-ZC-8 — Raku zframe regime pin gate ==="
# ── INVARIANT A — the ζ-frame regime is derived (A2) and carries the user-sub call (A1) ─────────
# Class-b: `sub f($a){return $a*2} say f(21);` — a user sub call with an argument. Under the legacy
# non-zframe entry this bombed (rt_flat_wire_adopt read gw=ww=0, no γ/ω wires supplied); under the one
# derived regime it must simply be RIGHT. Class-a (`say 42;`) never needed the frame: a flat program
# with no user subs ran fine on the old RSP carve path, which is why the witness is class-b.
W2=$(mktemp /tmp/rk_zc8_XXXXXX.raku)
printf 'sub f($a){return $a*2} say f(21);\n'                   > "$W2"
echo "--- INVARIANT A1: the class-b witness is CORRECT in both modes (zframe carries the user-sub call) ---"
M3OUT=$(timeout -k 5 8 "$SCRIP" --run "$W2" 2>/dev/null </dev/null); M3RC=$?
if [ "$M3RC" = "0" ] && [ "$M3OUT" = "42" ]; then
    echo "  OK   m3: rc=0 out=42"
else
    echo "  FAIL m3: rc=$M3RC out='$M3OUT' (expected rc=0 out=42 — the ζ-frame entry is not carrying the user-sub call)"
    FAIL=1
fi
A4S=$(mktemp /tmp/rk_zc8_XXXXXX.s); A4B=$(mktemp /tmp/rk_zc8_XXXXXX.bin)
if timeout -k 5 20 "$SCRIP" --compile --out="$A4S" "$W2" >/dev/null 2>&1 \
   && gcc -m64 -no-pie "$A4S" -L"${HERE}/../../SCRIP/out" -lscrip_rt -Wl,-rpath,"${HERE}/../../SCRIP/out" -lm -lpthread -o "$A4B" >/dev/null 2>&1; then
    M4OUT=$(timeout -k 5 8 "$A4B" 2>/dev/null </dev/null); M4RC=$?
    if [ "$M4RC" = "0" ] && [ "$M4OUT" = "42" ]; then
        echo "  OK   m4: rc=0 out=42"
    else
        echo "  FAIL m4: rc=$M4RC out='$M4OUT' (expected rc=0 out=42)"
        FAIL=1
    fi
else
    echo "  FAIL m4: the class-b witness did not compile+link (cannot measure the regime it is here to pin)"
    FAIL=1
fi
rm -f "$W2" "$A4S" "$A4B"
# A2 — THE CENSUS, SCOPED TO THE FILES THIS LANE OWNS. The old arm's content that is still mine to hold
# is "no frame placement is SELECTED by hand on the Raku path". src/-wide, test_gate_no_zeta_frame_switches.sh
# holds that line blocking; here it is held over the Raku frontend + lowerer specifically, so a switch
# re-added on this path is convicted by this gate too, next to the construct it would corrupt.
# ⛔ DO NOT repoint this at frame_layout.c or any spine file. The regime is DERIVED centrally now
# (fl_derive_tier), the `zframe_graph = 1` that lower_raku.c carried in 709a755df has since folded into
# that selector, and a first cut of this arm grepped lower_raku.c for the assignment and went RED on a
# healthy tree within the hour — the SAME failure as the killswitch arm it replaced, committed while
# writing its obituary. A gate in one lane must not pin another lane's internals: A3 below asks the
# BUILT COMPILER what regime it produced, which is what this gate actually cares about and survives
# any refactor that preserves behaviour.
echo "--- INVARIANT A2: no frame-placement switch on the Raku path (frontend + lowerer) ---"
A2FILES=$(ls "${HERE}/../../SCRIP/src/lower/lower_raku.c" "${HERE}/../../SCRIP/src/parsers/raku/"*.c 2>/dev/null)
if [ -z "$A2FILES" ]; then
    echo "  FAIL no Raku frontend/lowerer sources found — a census over nothing"; FAIL=1
else
    A2HITS=$(grep -rnoE 'getenv\("SCRIP_[A-Z0-9_]*(RBP|FRAME|PIN|ZFRAME|CARVE)[A-Z0-9_]*"\)' $A2FILES 2>/dev/null | grep -vE 'getenv\("SCRIP_GC_' || true)
    if [ -n "$A2HITS" ]; then
        echo "  FAIL a frame-placement getenv is back on the Raku path (CEO-447: ζ HAS NO MODES):"
        printf '%s\n' "$A2HITS" | sed 's/^/        /'
        FAIL=1
    else
        echo "  OK   0 frame-placement getenv across $(printf '%s\n' $A2FILES | wc -l) Raku source file(s)"
    fi
fi
# A3 — ASK THE BUILT COMPILER, not the source. The class-b witness's user sub must get a real
# per-activation ζ-frame: its own FN scope in the frame layout, and a vslot for its parameter.
# That is the observable the regime exists to produce.
echo "--- INVARIANT A3: the user sub gets a real per-activation ζ-frame (--dump-zeta) ---"
W3=$(mktemp /tmp/rk_zc8_XXXXXX.raku)
printf 'sub f($a){return $a*2} say f(21);\n' > "$W3"
ZOUT=$(timeout -k 5 10 "$SCRIP" --dump-zeta "$W3" 2>&1 </dev/null)
if printf '%s' "$ZOUT" | grep -qE '^; graph [0-9]+ .f.' \
   && printf '%s' "$ZOUT" | grep -qE 'scope +[0-9]+ +FN +f' \
   && printf '%s' "$ZOUT" | grep -qE 'vslot .*a$'; then
    echo "  OK   sub f has its own FN scope and a vslot for its parameter"
else
    echo "  FAIL --dump-zeta shows no per-activation frame for sub f (regime not carrying the user sub):"
    printf '%s\n' "$ZOUT" | head -12 | sed 's/^/        /'
    FAIL=1
fi
rm -f "$W3"
# ── INVARIANT B — full suite clean under default (zframe_graph=1) ────────────────────────────────
echo "--- INVARIANT B: full smoke suite must be FAIL=0 both modes ---"
SUITE_OUT=$("${HERE}/test_smoke_raku.sh" 2>&1)
M3=$(echo "$SUITE_OUT" | grep 'mode-3' | grep -oE 'FAIL=[0-9]+' | grep -oE '[0-9]+')
M4=$(echo "$SUITE_OUT" | grep 'mode-4' | grep -oE 'FAIL=[0-9]+' | grep -oE '[0-9]+')
M3="${M3:-?}"; M4="${M4:-?}"
if [ "$M3" = "0" ] && [ "$M4" = "0" ]; then
    echo "  OK   m3 FAIL=$M3  m4 FAIL=$M4"
else
    echo "  FAIL m3 FAIL=$M3  m4 FAIL=$M4 (suite not clean — regime drift)"
    FAIL=1
fi
# ── RESULT ────────────────────────────────────────────────────────────────────────────────────────
if [ "$FAIL" -eq 0 ]; then
    echo "=== RK-ZC-8 gate PASS ==="
    exit 0
else
    echo "=== RK-ZC-8 gate FAIL ==="
    exit 1
fi
