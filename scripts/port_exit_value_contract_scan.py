#!/usr/bin/env python3
# port_exit_value_contract_scan.py -- the analysis half of test_gate_port_exit_value_contract.sh.
#
# THE CONTRACT BEING CHECKED (row port-exit-value-contract-untagged-rax-forges-dt-fail):
#   A procedure-level success exit forwards rax:rdx as the procedure's DESCR_t return value
#   (`<proc>_γ:` begins `mov rdi, rax` / `mov rsi, rdx`).  The caller then detects a failed nested
#   call with `cmp al, 104` (DT_FAIL = 0x68, descr.h; DESCR_t.v is uint8_t so the tag IS the low
#   byte of rax).  Therefore EVERY transfer that reaches such an exit must arrive with rax:rdx
#   holding a real DESCR_t.  A transfer arriving with a raw untagged value in rax can forge
#   DT_FAIL whenever that value's low byte happens to be 104 -- a silent, data-dependent wrong
#   answer that cascades a spurious ω up the live call chain.
#
# WHY GENERATION-TIME AND NOT A RUNTIME ASSERT: the defect is data-dependent, so a runtime assert
# fires only on the inputs that already broke.  This reads the emitted TEXT and answers the
# question for every path, including the ones no input has exercised yet.
#
# WHAT IT CAN AND CANNOT SEE (stated because an instrument's blind spots are part of its result):
#   - It walks BACKWARD linearly across fall-through boundaries to the defining write of rax.
#     That is dataflow-lite, not a full CFG: a block entered by a jump from elsewhere may carry a
#     different rax there.  A definite raw-payload load found this way is a TRUE positive; an
#     "OK" verdict is only as strong as the fall-through assumption, so OK is reported, never
#     certified, and the counts are printed separately.
#   - It reads mode-4 TEXT only.  Per MODES MAY DIVERGE this verdict names its mode and does not
#     bind mode 3.
import re, sys, json

LBL     = re.compile(r'^([A-Za-z_.$][\w.$αβγω]*):')
MEMSLOT = re.compile(r'(?:qword|dword)\s+ptr\s+\[\s*(\w+)\s*\+\s*(\d+)\s*\]')
WRAX    = re.compile(r'^\s*(mov|movzx|movsx|lea|add|sub|imul|xor|and|or|shl|shr|sar|neg|not|set\w+|cqo|cdq|pop)\s+(rax|eax|ax|al)\b\s*(?:,\s*(.*))?$')
WRDX    = re.compile(r'^\s*(mov|movzx|movsx|lea|pop)\s+(rdx|edx|dx|dl)\b\s*(?:,\s*(.*))?$')
CALL    = re.compile(r'^\s*call\b')
JMP     = re.compile(r'^\s*jmp\b')
RET     = re.compile(r'^\s*(ret|jmp\s+rcx)\b')
XFER    = re.compile(r'^\s*(j[a-z]+)\s+([\w.$αβγω]+)\s*$')
CALLEE  = re.compile(r'^\s*call\s+\**([A-Za-z_][\w.$]*)')
# ⛔ THE CALL ARM IS AN ALLOW-LIST, NOT AN ASSUMPTION (seat03 2026-09-01).  It previously returned OK_CALL
# for EVERY `call`, with a detail string that asserted "a DESCR-returning call" -- a cause the code never
# tested.  Measured: 9 of the 10 OK_CALL transfers in the witness set call rt_relop_overload / rt_jct_relop,
# both of which return `int` (arithmetic.c:58, by_name_dispatch.c:4951; rt_relop_overload delivers its DESCR
# through an `out` pointer, not in rax).  Only rt_assign_var genuinely returns DESCR_t.  So the census's
# RAW count was HALF the true population, and curing only the RAW sites would have turned this gate GREEN
# with 9 contract violations still standing -- precisely the "fix the known instances and leave a fourth
# waiting" outcome this row's DONE-WHEN exists to prevent.  The set is derived MECHANICALLY from the runtime
# sources by the gate (never hand-maintained: a hand list is only as correct as the last person to edit it).
DESCR_FNS = set()

def parse(path):
    """-> list of (lineno, label_or_None, instruction_or_None); one entry per instruction."""
    out=[]
    for n,raw in enumerate(open(path,encoding="utf-8",errors="replace"),1):
        line=raw.split('#')[0].rstrip()
        if not line.strip(): continue
        lab=None
        m=LBL.match(line)
        if m:
            lab=m.group(1); line=line[m.end():]
            out.append((n,lab,None))
        for part in line.split(';'):
            p=part.strip()
            if p: out.append((n,None,p))
    return out

def rax_state_at(ins, idx):
    """Walk backward from idx to the defining write of rax. Returns (verdict, detail, line)."""
    i=idx-1; rdx_src=None; crossed=0
    while i>=0:
        n,lab,ist=ins[i]
        if ist is None:
            # a label boundary: keep walking only if the block above falls through
            j=i-1
            while j>=0 and ins[j][2] is None: j-=1
            if j<0: return ("UNKNOWN","reached top of file",n)
            if JMP.match(ins[j][2]) or RET.match(ins[j][2]):
                return ("UNKNOWN","block entered only by jump; no fall-through predecessor",n)
            crossed+=1
            if crossed>8: return ("UNKNOWN","fall-through walk exceeded 8 blocks",n)
            i-=1; continue
        if CALL.match(ist):
            m=CALLEE.search(ist)
            who=m.group(1) if m else "?"
            if who in DESCR_FNS:
                return ("OK_CALL","rax:rdx from a DESCR-returning call: %s" % who, n)
            return ("RAW","rax<-return of %s, which does NOT return DESCR_t: untagged value in the tag register" % who, n)
        if rdx_src is None:
            m=WRDX.match(ist)
            if m and m.group(3): rdx_src=(m.group(3), n)
        m=WRAX.match(ist)
        if m:
            src=(m.group(3) or "").strip()
            ma=MEMSLOT.search(src)
            if ma and rdx_src:
                mb=MEMSLOT.search(rdx_src[0])
                if mb and mb.group(1)==ma.group(1) and int(mb.group(2))==int(ma.group(2))+8:
                    return ("OK_PAIRED","rax<-[%s+%s] with rdx<-[%s+%s]: a real DESCR_t"
                            % (ma.group(1),ma.group(2),mb.group(1),mb.group(2)), n)
            if ma:
                return ("RAW","rax<-%s but rdx NOT loaded from [%s+%d]: untagged value in the tag register"
                        % (src[:50], ma.group(1), int(ma.group(2))+8), n)
            return ("RAW","rax<-%s (computed, never normalized to a DESCR_t)" % src[:50], n)
        i-=1
    return ("UNKNOWN","no defining write found",ins[idx][0])

def scan(path):
    ins=parse(path)
    # procedure exits that FORWARD rax as the return DESCR
    exits=set()
    for k,(n,lab,ist) in enumerate(ins):
        if lab and lab.endswith(("_γ","_gamma")):
            for m in range(k+1, min(k+6,len(ins))):
                if ins[m][2] and re.match(r'^\s*mov\s+rdi\s*,\s*rax\b', ins[m][2]):
                    exits.add(lab); break
    findings=[]
    for k,(n,lab,ist) in enumerate(ins):
        if not ist: continue
        m=XFER.match(ist)
        if not m or m.group(2) not in exits: continue
        v,detail,srcline=rax_state_at(ins,k)
        findings.append(dict(line=n,target=m.group(2),mnem=m.group(1),verdict=v,detail=detail,srcline=srcline))
    return dict(file=path,exits=sorted(exits),findings=findings)

if __name__=="__main__":
    args=[a for a in sys.argv[1:]]
    fns=[a.split("=",1)[1] for a in args if a.startswith("--descr-fns=")]
    args=[a for a in args if not a.startswith("--descr-fns=")]
    if not fns:
        sys.stderr.write("port_exit_value_contract_scan: REFUSING -- --descr-fns=<file> is required.\n"
                         "The call arm must know which runtime functions actually return DESCR_t; assuming\n"
                         "every call does is what made this instrument report half the true count.\n")
        sys.exit(2)
    try: DESCR_FNS.update(w.strip() for w in open(fns[0]) if w.strip())
    except OSError as e:
        sys.stderr.write("port_exit_value_contract_scan: REFUSING -- cannot read %s: %s\n" % (fns[0], e)); sys.exit(2)
    if not DESCR_FNS:
        sys.stderr.write("port_exit_value_contract_scan: REFUSING -- %s is empty; a zero-symbol allow-list\n"
                         "would reclassify every call as a violation and read as a catastrophe.\n" % fns[0])
        sys.exit(2)
    res=[scan(p) for p in args]
    print(json.dumps(res,ensure_ascii=False))
