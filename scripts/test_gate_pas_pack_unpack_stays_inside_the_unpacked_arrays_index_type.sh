#!/usr/bin/env bash
# test_gate_pas_pack_unpack_stays_inside_the_unpacked_arrays_index_type.sh -- ISO 7185 6.6.5.4, refused at compile time
#
# MEASURED 2026-09-13 by the coo on origin 93b4d8ed4, both modes, taking row pascal-pat-array-pack-unpack-bounds.
# EIGHT PAT rejection tests were ACCEPTED SILENTLY, rc=0 with no output: pack/unpack given a starting index that is not
# assignment-compatible with the unpacked array's index-type (1726, 1729), a starting index below the array's low bound
# (1867, 1868), a copy that runs off the end mid-way (1728, 1731), and a copy that overruns the end entirely (1869, 1870).
#
# ⛔ SIX OF THE EIGHT ARE MY OWN REGRESSION AND THAT IS WHY THEY ARE HERE: before `0a6e5520a` implemented pack/unpack at
# all, these programs were refused for the unrelated reason that the procedures did not exist, and PAT -- a suite of
# REJECTION tests -- scored that refusal as a PASS. Implementing the feature without its error conditions turned eight
# accidental passes into honest failures. A capability landing owes its ISO error conditions in the same breath.
#
# THE CURE, and why it costs nothing at run time: the Pascal array table never recorded a declared LOW bound (only the
# high), so the pack lowering assumed 1 and could not compare a starting index against the real index-type at all. The
# table now carries `low`, the lowering uses it, and the call site refuses when the touched range [start, start+count-1]
# lies outside [low, high] of the unpacked array, or when the ordinal parameter is a char where the index-type is
# integer. Every witness here has a literal starting index, so every one of these is decided in the parser and no
# generated code changes. ⛔ A RUNTIME check for a VARIABLE index (PAT 1828) is deliberately NOT in this cure: it would
# put a call on every Pascal array access, which is CONCERN 2's surface and an ask to hq_P, not a thing to bolt on here.
#
# ARMS: eight programs from the vendored PAT suite, each required to be REFUSED with a non-empty diagnostic in BOTH
# modes -- the suite's own criterion. A ninth arm proves the cure DISCRIMINATES rather than refusing everything: a legal
# pack over exactly the array's own range still compiles and runs, byte-identical to fpc -Miso. FAIL_ONCE=1 flips the
# first witness's expectation to prove the arm can fail.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- the control arm's ref is CUT FROM THE ORACLE"; exit 2; }
SRC="$S4E/corpus/packages/pascal/pat"
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
for b in iso7185prt1726 iso7185prt1728 iso7185prt1729 iso7185prt1731 iso7185prt1867 iso7185prt1868 iso7185prt1869 iso7185prt1870; do
  f="$SRC/$b.pas"; [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing vendored witness $f"; exit 2; }
  N=$((N+1)); bad=""
  o3=$( cd "$T" && timeout -k 5 10s "$SCRIP" "$f" </dev/null 2>&1 ); rc3=$?
  if [ -n "${FAIL_ONCE:-}" ] && [ "$b" = iso7185prt1726 ]; then rc3=0; o3=""; fi
  { [ "$rc3" -ne 0 ] && [ "$rc3" -lt 124 ] && [ -n "$o3" ]; } || bad="m3 (rc=$rc3, ${#o3} bytes of diagnostic)"
  o4=$( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o /dev/null "$f" </dev/null 2>&1 ); rc4=$?
  { [ "$rc4" -ne 0 ] && [ "$rc4" -lt 124 ] && [ -n "$o4" ]; } || bad="$bad m4 (rc=$rc4, ${#o4} bytes of diagnostic)"
  if [ -n "$bad" ]; then echo "  $b ACCEPTED where ISO 7185 6.6.5.4 requires refusal: $bad"; RC=1; else echo "  $b refused with a diagnostic in both modes"; fi
done
cat > "$T/ok.pas" <<'PAS'
program packok(output);
var a: array [1..10] of integer;
    b: packed array [1..10] of integer;
    i: integer;
begin
   for i := 1 to 10 do a[i] := i * 3;
   pack(a, 1, b);
   for i := 1 to 10 do write(b[i]:1, ' ');
   writeln
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 ok.pas >/dev/null 2>&1 && ./ok ) > "$T/ok.ref" 2>&1
[ -s "$T/ok.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no control-arm output"; exit 2; }
ok3=$( cd "$T" && timeout -k 5 20s "$SCRIP" --run ok.pas </dev/null 2>&1 )
if [ "$ok3" = "$(cat "$T/ok.ref")" ]; then echo "  control arm: a legal pack over the array's own range still runs, byte-identical to fpc -Miso"
else echo "  ⛔ control arm FAILED -- the cure refuses or miscompiles a LEGAL pack"; echo "      want: $(cat "$T/ok.ref")"; echo "      got : $ok3"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N pack/unpack range violations refused with a diagnostic in both modes, and a legal pack is untouched"
else echo "GATE FAIL(1) [$G]: examined $N vendored PAT witnesses plus one legal control"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
