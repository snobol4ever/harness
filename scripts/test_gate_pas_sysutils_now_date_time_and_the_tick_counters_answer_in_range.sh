#!/usr/bin/env bash
# test_gate_pas_sysutils_now_date_time_and_the_tick_counters_answer_in_range.sh -- sysutils' TDateTime, Now, Date, Time, GetTickCount and
# GetTickCount64 exist and answer in the ranges fpc's do: Now is days since 1899-12-30 in local time, Date its integer part, Time its fraction,
# the tick counters are non-negative and non-decreasing milliseconds.
#
# MEASURED 2026-10-14 by hq_pascal for PasRosetta's empty-output class (ceo CEO-1709): 10 of its programs name Now (timing, seeds) and died
# "no defining-point" or "undefined function"; the witness prints only the BOOLEAN range checks, since the values themselves differ per run.
# THE CURE: sysutils.pas gains TDateTime = double and Now / Date / Time / GetTickCount / GetTickCount64 over the new runtime __pas_now
# (clock_gettime REALTIME, local offset, 25569 days to the Unix epoch) and __pas_ticks (CLOCK_MONOTONIC milliseconds).
# OPEN, NOT GRADED HERE: FormatDateTime, DateTimeToStr, EncodeDate / DecodeDate, and the other DateUtils.
#
# ARMS: clocks against fpc -Mobjfpc, both modes, cut LIVE. MEASURED on the parent (in-tree swap): red. FAIL_ONCE=1 corrupts it.
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
cat > "$T/clocks.pas" <<'PAS'
program clocks;
{$mode objfpc}
uses sysutils;
var t0, t1: TDateTime; a, b: int64; d: double; ok: boolean;
begin
  t0 := Now; a := GetTickCount64; b := GetTickCount;
  d := Date; t1 := Time;
  ok := (t0 > 45000) and (t0 < 80000) and (d <= t0) and (d = trunc(d)) and (t1 >= 0) and (t1 < 1) and (a >= 0) and (b >= 0) and (Now >= t0);
  writeln(ok, ' ', GetTickCount64 >= a, ' ', Now - t0 < 1)
end.
PAS
for pm in "clocks -Mobjfpc"; do p=${pm% *}; om=${pm#* }
  frc=$(fpcrun $p $om) || exit 2
  if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc $om ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: Now, Date, Time and the tick counters answer in range, as fpc's do, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined one program in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
