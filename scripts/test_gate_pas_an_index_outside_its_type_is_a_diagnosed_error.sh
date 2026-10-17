#!/usr/bin/env bash
# test_gate_pas_an_index_outside_its_type_is_a_diagnosed_error.sh -- an array index outside the index-type stops the program WITH A DIAGNOSTIC
#
# MEASURED 2026-09-25 by hq_pascal on SCRIP f65f143e2f-runtime tree, both modes, row pascal-every-suite-to-100-under-nonet-ceo-1266. PAT
# iso7185prt1701 and iso7185prt1828 read "rejected-silently-no-diagnostic": a[11] on array [1..10] exited rc=1 and printed NOTHING, in
# both modes. arr_get / arr_set_pure answer FAILDESCR for an index outside the block, the failure ran up every statement's omega to the
# program's own, and main's omega is the shared emitter's bare exit(1) -- so ISO 7185 6.5.3.2's error was detected and never reported.
# The cure is Pascal's own lowerer: the failure port of every array read and write it emits is wired to __pas_rterr("6.5.3.2", ...),
# which prints the clause and exits 1 through pas_file_err. The success path is unchanged, so an in-range access costs nothing new.
#
# ARMS: five out-of-range shapes (1-based read after output, 0-based, char-indexed, an array of records, an array of boolean). Each
# must, in BOTH modes (m4 compiles, links and runs): print exactly the stdout fpc -Miso -Cr prints before its own range fault, exit
# non-zero, and name ISO 7185 6.5.3.2 on stderr. One in-range CONTROL arm must be byte-identical to fpc -Miso in both modes.
# It FAILS on the parent tree (every out-of-range arm: rc=1, empty stderr). FAIL_ONCE=1 corrupts the control's ref to prove it can fail.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
run_mode() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/$p.$m.out" 2>"$T/$p.$m.err" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: arm $p did not compile in m4"; exit 2; }
  ( cd "$T" && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: arm $p compiled but would not link"; exit 2; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/$p.$m.out" 2>"$T/$p.$m.err" ); return $?; }
cat > "$T/read1.pas" <<'PAS'
program read1(output);
var a: array [1..10] of integer; i: integer;
begin for i := 1 to 10 do a[i] := i; writeln('before'); i := 11; writeln(a[i]); writeln('after') end.
PAS
cat > "$T/zero.pas" <<'PAS'
program zero(output);
var a: array [0..9] of integer; i: integer;
begin writeln('z'); i := 10; a[i] := 1; writeln('after') end.
PAS
cat > "$T/chr.pas" <<'PAS'
program chr(output);
var a: array ['a'..'c'] of integer; c: char;
begin a['b'] := 2; writeln(a['b']:1); c := 'd'; a[c] := 1; writeln('after') end.
PAS
cat > "$T/rec.pas" <<'PAS'
program rec(output);
type r = record x, y: integer end;
var a: array [1..3] of r; i: integer;
begin a[3].x := 5; writeln(a[3].x:1); i := 4; a[i].x := 1; writeln('after') end.
PAS
cat > "$T/bool.pas" <<'PAS'
program bool(output);
var a: array [1..3] of boolean; i: integer;
begin a[1] := true; writeln(ord(a[1]):1); i := 4; a[i] := true; writeln('after') end.
PAS
cat > "$T/ctl.pas" <<'PAS'
program ctl(output);
type r = record x, y: integer end;
var a: array [1..10] of integer; z: array [0..9] of integer; c: array ['a'..'c'] of integer;
    q: array [1..3] of r; b: array [1..3] of boolean; i: integer; ch: char;
begin
  for i := 1 to 10 do a[i] := i * i; for i := 0 to 9 do z[i] := a[i + 1] - i; for ch := 'a' to 'c' do c[ch] := ord(ch);
  for i := 1 to 3 do begin q[i].x := i; q[i].y := -i; b[i] := odd(i) end;
  for i := 1 to 10 do write(a[i]:4); writeln; for i := 0 to 9 do write(z[i]:4); writeln;
  writeln(c['a']:4, c['c']:4, q[2].x:4, q[3].y:4, ord(b[1]):2, ord(b[2]):2)
end.
PAS
for p in read1 zero chr rec bool; do
  N=$((N+1))
  ( cd "$T" && "$FPC" -Miso -Cr -v0 -o"$p.fpc" $p.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso -Cr would not compile arm $p"; exit 2; }
  ( cd "$T" && timeout -k 5 20s "./$p.fpc" </dev/null >"$T/$p.want" 2>/dev/null ); frc=$?
  [ "$frc" -ne 0 ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle ran arm $p to rc=0 -- the arm does not carry the range fault it claims"; exit 2; }
  for m in m3 m4; do
    run_mode $m $p; rc=$?
    if [ "$rc" -ne 0 ] && [ "$rc" -lt 124 ] && cmp -s "$T/$p.want" "$T/$p.$m.out" && grep -q 'ISO 7185 6\.5\.3\.2' "$T/$p.$m.err"; then
         echo "  arm $p $m: rc=$rc, stdout = fpc -Miso -Cr before its fault, stderr names 6.5.3.2"
    else echo "  ⛔ arm $p $m FAILED: rc=$rc (oracle rc=$frc)"; echo "      want out: $(tr '\n' '|' < "$T/$p.want")"; echo "      got  out: $(tr '\n' '|' < "$T/$p.$m.out")"
         echo "      got  err: $(tr '\n' '|' < "$T/$p.$m.err" | cut -c1-160)"; RC=1; fi
  done
done
N=$((N+1))
( cd "$T" && "$FPC" -Miso -v0 -o"ctl.fpc" ctl.pas >/dev/null 2>&1 && ./ctl.fpc ) > "$T/ctl.want" 2>&1
[ -s "$T/ctl.want" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no output for the control arm"; exit 2; }
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/ctl.want"; fi
for m in m3 m4; do
  run_mode $m ctl; rc=$?
  if [ "$rc" = 0 ] && cmp -s "$T/ctl.want" "$T/ctl.$m.out"; then echo "  arm ctl $m: in-range control byte-identical to fpc -Miso"
  else echo "  ⛔ arm ctl $m FAILED: rc=$rc"; echo "      want: $(tr '\n' '|' < "$T/ctl.want")"; echo "      got : $(tr '\n' '|' < "$T/ctl.$m.out")"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $((N-1)) out-of-range shapes stop with an ISO 7185 6.5.3.2 diagnostic and the in-range control matches fpc -Miso, both modes"
else echo "GATE FAIL(1) [$G]: examined $N oracle-cut arms"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
