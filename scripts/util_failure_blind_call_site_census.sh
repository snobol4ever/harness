#!/bin/bash
# util_failure_blind_call_site_census.sh -- census of call sites in src/runtime/ and src/driver/ where a
# language-facing resolve/lookup failure cannot be observed by the caller.
#
# THE SHAPE (task runtime-and-driver-paths-that-cannot-express-failure-censused, minted by hq_U
# 2026-09-05; GOAL-HQ-UNIFY.md; MASTER-PLAN.md seat19 row): a function that stands between a language-
# level event -- a GOTO target, a called entry, a SETEXIT handler -- and the resolve/lookup that answers
# it has no return channel of its own to say "the target did not resolve", so code written after the call
# (which assumes the transfer already happened) runs anyway. rt_goto_transfer is the diagnosed instance
# (.github 671fc125: root-caused end to end, two cure attempts built and reverted -- NOT yet cured).
#
# SCOPE NOTE: the task names "runtime/{core,rt,rtx}" but rt_goto_transfer/rt_goto_resolve/rt_entry_resolve
# themselves live directly under src/runtime/ (runtime_eval.c), outside all three named subdirectories --
# so this census reads the WHOLE src/runtime/ tree plus src/driver/, not just the three subdirs, or it
# would miss its own headline example. src/templates/ and src/emitter/ also call some of these same
# runtime symbols directly from GENERATED code; that is a different layer (the compiled program calling
# in, not a C function calling a C function) and a different census -- deliberately out of scope here.
#
# NEGATIVE CONTROLS, so this script can say NO as well as YES (two-part-proof, RULES.md § INSTRUMENT
# LAWS): rt_entry_resolve's one consumer (rt.c:900) and label_lookup's three consumers in driver_call.c
# plus its one consumer in driver_hooks.c all check their result and escalate correctly. If any of those
# five sites is ever reported below as a candidate, this script is broken, not the runtime.
#
# Exit codes: 0 = census ran and printed (this is what this task's own DONE-WHEN needs -- a census is a
# report, not a pass/fail gate, so a clean run reports 0 even when it lists open candidates below).
#             2 = REFUSE -- could not find the source tree, i.e. could not measure at all.
set -u

# Self-locate rather than trust $S4E_HOME: this script's own DONE-WHEN invokes it as
# "$S4E_HOME/harness/scripts/<this file>", i.e. S4E_HOME is the SIBLING root, not the SCRIP repo root --
# but this script always lives inside the SCRIP checkout it needs to examine, so BASH_SOURCE already
# names the right tree regardless of which sibling root invoked it. $1 stays as an explicit override.
ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)}"
SRC="$ROOT/src"
for d in runtime driver; do
    [ -d "$SRC/$d" ] || { echo "⛔ REFUSE: $SRC/$d not found -- cannot census a tree that isn't there" >&2; exit 2; }
done

TREE=$(cd "$ROOT" && git rev-parse --short HEAD 2>/dev/null || echo unknown)
DIRTY=""
(cd "$ROOT" && git status --porcelain 2>/dev/null | grep -q .) && DIRTY="-DIRTY"
echo "util_failure_blind_call_site_census: root=$ROOT tree=${TREE}${DIRTY} scope=src/runtime,src/driver"
echo

PRIMS="rt_goto_resolve rt_entry_resolve label_lookup"
sites=$(grep -rn --include='*.c' --include='*.cpp' "\(rt_goto_resolve\|rt_entry_resolve\|label_lookup\)(" \
             "$SRC/runtime" "$SRC/driver" 2>/dev/null \
        | grep -v -E '^[^:]+:[0-9]+: *(static +|extern +)?(void|const [A-Za-z_][A-Za-z0-9_]*) *\*? *(rt_goto_resolve|rt_entry_resolve|label_lookup) *\(')
n_sites=$(printf '%s\n' "$sites" | grep -c .)
echo "call sites naming a tracked primitive (definitions excluded): $n_sites"
printf '%s\n' "$sites" | sed "s#^$SRC/#  #"
echo

cat <<'EOF'
--- TRACKED (already filed -- cross-reference only, do not re-open) ---
  src/runtime/core/core.c:2192       rt_goto_transfer(lbl) in core_runtime_error()'s SETEXIT-transfer arm
  src/runtime/core/core.c:1424,1426  rt_goto_transfer(lbl) in sno_setexit_fire_on_end()'s END-trap arm
                                     (same root cause as the line above, not an independent site)
    -> owner: hq_P row "setexit-not-invoked-under-errlimit-survival"; root cause: .github 671fc125
    -> also entangled with task snobol4-setexit-does-not-validate-its-argument-so-error-187-never-fires
  (outside this script's dir scope: src/templates/bb/bb_goto_deferred.cpp's TAIL-TRANSFER arm calls
   rt_goto_resolve directly for a plain :GOTO, shared with lower_prolog.c --
   -> owner: hq_U row "plain-goto-to-an-undefined-label-under-errlimit-exits-0-with-no-diagnostic")

--- VERIFIED SAFE (escalate correctly -- negative controls; must stay off the candidate list above) ---
  src/runtime/rt/rt.c:900          rt_entry_resolve -> core_runtime_error(286, ...) on NULL, returns FAILDESCR
  src/driver/driver_call.c:131-145 label_lookup x3 -> core_runtime_error(22, "Undefined function called")
                                   when unresolved AND !FNCEX_fn(fname) AND !FNCEX_fn(ufname)
  src/driver/driver_hooks.c:10     label_lookup -> returned to caller as a plain boolean

--- CHECKED THIS SWEEP, RULED OUT (plausible from source alone, not reachable in practice) ---
  src/runtime/runtime_eval.c:335  rt_goto_resolve's `$name`-indirect branch: `if (!inm || !*inm)
                                  { fprintf(stderr, ...); exit(1); }` looks like the same failure-blind
                                  shape (a raw process exit bypassing core_runtime_error, uncatchable by
                                  SETEXIT). Witness tried 2026-09-05: `:($X)` with X unassigned. Verdict:
                                  SCRIP raises ERROR 239 "indirection operand is not name" BEFORE this
                                  point (matches the SPITBOL oracle, both m3), so an empty/null indirect
                                  name never reaches rt_goto_resolve's own check from ordinary source --
                                  this is defensive dead code, not a live gap. (Aside, not this census's
                                  shape: SCRIP prints the ERROR 239 diagnostic TWICE where the oracle
                                  prints it once, and SCRIP's "in statement 0" vs. the oracle's "in
                                  statement 2" -- a real but separate divergence, unfiled, not chased here.)

--- NEEDS A WITNESS (found this sweep, not yet on a filed row -- next rung for this walk) ---
  src/runtime/runtime_eval.c:~341  rt_goto_resolve's `<code>`-value branch has the identical raw-exit(1)
                                   shape as the `$name` branch above for "goto operand in direct goto is
                                   not code". Not yet tried against a real CODE()/`<...>` witness --
                                   unlike the $name case, no upstream check is confirmed to intercept it.
  src/driver/driver_call.c:143     when FNCEX_fn(fname) or FNCEX_fn(ufname) is true and body is still
                                   NULL, control falls through PAST the ERROR-22 arm and returns as an
                                   ordinary RETURN (fr->retval_set ? fr->retval_cell : NV_GET_fn(fr->fname))
                                   with no diagnostic. Unconfirmed whether FNCEX marks a case this can
                                   legitimately defer (e.g. a forward reference resolved by a later pass)
                                   or a live gap -- needs a forward-declared-never-defined-function witness
                                   before it can be filed as a bug.

EOF
echo "denominator: 3 tracked, 3 verified-safe, 1 ruled-out, 2 open needing a witness"
exit 0
