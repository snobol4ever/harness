#!/usr/bin/env bash
# SET-BASED board for crosscheck/patterns.  Replaces test_board_wreg_byset.sh, whose two-arm
# ON/OFF compare became VACUOUS when 855a12a physically deleted the SCRIP_WREG killswitch
# (it now survives only in two comments: bb_match_defer.cpp:83, bb_glue_flat.cpp:150).
# That script would report REPAIRED 0 / BROKEN 0 -- indistinguishable from "neutral change",
# but actually meaning "both arms ran identical bytes".  A green board with no signal behind it.
#
# The s17 law is preserved by comparing SETS ACROSS BUILDS instead of across a dead env arm:
#   a net count cannot distinguish 10-repaired/0-broken from 15/5.
#
# SERIAL BY CONSTRUCTION.  Parallel execution is NOT safe for this board: CPU contention pushes
# slow-but-crashing programs past the timeout and misclassifies SEGV as HANG (measured: 178, 179
# flipped SIG11->HANG at -P 8 / 10s).  The failure-mode split is the whole point, so do not
# reintroduce xargs -P here.
#
# Usage:
#   bash ../harness/scripts/board_patterns_set.sh snap <tag>        # measure, write set file
#   bash ../harness/scripts/board_patterns_set.sh diff <old> <new>  # REPAIRED / BROKEN by set membership
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
TIMEOUT_RETRY="${TIMEOUT_RETRY:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_timeout_retry.sh}"   # every graded timeout is retried once, longer (Lon 2026-10-15, in-chat to the coo: "do a retry with longer timeouts")
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.
set -u
SCRIP=${SCRIP_BIN:-$(cd "$(dirname "$0")/../../SCRIP" && pwd)/scrip}
SNAPDIR=${BOARD_SNAPS:-$S4A/work/board_snaps}
PER=${PAT_TIMEOUT:-30}
mkdir -p "$SNAPDIR"
# ⭐ RE-POINTED 2026-08-30 (seat12, repo-wide dead-suite-path consumer sweep): crosscheck/patterns/
# is gone -- absorbed into THE ONE FLAT RUNGS. An explicit PAT_CORPUS override is honored as-is; the
# default now materializes the "crosscheck_patterns" family via lib_rungs_extract.sh into a
# persistent scratch dir under SNAPDIR so repeated snap/diff invocations reuse the same extraction.
if [ -n "${PAT_CORPUS:-}" ]; then
  DIR="$PAT_CORPUS"
else
  RUNGS_LANG="${RUNGS_LANG:-snobol4}" . "$(cd "$(dirname "$0")" && pwd)/lib_rungs_extract.sh"
  DIR="$SNAPDIR/crosscheck_patterns_src"
  [ -d "$DIR" ] && [ -n "$(ls -A "$DIR" 2>/dev/null)" ] || { mkdir -p "$DIR"; rungs_extract_family crosscheck_patterns "$DIR" 2>/dev/null; }
fi

snap() {
  local tag="$1"
  local p="$SNAPDIR/$tag.pass"
  local f="$SNAPDIR/$tag.fail"
  : > "$p"; : > "$f"
  cd "$DIR" || exit 1
  for s in *.sno; do
    local b="${s%.sno}"; local IN=/dev/null; local got; local rc; local mode
    [ -f "$b.ref" ] || continue
    [ -f "$b.input" ] && IN="$b.input"
    got=$("$TIMEOUT_RETRY" "$PER" "$SCRIP" --run "$s" < "$IN" 2>/dev/null); rc=$?
    if [ $rc -eq 0 ] && [ "$got" = "$(cat "$b.ref")" ]; then
      echo "$b" >> "$p"
    else
      if   [ $rc -eq 0   ]; then mode=DIFF
      elif [ $rc -eq 124 ]; then mode=HANG
      elif [ $rc -ge 128 ]; then mode="SIG$((rc-128))"
      else                       mode="rc$rc"; fi
      echo "$b $mode" >> "$f"
    fi
  done
  sort -o "$p" "$p"; sort -o "$f" "$f"
  echo "[$tag] PASS $(wc -l < "$p") / $(ls "$DIR"/*.sno | wc -l)"
  echo "[$tag] failure modes:"
  awk '{print $2}' "$f" | sort | uniq -c | sort -rn | sed 's/^/    /'
  echo "[$tag] snapshot: $p"
}

diffsets() {
  local o="$SNAPDIR/$1.pass" n="$SNAPDIR/$2.pass" nf="$SNAPDIR/$2.fail"
  [ -f "$o" ] && [ -f "$n" ] || { echo "missing snapshot ($1 or $2)"; exit 1; }
  echo "REPAIRED ($2 passes, $1 fails): $(comm -13 "$o" "$n" | wc -l)"
  comm -13 "$o" "$n" | sed 's/^/  + /'
  comm -23 "$o" "$n" > /tmp/.broken.$$
  echo "BROKEN ($1 passes, $2 fails): $(wc -l < /tmp/.broken.$$)"
  sed 's/^/  - /' /tmp/.broken.$$
  if [ -s /tmp/.broken.$$ ]; then
    echo "BROKEN split by failure mode:"
    grep -Ff /tmp/.broken.$$ "$nf" | awk '{print $2}' | sort | uniq -c | sort -rn | sed 's/^/    /'
  fi
  rm -f /tmp/.broken.$$
}

case "${1:-}" in
  snap) snap "${2:?tag required}" ;;
  diff) diffsets "${2:?old tag}" "${3:?new tag}" ;;
  *) echo "usage: $0 snap <tag> | diff <old> <new>"; exit 2 ;;
esac
