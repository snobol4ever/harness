#!/usr/bin/env bash
# test_gate_wreg_claim_binary.sh — BINARY-MEDIUM half of the WREG claim gate (W-0b decision (c), Lon 2026-08-12 s36c).
#
# WHY THIS EXISTS: test_gate_wreg_claim.sh is a text regex over SOURCE.  FINDING-2026-08-12j proved by
# construction that a raw-byte emission (ef_b4(0x4C,0x8B,...)) greps to ZERO there — so --strict can be green
# while binary-medium r10/r11 code drifts underneath.  This gate closes that blind spot by disassembling the
# ACTUAL mode-3 runtime slab (dumped pre-mprotect at bb_seal) and asserting every r10/r11-touching instruction
# matches an allowlisted SHAPE.  ⛔ Do NOT solve this with byte patterns in the source regex: 0x41/0x4C are REX
# prefixes shared across registers — the instrument for the binary half is a disassembler over OUTPUT, never a
# matcher over SOURCE (finding's own warning, verbatim).
#
# METHOD (proven in FINDING-2026-08-12j): gdb `start; break bb_seal` (bb_seal lives in libscrip_rt.so — break
# BEFORE start silently fails to resolve), dump [buf,buf+size) per seal, objdump -D -b binary each slab,
# extract r10/r11 lines, normalize, diff against the allowlist below.
#
# PROGRAM SET: the finding's 17-program CLASS-D/DEFER/ARBNO-defer concentration set (highest wire-traffic
# region).  Widen deliberately, not accidentally — adding a program is an allowlist-review event.
#
# ALLOWLIST: the exactly-two mechanisms the finding classified (46 sealed graphs, 14 shapes, no third):
#   CLASS-D wire glue  — push/reload of the 32B suspension record + jmp-through-wire exits (emit.cpp occ=6)
#   RTCC veneer        — save/reload of the wire pair around C-RT crossings (x86_asm.h class-(3) 9)
# Anything else that names r10/r11 in emitted bytes is binary sweep debt: exit 1.
#
# Usage: bash ../harness/scripts/test_gate_wreg_claim_binary.sh [--quick]   (--quick = first 3 programs, smoke only)
# Exit:  0 = every r10/r11 instruction shape allowlisted · 1 = unallowlisted shape(s) found · 2 = setup failure
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"; cd "$HERE"
# library/probe_reference/bb/probes moved into suite format 2026-08-28 (probe-consolidate-bb, LON-20260828 total
# conversion) -- each SET member below is materialized on demand. ⭐ RE-POINTED 2026-08-30 (seat12,
# repo-wide dead-suite-path consumer sweep): that per-family bb_probes.{sno,ref} pair was itself
# absorbed into THE ONE FLAT RUNGS and deleted; lib_rungs_extract.sh now extracts each SET member
# by its ALL.csv origin ("probe_bb_probes__<name>") instead.
RUNGS_LANG="${RUNGS_LANG:-snobol4}" . "$HERE/../harness/scripts/lib_rungs_extract.sh"
SET=(D09 D10 D11 D12 D13 G19 G20 H21 H24 H25 N12 N17 X01 X02 X03 X04 X05 X06 X11)
[ "${1:-}" = "--quick" ] && SET=(D09 D12 X02)
command -v gdb >/dev/null || { echo "SETUP: gdb missing (apt-get install -y --no-install-recommends gdb)"; exit 2; }
command -v objdump >/dev/null || { echo "SETUP: objdump missing"; exit 2; }
[ -x ./scrip ] || { echo "SETUP: ./scrip missing — build first"; exit 2; }
TMP=$(mktemp -d /tmp/wreg_bin.XXXXXX); trap 'rm -rf "$TMP"' EXIT
# --- ALLOWLIST of normalized instruction shapes (operands canonicalized: hex/dec immediates -> N) ---------------
cat > "$TMP/allow.txt" << 'ALLOW'
mov %r10,N(%rax)
mov %r11,N(%rax)
mov N(%r11),%r8
mov N(%r11),%r9
mov N(%r11),%r10
mov N(%r11),%r11
movabs $N,%r10
movabs $N,%r11
call *%r10
call *%r11
jmp *%r10
jmp *%r11
lea N(%rip),%r10
lea N(%rip),%r11
push %r10
push %r11
mov N(%rsp),%r10
mov N(%rsp),%r11
ALLOW
# ---------------------------------------------------------------------------------------------------------------
fail=0; total_slabs=0; total_hits=0
for p in "${SET[@]}"; do
    sno="$TMP/probes/$p.sno"; mkdir -p "$TMP/probes"
    rungs_extract_origin "probe_bb_probes__$p" "$sno" >/dev/null 2>&1
    [ -f "$sno" ] || { echo "SETUP: missing $sno (extract failed for entry $p)"; exit 2; }
    d="$TMP/$p"; mkdir -p "$d"
    # gdb script: dump every seal with an incrementing convenience var
    cat > "$d/g.cmds" << GEOF
start
set \$i = 0
break bb_seal
commands
  silent
  eval "dump binary memory $d/slab_%d.bin buf buf+size", \$i
  set \$i = \$i + 1
  continue
end
continue
GEOF
    timeout -k 5 25 gdb -batch -x "$d/g.cmds" --args ./scrip --run "$sno" < /dev/null > /dev/null 2>&1
    shopt -s nullglob
    for slab in "$d"/slab_*.bin; do
        total_slabs=$((total_slabs+1))
        objdump -D -b binary -m i386:x86-64 "$slab" 2>/dev/null \
          | grep -E '%r1[01]\b' \
          | sed -E 's/^[^\t]*\t[^\t]*\t//' \
          | sed -E 's/(0x[0-9a-f]+|\$0x[0-9a-f]+|-?[0-9]+)\(/N(/g; s/\$0x[0-9a-f]+/\$N/g; s/#.*$//; s/[[:space:]]+/ /g; s/ $//' \
          | sort -u > "$slab.shapes"
        while IFS= read -r shape; do
            [ -z "$shape" ] && continue
            total_hits=$((total_hits+1))
            grep -qxF "$shape" "$TMP/allow.txt" || { echo "⛔ UNALLOWLISTED [$p $(basename "$slab")]: $shape"; fail=1; }
        done < "$slab.shapes"
    done
done
echo "---"
echo "binary wreg gate: programs=${#SET[@]} slabs=$total_slabs r10/r11-shape-checks=$total_hits"
if [ $fail -eq 0 ]; then echo "BINARY MEDIUM CLEAN — every emitted r10/r11 instruction matches an allowlisted shape"; exit 0
else echo "⛔ BINARY SWEEP DEBT FOUND — shapes above are not licensed; extend the allowlist ONLY with a FINDING"; exit 1; fi
