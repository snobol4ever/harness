#!/usr/bin/env python3
import os, re, sys

ENTRY = re.compile(r'\b(rt_wsb_alloc|rt_wsb_realloc|rt_heap_alloc_c|rt_gcheap_grow_block|gv_push|gv_reserve|RX_ALLOC|RX_REALLOC)\s*\(')
SCALAR = {'char', 'unsigned char', 'int', 'unsigned', 'unsigned int', 'size_t', 'long', 'long long', 'uint32_t', 'int32_t', 'uint8_t', 'uint16_t', 'uint64_t', 'int64_t', 'double', 'short'}
SKIP_FILES = ('gc_heap.c', 'gc_heap.h', 'rt_arena.h', 'runtime_shim.h', 'rtx_alloc_test.c', 'gc_slot_table.c', 'gc_audit_b.c')
CAST = re.compile(r'\(\s*((?:const\s+)?[A-Za-z_][A-Za-z_0-9 ]*?\s*\**)\s*\)\s*$')
DECL = re.compile(r'((?:const\s+)?[A-Za-z_][A-Za-z_0-9]*(?:\s+[A-Za-z_][A-Za-z_0-9]*)*)\s*(\**)\s*([A-Za-z_][A-Za-z_0-9]*)\s*=\s*(?:\([^()]*\)\s*)?$')


def wsb_kind(entry, stmt):
    if entry in ('rt_wsb_alloc', 'rt_wsb_realloc', 'rt_heap_alloc_c', 'RX_ALLOC', 'RX_REALLOC'):
        return True
    m = re.search(r'\b(HB_[A-Z]+)\b', stmt[stmt.index(entry):])
    return bool(m and m.group(1) in ('HB_WSB', 'HB_WSC'))


def dest_type(prefix):
    m = CAST.search(prefix)
    if m:
        return re.sub(r'\s+', ' ', m.group(1)).strip()
    m = DECL.search(prefix)
    if m and m.group(2):
        return (re.sub(r'\s+', ' ', m.group(1)) + ' ' + m.group(2)).strip()
    return None


def scalar_ptr(t):
    if t is None:
        return False
    if t.count('*') != 1:
        return False
    return re.sub(r'\s*\*+$', '', t).replace('const ', '').strip() in SCALAR


def element_bytes(entry, stmt, at):
    if entry in ('gv_push', 'gv_reserve'):
        m = re.search(r'\(\s*uint16_t\s*\)\s*HB_[A-Z]+\s*,\s*([^,]+),', stmt[at:])
        return m.group(1).strip() if m else None
    return None


def sites(root):
    out = []
    for dp, dn, fn in os.walk(root):
        for f in fn:
            if not f.endswith(('.c', '.h', '.cpp', '.inc')) or f in SKIP_FILES:
                continue
            p = os.path.join(dp, f)
            try:
                lines = open(p, errors='replace').read().split('\n')
            except OSError:
                continue
            for i, ln in enumerate(lines):
                for m in ENTRY.finditer(ln):
                    entry = m.group(1)
                    pre = ln[:m.start()]
                    if re.match(r'\s*(extern|#define|void\s*\*\s*rt_|static\s+void\s*\*\s*rx_alloc0)', ln) or re.match(r'\s*(extern\s+)?void\s*\*\s*\w+\s*\(', ln):
                        continue
                    stmt = ln
                    if entry in ('gv_push', 'gv_reserve', 'rt_gcheap_grow_block') and not wsb_kind(entry, ln[m.start():]):
                        continue
                    out.append((p, i + 1, entry, pre, ln.strip()))
    return out


def classify(root, audited):
    res = []
    for p, n, entry, pre, text in sites(root):
        rel = os.path.relpath(p, root)
        t = dest_type(pre)
        if entry in ('gv_push', 'gv_reserve'):
            es = element_bytes(entry, text, text.index(entry))
            if es in ('1u', '1'):
                res.append((rel, n, 'BYTES', 'esz 1', text))
                continue
        if scalar_ptr(t) or (entry == 'rt_wsb_realloc' and t is None and re.search(r'\b(buf|cap)\b', text) and False):
            res.append((rel, n, 'BYTES', t, text))
            continue
        hit = None
        for (arel, sub, cls, why) in audited:
            if arel == rel and sub in text:
                hit = (cls, why)
                break
        if hit:
            res.append((rel, n, hit[0], hit[1], text))
        else:
            res.append((rel, n, 'UNAUDITED', t, text))
    return res


def load(tsv):
    rows = []
    for ln in open(tsv):
        if ln.startswith('#') or not ln.strip():
            continue
        f = ln.rstrip('\n').split('\t')
        if len(f) >= 4:
            rows.append((f[0], f[1], f[2], f[3]))
    return rows


def hooks(root, tsv, cfile, sfile, minimum):
    rows = [r for r in load(tsv) if r[2].startswith('HOOKED:')]
    if len(rows) < minimum:
        print('REFUSE hooked rows=%d wanted at least %d' % (len(rows), minimum))
        return 2
    try:
        csrc = open(os.path.join(root, cfile), errors='replace').read()
        ssrc = open(os.path.join(root, sfile), errors='replace').read()
    except OSError as e:
        print('REFUSE collector body unreadable: %s' % e)
        return 2
    bad = []
    for (rel, sub, cls, why) in rows:
        try:
            own = open(os.path.join(root, rel), errors='replace').read()
        except OSError:
            bad.append('%s: file absent' % rel)
            continue
        for fn in cls[len('HOOKED:'):].split(','):
            if not re.search(r'^(?:static\s+)?void\s+%s\s*\(' % re.escape(fn), own, re.M):
                bad.append('%s: hook %s is not defined' % (rel, fn))
            if not re.search(r'\b%s\s*\(\s*\)\s*;' % re.escape(fn), csrc):
                bad.append('%s: hook %s is not called from %s' % (rel, fn, cfile))
            if not re.search(r'RTX_CALL\(\s*%s\s*\)' % re.escape(fn), ssrc):
                bad.append('%s: hook %s is not called from %s' % (rel, fn, sfile))
    print('wsb_wsc_hooked rows=%d bad=%d' % (len(rows), len(bad)))
    for b in bad:
        print('UNHOOKED ' + b)
    return 1 if bad else 0


def main(argv):
    if len(argv) >= 7 and argv[1] == '--hooks':
        return hooks(argv[2], argv[3], argv[4], argv[5], int(argv[6]))
    if len(argv) < 3 or argv[1] not in ('--check', '--list'):
        print('usage: util_wsb_producer_audit.py --check|--list <src-root> <audit.tsv> | --hooks <src-root> <audit.tsv> <collector.c> <collector.s> <min-rows>', file=sys.stderr)
        return 2
    root, tsv = argv[2], argv[3]
    audited = load(tsv)
    res = classify(root, audited)
    if argv[1] == '--list':
        for r in res:
            if r[2] != 'BYTES':
                print('%s:%d\t%s\t%s' % (r[0], r[1], r[2], r[4][:150]))
        return 0
    bad = [r for r in res if r[2] == 'UNAUDITED']
    used = set()
    for r in res:
        for k, (arel, sub, cls, why) in enumerate(audited):
            if arel == r[0] and sub in r[4]:
                used.add(k)
    stale = [audited[k] for k in range(len(audited)) if k not in used]
    nb = sum(1 for r in res if r[2] == 'BYTES')
    na = sum(1 for r in res if r[2] not in ('BYTES', 'UNAUDITED'))
    print('wsb_wsc_producers sites=%d bytes=%d audited=%d unaudited=%d stale_rows=%d' % (len(res), nb, na, len(bad), len(stale)))
    for r in bad:
        print('UNAUDITED %s:%d dest=%s %s' % (r[0], r[1], r[3], r[4][:160]))
    for a in stale:
        print('STALE %s | %s' % (a[0], a[1][:100]))
    return 1 if bad or stale else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
