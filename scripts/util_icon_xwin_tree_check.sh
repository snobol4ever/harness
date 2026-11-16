#!/usr/bin/env bash
# util_icon_xwin_tree_check.sh [SCRIP_ROOT] -- THE VENDORED WINDOW TREE'S OWN CHECK (skill icon reference.md section 9: a gate holds src/runtime/xwin equal to generated plus patch, and nobody edits it; the cto 09:2x CST 2026-11-16, officer_07).
# Regenerates Arizona's tree from the oracle's sources by util_gen_icon_xwin_device.py and compares it byte for byte with SCRIP_ROOT/src/runtime/xwin (default $S4E_SCRIP), with --syntax and --link-census.
# rc 0 EQUAL; rc 1 the tree differs from generated plus patch (the files named) or the generator failed; rc 2 REFUSE: no SCRIP root, no src/runtime/xwin in it, or the generator refused.
# One board line: XWIN_TREE_BOARD ... ending CHECK OK or CHECK FAIL.
set -u
. "${S4E_HARNESS:-/home/harness}/scripts/lib_paths.sh" || { echo "REFUSE(2): lib_paths.sh did not load"; exit 2; }
root="${1:-${S4E_SCRIP:-}}"
[ -n "$root" ] || { echo "REFUSE(2): no SCRIP root (give one, or set S4E_SCRIP)"; exit 2; }
tree="$root/src/runtime/xwin"
[ -d "$tree" ] || { echo "REFUSE(2): $tree is absent: no vendored window tree to check"; exit 2; }
[ -f "$tree/XWIN-MANIFEST.tsv" ] || { echo "REFUSE(2): $tree holds no XWIN-MANIFEST.tsv: not a tree the generator wrote"; exit 2; }
head=$(git -C "$root" rev-parse --short HEAD 2>/dev/null || echo unknown)
out=$(S4E_SCRIP="$root" python3 "$S4E_HARNESS/scripts/util_gen_icon_xwin_device.py" --check "$tree" --syntax --link-census 2>&1)
rc=$?
printf '%s\n' "$out" | grep -E '^(XWIN-GEN|XWIN-NO-ALLOCATOR|REFUSE)' | tail -3
case "$rc" in
   0) echo "XWIN_TREE_BOARD $tree equal to generated plus patch (tree $head) CHECK OK"; exit 0 ;;
   2) echo "XWIN_TREE_BOARD $tree not measured (tree $head) REFUSE(2)"; exit 2 ;;
   *) echo "XWIN_TREE_BOARD $tree differs from generated plus patch (tree $head) CHECK FAIL"; exit 1 ;;
esac
