#!/usr/bin/env bash
# util_swi_cut_refs.sh -- cut corpus/packages/prolog/swi_tests/**/*.ref from REAL swipl running its OWN library(plunit),
# ONE LINE PER TEST CASE, the ref BESIDE its .pl BY PATH (never by basename: the same basename exists in several
# subdirectories of the vendored swipl-devel src/Tests tree). Lon 2026-09-12, in-chat to cto, verbatim: "Get all SWI
# tests graded." Row prolog-swi-tests-all-2879-cases-graded-per-case-against-swipl-by-path.
#
# The oracle is swipl, never our shim (ceo ruling 2026-09-06). Each (file, unit) runs in its OWN swipl process so a
# C-level abort in one unit (test_string's string_upper/2 on a non-Latin-1 codepoint SIGABRTs swipl 9.0.4) cannot
# swallow a sibling unit's verdict. The verdict per CASE is read from plunit's own bookkeeping after run_tests/1:
# passed/5, failed/4, failed_assertion/7, blocked/4 -- never scraped from printed dots.
#
# REF LINES (one per case, in source-line order within a unit; units in source order):
#   PASS unit:test          the oracle passed the case
#   FAIL unit:test          the oracle failed the case (a failing test, or a failed assertion)
#   BLOCKED unit:test       the oracle skipped it (blocked(Reason)) -- named, ungraded
#   EMPTY unit              the unit ran zero cases under the oracle (every case condition(...)-false, or no tests)
#   UNGRADABLE unit reason  the oracle produced no verdict (consult error, crash, SIGABRT, timeout) -- the reason is
#                           the ORACLE'S, never ours; named, ungraded
# A test name that appears on several test/2 clauses appears once per clause; the grader matches by occurrence order.
#
# Usage: util_swi_cut_refs.sh [--write] [--jobs N] [path/under/swi_tests.pl ...]
#   default population: every *.pl under the package that declares a begin_tests( unit
#   --write   write each ref beside its .pl (default: print a diff against the existing ref, write nothing)
#   --jobs N  oracle processes in parallel (default 8)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib_oracle_flags.sh"
SWIPL="$(swipl_bin)" || exit 2
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
D="$S4E/corpus/packages/prolog/swi_tests"
[ -d "$D" ] || { echo "⛔ REFUSE(2): $D missing -- the corpus moved; re-pin rather than reinterpret" >&2; exit 2; }
WRITE=0; JOBS=8; FILES=()
while [ $# -gt 0 ]; do
    case "$1" in
        --write) WRITE=1; shift ;;
        --jobs) JOBS="$2"; shift 2 ;;
        *) FILES+=("$1"); shift ;;
    esac
done
if [ "${#FILES[@]}" -eq 0 ]; then
    while IFS= read -r f; do FILES+=("$f"); done < <(grep -rl --include='*.pl' 'begin_tests(' "$D" | sort)
fi
DRIVER=$(mktemp /tmp/swi_case_driver_XXXXXX.pl)
WORK=$(mktemp -d /tmp/swi_cut_XXXXXX)
trap 'rm -rf "$DRIVER" "$WORK"' EXIT
cat > "$DRIVER" <<'PLEOF'
main :-
    current_prolog_flag(argv, [File, Unit]),
    catch(consult(File), CErr,
          ( message_to_codes(CErr, Codes), format("UNGRADABLE ~w consult: ~s~n", [Unit, Codes]), halt(0))),
    ( catch(run_tests([Unit]), TErr, (print_message(error, TErr), true)) -> true ; true ),
    findall(L-p(T), plunit:passed(Unit, T, L, _, _), Ps),
    findall(L-f(T), plunit:failed(Unit, T, L, _), Fs),
    findall(L-f(T), ( plunit:failed_assertion(Unit, T, L, _, _, _, _), \+ plunit:failed(Unit, T, L, _) ), FAs),
    findall(L-b(T), plunit:blocked(Unit, T, L, _), Bs),
    append([Ps, Fs, FAs, Bs], All0),
    sort(0, @=<, All0, All),
    ( All == [] -> format("EMPTY ~w~n", [Unit])
    ; forall(member(_-V, All), out(Unit, V)) ),
    halt(0).
out(U, p(T)) :- format("PASS ~w:~w~n", [U, T]).
out(U, f(T)) :- format("FAIL ~w:~w~n", [U, T]).
out(U, b(T)) :- format("BLOCKED ~w:~w~n", [U, T]).
message_to_codes(E, Codes) :-
    catch(( message_to_codes_(E, Codes) ), _, ( with_output_to(codes(Codes), print(E)) )).
message_to_codes_(E, Codes) :-
    '$messages':translate_message(E, Lines, []),
    with_output_to(codes(Codes0), print_message_lines(current_output, '', Lines)),
    exclude([C]>>(C =:= 10), Codes0, Codes).
PLEOF
WORKER="$WORK/worker.sh"
cat > "$WORKER" <<'WEOF'
#!/usr/bin/env bash
f="$1"; unit="$2"; out="$3"
raw=$(cd "$(dirname "$f")" && timeout -k 5 60 "$SWIPL" -q -g main -t "halt(9)" "$DRIVER" -- "$f" "$unit" 2>/dev/null)
rc=$?
line=$(printf '%s\n' "$raw" | grep -E '^(PASS|FAIL|BLOCKED|EMPTY|UNGRADABLE) ')
if [ -z "$line" ]; then
    case "$rc" in
        124) printf 'UNGRADABLE %s oracle timeout after 60s\n' "$unit" > "$out" ;;
        *)   printf 'UNGRADABLE %s oracle process exited rc=%s with no verdict (crash or abort)\n' "$unit" "$rc" > "$out" ;;
    esac
else
    printf '%s\n' "$line" > "$out"
fi
WEOF
export SWIPL DRIVER
JOBLIST="$WORK/jobs.txt"; : > "$JOBLIST"
n=0
for f in "${FILES[@]}"; do
    case "$f" in /*) : ;; *) f="$D/$f" ;; esac
    [ -f "$f" ] || { echo "⛔ REFUSE: $f missing -- skipping" >&2; continue; }
    rel="${f#"$D"/}"; fdir="$WORK/${rel%.pl}"; mkdir -p "$fdir"
    i=0
    while IFS= read -r unit; do
        [ -n "$unit" ] || continue
        i=$((i + 1)); n=$((n + 1))
        printf '%s %s %s\n' "$f" "$unit" "$fdir/$(printf '%04d' "$i").part" >> "$JOBLIST"
    done < <(grep -oP '^\s*:-\s*begin_tests\(\K[a-zA-Z0-9_]+' "$f")
done
echo "cutting $n unit(s) from ${#FILES[@]} file(s) with $JOBS oracle process(es) in parallel"
xargs -P "$JOBS" -n 3 -a "$JOBLIST" bash "$WORKER"
wrote=0; changed=0; unchanged=0; ungr=0; cases=0
for f in "${FILES[@]}"; do
    case "$f" in /*) : ;; *) f="$D/$f" ;; esac
    [ -f "$f" ] || continue
    rel="${f#"$D"/}"; fdir="$WORK/${rel%.pl}"; ref="${f%.pl}.ref"
    cat "$fdir"/*.part > "$fdir/new.ref" 2>/dev/null || : > "$fdir/new.ref"
    cases=$((cases + $(grep -cE '^(PASS|FAIL) ' "$fdir/new.ref")))
    ungr=$((ungr + $(grep -c '^UNGRADABLE ' "$fdir/new.ref")))
    if [ "$WRITE" -eq 1 ]; then
        if [ -f "$ref" ] && cmp -s "$ref" "$fdir/new.ref"; then unchanged=$((unchanged + 1)); else cp "$fdir/new.ref" "$ref"; wrote=$((wrote + 1)); fi
    else
        if [ -f "$ref" ]; then diff -q "$ref" "$fdir/new.ref" >/dev/null && unchanged=$((unchanged + 1)) || { changed=$((changed + 1)); echo "=== $rel: would change"; diff "$ref" "$fdir/new.ref" | head -20; }
        else changed=$((changed + 1)); echo "=== $rel: NEW ($(wc -l < "$fdir/new.ref") line(s))"; fi
    fi
done
echo "SWI_REFS files=${#FILES[@]} units=$n graded_cases=$cases ungradable_units=$ungr written=$wrote unchanged=$unchanged would_change=$changed"
grep -h '^UNGRADABLE ' "$WORK"/*/*.part "$WORK"/*/*/*.part 2>/dev/null | sort | uniq -c | sort -rn | head -20
