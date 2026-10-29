#!/usr/bin/env bash
# test_gate_pas_readln_and_writeln_require_a_textfile.sh -- ISO 7185 6.9.2 / 6.9.4, refused at compile time
#
# MEASURED 2026-09-16 by hq_pascal on SCRIP e23184b28, both modes, working row pascal-pat-suite-427-to-100-percent-by-class.
# PAT 1842 was ACCEPTED SILENTLY, rc=0 with no output: `readln(f, i)` where f is `file of integer`. ISO 7185 6.9.2 requires
# readln's file parameter to be a textfile, and 6.9.4 requires the same of writeln. read and write have NO such rule --
# `read(f, x)` on a file of integer is perfectly legal -- so the check must discriminate between the two pairs.
#
# THE CURE: the parser already routes a TYPED file variable (the tfilevar registry) through its own dispatch for get, put,
# eof, reset, rewrite, read and write. readln and writeln were simply absent from that dispatch, so they fell through to
# the TEXT read path, which does not recognise a typed file as a stream at all -- it treated the file variable itself as
# the first item to read into and assigned a number to it. Adding the two names to the dispatch as a refusal both closes
# the ISO gap and removes that silent miscompilation. Decided in the parser; no generated code changes.
#
# ⛔ NOT INCLUDED, NAMED RATHER THAN QUIETLY SCOPED OUT: `page(f)` on a non-text file is the same rule at ISO 7185 6.9.5.
# No PAT witness exercises it, so it is not cured here and this gate does not claim it.
#
# ARMS: the one vendored PAT witness, required to be REFUSED with a non-empty diagnostic in BOTH modes -- the suite's own
# criterion. A second arm proves the cure DISCRIMINATES rather than refusing every file: a program that reads and writes a
# `file of integer` with read/write AND uses read/readln/writeln on a real `text` still compiles and runs, byte-identical
# to fpc -Miso. A third arm checks writeln is refused on a typed file too, which no PAT witness covers.
# FAIL_ONCE=1 flips the witness's expectation to prove the arm can fail.
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
b=iso7185prt1842; f="$SRC/$b.pas"
[ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing vendored witness $f"; exit 2; }
N=$((N+1)); bad=""
o3=$( cd "$T" && timeout -k 5 10s "$SCRIP" "$f" </dev/null 2>&1 ); rc3=$?
[ -n "${FAIL_ONCE:-}" ] && { rc3=0; o3=""; }
{ [ "$rc3" -ne 0 ] && [ "$rc3" -lt 124 ] && [ -n "$o3" ]; } || bad="m3 (rc=$rc3, ${#o3} bytes of diagnostic)"
o4=$( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out=/dev/null "$f" </dev/null 2>&1 ); rc4=$?
{ [ "$rc4" -ne 0 ] && [ "$rc4" -lt 124 ] && [ -n "$o4" ]; } || bad="$bad m4 (rc=$rc4, ${#o4} bytes of diagnostic)"
if [ -n "$bad" ]; then echo "  $b ACCEPTED where ISO 7185 6.9.2 requires refusal: $bad"; RC=1; else echo "  $b refused with a diagnostic in both modes"; fi
cat > "$T/wl.pas" <<'PAS'
program wlbad(output);
var f: file of integer;
begin
   rewrite(f); writeln(f, 1)
end.
PAS
N=$((N+1))
w3=$( cd "$T" && timeout -k 5 10s "$SCRIP" wl.pas </dev/null 2>&1 ); wrc3=$?
w4=$( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out=/dev/null wl.pas </dev/null 2>&1 ); wrc4=$?
if { [ "$wrc3" -ne 0 ] && [ -n "$w3" ]; } && { [ "$wrc4" -ne 0 ] && [ -n "$w4" ]; }
then echo "  writeln on a file of integer refused with a diagnostic in both modes (ISO 7185 6.9.4, no PAT witness)"
else echo "  writeln on a file of integer ACCEPTED: m3 rc=$wrc3 (${#w3}b), m4 rc=$wrc4 (${#w4}b)"; RC=1; fi
cat > "$T/ok.pas" <<'PAS'
program textok(output);
var f: file of integer;
    t: text;
    x: integer; s: char;
begin
   rewrite(f); write(f, 11); write(f, 22); reset(f);
   read(f, x); writeln('typed read: ', x:1);
   read(f, x); writeln('typed read: ', x:1);
   rewrite(t); writeln(t, 'zq'); reset(t);
   read(t, s); writeln('text read: ', s);
   readln(t);
   writeln('done')
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 ok.pas >/dev/null 2>&1 && ./ok ) > "$T/ok.ref" 2>&1
[ -s "$T/ok.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no control-arm output"; exit 2; }
ok3=$( cd "$T" && timeout -k 5 20s "$SCRIP" --run ok.pas </dev/null 2>&1 )
if [ "$ok3" = "$(cat "$T/ok.ref")" ]; then echo "  control arm: read/write on a typed file and read/readln/writeln on a text all still run, byte-identical to fpc -Miso"
else echo "  ⛔ control arm FAILED -- the cure refuses or miscompiles a LEGAL file operation"; echo "      want: $(cat "$T/ok.ref")"; echo "      got : $ok3"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N textfile-only violations refused with a diagnostic in both modes, and read/write on a typed file is untouched"
else echo "GATE FAIL(1) [$G]: examined $N refusal witnesses plus one legal control"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
