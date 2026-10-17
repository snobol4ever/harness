#!/usr/bin/env bash
# test_crosscheck_raku.sh — 3-mode crosscheck for RAKU (GOAL-RAKU-100.md)
#
# Runs the raku test corpus through --run, --run, --run.
# Run on every major push. Mode-consistency check, not regression.
# If .ref present alongside test file: diffs vs oracle too.
# Exits 0 only if all three modes agree on every test.
#
# AUTHORS: Lon Jones Cherryholmes · Claude Sonnet 4.6  DATE: 2026-04-14
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${HERE}/../../SCRIP/scrip"
TIMEOUT=30
PASS=0; FAIL=0; SKIP=0

xcheck() {
    local label="$1" file="$2" ref="${3:-}"
    if [ ! -f "$file" ]; then echo "  SKIP $label (no file)"; SKIP=$((SKIP+1)); return; fi
    local ir sm run_out
    ir=$(timeout -k 5 $TIMEOUT "$SCRIP" --run  "$file" </dev/null 2>/dev/null)
    sm=$(timeout -k 5 $TIMEOUT "$SCRIP" --run  "$file" </dev/null 2>/dev/null)
    run_out=$(timeout -k 5 $TIMEOUT "$SCRIP" --run "$file" </dev/null 2>/dev/null)
    local ok=1
    if [ -n "$ref" ] && [ -f "$ref" ]; then
        local exp; exp=$(cat "$ref")
        [ "$ir"  != "$exp" ] && { echo "  FAIL $label --run  vs oracle"; diff <(echo "$exp") <(echo "$ir")  | head -5 | sed 's/^/    /'; ok=0; }
        [ "$sm"  != "$exp" ] && { echo "  FAIL $label --run  vs oracle"; diff <(echo "$exp") <(echo "$sm")  | head -5 | sed 's/^/    /'; ok=0; }
        [ "$run_out" != "$exp" ] && { echo "  FAIL $label --run vs oracle"; diff <(echo "$exp") <(echo "$run_out") | head -5 | sed 's/^/    /'; ok=0; }
    else
        [ "$sm"  != "$ir" ] && { echo "  FAIL $label --run  vs --run";  diff <(echo "$ir") <(echo "$sm")  | head -5 | sed 's/^/    /'; ok=0; }
        [ "$run_out" != "$ir" ] && { echo "  FAIL $label --run vs --run";  diff <(echo "$ir") <(echo "$run_out") | head -5 | sed 's/^/    /'; ok=0; }
    fi
    if [ "$ok" -eq 1 ]; then echo "  PASS $label"; PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi
}

echo "=== Raku 3-mode crosscheck ==="

T=$(mktemp /tmp/rk_XXXXXX.raku)
cat > "$T" << 'EOF'
sub main() {
    say('hello world');
}
EOF
xcheck "hello" "$T"

cat > "$T" << 'EOF'
sub main() {
    my $x = 6 * 7;
    say($x);
}
EOF
xcheck "arith" "$T"

cat > "$T" << 'EOF'
sub main() {
    my $i = 1;
    while ($i <= 3) {
        say($i);
        $i = $i + 1;
    }
}
EOF
xcheck "while_loop" "$T"

cat > "$T" << 'EOF'
sub main() {
    my $s = 'ab' ~ 'cd';
    say($s);
}
EOF
xcheck "concat" "$T"

rm -f "$T"

# Raku corpus rung files
# ⛔⭐ THIS PATH WENT STALE AND THE SCRIPT REPORTED GREEN ANYWAY (seat05, 2026-08-30). SCRIP/test/raku moved to
# corpus/tests/scrip_test/raku in the consolidation. The glob then matched NOTHING, `[ -f ] || continue`
# swallowed it silently, and the script printed "PASS=4 FAIL=0 SKIP=0" rc=0 -- four inline smoke cases
# standing in for 51 rung files. ⭐ A SMALL, CLEAN, PLAUSIBLE COUNT HIDING A POPULATION COLLAPSE: RULES.md
# § INSTRUMENT LAWS SIXTH BATCH clause 3, and the reason it survived is that 4/4 green looks like a pass and
# nobody remembers the denominator should be 55.
# ⛔ REPOINTING ALONE WOULD NOT HAVE BEEN ENOUGH, which is why this refuses instead: the 47 .raku files at
# the new location have ZERO .ref siblings, so the rung arm cannot oracle-diff even when it finds them. A
# script that "works" after a path fix while grading nothing is the same defect with a fresh path.
RUNGS=$S4E/corpus/tests/scrip_test/raku
_rung_n=0
if [ -d "$RUNGS" ]; then
    for f in "$RUNGS"/*.raku; do
        [ -f "$f" ] || continue
        _rung_n=$((_rung_n+1))
        ref="${f%.raku}.ref"
        [ -f "$ref" ] || continue
        xcheck "$(basename $f .raku)" "$f" "$ref"
        _rung_graded=$((${_rung_graded:-0}+1))
    done
fi
if [ ! -d "$RUNGS" ]; then
    echo "⛔ REFUSES rc=2: the raku rung corpus is absent at $RUNGS -- this script would grade only its"
    echo "   inline smoke cases and print a clean PASS. A smaller total is NOT a pass; repoint or retire"
    echo "   this script deliberately." >&2
    exit 2
fi
if [ "${_rung_graded:-0}" -eq 0 ]; then
    echo "⛔ REFUSES rc=2: found $_rung_n rung file(s) at $RUNGS but ZERO have a .ref sibling, so the rung"
    echo "   arm graded NOTHING and the PASS below would describe only the inline smoke cases."
    echo "   Mint refs (capture-oracle-refs) or retire this arm -- do not read the smaller total as green." >&2
    exit 2
fi

echo ""
echo "PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
[ "$FAIL" -eq 0 ]
