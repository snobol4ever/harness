#!/usr/bin/env bash
# test_gate_pas_a_qword_writes_unsigned_at_its_dialects_width.sh -- a uint64 / qword variable writes as an unsigned decimal at the
# width its dialect gives an integer: natural in the FPC dialects, fpc -Miso's eleven columns in ISO, and an explicit :w right-aligned.
#
# MEASURED 2026-10-14 by hq_pascal for PasRosetta (CEO-1562, CEO-1709): triangular-numbers (fpc-default) wrote "Roots of        7140:"
# where fpc writes "Roots of 7140:": the write of a qword variable took width code -7 (unsigned) before the FPC dialect's natural
# width -4 could apply, and -7 always padded to eleven; and q:22 of 18446744073709551615 wrote -1, the signed reading. THE CURE: width
# code -8 is unsigned at natural width, chosen when the program is in an FPC dialect (lower_pascal_tree.c), read beside -7 by the
# runtime's integer write; an explicit width writes __pas_ustr(q), the unsigned decimal string, right-aligned as fpc does.
#
# ARMS: objqword ({$mode objfpc}) against fpc -Mobjfpc and isoqword against fpc -Miso, both modes, cut LIVE. MEASURED on the parent
# (in-tree swap): both red. FAIL_ONCE=1 corrupts objqword's expectation.
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
cat > "$T/objqword.pas" <<'PAS'
program objqword;
{$mode objfpc}
var n: uint64; q: qword; i: integer;
begin
  n := 7140; q := 18446744073709551615; i := -3;
  writeln('Roots of ', n, ':', q, ' ', i, ' ', n:6, '|', q:22, '|');
  write(n); writeln
end.
PAS
cat > "$T/isoqword.pas" <<'PAS'
program isoqword(output);

var n: uint64; q: qword; i: integer;
begin
  n := 7140; q := 18446744073709551615; i := -3;
  writeln('Roots of ', n, ':', q, ' ', i, ' ', n:6, '|', q:22, '|');
  write(n); writeln
end.
PAS
for pm in "objqword -Mobjfpc" "isoqword -Miso"; do p=${pm% *}; om=${pm#* }
  frc=$(fpcrun $p $om) || exit 2
  if [ -n "${FAIL_ONCE:-}" ] && [ "$p" = objqword ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc $om ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a qword writes unsigned at its dialect's width, as fpc reads it, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined two programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
