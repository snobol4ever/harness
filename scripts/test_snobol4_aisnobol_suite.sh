#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" "${AISNOBOL_SUITE:=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/corpus/packages/snobol4/aisnobol}" || exit 2
# ⛔ THE STATEMENT INSTRUMENTATION (--stlimit) IS EACH PROGRAM'S OWN compile_args DECLARATION, read per program below (clause 8 (f), CEO-1281): this runner exported SCRIP_SNO_STMTKW=1 for every program until 2026-09-26 (Lon 2026-09-24 16:0x: off by default, never inferred from the source)
# test_snobol4_aisnobol_suite.sh -- thin face over corpus_suite_harness.py for corpus/packages/snobol4/aisnobol
# (task every-vendored-package-absorbed-into-the-one-liner-or-multi-liner-python-harness-with-oracle-cut-refs,
# hq_T doorbell 2026-09-04, Lon verbatim: "You make the programs run, you measure the output, make a REF file,
# and place it into a ONE-LINER or a MULTI-LINER Python test harness."). SUPERSEDES the live-oracle-diff
# version of this script (git history holds it): the ALL.sno/ALL.ref container is built once by
# util_build_package_suite.py, with refs CUT FROM THE ORACLE (never hand-typed, never SCRIP's own output --
# see that script's header for the exclusion reasons), and this script becomes a thin face over the one
# suite grammar/grading authority (corpus_suite_harness.py) instead of a second, hand-rolled comparison
# loop duplicating oracle-invocation logic that already lives there.
#
# Regenerate the container (only needed if the shipped programs or the oracle changed):
#   python3 ../harness/scripts/util_build_package_suite.py ../corpus/packages/snobol4/aisnobol
#
# Population: 8 shipped .sno programs. absorbed + excluded == shipped is asserted by the builder itself
# (refuses otherwise) -- not re-checked here, this script only grades what the container already holds.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; SD="$HERE/../../SCRIP"; ROOT="$(cd "$HERE/../.." && pwd)"   # the root holds its repos as siblings, SCRIP or not
export TIMEOUT_RETRY="${TIMEOUT_RETRY:-$HERE/util_timeout_retry.sh}"   # a graded run's timeout (CEO-1335): a timeout under load is retried once, util_timeout_retry.sh
. "$HERE/lib_inventory.sh" 2>/dev/null || { echo "⛔ REFUSE(rc=2): lib_inventory.sh unloadable"; exit 2; }
SUITE="${AISNOBOL_SUITE:-$ROOT/corpus/packages/snobol4/aisnobol}"
# ⭐ UNDER A PORT ENGINE THIS RUNNER GRADES THE PORT WITH ITS OWN GRADING (S4E_ENGINE=dotnet|jvm; CEO-1822; Lon 2026-10-18, in-chat to hq_jvm,
# verbatim: "Get all SNOBOL4 test suite package runners working with snobol4jvm."): the harness dispatches each entry to the port's runner, whose
# --binaries is the one check; the port is graded in m3 alone, its rows are keyed aisnobol@<engine> by the harness, and no SCRIP score row is
# written -- the port's row is from-progress. Under scrip every line below reads as it did.
PORT=0; one_runner_is_port && PORT=1
MODES=m3,m4; ROWKEY=aisnobol; [ "$PORT" = 1 ] && { MODES=m3; ROWKEY="aisnobol@$(one_runner_engine)"; }
if [ "$PORT" = 1 ]; then one_runner_port_ready snobol4 || exit 2; cd "$ROOT" || exit 2; else
SCRIP="$SD/scrip"; RT_DIR="$SD/out"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(rc=2): no scrip binary at $SCRIP -- build first (make)"; exit 2; }
# ⛔⭐ STALE-BINARY PREFLIGHT (row harness-and-ladder-runner-refuse-on-a-stale-binary-like-the-artifact-regen-
# does, ceo -> hq_T 2026-09-04). The line above proves a binary EXISTS; this one proves it is the binary this
# tree describes. ceo's witness, twice on 2026-09-04: a 10:57 binary graded at 14:03 read RED, then GREEN after
# an incremental make -- a vendor board is exactly where that is least visible, because a plausible all-FAIL
# table is this class's normal output. NO LOGIC HERE: util_require_fresh.sh sources gate_require_fresh from
# lib_gate.sh, the ONE authority (hq_B 4c7253e99) -- never a second copy of the staleness rule.
"$HERE/util_require_fresh.sh" --gate test_snobol4_aisnobol_suite "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so" || exit 2
[ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ REFUSE(rc=2): no $RT_DIR/libscrip_rt.so"; exit 2; }
cd "$SD" || exit 2
fi

if [ ! -f "$SUITE/ALL.sno" ] || [ ! -f "$SUITE/ALL.ref" ]; then
  echo "⛔ GATE REFUSES(rc=2): no container at $SUITE/ALL.{sno,ref} -- run:" >&2
  echo "   python3 ../harness/scripts/util_build_package_suite.py ${SUITE#"$ROOT"/}" >&2
  exit 2
fi

# ⭐ THE DECLARED HEAP AND STACK are honoured INSIDE the harness: corpus_suite_harness.py reads the ALL.csv beside ALL.sno (heap_kb,
# stack_kb -- heap_declarations(), stack_declarations()) and runs each entry in both modes at its own declaration (CEO-1167, CEO-1225;
# proven for this runner on a fixture by the coo on CEO-1229). Line 2 hands the guard the suite this runner grades (AISNOBOL_SUITE).
# ⭐ S4E_CHUNK (ceo CEO-1802/1806): the round robin's part (core, chunk:NN, either @<entry>) or a request's entry:<a>[,entry:<b>...] -- the harness
# grades that selection, appends each test's rows as it ends, and no suite row is written; util_score_row.py from-progress --suite aisnobol assembles it.
OUT="$(python3 "$HERE/corpus_suite_harness.py" run "$SUITE/ALL.sno" "$SUITE/ALL.ref" --modes "$MODES" ${S4E_CHUNK:+--partition "$S4E_CHUNK"} 2>&1)"
rc=$?
printf '%s\n' "$OUT"
if [ -n "${S4E_CHUNK:-}" ]; then
  printf '%s\n' "$OUT" | grep -q '^SUITE_BOARD ' || { echo "⛔ REFUSE(rc=2): the harness printed no SUITE_BOARD line for $S4E_CHUNK (above) -- nothing measured"; exit 2; }
  echo "AISNOBOL_CHUNK $S4E_CHUNK graded: one progress row per program and mode; no suite row from a chunk -- the row is util_score_row.py from-progress --suite aisnobol (CEO-1802)"
  exit "$rc"
fi

board="$(printf '%s\n' "$OUT" | grep '^SUITE_BOARD ')"
if [ -z "$board" ]; then
  # ⛔ The harness printed no SUITE_BOARD line: it refused before measuring anything (see the REFUSING
  # line in $OUT above for why -- e.g. ALL.csv missing a `modes` column, corpus_suite_harness.py
  # c3948a321). Computing shipped/scored/PASS/FAIL from an empty $board silently manufactures a
  # blank-but-plausible AISNOBOL_BOARD line and, worse, persists it into SCORE.md as a real reading --
  # measured directly 2026-09-05 (seat02): every count field came back empty and still got written to
  # the shared leaderboard. An instrument that refused must say so, not print the pass/fail shape.
  echo "AISNOBOL_BOARD REFUSED -- harness printed no SUITE_BOARD line, see REFUSING output above"
  [ "$PORT" = 1 ] || python3 "$HERE/util_score_row.py" write --lang snobol4 --column vendor --suite aisnobol --modes m3,m4 \
    ${S4E_CRITERION_CHANGED:+--criterion-changed "$S4E_CRITERION_CHANGED"} \
      --measurer "${S4E_SEAT:-}" \
      --text "aisnobol: REFUSED -- corpus_suite_harness.py produced no measurement this run, see \`test_snobol4_aisnobol_suite.sh\` REFUSING output (\`test_snobol4_aisnobol_suite.sh\`)" \
      || echo "WARNING SCORE.md NOT UPDATED -- record this row by hand (the REFUSING line above says why)"
  [ "$rc" -eq 0 ] && rc=2
  exit "$rc"
fi
field() { printf '%s\n' "$board" | grep -oE "$1=[0-9]+" | head -1 | cut -d= -f2; }
scored="$(field total)"
# ⛔ A CONTAINER NAMED IN ALL.excluded.txt IS NOT A SHIPPED PROGRAM EITHER (CEO-1272: SPITCORE.sno is -INCLUDEd by SIR.sno and
# listed in CONTAINERS.tsv), so the excluded count that makes up shipped leaves it out, as lib_inventory.sh does.
excl=0; [ -s "$SUITE/ALL.excluded.txt" ] && excl=$(cut -d: -f1 "$SUITE/ALL.excluded.txt" | grep . | while IFS= read -r _x; do inventory_is_container "$SUITE" "$_x.sno" || echo "$_x"; done | grep -c .)
shipped=$((scored + excl))
m3p="$(field m3_pass)"; m3f="$(field m3_fail)"; m3c="$(field m3_crash)"; m3h="$(field m3_hang)"
m4p="$(field m4_pass)"; m4f="$(field m4_fail)"; m4c="$(field m4_crash)"; m4h="$(field m4_hang)"
[ "$PORT" = 1 ] && { m4p=0; m4f=0; m4c=0; m4h=0; }   # a port has no mode 4, so the harness prints no m4 field

# ⭐ THE SPITBOL BASELINE, MEASURED LIVE (Lon 2026-09-08; ceo ruling 18:49 on this seat's own ask). This runner
# is a thin face over the harness and never ran the oracle per program, so unlike the other package runners it
# had NO live outside set to record -- the shortcut was to declare one from ORACLE_ACCEPTANCE.tsv beside the
# package. THE CEO REFUSED THAT and was right on the facts: a cross-check that reads the file it is checking
# proves nothing, and that file names SPITCORE and spitlib.spt while a live pass names SPITCORE and BUILDLIB.
# ⛔ EACH PROGRAM IS RUN WITH ITS OWN .IN AND .argv. A pass that skips them manufactures refusals: the first
# such pass here flagged HSORT with ERROR 116 purely because it had not supplied HSORT.argv, and a manufactured
# refusal SHRINKS THE DENOMINATOR, which is the direction that flatters us.
# ⛔ THE ORACLE IS RESOLVED HERE, because this runner never had one: it delegates grading to the harness and
# had no SBL/FLAGS of its own. The first cut of this block copied those names from the testpgms runner, where
# they exist, so the oracle command expanded to nothing, every program produced no output, nothing was detected
# as refused, and the cross-check below dutifully reported the RECORD as stale. It reported a disagreement
# rather than a false agreement, which is the only reason the mistake was cheap -- accessors, never a
# hand-assembled path.
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ REFUSE(rc=2): lib_oracle_flags.sh unloadable"; exit 2; }
_SBL="$(sbl_correctness_bin)" || exit 2; _SBLF="$(sbl_lang_flags)"
OUTSIDE_TSV="$SUITE/OUTSIDE_SPITBOL_BASELINE.tsv"; MIRROR_TSV="$SUITE/UNGRADABLE.tsv"; OUTSIDE_LIST=""; OUTSIDE_N=0
_ow="$(mktemp -d)"; cp -a "$SUITE"/. "$_ow/" 2>/dev/null
trap 'rm -rf "$_ow"' EXIT INT TERM
for _f in "$_ow"/*.sno; do
    _n="$(basename "$_f" .sno)"; [ "$_n" = ALL ] && continue
    inventory_is_container "$SUITE" "$_n.sno" && continue   # not a program (CONTAINERS.tsv, CEO-1272): neither inside nor outside the baseline
    _in=/dev/null; for _e in IN in input; do [ -f "$_ow/$_n.$_e" ] && _in="$_ow/$_n.$_e"; done
    _av=""; [ -f "$_ow/$_n.argv" ] && _av="$(cat "$_ow/$_n.argv")"
    _o="$(cd "$_ow" && "$TIMEOUT_RETRY" 20s "$_SBL" $_SBLF "$_n.sno" $_av < "$_in" 2>&1)"; _rc=$?
    _why=""
    case "$_o" in *"No END statement found"*) _why="sbl -bf answers: No END statement found in source file(s)";; esac
    if [ -z "$_why" ]; then _e1="$(printf '%s' "$_o" | grep -oiE 'ERROR +[0-9]+[^)]*' | head -1 | cut -c1-90)"; [ -n "$_e1" ] && _why="$_e1"; fi
    [ -z "$_why" ] && [ "$_rc" -ge 128 ] && _why="killed by signal $((_rc-128))"
    if [ -n "$_why" ]; then OUTSIDE_N=$((OUTSIDE_N+1)); OUTSIDE_LIST="${OUTSIDE_LIST}${_n}\t${_why}\n"; fi
done
rm -rf "$_ow"
if [ "$OUTSIDE_N" -gt 0 ]; then echo "OUTSIDE-SPITBOL-BASELINE ($OUTSIDE_N; name<TAB>the oracle's own refusal, measured this run):"; printf '%b' "$OUTSIDE_LIST" | sed 's/^/OUTSIDE\t/'; fi
if [ -f "$OUTSIDE_TSV" ]; then
    rec="$(awk -F'\t' 'NF>2 && $1 !~ /^#/{sub(/\.sno$/,"",$1); print $1}' "$OUTSIDE_TSV" | sort)"
    live="$(printf '%b' "$OUTSIDE_LIST" | cut -f1 | grep . | sort)"
    stale="$(comm -23 <(printf '%s\n' "$rec") <(printf '%s\n' "$live") | tr '\n' ' ')"
    unrec="$(comm -13 <(printf '%s\n' "$rec") <(printf '%s\n' "$live") | tr '\n' ' ')"
    [ -n "$stale" ] && echo "⚠ OUTSIDE_SPITBOL_BASELINE.tsv STALE -- recorded as unrunnable by the oracle, but it answered cleanly this run: $stale"
    [ -n "$unrec" ] && echo "⚠ OUTSIDE_SPITBOL_BASELINE.tsv UNRECORDED -- the oracle refuses these and the record does not name them; record each with its error and a source check: $unrec"
    [ -z "$stale$unrec" ] && echo "OUTSIDE_SPITBOL_BASELINE.tsv agrees with the measured outside set ($OUTSIDE_N)"
    if [ -f "$MIRROR_TSV" ]; then
        mir="$(awk -F'\t' 'NF>2 && $1 !~ /^#/{print $1}' "$MIRROR_TSV" | sort)"; recn="$(awk -F'\t' 'NF>2 && $1 !~ /^#/{print $1}' "$OUTSIDE_TSV" | sort)"
        [ "$mir" = "$recn" ] || echo "⚠ UNGRADABLE.tsv does not mirror OUTSIDE_SPITBOL_BASELINE.tsv row for row -- the lockdown bucket and the record have drifted; edit them together"
    fi
else echo "⚠ no OUTSIDE_SPITBOL_BASELINE.tsv beside the suite -- the outside-baseline set above is measured, not yet recorded"; fi
echo "AISNOBOL_BOARD shipped=$shipped scored=$scored excluded=$excl m3_PASS=$m3p m3_FAIL=$m3f m3_CRASH=$m3c m3_HANG=$m3h m4_PASS=$m4p m4_FAIL=$m4f m4_CRASH=$m4c m4_HANG=$m4h"
if [ -s "$SUITE/ALL.excluded.txt" ]; then
  echo "EXCLUDED (named, not counted as fail):"
  sed 's/^/  /' "$SUITE/ALL.excluded.txt"
fi

# ⭐ THE PACKAGE LOCKDOWN (Lon 2026-09-06, MASTER-PLAN sec THE PACKAGE LOCKDOWN): shipped is measured
# FRESH from the vendored dir every run, never derived from the container alone -- a file added after
# the container was last built must show up as ungraded, not silently vanish. ALL.sno is the container
# itself, never a shipped program. lib_inventory.sh recomputes shipped/ungraded/ungradable itself from
# UNGRADABLE.tsv/UNGRADED.tsv beside $SUITE -- ALL.excluded.txt above is this harness's own pre-lockdown
# bucket (kept for the board's per-name EXCLUDED listing), no longer the inventory's source of truth.
real_shipped=$(find "$SUITE" -maxdepth 1 -name '*.sno' ! -name 'ALL.sno' | wc -l | tr -d ' ')
[ "$real_shipped" != "$shipped" ] && echo "⚠ CONTAINER STALE: $SUITE ships $real_shipped .sno file(s) now, container knows $shipped -- rebuild: python3 ../harness/scripts/util_build_package_suite.py ${SUITE#"$ROOT"/}"
INV_PACKAGE=aisnobol; INV_DIR="$SUITE"; INV_EXT=".sno"
INV_LINE="$(inventory_line "$scored" 0)"
if [ -n "$INV_LINE" ]; then echo "$INV_LINE"; else echo "⚠ inventory refused (above) -- the board line still stands; the inventory does not" >&2; fi

# ⛔ ONE LEADERBOARD (RULES.md FACT RULE, Lon 2026-09-03 ~16:05: "any run of a test suite by any session
# will update the ONE LEADERBOARD"). Records the board just printed into .github/SCORE.md -- runs nothing
# new. NON-FATAL BY DESIGN (matches test_icon_arizona_suite.sh's own convention): a bookkeeping failure
# must never turn a real measurement into a red gate for a reason unrelated to the code.
bothp="$(printf '%s\n' "$board" | grep -oE 'all_pass=[0-9]+' | head -1 | cut -d= -f2)"; bothp="${bothp:-$m3p}"
# ⛔⭐ CEO-1286 (Lon 2026-09-26): the denominator is SHIPPED minus the programs NOT IN THE SPITBOL DIALECT (EXCLUDED.tsv); BUILDLIB, which
# the oracle refuses on SET() -- a SPITBOL-documented function the x64 fork lacks (manual 5690) -- is SPITBOL dialect and STAYS as debt,
# so this row publishes over shipped and no longer over the harness's scored population alone.
. "$HERE/lib_outside_shape.sh" || exit 2
EXCL_D_N="$(excluded_in_outside "$SUITE" "$(printf '%b' "$OUTSIDE_LIST" | cut -f1)")" || exit 2; DENOM=$((shipped - EXCL_D_N))
echo "EXCLUDED_NOT_SPITBOL_DIALECT=$EXCL_D_N of this run's outside set leave the denominator ($(excluded_names_count "$SUITE") named in $SUITE/EXCLUDED.tsv; Lon 2026-09-26, CEO-1286): pass over $DENOM"
# ⭐ THE ROW'S Excl IS EVERY SHIPPED UNIT THE DENOMINATOR LEAVES OUT (Lon 2026-09-26, "use the Excl column to properly classify
# the exclusions for good reasons only"; CEO-1288): its include fragments of CONTAINERS.tsv (CEO-1272), read off the inventory
# line, plus the EXCLUDED.tsv programs of this run's outside set -- the denominator does not move, only its classification.
CONT_N="$(inventory_containers_of "${INV_LINE:-}")"; EXCL_ROW=$((EXCL_D_N + CONT_N))
_cc="${S4E_CRITERION_CHANGED:-}"; [ -n "$_cc" ] || _cc="$(excluded_shape_stamp aisnobol "$DENOM" "$OUTSIDE_N" "$EXCL_ROW" "$CONT_N")" || exit 2
if [ "$PORT" = 1 ]; then echo "SCORE.md: the $(one_runner_engine) engine writes no SCRIP row -- its row is util_score_row.py from-progress --suite $ROWKEY (CEO-1822), graded in m3 alone"
    if [ "$SUITE" = "$ROOT/corpus/packages/snobol4/aisnobol" ]; then one_runner_port_publish "$ROWKEY"; else echo "SUITES.tsv: scratch suite $SUITE -- not published (only the canonical suite publishes its row)"; fi
else
python3 "$HERE/util_score_row.py" write --lang snobol4 --column vendor --suite aisnobol --modes m3,m4 \
    ${_cc:+--criterion-changed "$_cc"} \
    --suite-pass "$bothp" --suite-total "$DENOM" --excluded "$EXCL_ROW" \
    --measurer "${S4E_SEAT:-}" --text "aisnobol both_modes_pass=$bothp/$DENOM ($shipped shipped minus EXCLUDED=$EXCL_D_N not in the SPITBOL dialect, CEO-1286; OUTSIDE=$OUTSIDE_N kept as debt) . $m3p/$scored m3 . $m4p/$scored m4 SCORED (of $shipped shipped, $excl not in ALL.sno and named) . m3 FAIL=$m3f CRASH=$m3c HANG=$m3h . m4 FAIL=$m4f CRASH=$m4c HANG=$m4h${INV_LINE:+ . $INV_LINE} (\`test_snobol4_aisnobol_suite.sh\`)" \
    || echo "WARNING SCORE.md NOT UPDATED -- record this row by hand (the REFUSED line above says why)"
fi

exit $rc
