#!/usr/bin/env bash
# test_gate_nul_dependent_string_reads_ratchet.sh -- THE NUL-DEPENDENT-READ RATCHET: the population of C reads that stop at the first NUL of a descriptor's string
# (strlen, strcmp, strncmp, strchr, strstr, strcpy, strdup, ct_strdup, atoi and the strto family, puts and fputs, a printf-family %s) in src/runtime, src/driver,
# src/emitter and src/parsers may only fall, and a fall lowers the baseline in the same landing (the brief line "No strlen on a descriptor's .s"; CTO-397 relayed by
# the ceo 2026-10-29; row runtime-audit-nul-dependent-string-reads-..., hq_runtime). A descriptor string carries its length and may hold a NUL byte (a SNOBOL4 string,
# a Prolog atom, an Icon string); such a read silently truncates it.
# THE POPULATION is audit_nul_dependent_string_reads.py's sites per file against audit_nul_dependent_string_reads.baseline.tsv. NO BINARY IS READ: a census of source text.
#
# ARMS:
#   1 the census's own selftest: every declared form is counted, and the comment, the include, the string literal, the length field, the indexed member and the
#     look-alike function are each refused
#   2 the real tree reads the baseline: no file rose and no new file appeared
#   3 FAIL-ONCE BUILT IN: a scratch copy of a real file with ONE strlen of a .s added reads RED (ROSE), a scratch new file with one reads RED (NEW FILE), and the same
#     copy unplanted reads GREEN -- the red comes from the plant
#   4 --update only lowers: a scratch baseline below the real count makes --update refuse rc 1 and leaves the file unchanged
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP"; exit 2; }
C="$HERE/audit_nul_dependent_string_reads.py"; B="$HERE/audit_nul_dependent_string_reads.baseline.tsv"
for f in "$C" "$B"; do [ -s "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing $f"; exit 2; }; done
command -v python3 >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: python3 absent"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
if python3 -I "$C" --selftest > "$T/self.txt" 2>&1; then echo "  arm 1 PASS: $(tail -1 "$T/self.txt" | cut -c1-140)"; else echo "  arm 1 FAIL: the census selftest reds -- $(grep -m1 FAIL "$T/self.txt" | cut -c1-200)"; RC=1; fi
python3 -I "$C" --src "$ROOT/src" --baseline "$B" --check --top 3 > "$T/real.txt" 2>&1; r=$?
if [ $r -eq 0 ]; then echo "  arm 2 PASS: $(grep -m1 '^CHECK' "$T/real.txt" | cut -c1-140)"; else echo "  arm 2 FAIL: rc=$r"; grep -E '^(RED|CHECK|REFUSE)' "$T/real.txt" | head -6 | cut -c1-200; RC=1; fi
mkdir -p "$T/s1/runtime" "$T/s2/runtime" "$T/s3/runtime"
cp "$ROOT/src/runtime/arithmetic.c" "$T/s1/runtime/arithmetic.c"; cp "$ROOT/src/runtime/arithmetic.c" "$T/s3/runtime/arithmetic.c"
printf 'static long probe_nul(DESCR_t d) { return (long)strlen(d.s); }\n' >> "$T/s1/runtime/arithmetic.c"
printf 'static long probe_nul(DESCR_t d) { return (long)strlen(d.s); }\n' > "$T/s2/runtime/zz_probe_nul.c"
python3 -I "$C" --src "$T/s1" --baseline "$B" --check --top 1 > "$T/s1.txt" 2>&1; r1=$?
python3 -I "$C" --src "$T/s2" --baseline "$B" --check --top 1 > "$T/s2.txt" 2>&1; r2=$?
python3 -I "$C" --src "$T/s3" --baseline "$B" --check --top 1 > "$T/s3.txt" 2>&1; r3=$?
if [ $r1 -eq 1 ] && grep -q '^RED: ROSE runtime/arithmetic.c' "$T/s1.txt" && [ $r2 -eq 1 ] && grep -q '^RED: NEW FILE runtime/zz_probe_nul.c' "$T/s2.txt" && [ $r3 -eq 0 ]; then
  echo "  arm 3 PASS: a strlen of a .s added to a copy of arithmetic.c reads ROSE (rc 1), in a new file NEW FILE (rc 1), the unplanted copy GREEN (rc 0)"
else echo "  arm 3 FAIL: planted-in-copy rc=$r1 new-file rc=$r2 unplanted rc=$r3"; RC=1; fi
awk 'BEGIN{FS=OFS="\t"} NR==1{print;next} $1=="driver/scrip.c"{$2=$2-1} {print}' "$B" > "$T/low.tsv"; cp "$T/low.tsv" "$T/low.before"
python3 -I "$C" --src "$ROOT/src" --baseline "$T/low.tsv" --update > "$T/up.txt" 2>&1; ru=$?
if [ $ru -eq 1 ] && cmp -s "$T/low.tsv" "$T/low.before" && grep -q 'REFUSE(1): driver/scrip.c rose' "$T/up.txt"; then echo "  arm 4 PASS: --update refuses to raise a file (rc 1) and leaves the baseline unchanged"
else echo "  arm 4 FAIL: --update rc=$ru"; RC=1; fi
if [ $RC -eq 0 ]; then echo "GATE PASS(0) [$G]: NUL-dependent reads of a descriptor's string read the baseline ($(grep -m1 '^CHECK' "$T/real.txt" | cut -c1-80)); a planted strlen of a .s reds"; exit 0; fi
echo "GATE FAIL(1) [$G]: see the arms above"; exit 1
