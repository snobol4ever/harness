#!/usr/bin/env bash
# test_gate_no_symlinks.sh -- NO SYMBOLIC LINK WE CREATE, EVER (Lon 2026-10-17, in-chat to the ceo, verbatim: "Do not EVER use symlinks.
# Remove all symlink everywhere found in anywhere." · "Use proper absolute and relative paths for things." · "You guarantee the all repos are
# siblings at the same level in their root folder. done and done."; ceo CEO-1820. Lon 2026-10-21, verbatim: "Get all those symlinks removed.
# We do not use symlinks anywhere for the snobol4ever organization." · "Do not worry about symlink that are apart of pacakges. I am concerned
# only with ones we create." · "In general, do not mess with /home/resources folder if the layout is as intended by the authors of the content
# in those folders."; ceo CEO-1853).
#
# ARM 1 (blocking): every git repo beside this one in the root -- SCRIP, corpus, harness, .github and any port repo -- tracks ZERO
#        symbolic links (git ls-files -s mode 120000).
# ARM 2 (blocking): SCRIP's Makefile creates no symlink (no `ln -s`).
# ARM 3 (blocking, ceiling 0): no code we write creates a symlink (`ln -s`, `cp -s`, `os.symlink`, `symlink_to`) -- harness/scripts,
#        .github/scripts and corpus, shell and Python, comment lines excepted.
# ARM 4 (blocking): this root's own tree holds no symlink on disk, tracked or not (.git internals excepted): a stale build's
#        out/libscrip_rt.so link, a refs/ link, a scratch tree's link to a sibling all count.
# ARM 5 (blocking): the top level of /home/resources holds no symlink. That level is ours (each entry a tree we placed); the links
#        INSIDE a package's own tree (an install's lib*.so aliases, a build system's links, a vendored repo's layout) are the
#        authors' and this gate never reads them.
# rc 0 green · rc 1 red · rc 2 could not measure (no sibling repos found, or /home/resources absent).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
RES=/home/resources
LN_CEILING=0
fail=0; repos=0
for g in "$ROOT"/*/.git "$ROOT"/.github/.git; do
    [ -d "$g" ] || continue
    r="$(dirname "$g")"; repos=$((repos+1))
    n="$(git -C "$r" ls-files -s 2>/dev/null | awk '$1=="120000"' | wc -l)"
    if [ "$n" = 0 ]; then echo "  ok   $(basename "$r") tracks no symlink"
    else echo "  RED  $(basename "$r") tracks $n symlink(s):"; git -C "$r" ls-files -s | awk '$1=="120000"{print "         " $4}' | head -5; fail=1; fi
done
[ "$repos" -ge 3 ] || { echo "⛔ REFUSE(2): fewer than three sibling repos under $ROOT -- the root layout is not the guaranteed one"; exit 2; }
[ -d "$RES" ] || { echo "⛔ REFUSE(2): $RES is absent -- the resources sibling of every root is part of the guaranteed layout"; exit 2; }
if [ -f "$ROOT/SCRIP/Makefile" ]; then
    if grep -nE '\bln +-[A-Za-z]*s' "$ROOT/SCRIP/Makefile" >/dev/null; then echo "  RED  SCRIP/Makefile creates a symlink"; fail=1
    else echo "  ok   SCRIP/Makefile creates no symlink"; fi
fi
sites=0
for d in "$HERE" "$ROOT/.github/scripts" "$ROOT/corpus"; do
    [ -d "$d" ] || continue
    hits="$(grep -rnE '\bln +-[A-Za-z]*s|\bcp +-[A-Za-z]*s|os\.symlink|symlink_to' --include='*.sh' --include='*.py' "$d" 2>/dev/null | grep -v '/test_gate_no_symlinks.sh:' | grep -vE ':[0-9]+:\s*#')"
    [ -n "$hits" ] || continue
    sites=$((sites + $(printf '%s\n' "$hits" | wc -l)))
    printf '%s\n' "$hits" | head -5 | cut -c1-200 | sed 's/^/         /'
done
if [ "$sites" -gt "$LN_CEILING" ]; then echo "  RED  $sites code site(s) create a symlink, above the ceiling $LN_CEILING"; fail=1
else echo "  ok   $sites code site(s) create a symlink (ceiling $LN_CEILING)"; fi
onroot="$(find "$ROOT" -path '*/.git' -prune -o -type l -print 2>/dev/null)"
if [ -z "$onroot" ]; then echo "  ok   no symlink on disk under $ROOT"
else echo "  RED  $(printf '%s\n' "$onroot" | wc -l) symlink(s) on disk under $ROOT:"; printf '%s\n' "$onroot" | head -5 | sed 's/^/         /'; fail=1; fi
top="$(find "$RES" -mindepth 1 -maxdepth 1 -type l 2>/dev/null)"
if [ -z "$top" ]; then echo "  ok   no symlink at the top level of $RES"
else echo "  RED  $(printf '%s\n' "$top" | wc -l) symlink(s) at the top level of $RES:"; printf '%s\n' "$top" | head -5 | sed 's/^/         /'; fail=1; fi
[ "$fail" = 0 ] && { echo "GATE OK [test_gate_no_symlinks]: $repos repos track no symlink; no link we create on disk"; exit 0; }
echo "GATE FAIL [test_gate_no_symlinks]"; exit 1
