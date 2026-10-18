#!/bin/bash
# lib_gate.sh -- V2-5 GATE HONESTY primitives.  Sourced, never executed.
#
# THE DEFECT THIS EXISTS TO KILL (seat16's audit, FINDING-2026-08-22-seat16-rung-gate-false-green-audit.md):
# 31 of 105 gates COULD NOT SAY NO.  Four distinct classes, one root cause -- a gate that examined NOTHING
# reported the same thing as a gate that examined everything and found it clean.  At 16 seats a gate that
# cannot fail closes rows on false green at scale, and ARCH-FLEET-CEO.md LAW 1 ("done is computed, never
# declared") is only as good as the gates a DONE-WHEN cites.
#
# THE THREE EXIT CODES.  This is the whole idea: "I checked and it is clean" and "I could not check" must
# never be the same exit code again.
#   0  CLEAN     -- work was actually examined, and it was good.
#   1  VIOLATION -- work was examined, and it was bad.
#   2  UNPROVEN  -- the gate could not examine the work (missing binary, empty corpus, absent path).
#                   ⛔ NOT a pass.  A fresh unbuilt seat gets 2, which is what SKIP-as-success was hiding.
#
# STRICTNESS IS NOW THE DEFAULT.  The old shape was "informational, exit 0, pass --strict to enforce" -- and
# `grep -rn -- --strict ../harness/scripts/` proved NOTHING in the repo ever passed it.  A flag no caller passes is not
# an option, it is a disabled gate.  Callers wanting the old behaviour pass --informational explicitly, and
# it announces itself.
GATE_NAME="${GATE_NAME:-$(basename "${BASH_SOURCE[1]:-gate}" .sh)}"
GATE_STRICT=1
GATE_EXAMINED=0
gate_parse_args() {
    for a in "$@"; do
        case "$a" in
            --strict)        GATE_STRICT=1 ;;
            --informational) GATE_STRICT=0 ;;
        esac
    done
    [ "$GATE_STRICT" = "0" ] && echo "⛔ $GATE_NAME: --informational -- verdict is NOT enforced, exit code is not a gate result."
    return 0
}
# ⭐⭐ THE TREE STAMP — ON EVERY ARM, INCLUDING UNPROVEN (hq_B + hq_C, 2026-08-29).
# ⛔ WHY IT IS NOT A TIMESTAMP: a verdict outlives the tree it measured, and then two honest readings of the
# same gate become an argument instead of a datum. hq_C's witness this session: one witness read stable at
# noon and 4/6 split that morning; without a stamp that is two people with different numbers, "resolved" by
# whoever measured last. WITH it, both readings are true and THE TREE MOVED — which is a finding, not a dispute.
# ⛔ SO IT STAMPS THE TREE, NOT THE CLOCK. Per repo, because SCRIP and corpus CAN disagree and a gate reads
# both. And -DIRTY is load-bearing: a bare HEAD hash on a dirty tree is WORSE than no hash, because it names a
# commit that does not describe what actually ran.
# ⛔ AND IT STAMPS UNPROVEN(2) TOO, not only PASS/FAIL. An UNPROVEN that cannot say which tree it failed to
# measure is the least actionable output a gate can produce — you cannot even tell whether a later build fixed it.
# ⭐ INSIDE THE HELPER, NEVER OPT-IN (hq_C's ruling, and the reason is decisive): an opt-in stamp is a stamp the
# next instrument forgets, and forgetting IS the failure mode. It also fails ASYMMETRICALLY — the gates that
# remember to opt in are the carefully-written ones, so the stamp would be present exactly where it was least
# needed and absent where it mattered most. No call site changes; all 17 callers inherit it.
# It must never break a gate: every git call is failure-tolerant and an unreadable repo prints `unknown`.
# ⛔⭐⭐ AND IT STAMPS THE TREE THIS SCRIPT LIVES IN, NOT THE ONE WHOSE NAME MATCHES (hq_B 2026-09-13, row
# snobol4-a-gate-that-reads-the-main-tree-src-passes-in-a-worktree-while-origin-is-red).  This helper used to
# hop UP to the sibling root and back DOWN into the literal string `SCRIP` -- which is the name of the MAIN
# checkout and of nothing else -- so a gate run in a second worktree stamped the main checkout's HEAD.
# ⛔ THE DAMAGE IS SPECIFICALLY TO `-DIRTY`, THE PART THIS COMMENT ALREADY CALLS LOAD-BEARING. Measured from an
# armed sibling worktree: the stamp printed `SCRIP=202d8bfff` with NO `-DIRTY` while the tree actually being
# graded was dirty -- a clean-looking receipt for an uncommitted tree, which is the one reading `-DIRTY` exists
# to make impossible.  ⭐ A bug in the instrument that reports provenance does not produce a wrong answer; it
# produces a wrong answer WEARING A CORRECT-LOOKING CITATION, and every downstream reader inherits it.
# The SIBLINGS (corpus, .github) still resolve through the root, because they genuinely are siblings and going
# up to reach them is the D-17 PORTABLE-HOME rule working as intended.  Only the hop BACK DOWN was ever wrong.
gate_stamp() {
    local _root _r _p _h _dirty _self
    _self="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" 2>/dev/null && pwd)"
    _root="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd 2>/dev/null)}"
    printf '    tree:'
    for _r in SCRIP corpus .github; do
        # ⭐ This helper lives at <SCRIP-repo>/scripts/lib_gate.sh BY CONSTRUCTION, so `_self` IS the SCRIP
        # repo being run -- worktree or main checkout, whatever it is named on disk.  That is the whole fix:
        # the SCRIP row is stamped from where this file actually is, the sibling rows from the root above it.
        if [ "$_r" = SCRIP ] && [ -n "$_self" ]; then _p="$_self"; else _p="$_root/$_r"; fi
        # ⛔ -e NOT -d: in a git WORKTREE `.git` is a FILE, not a directory, so `-d` skipped every repo and the
        # stamp printed a bare `tree:` with NOTHING after it — the exact unactionable verdict this helper
        # exists to prevent, and it fired precisely where fail-once proofs are required to run (rungs say
        # "prove it in a scratch worktree").  Measured hq_B 2026-09-02 proving I5.  `git -C` is worktree-native,
        # so widening the test is all that was ever needed; a real repo dir still matches -e unchanged.
        [ -e "$_p/.git" ] || continue
        _h="$(git -C "$_p" rev-parse --short HEAD 2>/dev/null)"
        if [ -z "$_h" ]; then printf ' %s=unknown' "$_r"; continue; fi
        if [ -n "$(git -C "$_p" status --porcelain 2>/dev/null)" ]; then _dirty="-DIRTY"; else _dirty=""; fi
        printf ' %s=%s%s' "$_r" "$_h" "$_dirty"
    done
    printf '  measured %s\n' "$(date -u +%Y-%m-%dT%H:%MZ)"
    # ⛔⭐ AND THE MACHINE, BECAUSE A TIMING-DEPENDENT VERDICT IS MACHINE-RELATIVE AS WELL AS TREE-RELATIVE.
    # ⚠️ READ THE PROVENANCE BEFORE CITING THIS. It was asked for by hq_C against fuzz-nondeterminism-rootcause,
    # where a witness appeared to flip rc 0 vs 124 with no code change. hq_C THEN RETRACTED THAT CASE ON THEIR
    # OWN MEASUREMENT and told me before I could build on it: a duration histogram (N=8, 20s ceiling, mode 3)
    # put fz_red_m1b at 0.02s x2 vs >=20.01s x6 and fz_segv_24 at 0.02s x4 vs >=20.01s x4 -- NOTHING near the
    # 8s boundary. A load-induced timeout clusters durations AROUND the boundary; those sit at 0.02s or run
    # past any ceiling offered. The hang is genuine and unbounded, and load was irrelevant to it.
    # ⭐ THE FEATURE STAYS, ON DIFFERENT AND INDEPENDENTLY MEASURED EVIDENCE -- not on the retracted case, and
    # this comment says so rather than quietly keeping the old justification. Measured here the same session:
    # test_corpus_snobol4.sh reported TIME TOTAL=487s where CLAUDE.md documents that board at ~28s, a 17x
    # spread on one box at load ~22/16 cores. A timeout tuned to the documented figure would SIGTERM a fully
    # green board and read as a hang. That is the real case, it is this file's own kind of instrument, and it
    # is why the stamp is worth its two lines.
    # ⛔ WHAT hq_C'S RETRACTION ACTUALLY PROVED IS SHARPER THAN THE ASK, AND IT IS NOT ABOUT LOAD: rc=124 is
    # byte-identical whether a program needs 8.1 seconds or forever, so the code has no capacity to
    # distinguish its two causes and every reader supplies the one they already believe -- six sessions read
    # a timeout code and inferred a hang, and were right by luck. ONLY A DURATION DISTRIBUTION SEPARATES THEM.
    # So the honest lesson is that an rc is not a measurement of time; if a verdict depends on duration,
    # RECORD THE DURATION. This stamp records the machine, which is the cheap half; the expensive half belongs
    # in whatever instrument is doing the timing.
    # ⭐ A NUMBER'S TREE IS PART OF ITS LABEL; FOR A TIMING-DEPENDENT NUMBER THE MACHINE STATE IS TOO, and
    # omitting it is the same omission wearing a clock. The ratio is what matters, so nproc is printed beside
    # the load rather than leaving the reader to guess the core count of a box they may never see.
    local _la _np
    _la="$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null)"; _np="$(nproc 2>/dev/null)"
    [ -n "$_la" ] && printf '    machine: load %s on %s core(s) — an rc=124 in this run is a TIMEOUT FIRING, which is not by itself evidence of a hang: it cannot distinguish "needs 8.1s" from "never finishes". If a verdict turns on duration, record the duration.\n' "$_la" "${_np:-?}"
}
# gate_require <path> <what-it-is> -- a prerequisite that must exist.  Absent => UNPROVEN(2), never SKIP-0.
gate_require() {
    if [ ! -e "$1" ]; then
        echo "GATE UNPROVEN(2) [$GATE_NAME]: required $2 is absent at $1"
        echo "    This is NOT a pass.  The gate could not examine anything, so it cannot certify anything."
        gate_stamp
        exit 2
    fi
}
# gate_require_exec <path> <what-it-is> -- same, but must also be executable (the unbuilt-scrip class).
gate_require_exec() {
    if [ ! -x "$1" ]; then
        echo "GATE UNPROVEN(2) [$GATE_NAME]: required $2 is not built/executable at $1"
        echo "    This is NOT a pass.  Build it (make) and re-run; a fresh seat must not read as green."
        gate_stamp
        exit 2
    fi
}
# gate_require_fresh <repo-root> <src-subdir> <binary> [<binary2> ...] -- refuse rc=2 (UNPROVEN) when any
# binary is older than the newest git-TRACKED FILE under <src-subdir> or Makefile. Never HEAD's commit time --
# a commit's %ct is when it was AUTHORED, and the ordinary order of work (build, grade, THEN commit) moves HEAD
# past a binary that is genuinely current without changing a byte of source (row stale-binary-refusal-compares-
# against-the-head-commit-time-not-the-newest-tracked-source, hq_B/ceo 2026-09-04, this function's own SIBLING
# defect: lib_build_currency.sh's assert_binary_current dropped the identical commit-time half in 3d12ca54 --
# "Fixes c9b9e144, which shipped max(newest src/ commit %ct, newest src/ file mtime). The commit half ... IS
# WRONG" -- but this second, unrelated copy of the same idea was never unified onto that fix and kept it).
#
# THE DEFECT THIS EXISTS TO KILL (FINDING-2026-08-30-hq_C-the-snobol4-board-grades-whatever-scrip-exists-and-
# labels-that-verdict-with-git-head.md): a board that never builds grades whatever binary happens to be sitting
# in the tree, then stamps the report with a `tree: SCRIP=<sha>` line read from git -- so the SHA is not
# evidence about the artifact that was graded. A pristine build of the exact commit one such board called clean
# SIGSEGV'd two counted entries. A board that cannot establish what it graded must refuse, never label.
gate_require_fresh() {
    local _root="$1" _srcdir="$2"; shift 2
    local _f _t _newest_t=0 _newest_f="" _bin _bin_t _stale=0 _why=""
    while IFS= read -r _f; do
        [ -e "$_root/$_f" ] || continue
        _t="$(stat -c %Y "$_root/$_f" 2>/dev/null)" || continue
        if [ "$_t" -gt "$_newest_t" ] 2>/dev/null; then _newest_t="$_t"; _newest_f="$_f"; fi
    done < <(git -C "$_root" ls-files -- "$_srcdir" Makefile 2>/dev/null)
    # ⭐ THE PROBE (ceo's DONE-WHEN contract for row harness-and-ladder-runner-refuse-on-a-stale-binary-like-the-artifact-
    # regen-does, hq_T 2026-09-04): SCRIP_STALE_PROBE_SRC names ONE extra candidate for "newest source". It exists so a
    # fail-once proof can run against a SCRATCH file instead of touching a tracked src/ file in the real tree -- a proof
    # that edits the tree it grades is how a green gate and a dirty checkout coexist. It can only make the verdict
    # STRICTER (a probe older than the real newest source changes nothing), so it cannot smuggle a stale binary past the
    # guard; the deliberate-stale-run switch is SCRIP_ALLOW_STALE below, and that one is loud by construction.
    if [ -n "${SCRIP_STALE_PROBE_SRC:-}" ] && [ -e "$SCRIP_STALE_PROBE_SRC" ]; then
        _t="$(stat -c %Y "$SCRIP_STALE_PROBE_SRC" 2>/dev/null)" || _t=0
        if [ "$_t" -gt "$_newest_t" ] 2>/dev/null; then _newest_t="$_t"; _newest_f="$SCRIP_STALE_PROBE_SRC (SCRIP_STALE_PROBE_SRC probe)"; fi
    fi
    for _bin in "$@"; do
        [ -e "$_bin" ] || continue
        _bin_t="$(stat -c %Y "$_bin" 2>/dev/null)" || continue
        if [ "$_newest_t" -gt 0 ] && [ "$_bin_t" -lt "$_newest_t" ] 2>/dev/null; then
            _stale=1; _why="$_bin is older than tracked source $_newest_f"; break
        fi
    done
    if [ "$_stale" = 1 ] && [ "${SCRIP_ALLOW_STALE:-}" = 1 ]; then
        # ⛔⭐ THE DELIBERATE STALE RUN -- LOUD AND RECORDED, NEVER SILENT (ceo's brief, same row). LOUD: the banner goes to
        # BOTH streams, so it lands in whatever a reader captured. RECORDED: gate_score_row refuses to write THE ONE
        # LEADERBOARD while SCRIP_ALLOW_STALE=1 is set -- a board row stamps a tree hash, and a number measured on a binary
        # older than that tree is a lie wearing a provenance clause. The verdict may be quoted only WITH this banner; it is
        # never the tree's score. ⛔ A MISSING artifact is not overridable (util_require_fresh.sh refuses before reaching
        # here): stale is "an older program ran", missing is "nothing ran", and only the first can be a deliberate choice.
        _msg="⚠️⚠️ STALE-BINARY OVERRIDE [${GATE_NAME:-gate}]: SCRIP_ALLOW_STALE=1 -- grading a binary OLDER than the tree it will be labelled with ($_why). This verdict describes a program that no longer exists: quote it WITH this line, never as the tree's score; SCORE.md will NOT be written from this run."
        echo "$_msg"; echo "$_msg" >&2
        gate_stamp
        return 0
    fi
    if [ "$_stale" = 1 ]; then
        echo "GATE UNPROVEN(2) [${GATE_NAME:-gate}]: ⛔ REFUSES rc=2: binary older than the tree it names -- make scrip, then re-run"
        echo "    $_why"
        for _bin in "$@"; do
            [ -e "$_bin" ] && echo "    $_bin: mtime $(date -u -d "@$(stat -c %Y "$_bin")" +%Y-%m-%dT%H:%MZ 2>/dev/null)"
        done
        echo "    newest tracked file under $_srcdir/ or Makefile: ${_newest_f:-none} ($([ "$_newest_t" -gt 0 ] && date -u -d "@$_newest_t" +%Y-%m-%dT%H:%MZ 2>/dev/null || echo n/a))"
        gate_stamp
        exit 2
    fi
}
# gate_tree_signature <repo-root> -- md5 of the CONTENT of every file under src/ plus the Makefile, in a stable
# order. Content, never mtime: the whole point of this pair of functions is that mtime is the instrument that
# failed. Untracked files are INCLUDED deliberately -- an uncommitted new .cpp is compiled into the build like
# any other, so a signature that only saw `git ls-files` would call a tree "the same tree" across an edit that
# changed the compiler. ~16ms MEASURED over 411 files.
gate_tree_signature() {
    local _root="$1"
    { find "$_root/src" -type f -print0 2>/dev/null | LC_ALL=C sort -z | xargs -0 md5sum 2>/dev/null; md5sum "$_root/Makefile" 2>/dev/null; } | md5sum | cut -c1-32
}
# gate_behaviour_signature <repo-root> <scrip-binary> -- md5 of the .s this binary EMITS for the pinned witnesses in
# ../harness/scripts/fixtures/build_behaviour/. Prints the signature on stdout; returns 1 and prints nothing if it could not
# compile every witness (the caller turns that into rc=2 -- "I could not establish what you are about to grade").
# ~0.10s MEASURED for all three witnesses. Emission is deterministic TWICE OVER, and the second is the load-bearing one:
# two runs on ONE binary are byte-identical, AND a 155-object rebuild of an UNCHANGED tree reproduces the signature
# exactly -- so emission is a pure function of the tree, and a green tree cannot be turned red merely by rebuilding it.
gate_behaviour_signature() {
    local _root="$1" _bin="$2" _tmp _w _rc=0 _n=0
    [ -x "$_bin" ] || return 1
    _tmp="$(mktemp -d 2>/dev/null)" || return 1
    for _w in "$_root"/../harness/scripts/fixtures/build_behaviour/*.icn "$_root"/../harness/scripts/fixtures/build_behaviour/*.sno "$_root"/../harness/scripts/fixtures/build_behaviour/*.pl; do
        [ -f "$_w" ] || continue
        _n=$((_n+1))
        env -u SCRIP_SNO_STMTKW -u SCRIP_DIAG -u SCRIP_DIAG_REGS "$_bin" --compile -o "$_tmp/$(basename "$_w").s" "$_w" </dev/null >/dev/null 2>&1 || _rc=1
        [ -s "$_tmp/$(basename "$_w").s" ] || _rc=1
    done
    if [ "$_n" = 0 ] || [ "$_rc" != 0 ]; then rm -rf "$_tmp"; return 1; fi
    ( cd "$_tmp" && LC_ALL=C ls *.s | LC_ALL=C sort | xargs cat ) | md5sum | cut -c1-32
    rm -rf "$_tmp"
}
# gate_require_built_from <repo-root> [<scrip-binary>] -- ⛔⭐ THE BEHAVIOUR PROBE. THE GUARD ABOVE PROVES THE BINARY
# IS NEWER THAN THE SOURCES; IT CANNOT PROVE THE BINARY WAS BUILT FROM THEM, AND THOSE ARE DIFFERENT CLAIMS.
#
# THE DEFECT THIS EXISTS TO KILL (FINDING-2026-09-09-hq_P-a-completed-make-produced-a-binary-that-did-not-match-its-
# own-templates.md): a full `make` reported "Built: scrip" after compiling 198 objects and handed back a compiler that
# emitted code its own template sources do not describe -- three builds on one commit produced two different compilers.
# Every freshness check on the box PASSED throughout, and the only thing that exposed it was an unrelated source edit.
# Two SCORE rows were published from it.
#
# ⛔⭐ WHY THE MTIME GUARD CANNOT SEE THIS, WHICH IS STRUCTURAL AND NOT A BUG IN IT: the two artifacts it stamps are
# touched by the ACT OF RUNNING make, not by the build being right. `scrip`'s only prerequisite is the PHONY target
# `libscrip_rt`, so it is relinked on EVERY make; `out/libscrip_rt.so` carries a FORCE prerequisite, so its symlink is
# re-pointed on EVERY make; and $(RT_SO) itself relinks whenever ANY ONE of 269 objects changed. So a single stale
# object among 269 leaves all three artifacts newer than every source in the tree. The mtime guard is satisfied by
# make having RUN. It is structurally incapable of failing after a make that compiled anything at all.
#
# ⭐ WHAT THIS PROVES, STATED HONESTLY: it is a SELF-PIN, in exactly the sense CEO-395 draws for rungs refs and the
# port-trace standard draws for its two shapes. It proves the emitted code HAS NOT MOVED under a tree that HAS NOT
# MOVED. It proves nothing whatever about whether that code is RIGHT -- the oracle diffs do that. That narrow claim is
# the one the FINDING needed and could not get: hq_P's three builds sat on ONE commit, so the tree signature was
# constant across all three while the behaviour signature was not, and this fires on precisely that.
#
# THE LEDGER is out/build_behaviour.sig (gitignored, per-checkout, one line per observation:
# <tree-sig> <behaviour-sig> <so-md5> <iso8601> <seat>). A tree seen for the first time is RECORDED and passes -- there
# is no prior observation to contradict, and a probe that refused on first sight would refuse on every fresh clone.
# EXIT: 0 consistent (or first observation) - 2 REFUSED (the binary moved under a static tree, or a witness would not
# compile). ⛔ NEVER 1, for the same reason gate_require_fresh never returns 1.
gate_require_built_from() {
    local _root="$1" _bin="${2:-$1/scrip}" _led _ts _bs _so _prev _prevso _now
    _led="$_root/out/build_behaviour.sig"
    if [ ! -x "$_bin" ]; then
        echo "GATE UNPROVEN(2) [${GATE_NAME:-gate}]: ⛔ REFUSES rc=2: no binary at $_bin -- cannot probe what a build emits when nothing was built"
        gate_stamp; return 2
    fi
    _ts="$(gate_tree_signature "$_root")"
    if ! _bs="$(gate_behaviour_signature "$_root" "$_bin")" || [ -z "$_bs" ]; then
        echo "GATE UNPROVEN(2) [${GATE_NAME:-gate}]: ⛔ REFUSES rc=2: $_bin could not --compile the pinned build-behaviour witnesses"
        echo "    witnesses: $_root/../harness/scripts/fixtures/build_behaviour/  -- a compiler that cannot emit for these cannot be probed, and a probe that cannot measure never prints a pass"
        gate_stamp; return 2
    fi
    _so="$(md5sum "$_root/out/libscrip_rt.so" 2>/dev/null | cut -c1-12)"; _so="${_so:-none}"
    # ⛔ A LEDGER THAT CANNOT BE READ RECORDS, IT NEVER REFUSES. This probe rides the preflight every runner calls, so a
    # corrupt or unreadable out/build_behaviour.sig must not be able to red the whole fleet for a reason that has nothing
    # to do with the class -- awk failing here yields an empty _prev, which is the first-observation path.
    _prev="$(awk -v t="$_ts" '$1==t {print $2; exit}' "$_led" 2>/dev/null)"
    if [ -n "$_prev" ] && [ "$_prev" != "$_bs" ] && [ "${SCRIP_ALLOW_STALE:-}" = 1 ]; then
        # ⭐ THE DECLARED OVERRIDE IS THE ONE THAT ALREADY EXISTS, NOT A SECOND KNOB. SCRIP_ALLOW_STALE already means "I
        # know this binary is not the one this tree describes, grade it anyway", and gate_score_row already refuses to
        # write THE ONE LEADERBOARD for the rest of such a run -- which is exactly the protection a moved build needs.
        # Minting SCRIP_ALLOW_MOVED_BUILD beside it would be a second name for one decision, and the second name is how
        # an operator silences the half they meant to keep.
        _msg="⚠️⚠️ MOVED-BUILD OVERRIDE [${GATE_NAME:-gate}]: SCRIP_ALLOW_STALE=1 -- this binary emits different code than an earlier build of the SAME tree ($_ts: $_prev then, $_bs now). Quote this verdict WITH this line; SCORE.md will NOT be written from this run."
        echo "$_msg"; echo "$_msg" >&2
        gate_stamp
        return 0
    fi
    if [ -n "$_prev" ] && [ "$_prev" != "$_bs" ]; then
        _prevso="$(awk -v t="$_ts" '$1==t {print $3" "$4" "$5; exit}' "$_led" 2>/dev/null)"
        echo "GATE UNPROVEN(2) [${GATE_NAME:-gate}]: ⛔ REFUSES rc=2: THE BINARY MOVED UNDER A TREE THAT DID NOT -- this build was not built from this tree"
        echo "    tree signature   $_ts   (unchanged: the same src/ and Makefile CONTENT as the earlier observation)"
        echo "    behaviour now    $_bs   libscrip_rt.so md5 $_so"
        echo "    behaviour before $_prev   (so-md5 / when / by: $_prevso)"
        echo "    ⛔ One of these two builds did not come from this tree. Do NOT diagnose a source defect and do NOT publish a"
        echo "       board from this binary -- see FINDING-2026-09-09-hq_P: a full diagnosis cycle was spent rediscovering a"
        echo "       defect that was already cured in the checked-out tree, and two SCORE rows were published from the bad build."
        echo "    cure: cd $_root && make pristine   (then re-run; the previous .so is kept under out/attic/ for a byte diff)"
        gate_stamp; return 2
    fi
    mkdir -p "$_root/out" 2>/dev/null
    _now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    if [ -z "$_prev" ]; then
        # A LEDGER BELONGS TO THE CHECKOUT IT DESCRIBES (the coo 2026-10-15): a scratch root's out/ was once a symlink to the real checkout's, and its probe line landed
        # in the REAL ledger mid fan-out (the RACED refusals). No link exists any more (CEO-1820): a staged root copies out/, so the line below lands in the root that was probed.
        printf '%s %s %s %s %s\n' "$_ts" "$_bs" "$_so" "$_now" "${S4E_SEAT:-unknown}" >> "$_led"
        # bounded, and pruned HERE rather than by a cron nobody runs (THE PACE RULES). One line per distinct tree.
        if [ "$(wc -l < "$_led" 2>/dev/null || echo 0)" -gt 400 ] 2>/dev/null; then tail -n 200 "$_led" > "$_led.t" 2>/dev/null && mv -f "$_led.t" "$_led" 2>/dev/null; fi
        echo "build-behaviour probe [${GATE_NAME:-gate}]: RECORDED tree $_ts -> behaviour $_bs (so $_so) -- first observation of this tree, nothing to contradict"
    else
        echo "build-behaviour probe [${GATE_NAME:-gate}]: consistent -- tree $_ts -> behaviour $_bs (so $_so)"
    fi
    return 0
}
# gate_bin_watch <artifact>... / gate_bin_unmoved -- THE BINARY MOVED UNDER THIS BOARD class.
# ⛔⭐ HOISTED FROM test_corpus_snobol4.sh (hq_S 2026-09-06, who measured it and asked for it to live here
# rather than in seven copies). THE MEASURED CASE: hq_S started an 1854-entry board and then ran an
# incremental build while it was still grading. The harness tried to exec the binary mid-relink, died with
# PermissionError, and refused -- WHICH IS THE ONLY REASON ANYONE NOTICED. A second either way and the board
# would have graded half its population on one binary and half on another AND PRINTED A COMPLETE, PLAUSIBLE
# TABLE. Every board that takes minutes has this hazard; the pre-existing board_stamp only compares ACROSS
# shards and only fingerprints scrip.
# ⛔ FINGERPRINT EVERY ARTIFACT THE RUN EXECUTES, AND THE .so IS THE ONE THAT MATTERS: ./scrip links the
# emitter and runtime DYNAMICALLY, so it is BYTE-IDENTICAL across the two arms of any emitter or runtime
# change -- a scrip-only check is vacuous exactly when it matters most. Measured on an emit.cpp A/B where two
# agents verified scrip's md5 as proof the binary had not moved, and the check was empty for the property in
# question. That is why this takes a LIST and the caller names the .so explicitly.
# ⭐ AND THE STRONGER MOVE, WHERE IT IS AFFORDABLE (hq_P): put the change behind a killswitch and run BOTH
# ARMS OFF ONE BUILD, env-only -- that REMOVES the hazard instead of detecting it. This guard is for what a
# killswitch cannot cover: a long board while somebody else, or your own next command, rebuilds underneath it.
# ⛔⭐ IT MUST FINGERPRINT EVERY ARTIFACT OR REPORT THAT IT COULD NOT -- a partial fingerprint is the exact
# defect this guard exists to prevent, one level down inside the guard. Measured while hoisting (hq_T
# 2026-09-06, ARM 3 of the extraction proof): `md5sum present missing 2>/dev/null` still prints a line for
# the one that exists, so a non-empty result was read as "fingerprinted", the missing artifact was silently
# unwatched, and the board ran to a verdict believing it was covered. The donor had the same shape, so this
# would have been vacuous for out/libscrip_rt.so exactly when the .so is the artifact that matters.
# ⭐ THE CHECK IS ARITHMETIC, NOT EMPTINESS: one output line per argument, or refuse. The extraction proof is
# what found it -- re-proving a moved guard on its own arms rather than trusting that a copy behaves.
_gate_bin_fp() {
    local _out _want=$#
    _out="$(md5sum "$@" 2>/dev/null)" || return 1
    [ "$(printf '%s\n' "$_out" | grep -c .)" -eq "$_want" ] || return 1
    printf '%s' "$_out" | cut -c1-12 | tr '\n' ' '
}
gate_bin_watch() {
    GATE_BIN_WATCHED="$*"
    GATE_BIN_FP0="$(_gate_bin_fp "$@")" || GATE_BIN_FP0=""
    # ⛔ REFUSE AT WATCH TIME, not only at check time: a board that could never fingerprint its own artifacts
    # has no baseline to compare against, and discovering that at the END means the whole run was unverifiable
    # and already paid for.
    [ -n "$GATE_BIN_FP0" ] || {
        echo "⛔ REFUSE(rc=2) [${GATE_NAME:-gate}]: could not fingerprint the artifacts this run will grade on ($GATE_BIN_WATCHED)"
        echo "   -- a board that cannot tell whether its binary moved must not print a verdict."
        exit 2; }
}
gate_bin_unmoved() {
    # ⛔ ORDER MATTERS: ask "was anything watched" BEFORE trying to fingerprint it. Measured while proving
    # the extraction (ARM 5): with the checks the other way round, calling this with no prior gate_bin_watch
    # ran md5sum with no arguments, failed, and refused with "an artifact can no longer be fingerprinted ()"
    # -- the right rc for the wrong reason, naming an empty list. rc=2 either way, so nothing would have
    # caught it but reading the message.
    [ -n "${GATE_BIN_FP0:-}" ] || {
        echo "⛔ REFUSE(rc=2) [${GATE_NAME:-gate}]: gate_bin_unmoved called without gate_bin_watch -- there is no baseline, so this cannot answer"
        exit 2; }
    local _now; _now="$(_gate_bin_fp $GATE_BIN_WATCHED)" || {
        echo "⛔ REFUSE(rc=2) [${GATE_NAME:-gate}]: an artifact this board was watching can no longer be fingerprinted ($GATE_BIN_WATCHED)"
        echo "   -- it was deleted or replaced mid-run, which is the moved-binary case in its loudest form."
        exit 2; }
    [ "$_now" = "$GATE_BIN_FP0" ] || {
        echo "⛔ REFUSE(rc=2) [${GATE_NAME:-gate}]: THE BINARY MOVED UNDER THIS BOARD -- start [$GATE_BIN_FP0] end [$_now]"
        echo "   ($GATE_BIN_WATCHED, md5 prefixes, in that order). Part of this population was graded on one build and part on another,"
        echo "   so every number above describes no single tree. Re-run on a quiet tree; do NOT quote this board."
        exit 2; }
}
# gate_tree_watch <sibling-root> / gate_tree_unmoved -- THE CORPUS MOVED UNDER THIS BOARD class, and the
# STAMP that names the tree a row actually graded. ONE CALL, because they are one question asked twice.
#
# ⛔⭐ THE WITNESS IS THE coo's OWN, 2026-09-10 18:42 (COO-54): a board pass recorded corpus 4986354bb at start
# and a background job moved corpus to 2e8b94fe5 EIGHT SECONDS LATER. gate_bin_watch stayed silent and was
# RIGHT to -- the BINARY had not moved. That is the right question for it and the wrong one for this, and
# NOTHING IN THE FLEET ASKED THE OTHER ONE. A board whose corpus moves grades half its population against one
# corpus and half against another and prints a complete, plausible table -- the same shape hq_S measured for
# the binary on 2026-09-06, one repo over.
#
# ⛔ AND THE HALF THAT ALREADY EXISTED ONLY ANNOTATED. util_score_row.py reads S4E_TREE_AT_START and, when HEAD
# moved under the run, writes "graded; HEAD moved to <h> during the run" into the provenance -- an honest
# sentence attached to a number that describes no single tree. ⭐ AN ANNOTATION IS NOT A REFUSAL: the row is
# still published, still checkoutable, still quoted. Worse, only THREE runners ever set that variable, and the
# three Icon PACKAGE boards the one runner runs every hour set NONE of it -- so their rows stamped HEAD AT
# WRITE TIME, which is precisely the defect CEO-524 (1) was raised about, in its second form.
#
# SO THIS SETS THE VARIABLE *AND* REFUSES: gate_tree_watch exports S4E_TREE_AT_START in util_score_row's own
# vocabulary (`SCRIP=<h>,corpus=<h>`), so a caller gets the honest stamp by calling it, and gate_tree_unmoved
# refuses rc=2 before a number is published. ⛔ ONE SPELLING OF THAT STRING, HERE: it was hand-written in three
# runners and absent from the rest, which is how three of four boards came to be unstamped.
#
# ⭐ THE FINGERPRINT INCLUDES UNCOMMITTED STATE, deliberately: `<short-HEAD> <md5 of git status --porcelain>`.
# A ref edited and not committed moves the GRADED DATA without moving HEAD, and that is the likelier accident
# on a seat root than a commit is -- the coo edited corpus refs by hand four times on the day this was written.
# No false positives: a board READS SCRIP and corpus and writes neither. ⛔ .github IS NEVER WATCHED -- the
# board writes SCORE.md and SUITES.tsv itself, so watching it would make every board trip on its own row.
# ⛔ THE SCRIP WATCHED IS THE CHECKOUT THIS LIBRARY LIVES IN (coo 2026-10-08, the class of CEO-1573): every board grades its own
# checkout's scrip, so a board run from a worktree watched <root>/SCRIP -- the directory BESIDE the worktree, by name -- and refused
# "cannot read HEAD" (or, beside a seat root, watched a tree it was not grading). corpus stays <root>/corpus, the caller's root.
_gate_tree_repo() { case "$2" in SCRIP) (cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd);; *) printf '%s/%s\n' "$1" "$2";; esac; }
gate_tree_watch() {
    local _root="$1" _r _h _d _fp="" _p
    for _r in SCRIP corpus; do
        _p="$(_gate_tree_repo "$_root" "$_r")"
        _h="$(git -C "$_p" rev-parse --short HEAD 2>/dev/null)" || _h=""
        [ -n "$_h" ] || {
            echo "⛔ REFUSE(rc=2) [${GATE_NAME:-gate}]: cannot read HEAD of $_p -- a board that cannot tell whether its corpus moved must not print a verdict"
            exit 2; }
        _d="$(git -C "$_p" status --porcelain 2>/dev/null | md5sum | cut -c1-8)"
        _fp="$_fp$_r=$_h/$_d "
        case "$_r" in SCRIP) GATE_TREE_STAMP="SCRIP=$_h";; corpus) GATE_TREE_STAMP="$GATE_TREE_STAMP,corpus=$_h";; esac
    done
    GATE_TREE_ROOT="$_root"; GATE_TREE_FP0="$_fp"
    export S4E_TREE_AT_START="$GATE_TREE_STAMP"
}
gate_tree_unmoved() {
    [ -n "${GATE_TREE_FP0:-}" ] || {
        echo "⛔ REFUSE(rc=2) [${GATE_NAME:-gate}]: gate_tree_unmoved called without gate_tree_watch -- there is no baseline, so this cannot answer"
        exit 2; }
    local _r _h _d _now="" _p
    for _r in SCRIP corpus; do
        _p="$(_gate_tree_repo "$GATE_TREE_ROOT" "$_r")"
        _h="$(git -C "$_p" rev-parse --short HEAD 2>/dev/null)" || _h=""
        [ -n "$_h" ] || {
            echo "⛔ REFUSE(rc=2) [${GATE_NAME:-gate}]: $_p can no longer be read -- it moved or vanished mid-run, which is the moved-tree case in its loudest form"
            exit 2; }
        _d="$(git -C "$_p" status --porcelain 2>/dev/null | md5sum | cut -c1-8)"
        _now="$_now$_r=$_h/$_d "
    done
    [ "$_now" = "$GATE_TREE_FP0" ] || {
        echo "⛔ REFUSE(rc=2) [${GATE_NAME:-gate}]: THE TREE MOVED UNDER THIS BOARD -- start [$GATE_TREE_FP0] end [$_now]"
        echo "   (repo=<HEAD>/<md5 of uncommitted state>). Part of this population was graded against one tree and part against another,"
        echo "   so every number above describes no single tree. Re-run on a quiet tree; do NOT quote this board."
        exit 2; }
}
# gate_and_per_program <graded-total> <mode-A red names> <mode-B red names> -- THE ROW WHEN THE MODES DISAGREE.
# Echoes "<and_pass> <union_count> <union names...>"; returns 2 and echoes nothing if the total is not a number.
#
# ⛔ THE RULE IS ceo CEO-545, ruled 2026-09-10 on the coo's handling: when the two modes disagree the row is the
# AND PER PROGRAM -- a program is green only if BOTH modes are -- the UNION OF REDS IS NAMED, and the per-mode
# numerators are carried BESIDE it, never a single fraction that hides which mode. It supersedes the
# m3-where-they-differ convention retired at ceo-372.
#
# ⛔⭐ IT LIVES HERE BECAUSE TWO RUNNERS GOT IT WRONG IN TWO DIFFERENT DIRECTIONS ON THE SAME PASS (coo,
# 2026-09-10). test_icon_jcon_suite handed util_score_row a --text carrying TWO fractions and the instrument
# REFUSED the write outright, correctly, saying which number the row means is a judgement and not a reading --
# so the row went unwritten. test_icon_arizona_suite did NOT refuse: it passed --suite-pass=$M3_PASS, m3's 84,
# into both halves of a cell whose m4 read 83. ⭐ ONE SILENTLY WRONG AND ONE HONESTLY UNWRITTEN IS THE SAME
# ROOT: neither runner could COMPUTE the number the rule asks for, so each did the best thing available to it.
# Giving them the computation is the cure; asking them to remember the convention is not.
#
# ⛔ REDS ARE COUNTED BY NAME, NEVER BY SUBTRACTING PASS COUNTS. `total - m3_pass - m4_pass` is not the AND and
# is not anything: a program red in BOTH modes would be subtracted twice. The union is what the rule names and
# the union is what this computes -- which is also why the caller must hand over NAMES and not counts.
gate_and_per_program() {
    local _total="$1"; shift
    case "$_total" in ''|*[!0-9]*) return 2;; esac
    local _u _n
    _u="$(printf '%s\n' $* | sed '/^$/d' | LC_ALL=C sort -u)"
    _n="$(printf '%s\n' "$_u" | grep -c .)"
    printf '%s %s %s\n' "$((_total - _n))" "$_n" "$(printf '%s ' $_u)"
}
# gate_floor <examined-count> <minimum> <what-was-counted> -- the empty-glob / empty-dir / zero-files class.
# ⛔⭐ AND IT PRINTS THE POPULATION ON THE PASSING PATH TOO (coo 2026-09-18, on the cto's finding).  The refusal
# was always here; what was missing is that A GATE WITH A FULL POPULATION AND A GATE WITH A NEARLY-EMPTY ONE
# PRINTED THE SAME THING when both cleared the floor, so nothing in the house style forced the denominator into
# the output and a reader could not tell 4851 scanned from 2.  One additive line, so every one of the 52 callers
# states what it actually looked at without changing its own verdict lines.
gate_floor() {
    GATE_EXAMINED="$1"
    if [ "$1" -lt "$2" ] 2>/dev/null; then
        echo "GATE UNPROVEN(2) [$GATE_NAME]: examined $1 $3, floor is $2"
        echo "    Zero-work-examined is indistinguishable from all-clean, so it is refused rather than passed."
        gate_stamp
        exit 2
    fi
    echo "population: examined $1 $3 (floor $2)"
}
# gate_oracle_stdout_match <oracle-stdout-file> <actual-stdout-file> <actual-stderr-file> <actual-rc>
#
# ERROR-IDENTITY NORMALIZER (row conform-unload-noop, hq_C ruling 2026-08-27). x64/bin/sbl prints a full
# abnormal-termination trailer to STDOUT on every uncaught runtime error -- file/line/statement/stmts-
# executed/"memory used (bytes)"/"memory left (bytes)" -- and the memory figures are SPITBOL-internal
# accounting that differs per program (measured: 11880/1036688 on f15_unload vs a different pair on
# f12_load), so no reimplementation can ever reproduce them byte-for-byte. The oracle's own exit code is
# ALSO 0 on this whole class of error (SCRIP's core_runtime_error always exit(1)), and SCRIP reports its
# error on STDERR where the oracle reports on STDOUT. A byte-exact-stdout-plus-exact-rc instrument can
# therefore never pass for a witness the oracle halts on -- a DONE-WHEN shape that cannot mechanically
# succeed, the same defect family as a gate that can never say FAIL, wearing the opposite mask.
#
# RULING: a witness the oracle completed NORMALLY on (no trailer) is graded exactly as before -- byte-
# exact stdout, matched rc -- so this changes nothing for the hundreds of already-passing witnesses. A
# witness the oracle HALTED on is graded on ERROR IDENTITY (the numeric `ERROR nnn` code, wherever each
# side reports it) plus termination status (actual rc != 0), with the genuine pre-error program output
# compared after the oracle's trailer -- and the blank-line padding SPITBOL prints immediately before it
# -- is stripped; command substitution's trailing-newline trim absorbs that padding on both sides.
#
# Returns 0 (match) or 1 (mismatch); prints nothing, same silent contract as the `cmp -s` it replaces.
gate_oracle_stdout_match() {
    local ora="$1" act_out="$2" act_err="$3" act_rc="$4"
    local ora_code
    ora_code="$(sed -n 's/^.*: ERROR \([0-9][0-9]*\) -- .*$/\1/p' "$ora" | head -1)"
    if [ -z "$ora_code" ]; then
        [ "$act_rc" -eq 0 ] && cmp -s "$ora" "$act_out"
        return $?
    fi
    local ora_pre act_pre act_code
    ora_pre="$(sed -n '/: ERROR [0-9][0-9]* -- /q; p' "$ora")"
    act_pre="$(cat "$act_out")"
    [ "$ora_pre" = "$act_pre" ] || return 1
    [ "$act_rc" -ne 0 ] || return 1
    act_code="$(sed -n 's/^\*\* Error \([0-9][0-9]*\) in statement.*$/\1/p' "$act_err" | head -1)"
    [ -n "$act_code" ] || return 1
    [ "$((10#$ora_code))" -eq "$((10#$act_code))" ]
}
# gate_verdict <violation-count> <what-was-violated> -- the computed verdict.  Never declared.
gate_verdict() {
    if [ "${1:-0}" -ne 0 ] 2>/dev/null; then
        echo "GATE FAIL(1) [$GATE_NAME]: $1 $2 (examined ${GATE_EXAMINED:-?})"
        gate_stamp
        [ "$GATE_STRICT" = "1" ] && exit 1
        echo "    (--informational: exiting 0 despite the failure above)"
        exit 0
    fi
    echo "GATE PASS(0) [$GATE_NAME]: 0 $2 (examined ${GATE_EXAMINED:-?})"
    gate_stamp
    exit 0
}
# s4e_seat_name -- THE ONE SEAT IDENTITY, for any runner that needs to name itself outside a SCORE.md
# stamp (a banner, a receipt filename, a log line).  Echoes the name, rc=0; on an unrecognised root it
# echoes NOTHING and returns 2, so a caller cannot silently bake a guess into an artifact.
#
# ⛔ IT IS A CALL SHAPE, NOT A SECOND COPY -- the same rule gate_score_row lives under.  The root->seat map
# is already carried in three hand-synced places (s4e_msg.sh, s4e_inbox_hook.sh, util_score_row.py's
# derive_measurer); spelling a fourth in bash is how the fourth one drifts.  So this delegates to the helper
# and must never grow a `case "$root" in` of its own.  test_gate_seat_identity_one_map.sh pins the copies.
#
# ⛔ NOT NEEDED FOR --measurer.  Runners pass `--measurer "${S4E_SEAT:-}"` and the helper resolves an empty
# one itself; that path is already single-sourced and needs no call-site change.  Use this only where bash
# genuinely needs the string.
s4e_seat_name() {
    local _py _out _rc
    _py="$(dirname "${BASH_SOURCE[0]}")/util_score_row.py"
    [ -f "$_py" ] || return 2
    _out="$(python3 "$_py" seat-name 2>/dev/null)"; _rc=$?
    [ "$_rc" -eq 0 ] && [ -n "$_out" ] || return 2
    printf '%s\n' "$_out"
    return 0
}
# gate_score_row <lang> <column> <text> [modes] [suite] -- THE ONE LINE A BASH RUNNER ADDS to satisfy the
# ONE-LEADERBOARD FACT RULE (Lon 2026-09-03 ~16:05: "any run of a test suite by any session will update
# the ONE LEADERBOARD").  Delegates to ../harness/scripts/util_score_row.py, which is the single implementation --
# this is a call shape, not a second copy, and must never grow logic of its own.  Measurer defaults to
# $S4E_SEAT because a row nobody signed is a claim with nobody behind it.
#
# ⛔ IT IS DELIBERATELY NON-FATAL TO THE GATE THAT CALLS IT, AND THAT IS NOT A LOOPHOLE.  A runner's job
# is to grade its suite; if the leaderboard write fails (dirty .github, a renamed column, a read-only
# checkout) the MEASUREMENT is still valid and must still be printed.  Turning a bookkeeping failure
# into a red board would make runners stop calling this, which is how the duty dies.  So it WARNS
# loudly and names the un-recorded row -- the operator then records it by hand, exactly as the FACT
# RULE's interim clause already requires.  What it must never do is fail SILENTLY, so there is no path
# here that returns 0 without either writing the row or printing why it did not.
# ⛔⭐ THE 5th ARGUMENT, `suite`, EXISTS BECAUSE THE WRAPPER WAS FORCING RUNNERS TO CHOOSE BETWEEN THE
# SANCTIONED CALL SHAPE AND A CORRECT CELL (seat14, 2026-09-05, measured on icon's vendor column).  Several
# vendor suites share ONE cell -- icon's V column carries JCON and Arizona -- and util_score_row.py's
# --suite is what lets them coexist as two NAMED sub-measurements inside it.  This wrapper did not pass it,
# so a runner that used the wrapper OVERWROTE its neighbour's number, and the two runners that noticed had
# to bypass the wrapper to stay correct.  ⭐ A convenience wrapper that cannot express a distinction the
# underlying tool has does not simplify the call -- it silently narrows what the caller can say, and the
# caller who obeys it loses data while the caller who ignores it is right.  Pass it through; a runner
# writing a whole cell simply omits it, exactly as before.
gate_score_row() {
    local _lang="$1" _col="$2" _text="$3" _modes="${4:-}" _suite="${5:-}" _crit="${6:-}" _py _out _rc
    # ⛔ A DELIBERATE STALE RUN NEVER REACHES THE LEADERBOARD (row harness-and-ladder-runner-refuse-on-a-stale-binary-like-
    # the-artifact-regen-does, hq_T 2026-09-04): SCRIP_ALLOW_STALE=1 is the operator's own declaration that this run's
    # binary currency was NOT enforced, and a SCORE.md row stamps the tree's hash on whatever number it carries. Checked on
    # the operator's env rather than on a flag from gate_require_fresh because every runner reaches that function through
    # util_require_fresh.sh, a subprocess, whose exports never come back -- and because the declaration, not the outcome,
    # is what makes the row untrustworthy: a run that MIGHT have graded an old binary is not evidence about the tree either.
    if [ "${SCRIP_ALLOW_STALE:-}" = 1 ]; then
        echo "⚠ SCORE.md NOT UPDATED [$GATE_NAME]: stale-binary override in effect (SCRIP_ALLOW_STALE=1) -- a leaderboard row stamps a tree hash, and this run's binary was not held to that tree. The measurement stands as a deliberate stale run only: $_lang / $_col = $_text"
        return 0
    fi
    _py="$(dirname "${BASH_SOURCE[0]}")/util_score_row.py"
    if [ ! -f "$_py" ]; then
        echo "⚠ SCORE.md NOT UPDATED [$GATE_NAME]: no util_score_row.py at $_py -- record $_lang/$_col by hand: $_text"
        return 0
    fi
    _out="$(python3 "$_py" write --lang "$_lang" --column "$_col" --text "$_text" \
            --measurer "${S4E_SEAT:-}" ${_modes:+--modes "$_modes"} ${_suite:+--suite "$_suite"} \
            ${_crit:+--criterion-changed "$_crit"} 2>&1)"; _rc=$?
    if [ "$_rc" -ne 0 ]; then
        echo "⚠ SCORE.md NOT UPDATED [$GATE_NAME] (rc=$_rc) -- the measurement below stands, the leaderboard row does not:"
        echo "$_out" | sed 's/^/    /'
        echo "    record it by hand: $_lang / $_col = $_text"
        return 0
    fi
    echo "$_out" | sed 's/^/    /'
    return 0
}

# gate_progress_line -- print THE ONE PROGRESS LINE after a row rewrite (Lon 2026-09-03 ~20:15: "each of
# the 7 main runners display a score of percentage in a banner ... just to see a progress indicator of any
# kind").  Lives HERE, beside gate_score_row, for the same reason gate_score_row does: this is the single
# shared write path, so wiring the progress line into it reaches every runner that records a row without
# putting a seventh copy of the same three lines into seven runners.  ⛔ NON-FATAL, like its neighbour --
# a reporting line must never be able to turn a measured board red.
gate_progress_line() {
    # ⛔ DELETED ON LON'S WORD 2026-09-13 ("All bogus. Delete that. Do not show that ever again.").
    # Kept as a no-op so any caller still works; it prints nothing and is no longer called from
    # gate_score_row above. See cmd_progress in util_score_row.py for what it printed and why it went.
    return 0
}
# gate_three_way <label> <rc> <out> <extract-pattern> -- THE ABSENT-LINE PRIMITIVE (row
# a-refusal-reported-in-the-vocabulary-of-a-red-absent-line-read-as-unparseable, seat15/hq_T 2026-09-05).
#
# THE DEFECT THIS EXISTS TO KILL: a consumer runs another gate/board, captures its output, and greps for
# one summary line -- then folds the line's ABSENCE into the same vocabulary as a MEASURED result: a bare
# `${x:-0}` that prints a false-clean board, an `${x:-UNPARSEABLE}` that reads a kill as a parse defect,
# or a hard `fail()` that reads a kill as a code regression. All three hand the reader a sentence about
# the CODE that is really a sentence about the MACHINE (a per-program timeout under fleet load, an outer
# kill, a crash) -- an instrument answering a narrower question than the reader thinks they asked, and
# never saying so. Witness: test_corpus_snobol4.sh KILLED 4 programs at its 120s bound under load 3.6 (a
# COULD-NOT-MEASURE, which that script itself already reports honestly, rc=2) and a consumer read the
# resulting absence as "FAIL m3=UNPARSEABLE" -- a sentence about zd_omega_head that was really a sentence
# about the box being busy.
#
# THE RULE: exactly one of the sub-run's own exit code and its printed text is trustworthy at a time.
#   rc==2   -- this codebase's OWN fixed vocabulary (see THE THREE EXIT CODES, top of this file) for "the
#              sub-run refused, and already explained why". ALWAYS propagate as UNPROVEN, no matter what
#              text happens to be sitting in $out -- a script that refuses can still have echoed partial
#              numbers before its refusal, and partial numbers are not a verdict.
#   rc==124 -- killed by an outer `timeout` wrapper. UNPROVEN: the sub-run never got to conclude.
#   rc>128  -- killed by a signal (rc-128). UNPROVEN, same reason.
#   else    -- the sub-run concluded under its own steam (ordinarily rc 0 or 1): look for
#              <extract-pattern> in $out. FOUND -> print the matched line, return 0 (present -- green or
#              red is for the CALLER to judge from the line's own fields, exactly as before this helper
#              existed). NOT FOUND -> still UNPROVEN: a format change or a crash that produced no summary
#              is not evidence about the code under test either.
#
# On UNPROVEN it prints NOTHING to stdout (so a caller that forgets to check the return code gets an
# empty string, never a manufactured number) and writes the real cause plus the sub-run's own last lines
# -- often an honest inner refusal already explaining itself -- to stderr, then returns 2.
#
# CALLER CONTRACT: check the return code before trusting the captured line, e.g.:
#     line=$(gate_three_way "label" "$rc" "$out" 'PATTERN'); grc=$?
#     [ "$grc" -eq 2 ] && { report_unproven ...; } || { ...use "$line"...; }
# Treating a return of 2 as "keep going with an empty $line" reintroduces the exact defect this helper
# exists to close.
gate_three_way() {
    local _label="$1" _rc="$2" _out="$3" _pat="$4" _line _cause
    if [ "$_rc" -eq 2 ] 2>/dev/null; then
        _cause="the sub-run REFUSED (rc=2, this codebase's own UNPROVEN code) -- not a verdict about the code under test"
    elif [ "$_rc" -eq 124 ] 2>/dev/null; then
        _cause="TIMED OUT (killed by an outer timeout wrapper, rc=124) -- unmeasured, not a hang/pass verdict"
    elif [ "$_rc" -gt 128 ] 2>/dev/null; then
        local _sig=$((_rc - 128)) _signame
        _signame="$(kill -l "$_sig" 2>/dev/null || echo "$_sig")"
        _cause="KILLED by SIG${_signame} (rc=$_rc) -- unmeasured, not a verdict about the code under test"
    else
        _line="$(printf '%s\n' "$_out" | grep -m1 -E "$_pat" 2>/dev/null)"
        if [ -n "$_line" ]; then printf '%s\n' "$_line"; return 0; fi
        _cause="ran to completion (rc=$_rc) but never printed a line matching the expected shape -- a format change or a crash with no summary"
    fi
    {
        echo "GATE UNPROVEN(2) [${GATE_NAME:-gate}]: $_label -- $_cause"
        echo "    what was actually seen (last 12 lines of $_label's own output):"
        printf '%s\n' "$_out" | tail -12 | sed 's/^/    /'
    } >&2
    return 2
}
# gate_file_executes_scrip <file> -- rc=0 when the file INVOKES the compiled binary, rc=1 when it does not.
# gate_file_has_fresh_guard  <file> -- rc=0 when the file reaches the staleness preflight (either spelling).
#
# ⛔⭐ THESE TWO ARE AN EXTRACTION, NOT A NEW IDEA, AND THAT IS THE WHOLE REASON THEY ARE HERE.  The predicate
# lived inline in ARM 15 of test_gate_runners_refuse_on_a_stale_binary.sh, where it answered the FLEET-WIDE
# question ("has anyone landed a scrip-executing gate without the guard").  util_gate_preflight.sh asks the
# SAME question about ONE file, before the push -- and the one thing this lane has measured over and over is
# that the second copy is where the cure stops arriving (gate_require_fresh vs assert_binary_current: cured in
# one, regenerated in the other, cured again nine days later).  A per-file tool that re-spelled the population
# rule would disagree with the census on the first gate whose shape sits near the boundary, and the seat would
# be told "clean" by one instrument and "uncovered" by the other on the same file.
#
# THE POPULATION RULE, unchanged from ARM 15: a call-shaped reference to the compiled binary -- a $SCRIP /
# $SCRIP_BIN-style variable actually INVOKED as a command, not merely assigned, not tested with -x/-e/-f, not
# echoed into a message -- OR an inline $ROOT/scrip / $HERE/scrip invocation with no intermediate variable.
# Comments are stripped first: a gate that DESCRIBES the binary in its header is not a gate that runs it, and
# a textual arm that cannot tell those apart reports red on files whose only sin is documentation.
# ⛔⭐ SINGLE-QUOTED SPANS ARE STRIPPED TOO, FOR THE SAME REASON COMMENTS ARE: TEXT ABOUT THE BINARY IS NOT A RUN
# OF IT (hq_B 2026-09-13, on the cto's re-aim of the freshness census under hq_R's row). Measured -- exactly two
# files in the whole gate population carried $SCRIP ONLY inside single quotes, and NEITHER executes anything:
# test_gate_mint_refuses_a_prose_donewhen.sh feeds '"$SCRIP" --run w.icn | grep -q ok' to `mint` as a CRITERION
# STRING to prove mint accepts it, and test_gate_boards_refuse_when_the_binary_moves.sh has '\$SCRIP' inside a
# grep -lE PATTERN it uses to find copies in other files. Both were named by census #2 as gates executing scrip
# with no freshness guard.
# ⛔⛔ AND THE FALSE POSITIVE WAS NOT MERELY NOISE -- ITS "CURE" WOULD HAVE DAMAGED THE TREE. The named file is a
# PREFLIGHT arm, and `make preflight` is the CHEAP HERMETIC NO-BUILD target whose own recipe says in as many
# words that the missing `scrip` prerequisite is the entire point and must not be added. Adding the freshness
# stanza it was being asked for would make preflight REFUSE rc=2 on any stale binary and destroy the one target
# a seat can run without building. ⭐ A census that names work items must be right about the population, because
# a wrongly named item is not ignored -- it is FIXED, by someone trusting the instrument, and the fix is the
# damage. That is a sharper cost than a wrong number and it is the reason this narrowing is worth the risk below.
# ⛔ THE RISK, NAMED, BECAUSE NARROWING A DETECTOR CAN ONLY CREATE FALSE NEGATIVES: stripping quoted spans could
# in principle exempt a real executor that happens to invoke through a single-quoted construct. Measured against
# the whole population before landing -- 268 gates in census #2, exactly the two above change classification,
# and the second already CARRIES the guard, so no covered gate loses its coverage and the floor (>=50) is
# untouched at 266. Re-measure this the same way if the detector is ever widened again.
gate_file_executes_scrip() {
    local _f="$1" _body _ln
    [ -f "$_f" ] || return 1
    _body="$(grep -vE '^[[:space:]]*#' "$_f" | sed "s/'[^']*'//g")"
    if grep -qE '\$\{?SCRIP(_BIN)?\}?\b' <<<"$_body"; then
        while IFS= read -r _ln; do
            grep -qE '\$\{?SCRIP(_BIN)?\}?\s*=' <<<"$_ln" && continue
            grep -qE '\[\[?[[:space:]]+-[a-zA-Z][[:space:]]+"?\$\{?SCRIP(_BIN)?\}?"?' <<<"$_ln" && continue
            grep -qE '(echo|printf)[^$]*\$\{?SCRIP(_BIN)?\}?' <<<"$_ln" && continue
            grep -qE '\$\{?SCRIP(_BIN)?\}?\b' <<<"$_ln" && return 0
        done <<<"$_body"
    fi
    grep -qE '"?\$(ROOT|HERE)"?/scrip\b' <<<"$_body" && return 0
    return 1
}
# gate_file_has_fresh_guard <file> -- 0 the file calls the staleness preflight · 1 it demonstrably does not · 2 COULD NOT
# MEASURE. ⛔⭐ THREE-VALUED ON PURPOSE, AND THE THIRD VALUE IS THE POINT (hq_T 2026-09-09): this decides whether a census
# ACCUSES a named file of a violation, and an accusation sourced from a read that did not happen is a false RED -- the
# mirror of the false GREEN this whole family of gates exists to kill, and worse to meet, because the reader goes and
# edits a file that was never wrong.
# THE MEASURED CASE: ARM 15 of test_gate_runners_refuse_on_a_stale_binary.sh reported `uncovered=1
# test_gate_pl_gz6b.sh`, then on a re-run `uncovered=2 test_gate_capture_stdin_and_red_exit.sh
# test_gate_icn_port_trace.sh` -- THREE DIFFERENT FILES ACROSS TWO RUNS, every one of them carrying the shim call on its
# own LINE 1. Ten other runs of the identical loop over the identical 140 files reported uncovered=0.
# ⭐⭐ THE MECHANISM, PROVEN 2026-09-09 AFTER THIS COMMENT FIRST SAID IT WAS UNFOUND: SIGPIPE, turned into a verdict by
# `set -o pipefail`. `grep -q` exits the instant it matches -- and the guard call is the FIRST non-comment line in 93 of
# the 144 gates -- so the kernel tears down the read end while the upstream `grep -vE` may not yet have been scheduled to
# finish writing. That write returns EPIPE, the upstream dies 141, pipefail makes 141 the pipeline's status, and the
# function reports "no guard". MEASURED: the old body over 2712 calls at box load 21 produced 11 false negatives, EVERY
# ONE exit 141; this body over the same 2712 calls at the same load produced 0.
# ⛔⭐ AND THE FIRST ANALYSIS RULED SIGPIPE OUT, WRONGLY, WHICH IS THE MORE USEFUL HALF OF THIS COMMENT. The reasoning
# was: every candidate file is under 5KB stripped, far inside the 64KB pipe buffer, so the upstream can always complete
# its write. That is true and irrelevant -- THE BUFFER PREVENTS BLOCKING, NOT EPIPE. Whether the upstream finishes before
# the reader exits is a SCHEDULING race, not a capacity question, and it is a race only load can open: a tight 500-call
# loop on a quiet box reproduced it zero times, which is exactly what made the wrong conclusion feel measured.
# ⭐ THE LESSON, which outlives this function: an experiment that cannot reproduce a rare race is not evidence the race
# is absent, and "I measured it" is not the same claim as "I measured it under the conditions where it happens". The
# first analysis had the right instinct (the pipeline is the only structural difference from the sibling that never
# flaked) and then talked itself out of it with a capacity argument about a timing bug.
# THE COST OF THE DELAY, so nobody repeats it: THREE seats reported false work items from this -- hq_T's own ARM 15 runs,
# the coo's make-test report, and hq_R's, which the ceo turned into a ruling (CEO-462) directing a cure to
# test_gate_pl_gz5c.sh, a file that has carried the guard on line 3 since 2026-09-05. Four innocent files accused.
# gate_file_has_bin_watch_guard <file> -- 0 the file watches its artifacts for a MID-RUN swap and checks them
# before it publishes, 1 it does not, 2 unreadable.  ⛔ THE POPULATION RULE FOR ceo CEO-524 (1) LIVES HERE AND
# NOWHERE ELSE, for the same reason gate_file_has_fresh_guard does: a census that re-spells its own rule is a
# second copy, and the copy is what drifts.  THREE CONDITIONS, and the third is the one that matters -- the
# defect this grades is not a missing check, it is a check that fires AFTER the number is already on the page:
#   1  the file calls gate_bin_watch                      (a baseline was taken)
#   2  the file calls gate_bin_unmoved                    (the baseline is compared)
#   3  the FIRST gate_bin_unmoved precedes the FIRST line that publishes a count -- an echo of a *_BOARD line,
#      or a util_score_row.py / gate_score_row write.  A board with no such line publishes nothing and passes 3
#      vacuously, which is correct: there is nothing to be too late for.
# Comment lines are stripped before every read, so a file that merely NAMES the guard in prose does not pass.
# gate_file_has_tree_watch_guard <file> -- the SAME three conditions gate_file_has_bin_watch_guard grades,
# asked about the TREE pair instead of the artifact pair (coo 2026-09-10, COO-54).  ⛔ A SEPARATE FUNCTION AND
# NOT A PARAMETER, deliberately: the two guards answer different questions -- did the BINARY move, did the
# CORPUS move -- and a board can carry one and lack the other, which is exactly the state every board was in
# until this landed.  Folding them into one predicate would let a board pass by carrying either.
gate_file_has_tree_watch_guard() {
    local _body _rc _u _pub
    [ -f "$1" ] || return 2
    [ -r "$1" ] || return 2
    _body="$(grep -vE '^[[:space:]]*#' "$1")"; _rc=$?
    [ "$_rc" -gt 1 ] && return 2
    grep -qE 'gate_tree_watch' <<<"$_body" || return 1
    grep -qE 'gate_tree_unmoved' <<<"$_body" || return 1
    _u="$(grep -nE 'gate_tree_unmoved' <<<"$_body" | head -1 | cut -d: -f1)"
    _pub="$(grep -nE 'echo "[A-Z0-9_]*BOARD |util_score_row\.py|gate_score_row' <<<"$_body" | head -1 | cut -d: -f1)"
    [ -n "$_pub" ] || return 0
    [ -n "$_u" ] || return 1
    [ "$_u" -lt "$_pub" ] 2>/dev/null || return 1
    return 0
}
gate_file_has_bin_watch_guard() {
    local _body _rc _w _u _pub
    [ -f "$1" ] || return 2
    [ -r "$1" ] || return 2
    _body="$(grep -vE '^[[:space:]]*#' "$1")"; _rc=$?
    [ "$_rc" -gt 1 ] && return 2
    grep -qE 'gate_bin_watch' <<<"$_body" || return 1
    grep -qE 'gate_bin_unmoved' <<<"$_body" || return 1
    _u="$(grep -nE 'gate_bin_unmoved' <<<"$_body" | head -1 | cut -d: -f1)"
    _pub="$(grep -nE 'echo "[A-Z0-9_]*BOARD |util_score_row\.py|gate_score_row' <<<"$_body" | head -1 | cut -d: -f1)"
    [ -n "$_pub" ] || return 0
    [ -n "$_u" ] || return 1
    [ "$_u" -lt "$_pub" ] 2>/dev/null || return 1
    return 0
}
gate_file_has_fresh_guard() {
    local _body _rc
    [ -f "$1" ] || return 2
    [ -r "$1" ] || return 2
    _body="$(grep -vE '^[[:space:]]*#' "$1")"; _rc=$?
    [ "$_rc" -gt 1 ] && return 2
    grep -qE 'gate_require_fresh|util_require_fresh\.sh' <<<"$_body" && return 0
    # ⛔ CONFIRM BEFORE ACCUSING. A second independent read costs a millisecond and is the difference between "this file
    # has no guard" and "one read said so once". They disagree -> REFUSE, never accuse.
    # ⛔⭐ THE CONFIRM READ MUST APPLY THE SAME RULE, NOT A LOOSER ONE. This line first read the RAW file, comments and
    # all -- which re-measured a DIFFERENT question, so a gate that merely MENTIONS the preflight in a comment while
    # calling it nowhere would have read 2 (could not measure) instead of 1 (violation), and ARM 15 would have refused
    # rc=2 instead of naming a genuinely guilty file. Caught before it shipped by the coo naming two real violations
    # (test_gate_pl_arith_iso_errors_are_catchable.sh, test_gate_sno_terminal_read_fails_without_a_tty.sh, both since
    # cured at origin) while this function was being written. ⭐ A confirmation that asks an easier question is not a
    # confirmation -- it is a second instrument agreeing with nothing, and it fails in the direction that hides work.
    _body="$(grep -vE '^[[:space:]]*#' "$1")"; _rc=$?
    [ "$_rc" -gt 1 ] && return 2
    grep -qE 'gate_require_fresh|util_require_fresh\.sh' <<<"$_body" && return 2
    return 1
}


# ---------------------------------------------------------------------------------------------------------
# ⛔⭐ STAGING A PICKER WITH A PINNED LANE TABLE, FOR THE POSTOFFICE GATES WHOSE SUBJECT IS A MECHANISM AND
# NOT THE LIVE LANE CUT (COO-80, 2026-09-19, row instrument-the-nineteen-non-gc-blocking-arms; the shape ceo
# CEO-953 directed: cure the SCENARIO, not the lane table).
# THE PROBLEM THESE SOLVE. The picker's language->owner map is a baked `case` inside s4e_msg.sh. Two gates in
# make test-postoffice grade mechanisms that need a table with a PARTICULAR SHAPE -- two distinct lanes for
# test_gate_next_honours_the_lane_cut, and an hq_* lane beside an officer lane for
# test_gate_s4e_next_any_lane_fallback_refuses_a_seat_with_no_language. Every mode that gives all seven
# languages to one seat (CEO, TRIO, QUARTET today) dissolves both scenarios, and both gates then REFUSE rc=2
# and take the whole target down with them -- which is how make test-postoffice came to be one of the
# twenty-three blocking arms that left every seat without a landing gate (CEO-944). Both gates were RIGHT to
# refuse rather than lower their bar, and right not to be cured by editing the live table; what they were
# missing is the ability to build the one part of their scenario they could not write themselves.
# ⛔ THIS IS NOT A FIXTURE RESTATING ITS SUBJECT'S FACTS. It pins the table needed to EXERCISE a mechanism;
# the mechanism itself -- the lane filter, the promotion path, the language freeze, the owns-a-language test
# -- is the real one, unmodified, in the staged copy. WHETHER THE LIVE TABLE IS CORRECT is a different gate's
# subject: it is compared to MODE line 2 language by language elsewhere, and that comparison is deliberately
# not restated by any caller of this helper.
# ⛔ AND IT IS PROVEN, NEVER ASSUMED: the rewrite returns 3 when the function it means to replace is not
# found (renamed or moved) and 4 when the staged copy does not read its pinned owners back. A staging that
# silently failed would grade the LIVE table and report the result as a defect in the mechanism.

# gate_lane_owner_of <picker> <language> -- the owner the picker's own table names, read out of the file.
gate_lane_owner_of() {
    bash -c '. /dev/stdin <<<"$(sed -n "/^s4e_lane_languages()/,/^s4e_lane_help()/p" "$1")"; s4e_lane_owner_of_language "$2"' _ "$1" "$2" 2>/dev/null
}

# gate_lane_languages <picker> -- the language list the picker's own table carries.
gate_lane_languages() {
    bash -c '. /dev/stdin <<<"$(sed -n "/^s4e_lane_languages()/,/^s4e_lane_help()/p" "$1")"; s4e_lane_languages' _ "$1" 2>/dev/null
}

# gate_stage_picker_lane_table <sut> <out> <default_owner> [<lang>=<owner>]...
# rc 0 staged and read back · 3 the table function was not found in <sut> · 4 the staged copy does not read
# its pinned owners back · other: the rewrite itself failed.
gate_stage_picker_lane_table() {
    local _sut="$1" _out="$2" _default="$3"; shift 3
    local _arms="" _pair _l _o _rc
    for _pair in "$@"; do
        _l="${_pair%%=*}"; _o="${_pair#*=}"
        _arms="$_arms $_l) printf '$_o';;"
    done
    local _fn="s4e_lane_owner_of_language() { case \"\$1\" in$_arms *) printf '$_default';; esac; }"
    awk -v fn="$_fn" '
        /^s4e_lane_owner_of_language\(\) \{/ { print fn; skip = 1; found = 1; next }
        skip && /^\}/ { skip = 0; next }
        !skip { print }
        END { if (!found) exit 3 }
    ' "$_sut" > "$_out"; _rc=$?
    [ "$_rc" -eq 0 ] || return "$_rc"
    chmod +x "$_out" 2>/dev/null
    # ⛔⭐⭐ THE LIBS GO WITH IT, because a staged bus resolves `dirname "${BASH_SOURCE[0]}"` to the SCRATCH
    # directory and finds nothing beside it. This was survivable while the missing libs carried only optional
    # helpers -- lib_release_guard.sh has been printing "No such file or directory" into these fixtures for as
    # long as they have existed, and nobody read it because the arms still passed. It stopped being survivable
    # on 2026-09-23, when THE DONE-WHEN EXTRACTOR MOVED INTO lib_donewhen.sh (cto's ruling: one implementation)
    # and the bus began REFUSING rc=2 without it rather than warning: nine of ten arms in
    # test_gate_next_honours_the_lane_cut.sh went red at once, none of them about the lane cut. ⭐ STAGING THEM
    # IS THE FIX RATHER THAN SOFTENING THE REFUSAL: a bus that cannot read a criterion must not pretend it can,
    # and a fixture is supposed to be the real script in a scratch tree, not a partial one.
    cp "$(dirname "$_sut")"/lib_*.sh "$(dirname "$_out")"/ 2>/dev/null || return 5
    for _pair in "$@"; do
        _l="${_pair%%=*}"; _o="${_pair#*=}"
        [ "$(gate_lane_owner_of "$_out" "$_l")" = "$_o" ] || return 4
    done
    [ "$(gate_lane_owner_of "$_out" __no_such_language__)" = "$_default" ] || return 4
    return 0
}

# ---------------------------------------------------------------------------------------------------------
# ⛔⭐ A POSTOFFICE FIXTURE MUST NOT HARDCODE THE MODE IT RUNS ITS SEATS UNDER (COO-80, 2026-09-19, row
# instrument-the-nineteen-non-gc-blocking-arms). THE FAILURE THIS CLOSES, measured today:
# test_gate_s4e_next_honours_owner.sh writes `DUO` into its scratch MODE and grades the OWNER COLUMN with two
# HQ seats. On 2026-09-19 DUO gained a stand-down arm for every HQ (CEO-907), so the picker began REFUSING TO
# DISPATCH both of its seats and seven of its nine arms went red -- not one of them about the owner column,
# which is the gate's entire subject. The mode string was incidental to what it grades and it became load-
# bearing without anyone choosing that. A fixture whose seats are stood down is not measuring its subject.
# ⭐ SO THE MODE IS CHOSEN BY PROBING THE PICKER, NOT BY BELIEF: each candidate is written into the scratch
# postoffice and `next` is run for the seat with an EMPTY queue, which claims nothing; the first mode under
# which the seat is not refused dispatch is the one the fixture uses. When no candidate admits the seat the
# caller REFUSES rc=2 and says so, which is a real finding about the stand-down table rather than a fixture
# quietly grading nothing.
# ⛔ CALL IT BEFORE MINTING ROWS: it truncates the scratch QUEUE.tsv as part of probing.

# gate_pick_dispatchable_mode <sut> <post> <seat>[,<seat>...] <candidate-mode>...
# prints the first candidate mode under which EVERY named seat is NOT refused dispatch; rc 1 when none is.
# ⛔ A fixture that drives two kinds of identity must name both: a mode standing EITHER of them down empties
# the scenario just as thoroughly as one standing down the only seat, and the FLEET seats and the HQs are
# refused by different arms of the same table (seat* is refused in every consolidated mode, hq_* in CEO, DUO,
# TRIO, QUARTET, SEXTET and EXECUTIVE), so the two constraints genuinely differ.
gate_pick_dispatchable_mode() {
    local _sut="$1" _post="$2" _seats="$3"; shift 3
    local _m _out _s _ok
    for _m in "$@"; do
        printf '%s\n' "$_m" > "$_post/MODE"
        _ok=1
        for _s in $(printf '%s' "$_seats" | tr ',' ' '); do
            : > "$_post/QUEUE.tsv"
            _out="$(S4E_POST="$_post" S4E_SEAT="$_s" S4E_RELEASE_COOLDOWN=0 bash "$_sut" next 2>&1)"
            case "$_out" in *"REFUSING TO DISPATCH"*) _ok=0; break ;; esac
        done
        [ "$_ok" = 1 ] || continue
        printf '%s' "$_m"
        return 0
    done
    return 1
}
