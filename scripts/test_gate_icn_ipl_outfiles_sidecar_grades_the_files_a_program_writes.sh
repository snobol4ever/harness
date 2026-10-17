#!/usr/bin/env bash
# test_gate_icn_ipl_outfiles_sidecar_grades_the_files_a_program_writes.sh -- NAME.outfiles APPENDS THE FILES A PROGRAM WRITES TO
# ITS GRADED OUTPUT, FOR THE REF AND BOTH SCRIP MODES ALIKE (hq_icon 2026-09-27; Lon's word "Get IPL to 843."; ceo CEO-1315). IPL's
# RESULT_NOT_ON_STDOUT programs (ipsplit, lcn, nocr, yescr, idxtext, ...) and painterc/dd2wif put their whole result in files, so a
# stdout-only grade is empty. ipl_outfiles_append in lib_icon_ipl_isolation.sh appends "=== OUTFILE name ===" and each file's
# bytes (or "(absent)") after the run, called by the cutter's run_isolated and by ipl_isolation_run alike.
# GREEN: a planted unit that writes result.txt and prints one line cuts a ref carrying the file, and m3 and m4 match it. RED: a
# copy whose ipl_outfiles_append does nothing (the origin behaviour) cuts a ref without the file. A path leaving the run
# directory refuses.
set -uo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_ipl_sidecar_gate.sh"
G=test_gate_icn_ipl_outfiles_sidecar_grades_the_files_a_program_writes
sg_init
plant() {
  cat > "$SG_PKG/progs/outw.icn" <<'ICN'
procedure main()
   local f;
   f := open("result.txt", "w");
   every write(f, "line ", 1 to 3);
   close(f);
   write("wrote result.txt");
end
ICN
  printf '# the program writes its result to result.txt\nresult.txt\nnever-written.txt\n' > "$SG_PKG/progs/outw.outfiles"
}
red=0
g="$(sg_verdict "$SG_HERE" outw plant)"; gref="$(cat "$(sg_ref "$SG_HERE" outw)" 2>/dev/null)"
case "$g" in "MINTED=1 M3=PASS M4=PASS"*) ;; *) echo "  FAIL green: $g"; red=1 ;; esac
printf '%s' "$gref" | grep -q '=== OUTFILE result.txt ===' && printf '%s' "$gref" | grep -q 'line 3' && printf '%s' "$gref" | grep -q '(absent)' \
  || { echo "  FAIL green: the ref does not carry the written file: $(printf '%s' "$gref" | tr '\n' '|')"; red=1; }
d="$(sg_doctor "s = s.replace('local side=\"\${1%.icn}.outfiles\" run=\"\$2\" out=\"\$3\" rel\n', 'local side=\"\${1%.icn}.outfiles\" run=\"\$2\" out=\"\$3\" rel\n  return 0\n', 1)")" || exit 2
r="$(sg_verdict "$d" outw plant)"; rref="$(cat "$(sg_ref "$d" outw)" 2>/dev/null)"
printf '%s' "$rref" | grep -q 'OUTFILE' && { echo "  FAIL red: with NAME.outfiles ignored the ref still carries the file ($r)"; red=1; }
sg_fresh_pkg refuse; printf 'procedure main()\n   write(1);\nend\n' > "$SG_PKG/progs/outp.icn"; printf '../escape.txt\n' > "$SG_PKG/progs/outp.outfiles"
( . "$SG_HERE/lib_icon_ipl_isolation.sh"; ipl_outfiles_append "$SG_PKG/progs/outp.icn" "$SG_T" "$SG_T/o" 2>/dev/null ); [ $? -eq 2 ] || { echo "  FAIL: an outfile path leaving the run directory was accepted"; red=1; }
[ "$red" -eq 0 ] && { echo "✅ GATE PASS [$G]: NAME.outfiles appends the written files for iconx in the cutter and SCRIP in m3 and m4 ($g); ignored, the ref loses them ($r); ../ refuses"; exit 0; }
echo "⛔ GATE FAIL [$G]"; exit 1
