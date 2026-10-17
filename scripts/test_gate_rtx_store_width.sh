#!/usr/bin/env bash
# test_gate_rtx_store_width.sh — AN RTX ASM STORE MAY NOT BE WIDER THAN THE GLOBAL IT WRITES.
#
# Minted s219 (2026-07-30) to close the hazard s218 named and MIS-PRESCRIBED.
#
# THE HAZARD (s218, on rtx_match.s): g_cap_gen_next sits at +0x4, immediately
# after the 4-byte g_cap_gen, and it is the MONOTONIC CAPTURE-GENERATION WELL.
# An 8-byte store to g_cap_gen therefore overwrites g_cap_gen_next with the high
# half of a generation id, corrupting generation ALLOCATION downstream of every
# nested match. It links fine, emits no diagnostic at any stage, and passes short
# tests. The same shape holds for Sigma (8-byte ptr) beside Sigmalen (4-byte int).
#
# WHY s218's PRESCRIPTION ("_Static_assert the adjacency") CANNOT BE WRITTEN:
# offsetof spans STRUCT MEMBERS only. C guarantees NOTHING about the relative
# placement of two distinct objects with static storage duration -- the linker may
# order, pad, or separate them freely. So there is no legal expression whose value
# is "g_cap_gen_next - g_cap_gen" for a static assertion to check, and a session
# following s218 literally would have found that out only after writing the code.
# ⭐ THE ADJACENCY IS NOT THE THING TO DEFEND. It is neither guaranteed nor needed:
# if every store is the WIDTH OF ITS TARGET, the neighbour is untouchable whether
# it is adjacent, padded away, or in another section entirely. Defend the WIDTH.
#
# WHAT THIS GATE DOES: harvests every global's true size from the ELF symbol table
# (ground truth, not prose -- ARCH section 7 0(c)'s own lesson about reading the
# object), then walks src/runtime/rtx/*.s. Each `[rip + sym@GOTPCREL]` load taints
# the destination register with sym's size; a store through that register wider
# than the size is a VIOLATION. Registers are re-tainted on each load, so the
# window is exact rather than line-count heuristic.
set -u
ROOT="$(cd "$(dirname "$0")/../../SCRIP" && pwd)"
SO="$ROOT/out/libscrip_rt.so"
[ -f "$SO" ] || { echo "FATAL: $SO missing — run make libscrip_rt first"; exit 1; }
nm -S --defined-only "$SO" 2>/dev/null | awk 'NF>=4 && ($3=="B"||$3=="D"||$3=="b"||$3=="d"){print $4" "$2}' > /tmp/rtx_sym_sizes.txt
[ -s /tmp/rtx_sym_sizes.txt ] || { echo "FATAL: harvested zero sized data symbols from the ELF"; exit 1; }
python3 - "$ROOT" <<'PY'
import re,sys,glob,os
root=sys.argv[1]
size={}
for ln in open('/tmp/rtx_sym_sizes.txt'):
    p=ln.split()
    if len(p)==2:
        try: size[p[0]]=int(p[1],16)
        except ValueError: pass
W={'byte':1,'word':2,'dword':4,'qword':8}
load=re.compile(r'mov\s+(\w+)\s*,\s*(?:qword\s+ptr\s+)?\[\s*rip\s*\+\s*(\w+)@GOTPCREL\s*\]')
redef=re.compile(r'(?:mov|lea|xor|add|sub|pop|movzx|movsx)\s+(\w+)\s*,')
newfn=re.compile(r'RTX_FUNC\(')
store=re.compile(r'mov\s+(byte|word|dword|qword)\s+ptr\s*\[\s*(\w+)\s*(?:[+\-][^\]]*)?\]\s*,')
viol=[];checked=0
for f in sorted(glob.glob(os.path.join(root,'src/runtime/rtx/*.s'))):
    taint={}
    for n,raw in enumerate(open(f,encoding='utf-8',errors='replace'),1):
        line=raw.split('/*')[0]
        if newfn.search(line): taint={}
        m=load.search(line)
        if m:
            reg,sym=m.group(1),m.group(2)
            if sym in size and size[sym]>0: taint[reg]=(sym,size[sym])
            else: taint.pop(reg,None)
            continue
        s=store.search(line)
        if not s:
            r=redef.search(line)
            if r: taint.pop(r.group(1),None)
            continue
        if s:
            width,reg=W[s.group(1)],s.group(2)
            if reg in taint:
                sym,sz=taint[reg]; checked+=1
                if width>sz:
                    viol.append(f"{os.path.basename(f)}:{n}  {s.group(1)} ptr store ({width}B) through {reg} -> {sym} (ELF size {sz}B)")
print(f"=== RTX ASM STORE-WIDTH GATE — {checked} GOT-tainted store(s) checked against ELF symbol sizes ===")
for v in viol: print("  VIOLATION",v)
if viol:
    print(f"GATE FAIL ({len(viol)} store(s) wider than their target global)"); sys.exit(1)
print("GATE PASS (no RTX asm store exceeds the width of the global it writes)")
PY
