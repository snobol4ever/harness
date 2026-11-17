#!/usr/bin/env bash
# util_package_rc_check.sh -- A PACKAGE'S ALL.rc IS THE DERIVED FILE OF ITS ALL.csv want_rc, FOR ITS ABSORBED ENTRIES (the coo's ruling 2026-11-17 00:3x CST, row
# icon-packages-all-rc-agrees-with-the-want-rc-of-all-csv-read-on-the-oracle, officer_04). util_build_package_suite.py writes ALL.rc as one line, name TAB status, for each
# ABSORBED entry whose want_rc is nonzero; an entry ALL.omit names is graded nowhere, so its want_rc cell stands as it is and owes no line. A mismatch is drift from a hand
# edit of one file without the other: MEASURED 2026-11-17, three unicon_uni entries declared want_rc 1 with no ALL.rc line and were graded at status 0 (cured by corpus
# patch 20261117T062904Z-officer_04-corpus-3729695). An ALL.omit name may carry its source suffix (.icn, .iol, .uni), which is stripped.
#   bash util_package_rc_check.sh [CORPUS]     every packages/*/*/ALL.csv with a want_rc column under CORPUS (default $S4E_CORPUS, from lib_paths.sh)
#   bash util_package_rc_check.sh --probe      three scratch packages: agree, disagree, an omitted entry with no line
# rc 0 every package agrees (PACKAGE_RC OK); rc 1 one disagrees (PACKAGE_RC RED, each named with its first differing lines); rc 2 nothing to measure.
# The lander runs it as the land_checks.tsv row package_rc for a landing that changes a package's ALL.csv, ALL.rc or ALL.omit.
one() {  # one DIR: echo the package's disagreement, nothing when it agrees
    local d="$1" w r
    w=$(awk -F, -v om="$d/ALL.omit" 'BEGIN{while((getline l < om)>0){sub(/:.*/,"",l); sub(/\.(icn|iol|uni)$/,"",l); o[l]=1}} NR==1{for(i=1;i<=NF;i++) if($i=="want_rc") k=i; next} k && $k!="" && $k!="0" && !($2 in o){print $2"\t"$k}' "$d/ALL.csv" | sort)
    r=$( [ -f "$d/ALL.rc" ] && sort "$d/ALL.rc" )
    [ "$w" = "$r" ] || { echo "DISAGREE $d"; diff <(printf '%s\n' "$w") <(printf '%s\n' "$r") | grep -E '^[<>] ' | head -6 | sed 's/^< /  want_rc in ALL.csv, no such ALL.rc line: /; s/^> /  ALL.rc line, no such want_rc in ALL.csv: /'; }
}
walk() {  # walk CORPUS: rc 0, 1 or 2
    local n=0 bad=0 c o
    for c in "$1"/packages/*/*/ALL.csv; do [ -f "$c" ] && head -1 "$c" | grep -q 'want_rc' || continue; n=$((n+1)); o=$(one "$(dirname "$c")"); [ -n "$o" ] && { echo "$o"; bad=$((bad+1)); }; done
    [ "$n" -gt 0 ] || { echo "PACKAGE_RC REFUSE(2): no packages/*/*/ALL.csv with a want_rc column under $1"; return 2; }
    [ "$bad" = 0 ] && { echo "PACKAGE_RC OK: $n packages, each ALL.rc the want_rc of its absorbed entries"; return 0; }
    echo "PACKAGE_RC RED: $bad of $n packages disagree"; return 1
}
if [ "${1:-}" = --probe ]; then
    t=$(mktemp -d "${TMPDIR:-/tmp}/package_rc_probe.XXXXXX") || exit 2; trap 'rm -rf "$t"' EXIT; p="$t/packages/icon"
    mk() { mkdir -p "$p/$1"; printf 'rank,entry,want_rc\n1,a,0\n2,b,1\n3,c,255\n' > "$p/$1/ALL.csv"; }
    mk agree; printf 'b\t1\nc\t255\n' > "$p/agree/ALL.rc"
    walk "$t" > "$t/l1"; r1=$?
    mk omitted; printf 'b\t1\n' > "$p/omitted/ALL.rc"; printf 'c.icn: NEEDS_TERMINAL\n' > "$p/omitted/ALL.omit"
    walk "$t" > "$t/l2"; r2=$?
    mk drift; printf 'b\t1\n' > "$p/drift/ALL.rc"
    walk "$t" > "$t/l3"; r3=$?
    if [ "$r1" = 0 ] && [ "$r2" = 0 ] && [ "$r3" = 1 ] && grep -q 'DISAGREE .*/drift$' "$t/l3" && ! grep -q 'DISAGREE .*/omitted$' "$t/l3"; then echo "PACKAGE_RC probe PASS (agree 0, omitted 0, drift 1)"; exit 0; fi
    echo "package_rc probe FAIL: agree=$r1 omitted=$r2 drift=$r3"; cat "$t/l3"; exit 1
fi
if [ -n "${1:-}" ]; then C="$1"; else . "${S4E_HARNESS:-/home/harness}/scripts/lib_paths.sh" || exit 2; C="$S4E_CORPUS"; fi
[ -d "$C/packages" ] || { echo "PACKAGE_RC REFUSE(2): no $C/packages"; exit 2; }
walk "$C"
