#!/usr/bin/env bash
# test_gate_pas_an_ordinal_function_never_takes_a_real.sh -- ISO 7185 6.6.6.4, refused at compile time
#
# MEASURED 2026-09-23 by hq_pascal on SCRIP 61b3875a5, both modes, row pascal-all-test-suites-of-the-language-
# read-100-percent-on-the-suite-table-the-home-stretch (class row pascal-pat-static-type-and-parameter-checking). ord, succ and pred
# take "an expression of an ordinal-type" and chr "an expression of integer-type" (6.6.6.4). mk_call lowered succ(x) to x + 1 and
# pred(x) to x - 1 whatever x was, so PAT iso7185prt1858 (r := succ(r), r: real) and 1859 (pred) compiled and ran. The check sits in
# call_with_args beside the arity check and fires on a real literal, or on a bare variable whose EVERY declaration in the flat type
# table resolves to real -- a global integer r is not refused because some procedure declares a local r: real (the fourth arm).
# A user routine named ord, chr, succ or pred is never checked. A real EXPRESSION (succ(r + 1)) is not graded here.
# Before landing, every acceptance program in the corpus (PasRungs, the FPC suite, P4, P5, the benchmarks, 456 programs) was compiled
# with the check: the refused set was identical to the tree before, so the check cannot move another suite's row.
#
# ARMS: two vendored PAT witnesses, each required to be REFUSED with a non-empty diagnostic in BOTH modes (m4 compiles, and if the
# compile is accepted, links and runs -- a witness passes that arm if either step refuses). A third arm proves the check
# DISCRIMINATES: ord, succ, pred and chr over integer, char, enumerated, Boolean and trunc() arguments run byte-identical to fpc -Miso
# in both modes. ⛔ A fourth arm is COMPILE-ONLY, and says why: a global integer r shadowed by a local r: real must still be
# ACCEPTED (fpc -Miso accepts it), but SCRIP cannot yet RUN it correctly -- the flat type table coerces the global's assignments to
# real (r := 41 stores 41.0), a separate open defect named in the row's baton -- so this arm grades acceptance against fpc's own
# compile verdict and never the output. FAIL_ONCE=1 flips the first witness to prove the arm can fail.
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
for b in iso7185prt1858 iso7185prt1859; do
  f="$SRC/$b.pas"; [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing vendored witness $f"; exit 2; }
  N=$((N+1)); bad=""
  o3=$( cd "$T" && timeout -k 5 10s "$SCRIP" "$f" </dev/null 2>&1 ); rc3=$?
  if [ -n "${FAIL_ONCE:-}" ] && [ "$b" = iso7185prt1858 ]; then rc3=0; o3=""; fi
  { [ "$rc3" -ne 0 ] && [ "$rc3" -lt 124 ] && [ -n "$o3" ]; } || bad="m3 (rc=$rc3, ${#o3} bytes of diagnostic)"
  m4_run "$f"; o4="$M4O"; rc4=$M4RC
  { [ "$rc4" -ne 0 ] && [ "$rc4" -lt 124 ] && [ -n "$o4" ]; } || bad="$bad m4 (rc=$rc4, ${#o4} bytes of diagnostic)"
  if [ -n "$bad" ]; then echo "  $b ACCEPTED where ISO 7185 requires an ordinal (or integer) argument: $bad"; RC=1; else echo "  $b refused with a diagnostic in both modes"; fi
done
cat > "$T/ok.pas" <<'PAS'
program ordfn(output);
type color = (red, green, blue); number = real;
var r, i, j: integer; c, d, e: char; k: color; b: boolean; x: number;
procedure local;
var q: real;
begin q := 2.5; writeln('local real ', q:4:1, ' ', trunc(q):1, ' ', round(q):1) end;
begin
  r := 41; c := 'b'; k := green; b := false; x := 1.5;
  local;
  i := succ(r); j := pred(r); d := succ(c); e := pred(c);
  writeln(i:1, ' ', j:1, ' ', ord(c):1, ' ', d, ' ', e);
  i := ord(succ(k)); j := ord(pred(k)); writeln(ord(k):1, ' ', i:1, ' ', j:1, ' ', ord(b):1);
  i := trunc(x); d := chr(i + 64); j := succ(trunc(x)); writeln(d, ' ', i:1, ' ', j:1)
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 ok.pas >/dev/null 2>&1 && ./ok ) > "$T/ok.ref" 2>&1
[ -s "$T/ok.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no control-arm output"; exit 2; }
ok3=$( cd "$T" && timeout -k 5 20s "$SCRIP" --run ok.pas </dev/null 2>&1 ); m4_run "$T/ok.pas"; ok4="$M4O"
if [ "$ok3" = "$(cat "$T/ok.ref")" ] && [ "$ok4" = "$(cat "$T/ok.ref")" ]; then echo "  control arm: ord, succ, pred and chr over integer, char, enumerated, Boolean and trunc() arguments run byte-identical to fpc -Miso in both modes"
else echo "  ⛔ control arm FAILED -- the check refuses or miscompiles a LEGAL program"; echo "      want: $(tr '\n' '|' < "$T/ok.ref")"; echo "      m3  : $(printf '%s' "$ok3" | tr '\n' '|')"; echo "      m4  : $(printf '%s' "$ok4" | tr '\n' '|')"; RC=1; fi
cat > "$T/shadow.pas" <<'PAS'
program shadow(output);
var r, i: integer;
procedure p;
var r: real;
begin r := 1.5; i := trunc(r) end;
begin r := 1; p; i := succ(r) + pred(r) + ord(r) end.
PAS
( cd "$T" && "$FPC" -Miso -v0 shadow.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso refused the shadow arm's program -- its verdict is the ref"; exit 2; }
if sh4=$( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/sh.s" shadow.pas </dev/null 2>&1 ); then echo "  shadow arm: a global integer r shadowed by a local r: real is accepted, as fpc -Miso accepts it (compile-only, see header)"
else echo "  ⛔ shadow arm FAILED -- a legal ordinal call on a variable with a same-named real local elsewhere was refused: $sh4"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N ordinal functions of a real refused with a NAMED diagnostic in both modes, and legal ordinal calls are untouched"
else echo "GATE FAIL(1) [$G]: examined $N vendored PAT witnesses plus one legal control"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
