#!/usr/bin/env bash
# test_gate_pas_only_the_tree_crosses_from_the_parser_to_lower.sh -- the Pascal lowerer takes nothing from the Pascal parser but
# the tree: no symbol the parser's objects define is referenced by lower_pascal.o, and none the lowerer defines is referenced by the
# parser (Lon 2026-09-27, relayed by hq_snocone, ruled by the ceo at CEO-1322: "Ensure that only the tree_t gets sent/used by parser
# stage to the lower stage. All global structures needed at runtime, are built in the lower stage."; RULES.md ONLY tree_t CROSSES
# FROM A PARSER TO THE LOWER STAGE; row pascal-only-tree-t-crosses-from-the-pascal-parser-to-lower-the-nested-record-index-side-table)
#
# MEASURED 2026-09-27 by hq_pascal. hq_snocone's link-level audit (findings/FINDING-2026-09-27-hq_snocone-only-tree-t-crosses-...)
# found Pascal failing once: pas_is_nrec_idx(e) answered from g_pas_nrec_marks[512], a parser side table of NODE ADDRESSES with a
# fixed cap, and lower_pascal.c asked it at the assignment and index arms. THE CURE: the parser writes the fact on the node itself
# (tree_t.slen = PAS_NREC_IDX_MARK on the TT_IDX it builds) and pas_node_nrec_marked, a static inline in pascal_driver.h, reads only
# the node; the table is deleted, and lower_pascal.c's dead extern of the parser's pas_is_agg_local goes with it.
#
# ARMS: (1) link -- nm over the linked objects of this tree: the lowerer's objects (one per src/lower/lower_pascal*.c) reference no
# symbol defined in the parser's objects (one per src/parsers/pascal/*.c), and those reference none the lowerer's define (the audit's
# arms A and C for one language). RE-CUT 2026-10-14 by hq_pascal (CEO-1697): SCRIP 1889d257e moved the semantic front end into the
# lowerer and deleted pascal_sem.c, and this arm still named pascal_sem.o -- it REFUSED where the objdir was clean and graded an Oct 9
# leftover where it was not. Both object sets are now read from the sources on disk, and an object older than its source refuses;
# (2) nrec -- a record's array field indexed through a record variable and two pointers, both modes, stdout and exit code
# cut LIVE from fpc -Miso: the nested-record-index path the side table used to steer. OPEN, NOT GRADED HERE: an array field of a
# record nested in a record VARIABLE (o.i.a[3] := 42) stops with a 6.5.3.2 index error on this tree and its parent alike -- the
# variable is initialised as a two-slot string and the inner record's fields are never built; and inside with p^ do, a[1] reads
# the character code of the field's string form (50 for 2) -- both on the parent alike, rows of their own.
# Arm (1) FAILS on the parent b6b9308ba (lower_pascal.o references the parser's pas_is_nrec_idx); arm (2) is the behaviour the cure
# must keep, green on both. FAIL_ONCE=1 corrupts arm (2)'s ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- arm (2)'s expectation is CUT FROM THE ORACLE"; exit 2; }
command -v nm >/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: no nm -- arm (1) reads the linked objects' symbol tables"; exit 2; }
declare -A SRC
OBJD="${PAS_GATE_OBJDIR:-$ROOT/$(make -s -C "$ROOT" -f Makefile -f <(printf 'gate_objdir:\n\t@echo $(RT_OBJDIR)\n') gate_objdir 2>/dev/null | tail -1)}"
LOWER=(); PARSER=()
for c in "$ROOT"/src/lower/lower_pascal*.c; do LOWER+=("$OBJD/$(basename "${c%.c}").o"); SRC["$OBJD/$(basename "${c%.c}").o"]="$c"; done
for c in "$ROOT"/src/parsers/pascal/*.c; do PARSER+=("$OBJD/$(basename "${c%.c}").o"); SRC["$OBJD/$(basename "${c%.c}").o"]="$c"; done
[ "${#LOWER[@]}" -gt 0 ] && [ "${#PARSER[@]}" -gt 0 ] || { echo "⛔ GATE REFUSE(2) [$G]: found ${#LOWER[@]} lowerer and ${#PARSER[@]} parser sources"; exit 2; }
for o in "${LOWER[@]}" "${PARSER[@]}"; do [ -f "$o" ] || { echo "⛔ GATE REFUSE(2) [$G]: no object $o -- build first (make)"; exit 2; }
  [ "${SRC[$o]}" -nt "$o" ] && { echo "⛔ GATE REFUSE(2) [$G]: $o is older than ${SRC[$o]} -- build first (make)"; exit 2; }; done
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
defined() { nm --defined-only "$@" 2>/dev/null | awk 'NF >= 3 && $2 ~ /^[TDBRCVWG]$/ {print $3}' | sort -u; }
undefd() { nm -u "$@" 2>/dev/null | awk '{print $NF}' | sort -u; }
comm -12 <(undefd "${LOWER[@]}") <(defined "${PARSER[@]}") > "$T/lower_asks_parser"
comm -12 <(undefd "${PARSER[@]}") <(defined "${LOWER[@]}") > "$T/parser_asks_lower"
N=$((N + 1))
if [ -s "$T/lower_asks_parser" ] || [ -s "$T/parser_asks_lower" ]; then
  echo "  ⛔ link FAILED: the lowerer references the parser's $(tr '\n' ' ' < "$T/lower_asks_parser")| the parser references the lowerer's $(tr '\n' ' ' < "$T/parser_asks_lower")"; RC=1
else echo "  link: the lowerer's ${#LOWER[@]} objects reference no symbol of the Pascal parser's ${#PARSER[@]}, and they reference none of theirs ($OBJD)"; fi
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile and link"; return 125; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/nrec.pas" <<'PAS'
program nrec(output);
type arr = array [1..5] of integer;
     inner = record k: integer; a: arr end;
     pr = ^inner;
var r: inner; p, q: pr; j, s: integer;
begin
  for j := 1 to 5 do r.a[j] := j * j; r.k := 7;
  new(p); for j := 1 to 5 do p^.a[j] := r.a[j] + 1;
  writeln(r.a[2]:1, ' ', p^.a[5]:1, ' ', r.k:1);
  p^.a[2] := p^.a[2] * 10; writeln(p^.a[2]:1);
  s := 0; for j := 1 to 5 do s := s + p^.a[j] + r.a[j]; writeln(s:1);
  p^.a[4] := p^.a[1] + p^.a[3]; r.a[5] := r.k * 6; writeln(p^.a[4]:1, ' ', r.a[5]:1);
  new(q); q^.a[1] := p^.a[4] - r.a[1]; q^.a[q^.a[1] - 10] := r.a[r.a[1] + 1]; writeln(q^.a[1]:1, ' ', q^.a[1]:1)
end.
PAS
frc=$(fpcrun nrec)
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/nrec.want"; fi
for m in m3 m4; do run $m nrec; rc=$?; N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/nrec.want" "$T/o"; then echo "  nrec $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ nrec $m FAILED: rc=$rc (fpc $frc)"; diff "$T/nrec.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: only the tree crosses from the Pascal parser to lower_pascal, and the nested-record index still reads as fpc -Miso does, $N of $N arms"
else echo "GATE FAIL(1) [$G]: examined the link arm and one program in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
