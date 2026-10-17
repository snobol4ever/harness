#!/usr/bin/env bash
# test_gate_icn_ipl_mask_sidecar_masks_what_varies_on_both_sides.sh -- the NAME.mask sidecar (hq_icon 2026-10-04; Lon CEO-1474, in-chat to hq_icon,
# verbatim: "The answer is the test harness needs a mechanism for masking to allow these tests which are run-dependent, or environment dependent so
# that these tests can actually run and be graded."; one gate per sidecar, CEO-1315; the mask is the CEO-409 mask through util_apply_ceo409_mask.py,
# CEO-1504). A malformed row (no reason) refuses (rc 2). The planted unit prints its HOME, which NAME.env sets to the run
# directory -- a fresh path on every run -- beside a stable line. GREEN: with NAME.mask masking that one line the real cutter mints the unit (its
# determinism arms compare the masked runs), the ref on disk carries a raw run path, and m3 and m4 pass the masked comparison. RED: with the mask
# ignored by ipl_graded_cmp the cutter sees two different runs and mints nothing. A malformed mask refuses (rc 2).
set -uo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_ipl_sidecar_gate.sh"
G=test_gate_icn_ipl_mask_sidecar_masks_what_varies_on_both_sides
sg_init
plant() {
  printf 'procedure main()\n   write("home: ", getenv("HOME") | "unset");\n   every write("stable: ", 6 * (7 to 10));\nend\n' > "$SG_PKG/progs/maskw.icn"
  printf 'HOME=@RUNDIR\n' > "$SG_PKG/progs/maskw.env"
  printf '# CEO-409 rows (entry<TAB>regex<TAB>measured reason)\nmaskw\t^home: .*$\tHOME is the run directory, a fresh mktemp path on every run (measured: two cutter runs differ in this line only)\n' > "$SG_PKG/progs/maskw.mask"
}
red=0
g="$(sg_verdict "$SG_HERE" maskw plant)"; gref="$(cat "$(sg_ref "$SG_HERE" maskw)" 2>/dev/null)"
case "$g" in "MINTED=1 M3=PASS M4=PASS"*) ;; *) echo "  FAIL green: $g"; red=1 ;; esac
printf '%s' "$gref" | grep -q '^home: /' && printf '%s' "$gref" | grep -q '^stable: 60$' || { echo "  FAIL green: the ref is not the oracle's raw output: $(printf '%s' "$gref" | head -2 | tr '\n' '|')"; red=1; }
d="$(sg_doctor "s = s.replace('[ -f \"\$side\" ] || { cmp -s \"\$2\" \"\$3\"; return; }\n  m=', '{ cmp -s \"\$2\" \"\$3\"; return; }\n  m=', 1)")" || exit 2
r="$(sg_verdict "$d" maskw plant)"
case "$r" in "MINTED=0"*) ;; *) echo "  FAIL red: with the mask ignored the unit still minted ($r) -- the gate cannot see the sidecar"; red=1 ;; esac
sg_fresh_pkg refuse; printf 'procedure main()\n   write(1);\nend\n' > "$SG_PKG/progs/maskp.icn"; printf 'maskp\t^.*$\n' > "$SG_PKG/progs/maskp.mask"
( . "$SG_HERE/lib_icon_ipl_isolation.sh"; ipl_mask_check "$SG_PKG/progs/maskp.icn" 2>/dev/null ); [ $? -eq 2 ] || { echo "  FAIL: a malformed NAME.mask was accepted"; red=1; }
[ "$red" -eq 0 ] && { echo "✅ GATE PASS [$G]: NAME.mask masks the run-dependent line on both sides -- minted and graded ($g); ignored, nothing mints ($r); malformed refuses"; exit 0; }
echo "⛔ GATE FAIL [$G]"; exit 1
