#!/usr/bin/env bash
# test_gate_swi_runner_grades_a_signal_death_crash_never_fail.sh -- A SWI CASE THE RUN NEVER REACHED BECAUSE THE RUN DIED IS CRASH (OR
# HANG), NEVER FAIL, IN THE CASE ROW, THE BOARD LINE AND THE PROGRESS ROW (the coo 2026-09-27, ceo CEO-1309: "the SWI runner's
# grade_one never captures the run's exit status, so a signal death grades FAIL, never CRASH"; the verdict ladder: CRASH never
# collapses into FAIL).
#
#   M   util_swi_match.py with the run's status: a two-case file whose run reported case 1 and then died on SIGSEGV grades case 1 PASS
#       and case 2 CRASH, and rc 124 grades the silent case HANG; FAIL-ONCE inside the arm: without the status (the old three-argument
#       call) case 2 reads FAIL, so the arm can tell the two apart
#   G   test_prolog_swi_suite.sh's own grade_one, LIFTED OUT OF THE RUNNER BY sed (never copied) and run against a stub scrip that prints
#       case 1's pass line and kills itself with SIGSEGV: its m3 case rows read PASS then CRASH
#   A   the runner's own aggregator, lifted the same way, over G's output: the progress row for case 2 carries CRASH and the board line
#       prints m3_crash=1 and m3_fail=0 -- the aggregator collapsed every non-PASS into FAIL before this landing
# The runner itself is never run here: its scrip is fixed at ../scrip, and the two lifted bodies are every line a status passes through.
# FAIL-ONCE, MEASURED 2026-09-27 (coo) against origin 13f04d788's runner and matcher, copied beside this gate in a scratch directory:
# 0 of 3 -- the old matcher refuses a fourth argument, grade_one grades case 2 FAIL, the aggregator records FAIL and m3_fail=1.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G=swi_runner_grades_a_signal_death_crash_never_fail
R="$HERE/test_prolog_swi_suite.sh"; MP="$HERE/util_swi_match.py"
unproven() { echo "GATE UNPROVEN(2) [$G]: $*"; exit 2; }
[ -f "$R" ] && [ -f "$MP" ] || unproven "the runner or the matcher is missing"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_swicrash.XXXXXX")" || unproven "mktemp failed"
trap 'rm -rf "$W"' EXIT
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ✅ $1: $2"; }
red() { FAIL=$((FAIL+1)); echo "  ⛔ $1 RED: $2"; }
S="$W/swit"; mkdir -p "$S/core"
printf ':- begin_tests(u).\ntest(t1) :- true.\ntest(t2) :- true.\n:- end_tests(u).\n' > "$S/core/a.pl"
printf 'PASS u:t1\nPASS u:t2\n' > "$S/core/a.ref"
printf 'rank,entry,origin,package,n_lines,stdin,want_rc,heap_kb,stack_kb,compile_args,run_args\n1,core/a,swi__core/a,swi_tests,4,0,0,131072,4096,,\n' > "$S/ALL.csv"
printf '  pass: u:t1\n' > "$W/one.out"

# ── M: the matcher ──────────────────────────────────────────────────────────────────────────────────────────────────────────
v() { awk -F'\t' -v k="$2" '$1==k {print $2}' <<<"$1"; }
m_seg="$(python3 "$MP" "$S/core/a.pl" "$S/core/a.ref" "$W/one.out" 139)"; m_hang="$(python3 "$MP" "$S/core/a.pl" "$S/core/a.ref" "$W/one.out" 124)"
m_old="$(python3 "$MP" "$S/core/a.pl" "$S/core/a.ref" "$W/one.out")"
if [ "$(v "$m_seg" 'u:t1#1')" = PASS ] && [ "$(v "$m_seg" 'u:t2#1')" = CRASH ] && [ "$(v "$m_hang" 'u:t2#1')" = HANG ] && [ "$(v "$m_old" 'u:t2#1')" = FAIL ] \
   && grep -q ' crash=1 hang=0$' <<<"$m_seg"; then
    ok M "rc 139 grades the reported case PASS and the silent one CRASH, rc 124 HANG; without a status the silent case reads FAIL (fail-once)"
else
    red M "rc139: t1=$(v "$m_seg" 'u:t1#1') t2=$(v "$m_seg" 'u:t2#1'); rc124: t2=$(v "$m_hang" 'u:t2#1'); no rc: t2=$(v "$m_old" 'u:t2#1') (want PASS CRASH HANG FAIL)"
fi

# ── G: the runner's grade_one, lifted ───────────────────────────────────────────────────────────────────────────────────────
sed -n "/^cat > \"\$WORK\/grade_one.sh\" <<'GEOF'\$/,/^GEOF\$/p" "$R" | sed '1d;$d' > "$W/grade_one.sh"
[ -s "$W/grade_one.sh" ] || unproven "could not lift grade_one out of $R -- its heredoc moved"
printf '#!/usr/bin/env bash\nprintf "  pass: u:t1\\n"\nkill -SEGV $$\n' > "$W/stub_scrip"; chmod +x "$W/stub_scrip"
WK="$W/work"; mkdir -p "$WK"
env SCRIP="$W/stub_scrip" RT="$W" PLUNIT="$W/none.pl" WORK="$WK" SWIT="$S" MATCH_PY="$MP" LIB_DECL="$HERE/lib_declared_arena.sh" \
    bash "$W/grade_one.sh" "$S/core/a.pl" m3 > "$W/g.out" 2>&1
g="$(cat "$WK/out/core/a/m3.tsv" 2>/dev/null)"
[ "$(v "$g" 'u:t1#1')" = PASS ] && [ "$(v "$g" 'u:t2#1')" = CRASH ] && ok G "the runner's own grade_one grades a run that died on SIGSEGV: case 1 PASS, case 2 CRASH" \
    || red G "grade_one's m3 rows: t1=$(v "$g" 'u:t1#1') t2=$(v "$g" 'u:t2#1') (want PASS CRASH) $(head -2 "$W/g.out" | tr '\n' ' ')"

# ── A: the runner's aggregator, lifted, over G's output ─────────────────────────────────────────────────────────────────────
sed -n "/^python3 - \"\$WORK\" \"\$FILES\" \"\$MODES\" \"\$SWIT\" \"\$NAME_REDS\" <<'PY'\$/,/^PY\$/p" "$R" | sed '1d;$d' > "$W/agg.py"
[ -s "$W/agg.py" ] || unproven "could not lift the aggregator out of $R -- its heredoc moved"
printf '%s\n' "$S/core/a.pl" > "$W/files.txt"
ao="$(cd "$W" && python3 "$W/agg.py" "$WK" "$W/files.txt" m3 "$S" 0 2>&1)"
rw="$(cat "$WK/rows.tsv" 2>/dev/null)"
c2="$(awk -F'\t' '$4 ~ /u:t2#1$/ {print $6}' <<<"$rw")"
if [ "$c2" = CRASH ] && grep -q 'm3_crash=1' <<<"$ao" && grep -q 'm3_fail=0' <<<"$ao"; then
    ok A "the aggregator records case 2 as CRASH in its progress row and prints m3_crash=1 m3_fail=0"
else
    red A "progress row outcome for case 2 [${c2:-none}], board: $(grep -o 'm3_[a-z_]*=[0-9]*' <<<"$ao" | tr '\n' ' ') (want the outcome CRASH, and the board's m3 crash count 1 and fail count 0)"
fi

echo "GATE $([ "$FAIL" = 0 ] && echo PASS || echo "FAIL($FAIL)") [$G]: $PASS of $((PASS + FAIL)) arms green (population: the matcher, the runner's grade_one and its aggregator)"
[ "$FAIL" = 0 ]
