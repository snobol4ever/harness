#!/usr/bin/env bash
# test_gate_pas_a_goto_never_enters_a_structured_statement.sh -- ISO 7185 6.8.1, refused at compile time
#
# MEASURED 2026-09-23 by hq_pascal on SCRIP 922c376ae, both modes, row pascal-all-test-suites-of-the-language-read-100-percent-on-the-
# suite-table-the-home-stretch (class row pascal-pat-goto-label-scope-validity). A goto may name label L only if the statement S that
# L prefixes contains the goto, or S is a statement of a statement-sequence containing the goto, or S is a statement of the outermost
# statement-sequence of an enclosing block. SCRIP checked none of it: PAT iso7185prt1832/1837/1845/1902/1903 jump INTO a for body,
# 1833 jumps from a procedure into a for body of main, and 1835 names a label that prefixes nothing -- all seven ran.
# ⭐ HOW: pascal_sem.c walks each procedure body once, carrying the path of structured statements (node, child) above each goto;
# statement-sequences (TT_PROGRAM, TT_SEQ_EXPR, a label's own TT_LABEL_DEF) add no step. The label's path must be a prefix of the
# goto's. A goto whose label is not in its own block searches the enclosing blocks (children precede parents in the procedure list),
# where the label must sit in the outermost sequence. The goto node now carries its source line, so the diagnostic names it.
# ⛔⭐ NO LENIENCY, BY RULING (ceo CEO-1228, 2026-09-23, on hq_pascal's question): this check once accepted one non-ISO shape by
# name -- a goto from one branch of a structured statement into a statement that is directly another branch (then -> else) --
# because Pascal-P4's insymbol does exactly that (goto 3). A by-name exception is the per-program accommodation the one-oracle law
# forbids, so it is gone: P4's vendored comp.pas carries a documented source patch instead (corpus/packages/pascal/p4/PATCHES.md,
# patch 6; SCRIP runs the patched and original compilers to byte-identical generation-1 output), and corpus/packages/pascal/pcom.pas,
# a P4-lineage copy no suite grades, is now refused at that line. Before landing, every acceptance program in the corpus was compiled
# with the check (PasRungs, the FPC suite, P4, P5, the benchmarks; 38 of them use goto): zero tripped but pcom.pas, named above; the
# other trips were the P5 copies of these same seven tests.
#
# ARMS: seven vendored PAT witnesses, each REFUSED with a non-empty diagnostic in BOTH modes (m4 compiles, and if the compile is
# accepted, links and runs). An eighth arm proves the check DISCRIMINATES: backward and forward gotos in one sequence, a goto out of a
# for body, a forward goto out of an if branch, and a (compiled, not taken) non-local goto to main's outermost sequence run byte-identical to
# fpc -Miso in both modes. The non-local goto is NOT taken because SCRIP does not yet perform one (it falls through; row
# pascal-fpc-class-nonlocal-control-transfer) -- this gate grades the compile-time rule, not that. FAIL_ONCE=1 flips the first witness.
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
for b in iso7185prt1832 iso7185prt1833 iso7185prt1835 iso7185prt1837 iso7185prt1845 iso7185prt1902 iso7185prt1903; do
  f="$SRC/$b.pas"; [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing vendored witness $f"; exit 2; }
  N=$((N+1)); bad=""
  o3=$( cd "$T" && timeout -k 5 10s "$SCRIP" "$f" </dev/null 2>&1 ); rc3=$?
  if [ -n "${FAIL_ONCE:-}" ] && [ "$b" = iso7185prt1832 ]; then rc3=0; o3=""; fi
  { [ "$rc3" -ne 0 ] && [ "$rc3" -lt 124 ] && [ -n "$o3" ]; } || bad="m3 (rc=$rc3, ${#o3} bytes of diagnostic)"
  m4_run "$f"; o4="$M4O"; rc4=$M4RC
  { [ "$rc4" -ne 0 ] && [ "$rc4" -lt 124 ] && [ -n "$o4" ]; } || bad="$bad m4 (rc=$rc4, ${#o4} bytes of diagnostic)"
  if [ -n "$bad" ]; then echo "  $b ACCEPTED where ISO 7185 6.8.1 forbids the goto: $bad"; RC=1; else echo "  $b refused with a diagnostic in both modes"; fi
done
cat > "$T/ok.pas" <<'PAS'
program gotoctl(output);
label 9;
var n: integer;
procedure bail(k: integer);
begin if k > 2 then goto 9; writeln('bail kept ', k) end;
procedure scan;
label 1, 2, 3;
var j, k: integer;
begin
  j := 0;
  1: j := j + 1;
  if j < 3 then goto 1;
  for k := 1 to 5 do begin
    if k = 4 then goto 2;
    writeln('loop ', k)
  end;
  2: writeln('scan done ', j);
  if j = 3 then begin writeln('then branch'); goto 3 end
  else writeln('else branch');
  writeln('skipped by goto');
  3: writeln('forward goto out of a branch landed')
end;
begin
  n := 0; scan;
  bail(1); bail(2);
  writeln('never');
  9: writeln('outer label')
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 ok.pas >/dev/null 2>&1 && ./ok ) > "$T/ok.ref" 2>&1
[ -s "$T/ok.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no control-arm output"; exit 2; }
ok3=$( cd "$T" && timeout -k 5 20s "$SCRIP" --run ok.pas </dev/null 2>&1 ); m4_run "$T/ok.pas"; ok4="$M4O"
if [ "$ok3" = "$(cat "$T/ok.ref")" ] && [ "$ok4" = "$(cat "$T/ok.ref")" ]; then echo "  control arm: legal local, outward, out-of-branch and non-local gotos run byte-identical to fpc -Miso in both modes"
else echo "  ⛔ control arm FAILED -- the check refuses or miscompiles LEGAL gotos"; echo "      want: $(tr '\n' '|' < "$T/ok.ref")"; echo "      m3  : $(printf '%s' "$ok3" | tr '\n' '|')"; echo "      m4  : $(printf '%s' "$ok4" | tr '\n' '|')"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N illegal gotos refused with a NAMED diagnostic in both modes, and legal gotos are untouched"
else echo "GATE FAIL(1) [$G]: examined $N vendored PAT witnesses plus one legal control"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
