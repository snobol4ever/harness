#!/usr/bin/env bash
# test_gate_pas_a_literal_actual_is_assignment_compatible_with_its_value_formal.sh -- ISO 7185 6.6.3.2: an actual value parameter shall be
# assignment-compatible with the type of its formal-parameter
#
# MEASURED 2026-09-26 by hq_pascal, both modes, row pascal-every-suite-to-100-under-nonet-ceo-1266. Nothing compared an actual with the type
# of its value formal: PAT iso7185prt1707a (b('c') with b(c: integer)) and 1831 (a(1, 2) with a(b: integer; c: char)) compiled and ran to
# rc 0. NO BRACKET: the program is refused at compile, before any event. The cure: pas_value_actuals_check, at the one call-site hook every
# user-routine call passes (pas_pf_actuals), reads each value formal's type from the routine's signature and refuses an actual whose type
# is certain -- a char literal, a real literal or a string -- when it is not assignment-compatible with a formal declared integer, real,
# char or boolean. ⛔ WHAT IT DELIBERATELY DOES NOT JUDGE: an enum constant and a boolean constant reach the call as the same bare integer
# literal an integer does, so an integer literal is refused only against a char formal (where integer, enum and boolean are all wrong).
#
# ARMS, both modes: four refusals (a char literal to an integer formal, an integer to a char formal, a real literal to an integer formal, a
# string to a char formal) must each exit non-zero naming 6.6.3.2; and a control cut LIVE from fpc -Miso (char, integer, enum and boolean
# constants and literals, an integer to a real formal) must run byte-identical. It FAILS on the parent (all four refusals are accepted).
# FAIL_ONCE=1 corrupts the control's ref to prove it can fail.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- the control's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
for arm in "b(c: integer)|b('c')" "b(q: integer; c: char)|b(1, 2)" "b(c: integer)|b(2.5)" "b(c: char)|b('ab')"; do
  N=$((N+1)); hd=${arm%%|*}; call=${arm#*|}
  printf 'program r%d(output);\nprocedure %s;\nbegin\nend;\nbegin\n  %s\nend.\n' $N "$hd" "$call" > "$T/r$N.pas"
  for m in m3 m4; do
    if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "r$N.pas" </dev/null >"$T/o" 2>"$T/e" ); rc=$?
    else ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/r$N.s" "r$N.pas" </dev/null >"$T/o" 2>"$T/e" ); rc=$?; fi
    if [ "$rc" -ne 0 ] && [ "$rc" -lt 124 ] && grep -q 'ISO 7185 6\.6\.3\.2 violation' "$T/e"; then echo "  refusal $N ($call against $hd) $m: rc=$rc, names 6.6.3.2"
    else echo "  ⛔ refusal $N ($call against $hd) $m FAILED: rc=$rc"; echo "      err: $(head -1 "$T/e" | cut -c1-160)"; RC=1; fi
  done
done
cat > "$T/ctl.pas" <<'PAS'
program ctl(output);
const c = 'x'; n = 5; t = true;
type color = (red, green, blue);
procedure a(p: char; q: integer; r: color; s: boolean; u: real);
begin writeln(p, q, ord(r), s, u:4:1) end;
begin
  a(c, n, green, t, 3);
  a('y', -2, blue, false, 2.5)
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 -o"ctl.fpc" ctl.pas >/dev/null 2>&1 && timeout -k 5 20s ./ctl.fpc ) > "$T/ctl.want" 2>&1
[ -s "$T/ctl.want" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no output for the control"; exit 2; }
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/ctl.want"; fi
for m in m3 m4; do
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run ctl.pas </dev/null >"$T/o" 2>"$T/e" ); rc=$?
  else ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/ctl.s" ctl.pas </dev/null >/dev/null 2>&1 && cc -m64 -no-pie ctl.s -o ctl.m4 -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 \
         && timeout -k 5 20s ./ctl.m4 </dev/null >"$T/o" 2>"$T/e" ); rc=$?; fi
  if [ "$rc" = 0 ] && cmp -s "$T/ctl.want" "$T/o"; then echo "  control $m: byte-identical to fpc -Miso"
  else echo "  ⛔ control $m FAILED: rc=$rc"; echo "      want: $(tr '\n' '|' < "$T/ctl.want")"; echo "      got : $(tr '\n' '|' < "$T/o")"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a literal actual of the wrong type for its value formal is refused with 6.6.3.2 ($N of $N), and compatible actuals run, both modes"
else echo "GATE FAIL(1) [$G]: examined $N refusal arms and 1 control in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
