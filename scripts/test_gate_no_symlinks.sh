#!/usr/bin/env bash
# test_gate_no_symlinks.sh -- NO SYMBOLIC LINK, EVER (Lon 2026-10-17, in-chat to the ceo, verbatim: "Do not EVER use symlinks. Remove all
# symlink everywhere found in anywhere." · "Use proper absolute and relative paths for things." · "You guarantee the all repos are
# siblings at the same level in their root folder. done and done."; ceo CEO-1820).
#
# ARM 1 (blocking): every git repo beside this one in the root -- SCRIP, corpus, harness, .github and any port repo -- tracks ZERO
#        symbolic links (git ls-files -s mode 120000).
# ARM 2 (blocking): SCRIP's Makefile creates no symlink (no `ln -s`).
# ARM 3 (ratchet): the code in harness/scripts that still creates a symlink (`ln -s`, `cp -s`, `os.symlink`, `symlink_to`) may only
#        fall: its count is held at LN_CEILING below and the gate reds if it rises. Lower the ceiling in the landing that cures a site.
# rc 0 green · rc 1 red · rc 2 could not measure (no sibling repos found).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
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
if [ -f "$ROOT/SCRIP/Makefile" ]; then
    if grep -nE '\bln +-[A-Za-z]*s' "$ROOT/SCRIP/Makefile" >/dev/null; then echo "  RED  SCRIP/Makefile creates a symlink"; fail=1
    else echo "  ok   SCRIP/Makefile creates no symlink"; fi
fi
sites="$(grep -rnE '\bln +-[A-Za-z]*s|\bcp +-[A-Za-z]*s|os\.symlink|symlink_to' --include='*.sh' --include='*.py' "$HERE" 2>/dev/null | grep -v '/test_gate_no_symlinks.sh:' | grep -vE ':[0-9]+:\s*#' | wc -l)"
if [ "$sites" -gt "$LN_CEILING" ]; then echo "  RED  $sites code site(s) in harness/scripts create a symlink, above the ceiling $LN_CEILING"; fail=1
else echo "  ok   $sites code site(s) still create a symlink (ceiling $LN_CEILING, may only fall)"; fi
[ "$fail" = 0 ] && { echo "GATE OK [test_gate_no_symlinks]: $repos repos track no symlink"; exit 0; }
echo "GATE FAIL [test_gate_no_symlinks]"; exit 1
