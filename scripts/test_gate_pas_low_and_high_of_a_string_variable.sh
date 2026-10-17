#!/usr/bin/env bash
# test_gate_pas_low_and_high_of_a_string_variable.sh -- low(s) and high(s) of a string-typed variable or formal answer as
# fpc does: low(s) is 1 and high(s) is Length(s) for an ansistring/string/widestring/unicodestring; low(s) is 0 and high(s) is 255
# for a shortstring or an OpenString formal; a variable's own declared type wins over a same-named variable in an enclosing scope.
#
# MEASURED 2026-10-03 by hq_pascal, row pascal-every-suite-to-100-under-nonet-ceo-1266. webtbs_tw14941a (FPC) printed its
# first line and halted rc=1: its procedure P(s: OpenString) tests high(s)<>255, and pascal.y's low/high folding knew only
# arrays and ordinal types, so high(s) fell through to an undefined-routine call (webtbs_tw22936, which also tests
# high(ansistring), additionally needs {$ZEROBASEDSTRINGS ON} and stays red -- a flag a new global would carry).
#
# CURE: pascal.y mk_call's low/high arm asks pas_var_string_kind(name), which reads the declaration VISIBLE at the use (the
# scalar-var-type table now records each entry's scope uid, and value/var formals register their string-family types
# through pas_formal_strtypes beside pas_formal_chararrs). Kind 2 (shortstring, openstring) folds high to 255 and low to 0 (the
# length byte is index 0); kind 1 lowers high(s) to Length(s) of a clone of the variable and low to the literal 1.
#
# ARMS, both modes, each program's expected stdout and exit code cut LIVE from fpc: (ansi) low/high of an ansistring that
# changes length; (open) the tw14941a shape, an OpenString formal; (shadow) a formal OpenString and a local shortstring both
# shadow a global ansistring of the same name -- the global's high stays Length(s) after each routine returns, which a
# latest-declaration-wins lookup answers 255. FAIL_ONCE=1 corrupts the shadow arm's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
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
cat > "$T/ansi.pas" <<'PAS'
{$mode objfpc}{$H+}
program ansi(output);
var s: ansistring;
begin
  s := 'abc';
  writeln(low(s), ' ', high(s));
  s := 'hello world';
  writeln(low(s), ' ', high(s))
end.
PAS
cat > "$T/open.pas" <<'PAS'
{$mode delphi}
program open(output);
var t: shortstring;
procedure P(s: OpenString);
begin
  writeln(s, ' ', high(s), ' ', low(s))
end;
begin
  P('12345');
  t := 'xy';
  P(t);
  writeln(high(t))
end.
PAS
cat > "$T/shadow.pas" <<'PAS'
{$mode delphi}
program shadow(output);
var s: string;
procedure P(s: OpenString);
begin
  writeln(high(s))
end;
procedure Q;
var s: shortstring;
begin
  s := 'q';
  writeln(high(s))
end;
begin
  s := 'abcd';
  P('zz');
  writeln(high(s));
  Q;
  writeln(high(s))
end.
PAS
for p in ansi open shadow; do
  frc=$(fpcrun $p)
  if [ "$p" = shadow ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: low/high of a string variable answer as fpc does, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 3 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
