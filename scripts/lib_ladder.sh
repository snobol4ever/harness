#!/usr/bin/env bash
# (the blanket `export SCRIP_SNO_STMTKW=1` that stood here typed the SNOBOL4 statement instrumentation for EVERY language's ladder; since 2026-09-28 each witness carries its own declared --stlimit in its <stem>.cmdline compile_args, read below -- CEO-1353, the coo)
# lib_ladder.sh -- THE ONE CONSTRUCT-LADDER RUNNER BODY, shared by every language's test_<lang>_ladder.sh
# (GOAL-TEST-SUITE-CONSISTENCY.md standard point 1; row test-suite-consistency-seven-languages-one-standard,
# hq_T 2026-09-03). Extracted from test_prolog_ladder.sh (hq_P/hq_C) and test_raku_ladder.sh (seat11), whose
# bodies were byte-identical apart from four language tokens -- so this file IS those two runners, once.
#
# A per-language runner sets three variables and calls ladder_main "$@":
#   LADDER_LANG   display name used in refusal text            e.g. Prolog
#   LADDER_SUITE  directory under corpus/tests/                e.g. prolog
#   LADDER_EXT    rungs/source extension, leading dot         e.g. .pl
# Everything else -- the interface, the population rule, the grading, the printed shape -- is here and is
# THE SAME FOR ALL SEVEN LANGUAGES, which is the entire point: one instrument body, seven instantiations.
#
#   --to N     grade rungs 0..N CUMULATIVELY (default: every rung the rungs carries)
#   --only N   grade rung N ALONE -- the rung under construction, while the rungs below it are still red.
#              Mutually exclusive with --to: a request naming both REFUSES rc=2 rather than guessing.
#   --list     print the witnesses per rung and exit 0 without grading
# ⛔⭐ THE DEFAULT (NO SELECTOR) GRADES UNBUILT RUNGS TOO, so it reads WORSE than the ladder's frontier and is
# not the number to quote for 'how far is the ladder'. Measured 2026-09-03 on Prolog: the unselected run is 33
# witnesses / 66 gradings because ALL.csv already carries rung 10-12 witnesses for rungs nobody has built,
# while `--to 9` -- the actual frontier -- is 28 / 56. Two sessions compared those two numbers and briefly
# suspected the runner of miscounting (hq_T/hq_C, same day). ⭐ `--to N` is the ONLY honest way to ask how far
# the ladder reaches; the bare default answers a different question -- 'everything the rungs mentions'.
# POPULATION: every origin `ladder__rungNN_<slug>` of corpus/tests/<suite>/ALL.csv with NN <= N, materialized
# OUT of the rungs by origin through lib_rungs_extract.sh -- keyed on the CSV `origin` column, never on the
# entry name or a filename glob.
# EACH WITNESS RUNS ALONE IN BOTH MODES:  m3 = scrip --run  ·  m4 = scrip --compile -o x.s + as --64 + gcc -no-pie + run
# Verdict per witness per mode: stdout byte-equal to the .ref AND rc equal to the declared rc (ALL.wantrc,
# keyed on the entry NAME; default 0, and the file need not exist). A timeout is a FAIL(rc=124), never a hang.
# ⭐ REFS ARE ORACLE-CUT, NOT HAND-AUTHORED, and this body never re-invokes an oracle at grading time: the
# .ref is the recorded oracle answer, cut once by the language's own oracle, and the runner's only job is
# diffing SCRIP against it. Which oracle cut them is the per-language runner's header to state.
# ⛔ XFAIL MARKERS ARE IGNORED HERE ON PURPOSE: this is the gate for the rung that OWNS the witness, and a
# rung is landed only when its witnesses PASS.
# PRINTS ITS DENOMINATOR. REFUSES rc=2 when it graded ZERO witnesses (no rungs, no ladder origins at or
# below --to N, or an extraction failure) -- a runner that cannot measure never prints the success shape.
# EXIT: 0 every graded witness PASS in both modes · 1 any FAIL · 2 REFUSED (cannot measure).
ladder_main() {
  # ⛔ SCRIP / RT / T / RUNGS_DIR / RUNGS_EXT ARE DELIBERATELY NOT `local`: `local X` shadows the inherited
  # environment, so `local SCRIP` would make SCRIP=... on the command line silently unreachable and the
  # ${SCRIP:-default} fallback would ALWAYS win -- a runner that ignores the binary you pointed it at and
  # grades the default one instead, printing a green board about the wrong tree. Caught by the negative test
  # `SCRIP=/nonexistent/scrip ... --to 0`, which must REFUSE rc=2 and did not (hq_T 2026-09-03).
  local S4E HERE ROOT TO ONLY LIST SEL
  S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
  export TIMEOUT_RETRY="${TIMEOUT_RETRY:-$HERE/util_timeout_retry.sh}"   # a graded run's timeout (CEO-1335): a timeout under load is retried once
  SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"; T="${TIMEOUT:-20}"
  refuse() { echo "REFUSE (rc=2): $*"; exit 2; }
  [ -n "${LADDER_LANG:-}" ] && [ -n "${LADDER_SUITE:-}" ] && [ -n "${LADDER_EXT:-}" ] \
    || refuse "lib_ladder.sh sourced without LADDER_LANG/LADDER_SUITE/LADDER_EXT -- the per-language runner must set all three"
  RUNGS_DIR="$S4E/corpus/tests/$LADDER_SUITE"; RUNGS_EXT="$LADDER_EXT"; export RUNGS_DIR RUNGS_EXT
  TO=""; ONLY=""; LIST=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --to) shift; TO="${1:-}";;
      --to=*) TO="${1#--to=}";;
      --only) shift; ONLY="${1:-}";;
      --only=*) ONLY="${1#--only=}";;
      --list) LIST=1;;
      -h|--help) sed -n '2,20p' "$0"; exit 0;;
      *) echo "REFUSE (rc=2): unknown argument '$1' (usage: $0 [--to N | --only N] [--list])"; exit 2;;
    esac; shift
  done
  case "$TO" in ""|*[!0-9]*) [ -z "$TO" ] || { echo "REFUSE (rc=2): --to wants a rung number, got '$TO'"; exit 2; };; esac
  case "$ONLY" in ""|*[!0-9]*) [ -z "$ONLY" ] || { echo "REFUSE (rc=2): --only wants a rung number, got '$ONLY'"; exit 2; };; esac
  [ -z "$TO" ] || [ -z "$ONLY" ] || { echo "REFUSE (rc=2): --to $TO and --only $ONLY name two different populations (cumulative 0..N vs rung N alone) -- pass one, never both"; exit 2; }
  if [ -n "$ONLY" ]; then SEL="--only $ONLY"; else SEL="--to ${TO:-max}"; fi
  [ -x "$SCRIP" ] || refuse "scrip binary not built at $SCRIP"
  [ -f "$RT/libscrip_rt.so" ] || refuse "runtime library missing at $RT/libscrip_rt.so"
  [ -f "$RUNGS_DIR/ALL$RUNGS_EXT" ] && [ -f "$RUNGS_DIR/ALL.ref" ] && [ -f "$RUNGS_DIR/ALL.csv" ] || refuse "$LADDER_LANG rungs suite missing under $RUNGS_DIR (ALL$RUNGS_EXT / ALL.ref / ALL.csv)"
  . "$HERE/lib_rungs_extract.sh" || refuse "cannot source lib_rungs_extract.sh"
  . "$HERE/lib_declared_arena.sh" || refuse "cannot source lib_declared_arena.sh -- the one reader of a witness's declared heap and stack"
  # ladder_cmdline_words <program> -- two lines: the compile_args and the run_args its <stem>.cmdline declares (empty lines when none),
  # through corpus_suite_harness.cmdline_declarations(), the one reader of a test unit's command line (clause 8 (f), CEO-1281).
  ladder_cmdline_words() { python3 - "$1" "$HERE" <<'PY'
import os, sys
sys.path.insert(0, sys.argv[2])
import corpus_suite_harness as h
decl, _ = h.cmdline_declarations(sys.argv[1])
ca, ra = decl.get(os.path.splitext(os.path.basename(sys.argv[1]))[0], (None, None))
print(" ".join(ca or [])); print(" ".join(ra or []))
PY
  }
  local all_origins; all_origins=$(rungs_origins_of_family ladder 2>/dev/null) || all_origins=""
  [ -n "$all_origins" ] || refuse "no \`ladder\` origins in $RUNGS_DIR/ALL.csv -- the witnesses moved or were never absorbed; re-point, never skip"
  local -a origins=(); local o r
  for o in $(printf '%s\n' $all_origins | sort); do
    r=$(printf '%s' "$o" | sed -nE 's/^ladder__rung([0-9]+)_.*$/\1/p'); [ -n "$r" ] || continue
    r=$((10#$r)); if [ -n "$ONLY" ]; then [ "$r" -eq "$ONLY" ] || continue; else [ -z "$TO" ] || [ "$r" -le "$TO" ] || continue; fi
    origins+=("$r $o")
  done
  [ "${#origins[@]}" -gt 0 ] || refuse "zero ladder__rungNN_* origins selected by $SEL in $RUNGS_DIR/ALL.csv (family present, rung filter empty) -- a rung with no witness is UNMEASURED, never a pass"
  if [ "$LIST" = 1 ]; then printf '%s\n' "${origins[@]}" | sort -n | awk '{printf "rung %2d  %s\n", $1, $2}'; echo "witnesses=${#origins[@]} ($SEL)"; exit 0; fi
  # ⛔⭐ STALE-BINARY PREFLIGHT -- placed HERE, after --list's early exit, on purpose (row harness-and-
  # ladder-runner-refuse-on-a-stale-binary-like-the-artifact-regen-does, ceo -> hq_T 2026-09-04).
  # ⛔ THE WITNESS IS THE CEO'S OWN TWO FALSE-RED AUDITS ON 2026-09-04: a 10:57 binary read RED at 14:03
  # and GREEN after an incremental make -- so the ladder's verdict was a statement about a program nobody
  # was shipping, and NOTHING in the printed board contradicted it. The board even stamps `tree: SCRIP=<sha>`,
  # which makes it WORSE than unlabelled: the SHA is read from git and is not evidence about the binary that
  # actually ran (FINDING-2026-08-30-hq_C-the-snobol4-board-grades-whatever-scrip-exists-and-labels-that-
  # verdict-with-git-head.md). test_corpus_snobol4.sh has refused on this since 4c7253e99; the ladders --
  # the instrument the seven-language standard makes every language's frontier gate -- did not.
  # ⭐ NOT BEFORE `--list`: listing witnesses is not grading them, and a refusal there would demand a rebuild
  # to answer a question the binary is not consulted for. The refusal belongs where the verdict is minted.
  "$HERE/util_require_fresh.sh" --gate "${LADDER_SUITE}-ladder" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
  wantrc() { local n="$1"; [ -f "$RUNGS_DIR/ALL.wantrc" ] || { echo 0; return; }; local v; v=$(awk -F'\t' -v n="$n" '$1==n{print $2; exit}' "$RUNGS_DIR/ALL.wantrc"); printf '%s\n' "${v:-0}"; }
  local W; W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
  local n=0 pass=0 fail=0 pair src ref name want r3 r4 v3 v4; local -A rp rf
  # ⭐ THE DEBT COUNTER IS PART OF THE CURE, NOT A DECORATION. Capturing stderr without saying how much of it nobody
  # asserts would replace a silent false green with a silent uncompared stream -- the same defect one step quieter.
  # This prints, on every run, how many witnesses EMIT stderr that no rungs block asserts. It is a work list.
  local unasserted=0 unasserted_names="" _decl_nums="" undeclared=""
  for pair in $(printf '%s\n' "${origins[@]}" | sort -n | tr ' ' ':'); do
    r=${pair%%:*}; o=${pair#*:}; src="$W/$o$RUNGS_EXT"; ref="$W/$o.ref"
    rungs_extract_origin "$o" "$src" "$ref" >/dev/null 2>&1 || refuse "cannot extract $o from the rungs suite (lib_rungs_extract.sh)"
    name=$(rungs_entry_for_origin "$o") || refuse "no entry name for origin $o"
    want=$(wantrc "$name"); n=$((n+1))
    # ⛔⭐ STDIN (row icon-construct-ladder-from-rung-0, seat01): rungs_extract_origin already writes
    # $W/$o.in via rungs_extract_name's --out-in whenever the origin has one (lib_rungs_extract.sh) --
    # this loop just never looked for it and fed /dev/null unconditionally, so no ladder witness in ANY
    # language could ever legitimately read() stdin. Purely additive: no .in present -> /dev/null, byte
    # for byte the prior behavior.
    local stdin_src="$W/$o.in"; [ -f "$stdin_src" ] || stdin_src=/dev/null
    # ⛔⭐ STDERR IS CAPTURED, AND COMPARED ONLY WHERE THE RUNGS DECLARES IT (hq_T 2026-09-09; hq_B .github 367b083e
    # and hq_V's FINDING measured the same gap from both ends, ceo ordered the cure CEO-457 item 3).
    # THE DEFECT: these two graded runs sent stderr to /dev/null, and Icon's &trace writes EXCLUSIVELY there
    # (core.c trace_print_icon) -- so every trace rung in the Icon ladder was graded on stdout alone and COULD NOT FAIL
    # for the reason it was minted. procedure_write_264 holds the one-line ref `A:end` and PASSES while the oracle
    # prints seven lines. corpus/tests/icon/ALL.ref contains ZERO trace-shaped lines. The Arizona suite runner had this
    # right all along (2>&1), which is why tracer.std carries all 85 trace lines -- so the PACKAGES instrument was right
    # and the LADDER instrument was wrong, and the ladder is where rungs are minted.
    # ⛔ WHY NOT SIMPLY 2>&1 LIKE ARIZONA, which is what the ruling first said: hq_V MEASURED that Icon writes a trace
    # line's first column as the SOURCE FILE NAME in a fixed 13-character field truncated FROM THE LEFT, and
    # rungs_extract_origin materialises a witness under its ORIGIN name (40-60 chars). A merged ref is therefore pinned
    # to the extraction basename -- a self-pin on a harness temp filename, which is a WORSE instrument than the one it
    # replaces and would rot the first time an origin is renamed. A separate stream has no such column.
    # ⭐ ADDITIVE, EXACTLY LIKE THE .in SIDECAR ABOVE: no $o.err declared -> stderr is captured but NOT compared, which
    # is byte-for-byte today's behaviour for all 886 entries. A declared block makes it an assertion. So this landing
    # changes ZERO verdicts by construction, and every later change is a deliberate one -- which is the whole reason it
    # is safe to land two days before the announcement.
    local err_ref="$W/$o.err"
    # ⛔⭐ THE WITNESS'S OWN COMMAND LINE (Lon 2026-09-28, ceo CEO-1353; the coo's row instruments-every-runner-passes-each-units-declared-
    # heap-and-stack-...): extract writes the entry's declared heap and stack (<stem>.heap / <stem>.stack) and compile and run args
    # (<stem>.cmdline) beside the witness, and the ladder READS them -- through lib_declared_arena.sh and the harness's own reader, never a
    # copy -- exactly as the harness runs the same entry: m3 scrip --run <compile_args> <sizes> src -- <run_args>; m4 compiles with
    # <compile_args> and no size, and the binary runs <sizes> -- <run_args>. A witness that declares no size is NAMED at the end, never
    # run silently at the default. (It used to type SCRIP_SNO_STMTKW=1 for every language and read no declaration at all.)
    local sw ca ra _cl
    sw=$(declared_switches_beside "$src") || refuse "lib_declared_arena.sh refused the declared heap/stack beside $o -- fix the ALL.csv row; this ladder does not grade around it"
    _cl=$(ladder_cmdline_words "$src") || refuse "the harness refused the declared command line beside $o"
    ca=$(printf '%s\n' "$_cl" | sed -n 1p); ra=$(printf '%s\n' "$_cl" | sed -n 2p)
    [ -n "$sw" ] || undeclared="$undeclared $o"
    # shellcheck disable=SC2086
    r3=$( ( "$TIMEOUT_RETRY" "$T" "$SCRIP" --run $ca $sw "$src" ${ra:+-- $ra} <"$stdin_src" >"$W/$o.m3.out" 2>"$W/$o.m3.err"; echo $? ) 2>/dev/null )
    [ -s "$W/$o.m3.err" ] && [ ! -f "$err_ref" ] && unasserted=$((unasserted+1)) && unasserted_names="$unasserted_names $o"
    if [ "$r3" = "$want" ] && cmp -s "$W/$o.m3.out" "$ref" && { [ ! -f "$err_ref" ] || cmp -s "$W/$o.m3.err" "$err_ref"; }; then v3=PASS; pass=$((pass+1)); rp[$r]=$(( ${rp[$r]:-0} + 1 )); else v3="FAIL(rc=$r3)"; fail=$((fail+1)); rf[$r]=$(( ${rf[$r]:-0} + 1 )); fi
    v4=NOBUILD
    # shellcheck disable=SC2086
    if (cd "$W" && "$TIMEOUT_RETRY" "$T" "$SCRIP" --compile $ca -o "$o.s" "$src" </dev/null >/dev/null 2>&1) && [ -s "$W/$o.s" ] \
       && as --64 -o "$W/$o.o" "$W/$o.s" 2>/dev/null && gcc -no-pie -o "$W/$o.bin" "$W/$o.o" "$RT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$RT" 2>/dev/null; then
      # shellcheck disable=SC2086
      r4=$( ( "$TIMEOUT_RETRY" "$T" "$W/$o.bin" $sw ${ra:+-- $ra} <"$stdin_src" >"$W/$o.m4.out" 2>"$W/$o.m4.err"; echo $? ) 2>/dev/null )
      if [ "$r4" = "$want" ] && cmp -s "$W/$o.m4.out" "$ref" && { [ ! -f "$err_ref" ] || cmp -s "$W/$o.m4.err" "$err_ref"; }; then v4=PASS; else v4="FAIL(rc=$r4)"; fi
    fi
    if [ "$v4" = PASS ]; then pass=$((pass+1)); rp[$r]=$(( ${rp[$r]:-0} + 1 )); else fail=$((fail+1)); rf[$r]=$(( ${rf[$r]:-0} + 1 )); fi
    printf 'rung %2d  %-44s m3=%-12s m4=%-12s (%s, want rc=%s)\n' "$r" "$o" "$v3" "$v4" "$name" "$want"
  done
  for r in $(printf '%s\n' "${!rp[@]}" "${!rf[@]}" | sort -nu); do printf 'rung %2d summary: PASS=%d FAIL=%d (witness x mode)\n' "$r" "${rp[$r]:-0}" "${rf[$r]:-0}"; done
  [ -n "$undeclared" ] && printf 'LADDER %s: UNDECLARED heap/stack on %d of %d witness(es) -- run at the runtime default, named (CEO-1353: every unit declares its sizes in its ALL.csv row):%s\n' "$SEL" "$(set -- $undeclared; echo $#)" "$n" "$(printf '%s' "$undeclared" | tr ' ' '\n' | head -12 | tr '\n' ' ')"
  [ "$unasserted" -gt 0 ] && printf 'LADDER %s: stderr UNASSERTED on %d of %d witness(es) -- captured, not compared (no ALL.err block):%s\n' "$SEL" "$unasserted" "$n" "$(printf '%s' "$unasserted_names" | tr ' ' '\n' | head -8 | tr '\n' ' ')"
  # ⛔⭐ `git status --short | grep -q .` WAS A PROVENANCE LIE WAITING FOR LOAD, and it is the same defect this session
  # proved in gate_file_has_fresh_guard: `grep -q .` exits on the FIRST line, the kernel tears down the read end, and a
  # `git status` that has not yet finished writing dies of SIGPIPE (141) -- so under `set -o pipefail` the `&&` fails and
  # **-DIRTY silently disappears from a board stamp taken on a dirty tree.** Measured on the sibling shape: 11 false
  # negatives in 2712 calls at box load 21, every one exit 141. A board that stamps a dirty tree as clean is worse than
  # one that refuses, because the SHA it prints then reads as evidence about a tree nobody has. Capture, then test -- the
  # shape gate_stamp in lib_gate.sh already uses. ⭐ This file was the ONLY one still using the pipeline form for it.
  local _sd="" _cd=""
  [ -n "$(git -C "$ROOT" status --short 2>/dev/null)" ] && _sd="-DIRTY"
  [ -n "$(git -C "$S4E/corpus" status --short 2>/dev/null)" ] && _cd="-DIRTY"
  echo "LADDER $SEL: witnesses=$n modes=2 (m3 --run, m4 --compile+as+gcc) graded=$((n*2)) PASS=$pass FAIL=$fail  tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo ?)$_sd corpus=$(git -C "$S4E/corpus" rev-parse --short HEAD 2>/dev/null || echo ?)$_cd"
  [ "$n" -gt 0 ] || refuse "graded ZERO witnesses -- cannot measure, not a pass"
  # ⛔⭐ A RUNG DECLARED IN LADDER.tsv AND NOT BUILT IS RED, NOT ABSENT. The population comes from ALL.csv's
  # `ladder__rungNN_*` origins, so a rung nobody has written simply is not in it -- and `--to <top>` then
  # grades the rungs that HAPPEN to exist and prints the success shape over the gaps. MEASURED, on Rebus,
  # against this row's own DONE-WHEN: with rungs 0-5 built and 6-11 declared, `--to 11` printed
  # "✅ LADDER OK: rungs 0..11 PASS 22/22" and rc=0. The DONE-WHEN would have CLOSED THE ROW with six of
  # twelve constructs never implemented. ⭐ This is the missing-denominator defect wearing a ladder's
  # clothes: the runner reported PASS over the population it could see, and the population was the answer.
  # LADDER.tsv is the DECLARED census (its last line is the top); when it exists, every rung it declares at
  # or below the requested ceiling must have at least one witness, or this REFUSES rc=2 and names them.
  _ltsv="$RUNGS_DIR/config/LADDER.tsv"
  if [ -f "$_ltsv" ]; then
      _ceiling="${ONLY:-${TO:-9999}}"
      _undeclared=""
      while read -r _r _rest; do
          case "$_r" in rung[0-9]*) ;; *) continue;; esac
          _num=$(printf '%s' "$_r" | sed 's/^rung0*//'); [ -n "$_num" ] || _num=0
          [ "$_num" -le "$_ceiling" ] 2>/dev/null || continue
          if [ -n "$ONLY" ] && [ "$_num" -ne "$ONLY" ]; then continue; fi
          # ⛔ SAME CLASS: `| grep -qx` exits on its first match, so under load the upstream can die 141 and pipefail turns
          # that into "rung not declared" -- a false accusation against a rung that IS declared. Capture, then test.
          _decl_nums="$(printf '%s\n' "${origins[@]}" | awk '{print $1}')"
          grep -qx "$_num" <<<"$_decl_nums" || _undeclared="$_undeclared $_r"
      done < "$_ltsv"
      [ -z "$_undeclared" ] || refuse "LADDER.tsv declares rung(s)$_undeclared at or below $_ceiling with NO witness in $RUNGS_DIR/ALL.csv -- a declared rung that is not built is RED, not absent; grading only what exists would print the success shape over the gap"
      # ⛔⭐⭐ THE SAME LAW ONE LEVEL DOWN, AT FORM GRANULARITY -- REPORTED, NOT YET ENFORCED (hq_T 2026-09-13,
      # on hq_I's report from inside this body). The refusal above enforces "declared and not built is RED" at
      # RUNG granularity: a rung with AT LEAST ONE witness satisfies it. Nothing compared the FORMS column
      # against the origins that exist, so snocone rung23 -- six forms declared, four built -- graded 8/8 and
      # printed the success shape over two gaps, and its STATUS said PARTIAL-4-OF-6 in words precisely because
      # the instrument would not say it. That is this runner's own missing-denominator defect with FORMS
      # substituted for RUNG.
      # ⛔ WHY THIS PRINTS AND DOES NOT REFUSE, WHICH IS A MEASURED DECISION AND NOT TIMIDITY. hq_I asked the
      # right question before proposing a gate -- how many declared-but-unbuilt forms exist across the seven? --
      # and ../harness/scripts/util_ladder_form_census.py answers it: 94 of 1058, BUT 77 of those sit in rungs with NO
      # witness at all, which is the ladder DECLARED AHEAD, a roadmap, and redding it would red every language
      # whose FORMS column looks past the current rung. Only 17 sit in rungs that HAVE witnesses and grade
      # green over a gap -- prolog r11/r12/r13/r18 (5), snobol4 r14/r19/r21 (10), snocone r23 (2) -- and those
      # 17 live in three OTHER seats' lanes (cto, cfo, hq_I). Turning the refusal on from here would red three
      # lanes on a number they have not yet seen. So the instrument says the true thing today; the refusal
      # follows once the 17 are named by the seats that own them.
      # ⭐ AND THE MATCH IS BY NAME, SO IT PROVES ABSENCE AND NEVER PRESENCE: an origin bearing a form's name
      # could still grade nothing. This reports a FLOOR on the gap, which is why it is worded as "declares ...
      # with no witness bearing its name" rather than as a count of defects.
      _fgap=""
      # ⛔⭐⭐ `IFS=$'\t' read` COALESCES CONSECUTIVE TABS, SO AN EMPTY COLUMN SHIFTS EVERY FIELD LEFT.
      # Tab is IFS *whitespace*, and bash collapses runs of IFS whitespace into one separator -- so a row with
      # an empty REFERENCE or PAIRS cell handed $4 the WITNESS_ORIGIN value instead of FORMS. It did not look
      # wrong: it printed a confident, plausible, entirely false gap list -- pascal "declares 1 form(s): 
      # ladder__rung06_arrays" (an origin, not a form) and rebus "declares 1 form(s): -" (the empty-column
      # dash). ⭐ NOTHING IN THE RUNNER COULD HAVE CAUGHT THAT; it was caught because util_ladder_form_census.py,
      # which splits in python and does NOT coalesce, reported ZERO gaps for both languages while this loop
      # reported four each. TWO INSTRUMENTS OVER ONE POPULATION, DISAGREEING, is what found it -- re-reading
      # either one alone would have confirmed it. `cut -f` uses a strict single-tab delimiter and is the fix.
      while IFS= read -r _line; do
          _r=$(printf '%s' "$_line" | cut -f1); _forms=$(printf '%s' "$_line" | cut -f4)
          case "$_r" in rung[0-9]*) ;; *) continue;; esac
          _num=$(printf '%s' "$_r" | sed 's/^rung0*//'); [ -n "$_num" ] || _num=0
          [ "$_num" -le "$_ceiling" ] 2>/dev/null || continue
          if [ -n "$ONLY" ] && [ "$_num" -ne "$ONLY" ]; then continue; fi
          [ -n "$_forms" ] || continue
          _rorig="$(printf '%s\n' "${origins[@]}" | awk -v n="$_num" '$1==n{print $2}')"
          [ -n "$_rorig" ] || continue   # no witness at all = declared ahead, already the rung-level rule's business
          _miss=""
          # ⛔ CAPTURE FIRST, THEN TEST -- never `printf ... | grep -q ... || x=y`. That shape asks a PIPELINE for a
          # status and gets the LAST stage's, which is the trap this file's own gate (test_gate_ladder_asserts_stderr.sh
          # arm 11) exists to ban, and it caught its author one hour after landing (hq_I -> hq_T 2026-09-13). Here the
          # names are already in a shell variable, so no pipeline is needed at all: `case` matches them in the shell.
          for _f in $(printf '%s' "$_forms" | tr '|' ' '); do
              _hit=0
              while IFS= read -r _o; do
                  case "$_o" in *"_${_f}") _hit=1;; *"_${_f}_"*) _hit=1;; esac
              done <<EOF
$_rorig
EOF
              [ "$_hit" -eq 1 ] || _miss="$_miss $_f"
          done
          [ -z "$_miss" ] || _fgap="$_fgap"$'\n'"    rung$_num declares $(set -- $_miss; echo $#) form(s) with no witness bearing the name:$_miss"
      done < "$_ltsv"
      [ -z "$_fgap" ] || { echo "⚠ FORM-LEVEL GAP (reported, and the verdict below is unchanged -- see ../harness/scripts/util_ladder_form_census.py):$_fgap"; }
  fi
  _top=$(printf '%s\n' "${!rp[@]}" "${!rf[@]}" | sort -n | tail -1)
  if [ -z "$ONLY" ]; then
    _ll=$(printf '%s' "$LADDER_LANG" | tr 'A-Z' 'a-z')
    _dtop=$( [ -f "$RUNGS_DIR/config/LADDER.tsv" ] && grep -o '^rung[0-9]*' "$RUNGS_DIR/config/LADDER.tsv" | sed 's/^rung0*//' | sort -n | tail -1 )
    # ⛔ THE UNBUILT SET IS ENUMERATED, NEVER A RANGE (cfo 2026-09-13). This printed "rungs <top+1>..<dtop> NOT BUILT",
    # a contiguous-range claim derived from two numbers -- true only while every built rung is below every unbuilt one.
    # It stopped being true the moment rungs 19, 20 and 21 were built above the 17/18 gap: `--to 16` is the cumulative
    # ceiling, so _top stayed 16 and the cell told SCORE.md that three rungs with sixteen graded witnesses were NOT BUILT.
    # A cell that names the rungs cannot say that: the list comes from the same declared-census-minus-origins comparison
    # the REFUSE above already trusts, over the WHOLE census rather than below the ceiling. ⛔ AND THE WITNESS SIDE IS
    # all_origins, NOT the selected `origins`: the selected set is what THIS invocation graded, so deriving the cell from it
    # made `--to 16` report every rung above 16 as unbuilt -- including the five that have witnesses. Measured both ways here.
    _have="$(printf '%s\n' $all_origins | sed -nE 's/^ladder__rung0*([0-9]+)_.*$/\1/p' | sort -n -u)"
    _unb=""
    if [ -f "$RUNGS_DIR/config/LADDER.tsv" ]; then
      while read -r _r _rest; do
        case "$_r" in rung[0-9]*) ;; *) continue;; esac
        _num=$(printf '%s' "$_r" | sed 's/^rung0*//'); [ -n "$_num" ] || _num=0
        grep -qx "$_num" <<<"$_have" || _unb="$_unb $_num"
      done < "$RUNGS_DIR/config/LADDER.tsv"
    fi
    # ⛔⭐ THE CELL NAMES THE COMMAND THAT PRODUCED IT, AND THAT COMMAND MUST RUN. This printed
  # `--to ${TO:-max}`, so a cell measured with no --to told its reader to run `--to max` -- which the
  # arg parser REFUSES rc=2 ("--to wants a rung number"). `max` was only ever the display default for
  # "no --to given". A provenance stamp whose reproduction line cannot reproduce it is worse than none:
  # the reader who tries it gets a refusal and reads the CELL as stale (hq_T 2026-09-13).
  _decl=$( [ -n "$_unb" ] && printf ' · declared top rung %s, %s rung(s) NOT BUILT (RED by declaration):%s' "$_dtop" "$(set -- $_unb; echo $#)" "$_unb" )
    _cell="built rungs 0..${_top} PASS $pass/$((n*2)) FAIL $fail${_decl} (witnesses=$n · m3+m4 · test_${_ll}_ladder.sh${TO:+ --to $TO}${ONLY:+ --only $ONLY} · SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo ?) corpus=$(git -C "$S4E/corpus" rev-parse --short HEAD 2>/dev/null || echo ?) RT_OPT=-O0)"
    # ⛔⭐ A FILTER THAT MATCHES NOTHING MUST SAY SO, NOT FALL SILENT (hq_T 2026-09-13, on the cfo's
    # measured report). This grep listed the three SUCCESS shapes and nothing else, while
    # util_score_row.py's ONE-RUNNER identity refusal exits 0 (correctly -- a bookkeeping refusal must
    # never red a board) and prints a line beginning '⚠ '. So for twelve of the thirteen seats the helper
    # ran, refused, and the seat saw NOTHING AT ALL: no SCORE line, no UNWRITTEN line, a green verdict and
    # rc=0. ⭐ THE FAILURE MODE IS NOT A MISSING MESSAGE, IT IS THE WRONG BELIEF IT LEAVES BEHIND -- a
    # guard that works and is invisible reads exactly like a write that happened, and the cfo spent four
    # measurements and a bash -x finding out their number was not on the leaderboard. ⛔ THE FIX IS THE
    # CLASS, NOT THE SHAPE: widening the pattern to also match '⚠' would swallow the NEXT refusal wearing
    # a fourth prefix just as silently. An unmatched filter falls back to printing what it was given, so
    # any output this call site does not recognise is surfaced rather than dropped.
    if _w=$(python3 "$ROOT/../harness/scripts/util_score_row.py" write --lang "$_ll" --column ladder --text "$_cell" --measurer "${S4E_SEAT:-}" 2>&1); then
      _shown=$(printf '%s\n' "$_w" | grep -E '^SCORE.md|ROW SKIPPED|^  now:' | cut -c1-200)
      if [ -n "$_shown" ]; then printf '%s\n' "$_shown"
      elif [ -n "$_w" ]; then echo "SCORE ROW: NOT WRITTEN (util_score_row.py exited 0 but wrote no row; the verdict below is unchanged):"; printf '%s\n' "$_w" | head -3 | cut -c1-200; fi
    else echo "SCORE ROW: UNWRITTEN (util_score_row.py refused; the verdict below is unchanged):"; printf '%s\n' "$_w" | head -3 | cut -c1-200; fi
  fi
  [ "$fail" -eq 0 ] && { if [ -n "$ONLY" ]; then echo "✅ LADDER OK: rung $ONLY alone PASS $pass/$((n*2))"; else echo "✅ LADDER OK: rungs 0..${_top} PASS $pass/$((n*2))$( [ "${TO:-}" != "" ] && [ "${TO}" != "${_top}" ] && printf ' (requested --to %s; top graded rung is %s)' "$TO" "$_top")"; fi; exit 0; }
  echo "⛔ LADDER RED: $fail of $((n*2)) witness x mode gradings FAIL (rungs 0..${_top})"; exit 1
}
