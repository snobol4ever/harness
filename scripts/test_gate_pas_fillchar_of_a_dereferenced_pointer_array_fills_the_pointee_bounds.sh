#!/usr/bin/env bash
# test_gate_pas_fillchar_of_a_dereferenced_pointer_array_fills_the_pointee_bounds.sh -- fillchar(p^, n, v) where p^ is a
# dereferenced pointer to a declared array type now fills every element of the POINTEE's own declared bounds (low..high read
# from the pointee's array TYPE, via pas_ptrexpr_target/pas_arrtype_high/pas_arrtype_lo), the same loop-lowering the named
# array-variable case already used.
#
# MEASURED 2026-10-01 by hq_pascal, row pascal-every-suite-to-100-under-nonet-ceo-1266. monitor_run.sh --oracle on
# corpus/packages/pascal/fpc_tests/test_opt_treg3.pas bracketed the divergence at step 5 (stno 16): fpx continues past
# `fillchar(p^, 101*sizeof(longint), 0)` to stno 17, scr ENDs right there. Root cause, src/parsers/pascal/pascal.y's fillchar
# lowering only recognized a destination that is a bare TT_VAR naming an array variable (pas_array_high_get keyed on the
# VARIABLE's name); `p^` lowers to a TT_FNC __pas_deref(p) node, which matched nothing, so the call fell through to an ordinary
# (undefined) routine call and bombed at runtime. Cure: when the destination is __pas_deref(ptr), resolve the pointee's
# declared TYPE name via pas_ptrexpr_target(ptr), look up that TYPE's own bounds via pas_arrtype_high/pas_arrtype_lo (not the
# per-variable table, which a pointer target never populates), and build the same per-element assignment loop indexing through
# a fresh __pas_deref(clone-of-ptr) rather than a bare variable leaf. The pre-existing named-array-variable path is untouched.
#
# ARMS, both modes, each program's expected stdout and exit code cut LIVE from fpc -Miso: (1) parr -- a pointer to array[0..4]
# of longint, filled to zero, two elements overwritten nonzero, re-filled to zero, all five read back; FAILS on parent (fillchar
# through the pointer never lowers, the undefined-routine call bombs). (2) lowb -- a pointer to array[5..8] of longint (a
# NONZERO low bound, pinning pas_arrtype_lo and not just pas_arrtype_high), same mutate/re-zero/read-back shape read at its own
# 5..8 indices; FAILS on parent, same cause. (3) named -- a plain named array variable (the pre-existing path, unchanged by this
# cure), filled to zero after being populated nonzero; already right on parent and stays right, pinning no regression.
# FAIL_ONCE=1 corrupts arm 3's ref.
#
# NOT THIS GATE'S DEFECT, FOUND WHILE DRAFTING, LEFT OPEN: write(p^[i]) where p^[i] indexes a CHAR array through a pointer
# dereference prints the ordinal (pas_is_charexpr has no TT_IDX-over-__pas_deref arm), independent of fillchar and of this cure
# -- reproduces with plain assignment, no fillchar involved. An earlier draft of arm (2) used array[5..8] of char and tripped
# on exactly this; switched to longint to keep this gate on only the fillchar defect it was minted for.
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
cat > "$T/parr.pas" <<'PAS'
program parr(output);
type
  pa = ^ta;
  ta = array[0..4] of longint;
var
  p: pa;
  i: longint;
begin
  new(p);
  fillchar(p^, sizeof(ta), 0);
  p^[2] := 9;
  p^[4] := 7;
  fillchar(p^, sizeof(ta), 0);
  for i := 0 to 4 do writeln(p^[i]);
  dispose(p)
end.
PAS
cat > "$T/lowb.pas" <<'PAS'
program lowb(output);
type
  pb = ^tb;
  tb = array[5..8] of longint;
var
  p: pb;
  i: longint;
begin
  new(p);
  fillchar(p^, sizeof(tb), 0);
  p^[5] := 3;
  p^[8] := 4;
  fillchar(p^, sizeof(tb), 0);
  for i := 5 to 8 do writeln(p^[i]);
  dispose(p)
end.
PAS
cat > "$T/named.pas" <<'PAS'
program named(output);
var
  a: array[1..5] of longint;
  i: longint;
begin
  for i := 1 to 5 do a[i] := i;
  fillchar(a, sizeof(a), 0);
  for i := 1 to 5 do writeln(a[i]);
end.
PAS
for p in parr lowb named; do
  frc=$(fpcrun $p)
  if [ "$p" = named ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: fillchar through a dereferenced pointer array fills the pointee's own bounds, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 3 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
