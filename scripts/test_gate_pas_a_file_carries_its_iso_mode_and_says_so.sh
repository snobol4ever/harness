#!/usr/bin/env bash
# test_gate_pas_a_file_carries_its_iso_mode_and_says_so.sh -- ISO 7185 6.6.5.2 / 6.9.1, refused at run time, out loud
#
# MEASURED 2026-09-16 by hq_pascal on SCRIP 3d71bfa5b, both modes, working row pascal-pat-suite-427-to-100-percent-by-class.
# EIGHT PAT rejection tests turned on one missing piece of state. The typed-file table carried a buffer and a has-buffer
# flag but NO FILE MODE, so nothing could ask whether a file stood in Generation or Inspection, and an unopened file
# reaching put/get/read/write/eof simply returned FAILDESCR -- the program stopped at the right instruction with rc=1
# and SAID NOTHING. ⛔ THAT SILENCE IS THE DEFECT, not merely the missing check: PAT grades a rejection test on a
# non-zero exit WITH a diagnostic, so a silent abort scores exactly like an acceptance, and a user got an exit code
# with no cause. The table gains a mode (0 Undefined, 1 Generation, 2 Inspection), rewrite sets Generation, reset sets
# Inspection, and every precondition speaks through one voice that names its own ISO clause.
#
# ⭐ THE ORACLE IS NOT THE BAR HERE AND THAT IS WORTH KNOWING BEFORE YOU READ THIS GATE. Measured the same day against
# fpc 3.2.2 -Miso: of the nine mode-and-definedness witnesses, fpc DETECTS ONLY FOUR (1709 rc=105, 1710 and 1715 rc=103,
# 1757 rc=100) and exits 0 on 1712, 1713, 1714, 1716 and 1740. ISO 7185 requires all of them, and PAT is the conformance
# suite, so these arms are graded against the STANDARD and the suite's own rejection criterion, never against fpc. The
# control arm below is the opposite case and IS cut from the oracle, because a legal program has an output to compare.
#
# ⛔ 1713 IS DELIBERATELY NOT HERE: reset on an undefined file. Our reset opens by name rather than requiring a prior
# definition, so curing it means changing what reset DOES, not adding a check beside it; fpc exits 0 on it too. Named,
# not hidden, and left for its own landing.
#
# ARMS: eight vendored PAT witnesses, each required to be REFUSED with a non-empty diagnostic in BOTH modes. ⛔ THE m4
# ARM LINKS AND RUNS rather than merely compiling -- every one of these is a RUNTIME condition, and a compile-only arm
# cannot see a runtime check at all (this gate's own audit sibling made exactly that mistake and reported a landed cure
# as absent). A ninth arm proves the cure DISCRIMINATES: a legal rewrite/write/reset/read round trip over a typed file
# still runs byte-identical to fpc -Miso. FAIL_ONCE=1 flips the first witness's expectation to prove the arm can fail.
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
for b in iso7185prt1709 iso7185prt1710 iso7185prt1712 iso7185prt1714 iso7185prt1715 iso7185prt1716 iso7185prt1740 iso7185prt1757; do
  f="$SRC/$b.pas"; [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing vendored witness $f"; exit 2; }
  N=$((N+1)); bad=""
  o3=$( cd "$T" && timeout -k 5 10s "$SCRIP" "$f" </dev/null 2>&1 ); rc3=$?
  if [ -n "${FAIL_ONCE:-}" ] && [ "$b" = iso7185prt1709 ]; then rc3=0; o3=""; fi
  { [ "$rc3" -ne 0 ] && [ "$rc3" -lt 124 ] && [ -n "$o3" ]; } || bad="m3 (rc=$rc3, ${#o3} bytes of diagnostic)"
  o4=$( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/w.s" "$f" </dev/null 2>&1 ); rc4=$?
  if [ "$rc4" = 0 ]; then
    if ( cd "$T" && cc -m64 -no-pie w.s -o w -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ); then
      o4=$( cd "$T" && timeout -k 5 20s ./w </dev/null 2>&1 ); rc4=$?
    else echo "⛔ GATE REFUSE(2) [$G]: $b compiled but would not link -- cannot grade the m4 arm"; exit 2; fi
  fi
  { [ "$rc4" -ne 0 ] && [ "$rc4" -lt 124 ] && [ -n "$o4" ]; } || bad="$bad m4 (rc=$rc4, ${#o4} bytes of diagnostic)"
  if [ -n "$bad" ]; then echo "  $b ACCEPTED where ISO 7185 6.6.5.2 requires refusal: $bad"; RC=1; else echo "  $b refused with a diagnostic in both modes"; fi
done
cat > "$T/ok.pas" <<'PAS'
program fileroundtrip(output);
var f: file of integer;
    i, x: integer;
begin
   rewrite(f);
   for i := 1 to 5 do write(f, i * 7);
   reset(f);
   while not eof(f) do begin read(f, x); write(x:1, ' ') end;
   writeln;
   writeln('ok')
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 ok.pas >/dev/null 2>&1 && ./ok ) > "$T/ok.ref" 2>&1
[ -s "$T/ok.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no control-arm output"; exit 2; }
ok3=$( cd "$T" && timeout -k 5 20s "$SCRIP" --run ok.pas </dev/null 2>&1 )
if [ "$ok3" = "$(cat "$T/ok.ref")" ]; then echo "  control arm: a legal rewrite/write/reset/read round trip still runs, byte-identical to fpc -Miso"
else echo "  ⛔ control arm FAILED -- the mode checks refuse or miscompile a LEGAL file round trip"; echo "      want: $(cat "$T/ok.ref")"; echo "      got : $ok3"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N file mode/definedness violations refused with a NAMED diagnostic in both modes, and a legal round trip is untouched"
else echo "GATE FAIL(1) [$G]: examined $N vendored PAT witnesses plus one legal control"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
