#!/usr/bin/env bash
# util_regen_prolog_bench_s_artifacts.sh — regenerate the mode-4 (--compile x86)
# .s artifact beside every benchmark .pl in corpus/benchmarks/prolog/bench.
#
# Mirrors util_regen_benchmark_s_artifacts.sh (SNOBOL4). Per RULES.md the .s is
# the HONEST CURRENT compiler output, never a pinned golden:
#   - a program that compiles to real x86 -> its .s is (re)written and, if the
#     bytes changed, committed.
#   - a program still FENCED by pl_gz_admit (no codegen yet) -> NO .s; instead a
#     one-line <name>.s.FENCED marker records the frontier honestly. When the
#     ladder admits that shape, the regen replaces the marker with a real .s.
#   - an assembler-rejected .s is left flagged, not silently committed.
# scrip --compile is deterministic, so an unchanged compiler yields no change.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"
B="${BENCH_DIR:-$S4E/corpus/benchmarks/prolog/bench}"
RUNG="${1:-prolog-bench-regen}"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED-TO-GRADE scrip not built"; exit 2; }
[ -d "$B" ] || { echo "⛔ REFUSED-TO-GRADE bench corpus missing: $B"; exit 2; }
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT   # PER-INVOCATION scratch: /tmp/regen_{cerr,aserr}.$$ was PID-keyed (safe) but the .s temps escaped on SIGKILL; one dir under the trap covers both (s169 seat2 FINDING §7.5)
changed=0; fenced=0; rejected=0; emitted=0; timedout=0; errored=0; refused=0; oversize=0
OVERSIZE_BYTES="${OVERSIZE_BYTES:-99000000}"
for pl in "$B"/*.pl; do
  s="${pl%.pl}"; base=$(basename "$s"); tmp="$(mktemp -p "$TMPD")"
  # Capture via REDIRECT-TO-TEMP (not command-substitution): a shell pipe `$(...)` can truncate bursty multi-KB asm
  # under load — the documented transient empty-emit. Redirecting straight to a file is the robust sibling pattern
  # (util_regen_benchmark/feature/demo all do this) and removes the flap at the source.
  (cd "$B" && timeout -k 5 30 "$SCRIP" --compile --target=x86 "$base.pl" </dev/null >"$tmp" 2>"$TMPD/cerr"); rc=$?   # from the bench dir by bare name: the .file directive stays "zebra.pl", never this seat's root (a second seat's regen would churn every file)
  if grep -qE '^\s*\.(intel_syntax|text|globl)' "$tmp"; then
    emitted=$((emitted+1))
    if as --64 -o /dev/null "$tmp" 2>"$TMPD/aserr"; then
      sz=$(stat -c %s "$tmp")
      if [ "$sz" -gt "$OVERSIZE_BYTES" ]; then
        # ⛔ OVERSIZE (hq_prolog 2026-10-11): GitHub refuses a file over 100 MB (GH001, pre-receive), so an honest .s that large can
        # never be committed -- measured: chat_parser.s 114 MB, unify.s 102 MB, queens_clpfd.s 141 MB. The marker names the size, as
        # .s.FENCED names a fence; the .s returns when the emitted code shrinks under the limit.
        rm -f "$tmp" "$s.s" "$s.s.FENCED" "$s.s.REFUSED"; oversize=$((oversize+1))
        printf 'OVERSIZE: the honest .s is %s bytes, over the %s-byte limit this repository can hold (GitHub refuses a file over 100 MB)\n' "$sz" "$OVERSIZE_BYTES" > "$s.s.OVERSIZE"
        echo "  OVERSIZE $base ($sz bytes) -> $base.s.OVERSIZE"; continue
      fi
      if [ ! -f "$s.s" ] || ! cmp -s "$tmp" "$s.s"; then mv "$tmp" "$s.s"; chmod 644 "$s.s"; changed=$((changed+1)); echo "  WROTE $base.s"; else rm -f "$tmp"; fi
      rm -f "$s.s.FENCED" "$s.s.REFUSED" "$s.s.OVERSIZE"
    else
      rm -f "$tmp"; rejected=$((rejected+1)); echo "  REJECTED-BY-AS $base (left untouched)"
    fi
  elif grep -q '\[PL-GZ FENCE\]' "$TMPD/cerr"; then
    # GENUINE fence: the compiler RAN and pl_gz_admit rejected the shape (positive evidence in stderr). Only HERE is the
    # destructive delete of an existing .s legitimate — replace it with the honest FENCED marker.
    rm -f "$tmp"; fenced=$((fenced+1)); rm -f "$s.s"
    printf 'FENCED by pl_gz_admit — no codegen yet (%s)\n' "$(grep -oE 'pl_gz_admit[^"]*' "$TMPD/cerr" | head -1 | cut -c1-70)" > "$s.s.FENCED"
    echo "  FENCED $base -> $base.s.FENCED"
  elif grep -q 'is not on the ladder yet' "$TMPD/cerr"; then
    rm -f "$tmp"; refused=$((refused+1)); rm -f "$s.s"
    printf 'REFUSED by the construct ladder -- no codegen until its rung lands (%s)\n' "$(grep -oE '[a-z /-]*is not on the ladder yet -- rung [0-9]+ lands it' "$TMPD/cerr" | head -1 | cut -c1-110)" > "$s.s.REFUSED"
    echo "  REFUSED $base -> $base.s.REFUSED"
  elif [ "$rc" -eq 124 ]; then
    # TIMEOUT (the destructive-delete bug this guard fixes): the compile was KILLED, not fenced. NEVER delete the .s on a
    # timeout — a flaky 30s contention spike must not erase a good artifact. Leave it untouched and flag loudly.
    rm -f "$tmp"; timedout=$((timedout+1)); echo "  TIMEOUT $base (compile exceeded 30s — .s LEFT UNTOUCHED, NOT fenced)"
  else
    # No asm, no fence marker, no timeout = a crash/error. Also non-destructive: preserve the .s and flag for a human.
    rm -f "$tmp"; errored=$((errored+1)); echo "  ERROR $base (no asm + no fence signal, rc=$rc — .s LEFT UNTOUCHED)"
  fi
done
echo "regen[$RUNG]: emitted=$emitted changed=$changed fenced=$fenced refused=$refused rejected=$rejected timedout=$timedout errored=$errored oversize=$oversize"
if [ "$timedout" -ne 0 ] || [ "$errored" -ne 0 ]; then
  echo "WARNING: $timedout timed out + $errored errored — their .s were PRESERVED (re-run, or compile standalone). A timeout is NOT a fence."
fi
# THE COMMIT BLOCK its five siblings all had and this script did not (s169 seat2 FINDING ⭐§3): it WROTE 19 .s and
# committed none, so any seat that ran it and then filtered `git status` to its own lane left them unstaged — a silent
# contributor to the five-week drift on this very tree. Pathspec is DERIVED from $B, not hardcoded, so a BENCH_DIR
# override outside the corpus repo declines to commit instead of committing the wrong tree.
CORPUS="${CORPUS:-$S4E/corpus}"
REL="${B#"$CORPUS"/}"
if [ "$REL" = "$B" ] || ! git -C "$CORPUS" rev-parse --git-dir >/dev/null 2>&1; then
  echo "  SKIP commit — $B is not inside the corpus git repo ($CORPUS); regenerated .s left in the worktree."
else
  cd "$CORPUS" || exit 1
  git add -- "$REL" 2>/dev/null || true
  if git diff --cached --quiet -- "$REL" 2>/dev/null; then
    echo "  No changes — prolog bench .s artifacts already current."
  else
    git -c user.name="LCherryholmes" -c user.email="lcherryh@yahoo.com" \
        commit -q -m "prolog bench x86 .s artifacts: $RUNG" -- "$REL"
    echo "  Committed:"; git show --stat --oneline HEAD | tail -2
  fi
fi
