#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ../harness/scripts/test_gate_em_beauty_subsystems_mode4.sh — EM-7d-prep gate:
# every *_driver.sno in corpus/tests/snobol4/beauty_suite/, under
#   --compile    (mode 4: emit .s, link to libscrip_rt.so, run binary)
# produces output byte-identical to the same driver under
#   --run            (mode 2: proven SM interpreter)
#
# This is a PARITY gate, not a correctness gate.  The beauty drivers'
# own .ref files belong to GOAL-PARSER-SNOBOL4 (rung SN-7-8) and may be
# regressing independently.  What this gate measures is solely whether
# mode-4 (emit binary) tracks mode-3/--run (runtime interp) — i.e.
# whether the emitter pipeline + libscrip_rt.so reproduces what the SM
# interpreter does on the same input.  Mode-4 cannot be more correct
# than mode-3; the goal here is simply that they agree.
#
# Self-contained per RULES.md: paths derived from $0; no env deps.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP:-$ROOT/scrip}"
RT_DIR="${RT_DIR:-$ROOT/out}"
CORPUS="${CORPUS:-$S4E/corpus}"
BEAUTY="$CORPUS/tests/snobol4/beauty_suite"
TIMEOUT="${TIMEOUT:-30}"

if [ ! -x "$SCRIP" ]; then
    echo "SKIP scrip not built at $SCRIP"
    exit 0
fi
if [ ! -f "$RT_DIR/libscrip_rt.so" ]; then
    echo "SKIP libscrip_rt.so not built — run: make libscrip_rt"
    exit 0
fi
if [ ! -d "$BEAUTY" ]; then
    echo "SKIP corpus not populated at $CORPUS"
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

PASS=0
FAIL_EMIT=0
FAIL_LINK=0
FAIL_DIFF=0
FAILS=""

for sno in "$BEAUTY"/*_driver.sno; do
    [ ! -f "$sno" ] && continue
    name=$(basename "$sno" .sno)

    # mode-3 oracle: --run on the same source.  Don't gate on its
    # rc; just capture what it produces.  If it segfaults, mode-4
    # parity means mode-4 should produce the same (empty) output.
    # bash -c runs the child in a fresh shell so SIGSEGV trap message
    # (printed by the parent's job-control) doesn't reach our stderr.
    bash -c "SNO_LIB='$BEAUTY' timeout '$TIMEOUT' '$SCRIP' --run '$sno' < /dev/null" \
        > "$name.sm.out" 2>/dev/null || true

    # mode-4: emit -> assemble+link -> run.
    SNO_LIB="$BEAUTY" "$SCRIP" --compile "$sno" \
        > "$name.s" 2> "$name.emit.err"
    if [ $? -ne 0 ] || [ ! -s "$name.s" ]; then
        FAIL_EMIT=$((FAIL_EMIT + 1))
        FAILS="$FAILS $name(emit)"
        continue
    fi
    gcc -no-pie "$name.s" -L"$RT_DIR" -lscrip_rt \
        -Wl,-rpath,"$RT_DIR" -o "$name.prog" 2> "$name.link.err"
    if [ $? -ne 0 ]; then
        FAIL_LINK=$((FAIL_LINK + 1))
        FAILS="$FAILS $name(link)"
        continue
    fi
    bash -c "SNO_LIB='$BEAUTY' timeout '$TIMEOUT' ./'$name.prog' < /dev/null" \
        > "$name.m4.out" 2>/dev/null || true

    if diff -q "$name.m4.out" "$name.sm.out" > /dev/null 2>&1; then
        PASS=$((PASS + 1))
    else
        FAIL_DIFF=$((FAIL_DIFF + 1))
        FAILS="$FAILS $name(diff)"
    fi
done

echo "PASS=$PASS FAIL=$((FAIL_EMIT + FAIL_LINK + FAIL_DIFF))  (emit=$FAIL_EMIT link=$FAIL_LINK diff=$FAIL_DIFF)"
[ -n "$FAILS" ] && echo "FAILS:$FAILS"
[ "$((FAIL_EMIT + FAIL_LINK + FAIL_DIFF))" -eq 0 ]
