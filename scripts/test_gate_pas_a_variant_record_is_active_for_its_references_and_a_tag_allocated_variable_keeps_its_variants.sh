#!/usr/bin/env bash
# test_gate_pas_a_variant_record_is_active_for_its_references_and_a_tag_allocated_variable_keeps_its_variants.sh -- ISO 7185 6.5.3.3 and 6.6.5.3:
# a reference to a component of a variant while the (assigned) tag-field selects another variant is an error; new(p, c1, ..., cn) fixes the variants
# of the variable it creates, so assigning its tag-field a value that activates another variant, disposing it with other constants (or none), or
# disposing with constants a variable not created that way, is an error; dispose of nil or an undefined pointer is an error.
#
# MEASURED 2026-10-04 by hq_pascal on PAT iso7185prt1702A, 1719, 1720, 1721, 1722, 1723 and 1724: each ran to rc 0 (the extra constants of new and dispose
# were dropped, the tag was never consulted, dispose took any value). CURE: pascal.y keeps a table of the tag-field and per-field arm masks of each
# record with a tagged variant part (Lon granted the one new parser table in chat 2026-10-04), marks a variant-field selection of a record variable whose
# tag was assigned earlier and wraps its read or assignment in __pas_vcheck; new(p, c...) assigns the tag and marks the block (the heap-dead flag byte's bit 2);
# __pas_dispose / __pas_dispose_k / __pas_tagset_chk read that bit.
#
# ARMS, both modes: seven fault programs each print `before`, then fault -- stdout must be exactly `before`, rc non-zero, stderr naming the clause (fpc -Miso
# does not fault on these, so the expectation is the ISO text, not fpc's); and a control cut LIVE from fpc -Miso (legal variant use, tag-allocated new/dispose
# with matching constants, an unassigned tag, a changed tag) that must run byte-identical. FAIL_ONCE=1 corrupts the control's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile or link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }

cat > "$T/vact.pas" <<'PAS'
program vact(output);
var a: record case val: boolean of true: (i: integer); false: (c: char) end;
begin
  writeln('before'); a.val := true; a.c := 'c'; writeln('after')
end.
PAS
cat > "$T/newtag.pas" <<'PAS'
program newtag(output);
type a = record case b: boolean of true: (c: integer); false: (d: char) end;
var e: ^a;
begin
  writeln('before'); new(e, true); e^.b := false; writeln('after')
end.
PAS
cat > "$T/disp0.pas" <<'PAS'
program disp0(output);
type a = record case b: boolean of true: (c: integer); false: (d: char) end;
var e: ^a;
begin
  writeln('before'); new(e, true); dispose(e); writeln('after')
end.
PAS
cat > "$T/dispk.pas" <<'PAS'
program dispk(output);
type a = record case b: boolean of true: (c: integer); false: (d: char) end;
var e: ^a;
begin
  writeln('before'); new(e, true); dispose(e, false); writeln('after')
end.
PAS
cat > "$T/dispn.pas" <<'PAS'
program dispn(output);
type a = record case b: boolean of true: (c: integer); false: (d: char) end;
var e: ^a;
begin
  writeln('before'); new(e); dispose(e, true); writeln('after')
end.
PAS
cat > "$T/dispnil.pas" <<'PAS'
program dispnil(output);
var a: ^integer;
begin
  writeln('before'); a := nil; dispose(a); writeln('after')
end.
PAS
cat > "$T/dispund.pas" <<'PAS'
program dispund(output);
var a: ^integer;
begin
  writeln('before'); dispose(a); writeln('after')
end.
PAS
cat > "$T/ctl.pas" <<'PAS'
program ctl(output);
type a = record case b: boolean of true: (c: integer); false: (d: integer) end;
var v: a; w: a; e, f: ^a;
begin
  v.b := true; v.c := 7; writeln(v.c);
  v.b := false; v.d := 31; writeln(v.d);
  w.c := 11; writeln(w.c);
  new(e, true); e^.c := 5; e^.b := true; writeln(e^.c); dispose(e, true);
  new(f); f^.b := false; f^.d := 32; f^.b := true; f^.c := 9; writeln(f^.c); dispose(f)
end.
PAS
RC=0; N=0
for m in m3 m4; do
  for p in vact newtag disp0 dispk dispn dispnil dispund; do
    case $p in vact) cl=6.5.3.3;; *) cl=6.6.5.3;; esac
    run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" != 0 ] && [ "$(cat "$T/o")" = before ] && grep -q "$cl" "$T/e"; then echo "  $p $m: refused with $cl after printing before (rc=$rc)"
    else echo "  ⛔ $p $m FAILED: rc=$rc stdout=[$(head -c 60 "$T/o" | tr '\n' '|')] err=[$(head -c 100 "$T/e")]"; RC=1; fi
  done
done
frc=$(fpcrun ctl)
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/ctl.want"; fi
for m in m3 m4; do run $m ctl; rc=$?; N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/ctl.want" "$T/o"; then echo "  ctl $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ ctl $m FAILED: rc=$rc (fpc $frc)"; diff "$T/ctl.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: seven variant/tag/dispose faults are refused and a legal control runs as fpc, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined 8 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
