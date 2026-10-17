#!/usr/bin/env bash
# test_area_smoke.sh -- THE AREA SMOKE a seat runs per landing (Lon 2026-09-27, verbatim: "So if you change the SPAN function,
# then run every program that has SPAN as a reference. That is one of the columns in the attribute file."; ceo CEO-1342;
# RULES.md section ONE TESTING OFFICER, ONE SCORE BOARD, THE AREA SMOKE clause 4; the coo's row instruments-the-area-smoke-...).
#
#   test_area_smoke.sh                     the landing: reads the tree's diff against origin/main (tracked changes and untracked
#                                          files), maps every touched src/ file and changed function through ../harness/scripts/area_map.tsv
#                                          to the feature columns of the attribute tables, runs the union in both modes.
#   test_area_smoke.sh FENCE SPAN ...      explicit feature names, as the tables spell them.
#   --list-only                            print the selection and run nothing.
#   AREA_SMOKE_BASE=<ref>                  the base to diff against (default origin/main).
#   AREA_SMOKE_ROOT=<dir>                  the checkout to diff (default this script's SCRIP/); the map is read from THAT root's
#                                          ../harness/scripts/area_map.tsv when it has one, else from beside this script.
#
# ⛔ THE SEAT MUST NOT HAVE TO KNOW (Lon's sixth question): the map answers, not memory. A touched src/ file with no row in the
# map REFUSES rc=2 naming it -- the lander adds the row with the landing. A tree equal to the base prints NO-DIFF and exits 0.
# A landing that touches only carriers mapped to `-` (no area) prints NO-AREA and exits 0. Files outside src/ (scripts, corpus,
# docs) carry no area and are printed as such: the gates a diff touched are the other half of the per-landing verdict.
# ⛔ NOT A BOARD: corpus_suite_harness.py smoke appends no progress row and writes no score cell (CEO-547); no one-runner guard
# is sourced here because none applies. EXIT: 0 every selected entry PASS in both modes (or nothing to smoke, said loudly);
# 1 a red entry; 2 could not measure (unmapped carrier, unknown feature, zero population, stale binary).
set -u
set -f   # ⛔ the map's `*` carrier is a word, never a glob: unquoted expansions of the hit list must not turn it into the checkout's top-level names (the cto, 2026-09-28, batch 2b: preflight read 65 arms 1 red on a core.c landing)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${AREA_SMOKE_ROOT:-$(cd "$HERE/../../SCRIP" && pwd)}"
MAP="$ROOT/../harness/scripts/area_map.tsv"; [ -f "$MAP" ] || MAP="$HERE/area_map.tsv"
H="$HERE/corpus_suite_harness.py"
BASE="${AREA_SMOKE_BASE:-origin/main}"
[ -f "$MAP" ] || { echo "AREA_SMOKE REFUSE(2): ../harness/scripts/area_map.tsv is missing -- the carrier map is the instrument"; exit 2; }
[ -f "$H" ] || { echo "AREA_SMOKE REFUSE(2): corpus_suite_harness.py is missing beside this script"; exit 2; }
LIST=""; FEATS=(); for a in "$@"; do case "$a" in --list-only) LIST=--list-only;; -*) echo "AREA_SMOKE REFUSE(2): unknown switch $a"; exit 2;; *) FEATS+=("$a");; esac; done
# ⛔⭐⭐⭐⭐ ZERO OR ONE TEST PER SEAT (Lon 2026-10-11 11:5x CDT, verbatim: "I'm thinking each seat can run ZERO test, oh ONE test, instead. Then let COO
# prioritize testing on a per feature basis and still cycle through everything eventually."; ceo CEO-1671): the smoke is the coo's per-landing
# selector -- for each origin landing the coo runs the feature the diff marks FIRST, through this map and the attribute rows -- and no other
# seat runs it (a shared node selects hundreds of programs in both modes; fourteen seats ran it per landing and the load read 29 on 16 cores).
# --list-only stays open to every seat: the selection costs nothing and tells a lander which feature its diff marks.
if [ -z "$LIST" ]; then _as_seat="$(bash "$HERE/lib_one_runner.sh" --seat 2>/dev/null)"; if [ "$_as_seat" != coo ] && [ -z "${S4E_ONE_TEST_ADMIT:-}" ]; then echo "AREA_SMOKE REFUSE(2): ZERO OR ONE TEST PER SEAT (CEO-1671) -- the smoke runs only in the coo's loop; seat ${_as_seat:-?} may run --list-only, and its row's DONE-WHEN"; exit 2; fi; fi

# expand_features: `*` -> every feature column of every table; `lang:<x>` -> the columns of x's tables; else itself.
expand_features() {
  local out="" f
  for f in "$@"; do
    case "$f" in
      '*') out="$out $(python3 "$H" smoke --vocabulary 2>/dev/null | sed 's/^AREA_SMOKE_VOCAB table=[^ ]* runnable=[^ ]* //' | tr '\n' ' ')" ;;
      # a language's own features are QUALIFIED by it (<lang>:<column>): a Prolog carrier selects Prolog's `write`, never Icon's
      lang:*) out="$out $(python3 "$H" smoke --vocabulary --tables "tests/${f#lang:} packages/${f#lang:}/" 2>/dev/null | sed 's/^AREA_SMOKE_VOCAB table=[^ ]* runnable=[^ ]* //' | awk -v l="${f#lang:}" '{for (i=1;i<=NF;i++) printf "%s:%s ", l, $i}')" ;;
      -) ;;
      *) out="$out $f" ;;
    esac
  done
  printf '%s\n' "$out" | tr ' ' '\n' | grep -v '^$' | awk '!seen[$0]++' | tr '\n' ' '
}

if [ ${#FEATS[@]} -eq 0 ]; then
  git -C "$ROOT" rev-parse --verify -q "$BASE^{commit}" >/dev/null || { echo "AREA_SMOKE REFUSE(2): base $BASE is not a commit in $ROOT (set AREA_SMOKE_BASE, or fetch origin)"; exit 2; }
  # ⛔ THE LANDING'S DIFF IS AGAINST THE MERGE BASE, NEVER AGAINST THE BASE'S TIP (the coo 2026-10-01, measured): `git diff $BASE` on a
  # checkout BEHIND origin -- a pass pinned to a tree while the fleet lands, a scratch worktree not yet rebased -- reads every landing
  # since as this tree's own change, reversed, and the smoke selected 351 features from other seats' commits (preflight's arm timed
  # out at 30 s inside the coo's blocking-set pass at ba10ba29f). The merge base of HEAD and the base is where this tree's own work
  # begins: behind origin it is HEAD itself (only the working tree's edits are smoked), ahead of it the tip (only the local commits).
  MB="$(git -C "$ROOT" merge-base HEAD "$BASE" 2>/dev/null)" || { echo "AREA_SMOKE REFUSE(2): HEAD and $BASE share no merge base in $ROOT"; exit 2; }
  files="$( { git -C "$ROOT" diff --name-only "$MB" -- . ; git -C "$ROOT" ls-files --others --exclude-standard -- . ; } 2>/dev/null | sort -u)"
  if [ -z "$files" ]; then echo "AREA_SMOKE NO-DIFF: the tree equals its merge base with $BASE ($(git -C "$ROOT" rev-parse --short "$MB")) -- nothing to smoke"; exit 0; fi
  raw=""; unmapped=""; noarea=""; outside=""; deleted=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in src/*) ;; *) outside="$outside $f"; continue;; esac
    # a src/ file the landing DELETES has no carrier left to map: the map's own gate (arm 7b) requires every carrier to exist, so its row went with it,
    # and the files that replace it carry their own rows -- it is named, not refused (hq_templates 2026-10-03, the bb_unify.cpp split into four boxes)
    [ -e "$ROOT/$f" ] || { deleted="$deleted $f"; continue; }
    hit=""
    # rows whose carrier is this file, or a directory prefix of it
    while IFS=$'\t' read -r feat car; do
      case "$feat" in ''|'#'*) continue;; esac
      case "$car" in
        */) case "$f" in "$car"*) hit="$hit $feat";; esac ;;
        */*|*.*) [ "$car" = "$f" ] && hit="$hit $feat" ;;
      esac
    done < "$MAP"
    # symbol rows: the functions the -U0 hunk headers name (a new file has no hunk names; a row for the file is owed then)
    if [ -z "$hit" ] && git -C "$ROOT" cat-file -e "$MB:$f" 2>/dev/null; then
      funcs="$(git -C "$ROOT" diff -U0 "$MB" -- "$f" | sed -n 's/^@@[^@]*@@ *//p' | sed -n 's/.*[^A-Za-z0-9_]\([A-Za-z_][A-Za-z0-9_]*\) *(.*/\1/p;s/^\([A-Za-z_][A-Za-z0-9_]*\) *(.*/\1/p' | sort -u)"
      all_named=1; any=0
      for fn in $funcs; do any=1; r="$(awk -F'\t' -v s="$fn" '$1 !~ /^#/ && $2==s {print $1}' "$MAP")"; [ -n "$r" ] && hit="$hit $r" || all_named=0; done
      [ "$any" = 1 ] && [ "$all_named" = 1 ] || hit=""
    fi
    if [ -z "$hit" ]; then unmapped="$unmapped $f"; continue; fi
    case " $hit " in *" - "*) [ "$(printf '%s\n' $hit | grep -vc '^-$')" = 0 ] && { noarea="$noarea $f"; continue; };; esac
    # a file that reaches every feature (a * row) contributes nothing else: its symbol and feature rows are the same shared node seen
    # up close, and running them is the whole population by another name (the cto 2026-09-28: core.c's ten feature rows ran 1790
    # entries for twelve minutes on a shared-node landing)
    # ⭐ BUT A SYMBOL ROW STILL SPEAKS INSIDE A SHARED NODE (hq_icon 2026-10-15, the section column: subscript_get2_s and rt_substr sit under
    # src/runtime/, mapped to *, so their section rows were never read and tier 2 ran the seven cores, 13 of the 45 section entries). A symbol
    # row names the FUNCTION the diff touched, not the file, so it is not core.c's ten file rows: the feature it names is added beside the *.
    case " $hit " in *" * "*)
      hit="*"
      if git -C "$ROOT" cat-file -e "$MB:$f" 2>/dev/null; then
        for fn in $(git -C "$ROOT" diff -U0 "$MB" -- "$f" | sed -n 's/^@@[^@]*@@ *//p' | sed -n 's/.*[^A-Za-z0-9_]\([A-Za-z_][A-Za-z0-9_]*\) *(.*/\1/p;s/^\([A-Za-z_][A-Za-z0-9_]*\) *(.*/\1/p' | sort -u); do
          hit="$hit $(awk -F'\t' -v s="$fn" '$1 !~ /^#/ && $1 != "*" && $1 != "-" && $2==s {print $1}' "$MAP" | tr '\n' ' ')"
        done
      fi;;
    esac
    raw="$raw $hit"
    echo "AREA_SMOKE_MAP $f -> $(printf '%s\n' $hit | grep -v '^-$' | awk '!seen[$0]++' | tr '\n' ' ' | sed 's/ $//')"
  done <<< "$files"
  [ -z "$outside" ] || echo "AREA_SMOKE no area (outside src/):$outside -- the gates such a diff touched are the other half of the verdict"
  [ -z "$noarea" ] || echo "AREA_SMOKE no area (mapped to -):$noarea"
  [ -z "$deleted" ] || echo "AREA_SMOKE no area (deleted by this landing, the files that replace it carry the rows):$deleted"
  if [ -n "$unmapped" ]; then
    echo "AREA_SMOKE REFUSE(2): touched src/ file(s) with NO ROW in ../harness/scripts/area_map.tsv:$unmapped -- add feature<TAB>carrier rows with this landing (a shared node maps to *, a frontend to lang:<x>, a helper to -)"
    exit 2
  fi
  # ⛔ A SHARED NODE IS THE OFFICER'S, NOT A SMOKE'S (Lon 2026-09-27, verbatim: "Should catch all SPAN problems, but not all system
  # level problems as side-effects to others. Those will be caught by the officer in charge."; CEO-1342 clause 1). A touched carrier
  # mapped to `*` reaches every feature of every table: that union IS the whole population, the loop's own pass, and running it here
  # would make every seat's preflight an hour long on a core.c landing. The smoke says so, names the files, runs the OTHER touched
  # carriers' features if any, and exits 0 on the shared node alone -- the loop's next pass on origin is that landing's verdict.
  if grep -qx '\*' <<<"$(printf '%s\n' $raw)"; then
    shared="$(printf '%s\n' "$files" | while IFS= read -r f; do case "$f" in src/*) ;; *) continue;; esac; awk -F'\t' -v f="$f" '$1=="*" && ($2==f || (substr($2,length($2),1)=="/" && index(f,$2)==1)) {print f; exit}' "$MAP"; done | tr '\n' ' ')"
    echo "AREA_SMOKE SHARED-NODE:$([ -n "$shared" ] && echo " $shared" || echo " (a touched carrier maps to *)") -- every feature of every table is reached, and that population is the testing officer's loop (CEO-1342), not a per-landing smoke; the loop's next pass on origin is this landing's verdict"
    raw="$(printf '%s\n' $raw | grep -vx '\*' | tr '\n' ' ')"
  fi
  FEATS=($(expand_features $raw))
  if [ ${#FEATS[@]} -eq 0 ]; then echo "AREA_SMOKE NO-AREA: the touched files carry no feature area of their own -- nothing to smoke here"; exit 0; fi
else
  FEATS=($(expand_features "${FEATS[@]}"))
fi
echo "AREA_SMOKE features (${#FEATS[@]}): ${FEATS[*]}"
python3 "$H" smoke $LIST -- "${FEATS[@]}"
rc=$?
echo "AREA_SMOKE rc=$rc tree=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$( [ -z "$(git -C "$ROOT" status --porcelain 2>/dev/null)" ] || printf -- '-DIRTY') base=$BASE"
exit $rc
