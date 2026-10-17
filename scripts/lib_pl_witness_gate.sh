#!/usr/bin/env bash
# lib_pl_witness_gate.sh -- the shared body of a Prolog witness gate: write the witness files into a scratch directory, run the program in
# mode 3 and as a mode-4 binary (compile -o, link against out/libscrip_rt.so, run), and compare each mode's stdout with the expected text
# cut from swipl. Sourced by a gate that sets GATE_NAME and calls pl_witness <label> <main.pl> <expected>; pl_witness_end prints the verdict.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
pl_refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || pl_refuse "no scrip binary at $SCRIP -- run make first"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
PLW_TMP="$(mktemp -d)"; trap 'rm -rf "$PLW_TMP"' EXIT
PLW_RED=0
pl_witness() {
    local label="$1" main="$2" want="$3" got rc
    got="$(cd "$PLW_TMP" && timeout -k 5 60 "$SCRIP" "$main" </dev/null 2>"$PLW_TMP/err")"; rc=$?
    if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  $label m3"; else echo "  RED $label m3: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|' | cut -c1-120)] err=[$(head -c 200 "$PLW_TMP/err" | tr '\n' '|')]"; PLW_RED=$((PLW_RED+1)); fi
    if (cd "$PLW_TMP" && timeout -k 5 120 "$SCRIP" --compile -o "$PLW_TMP/w.s" "$main" </dev/null 2>"$PLW_TMP/err") && gcc -m64 -no-pie "$PLW_TMP/w.s" -o "$PLW_TMP/w.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$PLW_TMP/err"; then
        got="$(cd "$PLW_TMP" && timeout -k 5 60 ./w.bin </dev/null 2>"$PLW_TMP/err")"; rc=$?
        if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  $label m4"; else echo "  RED $label m4: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|' | cut -c1-120)] err=[$(head -c 200 "$PLW_TMP/err" | tr '\n' '|')]"; PLW_RED=$((PLW_RED+1)); fi
    else echo "  RED $label m4: the compile or link refused: $(head -c 200 "$PLW_TMP/err" | tr '\n' '|')"; PLW_RED=$((PLW_RED+1)); fi
}
pl_witness_end() { [ "$PLW_RED" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $PLW_RED arm(s) red"; exit 1; }; echo "GATE PASS [$GATE_NAME]: $1"; exit 0; }
