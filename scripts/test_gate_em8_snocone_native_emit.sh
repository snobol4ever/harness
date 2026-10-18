#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_em8_snocone_native_emit.sh — EM-8 gate:
# five Snocone smoke programs compiled via --compile produce correct output.
# Gate: PASS=5 FAIL=0.
#
# Self-contained per RULES.md: paths derived from $0; no env deps.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP:-$ROOT/scrip}"
RT_DIR="${RT_DIR:-$ROOT/out}"
TIMEOUT="${TIMEOUT:-8}"

if [ ! -x "$SCRIP" ]; then
    echo "SKIP scrip not built at $SCRIP"
    exit 0
fi
if [ ! -f "$RT_DIR/libscrip_rt.so" ]; then
    echo "SKIP libscrip_rt.so not built — run: make libscrip_rt"
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0; FAILS=""

emit_test() {
    local label="$1" expected="$2"
    local src="$TMP/${label}.sc"
    cat > "$src"
    "$SCRIP" --compile "$src" > "$TMP/${label}.s" 2>"$TMP/${label}.emit.err" < /dev/null
    if [ $? -ne 0 ] || [ ! -s "$TMP/${label}.s" ]; then
        echo "  FAIL $label (emit failed: $(head -1 "$TMP/${label}.emit.err"))"
        FAIL=$((FAIL+1)); FAILS="$FAILS $label(emit)"; return
    fi
    gcc -no-pie "$TMP/${label}.s" -L"$RT_DIR" -lscrip_rt \
        -Wl,-rpath,"$RT_DIR" -o "$TMP/${label}.prog" 2>"$TMP/${label}.link.err"
    if [ $? -ne 0 ]; then
        echo "  FAIL $label (link failed: $(head -1 "$TMP/${label}.link.err"))"
        FAIL=$((FAIL+1)); FAILS="$FAILS $label(link)"; return
    fi
    local actual
    actual=$(timeout -k 5 "$TIMEOUT" "$TMP/${label}.prog" < /dev/null 2>/dev/null)
    if [ "$actual" = "$expected" ]; then
        echo "  PASS $label"; PASS=$((PASS+1))
    else
        echo "  FAIL $label (expected: $(echo "$expected"|head -1) got: $(echo "$actual"|head -1))"
        FAIL=$((FAIL+1)); FAILS="$FAILS $label(diff)"
    fi
}

echo "=== EM-8 Snocone native codegen-emit smoke ==="

emit_test "output" "hello" << 'EOF'
OUTPUT = "hello";
EOF

emit_test "arith" "5" << 'EOF'
OUTPUT = 2 + 3;
EOF

emit_test "procedure" "42" << 'EOF'
function Double(n) {
    Double = n + n; return;
}
OUTPUT = Double(21);
EOF

emit_test "if_eq" "yes" << 'EOF'
if (EQ(2 + 2, 4)) { OUTPUT = "yes"; } else { OUTPUT = "no"; }
EOF

emit_test "while" "$(printf '1\n2\n3')" << 'EOF'
i = 1;
while (LE(i, 3)) {
    OUTPUT = i;
    i = i + 1;
}
EOF

echo ""
echo "PASS=$PASS FAIL=$FAIL"
[ -n "$FAILS" ] && echo "FAILS:$FAILS"
[ "$FAIL" -eq 0 ]
