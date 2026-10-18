#!/usr/bin/env bash
# test_gate_pas_bytebool_wordbool_longbool_store_the_oracles_all_bits_value.sh -- FPC's ByteBool/WordBool/LongBool/QWordBool
# extension types store TRUE as ALL BITS SET (255/65535/-1/-1 read back as the target width), never as plain 1, and a value
# crossing out of one of these types through an explicit byte()/word()/longint()/int64() cast or a := into a plain boolean or
# another bool-family variable must land on the oracle's own number, not SCRIP's prior accidental 1.
#
# MEASURED 2026-10-01 by hq_pascal, both modes, row pascal-every-suite-to-100-under-nonet-ceo-1266. monitor_run.sh --oracle on
# corpus/packages/pascal/fpc_tests/test_cg_tcnvint1.pas bracketed the first divergence at its step 41 (stno 71): bb1 := TRUE then
# tobyte := byte(bb1) read INT=1 on scr against fpx's INT=255. Root cause, two sites in src/parsers/pascal/pascal.y: (1) mk_assign
# stored a boolean-valued RHS into a bytebool/wordbool/longbool/qwordbool-typed variable as the bare 0/1 the literal TRUE/FALSE or a
# comparison already produces, never widened to the family's all-bits pattern, and never narrowed back to strict 0/1 crossing INTO a
# plain boolean from one of these types; (2) the byte(x)/word(x)/shortint(x)/.../int64(x) typecast dispatch in mk_call was a pure
# passthrough for every integer target, truncating nothing, so a widened value crossing out through byte()/word() kept its full
# 64-bit pattern instead of the target width's own unsigned or sign-extended reading. A third site, the WriteLn/trace boolean-text
# formatter (pas_is_boolexpr gated on pas_is_boolvar, which bytebool-family names never populate), printed a bytebool/wordbool/
# longbool/qwordbool variable as a raw integer instead of fpc's "true"/"false" text. Cure: pas_var_is_boolfam(name) resolves a
# variable's declared type through aliases and answers its width (1/2/4/8) when it is one of the four family names; mk_assign widens
# (0 - rhs) into a bool-family destination from a strict boolean producer and narrows (rhs <> 0) crossing out into a non-bool-family
# destination; mk_call's integer-cast dispatch masks to the target width via iand and, for a signed target narrower than 8 bytes,
# sign-extends with the add-half/mod-full/sub-half identity (no ternary node, since lower_pascal.c never learned TT_TERNARY); the one
# remaining bare passthrough (boolfam targets, and every width-8/10 target) reshapes a bare bool-family TT_VAR argument with a +0 so a
# later mk_assign never mistakes a cast-collapsed value for a naked variable reference; the WriteLn/trace formatter's boolexpr gate
# grew an explicit pas_var_is_boolfam() arm and normalizes with (val <> 0) before the existing "false,true" enum-name wrap, which
# already assumed a clean 0/1 index.
#
# ARMS, both modes, each program's expected stdout and exit code cut LIVE from fpc -Miso: (1) conv -- bytebool/wordbool/longbool
# widened by := then read back through byte()/word()/longint()/int64(), both TRUE and FALSE; (2) mix -- wordbool/longbool narrowed
# into a plain boolean and into a differently-sized bool-family variable by :=, plus a bare WriteLn and a "not" of a bool-family
# variable; (3) plain -- a non-bool-family boolean expression (a comparison) through byte()/word() still reads exactly 0/1, pinning
# the pre-existing LOC_JUMP-style conversion this landing must not disturb. FAILS on the parent (bool-family TRUE reads 1 throughout
# arm 1, arm 2's narrowed boolean and bare WriteLn of a bool-family var are wrong, arm 3 was already right and stays right).
# FAIL_ONCE=1 corrupts arm 3's ref.
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
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile or link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/conv.pas" <<'PAS'
program conv(output);
var bb: bytebool; wb: wordbool; lb: longbool;
begin
  bb := true; writeln(byte(bb)); writeln(word(bb)); writeln(longint(bb)); writeln(int64(bb));
  bb := false; writeln(byte(bb)); writeln(word(bb)); writeln(longint(bb)); writeln(int64(bb));
  wb := true; writeln(byte(wb)); writeln(word(wb)); writeln(longint(wb)); writeln(int64(wb));
  wb := false; writeln(byte(wb)); writeln(word(wb));
  lb := true; writeln(byte(lb)); writeln(word(lb)); writeln(longint(lb)); writeln(int64(lb));
  lb := false; writeln(longint(lb))
end.
PAS
cat > "$T/mix.pas" <<'PAS'
program mix(output);
var b: boolean; bb: bytebool; wb: wordbool; lb: longbool;
begin
  wb := true; b := wb; writeln(b);
  wb := false; b := wb; writeln(b);
  lb := true; bb := lb; writeln(bb); writeln(byte(bb));
  b := false; lb := b; writeln(lb); writeln(longint(lb));
  wb := true; writeln(wb); writeln(not wb);
  wb := false; writeln(wb); writeln(not wb)
end.
PAS
cat > "$T/plain.pas" <<'PAS'
program plain(output);
var a, c: integer; tb: byte; tw: word;
begin
  a := 1; c := 2; tb := byte(a < c); writeln(tb); tw := word(a > c); writeln(tw);
  tb := byte(a = a); writeln(tb)
end.
PAS
for p in conv mix plain; do
  frc=$(fpcrun $p)
  if [ "$p" = plain ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: bytebool/wordbool/longbool store and convert as fpc -Miso does, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 3 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
