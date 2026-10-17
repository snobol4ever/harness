#!/usr/bin/env bash
# test_gate_no_fossil_src_paths.sh — instrument-repair-bundle PART 3 (new gate).
#
# A FOSSIL PATH is a default path VALUE, hardcoded into a ../harness/scripts/*.sh variable assignment, that
# points at a corpus directory which no longer exists on disk. Motivation, all measured 2026-08-24:
# the demo/corpus tree was repointed five times in one day; `INC` still defaults to
# `$CORPUS/demos/inc` in at least six scripts, and `corpus/demos/inc` does not exist (the includes
# live at `corpus/include`); `CORPUS-LOCATIONS.md` described a layout the s271-s272 reorg dissolved.
# A script that silently resolves its corpus dir to a smaller-or-empty set (or fails a `[ -d ]`
# check nobody is watching) does not FAIL loudly — it just quietly grades less than it claims to,
# the same "board could not say NO" class as SCRIP 9873fe6e (test_corpus_snobol4.sh's own rc=2).
#
# SCOPE, deliberately narrow (task's own words): "default path values in ../harness/scripts/*.sh — a path that
# is merely mentioned in a COMMENT is not a defect." This gate parses ASSIGNMENTS only, quoted or
# not (both are common in this tree), two shapes:
#   VAR="${ENVVAR:-literal/with/$OTHERVAR/refs}"   VAR=${ENVVAR:-literal/with/$OTHERVAR/refs}
#   VAR="literal/with/$OTHERVAR/refs"              VAR=literal/with/$OTHERVAR/refs
# and resolves $OTHERVAR/${OTHERVAR} references using ONLY the same file's own simple assignments
# (collected in file order, so a later default can build on an earlier one exactly as the shell
# itself would) plus $S4E (always known — this gate's own resolved sibling root) and a seeded
# $CORPUS = $S4E/corpus (the convention observed in the majority of scripts; a file that defines
# CORPUS via one of these shapes overrides the seed with its own value before resolution runs).
# A resolved value that still contains a $VAR, or a glob, is SKIPPED rather than guessed at — this
# gate reports what it can PROVE false, not what it suspects. A resolved value may be a
# whitespace-separated LIST of paths (e.g. `CORPUS_DIRS="$A $B"`) — each token is checked on its own.
#
# Further scoped to tokens that resolve under a `corpus` path segment (the task's own "corpus/
# source path" wording, and every named motivating example) and that look like a DIRECTORY
# reference (the last path segment has no dot-extension) — a file path meant to be CREATED as
# output almost always carries an extension or lives outside corpus/, so this keeps the false-
# positive rate low without hand-listing today's known-bad paths (which would be the "editing a
# test to return 0" trap the task explicitly forbids: this gate is satisfiable ONLY by making the
# path resolve for real, or by removing the fossil default, never by weakening what it checks).
#
# ⛔ NOT A FULL BASH PARSER. This is a best-effort static heuristic, not a shell interpreter: command
# substitutions (`$(...)`), arithmetic, and multi-hop chains through a var this gate could not
# resolve are SKIPPED, not guessed. A script whose only corpus default is built that way is invisible
# to this gate — narrower coverage on purpose, in exchange for zero false positives from a wrong guess.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
set -u
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SELF_DIR/lib_gate.sh"
SCRIPTS_DIR="${1:-$SELF_DIR}"
gate_require "$SCRIPTS_DIR" "the scripts directory to scan"

shopt -s nullglob
files=("$SCRIPTS_DIR"/*.sh)
gate_floor "${#files[@]}" 50 "../harness/scripts/*.sh files"

violations=0; checked=0; report=""
NAMERX='[A-Za-z_][A-Za-z0-9_]*'

# match_assign LINE -- on a match, sets MA_NAME/MA_RAW and returns 0; else returns 1. Tries, in
# order: quoted ${ENV:-default}, unquoted ${ENV:-default}, quoted literal, unquoted literal. The
# unquoted-literal arm is last and narrowest (a single non-space token) so it cannot eat a trailing
# comment or a second statement on the same line.
match_assign() {
  local line="$1"
  if [[ "$line" =~ ^[[:space:]]*($NAMERX)=\"\$\{$NAMERX:-([^}]*)\}\"[[:space:]]*(\#.*)?$ ]]; then
    MA_NAME="${BASH_REMATCH[1]}"; MA_RAW="${BASH_REMATCH[2]}"
    case "$MA_RAW" in *'$('*|*'`'*) return 1;; esac   # default itself is a command substitution -- not a literal
    return 0
  elif [[ "$line" =~ ^[[:space:]]*($NAMERX)=\$\{$NAMERX:-([^}]*)\}[[:space:]]*(\#.*)?$ ]]; then
    MA_NAME="${BASH_REMATCH[1]}"; MA_RAW="${BASH_REMATCH[2]}"
    case "$MA_RAW" in *'$('*|*'`'*) return 1;; esac
    return 0
  elif [[ "$line" =~ ^[[:space:]]*($NAMERX)=\"([^\"]*)\"[[:space:]]*(\#.*)?$ ]]; then
    MA_NAME="${BASH_REMATCH[1]}"; MA_RAW="${BASH_REMATCH[2]}"
    case "$MA_RAW" in *'$('*|*'`'*) return 1;; esac
    return 0
  elif [[ "$line" =~ ^[[:space:]]*($NAMERX)=([^[:space:]\"\'#][^[:space:]]*)[[:space:]]*(\#.*)?$ ]]; then
    MA_NAME="${BASH_REMATCH[1]}"; MA_RAW="${BASH_REMATCH[2]}"
    case "$MA_RAW" in *'$('*|*'`'*) return 1;; esac
    return 0
  fi
  return 1
}

resolve_one() {
  # $1 = raw default string (may contain $VAR / ${VAR} refs, and may be a space-separated LIST) --
  # prints the fully-substituted result after up to 6 passes (enough for any realistic chain here).
  # ⛔ KEYS MUST BE TRIED LONGEST-NAME-FIRST (seat14 2026-09-04, row dead-suite-path-consumer-sweep):
  # bash's `${val//\$k/...}` is an unanchored literal substring replace, so a SHORT name that is a
  # PREFIX of a longer one in the same file (e.g. `B=".../corpus/benchmarks/snobol4"` vs `BASE_N`)
  # gets spliced into the middle of the longer reference before the longer key's own turn comes —
  # `$BASE_N` became `$B` + literal `ASE_N`, resolving to a garbled path that "does not exist" for a
  # variable (`n1`) that was never a corpus path at all. Two SAME-length names can never collide this
  # way (a strict prefix match requires the shorter string), so sorting once by length descending is
  # a complete fix, not a heuristic. Found live on `bench_ir_slope.sh`'s `n1`/`B` pair.
  local val="$1" pass k
  for pass in 1 2 3 4 5 6; do
    val="${val//\$\{S4E\}/$S4E}"; val="${val//\$S4E/$S4E}"
    for k in "${SORTED_KEYS[@]}"; do
      val="${val//\$\{$k\}/${fvals[$k]}}"
      val="${val//\$$k/${fvals[$k]}}"
    done
  done
  printf '%s' "$val"
}

for f in "${files[@]}"; do
  base="$(basename "$f")"
  declare -A fvals=()
  fvals[CORPUS]="$S4E/corpus"   # seed: the observed convention, overridden below if the file says otherwise
  # Pass 1: collect every simple assignment in file order, so later lines can build on earlier ones
  # the same way the shell itself would when the script actually runs.
  while IFS= read -r line; do
    case "$line" in \#*) continue;; esac
    match_assign "$line" && fvals["$MA_NAME"]="$MA_RAW"
  done < "$f"
  # Longest-name-first order for resolve_one's substitution loop -- see resolve_one's own comment.
  SORTED_KEYS=()
  while IFS= read -r k; do SORTED_KEYS+=("$k"); done < <(
    for k in "${!fvals[@]}"; do printf '%d %s\n' "${#k}" "$k"; done | sort -rn -k1,1 | cut -d' ' -f2-)
  # Pass 2: re-walk the same lines, this time CHECKING each path-shaped token against disk, using
  # the (now-complete) fvals map built above so forward chains within one file resolve too.
  while IFS= read -r line; do
    case "$line" in \#*) continue;; esac
    match_assign "$line" || continue
    name="$MA_NAME"; raw="$MA_RAW"
    resolved="$(resolve_one "$raw")"
    for tok in $resolved; do   # unquoted on purpose: split a space-separated multi-path default
      case "$tok" in
        *'$'*) continue;;                 # still has an unresolved ref -- cannot verify, skip
        *'*'*) continue;;                 # a glob, not a concrete path -- skip
        /tmp/*) continue;;                # a scratch/work dir (this codebase's universal convention
                                           # for self-created temp trees) -- "corpus" as a subdir NAME
                                           # here is not a reference to the corpus REPO
        */corpus|*/corpus/*) : ;;         # in scope: resolves under a corpus path segment
        *) continue;;
      esac
      last="${tok##*/}"
      case "$last" in *.*) continue;; esac   # has a dot-extension -- looks like a file target, not a dir default
      [ -n "$tok" ] || continue
      # a script that itself `mkdir -p`'s this SAME variable is declaring an INSTALL/output target,
      # not a read-from-existing input -- not existing yet is the expected, normal state. Only the
      # exact variable this default feeds skips (a sibling var with a similar-looking path does not).
      grep -qE "mkdir([[:space:]]+-[A-Za-z]+)*[[:space:]]+.*\\\$\{?$name\\b" "$f" 2>/dev/null && continue
      checked=$((checked+1))
      if [ ! -e "$tok" ]; then
        violations=$((violations+1))
        report="$report
  $base: $name defaults to '$raw' -> resolves to '$tok', which does NOT exist"
      fi
    done
  done < "$f"
  unset fvals
done

if [ "$violations" -gt 0 ]; then
  echo "⛔ GATE REFUSES: $violations hardcoded corpus default path(s) no longer resolve:"
  printf '%s\n' "$report"
  echo "   Repoint the default (or the variable it composes with) to where the tree actually lives."
fi
gate_floor "$checked" 3 "resolved corpus-path default(s) examined"
gate_verdict "$violations" "fossil default path(s)"
