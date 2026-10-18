#!/usr/bin/env bash
# test_gate_pas_an_unassigned_header_file_binds_to_stdio_only_under_iso_mode.sh -- an extra (non-input/output) program-parameter
# text file that is never assign()'d binds to real stdout on rewrite / stdin on reset, exactly as fpc -Miso does, ISO 7185 6.10
# being implementation-defined on this point (row pascal-every-suite-to-100-under-nonet-ceo-1266, landing 2026-10-01).
#
# MEASURED 2026-10-01 by hq_pascal, both modes. test_tisobuf2.pas ({$mode iso}, program test(input,output,testfile)) rewrites
# testfile unassigned, writes 'Hello world', closes, assigns it to a DIFFERENT name ('TESTFILE.txt') that was never created, and
# resets -- fpc -Miso prints 'Hello world' to real stdout then halts with Runtime error 2 (rc=2, file not found) on the reset.
# Parent SCRIP instead bound the unassigned rewrite to a DISK FILE LITERALLY NAMED AFTER THE IDENTIFIER ('testfile' in cwd),
# so 'Hello world' never reached stdout (rc=1 silent, from a FAILDESCR dead end on reset, no diagnostic).
#
# ⛔⭐ THE WHOLE RULE, RULED ON THE ORACLE (ceo CEO-1621, 2026-10-10; it supersedes this gate's 2026-10-01 arm (b), which guarded a
# classic Pascal-P4 disk-file default that fpc never had). The ceo measured fpc 3.2.2 -Miso: the program-heading files beyond input
# and output bind to the command-line arguments IN HEADING ORDER -- the k-th to ParamStr(k) -- and to the console when that argument
# is absent. CEO-1589 (5e9926af2) built the console half for a program with no {$mode} too, since such a program is in ISO mode,
# and this landing builds the argument half. The lowerer passes 2k+console to __pas_rewrite/__pas_reset, so the old 0/1 codes keep
# their meaning. pas_main_arg(k) answers ParamStr(k) from the arguments the driver (m3) or the emitted main (m4) staged. The P4 and
# P5 self-host harnesses now name their files as program arguments after the double dash (comp.pas: prr; int.pas, pcom.pas and
# pint.pas: prd prr).
#
# ARMS: (a) hdrstdio -- {$mode iso}, graded live against fpc -Miso: stdout AND exit code, both modes; also asserts no stray disk
# file named after the identifier appears (the old, wrong binding). (b) hdrargs -- no mode directive, heading (input, output, prd,
# prr), graded live against fpc -Miso with NO argument (both to the console), ONE (prd reads the named file, prr to the console) and
# TWO (prr writes the second file, nothing of it on stdout): stdout, exit code and the written file, both modes.
# FAILS on the parent f6177b6e2 in arm (a) (rc=1 not 2, stdout empty not 'Hello world', a stray 'hdrstdio_extra' file on disk).
# FAIL_ONCE=1 corrupts arm (a)'s wanted stdout.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- arm (a)'s expectation is CUT FROM THE ORACLE"; exit 2; }
RC=0; N=0
run() { local m="$1" p="$2" w="$3"
  rm -f "$w"/extra "$w"/hdrstdio_extra.name.that.is.never.created 2>/dev/null
  if [ "$m" = m3 ]; then ( cd "$w" && timeout -k 5 20s env LD_LIBRARY_PATH="$RT_DIR" "$SCRIP" --run "$p.pas" </dev/null >"$w/o" 2>"$w/e" ); return $?; fi
  ( cd "$w" && timeout -k 5 20s "$SCRIP" --compile -o "$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile and link"; return 125; }
  ( cd "$w" && timeout -k 5 20s "./$p.m4" </dev/null >"$w/o" 2>"$w/e" ); return $?; }

# --- arm (a): hdrstdio, {$mode iso}, graded live against fpc -Miso ---
Ta=$(mktemp -d) || exit 2
trap 'rm -rf ${Ta:+"$Ta"} ${Tb:+"$Tb"}' EXIT; trap 'rm -rf ${Ta:+"$Ta"} ${Tb:+"$Tb"}; exit 143' TERM; trap 'rm -rf ${Ta:+"$Ta"} ${Tb:+"$Tb"}; exit 130' INT
cat > "$Ta/hdrstdio.pas" <<'PAS'
{$mode iso}
program hdrstdio(input, output, extra);
var
  extra : text;
begin
  rewrite(extra);
  writeln(extra, 'to stdout');
  close(extra);
  assign(extra, 'hdrstdio_extra.name.that.is.never.created');
  reset(extra);
  writeln('unreachable')
end.
PAS
( cd "$Ta" && "$FPC" -Miso -v0 -ohdrstdio.fpc hdrstdio.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile hdrstdio"; rm -rf "$Ta"; exit 2; }
( cd "$Ta" && timeout -k 5 20s ./hdrstdio.fpc </dev/null >hdrstdio.want 2>/dev/null ); frc=$?
[ -n "${FAIL_ONCE:-}" ] && echo "corrupted by FAIL_ONCE" >> "$Ta/hdrstdio.want"
for m in m3 m4; do
  run "$m" hdrstdio "$Ta"; rc=$?; N=$((N + 1))
  stray=""; [ -e "$Ta/extra" ] && stray="$Ta/extra"
  if [ "$rc" = "$frc" ] && cmp -s "$Ta/hdrstdio.want" "$Ta/o" && [ -z "$stray" ]; then
    echo "  hdrstdio $m: rc=$rc, stdout byte-identical to fpc -Miso, no stray disk file"
  else
    echo "  ⛔ hdrstdio $m FAILED: rc=$rc (fpc $frc) stray=[${stray:-none}]"; diff "$Ta/hdrstdio.want" "$Ta/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$Ta/e" 2>/dev/null | cut -c1-140)"; RC=1
  fi
done
rm -rf "$Ta"

# --- arm (b): hdrargs, no mode directive, the whole rule graded live against fpc -Miso: ParamStr(k) when given, else the console ---
Tb=$(mktemp -d) || exit 2
cat > "$Tb/hdrargs.pas" <<'PAS'
program hdrargs(input, output, prd, prr);
var prd, prr: text; c: char;
begin
  rewrite(prr);
  writeln(prr, 'to prr');
  writeln('to output');
  reset(prd);
  while not eof(prd) do begin read(prd, c); write(c) end;
  writeln('done')
end.
PAS
printf 'line from prd\n' > "$Tb/in.txt"
( cd "$Tb" && "$FPC" -Miso -v0 -ohdrargs.fpc hdrargs.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile hdrargs"; exit 2; }
( cd "$Tb" && timeout -k 5 20s "$SCRIP" --compile -o hdrargs.s hdrargs.pas </dev/null >/dev/null 2>&1 && cc -m64 -no-pie hdrargs.s -o hdrargs.m4 -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ hdrargs m4: did not compile and link"; RC=1; }
for args in "" "in.txt" "in.txt out.txt"; do
  ( cd "$Tb" && rm -f out.txt && printf 'stdin text\n' | timeout -k 5 20s ./hdrargs.fpc $args > want.o 2>/dev/null; echo $? > want.rc; cat out.txt > want.f 2>/dev/null; rm -f out.txt )
  for m in m3 m4; do
    N=$((N + 1))
    if [ "$m" = m3 ]; then ( cd "$Tb" && printf 'stdin text\n' | timeout -k 5 20s "$SCRIP" --run hdrargs.pas -- $args > got.o 2> got.e; echo $? > got.rc )
    else ( cd "$Tb" && printf 'stdin text\n' | timeout -k 5 20s ./hdrargs.m4 $args > got.o 2> got.e; echo $? > got.rc ); fi
    ( cd "$Tb" && cat out.txt > got.f 2>/dev/null; rm -f out.txt )
    if cmp -s "$Tb/want.o" "$Tb/got.o" && cmp -s "$Tb/want.rc" "$Tb/got.rc" && cmp -s "$Tb/want.f" "$Tb/got.f"; then
      echo "  hdrargs $m args=[$args]: stdout, rc and the file prr writes byte-identical to fpc -Miso"
    else
      echo "  ⛔ hdrargs $m args=[$args] FAILED: want [$(tr '\n' '|' < "$Tb/want.o")] rc $(cat "$Tb/want.rc") file [$(tr '\n' '|' < "$Tb/want.f")]; got [$(tr '\n' '|' < "$Tb/got.o")] rc $(cat "$Tb/got.rc") file [$(tr '\n' '|' < "$Tb/got.f")]"; RC=1
    fi
  done
done
rm -rf "$Tb"

if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a heading file binds to its program argument in heading order, else to the console, byte-identical to fpc -Miso, $N arms"
else echo "GATE FAIL(1) [$G]: examined $N program x mode x argument arms"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
