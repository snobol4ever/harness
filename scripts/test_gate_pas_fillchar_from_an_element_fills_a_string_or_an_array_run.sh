#!/usr/bin/env bash
# test_gate_pas_fillchar_from_an_element_fills_a_string_or_an_array_run.sh -- fillchar(s[k], n, c) writes c into a string's positions
# k..k+n-1 (its length unchanged), and fillchar(a[k], bytes, v) fills an array's elements from k, as many as bytes / element size when
# the element size is known (a static array's size over its count, a dynamic array of a predeclared type) and to the end otherwise.
#
# MEASURED 2026-10-14 by hq_pascal for PasRosetta's empty-output class (ceo CEO-1709): setlength(s, n); fillchar(s[1], n, ' ') and
# fillchar(Chkprimes[0], length(Chkprimes), #1) fell through to a by-name call and died "error 22: undefined function called". THE
# CURE (lower_pascal_tree.c): a string target lowers to s := __pas_strfill(s, k, n, c); an array target to __pas_fill_from(a, k, bytes,
# v, element-size-or-0); by_name_dispatch.c's pas_fill_from fills cells with pas_fill's rules (nested aggregates included).
# OPEN, NOT GRADED HERE: SizeOf of an element of a dynamic array (SizeOf(g[0])) is not folded and dies as a by-name call.
#
# ARMS: elemfill against fpc -Mobjfpc, both modes, cut LIVE. MEASURED on the parent (in-tree swap): red. FAIL_ONCE=1 corrupts it.
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
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile and link"; return 125; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { local mode="$2"; mkdir -p "$T/fpc"; ( cd "$T" && "$FPC" $mode -v0 -FE"$T/fpc" -o"$T/$1.fpc" "$T/$1.pas" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc $mode would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s "./$1.fpc" </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/elemfill.pas" <<'PAS'
program elemfill;
{$mode objfpc}
var s: string; g: array of integer; b: array of boolean; p: array [0..9] of byte; w: array [1..6] of word; i: integer;
begin
  setlength(s, 6); fillchar(s[1], 6, ' '); s[3] := 'x'; writeln('[', s, ']', length(s));
  fillchar(s[2], 2, '-'); writeln('[', s, ']');
  setlength(b, 4); fillchar(b[0], length(b), #1); writeln(b[0], ' ', b[3]);
  for i := 0 to 9 do p[i] := 7; fillchar(p[2], 3, 0); for i := 0 to 9 do write(p[i]); writeln;
  for i := 1 to 6 do w[i] := 9; fillchar(w[3], 2 * SizeOf(word), 0); for i := 1 to 6 do write(w[i]); writeln
end.
PAS
for pm in "elemfill -Mobjfpc"; do p=${pm% *}; om=${pm#* }
  frc=$(fpcrun $p $om) || exit 2
  if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc $om ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: fillchar from an element fills a string's positions or an array's run as fpc reads it, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined one program in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
