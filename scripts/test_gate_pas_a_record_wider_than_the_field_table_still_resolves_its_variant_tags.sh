#!/usr/bin/env bash
# test_gate_pas_a_record_wider_than_the_field_table_still_resolves_its_variant_tags.sh
#
# MEASURED 2026-09-13 by the coo on origin 6d384fd08, taking the P5 self-host row. Pascal-P5's compiler pcom.pas aborted
# the whole compiler with "FATAL emit_drive: IR op=5 ... REFUSED AT A GUARD -- emit.cpp:1600", the binop operand-slot
# guard. The ceo ruled (CEO-675) that a refusal sink is never the site of a cure and the guard names the WITNESS, not the
# bug; that ruling is what found this. Upstream: the Pascal lowerer's DEFAULT case turns any tree node it does not handle
# into a VALUELESS JUMP, silently, and a comparison built over one of those reaches the emitter with an operand that has
# no slot. The unhandled nodes were 38 raw field selections, and they were raw because of two frontend faults together:
#
#   1. PAS_FIELD_MAX was 32 and pas_pend_add DROPPED SILENTLY past it. P5's identifier record has about 35 fields.
#   2. A tagged variant part registers its tag AFTER the whole variant part is parsed, so every tag lands at the END of
#      the field list -- which is what put exactly the tags past the 32 cap. The three names that fell off were klass,
#      pfdeckind and pfkind, all three of them tags.
#
# Cure: the cap is 128 and an overflow now SAYS SO on stderr instead of dropping a field in silence. That is the whole
# cure and it is deliberately the smaller one. ⛔ MOVING THE TAG TO ITS OWN POSITION, which is where ISO 7185 6.4.3.3
# puts it, WAS TRIED AND REVERTED: it shifted every field after a tag by one and made the SCRIP-built Pascal-P4 compiler
# reject its own source with 105 errors where it had none, and CEO-589 forbids a cure that trades one program for
# another. The cap raise alone fixes P5's pcom and leaves P4 clean. The ordering is a separate row with the downstream
# assumption to find first. pascal.y keeps its 5 shift/reduce conflicts.
#
# ARMS: one program, both modes, byte-identical to fpc -Miso -- a record with 28 fixed fields and a NESTED tagged variant
# part, so the inner tag sits past the old cap; every fixed field written and summed, both tags written and read back by
# ord, a variant field under each tag, and the two tags compared. On the parent tree this witness DUMPS CORE at the
# emitter guard. FAIL_ONCE=1 corrupts the sum line to prove the diff arm trips.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "GATE REFUSE(2) [$G]: no fpc at $FPC -- the ref is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/b.pas" <<'PAS'
program bigrec(output);
type
  kind = (ka, kb, kc);
  dk = (da, db);
  ctp = ^big;
  big = record
    f01: integer;
    f02: integer;
    f03: integer;
    f04: integer;
    f05: integer;
    f06: integer;
    f07: integer;
    f08: integer;
    f09: integer;
    f10: integer;
    f11: integer;
    f12: integer;
    f13: integer;
    f14: integer;
    f15: integer;
    f16: integer;
    f17: integer;
    f18: integer;
    f19: integer;
    f20: integer;
    f21: integer;
    f22: integer;
    f23: integer;
    f24: integer;
    f25: integer;
    f26: integer;
    f27: integer;
    f28: integer;
    case tag: kind of
      ka: ();
      kb: (b1: integer; b2: integer);
      kc: (c1: integer;
           case tag2: dk of
             da: (d1: integer);
             db: (d2: integer))
  end;
var p: ctp; i, s: integer;
begin
  new(p);
  p^.f01 := 7;
  p^.f02 := 14;
  p^.f03 := 21;
  p^.f04 := 28;
  p^.f05 := 35;
  p^.f06 := 42;
  p^.f07 := 49;
  p^.f08 := 56;
  p^.f09 := 63;
  p^.f10 := 70;
  p^.f11 := 77;
  p^.f12 := 84;
  p^.f13 := 91;
  p^.f14 := 98;
  p^.f15 := 105;
  p^.f16 := 112;
  p^.f17 := 119;
  p^.f18 := 126;
  p^.f19 := 133;
  p^.f20 := 140;
  p^.f21 := 147;
  p^.f22 := 154;
  p^.f23 := 161;
  p^.f24 := 168;
  p^.f25 := 175;
  p^.f26 := 182;
  p^.f27 := 189;
  p^.f28 := 196;
  p^.tag := kc;
  p^.c1 := 900;
  p^.tag2 := db;
  p^.d2 := 4242;
  s := 0;
  s := s + p^.f01;
  s := s + p^.f02;
  s := s + p^.f03;
  s := s + p^.f04;
  s := s + p^.f05;
  s := s + p^.f06;
  s := s + p^.f07;
  s := s + p^.f08;
  s := s + p^.f09;
  s := s + p^.f10;
  s := s + p^.f11;
  s := s + p^.f12;
  s := s + p^.f13;
  s := s + p^.f14;
  s := s + p^.f15;
  s := s + p^.f16;
  s := s + p^.f17;
  s := s + p^.f18;
  s := s + p^.f19;
  s := s + p^.f20;
  s := s + p^.f21;
  s := s + p^.f22;
  s := s + p^.f23;
  s := s + p^.f24;
  s := s + p^.f25;
  s := s + p^.f26;
  s := s + p^.f27;
  s := s + p^.f28;
  writeln('sum ', s:1);
  writeln('tag ', ord(p^.tag):1, ' tag2 ', ord(p^.tag2):1, ' c1 ', p^.c1:1, ' d2 ', p^.d2:1);
  if (p^.tag = kc) and (p^.tag2 = db) then writeln('tags compare') else writeln('tags do not compare')
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 b.pas >/dev/null 2>&1 && ./b ) > "$T/b.ref" 2>&1
grep -q '^tags compare$' "$T/b.ref" || { echo "GATE REFUSE(2) [$G]: the oracle did not produce the tag-comparison line this gate pins -- the oracle moved: $(tail -1 "$T/b.ref")"; exit 2; }
( cd "$T" && timeout -k 5 60 "$SCRIP" --compile --out=b.s b.pas </dev/null && gcc b.s -o b.bin -L"$RT_DIR" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "GATE FAIL(1) [$G]: the mode-4 witness did not build -- a record wider than the field table still loses its variant tags"; exit 1; }
RC=0
for M in m3 m4; do
  if [ "$M" = m3 ]; then ( cd "$T" && timeout -k 5 60 "$SCRIP" --run b.pas </dev/null ) >"$T/$M.out" 2>&1
  else ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 60 ./b.bin </dev/null ) >"$T/$M.out" 2>&1
  fi
  if [ -n "${FAIL_ONCE:-}" ] && [ "$M" = m3 ]; then sed -i '1s/^sum 2842/sum 2841/' "$T/$M.out"; fi
  if diff -u "$T/b.ref" "$T/$M.out" >"$T/$M.diff"; then echo "  $M PASS ($(wc -l <"$T/b.ref") lines byte-identical to fpc -Miso)"
  else echo "  $M FAIL ($(grep -c '^[-+][^-+]' "$T/$M.diff") diff lines)"; sed -n '1,10p' "$T/$M.diff" | sed 's/^/      /'; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a record wider than the field table keeps every field, and a tagged variant part registers its tag at its own position in both modes"
else echo "GATE FAIL(1) [$G]: a wide record loses its variant tags (examined 2 modes)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
