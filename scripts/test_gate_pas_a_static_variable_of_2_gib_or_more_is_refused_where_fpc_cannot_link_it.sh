#!/usr/bin/env bash
# test_gate_pas_a_static_variable_of_2_gib_or_more_is_refused_where_fpc_cannot_link_it.sh -- a Pascal variable whose type needs 2 GiB (2147483648 bytes) or more
# is refused at compile time with a static-storage limit diagnostic, as fpc refuses it (it cannot link the data); a smaller array runs as before.
#
# WHY (PAT iso7185prt1881 and prt1882, "Create an array impossible to contain in memory"; the ceo's pat-five-reds-after-the-coo-measurement-fix, 2026-10-21):
# var a: array[0..maxint] of integer made SCRIP ask the allocator for 32 GB, which ended in the allocator's hard-cap message ([ZHP] heap exhausted) rather than
# in a refusal of the program. THE CURE (lower_pascal_tree.c): the element size now multiplies without overflow (saturating at 2^62) and a variable declaration whose
# size exceeds 2147483647 bytes counts a static-storage limit error, summarised on its own line ('N static-storage limit error(s) in FILE -- no code generated').
#
# MEASURED 2026-10-21 by hq_pascal against fpc 3.2.2 -Miso: 2^30 bytes compile, 2^31 bytes (char array to maxint, or integer array to 536870911) end 'Error while linking'.
# ARMS (both modes; the refusal side is judged against fpc LIVE -- fpc must refuse the same program, scrip must exit non-zero naming the limit and generate no code;
# the run side is cut from fpc): bigchar (array[0..2147483647] of char), bigint (array[-maxint..maxint] of integer, the prt1882 shape), bigobj (the same under
# {$mode objfpc}), okarr (array[0..1000000] of integer, a store and a read). FAIL_ONCE=1 corrupts okarr's expectation.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
cat > "$T/bigchar.pas" <<'PAS'
program bigchar;
var a: array[0..2147483647] of char;
begin
  a[0] := 'x'
end.
PAS
cat > "$T/bigint.pas" <<'PAS'
program bigint;
var a: array[-maxint..maxint] of integer;
begin
  a[maxint] := 0
end.
PAS
cat > "$T/bigobj.pas" <<'PAS'
{$mode objfpc}
program bigobj;
var a: array[0..2147483647] of char;
begin
  a[0] := 'x'
end.
PAS
cat > "$T/okarr.pas" <<'PAS'
program okarr;
var a: array[0..1000000] of integer;
begin
  a[1000000] := 7;
  writeln(a[1000000])
end.
PAS
refusal() { local p="$1" om="$2" fr
  mkdir -p "$T/fpc"; ( cd "$T" && "$FPC" $om -v0 -FE"$T/fpc" -o"$T/$p.fpc" "$T/$p.pas" >/dev/null 2>&1 ); fr=$?
  if [ "$fr" = 0 ]; then echo "⛔ GATE REFUSE(2) [$G]: fpc $om accepted $p -- the oracle does not refuse it, so this arm measures nothing"; exit 2; fi
  for m in m3 m4; do N=$((N + 1))
    if [ "$m" = m3 ]; then ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); rc=$?
    else ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/$p.s" "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); rc=$?; fi
    if [ "$rc" != 0 ] && [ "$rc" -lt 124 ] && grep -q 'static-storage limit' "$T/e" && [ ! -s "$T/o" ]; then echo "  $p $m: refused rc=$rc, as fpc $om refuses it ($(head -1 "$T/e" | cut -c1-70)...)"
    else echo "  ⛔ $p $m FAILED: rc=$rc, expected a refusal naming the static-storage limit: $(head -1 "$T/e" | cut -c1-120)"; RC=1; fi; done; }
refusal bigchar -Miso
refusal bigint -Miso
refusal bigobj -Mobjfpc
( cd "$T" && "$FPC" -Miso -v0 -FE"$T/fpc" -o"$T/okarr.fpc" "$T/okarr.pas" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc would not compile okarr"; exit 2; }
( cd "$T" && timeout -k 5 20s "./okarr.fpc" </dev/null >"$T/okarr.want" 2>/dev/null ); frc=$?
[ -n "${FAIL_ONCE:-}" ] && echo "corrupted by FAIL_ONCE" >> "$T/okarr.want"
for m in m3 m4; do N=$((N + 1))
  if [ "$m" = m3 ]; then ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" --run okarr.pas </dev/null >"$T/o" 2>"$T/e" ); rc=$?
  else ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/okarr.s" okarr.pas </dev/null >/dev/null 2>"$T/e" && cc -m64 -no-pie okarr.s -o okarr.m4 -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 && timeout -k 5 20s ./okarr.m4 </dev/null >"$T/o" 2>"$T/e" ); rc=$?; fi
  if [ "$rc" = "$frc" ] && cmp -s "$T/okarr.want" "$T/o"; then echo "  okarr $m: rc=$rc, stdout byte-identical to fpc -Miso ($(tr '\n' '|' < "$T/o"))"
  else echo "  ⛔ okarr $m FAILED: rc=$rc (fpc $frc)"; diff "$T/okarr.want" "$T/o" | head -4 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a variable of 2 GiB or more is refused where fpc cannot link it and a smaller array runs, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined four programs over $N arms"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
