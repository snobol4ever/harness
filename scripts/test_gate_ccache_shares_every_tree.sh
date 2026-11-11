#!/usr/bin/env bash
# test_gate_ccache_shares_every_tree.sh -- EVERY TREE THAT BUILDS SCRIP SHARES ONE COMPILER CACHE (the coo, 2026-11-11; Lon 16:1x-16:2x CST, in the coo's window:
# "Can YOU fix the sharing problem? Can the root folders share objects or NOT?" / "Will you update the scripts to this properly. Do not depend on your FEEBLE
# mind." / "How about relative versus absolute path names" / "Make them SIBLINGS").
# MEASURED 2026-11-11: SCRIP/Makefile exported CCACHE_BASEDIR=/home while 42 seat worktrees built under /tmp/s4e, so no worktree shared one object with any other
# tree, and the cache sat full at 30 of 30 GB with 45 percent misses. A scratch pair at different depths read 0 of 2 hits with base /home, 0 of 2 with base /
# (it also rewrites /usr/include, the implicit stdc-predef.h, relative to the tree), and 1 of 2 with each tree's own root as its base: the four repos SCRIP,
# harness, corpus and .github are siblings under it, so every path inside a tree is relative and every path outside it stays absolute.
# ARMS. (1) the base the Makefile gives this tree is the parent of its SCRIP (make --eval, the effective value). (2) behaviour: two scratch trees at different
# paths and depths under /tmp/s4e, each asking the same Makefile (-f, ROOT set to the scratch SCRIP) for its base, compile one file in a private cache; the
# second compile is a hit. rc 0 GREEN; rc 1 RED naming the arm; rc 2 REFUSE (no ccache, no gcc, no make, no Makefile, no base). S4E_CCACHE_GATE_MAKEFILE names
# another Makefile (the control arm: SCRIP 3db54604c, base /home, reads RED on both arms).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
MK="${S4E_CCACHE_GATE_MAKEFILE:-$S4E/SCRIP/Makefile}"
for t in ccache gcc make; do command -v "$t" > /dev/null 2>&1 || { echo "REFUSE(2) [test_gate_ccache_shares_every_tree]: no $t on PATH"; exit 2; }; done
[ -r "$MK" ] && [ -d "$S4E/SCRIP" ] || { echo "REFUSE(2) [test_gate_ccache_shares_every_tree]: cannot read $MK or $S4E/SCRIP"; exit 2; }
base_of() { ( cd "$1" && timeout -k 5 60 make -s --no-print-directory -f "$MK" ROOT="$1" --eval='s4e-print-ccbase: ; @echo "$$CCACHE_BASEDIR"' s4e-print-ccbase < /dev/null 2> /dev/null ) | tail -1; }
red=""
here_base="$(base_of "$S4E/SCRIP")"
[ -n "$here_base" ] || { echo "REFUSE(2) [test_gate_ccache_shares_every_tree]: the Makefile gave this tree no CCACHE_BASEDIR"; exit 2; }
[ "$here_base" = "$(cd "$S4E/SCRIP/.." && pwd)" ] || red="$red arm1:base=$here_base-is-not-the-tree-root-$(cd "$S4E/SCRIP/.." && pwd)"
mkdir -p /tmp/s4e/"${S4E_SEAT:-gate}" 2> /dev/null
T="$(mktemp -d /tmp/s4e/"${S4E_SEAT:-gate}"/ccshare.XXXXXX)" || { echo "REFUSE(2) [test_gate_ccache_shares_every_tree]: mktemp failed"; exit 2; }
trap 'rm -rf "$T"' EXIT
A="$T/a/SCRIP"; B="$T/deeper/tree-b/SCRIP"
mkdir -p "$A/src" "$B/src" "$T/cache"
printf '#include "h.h"\n#include <stdio.h>\nint f(int x) { return x + K; }\n' > "$A/src/f.c"
printf '#define K 3\n' > "$A/src/h.h"
cp "$A/src/f.c" "$A/src/h.h" "$B/src/"
cc_in() { local b; b="$(base_of "$1")"; [ -n "$b" ] || return 2
          ( cd "$1" && CCACHE_DIR="$T/cache" CCACHE_BASEDIR="$b" CCACHE_NOHASHDIR=true timeout -k 5 60 ccache gcc -g -O0 -fdebug-prefix-map="$1"=. -I"$1/src" -c "$1/src/f.c" -o "$1/f.o" < /dev/null ); }
cc_in "$A" > /dev/null 2>&1 || { echo "REFUSE(2) [test_gate_ccache_shares_every_tree]: the scratch compile failed in $A"; exit 2; }
cc_in "$B" > /dev/null 2>&1 || { echo "REFUSE(2) [test_gate_ccache_shares_every_tree]: the scratch compile failed in $B"; exit 2; }
hits="$(CCACHE_DIR="$T/cache" ccache --print-stats 2> /dev/null | awk -F'\t' '$1 == "direct_cache_hit" || $1 == "preprocessed_cache_hit" {s += $2} END {print s + 0}')"
[ "$hits" -ge 1 ] || red="$red arm2:two-scratch-trees-at-different-depths-shared-$hits-of-2-compiles"
tree="$(git -C "$S4E/SCRIP" rev-parse --short HEAD 2> /dev/null || echo unknown)"
echo "CCACHE_SHARE_BOARD this_tree_base=$here_base scratch_pair_hits=$hits/2 (tree $tree)"
[ -z "$red" ] && { echo "GATE OK [test_gate_ccache_shares_every_tree]: each tree's base is its own root, and two trees at different depths share one compile"; exit 0; }
echo "GATE FAIL [test_gate_ccache_shares_every_tree]:$red"; exit 1
