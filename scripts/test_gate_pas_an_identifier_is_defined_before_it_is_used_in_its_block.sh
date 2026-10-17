#!/usr/bin/env bash
# test_gate_pas_an_identifier_is_defined_before_it_is_used_in_its_block.sh -- ISO 7185 6.2.2.9: the defining-point of an identifier shall
# precede all its applied occurrences; the scope of a declaration is its WHOLE block, so a use earlier in that block of a name the block
# defines later is a use before the defining-point, even when an enclosing block defines the same name
#
# MEASURED 2026-09-26 by hq_pascal, both modes, row pascal-every-suite-to-100-under-nonet-ceo-1266. PAT iso7185prt1917 (const one = one
# inside a procedure, with an outer one) and iso7185prt1915 (const two = one; one = 2) ran to rc 0. fpc -Miso ACCEPTS both (it leaves this
# undetected), so the refusal arms are graded by the clause, not by the oracle. The cure (parser only, inside the granted g_pas_scope --
# Lon's grant names 6.2.2.9 use-before-definition): every applied occurrence that resolves to a defining-point of an ENCLOSING block is
# recorded against the current block (constant, type and variable identifiers); a later definition of that name in the same block is
# 6.2.2.9. Record fields are exempt (their own scope), and so is the domain-type of a pointer-type (6.2.2.9's own exception).
#
# ARMS, both modes: refusals naming 6.2.2.9 -- (1) u17, const one = one; (2) u15, const two = one; one = 2; (3) utyp, type u = t; t = char.
# Legal, byte-identical to fpc -Miso -- (4) uptr, type pp = ^t; t = record .. end beside an outer t (the pointer-domain exception); (5) ufld,
# a record field n beside an earlier use of an outer const n. It FAILS on the parent (arms 1-3 run). FAIL_ONCE=1 corrupts arm ufld's ref.
# ⛔ NOT CURED HERE, measured: a local constant shadowing an outer one reads the OUTER value, and a local char variable shadowing a program
# integer x empties the program's x -- the flat per-kind tables are name-keyed, not scope-keyed.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >"$T/o" 2>"$T/e" ) || return $?
  ( cd "$T" && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not link"; return 99; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
printf 'program u17(output);\nconst one = 1;\nprocedure x;\nconst one = one;\nbegin\n  write(one)\nend;\nbegin\n  writeln(one)\nend.\n' > "$T/u17.pas"
printf 'program u15(output);\nconst one = 1;\nprocedure x;\nconst two = one;\n      one = 2;\nbegin\n  writeln(one, two)\nend;\nbegin\n  writeln(one)\nend.\n' > "$T/u15.pas"
printf 'program utyp(output);\ntype t = integer;\nprocedure p;\ntype u = t;\n     t = char;\nvar x: u;\nbegin\n  x := 1; writeln(x)\nend;\nbegin\n  p\nend.\n' > "$T/utyp.pas"
printf 'program uptr(output);\ntype t = integer;\nprocedure p;\ntype pp = ^t; t = record a: integer end;\nvar v: pp;\nbegin\n  new(v); v^.a := 7; writeln(v^.a)\nend;\nbegin\n  p\nend.\n' > "$T/uptr.pas"
printf 'program ufld(output);\nconst n = 3;\nprocedure p;\nconst k = n;\ntype r = record n: integer end;\nvar x: r;\nbegin\n  x.n := k + 1; writeln(x.n, k)\nend;\nbegin\n  p\nend.\n' > "$T/ufld.pas"
for p in u17 u15 utyp; do
  for m in m3 m4; do run $m $p; rc=$?
    if [ "$rc" != 0 ] && [ "$rc" != 99 ] && grep -q 'ISO 7185 6\.2\.2\.9 violation' "$T/e"; then echo "  arm $p $m: refused rc=$rc naming 6.2.2.9"
    else echo "  ⛔ arm $p $m FAILED: rc=$rc, want a refusal naming 6.2.2.9"; echo "      err : $(head -1 "$T/e" | cut -c1-160)"; RC=1; fi; done
done
for p in uptr ufld; do
  ( cd "$T" && "$FPC" -Miso -v0 -o$p.fpc $p.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $p"; exit 2; }
  ( cd "$T" && timeout -k 5 20s ./$p.fpc </dev/null >"$T/$p.want" 2>/dev/null ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso's $p did not run to rc 0"; exit 2; }
  [ -n "${FAIL_ONCE:-}" ] && [ $p = ufld ] && echo "corrupted by FAIL_ONCE" >> "$T/$p.want"
  for m in m3 m4; do run $m $p; rc=$?
    if [ "$rc" = 0 ] && cmp -s "$T/$p.want" "$T/o"; then echo "  arm $p $m: byte-identical to fpc -Miso"
    else echo "  ⛔ arm $p $m FAILED: rc=$rc"; echo "      want: $(od -c "$T/$p.want" | head -2 | tr -s ' ' | tr '\n' '|')"; echo "      got : $(od -c "$T/o" | head -2 | tr -s ' ' | tr '\n' '|')"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a use before the defining-point in its block is refused naming 6.2.2.9; the pointer-domain exception and record fields stay legal, both modes"
else echo "GATE FAIL(1) [$G]: examined 5 arms in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
