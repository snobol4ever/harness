#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ../harness/scripts/test_gate_sn7_beauty_self_host.sh — SN-7 gate:
# every *_driver.sno in corpus/tests/snobol4/beauty_suite/, under BOTH
# real modes (--run = m3 BINARY, --compile = m4 TEXT),
# diff=0 vs its pre-baked .ref file (SPITBOL ground truth where valid; some
# drivers have .ref files that reflect correct behavior SPITBOL itself fails
# on — see RULES.md on .ref authority).
#
# B-9 FIX (BOARD, s-earlier session): the loop previously read
# `for mode in --run --run --run` (before that, `--interp --interp --run`,
# mechanically flattened when --interp was eradicated project-wide) — it
# NEVER invoked --compile, so this gate has apparently never once measured
# mode 4 on beauty_suite. FAIL counts before this fix were exactly 3x the
# true --run-only fail count, all under the label "--run". Fixed to name
# both modes explicitly so a future flatten-style edit cannot silently
# collapse it again.
#
# BEAUTY-CN FIX (this session): the B-9 fix above invoked `--compile` and
# diffed its raw stdout against the behavioural `.ref` — but `--compile`
# alone only emits x86-64 TEXT asm to stdout, it does not assemble/link/run.
# Every one of the 17 "--compile" rows was diffing assembly text against a
# beautified/behavioural reference and FAILING 17/17, unconditionally, since
# the B-9 fix landed (verified: `--run` 17/17, `--compile` 0/17 at HEAD
# before this fix). Repaired to the same compile->gcc->run pipeline
# scorecard_snobol4.sh's run_one already uses for m4.
#
# Self-contained per RULES.md: paths derived from $0; no env deps.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
SCRIP_ROOT="$(cd "$(dirname "$SCRIP")" && pwd)"
CORPUS="${CORPUS:-$S4E/corpus}"
BEAUTY="$CORPUS/tests/snobol4/beauty_suite"
TIMEOUT="${TIMEOUT:-30}"

if [ ! -x "$SCRIP" ]; then
    echo "GATE UNPROVEN(2) [sn7_beauty_self_host]: scrip not built at $SCRIP -- NOT a pass, the self-host was never attempted"
    exit 2
fi
if [ ! -d "$BEAUTY" ]; then
    echo "GATE UNPROVEN(2) [sn7_beauty_self_host]: corpus not populated at $CORPUS -- NOT a pass, zero programs were compared"
    exit 2
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
# ⭐ V2-5 GATE HONESTY: examining nothing must exit UNPROVEN(2), never read as a pass.
. "$(dirname "$0")/lib_gate.sh"
gate_require_exec "${SCRIP:-${SCRIP_BIN:-$(dirname "$0")/../../SCRIP/scrip}}" "the scrip compiler"
gate_require "${RT_DIR:-$(dirname "$0")/../../SCRIP/out}/libscrip_rt.so" "the runtime shared object out/libscrip_rt.so"
FAILS=""

for sno in "$BEAUTY"/*_driver.sno; do
    [ ! -f "$sno" ] && continue
    name=$(basename "$sno" .sno)
    ref="$BEAUTY/${name}.ref"
    [ ! -f "$ref" ] && continue

    got=$(SNO_LIB="$BEAUTY" timeout -k 5 "$TIMEOUT" "$SCRIP" --run "$sno" < /dev/null 2>/dev/null || true)
    if diff <(printf '%s\n' "$got") "$ref" > /dev/null 2>&1; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        FAILS="$FAILS $name(--run)"
    fi

    m4ok=0
    if SNO_LIB="$BEAUTY" timeout -k 5 "$TIMEOUT" "$SCRIP" --compile "$sno" < /dev/null > "$WORK/$name.s" 2>/dev/null && [ -s "$WORK/$name.s" ]; then
        if gcc -no-pie "$WORK/$name.s" -L"$SCRIP_ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$SCRIP_ROOT/out" -o "$WORK/$name.bin" 2>/dev/null; then
            got4=$(cd "$BEAUTY" && SNO_LIB="$BEAUTY" timeout -k 5 "$TIMEOUT" "$WORK/$name.bin" < /dev/null 2>/dev/null || true)
            if diff <(printf '%s\n' "$got4") "$ref" > /dev/null 2>&1; then
                m4ok=1
            fi
        fi
    fi
    if [ "$m4ok" -eq 1 ]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        FAILS="$FAILS $name(--compile)"
    fi
done

echo "PASS=$PASS FAIL=$FAIL"
[ -n "$FAILS" ] && echo "FAILS:$FAILS"
[ "$FAIL" -eq 0 ]
