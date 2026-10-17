#!/usr/bin/env bash
# lib_rr.sh -- THE ROUND ROBIN'S SEAM IN A BESPOKE RUNNER (ceo CEO-1802/1805/1806; Lon 2026-10-15, verbatim: "Basically the COO should run one test at a
# time and update the test-suite database. Round robin, done and done." and "The COO will have two work inputs, the round-robin and the recently requested
# from other officers and HQ's."). Sourced by a package runner that grades its own programs (not through corpus_suite_harness.py run). Five calls:
#   rr_load <suite-dir>    once, before the population loop: under S4E_CHUNK (core, chunk:NN, either @<entry>, or entry:<a>[,entry:<b>...]) read that selection
#                          from <suite-dir>/PARTITION.tsv; rc 2 (the runner refuses) when the partition is missing or names no such part or entry.
#                          A table with no partition (the benchmarks and the demos: each at most 100 programs, one chunk by rule) takes entry:
#                          selections only, each name a file of the suite dir (a path, or a stem three levels deep at most; CEO-1812)
#   rr_entries             the selection, one name per line, in the PARTITION's order (after a resume, from its entry on): a runner that grades its own
#                          list grades in this order, so the next test an RR_YIELD names is the one the resume starts at and nothing is skipped or repeated
#   rr_admits <name>       in the population loop: rc 0 when no selection is set, or <name> (its stem: directory and extension dropped) is selected
#   rr_flush <rows-tsv>    after each program's rows are written to <rows-tsv>: under S4E_RR=1 or a selection, append them NOW through the one writer and
#                          empty the file, so results.tsv holds every finished test (the row the runner would append at its end is then already there)
#   rr_yield <name>        before grading the next program: rc 0 when a test request waits in S4E_RR_YIELD_DIR during a round-robin run (never during a
#                          request); the runner then prints the RR_YIELD line this prints and stops, and the loop resumes the chunk at <name>
#   rr_over_budget <name>  before grading the next program: rc 0 when the part has run S4E_RR_BUDGET seconds or more since rr_load (never during a request,
#                          which is never split); the runner prints the RR_YIELD line this prints and stops, and the loop resumes the part at <name> on the
#                          member's next turn, so a part of long tests stays a bounded unit (10-17: SWI's chunk:01 is 100 files and about 1,900 cases)
#   rr_selected            rc 0 when a selection is set: the runner writes NO suite row and prints its <KEY>_CHUNK line (rr_end) -- the row is assembled
#                          from the per-program readings by util_score_row.py from-progress (CEO-1802)
#   rr_end <key>           the <KEY>_CHUNK line
RR_SEL=""; RR_SET=""; RR_FROM=""; RR_T0=$SECONDS
rr_load() {
  local d="${1:?rr_load <suite-dir>}" p part rest
  RR_T0=$SECONDS
  [ -n "${S4E_CHUNK:-}" ] || return 0
  p="$d/PARTITION.tsv"
  if [ ! -f "$p" ]; then case "$S4E_CHUNK" in entry:*) ;; *) echo "⛔ REFUSE(rc=2): S4E_CHUNK=$S4E_CHUNK but no $p -- build it: python3 ../harness/scripts/util_suite_partition.py build $d/ALL.csv (a table with no partition takes entry: selections only)"; return 2;; esac; fi
  part="${S4E_CHUNK%%@*}"; RR_FROM=""; [ "$part" != "$S4E_CHUNK" ] && RR_FROM="${S4E_CHUNK#*@}"
  case "$part" in
    core)   # the core is in no chunk, so the round robin gives it a turn of its own
      RR_SEL="$(awk -F'\t' '!/^#/ && $2 == "core" {print $1}' "$p")"
      [ -n "$RR_SEL" ] || { echo "⛔ REFUSE(rc=2): S4E_CHUNK=core: $p has no core entries"; return 2; };;
    chunk:[0-9]*)
      local k="${part#chunk:}" c
      c="$(awk -F'\t' '!/^#/ && $2 ~ /^chunk:/ {print $2}' "$p" | sort -u | awk -F: -v k="$k" '$2+0 == k+0 {print; exit}')"
      [ -n "$c" ] || { echo "⛔ REFUSE(rc=2): S4E_CHUNK=$S4E_CHUNK: $p has no chunk $k"; return 2; }
      RR_SEL="$(awk -F'\t' -v c="$c" '!/^#/ && $2 == c {print $1}' "$p")";;
    entry:*)
      local e names=""; [ -f "$p" ] && names="$(awk -F'\t' '!/^#/ {print $1}' "$p")"; RR_SEL=""
      for e in $(printf '%s' "$part" | tr ',' ' '); do e="${e#entry:}"
        if [ -f "$p" ]; then grep -qxF -- "$e" <<<"$names" || { echo "⛔ REFUSE(rc=2): S4E_CHUNK: $p has no entry '$e'"; return 2; }
        else { [ -f "$d/$e" ] || [ -n "$(find "$d" -maxdepth 3 -type f -name "$e.*" -print -quit 2>/dev/null)" ]; } || { echo "⛔ REFUSE(rc=2): S4E_CHUNK: $d has no program '$e' (no partition: a name is a file path or a stem)"; return 2; }; fi
        RR_SEL="$RR_SEL
$e"; done;;
    *) echo "⛔ REFUSE(rc=2): S4E_CHUNK=$S4E_CHUNK is not core[@entry], chunk:NN[@entry] or entry:<name>[,entry:<name>...]"; return 2;;
  esac
  RR_SEL="$(printf '%s\n' "$RR_SEL" | grep .)"
  if [ -n "$RR_FROM" ]; then
    grep -qxF -- "$RR_FROM" <<<"$RR_SEL" || { echo "⛔ REFUSE(rc=2): S4E_CHUNK=$S4E_CHUNK: '$RR_FROM' is not in $part"; return 2; }
    RR_SEL="$(printf '%s\n' "$RR_SEL" | sed -n "/^$(printf '%s' "$RR_FROM" | sed 's/[][\.*^$/]/\\&/g')\$/,\$p")"
  fi
  RR_SET=" $(printf '%s ' $RR_SEL)"
  echo "PARTITION $S4E_CHUNK: $(printf '%s\n' $RR_SEL | grep -c .) entr(ies) of $p (CEO-1802: one chunk, never the suite's row)"
}
rr_selected() { [ -n "${S4E_CHUNK:-}" ]; }
rr_entries() { [ -n "${S4E_CHUNK:-}" ] && printf '%s\n' $RR_SEL; }
rr_admits() {
  [ -n "${S4E_CHUNK:-}" ] || return 0
  local n="${1##*/}"; n="${n%.*}"
  case "$RR_SET " in *" $n "*|*" $1 "*) return 0;; esac; return 1
}
rr_flush() {
  local f="${1:?rr_flush <rows-tsv>}"
  { [ "${S4E_RR:-}" = 1 ] || [ -n "${S4E_CHUNK:-}" ]; } || return 0
  [ -s "$f" ] || return 0
  progress_append_rows_tsv "$f" > /dev/null || { echo "⚠ rr_flush: the progress rows were not appended (reason above)" >&2; return 1; }
  : > "$f"
}
rr_yield() {
  [ "${S4E_RR:-}" = 1 ] && [ -z "${S4E_REQ:-}" ] && [ -n "${S4E_RR_YIELD_DIR:-}" ] || return 1
  ls "$S4E_RR_YIELD_DIR"/*.req > /dev/null 2>&1 || return 1
  echo "RR_YIELD next=$1 -- a test request waits (CEO-1806); resume with S4E_CHUNK=${S4E_CHUNK%%@*}@$1"
}
rr_over_budget() {
  [ -n "${S4E_CHUNK:-}" ] && [ -n "${S4E_RR_BUDGET:-}" ] && [ -z "${S4E_REQ:-}" ] || return 1
  [ $(( SECONDS - RR_T0 )) -ge "$S4E_RR_BUDGET" ] || return 1
  echo "RR_YIELD next=$1 -- the part's budget of $S4E_RR_BUDGET s is spent ($(( SECONDS - RR_T0 )) s); resume with S4E_CHUNK=${S4E_CHUNK%%@*}@$1"
}
rr_end() { echo "$(printf '%s' "${1:?rr_end <key>}" | tr 'a-z-' 'A-Z_')_CHUNK ${S4E_CHUNK:-} graded: one progress row per program and mode; no suite row from a chunk -- the row is util_score_row.py from-progress --suite $1 (CEO-1802)"; }
