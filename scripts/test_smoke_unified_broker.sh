#!/bin/bash
# smoke_unified_broker.sh — GOAL-UNIFIED-BROKER fast smoke gate
#
# Self-contained. Run from anywhere with no env vars, no corpus required,
# never blocks on stdin. All programs are inline or in test/ (checked in).
# Target: < 10 seconds, 13+ tests.
#
# Usage: bash test/smoke_unified_broker.sh
# Exit:  0 = all PASS, 1 = any FAIL
#
# Authors: LCherryholmes · Claude Sonnet 4.6
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="$ROOT/scrip"
ICN_CORPUS="$S4E/corpus/tests/icon"
TIMEOUT=8
PASS=0; FAIL=0

_run() {
    local label="$1" file="$2" expected="$3"
    local actual
    actual=$(timeout -k 5 "$TIMEOUT" "$SCRIP" --run "$file" < /dev/null 2>/dev/null)
    if [ "$actual" = "$expected" ]; then
        echo "  PASS $label"; PASS=$((PASS+1))
    else
        echo "  FAIL $label"
        printf "       exp: %s\n" "$(printf '%s' "$expected" | head -3)"
        printf "       got: %s\n" "$(printf '%s' "$actual"   | head -3)"
        FAIL=$((FAIL+1))
    fi
    rm -f "$file"
}

sno() {
    local label="$1" expected="$2" tmp
    tmp=$(mktemp /tmp/ub_XXXXXX.sno)
    cat > "$tmp"
    _run "$label" "$tmp" "$expected"
}

icn() {
    local label="$1" expected="$2" tmp
    tmp=$(mktemp /tmp/ub_XXXXXX.icn)
    cat > "$tmp"
    _run "$label" "$tmp" "$expected"
}

pl() {
    local label="$1" expected="$2" tmp
    tmp=$(mktemp /tmp/ub_XXXXXX.pl)
    cat > "$tmp"
    _run "$label" "$tmp" "$expected"
}

file_test() {
    local label="$1" path="$2" expected="$3" actual
    actual=$(timeout -k 5 "$TIMEOUT" "$SCRIP" --run "$path" < /dev/null 2>/dev/null)
    if [ "$actual" = "$expected" ]; then
        echo "  PASS $label"; PASS=$((PASS+1))
    else
        echo "  FAIL $label"
        printf "       exp: %s\n" "$(printf '%s' "$expected" | head -3)"
        printf "       got: %s\n" "$(printf '%s' "$actual"   | head -3)"
        FAIL=$((FAIL+1))
    fi
}

# ── SNOBOL4 ──────────────────────────────────────────────────────────────────
echo "=== SNOBOL4 ==="

sno "SNO: hello" "Hello, World!" << 'EOF'
        OUTPUT = "Hello, World!"
END
EOF

sno "SNO: arithmetic" "42" << 'EOF'
        OUTPUT = 6 * 7
END
EOF

sno "SNO: pattern replace" "bbb" << 'EOF'
        X = "aaa"
        X "a" = "b"
        X "a" = "b"
        X "a" = "b"
        OUTPUT = X
END
EOF

sno "SNO: concat" "foobar" << 'EOF'
        X = "foo"
        X = X "bar"
        OUTPUT = X
END
EOF

# ── Icon ─────────────────────────────────────────────────────────────────────
echo "=== Icon ==="

# ⭐ seat03 2026-08-30: hello.icn/palindrome.icn were absorbed into the icon rungs
# (icon-scrip-test-icn-absorption) -- materialize them fresh via lib_rungs_extract.sh rather than
# reading loose tests/scrip_test/icon/... files that may no longer be on disk.
RUNGS_DIR="$ICN_CORPUS" RUNGS_EXT=.icn source "$HERE/lib_rungs_extract.sh"
ICN_EXTRACT_DIR="$(mktemp -d)"
trap 'rm -rf "$ICN_EXTRACT_DIR"' EXIT
rungs_extract_origin "scrip_test_icon_hello__hello" "$ICN_EXTRACT_DIR/hello.icn" \
    || { echo "  FAIL ICN: hello (could not extract from icon rungs)"; FAIL=$((FAIL+1)); }
rungs_extract_origin "scrip_test_icon_palindrome__palindrome" "$ICN_EXTRACT_DIR/palindrome.icn" \
    || { echo "  FAIL ICN: palindrome (could not extract from icon rungs)"; FAIL=$((FAIL+1)); }

file_test "ICN: hello" "$ICN_EXTRACT_DIR/hello.icn" "Hello, World!"

icn "ICN: 1 to 5" "$(printf '1\n2\n3\n4\n5')" << 'EOF'
procedure main()
    every write(1 to 5)
end
EOF

icn "ICN: !str iterate" "$(printf 'a\nb\nc')" << 'EOF'
procedure main()
    every write(!("abc"))
end
EOF

echo "  SKIP ICN: user proc suspend (AST_FNC coroutine — post-U-17, wired in U-18)"

file_test "ICN: palindrome" "$ICN_EXTRACT_DIR/palindrome.icn" "$(printf 'yes\nno\nyes')"

if [ -f "$ICN_CORPUS/rung01_paper_compound.icn" ]; then
    expected=$(cat "$ICN_CORPUS/rung01_paper_compound.expected" 2>/dev/null)
    file_test "ICN: rung01 compound" "$ICN_CORPUS/rung01_paper_compound.icn" "$expected"
else
    echo "  SKIP ICN: rung01 (no corpus at $ICN_CORPUS)"
fi

# ── Prolog ───────────────────────────────────────────────────────────────────
echo "=== Prolog ==="

file_test "PL: hello" "$ROOT/../corpus/tests/scrip_test/prolog/hello.pl" "Hello, World!"

pl "PL: fact" "bob" << 'EOF'
:- initialization(main).
parent(tom, bob).
main :- parent(tom, X), write(X), nl.
EOF

pl "PL: ancestor" "bob" << 'EOF'
:- initialization(main).
parent(tom, bob).
parent(bob, ann).
ancestor(X, Y) :- parent(X, Y).
ancestor(X, Y) :- parent(X, Z), ancestor(Z, Y).
main :- ancestor(tom, bob), write(bob), nl.
EOF

pl "PL: arithmetic" "10" << 'EOF'
:- initialization(main).
main :- X is 3 + 7, write(X), nl.
EOF

# ── Raku ─────────────────────────────────────────────────────────────────────
echo "=== Raku ==="

raku() {
    local label="$1" expected="$2" tmp
    tmp=$(mktemp /tmp/ub_XXXXXX.raku)
    cat > "$tmp"
    _run "$label" "$tmp" "$expected"
}

raku "RAKU: hello" "hello world" << 'EOF'
sub main() {
    say('hello world');
}
EOF

raku "RAKU: arithmetic" "42" << 'EOF'
sub main() {
    my $x = 6 * 7;
    say($x);
}
EOF

raku "RAKU: for loop" "$(printf '1\n2\n3\n4\n5')" << 'EOF'
sub main() {
    my $i = 1;
    while ($i <= 5) {
        say($i);
        $i = $i + 1;
    }
}
EOF

# RK-7: polyglot gather smoke test (ref-file based)
RAKU_SCRIP="$ROOT/../corpus/tests/scrip_test/raku_gather.md"
RAKU_REF="$ROOT/../corpus/tests/scrip_test/raku_gather.ref"
if [ -f "$RAKU_SCRIP" ] && [ -f "$RAKU_REF" ]; then
    actual=$(timeout -k 5 "$TIMEOUT" "$SCRIP" --run "$RAKU_SCRIP" < /dev/null 2>/dev/null)
    expected=$(cat "$RAKU_REF")
    if [ "$actual" = "$expected" ]; then
        echo "  PASS raku_gather.md (SNO+RAKU polyglot, BB_PUMP via while loop)"
        PASS=$((PASS+1))
    else
        echo "  FAIL raku_gather.md"
        printf "       exp: %s\n" "$(printf '%s' "$expected" | head -3)"
        printf "       got: %s\n" "$(printf '%s' "$actual"   | head -3)"
        FAIL=$((FAIL+1))
    fi
else
    echo "  SKIP raku_gather.md (file not found)"
fi

# ── Cross-language polyglot (U-19) ───────────────────────────────────────────
echo "=== Cross-language polyglot (U-19) ==="

CROSS="$ROOT/../corpus/tests/scrip_test/cross_lang.md"
REF="$ROOT/../corpus/tests/scrip_test/cross_lang.ref"
if [ -f "$CROSS" ] && [ -f "$REF" ]; then
    actual=$(timeout -k 5 "$TIMEOUT" "$SCRIP" --run "$CROSS" < /dev/null 2>/dev/null)
    expected=$(cat "$REF")
    if [ "$actual" = "$expected" ]; then
        echo "  PASS cross_lang.md (SNO+ICN+PL all three bb_broker modes)"
        PASS=$((PASS+1))
    else
        echo "  FAIL cross_lang.md"
        printf "       exp: %s\n" "$(printf '%s' "$expected" | head -3)"
        printf "       got: %s\n" "$(printf '%s' "$actual"   | head -3)"
        FAIL=$((FAIL+1))
    fi
else
    echo "  SKIP cross_lang.md (file not found)"
fi

# ── Shared NV store (U-23) ───────────────────────────────────────────────────
echo "=== Shared NV store (U-23) ==="

SHARED="$ROOT/../corpus/tests/scrip_test/test_shared_nv.md"
SREF="$ROOT/../corpus/tests/scrip_test/test_shared_nv.ref"
if [ -f "$SHARED" ] && [ -f "$SREF" ]; then
    actual=$(timeout -k 5 "$TIMEOUT" "$SCRIP" --run "$SHARED" < /dev/null 2>/dev/null)
    expected=$(cat "$SREF")
    if [ "$actual" = "$expected" ]; then
        echo "  PASS test_shared_nv.md (SNO+ICN+PL shared NV store)"
        PASS=$((PASS+1))
    else
        echo "  FAIL test_shared_nv.md"
        printf "       exp: %s\n" "$(printf '%s' "$expected" | head -6)"
        printf "       got: %s\n" "$(printf '%s' "$actual"   | head -6)"
        FAIL=$((FAIL+1))
    fi
else
    echo "  SKIP test_shared_nv.md (file not found)"
fi

# ── OE-12: --run polyglot smoke test ──────────────────────────────────────
echo "=== --run polyglot (OE-12) ==="
SMRUN_FILE="$ROOT/../corpus/tests/scrip_test/test_shared_nv.md"
SMRUN_REF="$ROOT/../corpus/tests/scrip_test/test_shared_nv.ref"
if [ -f "$SMRUN_FILE" ] && [ -f "$SMRUN_REF" ]; then
    actual=$(timeout -k 5 8 "$SCRIP" --run "$SMRUN_FILE" 2>/dev/null)
    expected=$(cat "$SMRUN_REF")
    if [ "$actual" = "$expected" ]; then
        echo "  PASS --run test_shared_nv.md (polyglot routes to polyglot_execute)"
        PASS=$((PASS+1))
    else
        echo "  FAIL --run test_shared_nv.md"
        printf "       exp: %s\n" "$(printf '%s' "$expected" | head -6)"
        printf "       got: %s\n" "$(printf '%s' "$actual"   | head -6)"
        FAIL=$((FAIL+1))
    fi
else
    echo "  SKIP --run polyglot test (file not found)"
fi

# ── Result ───────────────────────────────────────────────────────────────────
echo ""
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
