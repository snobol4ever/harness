#!/usr/bin/env bash
# test_gate_icn_ipl_head_sidecar_cuts_an_endless_output.sh -- the NAME.head sidecar (hq_icon 2026-10-04; Lon CEO-1474; one gate per sidecar,
# CEO-1315): a unit that writes without end (progs/noise) is graded on its first N bytes, the cut ending the run, for the oracle and both SCRIP
# modes alike. The planted unit writes 300000 bytes. GREEN: with NAME.head 100 the ref is 100 bytes and m3 and m4 pass. RED: with the cap ignored
# the ref is the whole output. A cap that is not one integer 1..67108864 refuses (rc 2).
set -uo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_ipl_sidecar_gate.sh"
G=test_gate_icn_ipl_head_sidecar_cuts_an_endless_output
sg_init
plant() {
  printf 'procedure main()\n   every 1 to 100000 do writes("abc");\nend\n' > "$SG_PKG/progs/headw.icn"
  printf '# the first 100 bytes are graded\n100\n' > "$SG_PKG/progs/headw.head"
}
red=0
g="$(sg_verdict "$SG_HERE" headw plant)"; gsz="$(wc -c < "$(sg_ref "$SG_HERE" headw)" 2>/dev/null || echo 0)"
case "$g" in "MINTED=1 M3=PASS M4=PASS"*) ;; *) echo "  FAIL green: $g"; red=1 ;; esac
[ "$gsz" -eq 100 ] || { echo "  FAIL green: the ref is $gsz bytes, not the declared 100"; red=1; }
d="$(sg_doctor "s = s.replace('  if [ -z \"\$cap\" ]; then ( cd', '  if true; then ( cd', 1)")" || exit 2
r="$(sg_verdict "$d" headw plant)"; rsz="$(wc -c < "$(sg_ref "$d" headw)" 2>/dev/null || echo 0)"
[ "$rsz" -eq 100 ] && { echo "  FAIL red: with the cap ignored the ref is still 100 bytes ($r)"; red=1; }
sg_fresh_pkg refuse; printf 'procedure main()\n   write(1);\nend\n' > "$SG_PKG/progs/headp.icn"; printf 'lots\n' > "$SG_PKG/progs/headp.head"
( . "$SG_HERE/lib_icon_ipl_isolation.sh"; ipl_head_declared "$SG_PKG/progs/headp.icn" >/dev/null 2>&1 ); [ $? -eq 2 ] || { echo "  FAIL: a NAME.head that is not a byte count was accepted"; red=1; }
[ "$red" -eq 0 ] && { echo "✅ GATE PASS [$G]: NAME.head grades the first 100 bytes, oracle and both modes ($g); ignored, the ref is ${rsz} bytes ($r); a bad cap refuses"; exit 0; }
echo "⛔ GATE FAIL [$G]"; exit 1
