#!/usr/bin/env bash
# test_gate_icn_ipl_pin_sidecar_fixes_the_clock_and_entropy_for_both_participants.sh -- NAME.pin PINS THE CLOCK AND THE ENTROPY
# FOR THE ORACLE AND BOTH SCRIP MODES ALIKE (hq_icon 2026-09-27; Lon's word "Get IPL to 843."; ceo CEO-1315: "the clock and urandom
# pin wrapping the oracle in the cutter too"). About twenty IPL programs seed randomize() -- which reads /dev/urandom before the
# clock -- or print &dateline, &clock or &time, so no two runs agree and the cutter refuses them. NAME.pin puts one LD_PRELOAD shim
# (../harness/scripts/ipl_pin_shim.c: wall clock 1000000000, CPU time 0, /dev/urandom a fixed stream) under iconx in run_isolated and under
# SCRIP in ipl_isolation_run, so the ref and both modes run in the same pinned world.
# GREEN: a planted unit printing &dateline, &time and three rolls after randomize() cuts a ref (four runs and a minute crossing
# agree) and m3 and m4 match it. RED: a copy that ignores NAME.pin (the origin behaviour) cannot mint it.
# FD REUSE (the coo's review of 569bf02c6): the shim remembers the entropy descriptor, so a program that opens /dev/urandom, closes it,
# and then opens a real file the kernel hands the same number must read the FILE. GREEN: through the shim this lib builds, it does.
# RED: through a copy whose close and fclose hooks are removed (the 569bf02c6 shim), the file reads as the entropy stream.
set -uo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_ipl_sidecar_gate.sh"
G=test_gate_icn_ipl_pin_sidecar_fixes_the_clock_and_entropy_for_both_participants
sg_init
plant() {
  cat > "$SG_PKG/progs/pinw.icn" <<'ICN'
procedure main()
   local f, s;
   write(&dateline);
   write("time ", &time);
   f := open("/dev/urandom", "r");
   s := reads(f, 4);
   close(f);
   every writes(" ", ord(!s));
   write();
   &random := ord(s[1]);
   write(?1000, " ", ?1000);
end
ICN
  printf '# the clock and /dev/urandom are pinned for the oracle and both modes\n' > "$SG_PKG/progs/pinw.pin"
}
red=0
g="$(sg_verdict "$SG_HERE" pinw plant)"; gref="$(cat "$(sg_ref "$SG_HERE" pinw)" 2>/dev/null)"
case "$g" in "MINTED=1 M3=PASS M4=PASS"*) ;; *) echo "  FAIL green: $g"; red=1 ;; esac
printf '%s' "$gref" | grep -q '2001' || { echo "  FAIL green: the ref does not carry the pinned date: $(printf '%s' "$gref" | tr '\n' '|')"; red=1; }
d="$(sg_doctor "s = s.replace('if [ -f \"\${icn%.icn}.pin\" ]; then', 'if false; then', 1)")" || exit 2
r="$(sg_verdict "$d" pinw plant)"
case "$r" in "MINTED=0"*) ;; *) echo "  FAIL red: with NAME.pin ignored the clock-reading unit still minted ($r)"; red=1 ;; esac
cat > "$SG_T/fdre.c" <<'C'
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
int main(int argc, char **argv) {
    unsigned char b[2]; char s[32] = {0}; int u = open("/dev/urandom", O_RDONLY); FILE *w;
    if (argc < 2 || read(u, b, 2) != 2) return 2;
    close(u); w = fopen(argv[1], "w"); if (!w) return 2; fputs("real file\n", w); fclose(w);
    int f = open(argv[1], O_RDONLY); if (read(f, s, 31) < 0) return 2;
    printf("%s", s); return 0;
}
C
gcc -o "$SG_T/fdre" "$SG_T/fdre.c" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: the fd-reuse probe did not build"; exit 2; }
fdre_with() { local so; so="$( . "$1/lib_icon_ipl_isolation.sh"; ipl_pin_shim_path )" || return 2; LD_PRELOAD="$so" "$SG_T/fdre" "$SG_T/fdre.$RANDOM.txt"; }
fg="$(fdre_with "$SG_HERE")"
[ "$fg" = "real file" ] || { echo "  FAIL fd-reuse green: a file opened on the recycled entropy descriptor read [$(printf '%s' "$fg" | head -c 20 | od -An -c | tr -s ' ')]"; red=1; }
d3="$(sg_doctor "s = s.replace('    if (fd >= 0 && fd == pin_fd) pin_fd = -1;\n', '', 1).replace('    if (f && pin_fd >= 0 && fileno(f) == pin_fd) pin_fd = -1;\n', '', 1)" ipl_pin_shim.c)" || exit 2
fr="$(fdre_with "$d3")"
[ "$fr" != "real file" ] || { echo "  FAIL fd-reuse red: without the close hooks the recycled descriptor still read the file"; red=1; }
[ "$red" -eq 0 ] && { echo "✅ GATE PASS [$G]: NAME.pin pins iconx in the cutter and SCRIP in m3 and m4 alike ($g); ignored, the unit cannot mint ($r); a file on a recycled entropy descriptor reads the file, and without the close hooks it does not"; exit 0; }
echo "⛔ GATE FAIL [$G]"; exit 1
