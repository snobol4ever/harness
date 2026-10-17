#!/usr/bin/env bash
# test_gate_pas_a_pack_records_directive_sets_the_field_alignment_of_the_records_after_it.sh -- {$PackRecords n} caps the
# alignment of every field of the records declared after it at n bytes, {$Push}/{$Pop} save and restore that setting beside
# {$MinEnumSize} and {$PackSet}, and SizeOf of the record answers as fpc does.
#
# MEASURED 2026-10-03 by hq_pascal, row pascal-every-suite-to-100-under-nonet-ceo-1266. FPC test_tpushpop2 halted rc=2:
# SizeOf of a record declared under {$PackRecords 1} equalled SizeOf of one declared inside {$Push}{$PackRecords 4}{$Pop},
# because the lexer skipped {$PackRecords} as an unknown directive and every record laid out at natural alignment.
#
# CURE (Lon granted the new global in-chat 2026-10-03): pascal.l keeps g_pas_pack_records (0 = natural alignment; set by
# {$PackRecords n}, C/NORMAL/DEFAULT read as 0), saved and restored by {$Push}/{$Pop} on the stack that already carries the
# enum and set sizes; pas_rectype_add snapshots it into the record's pack_n and the layout caps each field's alignment at it.
# A `packed` record is still 1 and the Mac68k alignment is unchanged.
#
# ARMS, both modes, expectations cut LIVE from fpc: (one) 1/2/4/8 on the same field mix; (pushpop) the test_tpushpop2 shape plus
# a nested Push inside a Push and a record after the Pop that has returned to the outer setting; (default) {$PackRecords C}
# and DEFAULT return to natural alignment. FAIL_ONCE=1 corrupts the pushpop arm's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile or link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }

cat > "$T/one.pas" <<'PAS'
{$mode objfpc}
program one(output);
type
{$PackRecords 1}
  r1 = record a: byte; b: longint; c: word; d: int64; end;
{$PackRecords 2}
  r2 = record a: byte; b: longint; c: word; d: int64; end;
{$PackRecords 4}
  r4 = record a: byte; b: longint; c: word; d: int64; end;
{$PackRecords 8}
  r8 = record a: byte; b: longint; c: word; d: int64; end;
begin
  writeln(sizeof(r1), ' ', sizeof(r2), ' ', sizeof(r4), ' ', sizeof(r8))
end.
PAS
cat > "$T/pushpop.pas" <<'PAS'
{$mode objfpc}
program pushpop(output);
type
{$PackRecords 1}
  a1 = record b: byte; l: longint; end;
{$Push}
{$PackRecords 4}
  a4 = record b: byte; l: longint; end;
{$Push}
{$PackRecords 2}
  a2 = record b: byte; l: longint; w: word; end;
{$Pop}
  a4b = record b: byte; l: longint; w: word; end;
{$Pop}
  a1b = record b: byte; l: longint; w: word; end;
begin
  writeln(sizeof(a1), ' ', sizeof(a4), ' ', sizeof(a2), ' ', sizeof(a4b), ' ', sizeof(a1b))
end.
PAS
cat > "$T/default.pas" <<'PAS'
{$mode objfpc}
program dflt(output);
type
{$PackRecords 1}
  p1 = record b: byte; l: longint; end;
{$PackRecords C}
  pc = record b: byte; l: longint; end;
{$PackRecords 1}
  q1 = record b: byte; l: longint; end;
{$PackRecords DEFAULT}
  pd = record b: byte; l: longint; end;
begin
  writeln(sizeof(p1), ' ', sizeof(pc), ' ', sizeof(q1), ' ', sizeof(pd))
end.
PAS
for p in one pushpop default; do
  frc=$(fpcrun $p)
  if [ "$p" = pushpop ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a PackRecords directive sets the field alignment as fpc does, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 3 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
