#!/bin/bash
# lib_subject_tree.sh -- THE SUBJECT TREE IS THE TREE THE SCRIPT LIVES IN.  Sourced, never executed.
#
# ⛔⭐ THE DEFECT THIS EXISTS TO KILL (measured by the coo 2026-09-13, reported against its OWN landing --
# an honest self-report, and the discipline this file exists to protect; row
# snobol4-a-gate-that-reads-the-main-tree-src-passes-in-a-worktree-while-origin-is-red):
# test_gate_no_weak_abort_stub.sh resolved the tree it graded from the MAIN root rather than from the tree it
# was invoked in, so a pre-landing preflight run in a second worktree read 33 arms 0 red WHILE ORIGIN WAS RED
# for about thirty-five minutes after f0d0adf5b landed a weak pas_gc_roots.
#
# ⭐ THE DEFECT IS NOT A TYPO, IT IS AN IDIOM.  Every instance has the same two hops:
#         S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # UP to the sibling root
#         SRC="$S4E/SCRIP/src"                                                     # DOWN into a HARDCODED name
# The first hop is correct and is the D-17 PORTABLE-HOME rule: siblings (corpus, .github, the oracles) really
# do hang off one root, and you really do have to go up to reach them.  ⛔ THE SECOND HOP IS THE BUG: it comes
# back down into the literal string `SCRIP`, which is the name of the MAIN checkout and of nothing else.  A
# worktree is a sibling of the main checkout, not a replacement for it, so the round trip lands in the tree you
# are NOT standing in -- and the gate then grades a tree the seat is not pushing.
#
# ⛔⭐ WHY IT IS SILENT, WHICH IS THE HALF THAT COST THIRTY-FIVE MINUTES OF RED ORIGIN.  The gate is not
# confused and does not guess: it prints `src: /home/claude_B/SCRIP/src`, names the tree, and grades it
# correctly.  Everything it says is TRUE.  It is simply an answer to a question nobody asked -- the same
# narrow-instrument shape as `command -v` answering "is it on PATH" when the reader meant "does it exist".
# A wrong-subject verdict has no symptom, because a verdict about the wrong tree looks exactly like a verdict.
#
# ⛔⭐⭐ AND THE PROVENANCE STAMP INHERITED IT, WHICH IS WHY THIS IS A LIBRARY AND NOT A ONE-LINE FIX.
# `gate_stamp` in lib_gate.sh carried the identical two hops, so the one line every seat cites to prove WHICH
# TREE a verdict came from named the main checkout too.  Measured here 2026-09-13 from an armed sibling
# worktree: the stamp printed `SCRIP=202d8bfff` with NO `-DIRTY` while the tree being graded was dirty.
# `-DIRTY` is described in lib_gate.sh's own comment as load-bearing, and worktree-blindness strips it in
# silence.  ⭐ The general form worth keeping: when a bug lives in the instrument that reports provenance, it
# does not merely produce a wrong answer -- it produces a wrong answer WEARING A CORRECT-LOOKING RECEIPT, and
# every downstream reader inherits the error with the confidence of a citation.
#
# THE RULE.  A script's SUBJECT -- its src, its `scrip` binary, its out/, its .git -- is resolved from the
# script's OWN location and never from a hardcoded repo name.  Siblings are still reached through the root.
# When the two disagree, say so; never silently grade the other one.

# s4e_subject_repo [<path-of-caller>] -- the repo directory the CALLING script lives in.
# Defaults to the caller's BASH_SOURCE, which is what you want at every call site; the argument exists so a
# census tool can ask the question about a script it is not running.
s4e_subject_repo() {
    local _src="${1:-${BASH_SOURCE[1]}}"
    ( cd "$(dirname "$_src")/../../SCRIP" 2>/dev/null && pwd )
}

# s4e_subject_root [<repo>] -- the sibling root ABOVE a repo.  Use this, and only this, to reach corpus/.github
# and the oracles.  ⛔ Never append a repo name to it to get back to your own tree -- that round trip IS the bug.
s4e_subject_root() {
    local _repo="${1:-$(s4e_subject_repo "${BASH_SOURCE[1]}")}"
    ( cd "$_repo/.." 2>/dev/null && pwd )
}

# s4e_subject_legacy [<repo>] -- what the OLD up-and-back-down idiom would have resolved to, given this repo.
# Echoes nothing when that path does not exist (a worktree parked somewhere with no `SCRIP` sibling: there is
# no other tree to be confused with, so there is nothing to diverge from).
s4e_subject_legacy() {
    local _repo="${1:-$(s4e_subject_repo "${BASH_SOURCE[1]}")}"
    local _root="${S4E_HOME:-$(cd "$_repo/.." 2>/dev/null && pwd)}"
    [ -n "$_root" ] || return 0
    [ -d "$_root/SCRIP" ] || return 0
    ( cd "$_root/SCRIP" 2>/dev/null && pwd )
}

# s4e_subject_diverges [<repo>] -- rc 0 when the script's own tree and the legacy target are the SAME tree (the
# ordinary main-checkout case, where this whole library is a no-op), rc 1 when they are DIFFERENT TREES.
s4e_subject_diverges() {
    local _repo="${1:-$(s4e_subject_repo "${BASH_SOURCE[1]}")}"
    local _legacy; _legacy="$(s4e_subject_legacy "$_repo")"
    [ -n "$_legacy" ] || return 0
    [ "$_legacy" = "$_repo" ] && return 0
    return 1
}

# s4e_subject_announce [<repo>] -- ALWAYS print which tree is the subject, and print the divergence when there
# is one.  ⭐ It prints on the agreeing case too, on purpose: a line that appears only when something is wrong
# teaches nobody to look for it, and the reader cannot tell "no divergence" from "this build of the gate has no
# divergence check".  One always-present line makes a wrong subject readable at a glance in any log.
s4e_subject_announce() {
    local _repo="${1:-$(s4e_subject_repo "${BASH_SOURCE[1]}")}"
    local _legacy; _legacy="$(s4e_subject_legacy "$_repo")"
    printf 'subject tree: %s   (derived from this script, not from a hardcoded repo name)\n' "$_repo"
    if [ -n "$_legacy" ] && [ "$_legacy" != "$_repo" ]; then
        printf '⚠️  DIVERGENCE: the old up-and-back-down idiom would have graded %s instead.\n' "$_legacy"
        printf '    That is a DIFFERENT TREE.  This run grades the tree it was invoked in, which is the tree you are pushing.\n'
        return 1
    fi
    return 0
}

# s4e_subject_refuse_on_divergence [<repo>] -- for an instrument that genuinely CANNOT self-derive its subject.
# ⛔ This is the second-best cure and the library says so: deriving correctly is always better than refusing,
# because a refusal still leaves the seat without a verdict.  It exists so that "I cannot tell which tree this
# is about" is never spelled the same way as "I checked and it is clean" -- lib_gate.sh's three-exit-code rule.
s4e_subject_refuse_on_divergence() {
    local _repo="${1:-$(s4e_subject_repo "${BASH_SOURCE[1]}")}"
    if ! s4e_subject_diverges "$_repo"; then
        local _legacy; _legacy="$(s4e_subject_legacy "$_repo")"
        echo "⛔ REFUSES rc=2: this instrument resolves its subject through a hardcoded repo name, and that"
        echo "   name points somewhere else right now."
        echo "     this script lives in : $_repo"
        echo "     it would have graded : $_legacy"
        echo "   Grading the second while standing in the first is how a worktree preflight reads green while"
        echo "   origin is red.  Refusing is NOT a pass; cure the instrument to derive from its own location."
        exit 2
    fi
}
