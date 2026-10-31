#!/usr/bin/env bash
# test_smoke_polyglot.sh — POLYGLOT smoke: SNOBOL4 + Icon + Prolog loaded and run TOGETHER, modes 3 + 4.
# Covers BOTH polyglot forms: (a) three separate files fed at once, (b) one SCRIPtix .md file with three fences.
# Proves: per-file/per-fence first dispatch, init-all-unconditional, shared g_stage2, cross-language sno→icon call.
# Gate: both modes HARD (this capability is a Lon directive, 2026-07-04).
# AUTHORS: Lon Jones Cherryholmes · Jeffrey Cooper M.D. · Claude Fable 5  DATE: 2026-07-04
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"   # worktree trap: a hardcoded ../../corpus ignored S4E_HOME, so a scratch
                                                 # worktree (SCRIP checked out elsewhere, corpus/.github NOT its siblings)
                                                 # silently graded against whatever ../../corpus happened to resolve to
                                                 # -- a false regression, not a real one, for anyone bisecting there.
SCRIP="${HERE}/../../SCRIP/scrip"
OUTDIR="${HERE}/../../SCRIP/out"
TESTD="$S4E/corpus/tests/scrip_test"   # re-pointed: SCRIP/test moved to corpus (repo-boundary ruling)
P3=0; F3=0; P4=0; F4=0
. "$HERE/lib_smoke_honest.sh" || { echo "SMOKE REFUSE(2): lib_smoke_honest.sh unloadable"; exit 2; }   # CEO-2081: a timeout is a TIMEOUT; under overload the smoke refuses
EXPECTED=$'TRI: mainline alive\nTRI: DOUBLE(21) = 42'

run_m3() {
    local label="$1"; shift
    local actual rc; actual=$(timeout -k 5 8 "$SCRIP" --run "$@" < /dev/null 2>/dev/null); rc=$?
    if smoke_note "$rc"; then
        echo "  [m3 TIMEOUT] $label (rc $rc after 8 s)"; F3=$((F3+1))
    elif [ "$actual" = "$EXPECTED" ]; then
        P3=$((P3+1)); echo "  [m3 PASS] $label"
    else
        echo "  [m3 FAIL] $label (got: $(printf '%s' "$actual" | head -1))"; F3=$((F3+1))
    fi
}

run_m4() {
    local label="$1"; shift
    local s o bin actual rc to=0
    s=$(mktemp /tmp/poly_XXXXXX.s); o="${s%.s}.o"; bin="${s%.s}.bin"
    timeout -k 5 8 "$SCRIP" --compile --target=x86 "$@" < /dev/null > "$s" 2>/dev/null; rc=$?
    if smoke_note "$rc"; then to=1
    elif [ "$rc" = 0 ] && as "$s" -o "$o" 2>/dev/null \
       && gcc -no-pie "$o" -L"$OUTDIR" -lscrip_rt -Wl,-rpath,"$OUTDIR" \
              -Wl,--allow-shlib-undefined -lm -o "$bin" 2>/dev/null; then
        actual=$(timeout -k 5 8 "$bin" < /dev/null 2>/dev/null); rc=$?
        smoke_note "$rc" && to=1
    else
        actual="<mode4-build-failed>"
    fi
    rm -f "$s" "$o" "$bin"
    if [ "$to" = 1 ]; then
        echo "  [m4 TIMEOUT] $label (rc $rc after 8 s)"; F4=$((F4+1))
    elif [ "$actual" = "$EXPECTED" ]; then
        P4=$((P4+1)); echo "  [m4 PASS] $label"
    else
        echo "  [m4 FAIL] $label (got: $(printf '%s' "$actual" | head -1))"; F4=$((F4+1))
    fi
}

echo "=== POLYGLOT smoke (modes 3+4) — both HARD ==="
run_m3 "tri-file  (sno+icn+pl)" "$TESTD/polyglot_tri_main.sno" "$TESTD/polyglot_tri_lib.icn" "$TESTD/polyglot_tri_rules.pl"
run_m4 "tri-file  (sno+icn+pl)" "$TESTD/polyglot_tri_main.sno" "$TESTD/polyglot_tri_lib.icn" "$TESTD/polyglot_tri_rules.pl"
run_m3 "tri-fence (.md)"        "$TESTD/polyglot_tri.md"
run_m4 "tri-fence (.md)"        "$TESTD/polyglot_tri.md"

echo ""
echo "mode-3 (--run):     PASS=$P3 FAIL=$F3   (HARD GATE)"
echo "mode-4 (--compile): PASS=$P4 FAIL=$F4   (HARD GATE)"
smoke_finish $((F3+F4))
