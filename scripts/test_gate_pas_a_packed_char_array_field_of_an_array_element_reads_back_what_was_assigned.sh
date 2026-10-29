#!/usr/bin/env bash
# test_gate_pas_a_packed_char_array_field_of_an_array_element_reads_back_what_was_assigned.sh -- a field of type packed array [1..n] of char of a
# record that is an ELEMENT OF AN ARRAY is assigned a string and reads back the same string: d[i].name := 'abc...'; writeln(d[i].name).
# MEASURED 2026-10-09 by hq_pascal on the Star Trek demo (CEO-1579): its Damage Control Report printed the eight device names blank, every
# number right. Minimised: a single record variable r.name round-trips; d[2].name does not (writeln prints nothing).
# CAUSE: the selector action marks a char-array FIELD (pas_cafield_mark_add, which makes the assignment pack the string and the read unpack it) on the
# single-record path only; the array-of-records path (pas_arrrec_flatten) marked only a char-valued field. CURE (lower_pascal_tree.c, the selector
# action): the flattened element node is marked a char-array field when the array's record type says so.
# ARMS, both modes, expected stdout and exit code cut LIVE from fpc -Miso: (1) intindex -- constant and variable integer subscripts; (2) charindex --
# an array indexed by a char subrange and a for loop over it, the Star Trek device table; (3) deviceshape -- the exact record of the witness. FAIL_ONCE=1
# corrupts arm 3's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile or link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/intindex.pas" <<'PAS'
program intindex(output);
type devicerec = record name: packed array [1..8] of char; downtime: integer end;
var d: array [0..3] of devicerec; r: devicerec; i: integer;
begin
  r.name := 'Warp Eng'; r.downtime := 1;
  writeln(r.name, r.downtime:3);
  d[2].name := 'Phaser C'; d[2].downtime := 2;
  writeln(d[2].name, d[2].downtime:3);
  i := 2;
  writeln(d[i].name, d[i].downtime:3);
  d[i].name := 'Photon T';
  writeln(d[i].name)
end.
PAS
cat > "$T/charindex.pas" <<'PAS'
program charindex(output);
type devicerec = record name: packed array [1..8] of char; downtime: integer end;
var d: array ['0'..'3'] of devicerec; c: char;
begin
  d['2'].name := 'Phaser C'; d['2'].downtime := 2;
  writeln(d['2'].name, d['2'].downtime:3);
  c := '2';
  writeln(d[c].name, d[c].downtime:3);
  for c := '0' to '3' do d[c].name := 'abcdefgh';
  c := '3'; writeln(d[c].name)
end.
PAS
cat > "$T/deviceshape.pas" <<'PAS'
program deviceshape(output);
const mindevice = '0'; maxdevice = '7';
type devicerec = record name: packed array [1..20] of char; downtime: integer end;
var device: array [mindevice..maxdevice] of devicerec; ch: char;
begin
  for ch := mindevice to maxdevice do device[ch].downtime := ord(ch) - ord('0');
  device['3'].name := 'Phaser Control      ';
  for ch := mindevice to maxdevice do
    if device[ch].downtime <> 0 then device[ch].downtime := device[ch].downtime - 1;
  ch := '3';
  writeln(device[ch].name, device[ch].downtime:5);
  device[ch].downtime := 9;
  writeln(device[ch].downtime)
end.
PAS
for p in intindex charindex deviceshape; do
  frc=$(fpcrun $p)
  if [ "$p" = deviceshape ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a packed char array field of an array element reads back what was assigned, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 3 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
