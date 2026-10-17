#!/usr/bin/env bash
# ../harness/scripts/util_census_dead_pinned_refs.sh — censuses PINS (.ref/.std/ALL.ref) whose OWN CONTENT is a
# transcript of the ORACLE'S DEATH: SPITBOL's fatal termination report, ending in its allocator counters
# `memory used (bytes)` / `memory left (bytes)`.  Row: the ceo's HOLD dispatch to hq_B, 2026-09-08 —
# "have it ready to re-run and report the before-and-after", the honest measure of hq_R's termination-report
# landing.  Reports; changes nothing.  Deleting a pin is a SEPARATE, HELD decision (ceo: removing programs
# from a denominator is the hardest edit on the board to undo).
#
# ⛔⭐ WHY A PIN LIKE THIS IS NOT A BUG WE CAN CURE.  The premise of a package board is "the oracle runs this
# clean and we do not".  For these entries the premise is INVERTED: the oracle DIES and the ref pins the
# death, so we are graded against a transcript of SPITBOL's own failure.  Six of the report's eight lines we
# can produce honestly (g_file g_line g_stno g_stcount + a clock); the two MEMORY counters are SPITBOL's own
# allocator and no other implementation can produce them by being correct, only by transcribing.  So a
# correct cure on such a program cannot flip it — hq_R proved that the expensive way on `rewind1`: a real
# defect (ERROR 174 on REWIND with no OPENed file), properly cured and landed, and THE BOARD DID NOT MOVE.
#
# ⛔⭐⭐ TWO INSTRUMENT LAWS ARE BUILT IN, BOTH LEARNED BY THIS CENSUS FAILING THEM FIRST.
# (1) ZERO-FOUND AND ZERO-EXAMINED PRINT IDENTICALLY.  The first sweep suppressed directories with no pins,
#     so `snoflake 0 / dotnet 0 / testpgms 0` READ AS CLEAN when it meant NOT LOOKED AT — those three suites
#     have no per-program pins at all, they grade live against the oracle.  Every directory is therefore
#     printed with its POPULATION, and a population of zero is spelled NO-PINS, never 0-dead.  A census that
#     cannot see its population must never print 0.
# (2) ⛔ MEASURE A PREDICATE WITH THE INTERPRETER THAT WILL RUN IT.  `corpus/tests/snobol4/ALL.ref` — the
#     SNOBOL4 RUNGS, the announcement board — carries ONE NUL byte in 330570, so `file` calls it "data".
#     ⛔ AN EARLIER VERSION OF THIS HEADER SAID THAT BYTE *HID* THREE DEAD-PINNED RUNGS ENTRIES behind a grep
#     that reports nothing and exits 0.  THAT WAS WRONG, and hq_T bounded it 2026-09-08.  The interactive shell
#     on this box routes `grep` to a ugrep FUNCTION; it is NOT exported (no BASH_FUNC_grep), so it never reaches
#     a script.  Inside a script — the only place `sbl_died` ever runs — grep is /usr/bin/grep GNU 3.11, whose
#     binary detection suppresses OUTPUT but never EXIT STATUS, and -q prints nothing anyway.  RE-MEASURED HERE
#     on the real rungs, in a script: no -a => DEAD, with -a => DEAD.  The predicate has ALWAYS answered DEAD
#     everywhere it actually runs; nothing was concealed and no board number was ever hidden.  The three entries
#     are genuinely dead-pinned — that half of the finding stands — but the NUL byte is not why they went unseen.
#     ⭐ THE KEEPER: `command -v grep` printed a bare "grep" and could not say so; `type -t` is the instrument
#     that answers WHICH grep.  A shell function shadowing a binary survives no export and silently answers a
#     different question than the same text in a script.
#     `-a` stays on every match here, and hq_T landed it on the authority too (SCRIP 60d58c05b), as INSURANCE
#     rather than a repair: it makes the answer independent of whatever grep is on PATH, at zero verdict cost.
#     The check below therefore guards ONE thing only — that the two spellings do not drift apart.
#     ⛔ AND QUOTE THAT WEAKER GUARANTEE, NOT THE OLD ONE (hq_T, 2026-09-08): a DRIFT guard greens whenever
#     the two spellings AGREE, and they will keep agreeing while both are wrong in the same way.  It can tell
#     you the predicate HAS NOT CHANGED; it can never tell you the predicate is RIGHT.  The old sentence
#     claimed the stronger thing, and the stronger thing is what a hurried reader remembers.
#
# (3) ⭐ --behind: A DEAD PIN DOES NOT MERELY MISCLASSIFY, IT CONCEALS (ceo CEO-427, 2026-09-08).  Because the
#     ref pins a transcript of SPITBOL dying, the suite never compares SCRIP's real output to anything -- it
#     sees a mismatch, writes FAIL, and nobody asks what our output WAS.  The ceo found three programs that
#     ABORT behind their dead pins, one cause, invisible for as long as the pins existed.  `--behind` runs
#     SCRIP on each dead-pinned program and reports WHAT THE PIN WAS HIDING: CRASH / TIMEOUT / rc + line count.
#     ⛔ IT FEEDS STDIN THROUGH split_at_end, THE SUITE'S OWN CONVENTION (stdin follows the END statement in
#     the same file).  A </dev/null run here would print a clean-looking table from a STARVED program -- the
#     trap that took hq_P, the cto and the ceo in one night, the last of them while actively looking for it.
#
# Exit: 0 = censused (any count; a report is not a verdict).  2 = REFUSED, could not measure.
set -u
BEHIND=0
for a in "$@"; do case "$a" in
  --behind) BEHIND=1 ;;
  -h|--help) echo "usage: $0 [--behind]   (--behind also runs SCRIP on each dead-pinned program and reports what the pin conceals)"; exit 0 ;;
  *) echo "⛔ REFUSE(2): unknown argument '$a' -- refusing rather than ignoring it and printing a census you did not ask for"; exit 2 ;;
esac; done
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
CORPUS="${CORPUS:-$ROOT/corpus}"
AUTH="$HERE/scorecard_snobol4.sh"
[ -d "$CORPUS" ] || { echo "⛔ REFUSE(2): no corpus at $CORPUS -- cannot measure"; exit 2; }

# ONE AUTHORITY FOR THE PREDICATE, checked rather than copied blind.
if [ -r "$AUTH" ]; then
  n=$(grep -c '^sbl_died() {' "$AUTH")
  if [ "$n" != 1 ]; then
    echo "⛔ REFUSE(2): sbl_died is defined $n times in scorecard_snobol4.sh -- the authority is ambiguous, refusing to guess"; exit 2
  fi
  auth_line=$(grep '^sbl_died() {' "$AUTH")
  case "$auth_line" in
    *'grep -aqE'*) : ;;
    *) DIVERGE="$auth_line" ;;
  esac
fi

# The predicate: BOTH halves, which is what separates a fatal TERMINATION REPORT from ordinary error text.
# (gimpel/ALL.ref carries 37 ` : ERROR NNN -- ` lines and ZERO `in statement` lines -- error output a program
# legitimately produces and handles.  The conjunction is load-bearing; do not weaken it to one half.)
pin_is_dead() { grep -aqE ' : ERROR [0-9][0-9][0-9] -- ' "$1" && grep -aqE '^in statement +[0-9]+$' "$1"; }

echo "DEAD-PINNED REF CENSUS -- pins whose own content transcribes the oracle's death"
echo "corpus: $CORPUS"
echo "stamp:  $(cd "$CORPUS" && git rev-parse --short HEAD 2>/dev/null || echo '(not a git tree)')$(cd "$CORPUS" && git diff --quiet 2>/dev/null || echo -dirty)"
echo
printf '%-52s %-9s %-9s %s\n' DIRECTORY PINS DEAD NAMES
seen_any=0; tot_pins=0; tot_dead=0; dead_dirs=""
DEADLIST=$(mktemp) || exit 2; trap 'rm -f "$DEADLIST"' EXIT
while IFS= read -r d; do
  pins=0; dead=0; names=""
  while IFS= read -r f; do
    pins=$((pins+1))
    if pin_is_dead "$f"; then dead=$((dead+1)); b="$(basename "$f")"; names="$names ${b%.*}"; printf '%s\n' "$f" >> "$DEADLIST"; fi
  done < <(find "$d" -type f \( -name '*.ref' -o -name '*.std' \) ! -name 'ALL.ref' 2>/dev/null | sort)
  tot_pins=$((tot_pins+pins)); tot_dead=$((tot_dead+dead)); [ "$pins" -gt 0 ] && seen_any=1
  if [ "$pins" -eq 0 ]; then
    printf '%-52s %-9s %-9s %s\n' "${d#$CORPUS/}" NO-PINS "-" "(graded live against the oracle, or no oracle)"
  else
    printf '%-52s %-9s %-9s %s\n' "${d#$CORPUS/}" "$pins" "$dead" "$(echo $names)"
    [ "$dead" -gt 0 ] && dead_dirs="$dead_dirs ${d#$CORPUS/}"
  fi
done < <( { find "$CORPUS/packages" -mindepth 2 -maxdepth 2 -type d 2>/dev/null; find "$CORPUS/tests" -mindepth 1 -maxdepth 1 -type d 2>/dev/null; } | sort )

# ⛔ ALL.ref IS EXCLUDED FROM THE PER-FILE LOOP ABOVE and counted only here.  It is one file holding many
# entries: counting it there as "1 dead pin" AND here as "3 dead entries" made this census's own total read
# 26 for 25 real entries.  A census that double-counts is the same defect as one that undercounts.
# ⛔ A CONCATENATED RUNGS IS ONE FILE HOLDING MANY ENTRIES, so the per-file loop above counts it as a single
# pin and would UNDERCOUNT it to 1.  Counted separately, by occurrence, and this is where the three hidden
# rungs entries live.  Named by the source line of each fatal report, which carries the program's own name.
echo
echo "CONCATENATED RUNG_SUITES (one file, many entries -- counted by occurrence, not by file):"
while IFS= read -r f; do
  k=$(grep -acE '^in statement +[0-9]+$' "$f")
  if [ "${k:-0}" -gt 0 ]; then
    printf '  %-50s dead_entries=%s\n' "${f#$CORPUS/}" "$k"
    grep -aoE '^[A-Za-z0-9_.-]+\.sno\([0-9]+\) : ERROR [0-9][0-9][0-9] -- .*' "$f" | sed 's/^/      /'
    tot_dead=$((tot_dead+k)); dead_dirs="$dead_dirs ${f#$CORPUS/}"
  else
    printf '  %-50s dead_entries=0\n' "${f#$CORPUS/}"
  fi
done < <(find "$CORPUS" -type f -name 'ALL.ref' 2>/dev/null | sort)

echo
[ "$seen_any" = 1 ] || { echo "⛔ REFUSE(2): zero pin files found anywhere under $CORPUS -- a census over nothing, not a clean corpus"; exit 2; }
echo "TOTAL dead-pinned entries: $tot_dead   (per-program pins examined: $tot_pins)"
echo "affected:$dead_dirs"
[ -n "${DIVERGE:-}" ] && { echo; echo "⚠️ PREDICATE DRIFT -- this census matches with -a and scorecard_snobol4.sh's sbl_died no longer does."; echo "   ⛔ This is NOT a claim that a number is being hidden: GNU grep in a script answers the same either way"; echo "   (measured 2026-09-08, hq_T + hq_B, on the real rungs). It is a spelling-drift guard only -- -a is"; echo "   insurance against a non-GNU grep on PATH, at zero verdict cost. Restore -a there and this goes quiet."; echo "   authority: $DIVERGE"; }
# ⭐ WHAT THE PINS CONCEAL (ceo CEO-427).  Opt-in, because it BUILDS NOTHING but does RUN every dead-pinned
# program, and a census must stay cheap enough that nobody skips it.
if [ "$BEHIND" = 1 ]; then
  echo
  echo "WHAT THE DEAD PINS CONCEAL -- SCRIP's own behaviour behind each pin (stdin via split_at_end)"
  SCRIP_BIN="${SCRIP_BIN:-$ROOT/SCRIP/scrip}"
  if [ ! -x "$SCRIP_BIN" ]; then
    echo "⛔ REFUSE(2): no scrip binary at $SCRIP_BIN -- cannot say what is behind a pin, and a blank column would read as 'nothing'"; exit 2
  fi
  W=$(mktemp -d) || exit 2
  printf '%-46s %-10s %s\n' PROGRAM VERDICT DETAIL
  nb=0; ncrash=0
  while IFS= read -r pin; do
    [ -n "$pin" ] || continue
    d=$(dirname "$pin"); b=$(basename "$pin"); stem="${b%.*}"; src=""
    srcext=""
    for ext in sno sc icn; do [ -f "$d/$stem.$ext" ] && { src="$d/$stem.$ext"; srcext="$ext"; break; }; done
    if [ -z "$src" ]; then printf '%-46s %-10s %s\n' "$stem" NO-SOURCE "pin has no sibling program -- cannot run it"; continue; fi
    nb=$((nb+1))
    rm -rf "$W/r"; mkdir -p "$W/r"; cp -rp "$d"/. "$W/r"/ 2>/dev/null || true
    # ⛔ split_at_end: stdin follows the END statement IN THE SAME FILE.  Never </dev/null here.
    # ⛔⭐ THE PROGRAM KEEPS ITS OWN EXTENSION.  The first cut of this block wrote "$stem.run" and SCRIP
    # infers the FRONTEND FROM THE EXTENSION -- so every program was run as an unknown language and the
    # table reported 10 CRASHes that were artifacts of this instrument, not defects.  Caught only by
    # checking a row against a ceo ruling that said the same program was clean.  Same family as everything
    # else in this file: an instrument answering a narrower question than the one asked, silently.
    python3 - "$src" "$W/r/$stem.$srcext" "$W/r/$stem.in" <<'SPLITPY'
import re, sys
lines = open(sys.argv[1], 'r', errors='replace').read().split('\n')
idx = next((i for i, l in enumerate(lines) if re.match(r'^END\s*$', l, re.IGNORECASE)), None)
if idx is None:
    open(sys.argv[2], 'w').write('\n'.join(lines)); open(sys.argv[3], 'w').write('')
else:
    open(sys.argv[2], 'w').write('\n'.join(lines[:idx+1]) + '\n'); open(sys.argv[3], 'w').write('\n'.join(lines[idx+1:]))
SPLITPY
    ( cd "$W/r" && timeout -k 5 20 "$SCRIP_BIN" "$stem.$srcext" < "$stem.in" > "$stem.out" 2>&1 ); rc=$?
    lines=$(wc -l < "$W/r/$stem.out" 2>/dev/null || echo 0)
    case "$rc" in
      139) v=CRASH; det="SIGSEGV (rc=139) -- $lines line(s) before it";  ncrash=$((ncrash+1)) ;;
      134) v=CRASH; det="SIGABRT (rc=134) -- $lines line(s) before it";  ncrash=$((ncrash+1)) ;;
      124) v=TIMEOUT; det="killed at 20s -- $lines line(s) so far" ;;
      0)   v=ran;   det="rc=0, $lines line(s)" ;;
      *)   v=ran;   det="rc=$rc, $lines line(s)" ;;
    esac
    printf '%-46s %-10s %s\n' "$stem" "$v" "$det"
  done < "$DEADLIST"
  rm -rf "$W"
  echo
  echo "behind $nb dead-pinned program(s): $ncrash CRASH"
  [ "$ncrash" -gt 0 ] && echo "⛔ A CRASH BEHIND A PIN WAS NEVER GRADED AGAINST ANYTHING -- the suite saw a mismatch and wrote FAIL."
fi
exit 0
