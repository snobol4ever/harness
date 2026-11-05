#!/usr/bin/env bash
# test_gate_live_oracle_callers_ratchet.sh -- THE LIVE-ORACLE CALLERS RATCHET (CEO-2041; the cto's ruling of 2026-10-31 17:1x CDT on shared-dev step 8,
# ARCH-SHARED-DEVELOPMENT 3.4): every live oracle run goes through util_oracle.sh (one run slot before the clock, timeout -k 5, the SHA-keyed shared cache).
# audit_live_oracle_callers.py counts per script the lines that still name an oracle binary directly (an accessor of lib_oracle_flags.sh that util_oracle.sh
# serves, or a literal path to one); the count per file may only fall, and a fall lowers audit_live_oracle_callers.baseline.tsv in the same landing (--update).
# EXEMPT, named in the audit: util_oracle.sh, monitor_run.sh (the monitor bracket runs the oracle live), lib_oracle_flags.sh, oracle_gprolog.sh, oracle_gplc.sh,
# util_toolchain_preflight.sh (it proves the binary itself runs; a cached answer would hide a broken one).
# NO BINARY IS READ OR RUN: a census of source text.
#
# ARMS:
#   1 the census's own selftest: each counted form counted, the comment, echo, docstring, look-alike, bench oracle, util_oracle.sh call and bare name refused
#   2 the real tree reads the baseline: no file rose and no new file appeared
#   3 FAIL-ONCE BUILT IN (CEO-1680): a scratch copy of a real script (the first shell script the baseline counts) with ONE direct oracle call added reads RED (ROSE), a scratch new script with one reads RED
#     (NEW FILE), the same copy unplanted reads GREEN, and the plant inside a copy named monitor_run.sh (exempt) reads GREEN -- the red comes from the plant
#   4 --update only lowers: a scratch baseline below the real count makes --update refuse rc 1 and leaves the file unchanged
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
C="$HERE/audit_live_oracle_callers.py"; B="$HERE/audit_live_oracle_callers.baseline.tsv"
for f in "$C" "$B"; do [ -s "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing $f"; exit 2; }; done
command -v python3 >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: python3 absent"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
if python3 -I "$C" --selftest > "$T/self.txt" 2>&1; then echo "  arm 1 PASS: $(tail -1 "$T/self.txt" | cut -c1-140)"; else echo "  arm 1 FAIL: the census selftest reds -- $(grep -m1 FAIL "$T/self.txt" | cut -c1-200)"; RC=1; fi
python3 -I "$C" --dir "$HERE" --baseline "$B" --check --top 0 > "$T/real.txt" 2>&1; r=$?
if [ $r -eq 0 ]; then echo "  arm 2 PASS: $(grep -m1 '^CHECK' "$T/real.txt" | cut -c1-160)"; else echo "  arm 2 FAIL: rc=$r"; grep -E '^(RED|CHECK|REFUSE)' "$T/real.txt" | head -8 | cut -c1-200; RC=1; fi
PN=$(awk -F'\t' 'NR>1 && $1 ~ /\.sh$/ && $2>0 {print $1; exit}' "$B"); pb=$(awk -F'\t' -v f="$PN" '$1==f {print $2}' "$B"); P="$HERE/$PN"
[ -n "$PN" ] && [ -s "$P" ] || { echo "⛔ GATE REFUSE(2) [$G]: no shell script with a counted site in the baseline to plant a copy of"; exit 2; }
mkdir -p "$T/s1" "$T/s2" "$T/s3" "$T/s4"
cp "$P" "$T/s1/$PN"; cp "$P" "$T/s3/$PN"; cp "$P" "$T/s4/$PN"
printf '%s\n' 'timeout -k 5 60 "$(swipl_bin)" -q -g main -t halt probe.pl < /dev/null' >> "$T/s1/$PN"
printf '%s\n' 'timeout -k 5 60 "$(swipl_bin)" -q -g main -t halt probe.pl < /dev/null' > "$T/s2/zz_probe_oracle.sh"
printf '%s\n' 'timeout -k 5 60 "$(swipl_bin)" -q -g main -t halt probe.pl < /dev/null' > "$T/s4/monitor_run.sh"
python3 -I "$C" --dir "$T/s1" --baseline "$B" --check --top 0 > "$T/s1.txt" 2>&1; r1=$?
python3 -I "$C" --dir "$T/s2" --baseline "$B" --check --top 0 > "$T/s2.txt" 2>&1; r2=$?
python3 -I "$C" --dir "$T/s3" --baseline "$B" --check --top 0 > "$T/s3.txt" 2>&1; r3=$?
python3 -I "$C" --dir "$T/s4" --baseline "$B" --check --top 0 > "$T/s4.txt" 2>&1; r4=$?
if [ $r1 -eq 1 ] && grep -qF "RED: ROSE $PN ($pb -> $((pb + 1)))" "$T/s1.txt" && [ $r2 -eq 1 ] && grep -q '^RED: NEW FILE zz_probe_oracle.sh' "$T/s2.txt" \
   && [ $r3 -eq 0 ] && [ $r4 -eq 0 ]; then
  echo "  arm 3 PASS: one direct swipl_bin call added to a copy of $PN reads ROSE $pb -> $((pb + 1)) (rc 1), in a new script NEW FILE (rc 1), the unplanted copy GREEN, the plant in an exempt monitor_run.sh GREEN"
else echo "  arm 3 FAIL: planted rc=$r1 new-file rc=$r2 unplanted rc=$r3 exempt rc=$r4"; grep -hE '^(RED|REFUSE)' "$T"/s[1-4].txt | head -4 | cut -c1-200; RC=1; fi
top=$(awk -F'\t' 'NR>1 && $2>1 {print $1; exit}' "$B")
awk -v f="$top" 'BEGIN{FS=OFS="\t"} NR>1 && $1==f {$2=$2-1} {print}' "$B" > "$T/low.tsv"; cp "$T/low.tsv" "$T/low.before"
python3 -I "$C" --dir "$HERE" --baseline "$T/low.tsv" --update --top 0 > "$T/up.txt" 2>&1; ru=$?
if [ -n "$top" ] && [ $ru -eq 1 ] && cmp -s "$T/low.tsv" "$T/low.before" && grep -q "REFUSE(1): $top rose" "$T/up.txt"; then
  echo "  arm 4 PASS: --update refuses to raise $top (rc 1) and leaves the baseline unchanged"
else echo "  arm 4 FAIL: --update rc=$ru top='$top'"; RC=1; fi
if [ $RC -eq 0 ]; then echo "LIVE_ORACLE_CALLERS_BOARD $(grep -m1 '^CHECK' "$T/real.txt" | cut -c8-120) (tree $(git -C "$HERE" rev-parse --short HEAD 2>/dev/null)) GATE OK [$G]"; exit 0; fi
echo "LIVE_ORACLE_CALLERS_BOARD (tree $(git -C "$HERE" rev-parse --short HEAD 2>/dev/null)) GATE FAIL [$G]: see the arms above"; exit 1
