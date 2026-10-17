#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_polyglot_demos.sh -- DONE-WHEN for polyglot-scrip-demos-10-working.
# Sweeps all 10 corpus/demos/scriptix/demoNN/*.md polyglot demos in BOTH modes (m3 --run, m4
# --compile) against their .ref files. Prints "m3 PASS=N" / "m4 PASS=N" lines (the
# umbrella's own DONE-WHEN greps for these verbatim) and exits 0 only when both read 10.
#
# rc=0 both modes 10/10 (CLEAN); rc=1 examined all 10 in both modes, at least one FAIL (VIOLATION);
# rc=2 scrip unbuilt or the demo corpus absent -- cannot measure (UNPROVEN, never a silent pass).
# RENAMED 2026-10-02 (Lon, in-chat to the ceo: "Rename the folder to be corpus/demos/scriptix since *.scrip will be its own
# language. And rename the *.scrip sources to be *.md, plain markdown files"; ceo CEO-1421): corpus/demos/scriptix/demoNN/*.md.
# PATH NOTE (corrected AGAIN 2026-08-29, seat10) -- THIS PATH HAS NOW ROUND-TRIPPED: demo/scrip ->
# scrip -> demo/scrip, all within about one day. seat15 (earlier 2026-08-29) verified corpus/scrip/
# was current and pointed DEMO_DIR there; a later same-day Lon-ordered move (corpus commit
# `23e65c0e`, "MOVE scrip/ -> demo/scrip/") relocated it back to corpus/demos/scrip/ before seat15's
# fix ever got exercised by a session after that move landed. Verified THIS session, fresh:
# corpus/demos/scrip/demoNN/ exists (10 dirs, each one *.scrip + *.ref); corpus/scrip/ does
# NOT exist. ⛔ DO NOT "fix" this back to corpus/scrip/ on the strength of seat15's comment alone --
# that comment was correct when written and is not now. If this gate starts reporting UNPROVEN(2)
# unexpectedly, run `find corpus -ipath '*demoNN*'` AND `git log --oneline -3 -- <the dir it's
# actually under>` before assuming either the demos regressed or a stale fix is still current --
# this specific path has now demonstrated it can move in either direction inside 24 hours.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME
set -u
SCRIP="${SCRIP:-$S4E/SCRIP/scrip}"
OUTDIR="${OUTDIR:-$S4E/SCRIP/out}"
CORPUS="${CORPUS:-$S4E/corpus}"
DEMO_DIR="$CORPUS/demos/scriptix"
TIMEOUT=8

if [ ! -x "$SCRIP" ]; then
    echo "GATE UNPROVEN(2) [test_gate_polyglot_demos]: scrip not built at $SCRIP -- run 'make pristine' in SCRIP/ first"
    exit 2
fi
if [ ! -d "$DEMO_DIR" ]; then
    echo "GATE UNPROVEN(2) [test_gate_polyglot_demos]: demo corpus absent at $DEMO_DIR"
    exit 2
fi

n_demos=0
P3=0; F3=0; P4=0; F4=0
declare -a fail_lines=()

# Both runners set globals RC_LAST/OUT_LAST rather than returning a string, so a crash's exit
# status is never silently discarded into the same bucket as "ran fine, produced nothing" --
# this project has been bitten by that exact stdout-only-capture confusion more than once.
run_m3() {
    local src="$1"
    OUT_LAST=$(timeout -k 5 "$TIMEOUT" "$SCRIP" --run "$src" < /dev/null 2>/dev/null); RC_LAST=$?
}

run_m4() {
    local src="$1"
    local s o bin
    s=$(mktemp /tmp/pgdemo_XXXXXX.s); o="${s%.s}.o"; bin="${s%.s}.bin"
    if timeout -k 5 "$TIMEOUT" "$SCRIP" --compile --target=x86 -o "$s" "$src" < /dev/null 2>/dev/null \
       && as "$s" -o "$o" 2>/dev/null \
       && gcc -no-pie "$o" -L"$OUTDIR" -lscrip_rt -Wl,-rpath,"$OUTDIR" \
              -Wl,--allow-shlib-undefined -lm -o "$bin" 2>/dev/null; then
        OUT_LAST=$(timeout -k 5 "$TIMEOUT" "$bin" < /dev/null 2>/dev/null); RC_LAST=$?
    else
        OUT_LAST="<mode4-build-failed>"; RC_LAST=1
    fi
    rm -f "$s" "$o" "$bin"
}

tag_rc() { local rc="$1"; [ "$rc" -ge 128 ] && echo " CRASH(rc=$rc, sig=$((rc-128)))" || { [ "$rc" -ne 0 ] && echo " rc=$rc"; }; }

for demo_dir in "$DEMO_DIR"/demo*/; do
    [ -d "$demo_dir" ] || continue
    dname=$(basename "$demo_dir")
    src=$(ls "$demo_dir"*.md 2>/dev/null | head -1)
    exp=$(ls "$demo_dir"*.ref 2>/dev/null | head -1)
    [ -n "$src" ] && [ -n "$exp" ] || continue
    n_demos=$((n_demos+1))
    expected=$(cat "$exp")

    run_m3 "$src"
    if [ "$OUT_LAST" = "$expected" ] && [ "$RC_LAST" -eq 0 ]; then P3=$((P3+1)); echo "  [m3 PASS] $dname"
    else F3=$((F3+1)); echo "  [m3 FAIL] $dname$(tag_rc "$RC_LAST") (got: $(printf '%s' "$OUT_LAST" | head -1))"; fi

    run_m4 "$src"
    if [ "$OUT_LAST" = "$expected" ] && [ "$RC_LAST" -eq 0 ]; then P4=$((P4+1)); echo "  [m4 PASS] $dname"
    else F4=$((F4+1)); echo "  [m4 FAIL] $dname$(tag_rc "$RC_LAST") (got: $(printf '%s' "$OUT_LAST" | head -1))"; fi
done

if [ "$n_demos" -lt 10 ]; then
    echo "GATE UNPROVEN(2) [test_gate_polyglot_demos]: found $n_demos demo dirs under $DEMO_DIR, expected 10"
    exit 2
fi

echo ""
echo "m3 PASS=$P3 FAIL=$F3"
echo "m4 PASS=$P4 FAIL=$F4"
[ "$P3" -eq 10 ] && [ "$P4" -eq 10 ]
