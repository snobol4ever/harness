#!/usr/bin/env bash
# util_regen_benchmark_s_artifacts.sh — regenerate the mode-4 (--compile) x86 .s
# artifact for every SNOBOL4 benchmark, placed side-by-side with its .sno source
# in corpus/benchmarks/snobol4/, and commit ONLY the artifacts whose bytes actually changed.
#
# Run before handoff on any session that touches codegen, i.e. any of:
#   src/emitter/emit_bb.c, src/emitter/emit_core.c, src/templates/{bb,xa}/*.cpp,
#   src/emitter/x86_asm.h, src/lower/lower_snobol4.c, or the runtime sinks they call.
#
# The .s is the honest current compiler output: a benchmark whose codegen still
# bombs an unimplemented shape emits a loud bomb stub INTO the .s (it still
# assembles); when the gap is later closed the .s changes and is recommitted.
# scrip --compile is deterministic, so re-running with an unchanged compiler
# produces byte-identical .s and yields NO commit (idempotent).
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"
CORPUS="${CORPUS:-$S4E/corpus}"
BENCH="${BENCH_DIR:-$CORPUS/benchmarks/snobol4}"

if [ ! -x "$SCRIP" ];  then echo "SKIP  scrip not built: $SCRIP"; exit 0; fi
if [ ! -d "$BENCH" ];  then echo "SKIP  benchmark corpus not found: $BENCH"; exit 0; fi
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT   # PER-INVOCATION scratch: /tmp/bench_<name>.* is program-keyed, so two seat roots regenerating at once collide on EVERY program (s169 seat2 FINDING §7.5)

cd "$BENCH"
fail=0
echo "Emitting benchmark .s artifacts (mode-4 --compile)..."
for sno in *.sno; do
    s="${sno%.sno}"
    if timeout -k 5 30 "$SCRIP" --compile "$sno" > "$TMPD/bench_$s.s" 2>/dev/null < /dev/null && [ -s "$TMPD/bench_$s.s" ]; then
        if gcc -c "$TMPD/bench_$s.s" -o "$TMPD/bench_$s.o" 2>"$TMPD/bench_$s.aserr"; then
            mv "$TMPD/bench_$s.s" "$s.s"
            echo "  OK    $s.s"
        else
            echo "  AS-FAIL $s.s (assembler rejected; NOT updated): $(head -1 "$TMPD/bench_$s.aserr")"
            fail=1
        fi
    else
        echo "  EMIT-FAIL $s.s (empty/crash; NOT updated)"
        fail=1
    fi
done

echo "Committing changed artifacts to corpus..."
cd "$CORPUS"
# ⛔ THE PATHSPEC NAMES THIS DIRECTORY'S .s ARTIFACTS AND NOTHING ELSE (ceo 2026-09-25, CEO-1266). It read "git add benchmarks/*.s"
# and "commit -- benchmarks": git's * crosses slashes, and a commit with a pathspec takes the WORKING-TREE state of every
# tracked file under it, so any edited kernel source was committed under this script's "artifacts" message -- which is how
# the 2026-08-23 rewrite of every SNOBOL4 kernel into a function landed with no message of its own (corpus cbc2df66e).
REL="${BENCH#"$CORPUS"/}"
git add -- "$REL/*.s" 2>/dev/null || true
if git diff --cached --quiet -- "$REL/*.s" 2>/dev/null; then
    echo "  No changes — benchmark .s artifacts already current."
else
    RUNG="${1:-regen}"
    git -c user.name="LCherryholmes" -c user.email="lcherryh@yahoo.com" \
        commit -q -m "benchmark x86 .s artifacts: $RUNG" -- "$REL/*.s"
    echo "  Committed:"; git show --stat --oneline HEAD | sed -n '1,40p'
fi

echo "Done.$([ "$fail" -ne 0 ] && echo '  (one or more benchmarks did not produce a clean .s — see above.)')"
exit "$fail"
