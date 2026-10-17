#!/bin/bash
# ONE-STEP RAKUDO ORACLE DRIVER (hq_S 2026-09-12, row raku-absorb-every-owed-source-into-the-one-master).
# resolve_oracle_bin()/run_oracle() in corpus_suite_harness.py invoke every oracle as a SINGLE process:
# `<oracle_bin> <flags...> <bare-filename>`, cwd already set to the source file's own directory. Rakudo IS
# one-step, so unlike fpc_oracle_run.sh this wrapper adds no compile half -- it exists for ONE reason: the
# self-timed benchmark kernels call wall_us()/wall_ms(), which are SCRIP BUILTINS, and the Rakudo arm gets
# them from prelude_rakudo.rakumod via -I/-M. The kernels say so in their own header comments, and three
# scripts already invoke rakudo exactly this way (bench_triangulate_raku.sh:140, bench_raku_fixed_iter.sh:69,
# test_bench_raku_timed.sh:82) -- this is that same established invocation reached through run_oracle's
# single-process contract, not a fourth spelling of it.
# ⛔⭐ WHY THIS IS NOT OPTIONAL POLISH, MEASURED: without the prelude, rakudo refuses the kernel at COMPILE
# time ("Undeclared routines: wall_ms"), which is rc=1 with EMPTY STDOUT -- and the builder's empty-output
# guard reads that as "oracle produced EMPTY output -- a vacuous ref is worse than none" and EXCLUDES the
# program. So a missing -M does not announce itself as a missing flag; it launders itself into a plausible
# per-program exclusion reason and moves four genuinely gradeable programs out of the denominator forever.
# Their refs are deterministic and already correct (point_class_add "6500001.5 9500002.5", string-escape
# "2000", send-more-money-loops "9567 + 1085 == 10652") because the kernels print TIMINGS TO STDERR via
# note() and only the deterministic result to stdout. A WRONG EXCLUSION COSTS MORE THAN A WRONG CURE: a red
# stays visible, an excluded name cannot be red (hq_V, standing practice 2026-09-10).
# ⛔ THE PRELUDE IS STAGED, NEVER USED IN PLACE: rakudo writes precompilation artifacts beside a -I directory,
# and the corpus is not a Rakudo output directory (bench_triangulate_raku.sh:42 made this ruling first).
# A source with no prelude beside it runs bare -- passing -M for a module that is not there would fail every
# ordinary tests/raku source, so the flag is added only when the file is actually present.
set -u
work=$(mktemp -d) || exit 127
trap 'rm -rf "$work"' EXIT
flags=()
while [ $# -gt 1 ]; do flags+=("$1"); shift; done
src="$1"
[ -f "$src" ] || { echo "raku_oracle_run.sh: no such file: $src" >&2; exit 127; }
raku=$(. "$(dirname "$0")/lib_oracle_flags.sh" && rakudo_bin) || exit 127
if [ -f prelude_rakudo.rakumod ]; then
    mkdir -p "$work/prelude" || exit 127
    cp prelude_rakudo.rakumod "$work/prelude/" || exit 127
    exec "$raku" -I"$work/prelude" -Mprelude_rakudo "${flags[@]+"${flags[@]}"}" "$src"
fi
exec "$raku" "${flags[@]+"${flags[@]}"}" "$src"
