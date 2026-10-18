#!/usr/bin/env bash
# test_gate_pas_a_case_statement_with_no_matching_constant_is_an_error.sh -- ISO 7185 6.8.3.5, refused at RUN time, out loud
#
# MEASURED 2026-09-23 by hq_pascal on SCRIP e6f13b4b6, both modes, row pascal-all-test-suites-of-the-language-read-100-percent-on-the-
# suite-table-the-home-stretch (class row pascal-pat-runtime-value-guards-div-mod-case). "One of the case-constants shall be equal to
# the value of the case-index upon entry to the case-statement; otherwise, it shall be an error" (6.8.3.5). The case chain ended in
# a TT_SUCCEED, so a case-index matching no constant fell through silently and PAT iso7185prt1751 (case 4 of 1, 2, 3) ran to rc=0.
# The chain's last else is now a call to __pas_rterr, the Pascal runtime arm of by_name_dispatch.c that speaks through the same
# voice as the file-state errors (pas_file_err: "scrip: pascal runtime error: ISO 7185 <clause>: <what>", rc=1). A matched arm
# never reaches it, so the check costs nothing on any path a legal program takes.
#
# ⭐ THE ORACLE IS NOT THE BAR FOR THE WITNESS, AND THAT IS WORTH KNOWING BEFORE YOU READ THIS GATE: fpc -Miso does NOT detect a
# case-index that matches no constant (it runs 1751 to rc=0), so the witness arm is graded against the STANDARD and PAT's own
# rejection criterion. The control arm is the opposite case and IS cut from fpc -Miso, because a legal program has an output to
# compare. Measured before landing, every graded Pascal program RUN in both modes (the rungs 246, the FPC suite 181, the eleven
# benchmarks, PAT's acceptance programs): no program's cell moved except 1751's, so no legal corpus program falls through a case.
#
# ARMS: one vendored PAT witness, required to be REFUSED at run time with a non-empty diagnostic in BOTH modes (m4 compiles, links
# and RUNS -- this is a runtime condition, and a compile-only arm cannot see it). A second arm proves the check DISCRIMINATES:
# nested case-statements over integer, Boolean, char and enumerated case-indexes, matching on first, middle and last arms and on
# constant lists, run byte-identical to fpc -Miso in both modes. FAIL_ONCE=1 flips the witness to prove the arm can fail.
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
m4_run() { M4O=$( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/w.s" "$1" </dev/null 2>&1 ); M4RC=$?
  if [ "$M4RC" = 0 ]; then
    ( cd "$T" && cc -m64 -no-pie w.s -o w -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: $1 compiled but would not link -- cannot grade the m4 arm"; exit 2; }
    M4O=$( cd "$T" && timeout -k 5 20s ./w </dev/null 2>&1 ); M4RC=$?
  fi; }
for b in iso7185prt1751; do
  f="$SRC/$b.pas"; [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing vendored witness $f"; exit 2; }
  N=$((N+1)); bad=""
  o3=$( cd "$T" && timeout -k 5 10s "$SCRIP" "$f" </dev/null 2>&1 ); rc3=$?
  if [ -n "${FAIL_ONCE:-}" ] && [ "$b" = iso7185prt1751 ]; then rc3=0; o3=""; fi
  { [ "$rc3" -ne 0 ] && [ "$rc3" -lt 124 ] && [ -n "$o3" ]; } || bad="m3 (rc=$rc3, ${#o3} bytes of diagnostic)"
  m4_run "$f"; o4="$M4O"; rc4=$M4RC
  { [ "$rc4" -ne 0 ] && [ "$rc4" -lt 124 ] && [ -n "$o4" ]; } || bad="$bad m4 (rc=$rc4, ${#o4} bytes of diagnostic)"
  if [ -n "$bad" ]; then echo "  $b RAN TO COMPLETION where ISO 7185 requires an error: $bad"; RC=1; else echo "  $b stopped with a runtime diagnostic in both modes"; fi
done
cat > "$T/ok.pas" <<'PAS'
program casectl(output);
type color = (red, green, blue);
var i, n: integer; c: char; k: color;
begin
  n := 0;
  for i := 1 to 6 do
    case i of
      1, 2: n := n + 1;
      3: case odd(i) of true: n := n + 10; false: n := n + 1000 end;
      4, 5, 6: n := n + 100
    end;
  for c := 'a' to 'c' do case c of 'a': n := n + 1; 'b', 'c': n := n + 2 end;
  for k := red to blue do case k of blue: writeln('last arm'); red, green: n := n + 5 end;
  writeln(n:1)
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 ok.pas >/dev/null 2>&1 && ./ok ) > "$T/ok.ref" 2>&1
[ -s "$T/ok.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no control-arm output"; exit 2; }
ok3=$( cd "$T" && timeout -k 5 20s "$SCRIP" --run ok.pas </dev/null 2>&1 ); m4_run "$T/ok.pas"; ok4="$M4O"
if [ "$ok3" = "$(cat "$T/ok.ref")" ] && [ "$ok4" = "$(cat "$T/ok.ref")" ]; then echo "  control arm: nested case-statements over integer, Boolean, char and enumerated indexes run byte-identical to fpc -Miso in both modes"
else echo "  ⛔ control arm FAILED -- the check refuses or miscompiles a LEGAL program"; echo "      want: $(tr '\n' '|' < "$T/ok.ref")"; echo "      m3  : $(printf '%s' "$ok3" | tr '\n' '|')"; echo "      m4  : $(printf '%s' "$ok4" | tr '\n' '|')"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N case-statement(s) with no matching constant stopped with a NAMED runtime diagnostic in both modes, and matching ones are untouched"
else echo "GATE FAIL(1) [$G]: examined $N vendored PAT witnesses plus one legal control"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
