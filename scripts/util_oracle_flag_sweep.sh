#!/usr/bin/env bash
# util_oracle_flag_sweep.sh -- measure what the SPITBOL ORACLE FLAG is worth, per program, both arms.
#
# WHY THIS EXISTS.  scorecard_snobol4.sh runs the live oracle as `sbl -b` for 12 of its 13 suites (11 once the off-limits lon suite is set aside) and
# `sbl -bf` for beauty_self alone.  `-b` only suppresses the sign-on banner (manual l.6944); `-f` is the
# CASE-FOLDING switch (l.6945), and folding is SPITBOL's DEFAULT (l.1205, l.7049).  Per the manual's own
# words (l.11074-11077) `-f` is what you use "if compatibility with standard SNOBOL4 is desired", and
# RULES.md declares SCRIP IS CASE-SENSITIVE.  So the flag is a LANGUAGE-SEMANTICS SWITCH, not a cosmetic
# one, and which arm is "ground truth" decides what a whole class of programs is graded against.
#
#   sweep      <outdir> [jobs]   3 arms per program: -b, -b again (CONTROL), -bf.  Tags each row
#                                same | MOVER | FLAKY.  FLAKY = the two SAME-FLAG control runs disagree,
#                                so that program cannot testify about the flag at all -- without this arm
#                                timing-bearing and runaway programs read as false MOVERs (measured: the
#                                2-arm form reported 103 movers where 3-arm reports 77 + 26 flaky).
#   transition <outdir>          for every MOVER, does flipping the LIVE arm change the scorecard VERDICT?
#                                Replays grade(): PASS iff output == pinned .ref OR == live arm (live counts
#                                only when the oracle exited 0).  Reports m3 and m4 before -> after.
#
# ⛔⭐ THE lon EXCLUSION HERE IS CORRECT, BUT ITS STATED REASON IS RETRACTED -- READ THIS BEFORE CITING THE LINE BELOW.
# ⭐ WHAT LON ACTUALLY RULED, 2026-08-27, in-chat to CEO, verbatim in substance: "Do not use the lon_cherryholmes folder as runtime tests.  Use them for parser tests
# all day long.  And in fact, all the corpus/programs need work and cannot be converted to tests currently."  Mechanically: PARSER TESTS unrestricted; RUNTIME AND
# SCORED BOARDS no; the whole corpus/programs/ tree (EBNF, lon_cherryholmes, TZ) is not convertible to tests currently.  Reading, compiling, running BY HAND, citing
# and measuring all stay free -- the restriction is solely about installing these programs AS TESTS.  Authority: RULES.md ABSOLUTE RULES, the lon_cherryholmes block.
# ⭐ THIS SWEEP EXECUTES PROGRAMS: it runs the live oracle as `"$SBL" -b/-bf ... "$prog"` (three arms, 60s timeout each), so it is a RUNTIME harness, and runtime is
# exactly what Lon closed.  The exclusion therefore STANDS on the 2026-08-27 ruling -- not on the s186 off-limits law, which Lon RETRACTED at s269 ("I retract all of
# it").  ⛔ A compile-only sweep would be a PARSER test and unrestricted; this one is not.  Do not copy this guard into a compile-only harness by analogy.
# ⚠️ KNOWN, NOT CURED HERE (hq_P 2026-08-27, comment-only commit): the guard's pattern is `*/programs/lon/*` and the tree was renamed to `programs/lon_cherryholmes/`
# by the s272 re-grid, so IT NO LONGER MATCHES AND HAS BEEN SILENTLY INERT SINCE.  ⛔ A guard keyed on a NAME is not a guard, it is a coincidence.  Repairing it is a
# BEHAVIOURAL change and this commit is comment-only by grant (hq_C, ceo) -- it needs its own attributed commit with measured, re-pinned totals.
# ⛔ HISTORICAL, SUPERSEDED, KEPT FOR THE RECORD ONLY: corpus/lon/ IS OFF LIMITS (RULES.md ABSOLUTE RULES; Lon s186).  TWO INDEPENDENT LOCKS: the
#    `lon` suite is not enumerated at all, AND every program path is re-checked before it is run.  This
#    script is therefore usable where scorecard_snobol4.sh currently is not.
# ⛔ ^iters:/^ms: lines are deleted from every arm before hashing (the scorecard's own norm=ms rule).
set -u
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"
SC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
CORPUS="${CORPUS:-$S4E/corpus}"; SBL="${SBL:-$S4A/x64/bin/sbl}"; SCRIP="${SCRIP:-$SC/scrip}"
DEMO="$CORPUS/demos"
# ⛔ s191: SPITBOL's ABNORMAL-TERMINATION report carries ENVIRONMENT-DEPENDENT lines, and without stripping them this
#    sweep REPORTS ITS OWN NOISE AS FLAG SENSITIVITY.  Measured: csnobol4_suite/tab.sno had its keywords uppercased
#    CORRECTLY -- normalized -bf output byte-identical to the pre-edit -b output -- and still read as a MOVER on
#    `memory used (bytes) 15912` vs `15888` alone (24 bytes, the symbol table holding different identifier strings).
#    4 of the 42 movers at s191 dissolved on this rule with nothing else changed.  Same argument the iters:/ms: rule
#    already makes.  `stmts executed` and `REGENERATIONS` are DELIBERATELY LEFT IN: those are deterministic given the
#    program, so a change in them is a real behavioural change this sweep should keep failing on.
NRM='/^iters: [0-9][0-9]*$/d; /^ns: [0-9][0-9]*$/d; /^ms: [0-9][0-9]*$/d; /^execution time msec[[:space:]][[:space:]]*[0-9][0-9]*$/d; /^memory used (bytes)[[:space:]][[:space:]]*[0-9][0-9]*$/d; /^memory left (bytes)[[:space:]][[:space:]]*[0-9][0-9]*$/d'
[ -x "$SBL" ] || { echo "FATAL: no oracle at $SBL -- a board without it prints a plausible all-FAIL table (PLAN.md 1b)"; exit 1; }
# ⛔ SINGLE AUTHORITY (row `suite-table-one-authority`, fixed 2026-08-24 -- this table used to be a
# SECOND COPY of scorecard_snobol4.sh's SUITES table, and the two drifted independently at least twice
# (s191's gimpel `-name *_driver.sno` fix had to be hand-mirrored here; a `demos` maxdepth divergence,
# 2 vs 1, was found live and unremarked at this fix's own mint -- neither editor had noticed). A sweep
# enumerating rows the scorecard does not score reports movers on programs no board grades, which reads
# as evidence, not noise. NOW: extracted from scorecard_snobol4.sh's own table at RUN TIME via its
# `SCORECARD_PRINT_SUITES=1` hook (post its own lon-guard), projected down to the 4 columns this sweep
# needs (name, root, find-args, lib -- weight/timeout/norm are scorecard-only and dropped). ⛔ REFUSES
# (rc!=0), NEVER falls back to a private copy, on ANY extraction failure -- a silent fallback here is
# exactly the bug this row exists to kill, so failure must be loud, not quiet. Negative-tested by
# injection (missing script, script exiting nonzero, empty output, malformed row) -- see the task's own
# LEDGER/FINDING for receipts.
SCORECARD_SH="$SC/../harness/scripts/scorecard_snobol4.sh"
[ -x "$SCORECARD_SH" ] || { echo "FATAL: cannot extract SUITES -- $SCORECARD_SH missing or not executable. Refusing rather than falling back to a private copy." >&2; exit 1; }
_sc_raw="$(SCORECARD_PRINT_SUITES=1 "$SCORECARD_SH" 2>&1)"; _sc_rc=$?
if [ "$_sc_rc" -ne 0 ]; then echo "FATAL: scorecard_snobol4.sh SCORECARD_PRINT_SUITES=1 exited $_sc_rc -- refusing rather than falling back to a private copy. Output was:" >&2; printf '%s\n' "$_sc_raw" >&2; exit 1; fi
[ -n "$_sc_raw" ] || { echo "FATAL: scorecard_snobol4.sh SCORECARD_PRINT_SUITES=1 printed nothing -- refusing rather than falling back to a private copy." >&2; exit 1; }
SUITES="$(printf '%s\n' "$_sc_raw" | awk 'NF<7{print "FATAL: malformed SUITES row from scorecard (need >=7 fields, got "NF"): " $0 > "/dev/stderr"; bad=1; next} {fa=""; for(i=4;i<=NF-3;i++) fa=fa (fa==""?"":" ") $i; print $1, $3, fa, $(NF-2)} END{if(bad) exit 1}')" || { echo "FATAL: SUITES extraction/projection from scorecard_snobol4.sh failed -- refusing rather than falling back to a private copy." >&2; exit 1; }
[ -n "$SUITES" ] || { echo "FATAL: projected SUITES table is empty after extraction -- refusing rather than falling back to a private copy." >&2; exit 1; }
unset _sc_raw _sc_rc
MISC_DIRS="tests/snobol4/feat tests/snobol4/parser tests/snobol4/smoke tests/snobol4/jvm_j3 tests/snobol4/linker packages/snobol4/dotnet packages/snobol4/aisnobol"
stdin_for() { local p="$1" b d n; b="${p%.sno}"; d="$(dirname "$p")"; n="$(basename "$b")"
  [ -f "$b.input" ] && { echo "$b.input"; return; }; [ -f "$b.in" ] && { echo "$b.in"; return; }
  case "$d" in "$DEMO") case "$n" in claws5*) echo "$DEMO/claws5/claws5.input";; treebank*) echo "$DEMO/treebank/treebank.input";; json*) echo "$DEMO/json/json.input";;
    calculator*) echo "$DEMO/calculator/calculator.input";; porter*) echo "$DEMO/porter/porter.input";; *) echo /dev/null;; esac; return;; esac; echo /dev/null; }
sc_libpath() { local spec="$1" pd="$2" e out="" oi="$IFS"; IFS=':'; for e in $spec; do case "$e" in SELFDIR) e="$pd";; CORPUS) e="$CORPUS";; *) e="$CORPUS/$e";; esac; out="${out:+$out:}$e"; done; IFS="$oi"; echo "$out"; }
libspec_for() { case "$1" in beauty_self) echo include;; patterns|crosscheck) echo demo/inc;; feature_test) echo CORPUS;; gimpel) echo SELFDIR:include;; *) echo SELFDIR;; esac; }
# ⛔⭐ THIS GUARD IS DEFENCE-IN-DEPTH BEHIND A DOOR THAT IS ALREADY SHUT -- READ WHY BEFORE JUDGING ITS VALUE (hq_P s274).
# It names the tree as spelled TODAY. Its old pattern was */programs/lon/*, which stopped matching when the s272 re-grid
# renamed lon/ -> lon_cherryholmes/, so it had been silently inert. ⛔ A guard keyed on a NAME is not a guard, it is a
# coincidence -- and a dead guard is indistinguishable from an absent one in the output.
# ⭐ BUT MEASURE BEFORE YOU CALL A DEAD GUARD AN EXPOSURE, WHICH IS THE MISTAKE I MADE AND CORRECTED: this sweep does NOT
# walk the corpus. It enumerates from the scorecard's SUITES table (SCORECARD_PRINT_SUITES=1) plus MISC_DIRS, and NOT ONE
# of those roots is under corpus/programs/ -- verified by execution s274. lon_cherryholmes was therefore never reachable
# here even while the guard was inert, because the scorecard row for it is DELETED STRUCTURALLY rather than filtered.
# ⛔ CONTRAST WITH test_gate_argnote_sweep.sh, where the identical dead pattern WAS load-bearing: that gate roots at the
# CORPUS ROOT and finds every .sno, so 99 files really did start flowing when its prune died. Two guards, both dead, only
# one of them ever doing anything. Do not generalise one measurement to the other -- I did, and was wrong.
# ⭐ IT STILL EARNS ITS PLACE: this sweep EXECUTES programs (it runs the live oracle, three arms, 60s each), and Lon ruled
# 2026-08-27 that lon_cherryholmes is for PARSER tests only, never runtime. If anyone ever adds a suite root under
# programs/, this is the second lock that stops a runtime run -- which is exactly the job the scorecard comment assigns it.
lon_guard() { case "$1" in */programs/lon_cherryholmes/*|*/programs/lon/*) echo "REFUSED: lon_cherryholmes is PARSER-TESTS-ONLY, never runtime (Lon 2026-08-27); this sweep EXECUTES the oracle. Path: $1" >&2; return 1;; esac; return 0; }
one_prog() {
  local name="$1" lib="$2" prog="$3" d in L W r1 r2 rf m1 m2 mf tag
  lon_guard "$prog" || return
  d="$(dirname "$prog")"; in="$(stdin_for "$prog")"; L="$(sc_libpath "$lib" "$d")"
  [ "$name" = beauty_self ] && in="$prog"
  W="$(mktemp -d)"
  (cd "$d" && SETL4PATH=".:$L" timeout -k 5 60 "$SBL" -b  -d512m -i64m "$prog" < "$in" > "$W/b1" 2>/dev/null); r1=$?
  (cd "$d" && SETL4PATH=".:$L" timeout -k 5 60 "$SBL" -b  -d512m -i64m "$prog" < "$in" > "$W/b2" 2>/dev/null); r2=$?
  (cd "$d" && SETL4PATH=".:$L" timeout -k 5 60 "$SBL" -bf -d512m -i64m "$prog" < "$in" > "$W/f"  2>/dev/null); rf=$?
  sed -i "$NRM" "$W/b1" "$W/b2" "$W/f"
  m1=$(md5sum < "$W/b1" | cut -c1-12); m2=$(md5sum < "$W/b2" | cut -c1-12); mf=$(md5sum < "$W/f" | cut -c1-12)
  if [ "$m1" != "$m2" ] || [ "$r1" != "$r2" ]; then tag=FLAKY
  elif [ "$m1" != "$mf" ] || [ "$r1" != "$rf" ]; then tag=MOVER; else tag=same; fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "${prog#$CORPUS/}" "$r1" "$rf" "$m1" "$mf" "$tag"
  rm -rf "$W"
}
export -f one_prog stdin_for sc_libpath lon_guard; export CORPUS SBL DEMO NRM
cmd_sweep() {
  local out="${1:?usage: sweep <outdir> [jobs]}" jobs="${2:-8}" name root rest nf lib fargs list m
  mkdir -p "$out"; : > "$out/arms.tsv"; set -f
  echo "$SUITES" | while read -r name root rest; do
    [ -z "$name" ] && continue
    set -- $rest; nf=$#; lib=${!nf}; fargs="${*:1:$((nf-1))}"; list="$out/list.$name"
    case "$root" in
      SELF)      echo "$DEMO/beauty/beauty.sno" > "$list";;
      SCRIPTEST) find "$SC/test" $fargs 2>/dev/null | sort > "$list";;
      MISC)      : > "$list"; for m in $MISC_DIRS; do find "$CORPUS/$m" $fargs 2>/dev/null; done | sort >> "$list";;
      *)         find "$CORPUS/$root" $fargs 2>/dev/null | sort > "$list";;
    esac
    grep -v -e '/programs/lon/' -e '/programs/lon_cherryholmes/' "$list" > "$list.safe" && mv "$list.safe" "$list"
    echo "== $name: $(wc -l < "$list") programs  $(date +%H:%M:%S)" >&2
    xargs -a "$list" -P "$jobs" -I{} bash -c 'one_prog "$0" "$1" "$2"' "$name" "$lib" {} >> "$out/arms.tsv" 2>>"$out/noise.log"
  done
  echo "DONE $(date +%H:%M:%S)  rows=$(wc -l < "$out/arms.tsv")" >&2
  awk -F'\t' '{t[$7]++} END{printf "same=%d MOVER=%d FLAKY=%d\n", t["same"], t["MOVER"], t["FLAKY"]}' "$out/arms.tsv"
}
cmd_transition() {
  local out="${1:?usage: transition <outdir>}" suite prog rb rf mb mf tag full d in L W rcb rcf hp ref b3 a3 b4 a4 m4
  while IFS=$'\t' read -r suite prog rb rf mb mf tag; do
    [ "$tag" = MOVER ] || continue
    case "$prog" in /*) full="$prog";; *) full="$CORPUS/$prog";; esac
    [ -f "$full" ] || continue; lon_guard "$full" || continue
    d="$(dirname "$full")"; in="$(stdin_for "$full")"; L="$(sc_libpath "$(libspec_for "$suite")" "$d")"
    [ "$suite" = beauty_self ] && in="$full"
    W="$(mktemp -d)"
    (cd "$d" && SETL4PATH=".:$L" timeout -k 5 60 "$SBL" -b  -d512m -i64m "$full" < "$in" > "$W/b" 2>/dev/null); rcb=$?
    (cd "$d" && SETL4PATH=".:$L" timeout -k 5 60 "$SBL" -bf -d512m -i64m "$full" < "$in" > "$W/f" 2>/dev/null); rcf=$?
    ref="${full%.sno}.ref"; hp=0; [ -f "$ref" ] && { sed "$NRM" "$ref" > "$W/pin"; hp=1; }
    (cd "$d" && SNO_LIB="$L" timeout -k 5 30 "$SCRIP" --run "$full" < "$in" > "$W/m3" 2>/dev/null)
    m4=SKIP
    if (cd "$d" && SNO_LIB="$L" timeout -k 5 60 "$SCRIP" --compile "$full" </dev/null > "$W/p.s" 2>/dev/null) && [ -s "$W/p.s" ] \
       && gcc -no-pie "$W/p.s" -L"$SC/out" -lscrip_rt -lm -Wl,-rpath,"$SC/out" -o "$W/p.bin" 2>/dev/null; then
         (cd "$d" && SNO_LIB="$L" timeout -k 5 30 "$W/p.bin" < "$in" > "$W/m4o" 2>/dev/null); m4=RAN; fi
    sed -i "$NRM" "$W/b" "$W/f" "$W/m3"; [ "$m4" = RAN ] && sed -i "$NRM" "$W/m4o"
    verdict() { local o="$1" lv="$2" lrc="$3"
      { [ $hp = 1 ] && cmp -s "$o" "$W/pin"; } && { echo PASS; return; }
      { [ "$lrc" = 0 ] && cmp -s "$o" "$lv"; } && { echo PASS; return; }; echo FAIL; }
    b3=$(verdict "$W/m3" "$W/b" $rcb); a3=$(verdict "$W/m3" "$W/f" $rcf)
    if [ "$m4" = RAN ]; then b4=$(verdict "$W/m4o" "$W/b" $rcb); a4=$(verdict "$W/m4o" "$W/f" $rcf); else b4=NOBUILD; a4=NOBUILD; fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$suite" "$prog" "$b3" "$a3" "$b4" "$a4"
    rm -rf "$W"
  done < "$out/arms.tsv" | tee "$out/transition.tsv"
  echo "-- m3 --"; awk -F'\t' '{print $3" -> "$4}' "$out/transition.tsv" | sort | uniq -c | sort -rn
  echo "-- m4 --"; awk -F'\t' '{print $5" -> "$6}' "$out/transition.tsv" | sort | uniq -c | sort -rn
}
case "${1:-}" in
  sweep)      shift; cmd_sweep "$@";;
  transition) shift; cmd_transition "$@";;
  *) echo "usage: $0 sweep <outdir> [jobs] | $0 transition <outdir>"; exit 2;;
esac
