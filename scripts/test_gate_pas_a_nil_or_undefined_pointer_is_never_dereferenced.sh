#!/usr/bin/env bash
# test_gate_pas_a_nil_or_undefined_pointer_is_never_dereferenced.sh -- ISO 7185 6.5.4: it is an error if the pointer-variable of an
# identified-variable denotes nil or is undefined
#
# MEASURED 2026-09-25 by hq_pascal, both modes, row pascal-every-suite-to-100-under-nonet-ceo-1266. Every Pascal dereference arm in
# by_name_dispatch.c (__pas_deref, __pas_deref_set, __pas_field_set, __pas_nrec_pfield_set, __pas_field_idx_set, __pas_nrec_deref_set)
# answered a nil, never-assigned or disposed pointer by silently reading 0 or dropping the store, so PAT iso7185prt1703 (nil) and 1704
# (undefined) ran to rc 0. NO BRACKET: fpx has no event for a dereference that should not happen -- the defect is an absent error. The
# cure: pas_heap_ref, the one door all six arms now go through, stops with ISO 7185 6.5.4 naming nil or undefined, or 6.6.5.3 for a disposed variable.
#
# ARMS, both modes: five faults -- read through nil, read through a never-assigned pointer, store through nil, a record-field store through
# nil, and a read after dispose -- each must print exactly what fpc -Miso prints before its own fault (cut LIVE), exit non-zero, and name
# 6.5.4 (6.6.5.3 for the disposed arm) on stderr; and a control cut LIVE from fpc -Miso (a linked list built, walked with nil tests, disposed) must run byte-identical.
# ⭐ THE DISPOSED ARM IS THE ONE PLACE fpc DOES NOT FAULT: fpc -Miso reads the stale value after dispose and runs to rc 0. ISO 7185 3.2 lets
# a processor leave an error undetected, and it lets one detect it; SCRIP detects it, so that arm's expected stdout is fpc's up to the fault
# (its 'after' line cut), and the gate REFUSES if fpc ever starts faulting there, because then the arm must be re-cut.
# It FAILS on the parent (all five faults run to rc 0). FAIL_ONCE=1 corrupts the control's ref to prove it can fail.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
run_mode() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/$p.$m.out" 2>"$T/$p.$m.err" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 ) || { echo "  ⛔ arm $p m4: did not compile"; return 99; }
  ( cd "$T" && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: arm $p compiled but would not link"; exit 2; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/$p.$m.out" 2>"$T/$p.$m.err" ); return $?; }
printf 'program nilrd(output);\nvar p: ^integer; b: integer;\nbegin\n  writeln(%s); p := nil; b := p^; writeln(%s, b)\nend.\n' "'before'" "'after '" > "$T/nilrd.pas"
printf 'program undrd(output);\nvar p: ^integer; b: integer;\nbegin\n  writeln(%s); b := p^; writeln(%s, b)\nend.\n' "'before'" "'after '" > "$T/undrd.pas"
printf 'program nilwr(output);\nvar p: ^integer;\nbegin\n  writeln(%s); p := nil; p^ := 7; writeln(%s)\nend.\n' "'before'" "'after'" > "$T/nilwr.pas"
printf 'program nilfld(output);\ntype r = record a, b: integer end;\nvar p: ^r;\nbegin\n  new(p); p^.a := 1; writeln(p^.a); p := nil; p^.b := 2; writeln(%s)\nend.\n' "'after'" > "$T/nilfld.pas"
printf 'program disprd(output);\nvar p: ^integer; b: integer;\nbegin\n  new(p); p^ := 5; writeln(p^); dispose(p); b := p^; writeln(%s, b)\nend.\n' "'after '" > "$T/disprd.pas"
cat > "$T/ctl.pas" <<'PAS'
program ctl(output);
type link = ^node; node = record v: integer; next: link end;
var head, p, q: link; i, s: integer;
begin
  head := nil;
  for i := 1 to 5 do begin new(p); p^.v := i * i; p^.next := head; head := p end;
  s := 0; p := head;
  while p <> nil do begin s := s + p^.v; write(p^.v:4); p := p^.next end;
  writeln(' sum ', s);
  p := head;
  while p <> nil do begin q := p^.next; dispose(p); p := q end;
  if p = nil then writeln('all disposed')
end.
PAS
for p in nilrd undrd nilwr nilfld disprd ctl; do
  ( cd "$T" && "$FPC" -Miso -v0 -o"$p.fpc" $p.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile arm $p"; exit 2; }
  ( cd "$T" && timeout -k 5 20s ./$p.fpc </dev/null >"$T/$p.want" 2>/dev/null ); echo $? > "$T/$p.frc"
done
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/ctl.want"; fi
[ "$(cat "$T/disprd.frc")" = 0 ] && grep -q '^after' "$T/disprd.want" || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso no longer reads through a disposed pointer undetected -- re-cut arm disprd"; exit 2; }
grep -v '^after' "$T/disprd.want" > "$T/disprd.cut"; mv "$T/disprd.cut" "$T/disprd.want"
for p in nilrd undrd nilwr nilfld disprd; do
  [ "$p" = disprd ] || [ "$(cat "$T/$p.frc")" != 0 ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle ran fault arm $p to rc 0 -- the arm does not carry the fault it claims"; exit 2; }
  for m in m3 m4; do
    run_mode $m $p; rc=$?
    cl='6\.5\.4'; [ "$p" = disprd ] && cl='6\.6\.5\.3'
    if [ "$rc" -ne 0 ] && [ "$rc" -lt 99 ] && cmp -s "$T/$p.want" "$T/$p.$m.out" && grep -q "ISO 7185 $cl" "$T/$p.$m.err"; then
         echo "  arm $p $m: rc=$rc, stdout = fpc -Miso before its fault, stderr names ${cl//\\/}"
    else echo "  ⛔ arm $p $m FAILED: rc=$rc (oracle rc=$(cat "$T/$p.frc"))"; echo "      want out: $(tr '\n' '|' < "$T/$p.want")"; echo "      got  out: $(tr '\n' '|' < "$T/$p.$m.out")"
         echo "      err: $(head -1 "$T/$p.$m.err" | cut -c1-160)"; RC=1; fi
  done
done
for m in m3 m4; do
  run_mode $m ctl; rc=$?
  if [ "$rc" = 0 ] && cmp -s "$T/ctl.want" "$T/ctl.$m.out"; then echo "  control arm $m: byte-identical to fpc -Miso"
  else echo "  ⛔ control arm $m FAILED: rc=$rc"; echo "      want: $(tr '\n' '|' < "$T/ctl.want")"; echo "      got : $(tr '\n' '|' < "$T/ctl.$m.out")"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a dereference of nil or of an undefined pointer stops with ISO 7185 6.5.4, of a disposed one with 6.6.5.3 (5 of 5), and a list walk runs, both modes"
else echo "GATE FAIL(1) [$G]: examined 5 fault arms and 1 control arm in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
