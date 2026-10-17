#!/bin/bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pas_typed_files_read_and_write_components.sh -- row pascal-typed-files-are-not-accepted-packed-file-of-byte-is-a-parse-error
# (coo, 2026-09-12; ISO 7185 6.4.3.5 file-type = 'file' 'of' component-type). 'packed file of byte', 'file of integer' and
# 'file of record' were parse errors (P5's pint.mpp.pas:290). The grammar now takes file-of types (and aliases of them),
# a typed file variable owns a buffer variable f^ (read and assigned), get, put, read(f, x), write(f, x), eof(f), reset
# and rewrite route to Pascal-own runtime helpers (__pas_fbuf_get/_set, __pas_fget/_fput, __pas_fread/_fwrite, __pas_feof_t,
# __pas_treset/_trewrite) that keep one buffer per file handle and store each component in a self-describing binary form
# (integer, real, string/char, and an array or record recursively), so a file SCRIP writes reads back component for
# component -- the P5 pcom/pint pair are both SCRIP-built. Expected lines cut from fpc 3.2.2 -Miso on 2026-09-12; the
# on-disk bytes are not the oracle's (ISO leaves them to the implementation), the read-back values are. Hermetic.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCRIP="${SCRIP:-$S4E/SCRIP/scrip}"
RT_DIR="${RT_DIR:-$(cd "$(dirname "$0")/../../SCRIP/out" && pwd)}"
. "$(dirname "$0")/lib_gate.sh"
gate_require_exec "$SCRIP" "the scrip compiler"
gate_require "$RT_DIR/libscrip_rt.so" "the runtime shared object out/libscrip_rt.so"
W=$(mktemp -d) || exit 2; trap 'rm -rf "$W"' EXIT
cat > "$W/g.pas" <<'PAS'
program typedfile;
type byte = 0..255; bytfil = packed file of byte;
     rec = record k: integer; c: char end;
var fi: file of integer; fb: bytfil; fr: file of rec;
    i, n, s: integer; b: byte; r: rec;
begin
  rewrite(fi); for i := 1 to 5 do write(fi, i * i);
  reset(fi); s := 0; n := 0;
  while not eof(fi) do begin read(fi, i); s := s + i; n := n + 1 end;
  writeln(n, s);
  rewrite(fb); for i := 250 to 255 do begin fb^ := i; put(fb) end;
  reset(fb); n := 0; s := 0;
  while not eof(fb) do begin b := fb^; get(fb); s := s + b; n := n + 1 end;
  writeln(n, s);
  rewrite(fr); r.k := 7; r.c := 'q'; write(fr, r); r.k := 9; r.c := 'z'; write(fr, r);
  reset(fr); read(fr, r); writeln(r.k, ' ', r.c); read(fr, r); writeln(r.k, ' ', r.c);
  if eof(fr) then writeln('eof ok') else writeln('eof bad')
end.
PAS
cat > "$W/want" <<'REF'
          5         55
          6       1515
          7 q
          9 z
eof ok
REF
PASS=0; FAIL=0
m3=$(cd "$W" && timeout -k 5 8s "$SCRIP" --run "$W/g.pas" < /dev/null 2>&1)
if [ "$m3" = "$(cat "$W/want")" ]; then echo "PASS m3"; PASS=$((PASS+1)); else echo "FAIL m3"; diff <(echo "$m3") "$W/want" | head; FAIL=$((FAIL+1)); fi
( cd "$W" && timeout -k 5 8s "$SCRIP" --compile g.pas < /dev/null > g.s 2>/dev/null && gcc -c g.s -o g.o 2>/dev/null && gcc g.o -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o g.bin 2>/dev/null ) || { echo "FAIL m4 (build)"; FAIL=$((FAIL+1)); }
if [ -x "$W/g.bin" ]; then m4=$(cd "$W" && timeout -k 5 8s ./g.bin < /dev/null 2>&1)
  if [ "$m4" = "$(cat "$W/want")" ]; then echo "PASS m4"; PASS=$((PASS+1)); else echo "FAIL m4"; diff <(echo "$m4") "$W/want" | head; FAIL=$((FAIL+1)); fi; fi
echo "pas-typed-files-read-and-write-components: PASS=$PASS FAIL=$FAIL (population: 1 program x 2 modes, 5 expected lines each; file of integer, packed file of byte, file of record)"
if [ $FAIL -eq 0 ] && [ $PASS -eq 2 ]; then echo "GATE PASS(0) [pas_typed_files_read_and_write_components]: 2/2 modes"; exit 0; else echo "GATE RED [pas_typed_files_read_and_write_components]: $FAIL red of 2"; exit 1; fi
