#!/usr/bin/env bash
# test_gate_pas_a_declared_label_prefixes_exactly_one_statement_of_its_block.sh -- ISO 7185 6.2.1: a block closest-containing a
# label-declaration-part in which a label occurs shall closest-contain exactly one statement in which that label occurs; 6.2.2.1: each label
# contained by the program-block shall have a defining-point
#
# MEASURED 2026-09-26 by hq_pascal, both modes, row pascal-every-suite-to-100-under-nonet-ceo-1266. PAT iso7185prt1836 declares label 1
# and prefixes no statement with it; scrip ran it to rc 0, fpc -Miso refuses it (warning "Label not defined", then an error). NO BRACKET:
# a static refusal sends no event. The cure: g_pas_scope keeps a per-block label list (lab/nlab/clab, PasDef reused, formal = the count of
# statements the label prefixes); label_list declares, the labelled-statement rule counts a prefix only when the label's block is the
# current one, a goto or a prefix naming no declared label is 6.2.2.1, and the block rule closes its own labels: a count other than one
# is 6.2.1. PAT 1837 (goto an undeclared label) and 1845 (a label of the program prefixing a statement of a procedure) were refused before
# for a different reason (the lowerer's goto check); they now name the clause their header states.
#
# ARMS, both modes: (1) lunused -- declared, prefixes nothing; (2) ltwice -- prefixes two statements; (3) linner -- declared in the program,
# prefixing a statement of a procedure; (4) lundecl -- a goto to, and a prefix by, a label no block declares. Each must be refused by scrip
# (rc non-zero, stderr names the clause) AND by fpc -Miso (its own compile error). (5) lok -- a procedure's own label, a goto from it to a
# program label (6.8.2.4 non-local), the label 02 spelled with a leading zero, and 9999 -- must run byte-identical to fpc -Miso. It FAILS on
# the parent (arms 1-2 run to rc 0; arms 3-4 name 6.8.1). FAIL_ONCE=1 corrupts arm 5's ref to prove it can fail.
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
printf 'program lunused(output);\nlabel 1;\nvar i: integer;\nbegin\n  i := 1; writeln(i)\nend.\n' > "$T/lunused.pas"
printf 'program ltwice(output);\nlabel 1;\nvar i: integer;\nbegin\n  i := 1;\n  1: writeln(i);\n  1: writeln(i)\nend.\n' > "$T/ltwice.pas"
printf 'program linner(output);\nlabel 1;\nprocedure a;\nbegin\n  goto 1;\n  1: writeln(1)\nend;\nbegin\n  a\nend.\n' > "$T/linner.pas"
printf 'program lundecl(output);\nvar i: integer;\nbegin\n  i := 1;\n  goto 1;\n  1: writeln(i)\nend.\n' > "$T/lundecl.pas"
printf 'program lok(output);\nlabel 02, 9999;\nvar i: integer;\nprocedure p;\nlabel 1;\nbegin\n  i := i + 1;\n  if i < 3 then goto 1;\n  writeln(%s);\n  goto 9999;\n  1: writeln(%s, i)\nend;\nbegin\n  i := 0;\n  2: p;\n  if i < 5 then goto 2;\n  writeln(%s);\n  9999: writeln(%s, i)\nend.\n' "'late'" "'inner '" "'never'" "'done '" > "$T/lok.pas"
for pc in lunused:6.2.1 ltwice:6.2.1 linner:6.2.1 lundecl:6.2.2.1; do p=${pc%%:*}; c=${pc#*:}
  ( cd "$T" && "$FPC" -Miso -v0 -o"$p.fpc" $p.pas >/dev/null 2>&1 ) && { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso now ACCEPTS arm $p -- re-cut it"; exit 2; }
  for m in m3 m4; do run $m $p; rc=$?
    if [ "$rc" != 0 ] && [ "$rc" != 99 ] && grep -q "ISO 7185 ${c//./\\.} violation" "$T/e"; then echo "  arm $p $m: refused rc=$rc naming $c, as fpc -Miso refuses it"
    else echo "  ⛔ arm $p $m FAILED: rc=$rc, want a refusal naming $c"; echo "      err : $(head -1 "$T/e" | cut -c1-160)"; RC=1; fi; done
done
p=lok
( cd "$T" && "$FPC" -Miso -v0 -o$p.fpc $p.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $p"; exit 2; }
( cd "$T" && timeout -k 5 20s ./$p.fpc </dev/null >"$T/$p.want" 2>/dev/null ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso's $p did not run to rc 0"; exit 2; }
[ -n "${FAIL_ONCE:-}" ] && echo "corrupted by FAIL_ONCE" >> "$T/$p.want"
for m in m3 m4; do run $m $p; rc=$?
  if [ "$rc" = 0 ] && cmp -s "$T/$p.want" "$T/o"; then echo "  arm $p $m: byte-identical to fpc -Miso"
  else echo "  ⛔ arm $p $m FAILED: rc=$rc"; echo "      want: $(tr '\n' '|' < "$T/$p.want")"; echo "      got : $(tr '\n' '|' < "$T/o")"; RC=1; fi; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: every declared label prefixes exactly one statement of its own block, an undeclared label is refused, both modes"
else echo "GATE FAIL(1) [$G]: examined 5 arms in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
