#!/usr/bin/env bash
# test_gate_pas_mod_in_the_fpc_dialects_keeps_the_dividends_sign_and_takes_a_negative_divisor.sh -- in a source that names a {$mode} (objfpc, delphi,
# tp), i mod j is the truncated remainder fpc computes: the sign of the dividend, a negative divisor allowed (-7 mod 3 is -1, 7 mod -3 is 1). The ISO
# 7185 6.7.2.2 rule (a result in 0..j-1, an error for j zero or negative) binds the ISO dialect only (CEO-1657), where it stays.
#
# MEASURED 2026-10-21 by hq_pascal on the parent (SCRIP 1aeeea663), fpc 3.2.2 against scrip, one program in each dialect:
#   objfpc  fpc "-1 -2 1 1" / "1 -2 -1"   scrip "2 -2 1 1" / the 6.7.2.2 refusal of a negative divisor
#   iso     fpc " 2 -2 1 1"               scrip " 2 -2 1 1"  (agrees; fpc -Miso stops with Runtime error 200 on a negative divisor, scrip with the 6.7.2.2 text)
# THE CURE (lower_pascal_tree.c, pas_mod): pas_dialect_fpc, the whole program's dialect, lowers i mod j to the plain remainder node; the ISO formula
# and its 'j zero or negative' check stay for every other program. Side effect MEASURED the same day: the check was a builtin call on the slow path,
# about 300 ns each, so a loop of 20M variable-divisor mods and divs took 12.4 s on the parent and 0.54 s after; fbench is unchanged (0.2 s).
#
# ARMS (both modes, stdout and exit code cut LIVE from fpc under the matching -M): modobj ({$mode objfpc}), moddel ({$mode delphi}), modtp ({$mode tp}) --
# a negative dividend, a negative divisor, both negative; modiso (no directive) -- a negative dividend with a positive divisor, ISO's non-negative
# result, and no negative divisor in it. FAIL_ONCE=1 corrupts modobj's expectation.
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
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/$p.s" "$p.pas" </dev/null >/dev/null 2>"$T/e" && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile and link ($(head -1 "$T/e" | cut -c1-120))"; return 125; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { local mode="$2"; mkdir -p "$T/fpc"; ( cd "$T" && "$FPC" $mode -v0 -FE"$T/fpc" -o"$T/$1.fpc" "$T/$1.pas" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc $mode would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s "./$1.fpc" </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
for pm in "modobj objfpc" "moddel delphi" "modtp tp"; do p=${pm% *}; md=${pm#* }
  cat > "$T/$p.pas" <<PAS
{\$mode $md}
program $p;
var a, b: integer;
begin
  a := -7; b := 3;
  writeln(a mod b, ' ', a div b, ' ', 7 mod b, ' ', (-a) mod b);
  a := 7; b := -3;
  writeln(a mod b, ' ', a div b, ' ', (-a) mod b);
  a := -7; b := -3;
  writeln(a mod b, ' ', a div b)
end.
PAS
done
cat > "$T/modiso.pas" <<'PAS'
program modiso;
var a, b: integer;
begin
  a := -7; b := 3;
  writeln(a mod b, ' ', a div b, ' ', 7 mod b, ' ', (-a) mod b)
end.
PAS
arm() { local p="$1" om="$2" frc
  frc=$(fpcrun "$p" "$om") || exit 2
  if [ -n "${FAIL_ONCE:-}" ] && [ "$p" = modobj ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m "$p"; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc $om ($(tr -s ' ' < "$T/o" | tr '\n' '|' | cut -c1-40))"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done; }
arm modobj -Mobjfpc
arm moddel -Mdelphi
arm modtp -Mtp
arm modiso -Miso
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: mod in the FPC dialects is fpc's truncated remainder with a negative divisor allowed, ISO keeps its own, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined four programs over $N arms"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
