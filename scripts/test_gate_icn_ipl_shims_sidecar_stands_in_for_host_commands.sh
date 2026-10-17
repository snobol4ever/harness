#!/usr/bin/env bash
# test_gate_icn_ipl_shims_sidecar_stands_in_for_host_commands.sh -- the NAME.shims/ sidecar (hq_icon 2026-10-04; Lon CEO-1474; one gate per sidecar,
# CEO-1315): stand-in host commands put first on PATH for the unit's run, the oracle's and both SCRIP modes' alike (an MS-DOS dir, an ULTRIX ls, a
# fixed nm). The planted unit pipes a command no box has. GREEN: the ref carries the stand-in's answer and m3 and m4 pass. RED: with the shims
# ignored the ref loses it. A stand-in that is not executable refuses (rc 2).
set -uo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_ipl_sidecar_gate.sh"
G=test_gate_icn_ipl_shims_sidecar_stands_in_for_host_commands
sg_init
plant() {
  printf 'procedure main()\n   local p;\n   p := open("greetcmd world", "p");\n   write("said: ", read(p) | "nothing");\n   close(p);\nend\n' > "$SG_PKG/progs/shimw.icn"
  mkdir -p "$SG_PKG/progs/shimw.shims"; printf '#!/bin/sh\nprintf "hello from a stand-in, %%s\\n" "$1"\n' > "$SG_PKG/progs/shimw.shims/greetcmd"; chmod +x "$SG_PKG/progs/shimw.shims/greetcmd"
}
red=0
g="$(sg_verdict "$SG_HERE" shimw plant)"; gref="$(cat "$(sg_ref "$SG_HERE" shimw)" 2>/dev/null)"
case "$g" in "MINTED=1 M3=PASS M4=PASS"*) ;; *) echo "  FAIL green: $g"; red=1 ;; esac
printf '%s' "$gref" | grep -q 'said: hello from a stand-in, world' || { echo "  FAIL green: the ref does not carry the stand-in's answer: $(printf '%s' "$gref" | head -2 | tr '\n' '|')"; red=1; }
d="$(sg_doctor "s = s.replace('  [ -d \"\$src\" ] || return 0\n  dst=', '  return 0\n  dst=', 1)")" || exit 2
r="$(sg_verdict "$d" shimw plant)"; rref="$(cat "$(sg_ref "$d" shimw)" 2>/dev/null)"
printf '%s' "$rref" | grep -q 'hello from a stand-in' && { echo "  FAIL red: with the shims ignored the ref still carries the stand-in's answer ($r)"; red=1; }
sg_fresh_pkg refuse; printf 'procedure main()\n   write(1);\nend\n' > "$SG_PKG/progs/shimp.icn"; mkdir -p "$SG_PKG/progs/shimp.shims"; printf '#!/bin/sh\necho x\n' > "$SG_PKG/progs/shimp.shims/cmd"; chmod -x "$SG_PKG/progs/shimp.shims/cmd"
( . "$SG_HERE/lib_icon_ipl_isolation.sh"; declare -a E=("PATH=/usr/bin:/bin"); mkdir -p "$SG_T/rr/progs"; ipl_shims_apply "$SG_PKG/progs/shimp.icn" "$SG_T/rr/progs" E 2>/dev/null ); [ $? -eq 2 ] || { echo "  FAIL: a stand-in that is not executable was accepted"; red=1; }
[ "$red" -eq 0 ] && { echo "✅ GATE PASS [$G]: NAME.shims/ reaches iconx in the cutter and SCRIP in m3 and m4 ($g); ignored, the ref loses it ($r); a non-executable stand-in refuses"; exit 0; }
echo "⛔ GATE FAIL [$G]"; exit 1
