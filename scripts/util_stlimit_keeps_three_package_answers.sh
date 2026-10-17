#!/usr/bin/env bash
# util_stlimit_keeps_three_package_answers.sh -- the DONE-WHEN of row snobol4-the-graders-stlimit-switch-changes-three-package-answers-tictacto-treeread-hsort
# (ceo 2026-09-25, CEO-1261 package pass): gimpel TICTACTO_driver and TREEREAD_driver and aisnobol HSORT answer the oracle with the
# graders' --stlimit switch OFF and not with it ON; this runs them ON. rc 0 all three answer, 1 a red named, 2 could not run.
export SCRIP_SNO_STMTKW=1
cd "${S4E_HOME:-/home/claude_ceo}/corpus/packages/snobol4/gimpel" || exit 2
for p in TICTACTO TREEREAD; do [ -f ${p}_driver.sno ] || p=$(printf %s "$p" | tr A-Z a-z); i=/dev/null; [ -f ${p}_driver.in ] && i=${p}_driver.in; diff -q <(SNO_LIB=.:include timeout -k 5 60 "${S4E_HOME:-/home/claude_ceo}/SCRIP/scrip" ${p}_driver.sno < $i 2>/dev/null) ${p}_driver.ref > /dev/null || { echo "RED $p"; exit 1; }; done
cd ../aisnobol || exit 2
# ⛔ THE ORACLE'S STATUS IS READ BEFORE ITS ANSWER IS USED (coo 2026-09-27, test_gate_ref_cutters_refuse_a_dead_oracle.sh arm 6, ceo
# CEO-1306): the answer came through a process substitution, so an sbl that died on a signal half-way through printing -- the ERROR 212
# class that gate exists for -- was compared as if it had answered. The oracle is named by lib_oracle_flags.sh, never a typed path.
. "${S4E_HOME:-/home/claude_ceo}/harness/scripts/lib_oracle_flags.sh" 2>/dev/null || { echo "REFUSE(2): lib_oracle_flags.sh unloadable"; exit 2; }
ora="$(mktemp)" || exit 2; trap 'rm -f "$ora"' EXIT
"$(sbl_correctness_bin)" -bf -u HSORT.IN HSORT.sno HSORT.IN < /dev/null > "$ora" 2>/dev/null; orc=$?
[ "$orc" -lt 128 ] || { echo "REFUSE(2): the oracle died on signal $((orc - 128)) running HSORT -- there is no answer to compare"; exit 2; }
diff -q <(timeout -k 5 60 "${S4E_HOME:-/home/claude_ceo}/SCRIP/scrip" --run -u HSORT.IN HSORT.sno -- HSORT.IN < /dev/null 2>/dev/null) "$ora" > /dev/null || { echo "RED HSORT"; exit 1; }
echo "GREEN: TICTACTO, TREEREAD and HSORT answer the oracle"; exit 0
