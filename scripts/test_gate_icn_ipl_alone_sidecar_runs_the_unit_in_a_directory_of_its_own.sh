#!/usr/bin/env bash
# test_gate_icn_ipl_alone_sidecar_runs_the_unit_in_a_directory_of_its_own.sh -- the NAME.alone sidecar (hq_icon 2026-10-04; Lon CEO-1474; one gate per
# sidecar, CEO-1315): a unit that lists its current directory (progs/gcomp) runs in a directory holding only its NAME.fixtures/, for the oracle and
# both SCRIP modes alike. The planted unit lists its cwd. GREEN: the ref is exactly the two fixture names and m3 and m4 pass. RED: with NAME.alone
# ignored the unit runs in the package subdirectory and its listing carries the package's own files. A reason under 20 characters refuses (rc 2).
set -uo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_ipl_sidecar_gate.sh"
G=test_gate_icn_ipl_alone_sidecar_runs_the_unit_in_a_directory_of_its_own
sg_init
plant() {
  printf 'procedure main()\n   local p, s;\n   p := open("ls -1", "p");\n   while s := read(p) do write(s);\n   close(p);\nend\n' > "$SG_PKG/progs/alonew.icn"
  printf 'alonew lists its current directory: it runs in a directory of its own holding only alonew.fixtures\n' > "$SG_PKG/progs/alonew.alone"
  mkdir -p "$SG_PKG/progs/alonew.fixtures"; printf 'a\n' > "$SG_PKG/progs/alonew.fixtures/a.txt"; printf 'b\n' > "$SG_PKG/progs/alonew.fixtures/b.txt"
}
red=0
g="$(sg_verdict "$SG_HERE" alonew plant)"; gref="$(cat "$(sg_ref "$SG_HERE" alonew)" 2>/dev/null)"
case "$g" in "MINTED=1 M3=PASS M4=PASS"*) ;; *) echo "  FAIL green: $g"; red=1 ;; esac
[ "$gref" = "$(printf 'a.txt\nb.txt')" ] || { echo "  FAIL green: the ref is not exactly the fixtures: $(printf '%s' "$gref" | head -4 | tr '\n' '|')"; red=1; }
d="$(sg_doctor "s = s.replace('  [ -f \"\$side\" ] || return 1\n  r=\"\$(_ipl_side_lines \"\$side\")\"\n  [ \"\${#r}\" -ge 20 ] || { echo \"⛔ ALONE', '  return 1\n  r=\"\$(_ipl_side_lines \"\$side\")\"\n  [ \"\${#r}\" -ge 20 ] || { echo \"⛔ ALONE', 1)")" || exit 2
r="$(sg_verdict "$d" alonew plant)"; rref="$(cat "$(sg_ref "$d" alonew)" 2>/dev/null)"
[ "$rref" = "$(printf 'a.txt\nb.txt')" ] && { echo "  FAIL red: with NAME.alone ignored the listing is still only the fixtures ($r)"; red=1; }
sg_fresh_pkg refuse; printf 'procedure main()\n   write(1);\nend\n' > "$SG_PKG/progs/alonep.icn"; printf 'short\n' > "$SG_PKG/progs/alonep.alone"
( . "$SG_HERE/lib_icon_ipl_isolation.sh"; ipl_alone_declared "$SG_PKG/progs/alonep.icn" 2>/dev/null ); [ $? -eq 2 ] || { echo "  FAIL: a NAME.alone without a reason was accepted"; red=1; }
[ "$red" -eq 0 ] && { echo "✅ GATE PASS [$G]: NAME.alone runs the unit among its fixtures alone, oracle and both modes ($g); ignored, the listing carries the package ($r); no reason refuses"; exit 0; }
echo "⛔ GATE FAIL [$G]"; exit 1
