#!/usr/bin/env bash
# lib_container_package_runner.sh -- THE BODY OF A PACKAGE RUNNER WHOSE PACKAGE IS ONE CONTAINER (ALL.<ext> / ALL.ref / ALL.csv, built by
# util_build_package_suite.py with every ref cut from the oracle). Sourced by the Rosetta runners (Lon 2026-10-09, in-chat to the coo,
# verbatim: "Let's get rosseta for both Pascal and Prolog on the official test suite banner. Graded against the oracle."), each of which
# keeps its own one-runner guard on line 2 and calls:
#
#   container_package_run <lang> <ext> <suite-key> <suite-dir> <gate-name>
#
# It grades the container in both modes through corpus_suite_harness.py run (the one grader: declared heap and stack from ALL.csv, the
# timeout retry, the per-program progress rows), prints the board line and the inventory, and writes the suite row through
# util_score_row.py: THE AND PER PROGRAM over the programs the oracle grades, with a program a ruled class excludes named in EXCLUDED.tsv
# by a ruled class and shown as Excl, so shipped = denominator + Excl; every other ungraded program stays in as debt. rc: the harness's, 2 refused.
#
# CPR_DEPTH=2 (default 1): the package ships its programs one directory down (category/NAME.<ext>, the Icon packages' layout); a unit is then keyed
# category/NAME as the container's ALL.csv keys it (hq_unicon, CEO-2072).
#
# container_package_excl <suite-dir> <ext> -- echo "<excl> <containers>": Excl is the EXCLUDED.tsv rows plus every CONTAINERS.tsv fragment
# shipped as <name>.<ext> beside the container and not already named in EXCLUDED.tsv (CEO-1288: Excl is every shipped unit a row leaves out,
# so shipped = denominator + Excl as jcon, arizona, gnu and ipl read; the coo 2026-10-10: rosetta-prolog published 220/786 with Excl 0 over
# 9 containers). Both files are read through lib_inventory.sh, the one reader; rc 2 when either is refused. Gate:
# test_gate_container_package_runner_counts_its_containers_as_excl.sh.
container_package_excl() {
  local suite="$1" ext="$2" conts exnames nex=0 ncont=0 f
  conts="$(inventory_container_names "$suite")" || return 2
  exnames="$(inventory_excluded_names "$suite")" || return 2
  [ -f "$suite/EXCLUDED.tsv" ] && nex=$(grep -vc -E '^#|^\s*$' "$suite/EXCLUDED.tsv")
  if [ -n "$conts" ]; then
    while IFS= read -r f; do
      grep -qxF -- "$f" <<<"$conts" || continue
      grep -qxF -- "$f" <<<"$exnames" && continue
      ncont=$((ncont + 1))
    done < <(find "$suite" -maxdepth 1 -name "*.$ext" ! -name "ALL.$ext" -printf '%f\n')
  fi
  echo "$((nex + ncont)) $ncont"
}
container_package_run() {
  local lang="$1" ext="$2" key="$3" suite="$4" gate="$5"
  local here sd board rc out field_ scored shipped excl denom bothp m3p m4p inv cc
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; sd="$here/../../SCRIP"
  export TIMEOUT_RETRY="${TIMEOUT_RETRY:-$here/util_timeout_retry.sh}"
  . "$here/lib_inventory.sh" 2>/dev/null || { echo "⛔ REFUSE(rc=2): lib_inventory.sh unloadable"; return 2; }
  [ -x "$sd/scrip" ] || { echo "⛔ REFUSE(rc=2): no scrip binary at $sd/scrip -- build first (make)"; return 2; }
  "$here/util_require_fresh.sh" --gate "$gate" "$sd/scrip" "${RT_DIR:-$sd/out}/libscrip_rt.so" || return 2
  [ -f "$suite/ALL.$ext" ] && [ -f "$suite/ALL.ref" ] || { echo "⛔ REFUSE(rc=2): no container at $suite/ALL.{$ext,ref} -- run: python3 ../harness/scripts/util_build_package_suite.py $suite --lang $lang --twice"; return 2; }
  # ⛔⭐ ONE CHUNK, NOT THE SUITE (ceo CEO-1802, Lon 2026-10-15 via the ceo: "Why are we running suites at a time versus sets/blocks at a time in a round
  # robin approach?"): S4E_CHUNK=chunk:NN grades that stored PARTITION.tsv chunk of the container in both modes through the harness, which appends one
  # progress row per program and mode stamped partition=chunk:NN, and writes NO suite row -- util_score_row.py from-progress --suite <key> assembles the
  # row from the latest per-program readings, shipped minus EXCLUDED as below (the coo's verifier loop runs it after every chunk).
  if [ -n "${S4E_CHUNK:-}" ]; then
    case "$S4E_CHUNK" in core|core@*|chunk:[0-9]*|entry:*) ;; *) echo "⛔ REFUSE(rc=2): S4E_CHUNK=$S4E_CHUNK is not core[@entry], chunk:NN[@entry] or entry:<name>[,entry:<name>...] (a request, CEO-1806)"; return 2;; esac
    [ -f "$suite/PARTITION.tsv" ] || { echo "⛔ REFUSE(rc=2): no $suite/PARTITION.tsv -- build it: python3 ../harness/scripts/util_suite_partition.py build $suite/ALL.csv"; return 2; }
    out="$(cd "$sd" && SUITE_LIST_ALL=1 python3 ../harness/scripts/corpus_suite_harness.py run "$suite/ALL.$ext" "$suite/ALL.ref" --lang "$lang" --modes m3,m4 --partition "$S4E_CHUNK" 2>&1)"; rc=$?
    printf '%s\n' "$out"
    printf '%s\n' "$out" | grep -q '^SUITE_BOARD ' || { echo "⛔ REFUSE(rc=2): corpus_suite_harness.py printed no SUITE_BOARD line for $S4E_CHUNK (above) -- nothing measured"; return 2; }
    echo "$(printf '%s' "$key" | tr 'a-z-' 'A-Z_')_CHUNK $S4E_CHUNK graded: one progress row per program and mode; no suite row from a chunk -- the row is util_score_row.py from-progress --suite $key (CEO-1802)"
    return "$rc"
  fi
  local cpr_depth="${CPR_DEPTH:-1}"
  shipped=$(find "$suite" -maxdepth "$cpr_depth" -name "*.$ext" ! -name "ALL.$ext" | wc -l)
  local conts xc ncont
  conts="$(inventory_container_names "$suite")" && xc="$(container_package_excl "$suite" "$ext")" \
    || { echo "⛔ REFUSE(rc=2): $suite/CONTAINERS.tsv or EXCLUDED.tsv is refused (the reader said why above) -- no row over an unread exclusion"; return 2; }
  excl="${xc% *}"; ncont="${xc#* }"
  out="$(cd "$sd" && SUITE_LIST_ALL=1 python3 ../harness/scripts/corpus_suite_harness.py run "$suite/ALL.$ext" "$suite/ALL.ref" --lang "$lang" --modes m3,m4 2>&1)"; rc=$?
  printf '%s\n' "$out"
  board="$(printf '%s\n' "$out" | grep -m1 '^SUITE_BOARD ')"
  [ -n "$board" ] || { echo "⛔ REFUSE(rc=2): corpus_suite_harness.py printed no SUITE_BOARD line (above) -- nothing measured, no row written"; return 2; }
  field_() { printf '%s\n' "$board" | grep -oE " $1=[0-9]+" | head -1 | cut -d= -f2; }
  scored="$(field_ total)"; bothp="$(field_ all_pass)"; m3p="$(field_ m3_pass)"; m4p="$(field_ m4_pass)"
  # ⛔⭐ THE NUMERATOR IS TAKEN OVER THE SAME POPULATION AS THE DENOMINATOR (the coo 2026-10-14, CEO-1696): an EXCLUDED.tsv program the container
  # still grades (puzzles' 251 OUTSIDE_CLPFD, CEO-1593: "graded and its verdicts named, and it leaves pass, fail and the denominator") was counted in
  # the harness's all_pass while the denominator left it out -- puzzles read 26 over a population holding 16 graded programs. The harness lists every
  # non-PASS entry per mode (SUITE_LIST_ALL=1); the passes are the graded entries outside EXCLUDED.tsv that no line names, in each mode and in both.
  local _gl _ex popg
  _gl="$(cd "$sd" && S4E_PROGRESS_OFF=1 python3 ../harness/scripts/corpus_suite_harness.py list "$suite/ALL.$ext" "$suite/ALL.ref" --lang "$lang" 2>/dev/null)"
  _ex="$(inventory_excluded_names "$suite")" || { echo "⛔ REFUSE(rc=2): $suite/EXCLUDED.tsv is refused (the reader said why above)"; return 2; }
  if [ -n "$_ex" ] && [ -n "$(comm -12 <(printf '%s\n' "$_gl" | sort -u) <(printf '%s\n' "$_ex" | sed "s/\.$ext\$//" | sort -u))" ]; then
    read -r popg bothp m3p m4p < <(python3 - "$ext" <(printf '%s\n' "$_gl") <(printf '%s\n' "$_ex") <(printf '%s\n' "$out") <<'PYEX'
import re, sys
ext, gl, ex, out = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
graded = [l.strip() for l in open(gl) if l.strip()]
excl = {re.sub(r"\.%s$" % re.escape(ext), "", l.strip()) for l in open(ex) if l.strip()}
red = {"m3": set(), "m4": set()}
for l in open(out, errors="replace"):
    m = re.match(r"^  (\S+?)(?:\([^)]*\))? (m3|m4) (\S+): ", l)
    if m and not m.group(1).startswith("XPASS"):
        red[m.group(2)].add(m.group(3))
pop = [g for g in graded if g not in excl]
print(len(pop), sum(1 for g in pop if g not in red["m3"] and g not in red["m4"]), sum(1 for g in pop if g not in red["m3"]), sum(1 for g in pop if g not in red["m4"]))
PYEX
)
    echo "NUMERATOR OVER THE DENOMINATOR'S POPULATION: $popg graded program(s) outside EXCLUDED.tsv (of $(field_ total) the container grades): both $bothp, m3 $m3p, m4 $m4p (the board's all_pass $(field_ all_pass) counted the excluded ones too)"
  fi
  # ⭐ THE POPULATION IS SHIPPED TOO (CEO-749/1286, test_gate_score_row_denominator_includes_xfails.sh): every shipped program the container does
  # not grade gets one UNGRADED progress row per mode, its class from UNGRADABLE.tsv or UNGRADED.tsv, before the row is written
  . "$here/lib_progress.sh" 2>/dev/null || { echo "⛔ REFUSE(rc=2): lib_progress.sh unloadable"; return 2; }
  local graded_list ung_rows n cls cfg exnames
  # ⛔ AND EACH DECLARES ITS CONFIGURATION, as the harness's graded rows do (the coo 2026-10-10: these rows went in `undeclared` 2-3 s after
  # the lane's declared rows, and test_gate_progress_configuration_declarations_do_not_regress.sh read rosetta-pascal, rosetta-prolog,
  # puzzles and trealla as lanes that stopped declaring); rows-tsv's ninth column, from the ONE reader of the environment
  cfg="$(progress_config_of_env)"
  graded_list="$(cd "$sd" && S4E_PROGRESS_OFF=1 python3 ../harness/scripts/corpus_suite_harness.py list "$suite/ALL.$ext" "$suite/ALL.ref" --lang "$lang" 2>/dev/null)"
  # ⭐ AN EXCLUDED PROGRAM THE CONTAINER DOES NOT GRADE WRITES NO ROW (ceo CEO-1696: a program with no oracle answer is EXCLUDED, never debt): it is out
  # of the denominator as a CONTAINERS.tsv fragment is, so an UNGRADED row for it would put it back into the population the audit tallies
  exnames="$(inventory_excluded_names "$suite")" || { echo "⛔ REFUSE(rc=2): $suite/EXCLUDED.tsv is refused (the reader said why above)"; return 2; }
  ( ung_rows="$(mktemp)"; trap 'rm -f "$ung_rows"' EXIT   # a subshell trap: this library is sourced, so an EXIT trap here must not replace the caller's
  while IFS= read -r f; do
    n="${f#"$suite"/}"; n="${n%".$ext"}"; grep -qxF "$n" <<<"$graded_list" && continue; grep -qxF -- "$n.$ext" <<<"$conts" && continue
    grep -qxF -- "$n.$ext" <<<"$exnames" && continue
    cls="$(awk -F'\t' -v k="$n.$ext" '$1==k {print $2; exit}' "$suite/UNGRADABLE.tsv" "$suite/UNGRADED.tsv" 2>/dev/null)"
    printf 'package\t%s\t%s\t%s\tm3\tUNGRADED\t0\t%s\t%s\npackage\t%s\t%s\t%s\tm4\tUNGRADED\t0\t%s\t%s\n' "$key" "$lang" "$n" "${cls:-unclassed}" "$cfg" "$key" "$lang" "$n" "${cls:-unclassed}" "$cfg" >> "$ung_rows"
  done < <(find "$suite" -maxdepth "$cpr_depth" -name "*.$ext" ! -name "ALL.$ext" | sort)
  [ -s "$ung_rows" ] && { progress_append_rows_tsv "$ung_rows" || echo "⚠ the UNGRADED progress rows were not appended (reason above) -- the row write's cross-check reads the graded population only" >&2; } )
  # the denominator is SHIPPED (CEO-1286): a program the container does not grade is named in UNGRADED.tsv and stays in as debt; a program a
  # ruled EXCLUDED.tsv class names (NO_ORACLE_ANSWER for every UNGRADABLE.tsv row since CEO-1696), or a CONTAINERS.tsv fragment, leaves it, shown as Excl
  denom=$((shipped - excl))
  echo "$(printf '%s' "$key" | tr 'a-z-' 'A-Z_')_BOARD shipped=$shipped graded=$scored excluded=$excl containers=$ncont denominator=$denom both_pass=$bothp m3_pass=$m3p m4_pass=$m4p"
  INV_PACKAGE="$key"; INV_DIR="$suite"; INV_EXT=".$ext"
  inv="$(inventory_line "$scored" 0)"
  if [ -n "$inv" ]; then echo "$inv"; else echo "⚠ inventory refused (above) -- the board line still stands; the inventory does not" >&2; fi
  cc="${S4E_CRITERION_CHANGED:-}"
  python3 "$here/util_score_row.py" write --lang "$lang" --column vendor --suite "$key" --suite-key "$key" --modes m3,m4 \
      ${cc:+--criterion-changed "$cc"} --suite-pass "$bothp" --suite-total "$denom" --excluded "$excl" --measurer "${S4E_SEAT:-}" \
      --text "$key both-modes $bothp/$denom · m3 $m3p/$denom · m4 $m4p/$denom ($scored graded of $shipped shipped, the rest named in UNGRADED.tsv as debt, EXCLUDED=$excl of which $ncont CONTAINERS.tsv fragments and the rest ruled classes -- NO_ORACLE_ANSWER (CEO-1696) for every program the oracle gives no answer${inv:+ · $inv} (\`$gate.sh\`))" \
      || echo "⚠ SCORE.md NOT UPDATED -- record this row by hand (the REFUSED line above says why)"
  return "$rc"
}
