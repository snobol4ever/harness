#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_raku_bar.sh -- THE RAKU SPEED ROW'S CRITERION (ceo CEO-1283, 2026-09-26; the Raku twin of bench_prolog_bar.sh): ONE kernel under
# corpus/benchmarks/raku, the bare multiple Rakudo time / SCRIP mode-4 time (RULES.md FACT RULE, CEO-1242) against a bar, read from the three-angle
# harness bench_triangulate_raku.sh (angle 3's self-measured WORK inside the kernel's bracket, best of REPS, the two timed angles' cross-proof
# required to AGREE on both arms; every rep byte-verified against the .ref; the kernel under its declared -d/-s sidecars) for the one kernel, in
# ONE run -- no board, no row written. The bar is the reference implementation, Rakudo: Raku has no native compiler on the box (RULES.md x-factor
# rule, THE REFERENCE IS THE COMPILER).
#   kernel K BAR       K is the kernel's file stem (string-escape, point_class_add, ...). A kernel whose arm is UNVERIFIED, whose cross-proof
#                      reads DISAGREE or UNPROVEN on either arm, or that carries no bracket, REFUSES: no multiple over an uncited reading.
#                      BAR_MODE=m3 grades mode 3 instead of mode 4.
# EXIT 0 at or above the bar (GREEN), 1 below it (RED, the row is open), 2 REFUSED (no binary, no rakudo, no citable reading).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
refuse() { echo "⛔ bench_raku_bar REFUSE(2): $*"; exit 2; }
[ $# -ge 3 ] && [ "$1" = kernel ] || { echo "usage: $0 kernel <stem> <bar>"; exit 2; }
NAME=$2; BAR=$3; MODE="${BAR_MODE:-m4}"
[ -x "$ROOT/scrip" ] || refuse "no ./scrip (make first)"; . "$HERE/lib_oracle_flags.sh" 2>/dev/null || refuse "cannot load lib_oracle_flags.sh"; rakudo_bin > /dev/null || refuse "rakudo absent"
T=$(mktemp -d) || refuse "mktemp"; trap 'rm -rf "$T"' EXIT
( cd "$ROOT" && KERNELS="$NAME" OUT_TSV="$T/w.tsv" TRI_TSV="$T/t.tsv" CHECK_SHAPE=1 bash ../harness/scripts/bench_triangulate_raku.sh ) > "$T/log" 2>&1
[ -s "$T/w.tsv" ] || { tail -4 "$T/log" | cut -c1-160; refuse "the harness wrote no work-time record for $NAME"; }
read -r rw rv rc <<<"$(awk -F'\t' -v k="$NAME" '$1==k && $2=="rakudo" {print $4, $9, $13}' "$T/w.tsv" | head -1)"
read -r mw mv mc <<<"$(awk -F'\t' -v k="$NAME" -v m="$MODE" '$1==k && $2==m {print $4, $9, $13}' "$T/w.tsv" | head -1)"
for v in "$rw" "$mw"; do case "$v" in ''|-|*[!0-9]*) grep -E "^$NAME " "$T/log" | head -3 | cut -c1-160; refuse "$NAME has no verified work reading on rakudo and $MODE ($rw / $mw)";; esac; done
[ "$rv" = VERIFIED ] && [ "$mv" = VERIFIED ] || refuse "$NAME: an arm is UNVERIFIED (rakudo $rv, $MODE $mv) -- a wrong or missing answer is never a fast answer"
[ "$rc" = AGREE ] && [ "$mc" = AGREE ] || refuse "$NAME: the cross-proof reads $rc on rakudo and $mc on $MODE -- only AGREE is citable"
awk -v r="$rw" -v m="$mw" -v bar="$BAR" -v k="$NAME" -v mode="$MODE" 'BEGIN{x=r/m; printf "kernel %s: rakudo %.0f us of work, %s %.0f us (angle 3, best of REPS, both cross-proofs AGREE); reads %.3fx rakudo in mode %s (bar %.2fx): %s\n", k, r, mode, m, x, substr(mode,2), bar, (x>=bar)?"GREEN":"RED"; exit (x>=bar)?0:1}'
