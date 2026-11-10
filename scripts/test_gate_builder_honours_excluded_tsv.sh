#!/usr/bin/env bash
# GATE test_gate_builder_honours_excluded_tsv (CIO-19): a package's EXCLUDED.tsv is honoured by the builder on every oracle road.
# Scratch package: a.sno (OUTPUT = 'a' END) absorbed, b.sno named by EXCLUDED.tsv with class PROBE_CLASS and not absorbed.
# rc 0 GREEN, rc 1 RED (the failing check is named), rc 2 REFUSE (the builder or the oracle cannot run here).
S="${S4E_HOME:?REFUSE(2): S4E_HOME unset}"
command -v python3 >/dev/null 2>&1 || { echo "REFUSE(2): python3 is not installed"; exit 2; }
B="$S/harness/scripts/util_build_package_suite.py"
M="$S/harness/scripts/util_mem_scope.py"
[ -f "$B" ] || { echo "REFUSE(2): no builder at $B"; exit 2; }
[ -f "$M" ] || { echo "REFUSE(2): no memory scope at $M"; exit 2; }
D="/tmp/s4e/${S4E_SEAT:-junior_05}/gate_excl_$$"
rm -rf "$D" && mkdir -p "$D" || { echo "REFUSE(2): cannot make scratch $D"; exit 2; }
printf "      OUTPUT = 'a'\nEND\n" > "$D/a.sno"
printf "      OUTPUT = 'b'\nEND\n" > "$D/b.sno"
printf "b.sno\tPROBE_CLASS\tgate probe: the builder must not absorb this program\n" > "$D/EXCLUDED.tsv"
S4E_PROGRESS_OFF=1 timeout -k 10 900 python3 -I "$M" supervise --kind board -- python3 -I "$B" "$D" --lang snobol4 --twice < /dev/null > "$D/build.log" 2>&1
rc=$?
if [ "$rc" = 2 ]; then echo "REFUSE(2): the builder refused on the scratch package: $(tail -1 "$D/build.log")"; exit 2; fi
fail=""
[ "$rc" = 0 ] || fail="$fail builder-rc($rc)"
n=$(tail -n +2 "$D/ALL.csv" 2>/dev/null | grep -c .)
[ "$n" = 1 ] || fail="$fail ALL.csv-rows($n,want 1)"
[ "$(awk -F, 'NR==2{print $2}' "$D/ALL.csv" 2>/dev/null)" = a ] || fail="$fail ALL.csv-entry-not-a"
grep -q '^b: EXCLUDED\.tsv PROBE_CLASS:' "$D/ALL.omit" 2>/dev/null || fail="$fail excluded-line-for-b-missing"
[ -s "$D/ALL.ref" ] && grep -q '^a$' "$D/ALL.ref" || fail="$fail a-ref-not-cut"
if [ -z "$fail" ]; then
    echo "GATE OK [test_gate_builder_honours_excluded_tsv]: b.sno declared PROBE_CLASS is excluded, a.sno is absorbed and its ref cut (scratch $D)"
    exit 0
fi
echo "GATE FAIL [test_gate_builder_honours_excluded_tsv]:$fail (scratch $D, build log $D/build.log)"
exit 1
