#!/usr/bin/env bash
# test_gate_sno_gimpel_infinip_driver_answers_as_spitbol_in_both_modes.sh -- the witness of the Gimpel regression the ceo
# rowed at CEO-1776: corpus packages/snobol4/gimpel/infinip_driver.sno (the grading vehicle of infinip.spt, CEO-1269) printed
# the oracle's answer in both modes at SCRIP 2781bf6e4 (Gimpel 145/145) and at 6b9c1519f mode 4 aborts rc 134 in the
# collector: "[GC-CHAIN] REFUSED: the chain over the maps stops short (top-above-segment) after 1 frame(s)". The ref is CUT
# FROM THE ORACLE at run time (sbl -bf in the package directory, as the board runs it), never typed; mode 3 is the control
# arm, mode 4 is linked the way the harness grades (PIE, CEO-1536). rc 0 both arms equal the oracle / 1 an arm diverged /
# 2 could not measure (no scrip, no runtime, no oracle, no corpus, or the oracle refused its own witness).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
LIBDIR="$ROOT/out"; [ -f "$LIBDIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no libscrip_rt.so in $LIBDIR"; exit 2; }
SBL="${SBL_BIN:-/home/resources/x64/bin/sbl}"; [ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no sbl at $SBL -- the ref is cut from the oracle at run time"; exit 2; }
PKG="${CORPUS_ROOT:-$(cd "$ROOT/.." && pwd)/corpus}/packages/snobol4/gimpel"
[ -f "$PKG/infinip_driver.sno" ] && [ -f "$PKG/infinip.inc" ] || { echo "⛔ GATE REFUSE(2) [$G]: no infinip_driver.sno or infinip.inc under $PKG"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
( cd "$PKG" && timeout -k 5 60s "$SBL" -bf infinip_driver.sno </dev/null ) > "$T/ref" 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: the oracle refused its own witness -- no ref to grade against"; exit 2; }
[ -s "$T/ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle printed an EMPTY ref -- an instrument that cannot measure refuses"; exit 2; }
RC=0
( cd "$PKG" && timeout -k 5 20s "$SCRIP" infinip_driver.sno </dev/null ) > "$T/m3" 2>&1; r3=$?
if [ "$r3" = 0 ] && cmp -s "$T/m3" "$T/ref"; then echo "  m3 PASS ($(wc -l < "$T/ref") lines equal to sbl -bf)"
else echo "  m3 FAIL (rc=$r3, $(diff "$T/m3" "$T/ref" | grep -c '^[<>]') differing lines; first: $(diff "$T/m3" "$T/ref" | grep -m1 '^[<>]' | cut -c1-160))"; RC=1; fi
( cd "$PKG" && "$SCRIP" --compile -o "$T/w.s" infinip_driver.sno </dev/null ) >"$T/c.log" 2>&1 && gcc "$T/w.s" -L"$LIBDIR" -lscrip_rt -lm -Wl,-rpath,"$LIBDIR" -o "$T/w" 2>"$T/ld.log" || { echo "⛔ GATE REFUSE(2) [$G]: mode-4 compile or link failed, so the mode-4 arm measured nothing: $(head -c 200 "$T/c.log" "$T/ld.log" | tr '\n' ' ')"; exit 2; }
( cd "$PKG" && timeout -k 5 20s "$T/w" </dev/null ) > "$T/m4" 2>"$T/m4.err"; r4=$?
if [ "$r4" = 0 ] && cmp -s "$T/m4" "$T/ref"; then echo "  m4 PASS ($(wc -l < "$T/ref") lines equal to sbl -bf)"
else echo "  m4 FAIL (rc=$r4, $(diff "$T/m4" "$T/ref" | grep -c '^[<>]') differing lines; stderr: $(grep -m1 . "$T/m4.err" | cut -c1-200))"; RC=1; fi
if [ "$RC" = 0 ]; then echo "✅ GATE PASS(0) [$G]: Gimpel's infinip driver answers as sbl -bf in mode 3 and mode 4"
else echo "⛔ GATE FAIL(1) [$G]: Gimpel's infinip driver diverges from sbl -bf (examined 2 arms)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
