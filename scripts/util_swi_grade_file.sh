#!/usr/bin/env bash
# util_swi_grade_file.sh REL -- grade ONE swi_tests file per case in mode 3, the way the deleted test_prolog_swi_suite.sh ran it (scrip --run plunit.pl FILE wrap.pl at the declared heap and stack, then util_swi_match.py against the swipl ref). rc 0 when every case agrees, 1 on any FAIL, HANG or CRASH, 2 when it cannot measure. Prints SWI_FILE rel cases=N red=R. Writes no progress row. The coo 2026-11-08 23:5x for the SWI rows (Lon: "Get SWI to 100%.").
cd "${S4E_HOME:?REFUSE(2): S4E_HOME unset}" || exit 2
rel="$1"; f=corpus/packages/prolog/swi_tests/$rel; [ -f "$f" ] && [ -f "${f%.pl}.ref" ] || exit 2
W=$(mktemp -d /tmp/s4e/${S4E_SEAT:-x}-swi.XXXXXX) || exit 2
printf 'main :- run_tests.\n:- initialization(main).\n' > $W/w.pl
hs=$(awk -F, -v k="${rel%.pl}" 'NR==1{for(i=1;i<=NF;i++){if($i=="heap_kb")h=i;if($i=="stack_kb")s=i}} $2==k{print "-d"$h"k -s"$s"k"}' corpus/packages/prolog/swi_tests/ALL.csv)
(cd "$(dirname "$f")" && timeout 120 "$S4E_HOME/SCRIP/scrip" --run $hs "$S4E_HOME/corpus/packages/prolog/swi_tests/plunit.pl" "$S4E_HOME/$f" $W/w.pl < /dev/null > $W/a 2> $W/e); rc=$?
python3 -I harness/scripts/util_swi_match.py "$f" "${f%.pl}.ref" $W/a $rc > $W/m 2>&1
n=$(grep -cP '\t(PASS|FAIL|HANG|CRASH)' $W/m); r=$(grep -cP '\t(FAIL|HANG|CRASH)' $W/m)
echo "SWI_FILE $rel cases=$n red=$r rc=$rc out=$W"; [ "$n" -gt 0 ] && [ "$r" = 0 ]
