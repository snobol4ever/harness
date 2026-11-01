#!/usr/bin/env bash
# util_template_ab_identity.sh -- THE IDENTITY A/B THAT STORES NOTHING (the cto, 2026-11-01, templates-zero; the lesson of CEO-1902 and of
# today's second flood: an A/B that keeps every program's .s on both sides is 2.7 GB a sweep of 186 programs, and seven sweeps of the cto's
# live session held 19.5 GB when /tmp passed 85 percent. A door, not discipline: this instrument cannot keep a population.)
#
# WHAT IT PROVES: a template landing is emission-identical to its parent. Each program is compiled in text mode (--compile) under the A root
# and the B root into ONE scratch pair; the pair's normalised text (.cpp:N and .c:N line tags) is hashed and the pair is deleted at once.
# A text difference is assembled (as) on both sides and the two objects compared byte for byte, then per allocated section (a kind or box
# rename moves label spellings and gc-site numbers, never bytes: templates-zero 6a and 6b were graded so), then deleted too. Nothing of a
# program outlives its own comparison; the scratch dir is one pair wide and goes on EXIT.
#
# USE (from any root; A and B are SCRIP roots with a built ./scrip; each compile takes a run slot through util_run_slot.sh, niced):
#   bash harness/scripts/util_template_ab_identity.sh A_ROOT B_ROOT --population            # every committed benchmark and demo source
#   bash harness/scripts/util_template_ab_identity.sh A_ROOT B_ROOT --population --step N   # plus step N's witnesses of templates_zero/STEPS.tsv
#   bash harness/scripts/util_template_ab_identity.sh A_ROOT B_ROOT --list FILE             # one source path per line
#   bash harness/scripts/util_template_ab_identity.sh A_ROOT B_ROOT prog.sno prog2.icn ...  # named programs
# BOARD: AB_IDENTITY_BOARD text_same=<n> bytes_same=<n> diff=<n> fail=<n> of <total> a=<sha> b=<sha>
#   BYTES_SAME <prog>                      the text differed, the assembled objects did not
#   DIFF <prog> sections:<list> rela=<n>   a real emission change (the sections and relocation lines that differ)
#   FAIL <prog> rc=<a>/<b>                 a side did not compile (the log's last line follows)
# rc 0 every program identical in text or bytes; 1 a DIFF or a FAIL; 2 refused (no ./scrip under a root, empty population, a missing tool).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
[ $# -ge 2 ] || { echo "REFUSE(2): usage: $0 A_ROOT B_ROOT [--population] [--step N] [--list FILE] [prog...]"; exit 2; }
A="$(cd "$1" 2>/dev/null && pwd)" || { echo "REFUSE(2): no A root $1"; exit 2; }
B="$(cd "$2" 2>/dev/null && pwd)" || { echo "REFUSE(2): no B root $2"; exit 2; }
shift 2
[ -x "$A/scrip" ] && [ -x "$B/scrip" ] || { echo "REFUSE(2): ./scrip missing under $A or $B (make first)"; exit 2; }
for t in as readelf objcopy cmp sha256sum; do command -v "$t" >/dev/null 2>&1 || { echo "REFUSE(2): no $t on PATH"; exit 2; }; done
POP=0; STEP=""; LIST=""; PROGS=()
while [ $# -gt 0 ]; do case "$1" in
  --population) POP=1;; --step) STEP="$2"; shift;; --list) LIST="$2"; shift;;
  -*) echo "REFUSE(2): unknown argument $1"; exit 2;; *) PROGS+=("$1");; esac; shift; done
W="$(mktemp -d "${TMPDIR:-/tmp}/ab_identity.XXXXXX")" || { echo "REFUSE(2): no scratch dir"; exit 2; }
trap 'rm -rf "$W"' EXIT
LISTF="$W/list"; : > "$LISTF"
if [ "$POP" = 1 ]; then
  find "$ROOT/corpus/benchmarks" "$ROOT/corpus/demos" -type f \( -name '*.sno' -o -name '*.icn' -o -name '*.pl' -o -name '*.pas' -o -name '*.raku' \) 2>/dev/null | sort >> "$LISTF"
fi
if [ -n "$STEP" ]; then
  STEPS="$ROOT/corpus/tests/shared/templates_zero/STEPS.tsv"
  [ -f "$STEPS" ] || { echo "REFUSE(2): no $STEPS"; exit 2; }
  mkdir -p "$W/wit"
  wits="$(awk -F'\t' -v s="$STEP" '!/^#/ && $1 == s {print $6}' "$STEPS")"
  [ -n "$wits" ] || { echo "REFUSE(2): step $STEP has no witnesses in STEPS.tsv"; exit 2; }
  for lw in $wits; do
    lang="${lw%%:*}"; ent="${lw#*:}"
    case "$lang" in snobol4) ext=sno;; icon) ext=icn;; prolog) ext=pl;; pascal) ext=pas;; raku) ext=raku;; snocone) ext=sc;; rebus) ext=reb;; *) echo "REFUSE(2): unknown witness language $lang"; exit 2;; esac
    python3 "$HERE/corpus_suite_harness.py" extract "$ROOT/corpus/tests/$lang/ALL.$ext" "$ROOT/corpus/tests/$lang/ALL.ref" "$ent" "$W/wit/$ent.$ext" >/dev/null 2>&1 \
      || { echo "REFUSE(2): cannot extract witness $lw"; exit 2; }
    echo "$W/wit/$ent.$ext" >> "$LISTF"
  done
fi
[ -n "$LIST" ] && { [ -f "$LIST" ] || { echo "REFUSE(2): no list $LIST"; exit 2; }; grep -v '^\s*$' "$LIST" >> "$LISTF"; }
for p in "${PROGS[@]:-}"; do [ -n "$p" ] && echo "$p" >> "$LISTF"; done
total=$(wc -l < "$LISTF"); [ "$total" -gt 0 ] || { echo "REFUSE(2): the population is empty"; exit 2; }
norm() { sed -E 's/\.cpp:[0-9]+/.cpp:N/g; s/\.c:[0-9]+/.c:N/g' "$1" | sha256sum | cut -c1-16; }
compile() { ( cd "$2" && nice -n 19 bash "$HERE/util_run_slot.sh" timeout -k 5 300 "$1/scrip" --compile --out="$3" "$4" < /dev/null > "$5" 2>&1 ); }
text_same=0; bytes_same=0; diffn=0; fail=0; rc=0
while IFS= read -r p; do
  [ -n "$p" ] || continue
  b="$(basename "$p")"; d="$(cd "$(dirname "$p")" 2>/dev/null && pwd)" || { echo "FAIL $b rc=nodir"; fail=$((fail+1)); rc=1; continue; }
  compile "$A" "$d" "$W/a.s" "$b" "$W/a.log"; ra=$?
  compile "$B" "$d" "$W/b.s" "$b" "$W/b.log"; rb=$?
  if [ $ra != 0 ] || [ $rb != 0 ]; then echo "FAIL $b rc=$ra/$rb  $(tail -1 "$W/a.log" "$W/b.log" 2>/dev/null | tr '\n' ' ' | cut -c1-160)"; fail=$((fail+1)); rc=1; rm -f "$W"/a.* "$W"/b.*; continue; fi
  if [ "$(norm "$W/a.s")" = "$(norm "$W/b.s")" ]; then text_same=$((text_same+1)); rm -f "$W"/a.* "$W"/b.*; continue; fi
  if as -o "$W/a.o" "$W/a.s" 2>/dev/null && as -o "$W/b.o" "$W/b.s" 2>/dev/null && cmp -s "$W/a.o" "$W/b.o"; then
    echo "BYTES_SAME $b"; bytes_same=$((bytes_same+1)); rm -f "$W"/a.* "$W"/b.*; continue; fi
  bad=""
  for s in $(readelf -S -W "$W/a.o" 2>/dev/null | awk '/^ *\[ *[0-9]+\]/ {print $2}' | grep '^\.' | grep -v -E '^\.(symtab|strtab|shstrtab|rela|note\.GNU-stack)' | sort -u); do
    objcopy -O binary -j "$s" "$W/a.o" "$W/a.sec" 2>/dev/null; objcopy -O binary -j "$s" "$W/b.o" "$W/b.sec" 2>/dev/null
    cmp -s "$W/a.sec" "$W/b.sec" || bad="$bad$s,"
  done
  rela=$(diff <(readelf -r -W "$W/a.o" 2>/dev/null | awk '{print $3, $4, $5, $6}') <(readelf -r -W "$W/b.o" 2>/dev/null | awk '{print $3, $4, $5, $6}') | grep -c '^[<>]')
  if [ -z "$bad" ] && [ "$rela" = 0 ] && [ -s "$W/a.o" ]; then echo "BYTES_SAME $b (outside the allocated sections only)"; bytes_same=$((bytes_same+1))
  else echo "DIFF $b sections:${bad:-none} rela=$rela"; diffn=$((diffn+1)); rc=1; fi
  rm -f "$W"/a.* "$W"/b.*
done < "$LISTF"
echo "AB_IDENTITY_BOARD text_same=$text_same bytes_same=$bytes_same diff=$diffn fail=$fail of $total a=$(git -C "$A" rev-parse --short HEAD 2>/dev/null || echo ?) b=$(git -C "$B" rev-parse --short HEAD 2>/dev/null || echo ?)"
exit $rc
