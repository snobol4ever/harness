#!/usr/bin/env bash
# test_gate_pas_eoln_needs_a_defined_file_not_at_its_end.sh -- ISO 7185 6.6.6.5: when eoln(f) is activated it is an error if f is
# undefined or if eof(f) is true
#
# MEASURED 2026-09-26 by hq_pascal, both modes, row pascal-every-suite-to-100-under-nonet-ceo-1266. The eoln arms in by_name_dispatch.c
# answered both errors quietly: eoln of a never-opened text file fell through to reading STDIN (PAT iso7185prt1741 ran to rc 0), and eoln
# at end-of-file answered true (PAT 1866). NO BRACKET: an absent error sends no event. The cure: __pas_eoln_f stops with 6.6.6.5 when its
# file is no open stream or is at its end, and __pas_eoln (input) stops at end-of-file. fpc -Miso faults on the undefined file (its runtime
# error 103) and answers the two end-of-file cases quietly (ISO 3.2 lets a processor leave an error undetected), so each fault arm expects
# fpc's stdout up to the fault -- as fpc prints it where fpc faults, with its 'after' line cut where it does not.
#
# ARMS, both modes: three faults -- eoln of an undefined file, eoln of a file at its end, eoln(input) at end-of-file -- each print fpc's
# stdout up to the fault, exit 1 and name 6.6.6.5; and a control cut LIVE from fpc -Miso (a file and stdin walked line by line with eof,
# eoln and readln) runs byte-identical. It FAILS on the parent (the faults run to rc 0). FAIL_ONCE=1 corrupts the control's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" <"$T/in" >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile or link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" <"$T/in" >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc <"$T/in" >"$T/$1.want" 2>/dev/null ); echo $?; }
printf 'line one\n' > "$T/in"
printf 'program eu(output);\nvar f: text; b: boolean;\nbegin\n  writeln(%s); b := eoln(f); writeln(%s, b)\nend.\n' "'before'" "'after '" > "$T/eu.pas"
printf 'program ee(output);\nvar f: text; b: boolean;\nbegin\n  rewrite(f); writeln(f, %s); reset(f); readln(f); writeln(%s); b := eoln(f); writeln(%s, b)\nend.\n' "'x'" "'before'" "'after '" > "$T/ee.pas"
printf 'program ei(input, output);\nvar b: boolean;\nbegin\n  readln; writeln(%s); b := eoln; writeln(%s, b)\nend.\n' "'before'" "'after '" > "$T/ei.pas"
for p in eu ee ei; do
  frc=$(fpcrun $p); { [ "$frc" != 0 ] || grep -q '^after' "$T/$p.want"; } || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso ran arm $p to rc 0 without its after line -- re-cut it"; exit 2; }
  grep -v '^after' "$T/$p.want" > "$T/$p.cut"
  for m in m3 m4; do run $m $p; rc=$?
    if [ "$rc" = 1 ] && cmp -s "$T/$p.cut" "$T/o" && grep -q 'ISO 7185 6\.6\.6\.5' "$T/e"; then echo "  fault $p $m: rc=1, stdout = fpc up to the fault, stderr names 6.6.6.5"
    else echo "  ⛔ fault $p $m FAILED: rc=$rc"; echo "      want: $(tr '\n' '|' < "$T/$p.cut")"; echo "      got : $(tr '\n' '|' < "$T/o")"; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
printf 'ab\n\ncd e\n' > "$T/in"
cat > "$T/ctl.pas" <<'PAS'
program ctl(input, output);
var f: text; c: char; n, k: integer;
begin
  rewrite(f); writeln(f, 'one'); writeln(f); writeln(f, 'two three'); reset(f);
  n := 0;
  while not eof(f) do begin k := 0; while not eoln(f) do begin read(f, c); k := k + 1 end; readln(f); n := n + 1; writeln('file line ', n, ' has ', k) end;
  n := 0;
  while not eof do begin k := 0; while not eoln do begin read(c); k := k + 1 end; readln; n := n + 1; writeln('input line ', n, ' has ', k) end
end.
PAS
frc=$(fpcrun ctl); [ "$frc" = 0 ] || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso ran the control to rc $frc"; exit 2; }
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/ctl.want"; fi
for m in m3 m4; do run $m ctl; rc=$?
  if [ "$rc" = 0 ] && cmp -s "$T/ctl.want" "$T/o"; then echo "  control $m: byte-identical to fpc -Miso"
  else echo "  ⛔ control $m FAILED: rc=$rc"; echo "      want: $(tr '\n' '|' < "$T/ctl.want")"; echo "      got : $(tr '\n' '|' < "$T/o")"; RC=1; fi; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: eoln of an undefined file or at end-of-file stops with 6.6.6.5 (3 of 3), and line walks run, both modes"
else echo "GATE FAIL(1) [$G]: examined 3 fault arms and 1 control in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
