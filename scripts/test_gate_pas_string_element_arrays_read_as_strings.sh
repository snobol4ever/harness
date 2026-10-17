#!/usr/bin/env bash
# test_gate_pas_string_element_arrays_read_as_strings.sh -- an array whose element type is a string (var, typed constant or local;
# static or dynamic) reads, stores, compares and measures its elements as strings, as fpc does; and a string compared with a char
# compares as strings.
#
# MEASURED 2026-10-14 by hq_pascal for PasRosetta (CEO-1562, row pascal-every-suite-to-100-under-nonet-ceo-1266): no master entry
# declares an array of string, and every use was wrong. The declaration registers the element type as the variable's scalar type
# (pas_scalarvartype), so pas_var_string_kind answered yes for the ARRAY: s[2] lowered as a char of a string (writeln printed nothing),
# s[0] as a shortstring's length byte (the first element of a 0-based typed constant was stored into a __pas_chrlit pseudo-target and
# lost), length(s) as a string length (12 for three elements), and a one-char store as its char code (s[1] := 'q' stored 113).
# Separately u < 'b' with u a string died "error 102: numeric expected" (the char side stayed an integer).
# THE CURE (lower_pascal_tree.c): pas_decl_string_kind is the old table lookup; pas_is_strelem_arr names a static or dynamic array
# whose element type is a string; pas_var_string_kind answers no for such an array. Its elements are string expressions
# (pas_is_stringexpr, pas_is_strval), s[i][j] is a char, a char stored into an element is wrapped as a string, length of a static one
# is its element count, and pas_rel compares a string with a char as two strings.
#
# ARMS: strarr (var, typed constant and local arrays: concatenation, element of element, stores, =, <, pos, a string parameter, length,
# low, high), strzero (a 0-based typed constant's first element), strchar (string against char, both sides), each both modes, stdout
# and exit code cut LIVE from fpc -Mfpc. OPEN, NOT GRADED HERE: string[N] does not truncate on assignment (u: string[10] := 'hello
# world' keeps 11 characters; fpc keeps 10), scalar and element alike -- a row of its own.
# MEASURED on the parent 917f42fdd (an in-tree swap of lower_pascal_tree.c): all three programs red in m3. FAIL_ONCE=1 corrupts strarr.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
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
cat > "$T/strarr.pas" <<'PAS'
program strarr;
const names: array [0..3] of string = ('alpha', 'beta', '', 'delta');
var s: array [1..4] of string; i, n: integer; u: string;
function Shout(x: string): string; begin Shout := x + '!' end;
procedure Local;
var w: array [5..7] of string; k: integer;
begin
  for k := 5 to 7 do w[k] := Copy('abcdefg', k - 4, k - 4);
  for k := low(w) to high(w) do write(w[k], '/', length(w[k]), ' ');
  writeln(length(w), ' ', w[6] + w[7], ' ', w[7][2])
end;
begin
  for i := 1 to 4 do s[i] := names[i - 1] + 'x';
  s[2] := s[2] + s[1]; u := s[2];
  writeln(u, ' ', s[2][3], ' ', length(s[2]), ' ', length(s), ' ', high(s), ' ', low(names));
  for i := 1 to 4 do writeln(i, ':', s[i], ':', Shout(s[i]), ':', pos('x', s[i]), ':', s[i] = 'deltax', ':', s[i] < 'b');
  n := 0; for i := 0 to 3 do n := n + length(names[i]); writeln(n, ' ', names[3][1], names[0]);
  Local
end.
PAS
cat > "$T/strzero.pas" <<'PAS'
program strzero;
const names: array [0..1] of string = ('alpha', 'beta');
 n: array [0..1] of integer = (5, 6);
var i: integer;
begin
  i := 0;
  writeln(names[0], '|', names[i], '|', n[0], '|', n[i]);
end.
PAS
cat > "$T/strchar.pas" <<'PAS'
program strchar;
var u: string; c: char;
begin
  u := 'alphax'; c := 'b';
  writeln(u < 'b', ' ', u < c, ' ', 'alphax' < 'b', ' ', u > 'a');
end.
PAS
for p in strarr strzero strchar; do
  frc=$(fpcrun $p -Mfpc) || exit 2
  if [ -n "${FAIL_ONCE:-}" ] && [ "$p" = strarr ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Mfpc ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: string-element arrays and string-against-char comparisons read as fpc -Mfpc does, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined three programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
