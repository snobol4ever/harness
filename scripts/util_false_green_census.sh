#!/usr/bin/env bash
# util_false_green_census.sh -- DOES A RUNNER CALL FAILURE SUCCESS? (Lon 2026-10-21 16:5x CDT, in-chat to the coo, verbatim: "I suspect you know not
# what you are doing and are measuring failure not success." · "You better fix your flawed measurement system for the test suites.")
# Runs ONE suite runner, unchanged, in a staged root whose SCRIP is a BROKEN ENGINE, and reads the PASS rows it writes. Two engines:
#   silent   prints nothing and exits 0 (under --compile it writes one comment line, so a build probe and the assembler see a file)
#   refuser  under --run prints "error 1: refused by the stub engine" on stdout and stderr and exits 1; under --compile it succeeds (a build probe
#            refuses a compiler that cannot emit) and emits a program that prints the same line and exits 1 -- an engine whose every program dies
# Neither engine runs any program, so every PASS either one earns is a FALSE GREEN: the runner grades something other than the program's answer --
# a matched failure (the oracle refuses or dies and the engine refuses or dies "the same way"), an empty answer, or compile-and-terminate.
# The x32/x64 print-nothing gate (test_gate_x32t_and_x64t_a_print_nothing_engine_passes_no_program.sh) is this witness for two runners; this is it
# for any runner, read from the rows rather than from each runner's board line.
# NOTHING REAL IS WRITTEN: the progress DB, SUITES.tsv and SCORE.md are scratch copies under the staged root, the corpus is a git worktree detached at
# origin/main (kept between runs at $S4E_FG_ROOT/corpus, refreshed each run), and the runner is this folder's own copy.
# USAGE: util_false_green_census.sh [--engine silent|refuser|both] <runner.sh> [runner args...]   (S4E_CHUNK and the like pass through)
# OUTPUT: one line per engine -- FALSE_GREEN runner=<r> engine=<e> rows=<n> pass=<n> programs_passed=<n> :: <program mode>... -- then a verdict line.
# EXIT 0 neither engine earns a PASS; 1 an engine earns one (named); 2 could not measure (no runner, no rows written under an engine, no oracle).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="${S4E_FG_BASE:-$HERE/../..}"   # the root whose corpus and .github are read (a worktree of harness names the seat root here)
eval "$(S4E_HOME="$BASE" bash -c '. "$1/lib_paths.sh"; printf "FG_REAL_SCRIP=%q FG_REAL_CORPUS=%q FG_REAL_GITHUB=%q\n" "$S4E_SCRIP" "$S4E_CORPUS" "$S4E_GITHUB"' _ "$HERE")"   # the real repos the census reads, by the four variables of lib_paths.sh, resolved for the root BASE names
REAL_CORPUS="$(cd "$FG_REAL_CORPUS" 2>/dev/null && pwd)"
ROOT="${S4E_FG_ROOT:-$(cd "$BASE" && pwd)/.scratch/fg}"   # the seat root's own scratch, kept between runs (its corpus worktree is 1.6 GB)
fg_repo() { printf '%s/%s' "$ROOT" "$1"; }   # the staged root keeps the four repos as its own directories; each is named once here, as the four variables the runner reads
FG_CORPUS="$(fg_repo corpus)"; FG_HARNESS="$(fg_repo harness)"; FG_SCRIP="$(fg_repo SCRIP)"; FG_GITHUB="$(fg_repo .github)"
refuse() { echo "REFUSE(2) [false-green]: $* -- nothing measured"; exit 2; }
engines="silent refuser"
# --engine real grades the seat's own built SCRIP (its scrip and its current .so files copied in) under the same scratch tables: the runner's verdict
# counts for the real engine, before and after a runner's cure, with nothing written to the shared record
if [ "${1:-}" = --engine ]; then engines="$(echo "${2:-}" | tr ',' ' ')"; [ "$engines" = both ] && engines="silent refuser"
  for e in $engines; do case "$e" in silent|refuser|real) ;; *) refuse "--engine wants silent, refuser, real, both or a comma list";; esac; done; shift 2; fi
FG_REF="${S4E_FG_REF:-origin/main}"   # the corpus commit the staged root grades (a branch carrying a corpus cure, before it lands)
runner="${1:-}"; [ -n "$runner" ] || refuse "name a runner (one of one_runner_boards.txt)"; shift
[ -r "$HERE/$runner" ] || refuse "no runner $runner beside this script"
[ -n "$REAL_CORPUS" ] && git -C "$REAL_CORPUS" rev-parse -q --verify origin/main > /dev/null || refuse "no corpus repo with an origin/main at $FG_REAL_CORPUS"
SEAT="${S4E_SEAT:-$(basename "$(cd "$BASE" && pwd)" | sed -n 's/^claude_//p')}"   # the staged root is no seat root, so the guard is told whose run this is
[ -n "$SEAT" ] || refuse "no seat: run from a seat root or set S4E_SEAT"
mkdir -p "$ROOT" || refuse "cannot make $ROOT"
if [ ! -d "$FG_CORPUS/.git" ] && [ ! -f "$FG_CORPUS/.git" ]; then
  git -C "$REAL_CORPUS" worktree add -q --detach "$FG_CORPUS" "$FG_REF" > /dev/null 2>&1 || refuse "git worktree add $FG_CORPUS failed"
else
  git -C "$FG_CORPUS" checkout -q --detach "$FG_REF" 2> /dev/null && git -C "$FG_CORPUS" clean -qfdx > /dev/null 2>&1 || refuse "cannot reset the census corpus worktree $FG_CORPUS to $FG_REF"
fi
rm -rf "$FG_HARNESS" "$FG_SCRIP" "$FG_GITHUB"; rm -f "$ROOT/progress/$runner".*   # each runner keeps its own outputs and scratch tables beside the others
mkdir -p "$FG_HARNESS" "$FG_SCRIP/out" "$FG_GITHUB" "$ROOT/progress"
cp -r "$HERE" "$FG_HARNESS/scripts"
cp "$FG_REAL_GITHUB/SCORE.md" "$FG_GITHUB/SCORE.md" 2> /dev/null || : > "$FG_GITHUB/SCORE.md"
: > "$FG_SCRIP/out/libscrip_rt.so"
# a runner stamps the SCRIP HEAD it graded and refuses without one (jcon, arizona, csnobol4): the staged SCRIP is a scratch git repo of one empty commit
git -C "$FG_SCRIP" init -q 2> /dev/null && GIT_AUTHOR_NAME=fg GIT_AUTHOR_EMAIL=fg@localhost GIT_COMMITTER_NAME=fg GIT_COMMITTER_EMAIL=fg@localhost \
  git -C "$FG_SCRIP" commit -q --allow-empty -m "false-green census stub engine" > /dev/null 2>&1 || refuse "cannot make the staged SCRIP a git repo"
fail=0
for e in $engines; do
  rm -f "$FG_SCRIP/out/"*.so
  if [ "$e" = real ]; then
    [ -x "$FG_REAL_SCRIP/scrip" ] && [ -f "$FG_REAL_SCRIP/out/libscrip_rt.so" ] || refuse "--engine real: no built SCRIP at $FG_REAL_SCRIP"
    cp "$FG_REAL_SCRIP/scrip" "$FG_SCRIP/scrip"; for so in "$FG_REAL_SCRIP/out/"*.so; do case "${so##*/}" in *-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f].so) ;; *) cp "$so" "$FG_SCRIP/out/";; esac; done
  elif [ "$e" = silent ]; then
    printf '%s\n' '#!/bin/sh' 'c=0; o=""' 'while [ $# -gt 0 ]; do case "$1" in --compile) c=1;; --out=*) o="${1#--out=}";; esac; shift; done' \
      '[ "$c" = 1 ] || exit 0' 'if [ -n "$o" ]; then echo "# stub engine: prints nothing" > "$o"; else echo "# stub engine: prints nothing"; fi' 'exit 0' > "$FG_SCRIP/scrip"
  else
    # --compile succeeds (a build probe refuses a compiler that cannot emit), and what it emits is a program that prints the same error and exits 1
    printf '%s\n' '#!/bin/sh' 'c=0; o=""' 'while [ $# -gt 0 ]; do case "$1" in --compile) c=1;; --out=*) o="${1#--out=}";; esac; shift; done' \
      'if [ "$c" = 0 ]; then echo "error 1: refused by the stub engine"; echo "error 1: refused by the stub engine" >&2; exit 1; fi' \
      'a="	.text
	.globl main
main:
	sub \$8, %rsp
	lea msg(%rip), %rdi
	call puts@PLT
	mov \$1, %eax
	add \$8, %rsp
	ret
	.section .rodata
msg:	.string \"error 1: refused by the stub engine\"
	.section .note.GNU-stack,\"\",@progbits"' \
      'if [ -n "$o" ]; then printf "%s\n" "$a" > "$o"; else printf "%s\n" "$a"; fi' 'exit 0' > "$FG_SCRIP/scrip"
  fi
  [ -f "$FG_SCRIP/out/libscrip_rt.so" ] || : > "$FG_SCRIP/out/libscrip_rt.so"
  chmod +x "$FG_SCRIP/scrip"; rm -f "$FG_SCRIP/out/build_behaviour.sig"   # each stub is its own build: the checkout's behaviour ledger starts empty
  db="$ROOT/progress/$runner.$e.results.tsv"; head -1 /home/resources/progress/results.tsv > "$db"; : > "$db.current"
  cp /home/resources/progress/SUITES.tsv "$ROOT/progress/$runner.$e.SUITES.tsv"
  out="$ROOT/progress/$runner.$e.out"
  ( cd "$FG_SCRIP" && S4E_SCRIP="$FG_SCRIP" S4E_CORPUS="$FG_CORPUS" S4E_HARNESS="$FG_HARNESS" S4E_GITHUB="$FG_GITHUB" S4E_SEAT="$SEAT" S4E_PROGRESS_DB="$db" S4E_SUITES_TSV="$ROOT/progress/$runner.$e.SUITES.tsv" S4E_SCORE_MD="$FG_GITHUB/SCORE.md" \
      timeout -k 5 7200 bash "$FG_HARNESS/scripts/$runner" "$@" < /dev/null > "$out" 2>&1 )
  rows=$(awk 'NR>1' "$db" | grep -c .)
  if [ "$rows" = 0 ]; then
    echo "FALSE_GREEN runner=$runner engine=$e rows=0 :: UNMEASURED -- the runner wrote no progress row under the stub; its tail:"; tail -4 "$out" | sed 's/^/    /'; fail=2; continue
  fi
  # a PASS on a program its package EXCLUDES (any EXCLUDED*.tsv row of the graded corpus) is outside the denominator, so it is excused and named, never counted
  excl="$ROOT/progress/$runner.$e.excluded"; cat "$FG_CORPUS"/packages/*/*/EXCLUDED*.tsv 2> /dev/null | awk -F'\t' '!/^#/ && NF > 1 {n = $1; sub(/\.[A-Za-z]+$/, "", n); print n}' | sort -u > "$excl"
  excused=$(awk -F'\t' 'NR==FNR {x[$1]=1; next} FNR>1 && $10=="PASS" && ($8 in x) {print $8 " " $9}' "$excl" "$db" | sort -u)
  passed=$(awk -F'\t' 'NR==FNR {x[$1]=1; next} FNR>1 && $10=="PASS" && !($8 in x) {print $8 " " $9}' "$excl" "$db" | sort -u)
  [ -n "$excused" ] && [ "$e" != real ] && echo "  excused, EXCLUDED by their package: $(printf '%s\n' "$excused" | grep -c .) PASS row(s) -- $(printf '%s\n' "$excused" | head -12 | tr '\n' ',' | sed 's/,$//')"
  np=$(printf '%s\n' "$passed" | grep -c .); nprog=$(printf '%s\n' "$passed" | awk 'NF {print $1}' | sort -u | grep -c .)
  if [ "$e" = real ]; then   # the real engine's score under the runner's verdict: both-modes programs, and per mode
    both=$(printf '%s\n' "$passed" | awk 'NF {n[$1]++} END {c=0; for (p in n) if (n[p] >= 2) c++; print c}')
    echo "REAL_ENGINE runner=$runner rows=$rows programs=$(awk -F'\t' 'NR>1 {print $8}' "$db" | sort -u | grep -c .) pass_rows=$np both_modes_pass=$both m3_pass=$(printf '%s\n' "$passed" | grep -c ' m3$') m4_pass=$(printf '%s\n' "$passed" | grep -c ' m4$')"
    awk -F'\t' 'NR>1 && $10=="PASS" {print "    PASS note: " substr($12, 1, 100)}' "$db" | sort | uniq -c | sort -rn | head -4
    continue
  fi
  echo "FALSE_GREEN runner=$runner engine=$e rows=$rows pass=$np programs_passed=$nprog :: $(printf '%s\n' "$passed" | head -40 | tr '\n' ',' | sed 's/,$//')$( [ "$np" -gt 40 ] && echo " ... and $((np-40)) more")"
  if [ "$np" -gt 0 ]; then
    echo "  why, as the runner noted it (the commonest notes on those PASS rows):"
    awk -F'\t' 'NR==FNR {x[$1]=1; next} FNR>1 && $10=="PASS" && !($8 in x) {print "    " substr($12, 1, 140)}' "$excl" "$db" | sort | uniq -c | sort -rn | head -5
    [ "$fail" = 2 ] || fail=1
  fi
done
case "$fail" in
  0) echo "VERDICT [false-green] $runner: no broken engine earns a PASS ($engines)"; exit 0;;   # a real engine's PASS rows are its score, never a false green
  1) echo "VERDICT [false-green] $runner: a broken engine earns PASS rows -- the runner credits something other than the program's answer"; exit 1;;
  *) echo "VERDICT [false-green] $runner: could not measure under every engine"; exit 2;;
esac
