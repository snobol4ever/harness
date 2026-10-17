#!/usr/bin/env bash
# handoff_status.sh — THE ONLY SANCTIONED SOURCE OF A CHAT SESSION COMPLETION CLAIM.
#
# Per RULES.md FACT RULE (2026-06-24): the assistant MUST NOT compose "CHAT SESSION COMPLETE"
# as prose. It runs THIS script and presents the verbatim output.
#
# It does NOT hardcode a repo count. With no args it DISCOVERS every git repo that has an
# 'origin' remote directly under the workspace root (the parent of the SCRIP repo this
# script lives in) — so it can never miss a touched repo, and it prints how many it found.
# Pass explicit repo dirs to override. Reading origin needs no credential; only the push that
# PRECEDES this check does.
#
# ⭐ THREE-STATE VERDICT (instrument-repair-bundle PART 2, s273; precedent copied verbatim from
# test_corpus_snobol4.sh's rc=0/1/2 shape, SCRIP 9873fe6e): "I cannot honestly tell" is not the
# same answer as either confident one, and collapsing it into BLOCKED (or worse, COMPLETE) is how
# an unreachable remote or an unreadable repo gets misread as a real verdict.
#   exit 0  CHAT SESSION COMPLETE — every repo examined, none blocked, none unknown.
#   exit 1  CHAT SESSION WAITING  — a repo is DIRTY, UNPUSHED, or DIVERGED. Known, actionable.
#   exit 2  CHAT SESSION REFUSES  — a repo's push-state could not be determined (fetch failed,
#           unreadable) or there was nothing to examine at all. NOT a pass; read the reason(s).
#
# ⭐ PER-REPO STATE, three-way (adopted from tasks/handoff-status-three-state-push-check.task.md,
# hq_P s269, FINDING-2026-08-24-hq_P-three-instruments-that-cannot-express-their-own-outcome.md
# §1): the old script printed one word, UNPUSHED, for BOTH "your work is missing from origin,
# nothing of yours at risk" and "you have local commits origin doesn't." A seat reading the label
# (not the count beside it) concluded it had LOST work it had not — exactly the panic that tempts
# `reset --hard`/`push --force`, the two actions THE LOOP §3b most wants to prevent.
#   SYNCED   — local HEAD == origin/<branch>. Nothing to do.
#   BEHIND   — HEAD is an ancestor of origin (all of ours is already there; we're missing some of
#              theirs). NOT a failure of this session's own work — does not block.
#   UNPUSHED — origin is an ancestor of HEAD (we have commits origin doesn't). Blocks.
#   DIVERGED — neither is an ancestor of the other (both sides moved). Blocks — and a plain push
#              will be REJECTED here, so the reason says "pull --rebase", never "push".
# ⛔ FETCH-IS-NOT-CHECKOUT, both directions: the remote ref must be FRESH before any ancestry
# check runs, or a stale origin/<branch> makes the test confidently wrong in whichever direction
# the staleness happens to run. A fetch failure is therefore its own UNKNOWN state, never silently
# read as any of the four above.
set -uo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # <ws>/harness/scripts
# ⛔ D-17 PORTABLE-HOME (CLAUDE.md Workspace map): "every script derives paths from $0 or S4E_HOME" -- this
# script derived WS from $0 ONLY, so a caller pointing S4E_HOME at a scratch worktree (as the DONE-WHEN for
# task handoff-artifact-check-cannot-tell-stale-local-build-from-drift does, to sandbox the stale-binary proof
# away from the real tree) was silently ignored: WS still resolved to the real sibling root. Found proving
# that DONE-WHEN (seat15 2026-09-04); cured to match util_verify_s_artifacts_owed.sh's existing S4E_HOME pattern.
WS="${S4E_HOME:-$(dirname "$(dirname "$SELF_DIR")")}"       # <ws> (parent of the SCRIP repo), S4E_HOME overrides
REPOS=("$@") ; src="given on command line"
if [ ${#REPOS[@]} -eq 0 ]; then
  src="auto-discovered under $WS"
  shopt -s nullglob dotglob
  for d in "$WS"/*/; do
    d="${d%/}"; base="$(basename "$d")"
    { [ "$base" = "." ] || [ "$base" = ".." ]; } && continue
    [ -e "$d/.git" ] || continue                              # is a git repo (worktree: .git is a FILE, not a dir)
    git -C "$d" remote get-url origin >/dev/null 2>&1 || continue   # has an origin to push to
    REPOS+=("$d")
  done
  IFS=$'\n' REPOS=($(printf '%s\n' "${REPOS[@]}" | sort)); unset IFS
fi
echo "=== CHAT SESSION STATUS — checking ${#REPOS[@]} repo(s) ($src); ground truth from git ==="
# ⛔ ZERO-EXAMINED IS NOT A PASS (same law as lib_gate.sh's gate_floor: "zero-work-examined is
# indistinguishable from all-clean, so it is refused rather than passed"). An empty workspace used
# to read WAITING (rc=1) — a mislabel in the OTHER direction: there is nothing here to be blocked
# ON, the honest answer is "could not examine anything."
if [ ${#REPOS[@]} -eq 0 ]; then
  echo "⛔ CHAT SESSION REFUSES — no git repos with an 'origin' remote found under $WS"
  echo "   This is NOT complete and NOT a known block: there was nothing to examine. Check WS/S4E_HOME."
  exit 2
fi
blocked=0; unknown=0; reasons=(); unknown_reasons=()
for r in "${REPOS[@]}"; do
  name=$(basename "$r")
  br=$(git -C "$r" rev-parse --abbrev-ref HEAD 2>/dev/null)
  # ⭐ GRADE AGAINST THE BRANCH'S ACTUAL UPSTREAM, NOT AGAINST origin/<its own name>. A seat working on a local
  # branch that TRACKS origin/main (the fleet's normal shape -- push with `git push origin HEAD:main`) has no
  # origin/<branch> at all, and grading it against that phantom made a fully-pushed tree read as unfinished.
  up=$(git -C "$r" rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null); [ -n "$up" ] || up="origin/$br"
  dirty=$(git -C "$r" status --porcelain 2>/dev/null | wc -l)
  if ! git -C "$r" fetch --quiet origin 2>/dev/null; then
    unknown_reasons+=("$name: fetch failed — origin unreachable or no credential; push-state UNKNOWABLE from here, not assumed BLOCKED or COMPLETE")
    unknown=1
    printf "  %-22s %-10s local=%s origin=%s\n" "$name [$br]" "UNKNOWN" "${dirty}dirty" "fetch-failed"
    continue
  fi
  lh=$(git -C "$r" rev-parse HEAD 2>/dev/null)
  # ⛔ --verify --quiet, NOT bare rev-parse: on an unresolvable ref `git rev-parse origin/foo` ECHOES ITS
  # ARGUMENT ON STDOUT and then exits non-zero, so `$(... || echo MISSING)` yields "origin/foo\nMISSING",
  # which is never == MISSING. The no-such-branch arm below then never fires, both merge-base probes fail on
  # the invalid ref (fwd=0 back=0), and every seat on a local branch with no origin/<same-name> got a hard
  # phantom "DIVERGED ... not done" whose printed remedy (pull --rebase && push) could never clear it.
  oh=$(git -C "$r" rev-parse --verify --quiet "$up" 2>/dev/null || echo MISSING)
  st="SYNCED"
  if [ "$dirty" -ne 0 ]; then st="DIRTY"; fi
  if [ "$oh" = "MISSING" ]; then
    # origin has no such branch at all -- everything local is, by definition, unpushed.
    [ "$st" = "DIRTY" ] || st="UNPUSHED"
    reasons+=("$name: no upstream ref '$up' — git push -u origin $br")
    blocked=1
  elif [ "$lh" != "$oh" ]; then
    fwd=0; git -C "$r" merge-base --is-ancestor "$lh" "$oh" 2>/dev/null && fwd=1
    back=0; git -C "$r" merge-base --is-ancestor "$oh" "$lh" 2>/dev/null && back=1
    if [ "$fwd" -eq 1 ]; then
      [ "$st" = "DIRTY" ] || st="BEHIND"   # all of OURS is on origin; nothing at risk, does not block
    elif [ "$back" -eq 1 ]; then
      [ "$st" = "DIRTY" ] || st="UNPUSHED"
      reasons+=("$name: $(git -C "$r" rev-list --count "$oh..$lh" 2>/dev/null || echo '?') commit(s) not on $up — git push")
      blocked=1
    else
      [ "$st" = "DIRTY" ] || st="DIVERGED"
      reasons+=("$name: DIVERGED from $up — both sides have unique commits, a plain push will be REJECTED — git pull --rebase && git push")
      blocked=1
    fi
  fi
  if [ "$dirty" -ne 0 ]; then reasons+=("$name: $dirty uncommitted change(s) — commit them"); blocked=1; fi
  printf "  %-22s %-10s local=%s origin=%s\n" "$name [$br]" "$st" "${lh:0:9}" "${oh:0:9}"
done
echo "------------------------------------------------------------"
echo "=== .s ARTIFACT DRIFT (RULES.md handoff step 4) — BLOCKING since 2026-08-30 (ceo: the s272 ramp condition was met — hq_B drove the standing owed count to 0 and confirmed via this script) ==="
echo "    (owed artifacts now BLOCK the handoff verdict; a verifier REFUSAL (rc=2, cannot measure) still only warns. If blocked and the debt is not yours: run the three regen scripts named in RULES.md handoff step 4 — earlier sessions' unregenerated codegen surfaces on whoever handoffs next, which is correct, not an accusation.)"
# ⛔ A SUB-CHECK THAT COULD NOT MEASURE MAKES THE COMPOSITE REFUSE, NEVER PASS (coo 2026-09-16, hq_snobol4's witness: a stale-binary
# refusal here was warn-only and the run ended CHAT SESSION COMPLETE with the check never run; hq_prolog's general form). Every
# not-measured outcome below goes to `unknown`, which the verdict prints as CHAT SESSION REFUSES (rc=2). And the OWED set blocks
# only the seat whose LANE owes it (lib_handoff_verdict.sh): another lane's debt is information with its owner named, and the
# remedy is addressed to that owner, never to the innocent seat reading this.
. "$SELF_DIR/lib_handoff_verdict.sh"
_ho_seat="${S4E_SEAT:-$(basename "$(cd "$SELF_DIR/../.." && pwd)" | sed 's/^claude_//')}"
if [ "${SKIP_S_ARTIFACT_CHECK:-0}" = "1" ]; then
  echo "  SKIPPED (SKIP_S_ARTIFACT_CHECK=1 set) — .s drift is UNVERIFIED this run, and an unverified check cannot read COMPLETE."
  unknown=1; unknown_reasons+=(".s artifact drift NOT GRADED: skipped by SKIP_S_ARTIFACT_CHECK=1 -- unset it and re-run")
elif [ "$_ho_seat" != coo ] && [ -z "${S4E_ONE_TEST_ADMIT:-}" ]; then
  # ⛔⭐⭐⭐⭐ ZERO OR ONE TEST PER SEAT (Lon 2026-10-11 11:5x CDT, verbatim: "I'm thinking each seat can run ZERO test, oh ONE test, instead. Then let
  # COO prioritize testing on a per feature basis and still cycle through everything eventually."; ceo CEO-1671): this verifier regenerates
  # every demo and benchmark .s of every language (102 artifacts, each a compile) in a disposable clone, and it ran here for EVERY seat at
  # every handoff -- and through the Stop hook's banner at every response. MEASURED 11:57 CDT: load 29 on 16 cores, the ceo's and
  # hq_templates' chains both compiling the Prolog benches. The drift check is the coo's, once per batch of landings; a seat's handoff
  # does not run it and is not blocked by it. S4E_ONE_TEST_ADMIT="why" is the ceo's loud audit-window override.
  echo "  ARTIFACT DRIFT: not graded by seat $_ho_seat -- the coo's loop grades .s drift once per batch (ZERO OR ONE TEST PER SEAT, CEO-1671)"
else
  verifier="$SELF_DIR/util_verify_s_artifacts_owed.sh"
  if [ ! -x "$verifier" ]; then
    echo "  ⛔ $verifier missing/not executable — .s drift is UNVERIFIED this run."
    unknown=1; unknown_reasons+=(".s artifact drift NOT GRADED: the verifier is missing")
  else
    # ⛔⭐⭐ THIS WARN-ONLY CHECK MUST NOT RUN A DESTRUCTIVE BUILD (row `stop-hook-pristine`, hq_P s274; ceo CEO-30).
    # Until now this line invoked the verifier with NO ARGUMENTS, so it defaulted to SKIP_PRISTINE=0 and ran a full
    # `make pristine` in the LIVE checkout -- wiping ./scrip and out/ -- to feed a block whose own header three lines
    # up says "WARN-ONLY, does not affect the verdict below". The most destructive operation in the whole chain was
    # serving the one check that is explicitly non-binding.
    # ⛔ AND IT FIRES FAR MORE OFTEN THAN "AT HANDOFF": the seat's `Stop` hook runs `s4e_msg.sh banner` -> here, and
    # Stop fires every time the seat RESPONDS, not only at session end. So a seat that starts a long build and then
    # answers a message destroys its own build, with no build of its own visibly running. That is why it read as a
    # haunting rather than a race: MEASURED 4 binary losses across 3 roots in one day (hq_P x2, hq_C x2), each first
    # reported as "the binary vanished and no make of mine was running". seat09 diagnosed it after 4 collisions in a
    # single session and "waited 5 min for a clear window, found none" -- there is no window, because the thing
    # closing it is the seat itself. Symptom: `ld: cannot find out/rt_pic-<hash>/*.o`, then collect2 error, Makefile:406.
    # ⭐ LAW COVER, so nobody re-arms this citing HQ-27: HQ-27 owes a pristine build before a VERDICT, never before a
    # BANNER. The hook OVER-APPLIED it; no law changed. A real gate/handoff verdict still gets its pristine.
    # ⭐ SAFE BY CONSTRUCTION, NOT BY HOPE: under --skip-pristine the verifier REFUSES rc=2 if ./scrip is absent
    # ("FATAL: scrip not built") -- so this can degrade to a REFUSAL, never to a false CLEAN.
    # ✅ Opt back in deliberately with S_ARTIFACT_PRISTINE=1 when you actually want the pristine-verified drift check.
    verifier_args=""
    [ "${S_ARTIFACT_PRISTINE:-0}" = "1" ] || verifier_args="--skip-pristine"
    s_out="$(bash "$verifier" $verifier_args 2>&1)"; s_rc=$?
    if [ "$s_rc" -eq 0 ]; then
      printf '%s\n' "$s_out" | grep '^S-ARTIFACTS-' | sed 's/^/  /'
      echo "  CLEAN — benchmark/demo/prolog_bench/icon_bench all current, all checks actually ran."
    elif [ "$s_rc" -eq 2 ] && printf '%s\n' "$s_out" | grep -q 'PREDATES src/'; then
      # ⛔ STALE-BINARY, NOT DRIFT (task handoff-artifact-check-cannot-tell-stale-local-build-from-drift, hq_C
      # 2026-09-01 / seat15 2026-09-04): lib_build_currency.sh's preflight inside the verifier already refuses
      # rc=2 here and never computes an owed count -- the bug was that handoff_status.sh then threw the refusal
      # away: the generic branch below only ever prints text from a "VERDICT:" line, and a preflight refusal
      # exits before the verifier reaches one, so the mtime/cure detail silently vanished and every rc=2 looked
      # identical to a false OWED that just didn't happen to fire this time. This branch names the real cause.
      rt_tag="$(readlink out/libscrip_rt.so 2>/dev/null | grep -oE 'libscrip_rt-[0-9a-f]+' | sed 's/libscrip_rt-//')"
      echo "  ⛔ STALE-BINARY — ./scrip (or out/libscrip_rt.so) is older than the newest tracked src/ change: a stale local build, not corpus drift, so no OWED count was computed. RT_TAG: ${rt_tag:-unknown}"
      printf '%s\n' "$s_out" | sed 's/^/  /'
      echo "  cure: cd SCRIP && make pristine, then re-run — RULES.md:118 keeps pristine owed for exactly this refusal even though ordinary landings loosened it; an incremental 'make' is not certified equivalent here."
      unknown=1; unknown_reasons+=(".s artifact drift NOT GRADED: the verifier refused on a stale binary (rc=2) -- rebuild and re-run; a check that could not measure cannot read COMPLETE")
    elif [ "$s_rc" -eq 2 ]; then
      echo "  ⛔ UNVERIFIED — the verifier REFUSED (rc=2, cannot measure; e.g. no built ./scrip). This run proves nothing about .s drift, so it cannot read COMPLETE."
      unknown=1; unknown_reasons+=(".s artifact drift NOT GRADED: the verifier refused (rc=2, could not measure)")
      printf '%s\n' "$s_out" | sed -n '/^VERDICT:/,$p' | sed 's/^/  /'
    else
      _owed_files="$(printf '%s\n' "$s_out" | sed -n 's/^S-ARTIFACTS-OWED-FILE: //p')"
      echo "  ⛔ OWED .s artifacts, BY LANE (ramp flipped 2026-08-30): $(printf '%s\n' "$s_out" | sed -n 's/^S-ARTIFACTS-OWED-BY-LANE: //p')"
      _ho_v="$(handoff_owed_verdict "$_ho_seat" "$_owed_files")"; _ho_rc=$?
      printf '%s\n' "$_ho_v" | sed 's/^/    /'
      printf '%s\n' "$s_out" | sed -n '/^VERDICT:/,$p' | sed 's/^/  /'
      if [ "$_ho_rc" -ne 0 ]; then
        blocked=1; reasons+=(".s artifacts OWED in YOUR lane — regenerate (RULES.md handoff step 4): $(printf '%s\n' "$_ho_v" | grep '^BLOCK' | cut -d' ' -f2 | tr '\n' ' ')")
      else
        echo "  not this seat's blocker: every owed artifact is another lane's, named above with its owner; $_ho_seat does not regenerate it"
      fi
    fi
  fi
fi
echo "------------------------------------------------------------"
echo "THE ONE LEADERBOARD (.github/SCORE.md) — row staleness — WARN-ONLY, does not affect the verdict below"
# ⛔⭐ WARN-ONLY ON PURPOSE, AND THE REASON IS THE SAME ONE THE .s BLOCK LEARNED ABOVE. A stale SCORE.md row is
# not a defect of the session that happens to be handing off -- it is usually a defect of some OTHER session
# that measured a suite and did not rewrite its row. Blocking this seat's handoff on that would punish the
# wrong session and, within a week, get this check `|| true`-d out of the file. What it CAN honestly do is
# make the debt visible at the one moment somebody is looking at the state of the world.
# ⛔ It runs `check`, which reads git and the markdown ONLY -- it runs no suite and builds nothing, so unlike
# the .s verifier above it cannot destroy a live build (the haunting documented at length in that block).
# ⭐ rc=1 means "rows ARE stale" -- a real answer, printed. rc>=2 means it could not measure, which is its own
# state and says so; neither is allowed to read as CLEAN.
_score_helper="$SELF_DIR/util_score_row.py"
if [ ! -f "$_score_helper" ]; then
  echo "  ⛔ $_score_helper missing — leaderboard staleness UNVERIFIED this run."
else
  _score_out="$(python3 "$_score_helper" check 2>&1)"; _score_rc=$?
  if [ "$_score_rc" -eq 0 ]; then
    echo "  CLEAN — every row measured within 25 commits of origin/main."
  elif [ "$_score_rc" -eq 1 ]; then
    # ⛔ ADRIFT MUST BE IN THIS FILTER OR IT IS INVISIBLE HERE (hq_T 2026-09-05). A cell can be ADRIFT and
    # perfectly CURRENT -- hand-edited onto today's tree, so its line reads `ok` and carries no STALE token.
    # Filtering on STALE alone reproduced, one layer up, the exact blind spot the ADRIFT state was added to
    # close: the one moment somebody is looking at the state of the world would not have shown it.
    printf '%s\n' "$_score_out" | grep -E 'STALE|ADRIFT|UNPINNED|UNKNOWN|^worst=' | sed 's/^/  /'
    echo "  ⚠ WARN — re-measure the stale suite(s) and rewrite the row: python3 ../harness/scripts/util_score_row.py write --lang <lang> --column board --measurer \"\${S4E_SEAT:-}\" --text '<board line>'"
  else
    echo "  ⛔ UNVERIFIED — the staleness check REFUSED (rc=$_score_rc, cannot measure). Not blocking, but this run proves nothing about the leaderboard."
    printf '%s\n' "$_score_out" | sed 's/^/  /'
  fi
fi
echo "------------------------------------------------------------"
echo "GATE WIRING (../harness/scripts/gate_wiring.tsv) — a gate on disk that no recipe runs — WARN-ONLY, does not affect the verdict below"
# ⛔⭐ THE DEFECT, and it is hq_S's, measured 2026-09-06: test_gate_sno_fence_body_dynamic_operand.sh landed on
# disk IN THE SAME PUSH as the cure it grades and was never added to the `test:` recipe, so for a day the ONE
# instrument that could grade that cure was run by nothing. NOTHING COULD HAVE NOTICED: the gate was green when
# run by hand, ls found it, the commit that added it looked complete, and every board was byte-identical with
# and without the cure BY CONSTRUCTION, so no suite could miss it either. An unwired gate is indistinguishable
# from a wired one by every check except reading the recipe.
# ⭐ HERE RATHER THAN IN THE RECIPE, and this is hq_S's placement argument, which is the half that would not
# have been got right alone: they found their own case while CLOSING a row, not while landing the cure. This is
# the moment a seat asks "is there anything I owe"; a check on `make test` would fire for every seat, on
# everybody else's debt, at every build.
# ⛔ WARN-ONLY FOR THE SAME REASON THE LEADERBOARD BLOCK ABOVE IS. An unwired gate is usually some OTHER
# session's, arriving here on a pull; blocking this seat's handoff on it would punish the wrong session and,
# within a week, get this line `|| true`-d out of the file. And it is a RATCHET, never a census: measured at
# installation, 282 gates on disk and 92 reachable, so UNWIRED IS THE NORM at two in three. A check that
# arrived red on 181 lines would be muted on day one, and a muted check is worse than no check because it
# looks like coverage. It fires on the TRANSITION -- a gate that LEFT the wired set, or one that just landed
# unwired and undeclared -- and every refusal NAMES the gates and prints the cure, because "the floor moved"
# sends its reader to diff two files by hand.
# ⛔ It runs `make -n` only: it expands the recipe, executes nothing and builds nothing, so unlike the .s
# verifier above it cannot destroy a live build (the haunting documented at length in that block).
# ⭐ rc=1 means "gates moved" -- a real answer, printed and named. rc=2 means it could not measure (no make, an
# unparseable Makefile), which is its own state and says so; neither is allowed to read as CLEAN.
_wiring_helper="$SELF_DIR/util_gate_wiring.py"
if [ ! -f "$_wiring_helper" ]; then
  echo "  ⛔ $_wiring_helper missing — gate wiring UNVERIFIED this run."
else
  _wiring_out="$(python3 "$_wiring_helper" check 2>&1)"; _wiring_rc=$?
  if [ "$_wiring_rc" -eq 0 ]; then
    printf '%s\n' "$_wiring_out" | sed -n '2p;$p' | sed 's/^/  /'
  elif [ "$_wiring_rc" -eq 1 ]; then
    printf '%s\n' "$_wiring_out" | sed 's/^/  /'
    echo "  ⚠ WARN — wire the gate(s) named above into the Makefile 'test:' recipe, or declare the state with a reason."
  else
    echo "  ⛔ UNVERIFIED — the wiring ratchet REFUSED (rc=$_wiring_rc, cannot measure). Not blocking, but this run proves nothing about gate wiring."
    printf '%s\n' "$_wiring_out" | sed 's/^/  /'
  fi
fi
echo "------------------------------------------------------------"
echo "------------------------------------------------------------"
echo "GC ACCEPTANCE — the four numbers of CEO-1039 — WARN-ONLY, does not affect the verdict below"
echo "    (Lon 2026-09-21 ordered the metrics displayed periodically; a handoff is the boundary where a stale"
echo "     number costs something, which is CEO-822's reason for putting the seven-language sweep here too."
echo "     SKIP_GC_ACCEPTANCE=1 skips it and SAYS SO: a display that did not run prints nothing green.)"
if [ -n "${SKIP_GC_ACCEPTANCE:-}" ]; then echo "  SKIPPED by SKIP_GC_ACCEPTANCE — the four numbers were NOT read on this handoff"; else
  timeout -k 5 2400 python3 "$SELF_DIR/util_gc_acceptance.py" 2>&1 | sed "s/^/  /" || true
fi
echo "ALL-LANGUAGE SLOT-KIND SWEEP (util_gc_census.py maps --zls-langs all) — WARN-ONLY, does not affect the verdict below"
echo "    (CEO-822, 2026-09-17, on the coo's ask: the FAST THREE stay wired in make test — a 35s number that moves once a"
echo "     day does not belong on every seat's per-landing verdict — and THE SEVEN run HERE, once, at the boundary where a"
echo "     stale number costs something. SKIP_ZLS_ALL=1 skips it and SAYS SO: a sweep that did not run prints nothing green.)"
_zls_root="$SELF_DIR/../../SCRIP"
if [ "${SKIP_ZLS_ALL:-0}" = "1" ]; then
  echo "  SKIPPED (SKIP_ZLS_ALL=1) — the seven-language reading is UNVERIFIED this run; make test proves the fast three only."
elif [ ! -f "$SELF_DIR/util_gc_census.py" ]; then
  echo "  ⛔ NOT MEASURED — $SELF_DIR/util_gc_census.py is missing. Nothing was censused; this is not a zero."
elif [ ! -x "$_zls_root/scrip" ]; then
  echo "  ⛔ NOT MEASURED — no ./scrip binary under $_zls_root (run make). A census that cannot compile a rung suite must never print 0."
else
  _zls_out="$(cd "$_zls_root" && timeout -k 5 300s python3 ../harness/scripts/util_gc_census.py maps --zls-langs all 2>&1)"; _zls_rc=$?
  if [ "$_zls_rc" = 124 ]; then
    echo "  ⛔ NOT MEASURED — the sweep timed out at 300s (load $(cut -d' ' -f1 /proc/loadavg)). No reading this run."
  else
    printf '%s\n' "$_zls_out" | grep -E '^CENSUS maps/(slot-kind swept|table [0-9]|slot-kind NOT CENSUSED)|^CENSUS maps slot-kind=' | sed 's/^/  /'
    printf '%s\n' "$_zls_out" | grep -E '^  (DIVERGENCE|REFUSED)' | sed 's/^/  /'
    [ "$_zls_rc" = 2 ] && echo "  ⛔ the maps census REFUSED (rc=2) — read the line above; a refusal is not a red and not a pass."
  fi
fi
echo "------------------------------------------------------------"
if [ "$blocked" -ne 0 ]; then
  echo "CHAT SESSION WAITING — not done:"; printf '  - %s\n' "${reasons[@]}"
  [ "$unknown" -ne 0 ] && { echo "  (also UNKNOWN, see below — fix the known blockers first, they are certain; the unknown repo(s) still need a look)"; printf '  - %s\n' "${unknown_reasons[@]}"; }
  exit 1
elif [ "$unknown" -ne 0 ]; then
  echo "⛔ CHAT SESSION REFUSES — cannot honestly say COMPLETE or WAITING:"; printf '  - %s\n' "${unknown_reasons[@]}"
  echo "   No repo is a KNOWN blocker, but at least one could not be examined. This is NOT a pass."
  exit 2
else
  echo "CHAT SESSION COMPLETE"; exit 0
fi
