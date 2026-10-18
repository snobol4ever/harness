#!/usr/bin/env bash
# test_gate_pas_a_file_component_is_never_itself_a_file.sh -- ISO 7185 6.4.3.5, refused at compile time
#
# MEASURED 2026-09-16 by hq_pascal on SCRIP 2f2b84d38, both modes, working row pascal-pat-suite-427-to-100-percent-by-class.
# TWO PAT rejection tests were ACCEPTED SILENTLY, rc=0 with no output: a file whose component-type is itself a file
# (1826, `file of file of integer`) and a file whose component-type is a record carrying a text field (1827). ISO 7185
# 6.4.3.5 forbids both -- the component-type of a file-type shall be neither a file-type nor a structured-type having a
# file-type as a component, at any depth.
#
# THE CURE, and why it costs nothing at run time: the Pascal record-type table recorded a per-field char flag but nothing
# about a field being a FILE, so `file of r` could not ask whether r carried one. The table now carries `fldfile`,
# staged in pas_pend_add exactly as fldchar is, set when the field's own type is a typed file, is `text`, or is a record
# the table already knows carries a file -- so the flag is transitive by construction rather than by a walk. The file-type
# production consults it, plus its own pending state for an INLINE component record. Every witness is decided in the
# parser; no generated code changes and no runtime check is added.
#
# ⛔ KNOWN LIMIT, NAMED RATHER THAN HIDDEN: a component reached only through an ARRAY OF a record that carries a file is
# caught (the array's element type name is the pending typename), but a component reached through a POINTER is not, and
# ISO 7185 does not require it to be -- a pointer to a file-bearing record is not itself a structured-type having a file
# as a component. No PAT witness exercises a deeper shape than these two.
#
# ARMS: the two vendored PAT witnesses, each required to be REFUSED with a non-empty diagnostic in BOTH modes -- the
# suite's own criterion. A third arm proves the cure DISCRIMINATES rather than refusing every file: a program declaring
# `file of integer`, `file of <a plain record>` and `text` side by side still compiles and runs, byte-identical to
# fpc -Miso. FAIL_ONCE=1 flips the first witness's expectation to prove the arm can fail.
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
for b in iso7185prt1826 iso7185prt1827; do
  f="$SRC/$b.pas"; [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing vendored witness $f"; exit 2; }
  N=$((N+1)); bad=""
  o3=$( cd "$T" && timeout -k 5 10s "$SCRIP" "$f" </dev/null 2>&1 ); rc3=$?
  if [ -n "${FAIL_ONCE:-}" ] && [ "$b" = iso7185prt1826 ]; then rc3=0; o3=""; fi
  { [ "$rc3" -ne 0 ] && [ "$rc3" -lt 124 ] && [ -n "$o3" ]; } || bad="m3 (rc=$rc3, ${#o3} bytes of diagnostic)"
  o4=$( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o /dev/null "$f" </dev/null 2>&1 ); rc4=$?
  { [ "$rc4" -ne 0 ] && [ "$rc4" -lt 124 ] && [ -n "$o4" ]; } || bad="$bad m4 (rc=$rc4, ${#o4} bytes of diagnostic)"
  if [ -n "$bad" ]; then echo "  $b ACCEPTED where ISO 7185 6.4.3.5 requires refusal: $bad"; RC=1; else echo "  $b refused with a diagnostic in both modes"; fi
done
cat > "$T/ok.pas" <<'PAS'
program fileok(output);
type r = record i: integer; c: char end;
var f: file of integer;
    g: file of r;
    t: text;
    x: integer; v: r;
begin
   rewrite(f); write(f, 42); reset(f); read(f, x); writeln('int file: ', x:1);
   v.i := 7; v.c := 'q';
   rewrite(g); write(g, v); reset(g); read(g, v); writeln('rec file: ', v.i:1, ' ', v.c);
   rewrite(t); writeln(t, 'hello'); reset(t);
   writeln('done')
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 ok.pas >/dev/null 2>&1 && ./ok ) > "$T/ok.ref" 2>&1
[ -s "$T/ok.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no control-arm output"; exit 2; }
ok3=$( cd "$T" && timeout -k 5 20s "$SCRIP" --run ok.pas </dev/null 2>&1 )
if [ "$ok3" = "$(cat "$T/ok.ref")" ]; then echo "  control arm: a file of integer, a file of a plain record and a text all still run, byte-identical to fpc -Miso"
else echo "  ⛔ control arm FAILED -- the cure refuses or miscompiles a LEGAL file declaration"; echo "      want: $(cat "$T/ok.ref")"; echo "      got : $ok3"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N file-of-file violations refused with a diagnostic in both modes, and every legal file type is untouched"
else echo "GATE FAIL(1) [$G]: examined $N vendored PAT witnesses plus one legal control"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
