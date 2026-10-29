#!/usr/bin/env bash
# test_gate_icn_writes_to_errout_flushes_output_first.sh -- WRITING TO &errout FLUSHES &output FIRST, IN BOTH MODES, AS ICONX DOES
# (hq_icon 2026-09-26, crawl work under CEO-1270: IPL openchk and press, the AD class).
#
# iconx flushes &output before anything reaches &errout, so a program's merged stdout+stderr reads in program order. The
# write builtin flushed stdout before a file argument only for write (the nl case), never for writes; a mode-4 binary, whose
# stdout is fully buffered into a file, therefore printed writes(&errout, ...) ahead of every earlier stdout line
# (openchk: "Open of ..." ahead of "close again", then " failed." after it). The rungs discards stderr, so this is graded
# here: the witness runs under icont/iconx, m3 and m4 with stdout and stderr merged into one file, and all three must agree.
# On by_name_dispatch.c before the cure the m4 file differs (red).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G=test_gate_icn_writes_to_errout_flushes_output_first
S="$HERE/../../SCRIP/scrip"; O="$HERE/../../SCRIP/out"
[ -x "$S" ] || { echo "⛔ GATE REFUSE(2) [$G]: scrip not built"; exit 2; }
IC=/home/resources/icon-master/bin/icont
[ -x "$IC" ] || { echo "⛔ GATE REFUSE(2) [$G]: icont not found at $IC -- the oracle is required"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/errflush_gate.XXXXXX")" || { echo "⛔ GATE REFUSE(2) [$G]: mktemp failed"; exit 2; }
trap 'rm -rf "$T"' EXIT
cat > "$T/w.icn" <<'ICN'
procedure main()
   write("line one");
   writes(&errout, "err part A ");
   write("line two");
   write(&errout, "err part B");
   writes("line three ");
   writes(&errout, "err part C");
   write(" end");
end
ICN
( cd "$T" && "$IC" -s -o w.ox w.icn >/dev/null 2>&1 && ./w.ox > oracle.txt 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: icont/iconx did not run the witness"; exit 2; }
"$S" "$T/w.icn" > "$T/m3.txt" 2>&1 < /dev/null || { echo "⛔ GATE REFUSE(2) [$G]: m3 did not run"; exit 2; }
"$S" --compile --out="$T/w.s" "$T/w.icn" < /dev/null >/dev/null 2>&1 && gcc -no-pie -o "$T/w.x" "$T/w.s" -Wl,-rpath,"$O" -L"$O" -lscrip_rt -lm -lpthread 2>/dev/null \
    || { echo "⛔ GATE REFUSE(2) [$G]: m4 did not build"; exit 2; }
"$T/w.x" > "$T/m4.txt" 2>&1 < /dev/null || { echo "⛔ GATE REFUSE(2) [$G]: m4 did not run"; exit 2; }
red=0
cmp -s "$T/oracle.txt" "$T/m3.txt" || { echo "  m3 merged output differs from iconx:"; diff "$T/oracle.txt" "$T/m3.txt" | head -6; red=1; }
cmp -s "$T/oracle.txt" "$T/m4.txt" || { echo "  m4 merged output differs from iconx:"; diff "$T/oracle.txt" "$T/m4.txt" | head -6; red=1; }
# ⭐ AND stop(), WHICH WRITES ITS MESSAGE TO &errout AND ENDS THE PROGRAM (hq_icon 2026-09-27, IPL ttt and hr): it wrote the message
# first and flushed &output after, so a pending prompt landed after "Game Over." in m3 and every buffered stdout line after it in m4.
cat > "$T/s.icn" <<'ICN'
procedure main()
   writes("prompt :");
   write("line");
   writes("tail:");
   stop("Game Over.");
end
ICN
( cd "$T" && "$IC" -s -o s.ox s.icn >/dev/null 2>&1 && ./s.ox > soracle.txt 2>&1 ); [ -s "$T/soracle.txt" ] || { echo "⛔ GATE REFUSE(2) [$G]: icont/iconx did not run the stop witness"; exit 2; }
"$S" "$T/s.icn" > "$T/s3.txt" 2>&1 < /dev/null
"$S" --compile --out="$T/s.s" "$T/s.icn" < /dev/null >/dev/null 2>&1 && gcc -no-pie -o "$T/s.x" "$T/s.s" -Wl,-rpath,"$O" -L"$O" -lscrip_rt -lm -lpthread 2>/dev/null \
    || { echo "⛔ GATE REFUSE(2) [$G]: m4 did not build the stop witness"; exit 2; }
"$T/s.x" > "$T/s4.txt" 2>&1 < /dev/null
cmp -s "$T/soracle.txt" "$T/s3.txt" || { echo "  stop: m3 merged output differs from iconx:"; diff "$T/soracle.txt" "$T/s3.txt" | head -6; red=1; }
cmp -s "$T/soracle.txt" "$T/s4.txt" || { echo "  stop: m4 merged output differs from iconx:"; diff "$T/soracle.txt" "$T/s4.txt" | head -6; red=1; }
[ "$red" -eq 0 ] && { echo "✅ GATE PASS [$G]: writes, write and stop to &errout keep program order with &output in m3 and m4, as iconx"; exit 0; }
echo "⛔ GATE FAIL [$G]: &output was not flushed before &errout"; exit 1
