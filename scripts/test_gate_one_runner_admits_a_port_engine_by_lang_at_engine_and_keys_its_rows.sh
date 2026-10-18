#!/bin/bash
# test_gate_one_runner_admits_a_port_engine_by_lang_at_engine_and_keys_its_rows.sh -- THE ENGINE IS A RUNNER SETTING (Lon 2026-10-17 to
# hq_dotnet: "The suite banner should represent the snobol4dotnet executable program, not SCRIP." and, asked who runs the SNOBOL4 suites on
# the snobol4dotnet engine, "hq_dotnet runs them"; ceo CEO-1822). Hermetic, no build: a scratch MODE whose LANES line carries
# snobol4@dotnet=hq_dotnet, a plain-copy two-entry rungs suite (no checkout, so the guard judges it a board and the lane decides), a stub
# dotnet host that prints nothing (both entries' refs are empty), stub DLLs, and a scratch progress table. Nothing live is read or written.
# ARMS: (1) lib_one_runner.sh one_runner_who looks up <lang>@<engine> under a port engine -- snobol4 under dotnet is hq_dotnet, under scrip
# the coo; "all" stays the bare keys; another language and an unknown engine name no lane. (2) corpus_suite_harness.py run under
# S4E_ENGINE=dotnet as hq_dotnet is ADMITTED and every row it writes is keyed snobol4-rungs@dotnet, none snobol4-rungs. (3) the same run as
# hq_dotnet without the engine is REFUSED rc 2 (ONE SEAT, ONE LANGUAGE). (4) as the coo with the engine it is REFUSED rc 2 (the coo grades
# SCRIP's lane). (5) an unknown engine REFUSES rc 2. (6) m4 under dotnet REFUSES rc 2 (the port has no mode 4).
set -u
unset S4E_DONE_WHEN_RUN S4E_ONE_RUNNER_OVERRIDE S4E_ONE_RUNNER_FIXTURE S4E_SEAT S4E_ENGINE S4E_BIN_AT_START SNOBOL4DOTNET_DLL
H="$(cd "$(dirname "$0")" && pwd)"; L="$H/lib_one_runner.sh"; HARN="$H/corpus_suite_harness.py"; G=one_runner_admits_a_port_engine; fail=0; examined=0
[ -r "$L" ] && [ -r "$HARN" ] || { echo "REFUSE(2) [$G]: $L or $HARN missing -- cannot measure"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
arm() { examined=$((examined+1)); if eval "$2"; then echo "  ok   $1"; else echo "  FAIL $1"; fail=$((fail+1)); fi; }

# the scratch law: SCRIP's bare lanes beside one port lane
mkdir -p "$T/post"; printf 'TENET\n# scratch MODE for %s\nLANES: snobol4=coo icon=coo snobol4@dotnet=hq_dotnet\n' "$G" > "$T/post/MODE"
# sourced, never named as $0: the library runs its own CLI (and prints its usage) when BASH_SOURCE[0] is $0
who() { S4E_POST="$T/post" S4E_ENGINE="$1" WHO_LIB="$L" WHO_LANG="$2" bash -c '. "$WHO_LIB"; one_runner_who "$WHO_LANG"'; }
arm "1a snobol4 under dotnet is hq_dotnet's lane"        '[ "$(who dotnet snobol4)" = hq_dotnet ]'
arm "1b snobol4 under scrip is still the coo's lane"     '[ "$(who scrip snobol4)" = coo ]'
arm "1c all under dotnet is the bare keys only"          '[ "$(who dotnet all)" = coo ]'
arm "1d icon under dotnet names no lane"                 '[ -z "$(who dotnet icon)" ]'
arm "1e an unknown engine names no lane"                 '[ -z "$(who nope snobol4)" ]'

# the scratch world: a plain-copy rungs suite, a stub dotnet host and stub DLLs
R="$T/root"; mkdir -p "$R/corpus/tests/snobol4" "$R/corpus/include" "$T/bin" "$T/dll"
printf " X = 1;END;* gate_engine_e1\n Y = 2;END;* gate_engine_e2\n" > "$R/corpus/tests/snobol4/ALL.sno"
printf "\n\n" > "$R/corpus/tests/snobol4/ALL.ref"
printf '#!/bin/sh\nexit 0\n' > "$T/bin/dotnet"; chmod +x "$T/bin/dotnet"
printf 'stub driver\n' > "$T/dll/Snobol4.dll"; printf 'stub engine\n' > "$T/dll/Snobol4.Common.dll"
run() {  # run <seat> <engine> <db> [modes]: the harness over the scratch suite; prints its rc last
    env PATH="$T/bin:$PATH" S4E_POST="$T/post" S4E_HOME="$R" S4E_SEAT="$1" ${2:+S4E_ENGINE="$2"} S4E_PROGRESS_DB="$3" \
        SNOBOL4DOTNET_DLL="$T/dll/Snobol4.dll" python3 "$HARN" run "$R/corpus/tests/snobol4/ALL.sno" "$R/corpus/tests/snobol4/ALL.ref" \
        --modes "${4:-m3}" > "$T/out" 2>&1
    echo $?
}
rows() { [ -f "$1" ] && awk -F'\t' -v s="$2" 'NR>1 && $6==s' "$1" | wc -l || echo 0; }

rc="$(run hq_dotnet dotnet "$T/admitted.tsv")"
arm "2a hq_dotnet under dotnet is admitted and graded (rc $rc)"       '[ "$rc" = 0 ]'
arm "2b its rows are keyed snobol4-rungs@dotnet (2 of 2)"             '[ "$(rows "$T/admitted.tsv" snobol4-rungs@dotnet)" -eq 2 ]'
arm "2c none of its rows lands in SCRIP's snobol4-rungs"              '[ "$(rows "$T/admitted.tsv" snobol4-rungs)" -eq 0 ]'
rc="$(run hq_dotnet "" "$T/bare.tsv")"
arm "3 hq_dotnet without the engine is refused rc 2 (got $rc)"        '[ "$rc" = 2 ] && grep -q "ONE SEAT, ONE LANGUAGE" "$T/out"'
rc="$(run coo dotnet "$T/coo.tsv")"
arm "4 the coo under dotnet is refused rc 2 by the lane (got $rc)"    '[ "$rc" = 2 ] && grep -q "ONE RUNNER PER LANGUAGE" "$T/out" && [ "$(rows "$T/coo.tsv" snobol4-rungs@dotnet)" -eq 0 ]'
rc="$(run hq_dotnet nope "$T/nope.tsv")"
arm "5 an unknown engine refuses rc 2 (got $rc)"                      '[ "$rc" = 2 ] && grep -q "names no engine" "$T/out"'
rc="$(run hq_dotnet dotnet "$T/m4.tsv" m3,m4)"
arm "6 m4 under dotnet refuses rc 2 (got $rc)"                        '[ "$rc" = 2 ] && grep -q "has none" "$T/out"'

[ $examined -ge 12 ] || { echo "REFUSE(2) [$G]: examined=$examined below the 12 declared arms"; exit 2; }
[ $fail -eq 0 ] && { echo "GATE OK [$G]: $examined arms"; exit 0; }
echo "GATE FAIL(1) [$G]: $fail of $examined arms red"; exit 1
