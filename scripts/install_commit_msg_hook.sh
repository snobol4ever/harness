#!/usr/bin/env bash
# install_commit_msg_hook.sh — put the forbidden-trailer commit-msg hook into EVERY sibling repo.
# D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root).
#
# ⛔⭐ GIT HOOKS DO NOT PROPAGATE THROUGH CLONE. A hook that lives in one seat's .git/hooks
# protects one seat. That is why this installer exists and why it is invoked from the
# per-prompt session path (../harness/scripts/s4e_inbox_hook.sh) rather than from `make setup`:
# MEASURED 2026-08-30 -- `make setup` runs `bash $ROOT/setup.sh`, and setup.sh DOES NOT EXIST
# in this tree, so wiring installation there would have installed nothing, forever. Same
# defect class as the graders that refused over a population that had moved: a mechanism that
# exists, looks wired, and cannot fire. `make hooks` is provided as the explicit manual entry
# point and `make setup` now runs it first.
#
# Idempotent and silent when already current: it rewrites a hook only when the bytes differ,
# so the per-prompt call costs a cmp and nothing else.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SRC="$HERE/lib_commit_msg_hook.txt"
[ -f "$SRC" ] || { echo "install_commit_msg_hook: canonical hook missing at $SRC" >&2; exit 2; }
# ⛔⭐ THE PRE-COMMIT HOOK RIDES THE SAME INSTALLER, deliberately. Hooks do not propagate through clone, and
# this installer is already invoked per-prompt from ../harness/scripts/s4e_inbox_hook.sh -- so a SECOND installer would
# be a second thing to remember to wire, and the first cut of THIS one was measured installing into two of
# three repos while printing a confident success line. One walk, both hooks, one report.
SRC_PC="$HERE/lib_pre_commit_hook.txt"
[ -f "$SRC_PC" ] || { echo "install_commit_msg_hook: canonical pre-commit hook missing at $SRC_PC" >&2; exit 2; }
quiet=0; [ "${1:-}" = "--quiet" ] && quiet=1
installed=0; current=0; failed=0
# ⛔⭐ BOTH GLOBS, AND THIS IS NOT DEFENSIVE PADDING -- `*/` ALONE SILENTLY HIDES .github/.
# CLAUDE.md documents this exact trap for the workspace map, and the first cut of this
# installer walked straight into it: it reported "installed=2" (SCRIP, corpus) and left
# .github -- the repo that carries RULES.md and every FINDING -- entirely unprotected, while
# printing a confident success line. An unanchored glob does not report what it did not match.
for d in "$S4E"/*/ "$S4E"/.*/; do
    b="$(basename "${d%/}")"
    [ "$b" = "." ] || [ "$b" = ".." ] && continue
    g="$d/.git"
    [ -d "$g" ] || continue
    hd="$g/hooks"; mkdir -p "$hd" 2>/dev/null || { failed=$((failed+1)); continue; }
    for pair in "commit-msg:$SRC" "pre-commit:$SRC_PC"; do
        nm="${pair%%:*}"; src="${pair#*:}"
        dst="$hd/$nm"
        if [ -f "$dst" ] && cmp -s "$src" "$dst"; then current=$((current+1)); continue; fi
        if cp "$src" "$dst" 2>/dev/null && chmod +x "$dst" 2>/dev/null; then
            installed=$((installed+1))
            [ "$quiet" = 1 ] || echo "  installed $nm hook -> $(basename "${d%/}")"
        else
            failed=$((failed+1))
            echo "install_commit_msg_hook: FAILED to write $dst" >&2
        fi
    done
done
if [ "$quiet" = 1 ]; then
    # ⭐ SILENT WHEN THERE IS NOTHING TO SAY. This runs from the per-prompt session hook, whose
    # output lands in every seat's context on EVERY turn -- a line printed each time would be
    # exactly the reminder-nobody-reads this hook exists to replace. One line when it actually
    # installs something (a seat should know it just got protected), nothing when already current.
    [ "$installed" -gt 0 ] && echo "✅ commit-msg hook installed into $installed repo(s) — forbidden trailers are now rejected at commit time."
else
    echo "commit-msg hook: installed=$installed already-current=$current failed=$failed (root $S4E)"
fi
[ "$failed" -eq 0 ] || exit 1
exit 0
