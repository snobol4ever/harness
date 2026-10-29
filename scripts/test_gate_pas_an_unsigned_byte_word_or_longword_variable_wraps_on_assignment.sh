#!/usr/bin/env bash
# test_gate_pas_an_unsigned_byte_word_or_longword_variable_wraps_on_assignment.sh -- a value assigned to a byte / uint8, word / uint16 or
# longword / cardinal / uint32 / dword scalar (a variable, a function result, a value or var parameter, through inc / dec / += and a type
# alias) is reduced modulo 2^8 / 2^16 / 2^32, as fpc does with range checking off.
#
# MEASURED 2026-10-14 by hq_pascal for PasRosetta (CEO-1562; empty-output class, CEO-1709): SCRIP kept every integer as a 64-bit value, so
# b := 250; b := b + 10 read 260, c := 0; c := c - 1 read -1, a multiplicative hash grew past 2^63, and pernicious-numbers' popcnt32
# (n := (n * K) shr 24 on a Uint32) returned a huge "population count" that indexed a 65-element table out of range (6.5.3.2).
# THE CURE (lower_pascal_tree.c): pas_wrap_mask_of_type names the mask of the unsigned small types through type aliases; mk_assign
# (which inc / dec / the compound operators already use) wraps the right-hand side of an assignment to a TT_VAR of such a type in
# iand(rhs, mask), and value / var parameters of those types are registered so the callee's assignments wrap.
# OPEN, NOT GRADED HERE: signed longint / integer / smallint / shortint wrap; array elements and record fields of these types; qword
# arithmetic past 2^64 (it promotes instead of wrapping); the value of an unassigned expression such as b + 10 (not measured here).
#
# ARMS: unsignedwrap against fpc -Mobjfpc, both modes, cut LIVE. MEASURED on the parent (in-tree swap): red. FAIL_ONCE=1 corrupts it.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile and link"; return 125; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { local mode="$2"; mkdir -p "$T/fpc"; ( cd "$T" && "$FPC" $mode -v0 -FE"$T/fpc" -o"$T/$1.fpc" "$T/$1.pas" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc $mode would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s "./$1.fpc" </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/unsignedwrap.pas" <<'PAS'
program unsignedwrap;
{$mode objfpc}
type tsmall = byte;
var t1: tsmall; b: byte; w: word; l: longword; c: cardinal; u8: uint8; u16: uint16; u32: uint32; i: integer; q: qword;
function Mix(x: longword): longword;
begin
  x := x * 2654435761;
  x := x xor (x shr 15);
  Mix := x + 12345
end;
function Pop32(n: uint32): uint32;
begin
  n := n - ((n shr 1) and $55555555);
  n := (n and $33333333) + ((n shr 2) and $33333333);
  n := (n + (n shr 4)) and $0F0F0F0F;
  n := (n * $01010101) shr 24;
  Pop32 := n
end;
procedure Step(var s: uint32);
begin
  s := s * 1664525 + 1013904223
end;
begin
  b := 250; b := b + 10; w := 65530; w := w + 10; l := 4294967290; l := l + 10; c := 0; c := c - 1;
  u8 := 255; inc(u8); u16 := 0; dec(u16); u32 := 4000000000; u32 := u32 * 2;
  writeln(b, ' ', w, ' ', l, ' ', c, ' ', u8, ' ', u16, ' ', u32);
  writeln(Mix(123456789), ' ', Mix(4294967295));
  u32 := 1; for i := 1 to 5 do Step(u32); writeln(u32);
  l := 3000000000; l := l + l; writeln(l, ' ', l shr 1);
  t1 := 200; t1 := t1 + 100; writeln(t1, ' ', Pop32(4294967295), ' ', Pop32(255 + 256))
end.
PAS
for pm in "unsignedwrap -Mobjfpc"; do p=${pm% *}; om=${pm#* }
  frc=$(fpcrun $p $om) || exit 2
  if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc $om ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: an unsigned byte / word / longword wraps on assignment, as fpc does, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined one program in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
