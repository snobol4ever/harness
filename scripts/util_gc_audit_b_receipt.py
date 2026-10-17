#!/usr/bin/env python3
"""util_gc_audit_b_receipt.py -- THE ONE READER OF A PASS-B LOG AGAINST THE HOLDER LEDGER (cfo 2026-09-27, CEO-1307).

    util_gc_audit_b_receipt.py holders ERRFILE SO DECL      the auditor gate's listing: HOLDER <name> <count> <ledger status>,
                                                             then OPENROWS and TOTALHOLDERS (the gate greps these lines)
    util_gc_audit_b_receipt.py receipt LOG SO [DECL]        an HQ's receipt: candidates=N findings=M audited=A, one UNCLOSED
                                                             line per holder that counts, rc 0 when findings=0, rc 1 otherwise

WHY ONE FILE.  CEO-1307 ruled that a receipt of the auditor-retirement row counts FINDINGS, the candidates whose holder the
ledger does not close, beside the raw CANDIDATE count kept visible -- ARCH-GC section 9's grant counts only findings that
survived the lane owner's reading.  The auditor gate already resolved holders this way inline; a second copy for the receipts
would be the drift this fleet keeps paying for, so the gate calls this file and so does every HQ.

HOW A HOLDER IS NAMED.  A candidate line carries in=<module>+0x<offset>/<symbol-or-region> for a static (dladdr cannot name a
file-local static, so the offset is resolved through nm -S on the SAME auditor library that produced the log) and in=<region>
for a stack word (cstack, parked, ...), and in=- for a word inside an opaque heap block.  A function-local static's per-unit
serial (lnv.3) is dropped, because it moves whenever its file gains or loses a static.

WHAT CLOSES A HOLDER.  holders mode reports the ledger status as the gate has always read it.  receipt mode counts a candidate
as a FINDING unless its holder is DECLARED: an UNDECLARED holder, an OPEN row, and a CURED holder named again (REGRESSED -- a
receipt certifies that the cure still holds) all count.  Statics and heap interiors are never declared by population (CEO-1307
(iii)); the stack populations are, with their measured classes in the ledger's reasons.

Deleted with the auditor: it is on the retirement row's deletion list.
"""
import re
import subprocess
import sys

CAND = re.compile(r"CANDIDATE-LOST-ROOT at=\S+ in=(\S+)")


def nm_symbols(so):
    out = []
    for ln in subprocess.run(["nm", "-S", "--defined-only", so], capture_output=True, text=True).stdout.splitlines():
        f = ln.split()
        if len(f) < 4:
            continue
        try:
            out.append((int(f[0], 16), int(f[1], 16), f[3]))
        except ValueError:
            continue
    return out


def holder_name(h, syms):
    mo = re.match(r"^.*\+0x([0-9a-f]+)/(.*)$", h)
    if mo:
        off = int(mo.group(1), 16)
        tail = mo.group(2)
        hit = [s for s in syms if s[0] <= off < s[0] + s[1]]
        name = hit[0][2] if hit else (tail if tail != "writable-PT_LOAD" else "UNRESOLVED+0x%x" % off)
    else:
        name = h
    return re.sub(r"\.\d+$", "", name)


def read_ledger(decl):
    st = {}
    for ln in open(decl, encoding="utf-8"):
        ln = ln.strip()
        if not ln or ln.startswith("#"):
            continue
        f = ln.split(None, 2)
        if len(f) >= 2:
            st[f[0]] = f[1]
    return st


def count(logf, so):
    syms = nm_symbols(so)
    seen, audited = {}, 0
    for ln in open(logf, errors="replace"):
        if "audited=1" in ln:
            audited += 1
        m = CAND.search(ln)
        if not m:
            continue
        k = holder_name(m.group(1), syms)
        seen[k] = seen.get(k, 0) + 1
    return seen, audited


def main(argv):
    if len(argv) < 4 or argv[1] not in ("holders", "receipt"):
        sys.stderr.write(__doc__)
        return 2
    mode, logf, so = argv[1], argv[2], argv[3]
    decl = argv[4] if len(argv) > 4 else "../harness/scripts/gc_audit_b_declared.txt"
    ledger = read_ledger(decl)
    seen, audited = count(logf, so)
    if mode == "holders":
        for k in sorted(seen):
            print("HOLDER %s %d %s" % (k, seen[k], ledger.get(k, "UNDECLARED")))
        print("OPENROWS %d" % sum(1 for v in ledger.values() if v == "OPEN"))
        print("TOTALHOLDERS %d" % len(seen))
        return 0
    cands = sum(seen.values())
    unclosed = {k: n for k, n in seen.items() if ledger.get(k) != "DECLARED"}
    print("candidates=%d findings=%d audited=%d" % (cands, sum(unclosed.values()), audited))
    for k in sorted(unclosed):
        s = ledger.get(k, "UNDECLARED")
        print("UNCLOSED %s %d %s" % (k, unclosed[k], "REGRESSED" if s == "CURED" else s))
    return 0 if not unclosed else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
