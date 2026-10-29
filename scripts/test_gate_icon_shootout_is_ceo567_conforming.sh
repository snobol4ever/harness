#!/usr/bin/env bash
# test_gate_icon_shootout_is_ceo567_conforming.sh -- EVERY KERNEL IN benchmarks/icon/shootout IS A REVIEWED,
# PRISTINE, REF-BEARING ICON PROGRAM (CEO-567 THE KERNEL CONVENTION; row icon-shootout-five-programs-are-raw-
# upstream-and-cannot-parse-under-scrip, cfo 2026-09-12).
#
# PER PROGRAM, FOUR THINGS, and each is a separate red so a reader can route it:
#   GUARD    no `$ifdef`/`$ifndef`/`$endif` line remains -- the entry point is a plain `procedure main`, not a
#            harness-defined symbol (upstream wrapped main in `$ifdef MAIN` for the Unicon bench driver).
#   PARSE    SCRIP parses it (`--dump-ast` rc=0 and no "parse error") -- the semicolon form is committed as a
#            reviewed file, never normalised at grade time (CEO-570).
#   ORACLE   icont compiles OUR copy and the oracle's own binary reproduces the .ref byte for byte -- so the ref
#            we grade SCRIP against is the oracle's statement about THIS file, not our artifact (the two-bar
#            rule of test_gate_icon_vendored_sources_compile_under_icont).
#   SCRIP    m3 and m4 reproduce the .ref byte for byte (cmp, never `$(...)`: mandelbrot's ref is a P4 PBM
#            full of NUL bytes, and a capture would grade it wrong -- CFO-52 trap 2).
# A program named in OUTSIDE_ARIZONA_BASELINE.tsv beside the sources is OUTSIDE the graded set: it still owes
# GUARD and PARSE, and its CONTROL arm is that the oracle STILL dies with the `Run-time error NNN` the row
# quotes -- if the oracle now runs it, or dies differently, this gate REFUSES rather than keep a stale reason.
# Arguments come from `<name>.argv` (name<TAB>arg<TAB>arg, no quoting language, the corpus convention), stdin
# from `<name>.dat` if present. Every run is staged under mktemp; the tracked tree is never written.
# ⛔ NOT A BOARD: it grades the five kernels of one directory and prints no suite pass/total.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
GATE="$(basename "${BASH_SOURCE[0]}" .sh)"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ REFUSE(2) [$GATE]: lib_oracle_flags.sh unloadable"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2) [$GATE]: no scrip at $SCRIP"; exit 2; }
ICONT="$(icont_bin)" || exit 2
export IPATH="$(cd "$(dirname "$ICONT")/../lib" && pwd)"
DIR="$S4E/corpus/benchmarks/icon/shootout"
[ -d "$DIR" ] || { echo "⛔ REFUSE(2) [$GATE]: no $DIR"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cp -r "$DIR"/. "$T"/ || { echo "⛔ REFUSE(2) [$GATE]: could not stage $DIR"; exit 2; }
mapfile -t PROGS < <(cd "$T" && ls *.icn 2>/dev/null | sed 's/\.icn$//' | sort)
[ "${#PROGS[@]}" -gt 0 ] || { echo "⛔ REFUSE(2) [$GATE]: no .icn under $DIR -- graded nothing"; exit 2; }
OUTSIDE="$T/OUTSIDE_ARIZONA_BASELINE.tsv"
outside_row() { [ -f "$OUTSIDE" ] || return 1; awk -F'\t' -v n="$1" '!/^#/ && $1==n {print $2 "\t" $3; f=1} END {exit !f}' "$OUTSIDE"; }
if [ -f "$OUTSIDE" ]; then
  while IFS=$'\t' read -r nm _cls _rsn; do
    [ -z "$nm" ] || [ "${nm#\#}" != "$nm" ] && continue
    [ -f "$T/$nm.icn" ] || { echo "⛔ REFUSE(2) [$GATE]: OUTSIDE_ARIZONA_BASELINE.tsv names '$nm' and no such kernel is shipped -- a stale row cannot shrink anything"; exit 2; }
  done < "$OUTSIDE"
fi
args_of() { local f="$T/$1.argv"; ARGS=(); [ -f "$f" ] || return 0; local line; line=$(grep -v '^#' "$f" | awk -F'\t' -v n="$1" '$1==n' | head -1); [ -n "$line" ] || return 0; local F; IFS=$'\t' read -r -a F <<< "$line"; ARGS=("${F[@]:1}"); }
n_graded=0; n_ok=0; n_outside=0; RED=()
for p in "${PROGS[@]}"; do
  args_of "$p"; stdin_src=/dev/null; [ -f "$T/$p.dat" ] && stdin_src="$T/$p.dat"
  # GUARD
  if grep -qE '^\$(ifdef|ifndef|endif)\b' "$T/$p.icn"; then RED+=("$p GUARD: a \$ifdef guard still wraps the entry point"); fi
  grep -qE '^procedure main\b' "$T/$p.icn" || RED+=("$p GUARD: no top-level 'procedure main'")
  # PARSE
  ( cd "$T" && timeout -k 5 20 "$SCRIP" --dump-ast "$p.icn" </dev/null >/dev/null 2>"$T/$p.ast.err" ); prc=$?
  if [ "$prc" -ne 0 ] || grep -q 'parse error' "$T/$p.ast.err"; then RED+=("$p PARSE: $(grep -m1 'parse error' "$T/$p.ast.err" || echo "dump-ast rc=$prc")"); continue; fi
  # ORACLE compile (both graded and outside need the binary)
  ( cd "$T" && timeout -k 5 60 "$ICONT" -s -o "$p.oracle" "$p.icn" ) >"$T/$p.icont.err" 2>&1 || { RED+=("$p ORACLE: icont refuses our copy: $(head -1 "$T/$p.icont.err")"); continue; }
  if row=$(outside_row "$p"); then
    n_outside=$((n_outside+1)); cls="${row%%$'\t'*}"; rsn="${row#*$'\t'}"
    want=$(printf '%s' "$rsn" | grep -oE 'Run-time error [0-9]+' | head -1)
    [ -n "$want" ] || { echo "⛔ REFUSE(2) [$GATE]: the OUTSIDE row for $p quotes no 'Run-time error NNN' -- a reason that names no measurement cannot be re-asked"; exit 2; }
    ( cd "$T" && timeout -k 5 30 "./$p.oracle" "${ARGS[@]}" <"$stdin_src" >/dev/null 2>"$T/$p.oracle.err" ); orc=$?
    if [ "$orc" -eq 0 ] || ! grep -q "$want" "$T/$p.oracle.err"; then
      echo "⛔ REFUSE(2) [$GATE]: OUTSIDE row for $p says '$want' but the oracle now exits $orc with: $(grep -m1 'Run-time error' "$T/$p.oracle.err" || echo '(no run-time error)') -- re-grade the row"; exit 2; fi
    echo "  OUTSIDE $p [$cls]: oracle still says '$want' (control arm holds); GUARD and PARSE green"
    continue
  fi
  n_graded=$((n_graded+1))
  [ -f "$T/$p.ref" ] || { RED+=("$p REF: no $p.ref beside the kernel (CEO-567 clause 3)"); continue; }
  ( cd "$T" && timeout -k 5 30 "./$p.oracle" "${ARGS[@]}" <"$stdin_src" >"$T/$p.oracle.out" 2>"$T/$p.oracle.err" ); orc=$?
  cmp -s "$T/$p.ref" "$T/$p.oracle.out" || { RED+=("$p ORACLE: the oracle's own binary (rc=$orc) does not reproduce $p.ref -- the ref is not the oracle's statement about this file"); continue; }
  ok=1
  ( cd "$T" && timeout -k 5 30 "$SCRIP" "$p.icn" -- "${ARGS[@]}" <"$stdin_src" >"$T/$p.m3" 2>"$T/$p.m3.err" ); rc3=$?
  cmp -s "$T/$p.ref" "$T/$p.m3" || { RED+=("$p SCRIP m3 (rc=$rc3): $(cmp "$T/$p.ref" "$T/$p.m3" 2>&1 | head -1)"); ok=0; }
  if ( cd "$T" && timeout -k 5 60 "$SCRIP" --compile --out="$p.s" "$p.icn" </dev/null >/dev/null 2>"$T/$p.m4c.err" && gcc -no-pie "$p.s" -o "$p.bin" -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" >>"$T/$p.m4c.err" 2>&1 ); then
    ( cd "$T" && timeout -k 5 30 "./$p.bin" "${ARGS[@]}" <"$stdin_src" >"$T/$p.m4" 2>"$T/$p.m4.err" ); rc4=$?
    cmp -s "$T/$p.ref" "$T/$p.m4" || { RED+=("$p SCRIP m4 (rc=$rc4): $(cmp "$T/$p.ref" "$T/$p.m4" 2>&1 | head -1)"); ok=0; }
  else RED+=("$p SCRIP m4: would not compile or link: $(head -1 "$T/$p.m4c.err")"); ok=0; fi
  [ "$ok" = 1 ] && { n_ok=$((n_ok+1)); echo "  GRADED $p: ref $(wc -c < "$T/$p.ref") bytes, oracle and SCRIP m3+m4 byte-identical"; }
done
echo "-- $GATE: $((n_graded+n_outside)) kernels under benchmarks/icon/shootout -- graded $n_graded (green $n_ok), outside the Arizona baseline $n_outside --"
if [ "${#RED[@]}" -eq 0 ]; then echo "GATE PASS [$GATE]: every shootout kernel is guard-free, parses, and every graded one reproduces its oracle-cut ref in both modes"; exit 0; fi
printf '  ⛔ %s\n' "${RED[@]}"; echo "GATE FAIL [$GATE]: ${#RED[@]} red(s)"; exit 1
