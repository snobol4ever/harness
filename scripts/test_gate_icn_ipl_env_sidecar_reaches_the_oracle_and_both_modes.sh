#!/usr/bin/env bash
# test_gate_icn_ipl_env_sidecar_reaches_the_oracle_and_both_modes.sh -- NAME.env SETS THE UNIT'S ENVIRONMENT FOR THE REF AND BOTH
# SCRIP MODES ALIKE (hq_icon 2026-09-27; Lon's word "Get IPL to 843."; ceo CEO-1315). IPL's termcap programs (hcal4unx, mr, yahtz)
# need TERM and TERMCAP, ranstars TERM=ansi, hotedit HOME at its run directory: one sidecar, read by ipl_env_apply in
# lib_icon_ipl_isolation.sh and applied by the cutter's run_isolated and by ipl_isolation_run alike.
# GREEN: a planted unit that prints GREETING and HOME cuts a ref carrying the sidecar's values (HOME=@RUNDIR resolves to the run
# directory, which the program prints relative to its cwd), and m3 and m4 match it. RED: the same run against a copy whose
# ipl_env_apply ignores NAME.env (the origin behaviour) must not produce that ref. A sidecar setting the runner's own PATH refuses.
set -uo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_ipl_sidecar_gate.sh"
G=test_gate_icn_ipl_env_sidecar_reaches_the_oracle_and_both_modes
sg_init
plant() {
  cat > "$SG_PKG/progs/envw.icn" <<'ICN'
procedure main()
   local h;
   write("greeting: ", \getenv("GREETING") | "unset");
   h := getenv("HOME") | "";
   write("home is the run directory: ", if h[-6:0] == "/progs" then "yes" else "no");
end
ICN
  printf '# a greeting and HOME at the run directory\nGREETING=hello there\nHOME=@RUNDIR\n' > "$SG_PKG/progs/envw.env"
}
red=0
g="$(sg_verdict "$SG_HERE" envw plant)"; gref="$(cat "$(sg_ref "$SG_HERE" envw)" 2>/dev/null)"
case "$g" in "MINTED=1 M3=PASS M4=PASS"*) ;; *) echo "  FAIL green: $g"; red=1 ;; esac
printf '%s' "$gref" | grep -q 'greeting: hello there' && printf '%s' "$gref" | grep -q 'run directory: yes' || { echo "  FAIL green: the ref does not carry the sidecar's values: $(printf '%s' "$gref" | tr '\n' '|')"; red=1; }
d="$(sg_doctor "s = s.replace('if [ -f \"\$side\" ]; then\n    while IFS= read -r kv; do', 'if false; then\n    while IFS= read -r kv; do', 1)")" || exit 2
r="$(sg_verdict "$d" envw plant)"; rref="$(cat "$(sg_ref "$d" envw)" 2>/dev/null)"
printf '%s' "$rref" | grep -q 'greeting: hello there' && { echo "  FAIL red: with NAME.env ignored the ref still carries its values ($r) -- the gate cannot see the sidecar"; red=1; }
sg_fresh_pkg refuse; printf 'procedure main()\n   write(1);\nend\n' > "$SG_PKG/progs/envp.icn"; printf 'PATH=/nowhere\n' > "$SG_PKG/progs/envp.env"
( . "$SG_HERE/lib_icon_ipl_isolation.sh"; declare -a E=(); ipl_env_apply "$SG_PKG/progs/envp.icn" /tmp E 2>/dev/null ); [ $? -eq 2 ] || { echo "  FAIL: a NAME.env setting PATH was accepted"; red=1; }
[ "$red" -eq 0 ] && { echo "✅ GATE PASS [$G]: NAME.env reaches iconx in the cutter and SCRIP in m3 and m4 ($g); ignored, the ref loses it ($r); PATH refuses"; exit 0; }
echo "⛔ GATE FAIL [$G]"; exit 1
