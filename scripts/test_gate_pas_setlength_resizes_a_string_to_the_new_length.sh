#!/usr/bin/env bash
# test_gate_pas_setlength_resizes_a_string_to_the_new_length.sh -- SetLength(S, N) on a string or widestring variable
# resizes it to exactly N characters (truncating or extending), matching ISO 6.6.3.3's var-parameter semantics by
# REASSIGNING the variable to a freshly built string rather than mutating in place, since SCRIP strings are plain
# value-copied DESCR strings with no in-place resize.
#
# MEASURED 2026-10-01 by hq_pascal, row pascal-every-suite-to-100-under-nonet-ceo-1266. monitor_run.sh --oracle on
# corpus/packages/pascal/fpc_tests/webtbs_tw4763.pas bracketed the divergence at step 5 (stno 15, the SetLength call):
# fpx continues to stno 16, scr ENDs there (error 22: Undefined function called) -- SetLength was not implemented at
# all (zero occurrences anywhere in src/parsers/pascal/pascal.y or src/runtime before this landing).
#
# CURE: pascal.y's mk_call special-cases "setlength" exactly as it already does "inc"/"dec" -- a procedure that
# reassigns its first (variable) argument from a computed value -- lowering SetLength(v, n) to v := __pas_setlength(v, n).
# The new runtime builtin __pas_setlength (src/runtime/by_name_dispatch.c, beside __pas_alpha_str) allocates a fresh
# string of the requested length, copying min(old,new) bytes from the original. ⛔ MEASURED BUG CAUGHT BEFORE LANDING:
# the first cut padded a GROWN string's new bytes with NUL (0), which silently broke Length() on the grown string --
# every string-length function in this runtime (see "length" in the shared by-name dispatch) reads strlen(), so a NUL
# byte anywhere reads as the string's end. Padding with a space instead keeps Length() correct; the actual CONTENT of
# bytes past the old length is undefined by the ISO/FPC spec and MEASURED to differ from fpc -Miso's own choice (fpc's
# reference-counted strings expose old capacity bytes after a prior shrink; SCRIP's fresh allocation cannot and need
# not reproduce that) -- no arm below prints a grown string's content, only its length, to stay off that undefined
# ground entirely.
#
# ARMS, both modes, each program's expected stdout and exit code cut LIVE from fpc -Miso: (1) shrink -- SetLength
# truncates a string, prints the (well-defined) truncated content and its new length; FAILS on parent (error 22).
# (2) grow -- SetLength extends a string past its old length; prints ONLY the lengths before and after, never the
# grown content (undefined ground, deliberately not graded); FAILS on parent. (3) widewit -- the exact witness shape
# that found this defect: a WideString set via SetLength to its OWN current length (a no-op in substance), printing
# Length(); FAILS on parent, same error 22. FAIL_ONCE=1 corrupts arm 3's ref.
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
cat > "$T/shrink.pas" <<'PAS'
{$mode objfpc}
program shrink(output);
var s: string;
begin
  s := 'hello world';
  SetLength(s, 5);
  writeln(s);
  writeln(Length(s))
end.
PAS
cat > "$T/grow.pas" <<'PAS'
{$mode objfpc}
program grow(output);
var s: string;
begin
  s := 'hi';
  writeln(Length(s));
  SetLength(s, 9);
  writeln(Length(s))
end.
PAS
cat > "$T/widewit.pas" <<'PAS'
{$mode objfpc}{H+}
program widewit(output);
var w: WideString;
begin
  w := '123456';
  SetLength(w, 6);
  writeln(Length(w))
end.
PAS
for p in shrink grow widewit; do
  frc=$(fpcrun $p)
  if [ "$p" = widewit ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: SetLength resizes a string/widestring to the new length, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 3 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
