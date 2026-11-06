#!/usr/bin/env bash
# test_gate_impact_set_names_what_a_commit_owes.sh -- THE GATE OF util_impact_set.py (DESIGN-PLAN box-budget step 3 and box-scheduler step 13,
# CTO-496; the president 2026-11-05, row box-scheduler-step-13-the-landing-proof-is-sized-by-the-change-impact-set-cto-496; the coo's plan for the
# step 3 gate, baton box-budget-step-3 NEXT 1, is arms 3 and 4 here). The design sentence it keeps true: "the proof is sized by the change-impact
# set (a Makefile line owes the build gate, not eight smokes)".
# WHAT IT PROVES, each arm on a PLANTED HOME (a fixture SCRIP repo of commits, this harness's real test_area_smoke.sh over a planted area_map.tsv,
# a planted scripts directory of stub smokes and gates with a planted gate_wiring.tsv, two planted masters' PARTITION.tsv, and a COPY of the real
# impact_proof.tsv), no build and no corpus read:
#   1  a README-only commit owes nothing: PROOF arms=0
#   2  a Makefile-only commit owes the build, the preflight and the declared build gates, and NO smoke (the design sentence)
#   3  a commit to one language's lowerer owes that language's smoke and the area smoke, and its IMPACT line names the language and its core
#   4  a commit to a shared node owes the declared eight smokes, the WIRED gate that names the touched path and not the TASK gate that names it
#      too (unwired=1), and its IMPACT line names every master
#   5  a commit to a carrier the map sends to `-` owes the build and the preflight and NO area arm and NO smoke
#   6  a src/ file the map does not name REFUSES rc 2, naming it (the selector's refusal reaches the caller)
#   7  a gate script touched in the harness repo owes itself and the preflight
#   8  FAIL-ONCE: a declared build gate missing from the scripts directory REFUSES rc 2 naming it, never a quietly smaller proof
#   9  a --commit that is not HEAD REFUSES rc 2; a table row owing a token it does not know REFUSES rc 2
#  10  the sizing law, across arms 2 and 4: the Makefile commit owes strictly fewer arms and fewer smokes than the shared-node commit
#  12  --eight (box-scheduler step 24) on a one-language commit names that language's CORE entries by greedy set cover over the touched features, under the cap
#      READ FROM s4e_test_request.sh, and --cap overrides it; 13 on a shared node the cap is spread one program per suite per round, and a master with no suite key
#      is named in nosuite and files nothing; 14 a commit that names no program prints NO-EIGHT and never an EIGHT line (the probe's grep must not pass on it);
#      15 --proof and --eight together refuse rc 2
#  11  THE REAL TABLE: every repo carries a `.` catch-all row, every @ directive name is a file in this scripts directory, and the declared build
#      gates are WIRED in the real gate_wiring.tsv
# FAIL_ONCE=1 corrupts the PLANTED gate_wiring.tsv (the TASK gate is marked WIRED) and arm 4 must read red; FAIL_ONCE=2 plants REQUEST_CAP=5 where the arms expect 3
# and arms 12a and 13 must read red; nothing under src/ is planted.
# EXIT: 0 every arm holds; 1 an arm failed; 2 could not measure. Population printed.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_gate.sh" || { echo "REFUSING(2): cannot load lib_gate.sh"; exit 2; }
GATE_NAME=impact_set_names_what_a_commit_owes
gate_parse_args "$@"
TOOL="$HERE/util_impact_set.py"; TABLE="$HERE/impact_proof.tsv"; WIRING="$HERE/gate_wiring.tsv"
gate_require "$TOOL" "util_impact_set.py" || exit 2
gate_require "$TABLE" "impact_proof.tsv" || exit 2
gate_require "$WIRING" "gate_wiring.tsv" || exit 2
gate_require "$HERE/test_area_smoke.sh" "test_area_smoke.sh" || exit 2
command -v git > /dev/null && command -v python3 > /dev/null || { echo "GATE UNPROVEN(2) [$GATE_NAME]: git and python3 are required"; gate_stamp; exit 2; }
SCR="${S4E_SCRATCH:-/tmp/s4e/${S4E_SEAT:-gate}}"; mkdir -p "$SCR" || exit 2
WORK=$(mktemp -d "$SCR/gate_impact_set_XXXXXX") || exit 2
trap '[ -n "${WORK:-}" ] && rm -rf "$WORK"' EXIT INT TERM
fails=0; n=0
ck() { n=$((n+1)); if eval "$2"; then echo "  ok   $1"; else fails=$((fails+1)); echo "  FAIL $1"; fi; }
decl() { awk -F'\t' -v k="$1" '$1=="@" && $2==k {print $3}' "$TABLE"; }
field() { sed -n "s/.*[ ]$1=\([^ ]*\).*/\1/p" <<<"$2" | head -1; }
S="$WORK/harness/scripts"; R="$WORK/SCRIP"; C="$WORK/corpus"
mkdir -p "$S" "$R/src/lower" "$R/src/runtime" "$R/src/tools" "$R/docs" "$C/tests/rebus" "$C/tests/snobol4" "$C/tests/zzfake"
cp "$TABLE" "$S/impact_proof.tsv"
printf 'lang:rebus\tsrc/lower/lower_rebus.c\n*\tsrc/runtime/\n-\tsrc/tools/\n' > "$S/area_map.tsv"
for g in $(decl buildgates); do printf 'exit 0\n' > "$S/$g"; done
for l in $(decl shared-smokes); do printf 'exit 0\n' > "$S/test_smoke_$l.sh"; done
printf '# planted\nsrc/runtime/zz.c is read here\n' > "$S/test_gate_names_the_runtime_leaf.sh"
printf '# planted debt\nsrc/runtime/zz.c is read here too\n' > "$S/test_gate_debt_names_the_runtime_leaf.sh"
{ printf '# planted\n'; for g in $(decl buildgates) test_gate_names_the_runtime_leaf.sh; do printf '%s\tWIRED\t-\t-\t-\n' "$g"; done
  if [ "${FAIL_ONCE:-0}" = 1 ]; then printf 'test_gate_debt_names_the_runtime_leaf.sh\tWIRED\t-\t-\t-\n'; else printf 'test_gate_debt_names_the_runtime_leaf.sh\tTASK\t-\t-\t-\n'; fi; } > "$S/gate_wiring.tsv"
printf 'entry\tpart\tcluster\tshells\ne1\tcore\tcore\talpha beta\ne2\tcore\tcore\tbeta gamma\ne3\tshell\tx\talpha\ne4\tcore\tcore\tdelta\n' > "$C/tests/rebus/PARTITION.tsv"
printf 'entry\tpart\tcluster\tshells\ns1\tcore\tcore\tsa sb\ns2\tcore\tcore\tsb\n' > "$C/tests/snobol4/PARTITION.tsv"
printf 'entry\tpart\tcluster\tshells\nz1\tcore\tcore\tzf\nz2\tcore\tcore\tzf\nz3\tcore\tcore\tzf\n' > "$C/tests/zzfake/PARTITION.tsv"
gate_require "$HERE/s4e_test_request.sh" "s4e_test_request.sh" || exit 2
if [ "${FAIL_ONCE:-0}" = 2 ]; then cap=5; else cap=3; fi
sed "s/^REQUEST_CAP=8\$/REQUEST_CAP=$cap/" "$HERE/s4e_test_request.sh" > "$S/s4e_test_request.sh"
printf 'int lower;\n' > "$R/src/lower/lower_rebus.c"; printf 'int zz;\n' > "$R/src/runtime/zz.c"; printf 'int t;\n' > "$R/src/tools/t.c"
printf 'all:\n\t@true\n' > "$R/Makefile"; printf 'readme\n' > "$R/README.md"
G() { git -C "$1" -c user.name=g -c user.email=g@g "${@:2}"; }
( G "$R" init -q && G "$R" add -A && G "$R" commit -q -m base ) || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot make the fixture repo"; gate_stamp; exit 2; }
step() { printf '%s\n' "$2" >> "$R/$1"; G "$R" commit -qam "edit $1"; }
proof() { ( cd "$WORK" && S4E_HOME="$WORK" python3 "$TOOL" --root "${ROOT_ARG:-SCRIP}" --scripts "$S" --corpus "$C" --proof "$@" 2>&1 ); }
impact() { ( cd "$WORK" && S4E_HOME="$WORK" python3 "$TOOL" --root SCRIP --scripts "$S" --corpus "$C" "$@" 2>&1 ); }
nbg=$(decl buildgates | wc -w); nsh=$(decl shared-smokes | wc -w)
[ "$nbg" -ge 1 ] && [ "$nsh" -ge 1 ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the real table declares no @ buildgates or no @ shared-smokes"; gate_stamp; exit 2; }

echo "--- ARM 1: a README-only commit owes nothing ---"
step README.md more; o1=$(proof); r1=$?
ck "1 rc 0, PROOF arms=0 smokes=0 gates=0, no ARM line" '[ "$r1" = 0 ] && grep -q "^PROOF arms=0 smokes=0 gates=0 owes=- " <<<"$o1" && ! grep -q "^ARM " <<<"$o1"'
echo "--- ARM 2: a Makefile-only commit owes the build gate and no smoke ---"
step Makefile '# one more line'; o2=$(proof); r2=$?
a2=$(field arms "$o2"); s2=$(field smokes "$o2")
ck "2 rc 0, ARM build, ARM preflight, $nbg declared build gate(s), smokes=0, arms=$((nbg+2))" '[ "$r2" = 0 ] && grep -q "^ARM build " <<<"$o2" && grep -q "^ARM preflight " <<<"$o2" && [ "$(field gates "$o2")" = "$nbg" ] && [ "$s2" = 0 ] && [ "$a2" = "$((nbg+2))" ] && ! grep -q "^ARM smoke " <<<"$o2"'
echo "--- ARM 3: one language's lowerer owes that language's smoke ---"
step src/lower/lower_rebus.c 'int more;'; o3=$(proof); r3=$?; i3=$(impact); ri3=$?
ck "3a rc 0, ARM area, exactly ARM smoke test_smoke_rebus.sh, langs=rebus, shared=0" '[ "$r3" = 0 ] && grep -q "^ARM area " <<<"$o3" && [ "$(field smokes "$o3")" = 1 ] && grep -q "^ARM smoke bash harness/scripts/test_smoke_rebus.sh$" <<<"$o3" && [ "$(field langs "$o3")" = rebus ] && [ "$(field shared "$o3")" = 0 ]'
ck "3b the IMPACT line names rebus and its 3 core entries" '[ "$ri3" = 0 ] && grep -q "^IMPACT lang=rebus core=3 shells=0 shared=0 files=1 " <<<"$i3"'
echo "--- ARM 4: a shared node owes the declared smokes and the WIRED gate that names it ---"
step src/runtime/zz.c 'int more;'; o4=$(proof); r4=$?; i4=$(impact); ri4=$?
ck "4a rc 0, smokes=$nsh (the @ shared-smokes), shared=1" '[ "$r4" = 0 ] && [ "$(field smokes "$o4")" = "$nsh" ] && [ "$(field shared "$o4")" = 1 ]'
ck "4b the WIRED gate naming src/runtime/zz.c is owed, the TASK gate naming it is not (gates=1 unwired=1)" 'grep -q "^ARM gate bash harness/scripts/test_gate_names_the_runtime_leaf.sh$" <<<"$o4" && ! grep -q "debt_names" <<<"$o4" && [ "$(field gates "$o4")" = 1 ] && [ "$(field unwired "$o4")" = 1 ]'
ck "4c the IMPACT line names every master (rebus,snobol4,zzfake) and their 8 core entries" '[ "$ri4" = 0 ] && grep -q "^IMPACT lang=rebus,snobol4,zzfake core=8 " <<<"$i4"'
echo "--- ARM 5: a carrier the map sends to - owes no area and no smoke ---"
step src/tools/t.c 'int more;'; o5=$(proof); r5=$?
ck "5 rc 0, ARM build and ARM preflight, no ARM area, smokes=0" '[ "$r5" = 0 ] && grep -q "^ARM build " <<<"$o5" && ! grep -q "^ARM area " <<<"$o5" && [ "$(field smokes "$o5")" = 0 ]'
echo "--- ARM 10: the sizing law across arms 2 and 4 ---"
ck "10 the Makefile commit owes $a2 arm(s) and $s2 smoke(s), the shared-node commit $(field arms "$o4") and $(field smokes "$o4")" '[ "$a2" -lt "$(field arms "$o4")" ] && [ "$s2" -lt "$(field smokes "$o4")" ]'
echo "--- ARM 6: an unmapped src file refuses naming it ---"
printf 'int u;\n' > "$R/src/zz_unmapped.c"; G "$R" add -A; G "$R" commit -qm unmapped
o6=$(proof); r6=$?
ck "6 rc 2 and the refusal names src/zz_unmapped.c" '[ "$r6" = 2 ] && grep -q "REFUSE(2)" <<<"$o6" && grep -q "src/zz_unmapped.c" <<<"$o6"'
G "$R" reset -q --hard HEAD^
echo "--- ARM 7: a gate script touched in the harness repo owes itself ---"
( G "$WORK/harness" init -q && G "$WORK/harness" add -A && G "$WORK/harness" commit -q -m base && printf '# edited\n' >> "$S/test_gate_names_the_runtime_leaf.sh" && G "$WORK/harness" commit -qam gate ) || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot make the harness fixture repo"; gate_stamp; exit 2; }
o7=$(ROOT_ARG=harness proof); r7=$?
ck "7 rc 0, gates=1 (ARM gate test_gate_names_the_runtime_leaf.sh), ARM preflight, no smoke, no build" '[ "$r7" = 0 ] && [ "$(field gates "$o7")" = 1 ] && grep -q "^ARM gate bash harness/scripts/test_gate_names_the_runtime_leaf.sh$" <<<"$o7" && grep -q "^ARM preflight " <<<"$o7" && ! grep -q "^ARM build \|^ARM smoke " <<<"$o7"'
echo "--- ARM 8: FAIL-ONCE -- a declared build gate that is not a file refuses ---"
gone=$(decl buildgates | tr ' ' '\n' | head -1); mv "$S/$gone" "$WORK/gone.sh"; step Makefile '# again'; o8=$(proof); r8=$?
ck "8 rc 2 naming $gone, no PROOF line" '[ "$r8" = 2 ] && grep -q "$gone" <<<"$o8" && ! grep -q "^PROOF arms=" <<<"$o8"'
mv "$WORK/gone.sh" "$S/$gone"
echo "--- ARM 9: a non-HEAD commit and an unknown token refuse ---"
o9a=$(proof --commit HEAD^); r9a=$?
ck "9a --commit HEAD^ rc 2 naming HEAD" '[ "$r9a" = 2 ] && grep -q "is not the tree.s HEAD" <<<"$o9a"'
printf 'SCRIP\tMakefile\tbuild,bogus\nSCRIP\t.\tbuild\n' > "$WORK/bad.tsv"
o9b=$(proof --table "$WORK/bad.tsv"); r9b=$?
ck "9b a table row owing the token bogus rc 2 naming it" '[ "$r9b" = 2 ] && grep -q "bogus" <<<"$o9b"'
eight() { ( cd "$WORK" && S4E_HOME="$WORK" python3 "$TOOL" --root SCRIP --scripts "$S" --corpus "$C" --eight "$@" 2>&1 ); }
echo "--- ARM 12: --eight names one language's core entries by greedy cover, under the cap the request script declares ---"
step src/lower/lower_rebus.c 'int e;'; o12=$(eight); r12=$?; o12b=$(eight --cap 2); r12b=$?
ck "12a rc 0, exactly EIGHT reb-rungs e1 e2 e4 (alpha beta, then gamma, then delta) and EIGHT-TOTAL programs=3 cap=3 features=4/4" '[ "$r12" = 0 ] && [ "$(grep -c "^EIGHT " <<<"$o12")" = 1 ] && grep -qx "EIGHT reb-rungs e1 e2 e4" <<<"$o12" && grep -q "^EIGHT-TOTAL programs=3 cap=3 suites=1 langs=rebus features=4/4 nosuite=- " <<<"$o12"'
ck "12b --cap 2 names e1 e2 only (programs=2 cap=2)" '[ "$r12b" = 0 ] && grep -qx "EIGHT reb-rungs e1 e2" <<<"$o12b" && grep -q "^EIGHT-TOTAL programs=2 cap=2 " <<<"$o12b"'
echo "--- ARM 13: a shared node spreads the cap one program per suite per round; a master with no suite files nothing ---"
step src/runtime/zz.c 'int e;'; o13=$(eight); r13=$?
ck "13 rc 0, EIGHT reb-rungs e1 e2 and EIGHT sno-rungs s1, programs=3 cap=3 suites=2 (the cap is the script's, not a fixed 8), nosuite=zzfake" '[ "$r13" = 0 ] && grep -qx "EIGHT reb-rungs e1 e2" <<<"$o13" && grep -qx "EIGHT sno-rungs s1" <<<"$o13" && [ "$(grep -c "^EIGHT " <<<"$o13")" = 2 ] && grep -q "^EIGHT-TOTAL programs=3 cap=3 suites=2 langs=rebus,snobol4 features=5/6 nosuite=zzfake " <<<"$o13"'
echo "--- ARM 14: a commit that names no program prints NO-EIGHT, never an EIGHT line ---"
step Makefile '# eight'; o14=$(eight); r14=$?
ck "14 rc 0, a NO-EIGHT line, no line starting EIGHT (the step probe greps for ^EIGHT [a-z])" '[ "$r14" = 0 ] && grep -q "^NO-EIGHT " <<<"$o14" && ! grep -q "^EIGHT" <<<"$o14"'
echo "--- ARM 15: --proof and --eight together refuse ---"
o15=$(proof --eight); r15=$?
ck "15 rc 2 naming the two questions" '[ "$r15" = 2 ] && grep -q "two questions" <<<"$o15"'
echo "--- ARM 11: the real table is complete and its declared names are real ---"
miss_repo=""; for r in SCRIP harness corpus .github; do awk -F'\t' -v r="$r" '$1==r && $2=="." {f=1} END {exit !f}' "$TABLE" || miss_repo="$miss_repo $r"; done
miss_name=""; for g in $(decl buildgates); do [ -f "$HERE/$g" ] || miss_name="$miss_name $g"; done; for l in $(decl shared-smokes); do [ -f "$HERE/test_smoke_$l.sh" ] || miss_name="$miss_name test_smoke_$l.sh"; done
unwired=""; for g in $(decl buildgates); do awk -F'\t' -v g="$g" '$1==g && $2=="WIRED" {f=1} END {exit !f}' "$WIRING" || unwired="$unwired $g"; done
ck "11a every repo carries a . catch-all row" '[ -z "$miss_repo" ]'; [ -z "$miss_repo" ] || echo "      no catch-all for:$miss_repo"
ck "11b every @ directive name is a file in $HERE" '[ -z "$miss_name" ]'; [ -z "$miss_name" ] || echo "      missing:$miss_name"
ck "11c the declared build gates are WIRED in the real gate_wiring.tsv" '[ -z "$unwired" ]'; [ -z "$unwired" ] || echo "      not WIRED:$unwired"
echo "------------------------------------------------------------"
echo "population: $n check(s) over a planted home (a fixture SCRIP of $(G "$R" rev-list --count HEAD) commits, $nsh shared smokes, $nbg build gates, 3 masters)"
if [ "$fails" -eq 0 ]; then echo "GATE OK [$GATE_NAME]: $n of $n checks hold"; gate_stamp; exit 0; fi
echo "GATE FAIL [$GATE_NAME]: $fails of $n check(s) failed"; gate_stamp; exit 1
