#!/usr/bin/env bash
# test_gate_icn_ipl_fixtures_stage_subdirectories_and_dotfiles.sh -- NAME.fixtures/ STAGES A DIRECTORY TREE AND ITS DOTFILES FOR THE
# REF AND BOTH SCRIP MODES ALIKE (hq_icon 2026-09-27; Lon's word "Get IPL to 843."; ceo CEO-1315). progs/iplweb and progs/mszip take
# a directory tree as their argument and progs/newsrc opens the fixed name .newsrc; ipl_fixtures_stage used to copy top-level
# regular files only, skipping every dotfile and refusing every subdirectory. It now copies the tree as it stands and still
# refuses a symlink anywhere in it.
# GREEN: a planted unit reading tree/sub/leaf.txt and .dotrc cuts a ref carrying both, and m3 and m4 match it. RED: a copy whose
# stager copies top-level plain files only (the origin behaviour) cannot produce that ref. A symlink in the tree refuses.
set -uo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_ipl_sidecar_gate.sh"
G=test_gate_icn_ipl_fixtures_stage_subdirectories_and_dotfiles
sg_init
plant() {
  cat > "$SG_PKG/progs/fxw.icn" <<'ICN'
procedure main()
   local f;
   if f := open("tree/sub/leaf.txt") then { write("leaf: ", read(f)); close(f) } else write("leaf: missing");
   if f := open(".dotrc") then { write("dotrc: ", read(f)); close(f) } else write("dotrc: missing");
end
ICN
  mkdir -p "$SG_PKG/progs/fxw.fixtures/tree/sub"; printf 'deep in the tree\n' > "$SG_PKG/progs/fxw.fixtures/tree/sub/leaf.txt"; printf 'a dotfile\n' > "$SG_PKG/progs/fxw.fixtures/.dotrc"
}
red=0
g="$(sg_verdict "$SG_HERE" fxw plant)"; gref="$(cat "$(sg_ref "$SG_HERE" fxw)" 2>/dev/null)"
case "$g" in "MINTED=1 M3=PASS M4=PASS"*) ;; *) echo "  FAIL green: $g"; red=1 ;; esac
printf '%s' "$gref" | grep -q 'leaf: deep in the tree' && printf '%s' "$gref" | grep -q 'dotrc: a dotfile' || { echo "  FAIL green: the ref does not carry the staged tree: $(printf '%s' "$gref" | tr '\n' '|')"; red=1; }
d="$(sg_doctor "s = s.replace('  cp -R \"\$dir\"/. \"\$dest\"/ || return 2\n', '  for f in \"\$dir\"/*; do [ -f \"\$f\" ] && cp \"\$f\" \"\$dest/\"; done\n', 1)")" || exit 2
r="$(sg_verdict "$d" fxw plant)"; rref="$(cat "$(sg_ref "$d" fxw)" 2>/dev/null)"
printf '%s' "$rref" | grep -q 'leaf: deep in the tree' && { echo "  FAIL red: with a top-level-only stager the ref still carries the tree ($r)"; red=1; }
sg_fresh_pkg refuse; mkdir -p "$SG_PKG/progs/fxl.fixtures/d"; ln -s /etc/passwd "$SG_PKG/progs/fxl.fixtures/d/link"; mkdir -p "$SG_T/dest"
( . "$SG_HERE/lib_icon_ipl_isolation.sh"; ipl_fixtures_stage "$SG_PKG/progs/fxl.icn" "$SG_T/dest" 2>/dev/null ); [ $? -eq 2 ] || { echo "  FAIL: a symlink inside a fixture tree was staged"; red=1; }
[ "$red" -eq 0 ] && { echo "✅ GATE PASS [$G]: a fixture tree and its dotfiles reach iconx in the cutter and SCRIP in m3 and m4 ($g); top-level only, the ref loses them ($r); a symlink refuses"; exit 0; }
echo "⛔ GATE FAIL [$G]"; exit 1
