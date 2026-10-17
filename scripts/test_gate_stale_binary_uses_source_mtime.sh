#!/usr/bin/env bash
# test_gate_stale_binary_uses_source_mtime.sh -- THE ACCEPTANCE GATE for gate_require_fresh's staleness basis
# (row stale-binary-refusal-compares-against-the-head-commit-time-not-the-newest-tracked-source, hq_B measured
# 2026-09-03, ceo ruled, cured seat02 2026-09-04).
#
# WHAT IT PROVES, in BOTH directions, hermetically, in a throwaway git sandbox (never touches the real tree):
#   ARM 1 "committed after building" -- the ORDINARY order of work (build, grade, THEN commit): a binary newer
#     than every tracked src/+Makefile file, followed by a LATER, unrelated commit that moves HEAD's own commit
#     time past the binary -- must PASS. Before this row's cure it WRONGLY REFUSED: a commit's %ct is when it
#     was AUTHORED, not when its content was last edited, so committing source you had already built moved HEAD
#     past a binary that had not gone stale by a single byte (measured on the ICN4 landing: binary 00:16Z,
#     newest tracked src 00:15Z -- correctly current -- HEAD commit 00:25Z -> REFUSED anyway).
#   ARM 2 "genuinely stale" -- a tracked src/ file touched AFTER the binary was built (never rebuilt since) --
#     must STILL REFUSE, both before and after the cure. A guard that only ever passes is the false-green it
#     exists to prevent (RULES.md THE INSTRUMENT LAWS): this is the control arm proving the cure did not also
#     delete the guard's actual job.
#   ARM 3 "Makefile-only edit" -- the cure's own added scope (the task named `git ls-files` under src/ + Makefile,
#     and the pre-cure code never looked at Makefile at all) -- a Makefile touched after the build must ALSO
#     still be caught.
#
# ⛔ HERMETIC AND NON-DESTRUCTIVE: every arm runs inside a throwaway `git init` sandbox under mktemp, with
# explicit `touch -d`/`GIT_COMMITTER_DATE` timestamps -- never sleeps, never touches this repo's own src/ or
# history. gate_require_fresh is SOURCED from the real lib_gate.sh (SUT= overrides for fail-once proof against a
# pre-cure copy), so this gate tests the actual production function, not a reimplementation of it.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="${SUT:-$HERE/lib_gate.sh}"
[ -f "$SUT" ] || { echo "⛔ REFUSED-TO-GRADE: script under test not found: $SUT"; exit 2; }
command -v git >/dev/null 2>&1 || { echo "⛔ REFUSED-TO-GRADE: git not on PATH"; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/gate_stale_bin_src.XXXXXX")" || { echo "⛔ REFUSED-TO-GRADE: mktemp failed"; exit 2; }
trap 'rm -rf "$WORK"' EXIT

fails=0; checks=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }

# call_gate <sandbox-root> <binary...> -- runs gate_require_fresh from the REAL lib_gate.sh in a clean
# subprocess (it calls `exit`, so it must never run in THIS shell) and prints its own stdout+stderr, then RC=<n>.
call_gate() {
    local root="$1"; shift
    local bins=("$@")
    bash -c 'source "'"$SUT"'" || exit 3; gate_require_fresh "$@"' _ "$root" src "${bins[@]}"
    echo "RC=$?"
}

mk_sandbox() {   # builds a fresh throwaway repo: src/a.c + Makefile, committed at 2020-01-01T00:00:00
    rm -rf "$WORK/repo"; mkdir -p "$WORK/repo/src" "$WORK/repo/docs"
    ( cd "$WORK/repo" \
      && git init -q \
      && git config user.name test && git config user.email test@test.local \
      && echo 'int a;' > src/a.c && echo 'all:' > Makefile \
      && git add -A \
      && GIT_AUTHOR_DATE="2020-01-01T00:00:00" GIT_COMMITTER_DATE="2020-01-01T00:00:00" git commit -q -m init )
    touch -d "2020-01-01T00:00:00" "$WORK/repo/src/a.c" "$WORK/repo/Makefile"
}

echo "=== gate: gate_require_fresh compares a binary against tracked src/+Makefile mtimes, never HEAD's commit time ==="

echo "--- ARM 1: build, THEN a later unrelated commit lands (ordinary order of work) -> must PASS ---"
mk_sandbox
: > "$WORK/repo/scrip"; touch -d "2020-01-01T00:05:00" "$WORK/repo/scrip"   # "build" -- 5 min after source
( cd "$WORK/repo" && echo hi > docs/readme.txt && git add -A \
  && GIT_AUTHOR_DATE="2020-01-01T00:10:00" GIT_COMMITTER_DATE="2020-01-01T00:10:00" git commit -q -m "later, unrelated commit" )
out="$(call_gate "$WORK/repo" "$WORK/repo/scrip")"; rc="$(grep -oP 'RC=\K[0-9]+' <<<"$out")"
[ "$rc" = 0 ] && ck ok "binary newer than source, older than HEAD's LATER commit -> PASS (rc=$rc)" \
              || ck no "must PASS (binary genuinely current); got rc=$rc -- $out"
grep -qi "HEAD's own commit" <<<"$out" \
    && ck no "⛔ refusal still names HEAD's commit time as a cause -- the buggy basis is still live" \
    || ck ok "refusal text never cites HEAD's commit time as a cause"

echo "--- ARM 2: a tracked src/ file is genuinely edited AFTER the binary was built (never rebuilt) -> must REFUSE ---"
mk_sandbox
: > "$WORK/repo/scrip"; touch -d "2020-01-01T00:05:00" "$WORK/repo/scrip"
touch -d "2020-01-01T00:20:00" "$WORK/repo/src/a.c"   # edited after the build, no rebuild yet
out="$(call_gate "$WORK/repo" "$WORK/repo/scrip")"; rc="$(grep -oP 'RC=\K[0-9]+' <<<"$out")"
[ "$rc" = 2 ] && ck ok "binary older than a freshly-edited tracked source file -> REFUSE (rc=$rc)" \
              || ck no "must REFUSE (binary genuinely stale); got rc=$rc -- $out"
grep -qi 'tracked source' <<<"$out" && ck ok "refusal names the real cause (tracked source, not HEAD)" \
                                     || ck no "refusal must name the tracked-source cause"

echo "--- ARM 3: a Makefile-only edit after the build is ALSO caught (the cure's own added scope) ---"
mk_sandbox
: > "$WORK/repo/scrip"; touch -d "2020-01-01T00:05:00" "$WORK/repo/scrip"
touch -d "2020-01-01T00:20:00" "$WORK/repo/Makefile"
out="$(call_gate "$WORK/repo" "$WORK/repo/scrip")"; rc="$(grep -oP 'RC=\K[0-9]+' <<<"$out")"
[ "$rc" = 2 ] && ck ok "binary older than a freshly-edited Makefile -> REFUSE (rc=$rc)" \
              || ck no "a stale-vs-Makefile case must still REFUSE; got rc=$rc -- $out"

echo "------------------------------------------------------------"
if [ "$fails" -ne 0 ]; then echo "⛔ GATE FAIL: $fails of $checks check(s) failed"; exit 1; fi
echo "✅ GATE PASS: $checks/$checks checks"; exit 0
