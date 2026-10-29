#!/usr/bin/env bash
# test_gate_icn_write_is_byte_exact_through_an_embedded_nul.sh -- write() AND writes() EMIT EVERY BYTE OF A
# STRING, INCLUDING THE BYTES AFTER AN EMBEDDED NUL (cfo 2026-09-12, found by the shootout mandelbrot kernel).
#
# THE DEFECT, MEASURED: `s := "a" || char(0) || "b" || char(0) || "c"; writes(s)` printed ONE byte under us and
# five under iconx, in both modes, while `*s` said 5 and image(s) said "a\x00b\x00c" -- the string was intact
# and only the stdout writer was NUL-terminated (VARVAL + fputs). The file-destination branch of the same
# builtin had been length-aware since 7fbb787eb (iobig); stdout and stderr were not. A P4 PBM (mandelbrot at
# w=64) lost 190 of its 512 pixel bytes to it and the diff looked like a wrong computation.
#
# THE REF IS CUT FROM THE ORACLE AT RUN TIME, never pinned by hand, and compared with cmp (byte compare) --
# a `$(...)` capture eats NUL bytes and trailing newlines and would grade this very class wrong (CFO-52 trap 2).
# ⭐ SELF-TEST SEAM: GATE_FAIL_ONCE=1 truncates our m3 stream at its first NUL so the gate is seen to say no.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
GATE="$(basename "${BASH_SOURCE[0]}" .sh)"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ REFUSE(2) [$GATE]: lib_oracle_flags.sh unloadable"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2) [$GATE]: no scrip at $SCRIP"; exit 2; }
ICONT="$(icont_bin)" || exit 2
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/w.icn" <<'ICN'
procedure main();
   local s, f;
   s := "a" || char(0) || "b" || char(0) || "c";
   write("len=", *s);
   writes(s); write();
   write(s);
   writes(&output, s); write();
   write(&output, s, "|", s);
   write(&errout, s);
   f := open("w.out", "w") | stop("cannot open w.out");
   write(f, s); writes(f, s); close(f);
   f := open("w.out") | stop("cannot reopen w.out");
   write(image(reads(f, 100)));
   write(image(s));
end
ICN
( cd "$T" && "$ICONT" -s -o w.oracle w.icn ) >/dev/null 2>&1 || { echo "⛔ REFUSE(2) [$GATE]: icont did not compile the witness"; exit 2; }
( cd "$T" && ./w.oracle >w.ref 2>w.ref.err ) || { echo "⛔ REFUSE(2) [$GATE]: the oracle itself did not run the witness"; exit 2; }
NULS=$(tr -cd '\000' < "$T/w.ref" | wc -c); [ "$NULS" -eq 10 ] || { echo "⛔ REFUSE(2) [$GATE]: the oracle stream carries $NULS NUL bytes, not the 10 the witness writes (five copies of a two-NUL string) -- the oracle moved or the witness is wrong"; exit 2; }
RC=0
for M in m3 m4; do
  rm -f "$T/w.out"
  if [ "$M" = m3 ]; then ( cd "$T" && timeout -k 5 20 "$SCRIP" w.icn </dev/null >"$T/$M.out" 2>"$T/$M.err" )
  else ( cd "$T" && timeout -k 5 30 "$SCRIP" --compile --out=w.s w.icn </dev/null >/dev/null 2>&1 && gcc -no-pie w.s -o w.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" ) >/dev/null 2>&1 || { echo "  m4 RED: the witness would not compile or link"; RC=1; continue; }
       ( cd "$T" && timeout -k 5 20 ./w.bin </dev/null >"$T/$M.out" 2>"$T/$M.err" )
  fi
  if [ -n "${GATE_FAIL_ONCE:-}" ]; then head -c 7 "$T/$M.out" > "$T/$M.cut"; mv "$T/$M.cut" "$T/$M.out"; fi
  if cmp -s "$T/w.ref" "$T/$M.out" && cmp -s "$T/w.ref.err" "$T/$M.err"; then echo "  $M PASS (stdout and stderr byte-identical to iconx, $(wc -c < "$T/$M.out")+$(wc -c < "$T/$M.err") bytes)"
  else echo "  $M FAIL: stdout $(wc -c < "$T/$M.out") bytes vs oracle $(wc -c < "$T/w.ref"); stderr $(wc -c < "$T/$M.err") vs $(wc -c < "$T/w.ref.err"); $(cmp "$T/w.ref" "$T/$M.out" 2>&1 | head -1)"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$GATE]: write and writes carry every byte through an embedded NUL on stdout, stderr and a file, in both modes"; exit 0; fi
echo "GATE FAIL [$GATE]: a string with an embedded NUL is truncated on its way out"; exit 1
