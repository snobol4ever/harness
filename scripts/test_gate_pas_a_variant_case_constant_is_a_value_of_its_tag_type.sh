#!/usr/bin/env bash
# test_gate_pas_a_variant_case_constant_is_a_value_of_its_tag_type.sh -- ISO 7185 6.4.3.3, refused at compile time
#
# MEASURED 2026-09-23 by hq_pascal on SCRIP 2441f7be7, both modes, row pascal-all-test-suites-of-the-language-read-100-percent-on-the-
# suite-table-the-home-stretch (class row pascal-pat-variant-record-active-tag-tracking). "The values denoted by all case-constants of
# a type that is required to be compatible with a given tag-type shall be distinct and the set thereof shall be equal to the set of
# values specified by the tag-type" (6.4.3.3). record_case_arm discarded its constants, so PAT iso7185prt1857 (tag-type two..four with
# an arm labelled five) compiled and ran. record_case_arm now yields its constant list and record_case_list collects them, threaded
# through yacc values with no new state; at record_case_opt a constant outside the tag-type, or one value named twice, is refused.
# The tag-type is checked when it resolves to Boolean, an enumerated type or a subrange of at most 4096 values; integer and char
# tag-types are left alone.
#
# ⭐ THE OTHER HALF OF THE SAME SENTENCE -- "equal to the set of values", a variant-part that OMITS a tag value (PAT iso7185prt1856)
# -- WAS HELD FOR A RULING AND IS NOW HERE: ceo CEO-1231 (2026-09-24), ISO wins. Measured before it landed, it refused exactly six
# acceptance programs, each now carrying empty arms for the values it omitted, behaviour unchanged: two rungs entries,
# program_record_array_replace_2 (blck) and program_record_packed_replace_1 (scalar, pointer), their outputs byte-identical under
# the oracle that cut their refs (fpc default mode for the first, whose enum write fpc -Miso cannot build; fpc -Miso for the second);
# Pascal-P4 comp.pas (expr, inxd, blck and rec -- PATCHES.md item 7, generation-1 listing, stderr and P-code byte-identical) and int.pas
# (undef -- item 8, emitted assembly byte-identical); and the P4-derived pcom.pas and pint.pas, with the same arms.
# Before landing, every acceptance program in the corpus (PasRungs, the FPC suite, P4, P5, the benchmarks, 456 programs) was compiled
# with the check: the refused set was identical to the tree before.
#
# ARMS: two vendored PAT witnesses (a value omitted, a value outside the tag-type), each required to be REFUSED with a non-empty diagnostic in BOTH modes (m4 compiles, and if the compile is
# accepted, links and runs). A second arm proves the check DISCRIMINATES: variant-parts over enumerated, Boolean and subrange tag-types,
# with a tag-field and without, with constant lists, run byte-identical to fpc -Miso in both modes. FAIL_ONCE=1 flips the witness.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- the control arm's ref is CUT FROM THE ORACLE"; exit 2; }
SRC="$S4E/corpus/packages/pascal/pat"
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
m4_run() { M4O=$( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/w.s" "$1" </dev/null 2>&1 ); M4RC=$?
  if [ "$M4RC" = 0 ]; then
    ( cd "$T" && cc -m64 -no-pie w.s -o w -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: $1 compiled but would not link -- cannot grade the m4 arm"; exit 2; }
    M4O=$( cd "$T" && timeout -k 5 20s ./w </dev/null 2>&1 ); M4RC=$?
  fi; }
for b in iso7185prt1856 iso7185prt1857; do
  f="$SRC/$b.pas"; [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing vendored witness $f"; exit 2; }
  N=$((N+1)); bad=""
  o3=$( cd "$T" && timeout -k 5 10s "$SCRIP" "$f" </dev/null 2>&1 ); rc3=$?
  if [ -n "${FAIL_ONCE:-}" ] && [ "$b" = iso7185prt1856 ]; then rc3=0; o3=""; fi
  { [ "$rc3" -ne 0 ] && [ "$rc3" -lt 124 ] && [ -n "$o3" ]; } || bad="m3 (rc=$rc3, ${#o3} bytes of diagnostic)"
  m4_run "$f"; o4="$M4O"; rc4=$M4RC
  { [ "$rc4" -ne 0 ] && [ "$rc4" -lt 124 ] && [ -n "$o4" ]; } || bad="$bad m4 (rc=$rc4, ${#o4} bytes of diagnostic)"
  if [ -n "$bad" ]; then echo "  $b ACCEPTED where ISO 7185 requires each case-constant to be a distinct value of the tag-type: $bad"; RC=1; else echo "  $b refused with a diagnostic in both modes"; fi
done
cat > "$T/ok.pas" <<'PAS'
program varctl(output);
type color = (red, green, blue, gray); warm = red..green;
     shape = record
               n: integer;
               case k: color of
                 red, gray: (i: integer);
                 green: (c: char);
                 blue: (b: boolean)
             end;
     flag = record case f: boolean of true: (x: integer); false: (y: char) end;
     part = record case w: warm of red: (p: integer); green: (q: integer) end;
     bare = record case color of red, green: (u: integer); blue, gray: (v: char) end;
var s: shape; t: flag; p: part; b: bare;
begin
  s.n := 1; s.k := green; s.c := 'z'; t.f := true; t.x := 5; p.w := green; p.q := 9; b.u := 4;
  writeln(s.n:1, ' ', ord(s.k):1, ' ', s.c, ' ', t.x:1, ' ', p.q:1, ' ', b.u:1)
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 ok.pas >/dev/null 2>&1 && ./ok ) > "$T/ok.ref" 2>&1
[ -s "$T/ok.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle produced no control-arm output"; exit 2; }
ok3=$( cd "$T" && timeout -k 5 20s "$SCRIP" --run ok.pas </dev/null 2>&1 ); m4_run "$T/ok.pas"; ok4="$M4O"
if [ "$ok3" = "$(cat "$T/ok.ref")" ] && [ "$ok4" = "$(cat "$T/ok.ref")" ]; then echo "  control arm: variant-parts over enumerated, Boolean and subrange tag-types run byte-identical to fpc -Miso in both modes"
else echo "  ⛔ control arm FAILED -- the check refuses or miscompiles a LEGAL program"; echo "      want: $(tr '\n' '|' < "$T/ok.ref")"; echo "      m3  : $(printf '%s' "$ok3" | tr '\n' '|')"; echo "      m4  : $(printf '%s' "$ok4" | tr '\n' '|')"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N variant-parts whose case-constants are not exactly the values of their tag-type refused with a NAMED diagnostic in both modes, and legal ones are untouched"
else echo "GATE FAIL(1) [$G]: examined $N vendored PAT witnesses plus one legal control"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
