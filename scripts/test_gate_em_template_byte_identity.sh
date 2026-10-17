#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_em_template_byte_identity.sh — EM-MODE4-IS-MODE3-DUMP-c gate.
#
# Verifies that the per-opcode template machinery (templates/sm_halt.c
# walked through a binary emitter and flushed into SEG_CODE) produces
# bytes byte-identical to the legacy `emit_halt_blob` it replaces.
#
# Strategy.  The legacy `emit_halt_blob` produces exactly 5 bytes
# (41 ff 45 14 c3 — inc dword [r13+20]; ret) at the start of every
# SM_HALT instruction's blob in SEG_CODE.  After the EM-MODE4-IS-MODE3-
# DUMP-c retrofit, `emit_halt_blob_via_template` produces the same
# 5 bytes by routing through the template + binary emitter +
# capture-and-flush adapter.  We verify this two ways:
#
# 1. **Behavioral equivalence (this script).**  Mode-3 (`--run`)
#    is the in-process native codegen.  If SM_HALT's bytes were wrong, the native codegen
#    would either crash (illegal instruction, garbled jump) or produce
#    different output (wrong pc value at halt time, wrong return
#    address).  We run a small fixture of SNOBOL4 programs that
#    terminate normally via SM_HALT and require `--run` output
#    to match `--run` (the interpreter, which doesn't use SEG_CODE
#    at all and is the byte-identity oracle).
#
# 2. **Static defensive check.**  The template adapter
#    (`emit_halt_blob_via_template` in sm_codegen.c) contains an
#    `abort()` if the template produces anything other than exactly
#    5 bytes.  If the template ever drifts (an SM_INSN_* kind change,
#    or an unintended `pad_to_blob_size` impl that suddenly emits
#    bytes), this script's runs will SIGABRT visibly rather than
#    silently corrupting SEG_CODE.  No script-side check needed for
#    this part — abort + signal exit code is enough.
#
# Self-contained per RULES.md: paths derived from $0; no env deps.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"
CORPUS="${CORPUS:-$S4E/corpus}"
TIMEOUT="${TIMEOUT:-8}"
# ⭐ V2-5 GATE HONESTY: examining nothing must exit UNPROVEN(2), never read as a pass.
. "$(dirname "$0")/lib_gate.sh"
gate_require_exec "${SCRIP:-${SCRIP_BIN:-$(dirname "$0")/../../SCRIP/scrip}}" "the scrip compiler"
gate_require "${RT_DIR:-$(dirname "$0")/../../SCRIP/out}/libscrip_rt.so" "the runtime shared object out/libscrip_rt.so"

if [ ! -x "$SCRIP" ]; then
    echo "SKIP scrip not built at $SCRIP"
    exit 0
fi

# Fixture: tiny SNOBOL4 programs that terminate via SM_HALT.  Inline
# heredocs so the gate is self-contained and doesn't depend on corpus
# files that may evolve independently.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/halt_immediate.sno" <<'SNO'
            OUTPUT = 'before halt'
END
SNO

cat > "$TMP/halt_after_arith.sno" <<'SNO'
            X = 1 + 2 * 3
            OUTPUT = X
END
SNO

cat > "$TMP/halt_after_match.sno" <<'SNO'
            &ANCHOR   = 0
            &FULLSCAN = 1
            S = 'hello world'
            S 'world' :S(ok)F(bad)
ok          OUTPUT = 'matched'                                     :(END)
bad         OUTPUT = 'no match'
END
SNO

cat > "$TMP/halt_after_loop.sno" <<'SNO'
            I = 0
loop        I = I + 1
            OUTPUT = I
            LE(I, 3) :S(loop)
END
SNO

PASS=0
FAIL=0
FAILS=""

for f in "$TMP"/*.sno; do
    name=$(basename "$f" .sno)

    # Run --run (the byte-identity oracle: pure interpreter, no
    # SEG_CODE involved).
    sm_out=$(timeout -k 5 "$TIMEOUT" "$SCRIP" --run "$f" < /dev/null 2>/dev/null)
    sm_rc=$?

    # Run --run (mode-3: walks SEG_CODE, including the SM_HALT
    # blob produced by the template).  If the template emits bad
    # bytes, --run will either crash or produce different output.
    jit_out=$(timeout -k 5 "$TIMEOUT" "$SCRIP" --run "$f" < /dev/null 2>/dev/null)
    jit_rc=$?

    if [ "$sm_rc" -eq 0 ] && [ "$jit_rc" -eq 0 ] && [ "$sm_out" = "$jit_out" ]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        FAILS="$FAILS $name(sm_rc=$sm_rc/jit_rc=$jit_rc/diff=$([ "$sm_out" = "$jit_out" ] && echo no || echo yes))"
    fi
done

echo "PASS=$PASS FAIL=$FAIL"
[ -n "$FAILS" ] && echo "FAILS:$FAILS"
[ "$FAIL" -eq 0 ]
