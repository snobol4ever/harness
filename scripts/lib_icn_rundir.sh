# lib_icn_rundir.sh -- THE ONE AUTHORITY for the RUN DIRECTORY a corpus/tests/icon witness is graded in.
#
# ⛔⛔ WHY THIS EXISTS: several rung36_jcon_* witnesses are REAL-WORLD I/O PROGRAMS that read their own
# working directory, their own source text, their own environment and their own argv. Graded with none of
# that present they still produce a full, plausible, ORDERLY answer -- they just stop early, at the point
# where they gave up. rung36_jcon_recent starved this way prints 313 lines whose LAST line is
# `can't open recent.dat`, and the oracle starved the same way prints the same 313 lines, so the two
# AGREED and the witness read PASS for months (hq_I, FINDING-2026-09-10). ⭐ AGREEING ABOUT WHERE YOU BOTH
# GAVE UP IS NOT AGREEMENT ABOUT THE PROGRAM, and it is invisible to every check a runner normally makes:
# the output is non-empty, well formed, byte-identical and stable across runs.
#
# ⛔ THE THREE RUNNERS EACH CARRIED THEIR OWN COPY of the one line that looked up the stdin sidecar
# (test_icon_all_rungs.sh, test_icon_rung_suite.sh, test_icon_mode4_rung.sh -- byte-identical `[ -f ... ]
# || ...config/...` in all three). That is the shape lib_icon_ipl_isolation.sh's own header names as how
# test_prolog_ladder.sh and its Raku twin silently diverged. A witness whose ref was cut under a contract
# ONE runner honours and another does not is a ref that grades two different programs, so the contract
# has to be readable from exactly one place -- this file.
#
# ⭐ NO NEW SIDECAR FORMATS. argv and fixture files already have a declared format and a written reader in
# lib_icon_ipl_isolation.sh (NAME.argv, NAME.fixtures/), authored for ipl but keyed only on the .icn path.
# This file SOURCES those readers rather than restating them, so a witness fixture cannot mean one thing
# under ipl and another here. Only NAME.env is new, because nothing yet declared environment.
#
# THE CONTRACT, all four parts OPTIONAL and all resolved beside the .icn (stdin additionally falls back to
# the historical config/ location, which is where every existing tests/icon stdin sidecar lives):
#   NAME.stdin  or config/NAME.stdin   bytes fed on stdin           (absent -> /dev/null)
#   NAME.argv                          one line NAME<TAB>arg<TAB>…  (absent -> no program arguments)
#   NAME.fixtures/                     files copied into the rundir (absent -> an empty rundir)
#   NAME.env                           VAR=value per line           (absent -> the caller's environment)
#
# USAGE:
#   . lib_icn_rundir.sh
#   icn_rundir_stdin "$icn"                    # echoes the stdin path, or /dev/null
#   icn_rundir_make  "$icn" "$parent"          # echoes a FRESH rundir under $parent, fixtures staged
#   icn_rundir_argv  "$icn" ARR                # 0 read / 1 none / 2 malformed
#   icn_rundir_env   "$icn" ARR                # 0 read / 1 none / 2 malformed
#   icn_rundir_declares "$icn"                 # 0 if ANY of stdin/argv/fixtures/env is declared
#
# ⛔ EVERY MALFORMED DECLARATION REFUSES WITH 2 AND NEVER FALLS BACK TO "no contract". A witness graded
# under a contract that silently failed to arm is the starvation defect wearing the cure's clothes -- it
# would print the same orderly wrong answer, and this time with a sidecar on disk saying otherwise.

_ICN_RUNDIR_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$_ICN_RUNDIR_HERE/lib_icon_ipl_isolation.sh"

# The historical two-place lookup, stated ONCE. Beside the .icn wins; config/ is where the tests/icon
# stdin sidecars have always lived. Echoes nothing and returns 1 when neither exists.
icn_sidecar_path() {
  local icn="$1" ext="$2" base name
  base="${icn%.icn}"; name="$(basename "$base")"
  if [ -e "$base.$ext" ]; then printf '%s\n' "$base.$ext"; return 0; fi
  if [ -e "$(dirname "$base")/config/$name.$ext" ]; then printf '%s\n' "$(dirname "$base")/config/$name.$ext"; return 0; fi
  return 1
}

icn_rundir_stdin() {
  local p; p="$(icn_sidecar_path "$1" stdin)" && [ -f "$p" ] && { printf '%s\n' "$p"; return 0; }
  printf '%s\n' /dev/null
}

# Delegates to the ipl readers so the FORMAT has exactly one implementation (see header). Both accept a
# .icn path and derive the sidecar beside it, which is where this contract puts them too.
icn_rundir_argv() { ipl_argv_read "$1" "$2"; }

# NAME.heap and NAME.stack -- the witness's declared heap and stack (ceo CEO-1353, RULES.md clause 8 (g)(1)), one line NAME<TAB>KB each,
# read by lib_declared_arena.sh's declared_switches_beside (the harness's own reader, never a copy). Fills the array with SPITBOL's
# switch words (-d<kb>k -s<kb>k) for the runner to place after scrip --run in m3 and at the head of the binary's argv, before a --,
# in m4 -- never SCRIP_HEAP_KB, the collector's window. rc 0 declared, 1 none (the runner NAMES it and runs at the shipped default),
# 2 malformed (the reader said why; the runner refuses).
icn_rundir_sizes() {
    local _w
    declare -F declared_switches_beside >/dev/null || . "$(dirname "${BASH_SOURCE[0]}")/lib_declared_arena.sh" || return 2
    _w="$(declared_switches_beside "$1")" || return 2
    [ -n "$_w" ] || return 1
    read -r -a "$2" <<<"$_w"
    return 0
}

# NAME.env -- VAR=value, one per line, blank and #-comment lines ignored. The array is filled with the
# raw VAR=value words, ready for `env "${arr[@]}" cmd`.
icn_rundir_env() {
  local icn="$1" arr="$2" side line n=0
  eval "$arr=()"
  side="${icn%.icn}.env"
  [ -f "$side" ] || return 1
  while IFS= read -r line; do
    case "$line" in ''|'#'*) continue ;; esac
    case "$line" in
      # ⛔ ANCHORED AND FULLY SPELLED OUT. The obvious glob [A-Za-z_]*=* accepts `this is not VAR=value`
      # -- one leading letter, then anything, then an '=' -- and arms an "environment variable" whose name
      # contains spaces. It was written that way here and my own negative test caught it: the gate reported
      # a wrong ANSWER (rc=1) instead of a malformed DECLARATION (rc=2), which sends a reader hunting a
      # compiler bug over a typo in a sidecar.
      *) case "${line%%=*}" in
           ''|*[!A-Za-z0-9_]*|[0-9]*) echo "⛔ ENV SIDECAR REFUSES(2): $side line '$line' is not VAR=value ('${line%%=*}' is not a variable name) -- refusing to guess an environment" >&2; return 2 ;;
         esac
         case "$line" in *=*) ;; *) echo "⛔ ENV SIDECAR REFUSES(2): $side line '$line' has no '=' -- refusing to guess an environment" >&2; return 2 ;; esac
         eval "$arr+=(\"\$line\")"; n=$((n+1)) ;;
    esac
  done < "$side"
  [ "$n" -gt 0 ] && return 0
  echo "⛔ ENV SIDECAR REFUSES(2): $side declares no variables -- an empty environment is what you get with no sidecar at all, so the file states nothing" >&2
  return 2
}

# ⛔⭐⭐ STDIN IS PART OF THE CONTRACT, AND LEAVING IT OUT MADE THE CONTRACT'S OWN GATE BLIND TO IT (hq_P
# 2026-09-10, on the coo's routed finding from the rung36_jcon_io ref cut). This predicate used to test argv,
# fixtures and env ONLY. Two consequences, and the second is the one nobody would have gone looking for:
#   (1) A WITNESS FED ON STDIN RAN IN THE SHARED SCRATCH. Its answer depends on an input that is not in its
#       source, which is the whole definition of environment-dependent, yet it was not a contract-bearing
#       witness -- so it got the cwd whose contents are whatever ran before it. MEASURED on the live corpus:
#       8 witnesses carry a stdin sidecar, 6 of them declared nothing else, and 4 of those 6 have an answer
#       that PROVABLY changes with stdin (btrees, others, prefix, recogn -- discriminated by running each
#       twice with different stdin, with a same-input control first so nondeterminism could not be reported
#       as dependence). rung36_jcon_io asserts that open("tmp1") FAILS; a sibling's litter is a wrong answer.
#   (2) `test_gate_icn_rundir_contract.sh` DISCOVERS ITS POPULATION WITH THIS PREDICATE (`icn_rundir_declares
#       "$icn" && WITNESSES+=(...)`). So the gate that exists to police the run-directory contract could not
#       see a stdin-only witness AT ALL -- it graded 2 of the 8. ⭐ A guard and its own canary must not share
#       a failure mode; here they were the same line of code, so the blind spot was perfectly silent.
# ⛔ THE NAIVE FIX MATCHES NOTHING AND LOOKS LIKE IT WORKED: `[ -e "$base.stdin" ]` finds ZERO of the eight,
# because every stdin sidecar in tests/icon lives in `config/`. The two-place lookup is stated once, in
# icn_sidecar_path, and this predicate must ask THE SAME QUESTION `icn_rundir_stdin` answers -- or the bus
# feeds a file the contract says is not declared, which is the two-instruments-one-question defect again.
# ⛔⭐ A SUITE CONTAINER IS NOT A WITNESS, AND ITS SIDECARS ARE A DIFFERENT CONTRACT WITH THE SAME EXTENSION
# (hq_V 2026-09-12, CEO-604, on hq_T's census: test_gate_icn_rundir_contract REFUSED rc=2 fleet-wide).
# TWO readers share `.argv` and they disagree by design. `NAME.argv` beside a WITNESS `NAME.icn` is ONE
# program's argv and must name NAME -- ipl_argv_read refuses anything else as a copied sidecar arming the
# wrong program, which is a refusal worth having. `ALL.argv` beside the RUNGS `ALL.icn` is the PER-ENTRY
# table read by corpus_suite_harness.read_argv_sidecar, keyed on ENTRY names; it names `ALL` nowhere and
# never could. A rung suite is a CONTAINER, never compiled whole (CLAUDE.md), and the same is true of its
# sidecars -- so pointing the witness reader at one is a category error, not a malformed file.
# ⭐ THE DISCRIMINATOR IS THE ENTRY TABLE, NOT THE NAME "ALL": a container is the thing that ships a
# per-entry provenance table beside it. Measured over corpus/tests/icon -- exactly one of the 9 .icn files
# declaring a contract has a sibling .csv, and it is precisely the one being mis-enumerated. A name-based
# test would have to be re-taught every time a family is renamed; this one cannot drift.
icn_rundir_is_container() {
  local base="${1%.icn}"
  [ -f "$base.csv" ]
}
icn_rundir_declares() {
  local base="${1%.icn}"
  icn_rundir_is_container "$1" && return 1
  [ -e "$base.argv" ] || [ -e "$base.fixtures" ] || [ -e "$base.env" ] || icn_sidecar_path "$1" stdin >/dev/null
}

# A FRESH directory per witness, never a shared scratch. rung36_jcon_io writes tmp1/tmp2 and then asserts
# that open("tmp1") FAILS; rung36_jcon_recent LISTS its own cwd. Sharing one scratch across witnesses lets
# an earlier witness's litter change a later witness's answer, which is the same confound as grading two
# arms in two different directories -- it measures the environment and reports it as the program.
icn_rundir_make() {
  local icn="$1" parent="$2" dir
  dir="$(mktemp -d "$parent/icnrun.XXXXXX")" || return 2
  ipl_fixtures_stage "$icn" "$dir" || { rm -rf "$dir"; return 2; }
  printf '%s\n' "$dir"
}

# icn_oracle_refuses "$icn" -- 0 when Arizona icont REFUSES to compile the source, 1 when it compiles it, 2 when the oracle
# cannot be reached. ⛔ A PAIRLESS FILE THE ORACLE REFUSES IS NOT A BOARD MEMBER (tests/icon KEEP.md "DELIBERATELY-INVALID
# ICON": rung16_seqexpr_gen_basic, rung20_section_seqexpr_excluded): with no .ref and no program the oracle accepts there is
# nothing to grade either way, and the rung runners counted both as MISSING, which kept every rung board red forever on two
# declared keepers (the ruling-xfail-stays-loose-and-your-2-files-are-a-runner-defect mail). A pairless file icont COMPILES
# stays MISSING -- an oracle answer exists and its ref is owed. An unreachable oracle answers 2, and callers treat that as
# "not refused", so a missing oracle can only ever keep a file MISSING, never excuse it.
icn_oracle_refuses() {
  local icn="$1" ic t rc
  . "$_ICN_RUNDIR_HERE/lib_oracle_flags.sh" 2>/dev/null || return 2
  ic="$(icont_bin 2>/dev/null)" || return 2
  t="$(mktemp -d)" || return 2
  ( cd "$t" && "$ic" -s -o x "$icn" ) >/dev/null 2>&1; rc=$?
  rm -rf "$t"
  [ "$rc" -ne 0 ] && return 0
  return 1
}
