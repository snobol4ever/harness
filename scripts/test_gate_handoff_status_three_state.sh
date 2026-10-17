#!/usr/bin/env bash
# test_gate_handoff_status_three_state.sh — regression gate for instrument-repair-bundle PART 2
# (handoff_status.sh three-state verdict + BEHIND/UNPUSHED/DIVERGED split).
#
# Builds real scratch git repos (bare "remote" + local clone) on disk under a tmpdir for EACH
# state and calls handoff_status.sh with EXPLICIT repo args pointing at them — never adds a repo
# under a seat root (tasks/handoff-status-three-state-push-check.task.md NEXT §5: "a stray clone
# becomes a permanent handoff blocker the moment it takes a local commit"). Also exercises the
# auto-discovery "nothing to examine" path by invoking a throwaway copy of the script from an
# empty scratch workspace. Nothing here touches the real workspace, postoffice, or any seat root.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
set -u
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HS="$SELF_DIR/handoff_status.sh"
. "$SELF_DIR/lib_gate.sh"
gate_require "$HS" "handoff_status.sh"

fail=0
TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT
G() { git -c user.name=gatetest -c user.email=gatetest@test.invalid -c init.defaultBranch=main "$@"; }

# mk_repo NAME -- a bare "origin" plus a local clone, one initial commit, both in sync.
mk_repo() {
  local name="$1" bare="$TMP/$1.git" local="$TMP/$1"
  G init -q --bare "$bare"
  G clone -q "$bare" "$local" 2>/dev/null
  G -C "$local" commit -q --allow-empty -m "$name: initial"
  G -C "$local" push -q -u origin HEAD:main
  printf '%s\n' "$local"
}

synced="$(mk_repo synced)"
behind="$(mk_repo behind)"
unpushed="$(mk_repo unpushed)"
diverged="$(mk_repo diverged)"
dirty="$(mk_repo dirty)"

# BEHIND: push a second commit directly into the bare remote via a THROWAWAY clone (never touch
# the "behind" local clone itself -- that is what makes it behind).
tmp2="$TMP/.behind-pusher"; G clone -q "$TMP/behind.git" "$tmp2"
G -C "$tmp2" commit -q --allow-empty -m "behind: a commit the local clone never sees"
G -C "$tmp2" push -q origin main

# UNPUSHED: commit locally, never push.
G -C "$unpushed" commit -q --allow-empty -m "unpushed: local-only commit"

# DIVERGED: commit locally AND push a different commit to the remote via a throwaway clone.
G -C "$diverged" commit -q --allow-empty -m "diverged: local-only commit"
tmp3="$TMP/.diverged-pusher"; G clone -q "$TMP/diverged.git" "$tmp3"
G -C "$tmp3" commit -q --allow-empty -m "diverged: a DIFFERENT remote-only commit"
G -C "$tmp3" push -q origin main

# DIRTY: an uncommitted modification to a tracked file.
echo "uncommitted" > "$dirty/tracked.txt"; G -C "$dirty" add tracked.txt
G -C "$dirty" commit -q -m "dirty: add the file we are about to dirty"
echo "modified, never committed" > "$dirty/tracked.txt"

# UNKNOWN: origin repointed at a path that does not exist -- fetch fails deterministically, no
# network involved.
unknown="$(mk_repo unknown)"
git -C "$unknown" remote set-url origin "$TMP/does-not-exist.git"

check() {
  local desc="$1" want_rc="$2" want_grep="$3"; shift 3
  local out rc
  out="$(bash "$HS" "$@" 2>&1)"; rc=$?
  if [ "$rc" -ne "$want_rc" ]; then
    echo "VIOLATION: $desc -- expected rc=$want_rc, got rc=$rc"; printf '%s\n' "$out"; fail=$((fail+1)); return
  fi
  if [ -n "$want_grep" ] && ! printf '%s\n' "$out" | grep -qiE "$want_grep"; then
    echo "VIOLATION: $desc -- rc was correct ($rc) but output did not match /$want_grep/"; printf '%s\n' "$out"; fail=$((fail+1))
  fi
}

check "SYNCED alone -> COMPLETE"                      0 "COMPLETE"                          "$synced"
check "SYNCED + BEHIND -> COMPLETE (BEHIND must not block)" 0 "COMPLETE"                     "$synced" "$behind"
check "BEHIND alone names the state BEHIND, not UNPUSHED"    0 "BEHIND"                      "$behind"
check "UNPUSHED alone -> WAITING, mentions push"      1 "WAITING.*\n.*push|push.*"           "$unpushed"
check "UNPUSHED alone names the state UNPUSHED"       1 "UNPUSHED"                           "$unpushed"
check "DIVERGED alone -> WAITING, mentions pull --rebase (not just push)" 1 "pull --rebase"  "$diverged"
check "DIVERGED alone names the state DIVERGED"       1 "DIVERGED"                           "$diverged"
check "DIRTY alone -> WAITING, mentions uncommitted"  1 "uncommitted"                        "$dirty"
check "UNKNOWN alone -> REFUSES (rc=2), not WAITING and not COMPLETE" 2 "REFUSES"            "$unknown"
check "SYNCED + UNKNOWN -> REFUSES, never a false COMPLETE" 2 "REFUSES"                      "$synced" "$unknown"
check "UNPUSHED + UNKNOWN -> known blocker wins, still WAITING (not silently REFUSES-only)" 1 "WAITING" "$unpushed" "$unknown"

# --- zero-repos-to-examine path: a throwaway copy of the script run from an EMPTY scratch
# workspace must REFUSE (rc=2), never WAITING and never COMPLETE (lib_gate.sh's own "zero-examined
# is not a pass" law, applied here to the handoff instrument itself).
emptyws="$TMP/emptyws/harness/scripts"; mkdir -p "$emptyws"
cp "$HS" "$emptyws/handoff_status.sh"
out_empty="$(bash "$emptyws/handoff_status.sh" 2>&1)"; rc_empty=$?
if [ "$rc_empty" -ne 2 ]; then
  echo "VIOLATION: empty workspace (nothing to examine) -- expected rc=2, got rc=$rc_empty"; printf '%s\n' "$out_empty"; fail=$((fail+1))
elif ! printf '%s\n' "$out_empty" | grep -qi "REFUSES"; then
  echo "VIOLATION: empty workspace -- rc=2 but output did not say REFUSES"; printf '%s\n' "$out_empty"; fail=$((fail+1))
fi

GATE_EXAMINED=12
gate_verdict "$fail" "handoff_status.sh three-state violation(s)"
