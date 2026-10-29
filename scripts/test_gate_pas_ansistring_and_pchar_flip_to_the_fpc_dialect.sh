#!/usr/bin/env bash
# test_gate_pas_ansistring_and_pchar_flip_to_the_fpc_dialect.sh -- a program that names ansistring or pchar as a type is not ISO
# (fpc -Miso refuses both, measured; it accepts shortstring, widestring, unicodestring, rawbytestring, utf8string, ansichar, pansichar
# and pwidechar), so SCRIP reads it in the FPC dialect: natural write widths and FPC's System routines (str with a width, random).
#
# MEASURED 2026-10-14 by hq_pascal for PasRosetta's empty-output class (ceo CEO-1709): largest-five-adjacent-number (no program
# heading, digits, s : AnsiString) stayed ISO in SCRIP's eyes and died "error 22: undefined function called" on str(i:5, s). THE CURE:
# pascal.y's pascal_note_type_ident flips the dialect on ansistring and pchar as it does on an undeclared string; pascal.tab.c
# regenerated with the pinned bison 3.8.2.
#
# ARMS: ansiflip against fpc in its default mode, both modes, cut LIVE. MEASURED on the parent (in-tree swap): red. FAIL_ONCE=1
# corrupts it.
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
cat > "$T/ansiflip.pas" <<'PAS'
var s: AnsiString; p: PChar; i: LongInt;
begin
  s := 'abc'; i := 7;
  str(i:4, s); writeln(s, '|', i, '|', length(s));
  p := nil; writeln(p = nil)
end.
PAS
for pm in "ansiflip -Mfpc"; do p=${pm% *}; om=${pm#* }
  frc=$(fpcrun $p $om) || exit 2
  if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc $om ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: ansistring and pchar flip a program to the FPC dialect, as fpc -Miso's refusal says, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined one program in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
