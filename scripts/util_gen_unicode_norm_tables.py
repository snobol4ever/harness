#!/usr/bin/env python3
"""util_gen_unicode_norm_tables.py -- generate src/runtime/rk_unicode_norm_tables.inc, the Unicode normalization tables the Raku runtime (by_name_dispatch.c) includes.

Usage: python3 ../harness/scripts/util_gen_unicode_norm_tables.py --unicode-data UnicodeData.txt [--props DerivedNormalizationProps.txt] [--out PATH] [--check]

  --unicode-data  the UnicodeData.txt of the Unicode version the Raku lane is graded against (Roast S15-normalization is generated from Unicode 17.0.0;
                  a copy is at /home/claude_ceo/.scratch/mon/rakudo-mon/build/t/3rdparty/Unicode/17.0.0/UnicodeData.txt, the 15.0.0 one at
                  /home/resources/roast-master/3rdparty/Unicode/15.0.0/UnicodeData.txt).
  --props         a DerivedNormalizationProps.txt (the system one, /usr/share/unicode/DerivedNormalizationProps.txt, is 15.1.0): its Full_Composition_Exclusion
                  list fixes the EXPLICIT composition exclusions (CompositionExclusions.txt has not grown since Unicode 3.1); every other exclusion is computed
                  (a singleton decomposition, a decomposition that begins with a non-starter, a non-starter itself) and the computation is checked against the
                  whole 15.1 list before anything is written.
  --check         write nothing; exit 0 when the checked-in file equals what would be generated.

The generated file is passed through ../harness/scripts/util_reflow_200.py --apply (the repository's 200-column rule), so it is byte-stable under that tool and --check compares after the same pass. It holds only data (const arrays): ccc ranges, canonical and compatibility decompositions, and the primary composites that survive the
exclusions. Hangul syllables are algorithmic and not in the tables. The generator also runs its own normalizer over every assigned code point and a
set of pairs and compares it with Python's unicodedata.normalize for the code points both versions assign.
"""
import argparse, os, re, sys, unicodedata

def parse_unicode_data(path):
    ccc, canon, compat, assigned = {}, {}, {}, set()
    first = None
    for line in open(path, encoding="utf-8"):
        f = line.rstrip("\n").split(";")
        if len(f) < 6: continue
        cp = int(f[0], 16)
        name = f[1]
        if name.endswith(", First>"): first = cp; continue
        if name.endswith(", Last>"):
            for c in range(first, cp + 1): assigned.add(c)
            first = None
            continue
        assigned.add(cp)
        c = int(f[3] or "0")
        if c: ccc[cp] = c
        d = f[5]
        if d:
            if d.startswith("<"):
                compat[cp] = [int(x, 16) for x in d.split()[1:]]
            else:
                canon[cp] = [int(x, 16) for x in d.split()]
    return ccc, canon, compat, assigned

def parse_fce(path):
    out = set()
    for line in open(path, encoding="utf-8"):
        m = re.match(r"^([0-9A-F]+)(?:\.\.([0-9A-F]+))?\s*;\s*Full_Composition_Exclusion\b", line)
        if m:
            a = int(m.group(1), 16); b = int(m.group(2), 16) if m.group(2) else a
            out.update(range(a, b + 1))
    return out

def hangul(cp): return 0xAC00 <= cp <= 0xD7A3

def build(ud, props):
    ccc, canon, compat, assigned = ud
    canon = {k: v for k, v in canon.items() if not hangul(k)}
    def computed_excl(cp, explicit):
        d = canon.get(cp)
        if d is None: return False
        return cp in explicit or len(d) == 1 or ccc.get(d[0], 0) != 0 or ccc.get(cp, 0) != 0
    explicit = set()
    if props:
        fce = parse_fce(props)
        for cp in fce:
            d = canon.get(cp)
            if d is not None and len(d) == 2 and ccc.get(d[0], 0) == 0 and ccc.get(cp, 0) == 0: explicit.add(cp)
        bad = []
        for cp in sorted(assigned):
            if cp > 0x1FFFF and cp not in fce and cp not in canon: continue
            want = cp in fce
            got = computed_excl(cp, explicit)
            if want != got and cp in canon and cp <= 0x1FAFF: bad.append((cp, want, got))
        if bad: sys.exit("exclusion derivation disagrees with the props file for %d code points, first %s" % (len(bad), bad[:5]))
    comp = {}
    for cp, d in canon.items():
        if len(d) == 2 and not computed_excl(cp, explicit): comp[(d[0], d[1])] = cp
    return ccc, canon, compat, comp, explicit

def full_decomp(cp, canon, compat, use_compat):
    if hangul(cp):
        s = cp - 0xAC00
        l, v, t = 0x1100 + s // 588, 0x1161 + (s % 588) // 28, 0x11A7 + s % 28
        return [l, v] + ([t] if s % 28 else [])
    d = canon.get(cp)
    if d is None and use_compat: d = compat.get(cp)
    if d is None: return [cp]
    out = []
    for x in d: out.extend(full_decomp(x, canon, compat, use_compat))
    return out

def normalize(cps, ccc, canon, compat, comp, use_compat, compose):
    out = []
    for cp in cps: out.extend(full_decomp(cp, canon, compat, use_compat))
    i = 0
    while i < len(out):
        if ccc.get(out[i], 0) == 0: i += 1; continue
        j = i
        while j < len(out) and ccc.get(out[j], 0) != 0: j += 1
        out[i:j] = sorted(out[i:j], key=lambda c: ccc.get(c, 0))
        i = j
    if not compose: return out
    if not out: return out
    res = [out[0]]
    starter_idx = 0 if ccc.get(out[0], 0) == 0 else -1
    last_ccc = ccc.get(out[0], 0) if starter_idx == 0 else 256
    for c in out[1:]:
        cc = ccc.get(c, 0)
        composed = None
        if starter_idx >= 0:
            s = res[starter_idx]
            blocked = len(res) - 1 > starter_idx and (last_ccc >= cc or last_ccc == 0)
            if not blocked:
                if 0x1100 <= s <= 0x1112 and 0x1161 <= c <= 0x1175: composed = 0xAC00 + ((s - 0x1100) * 21 + (c - 0x1161)) * 28
                elif hangul(s) and (s - 0xAC00) % 28 == 0 and 0x11A8 <= c <= 0x11C2: composed = s + (c - 0x11A7)
                else: composed = comp.get((s, c))
        if composed is not None:
            res[starter_idx] = composed
            continue
        if cc == 0:
            starter_idx = len(res)
            last_ccc = 0
        else:
            last_ccc = cc
        res.append(c)
    return res

def selfcheck(ud, tables, assigned15):
    ccc, canon, compat, comp, _ = tables
    n = 0
    for cp in sorted(assigned15):
        if 0xD800 <= cp <= 0xDFFF: continue
        s = chr(cp)
        for form, uc, cmp_ in (("NFD", False, False), ("NFKD", True, False), ("NFC", False, True), ("NFKC", True, True)):
            want = [ord(x) for x in unicodedata.normalize(form, s)]
            got = normalize([cp], ccc, canon, compat, comp, uc, cmp_)
            if want != got: sys.exit("selfcheck %s of U+%04X: want %s got %s" % (form, cp, want, got))
            n += 1
    import random
    random.seed(7)
    pool = [cp for cp in sorted(assigned15) if not (0xD800 <= cp <= 0xDFFF) and (cp in canon or cp in compat or ccc.get(cp, 0) or cp < 0x300 or hangul(cp) or 0x1100 <= cp <= 0x11FF)]
    for _ in range(60000):
        k = random.randint(2, 5)
        seq = [random.choice(pool) for _ in range(k)]
        s = "".join(chr(c) for c in seq)
        for form, uc, cmp_ in (("NFD", False, False), ("NFKD", True, False), ("NFC", False, True), ("NFKC", True, True)):
            want = [ord(x) for x in unicodedata.normalize(form, s)]
            got = normalize(seq, ccc, canon, compat, comp, uc, cmp_)
            if want != got: sys.exit("selfcheck %s of %s: want %s got %s" % (form, [hex(c) for c in seq], want, got))
            n += 1
    return n

def emit(tables):
    ccc, canon, compat, comp, _ = tables
    lines = []
    w = lines.append
    def rows(items, per=8):
        out = []
        for i in range(0, len(items), per): out.append("    " + " ".join(items[i:i + per]))
        return out
    w("/* rk_unicode_norm_tables.inc -- GENERATED by ../harness/scripts/util_gen_unicode_norm_tables.py from UnicodeData.txt; do not edit. Data only. */")
    ranges = []
    for cp in sorted(ccc):
        if ranges and ranges[-1][1] + 1 == cp and ranges[-1][2] == ccc[cp]: ranges[-1][1] = cp
        else: ranges.append([cp, cp, ccc[cp]])
    w("static const unsigned int rk_un_ccc[][3] = {")
    lines += rows(["{0x%X,0x%X,%d}," % (a, b, c) for a, b, c in ranges], 6)
    w("};")
    w("static const unsigned int rk_un_ccc_n = %d;" % len(ranges))
    cs = sorted(canon)
    w("static const unsigned int rk_un_canon[][3] = {")
    lines += rows(["{0x%X,0x%X,0x%X}," % (cp, canon[cp][0], canon[cp][1] if len(canon[cp]) > 1 else 0) for cp in cs], 4)
    w("};")
    w("static const unsigned int rk_un_canon_n = %d;" % len(cs))
    ks = sorted(compat)
    pool, offs = [], []
    for cp in ks:
        offs.append((cp, len(pool), len(compat[cp])))
        pool.extend(compat[cp])
    w("static const unsigned int rk_un_compat[][3] = {")
    lines += rows(["{0x%X,%d,%d}," % t for t in offs], 5)
    w("};")
    w("static const unsigned int rk_un_compat_n = %d;" % len(ks))
    w("static const unsigned int rk_un_compat_pool[] = {")
    lines += rows(["0x%X," % x for x in pool], 10)
    w("};")
    cl = sorted((a, b, c) for (a, b), c in comp.items())
    w("static const unsigned int rk_un_comp[][3] = {")
    lines += rows(["{0x%X,0x%X,0x%X}," % t for t in cl], 4)
    w("};")
    w("static const unsigned int rk_un_comp_n = %d;" % len(cl))
    return "\n".join(lines) + "\n"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--unicode-data", required=True)
    ap.add_argument("--props", default="/usr/share/unicode/DerivedNormalizationProps.txt")
    ap.add_argument("--ref-data", default="/home/resources/roast-master/3rdparty/Unicode/15.0.0/UnicodeData.txt")
    ap.add_argument("--out", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "runtime", "rk_unicode_norm_tables.inc"))
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    ud = parse_unicode_data(a.unicode_data)
    tables = build(ud, a.props if os.path.exists(a.props) else None)
    ref = parse_unicode_data(a.ref_data)
    n = selfcheck(ud, tables, ref[3] & ud[3])
    text = emit(tables)
    longest = max(len(l) for l in text.split("\n"))
    if longest > 200: sys.exit("generated line of %d columns" % longest)
    import subprocess, tempfile
    here = os.path.dirname(os.path.abspath(__file__))
    def reflowed(path):
        subprocess.run([sys.executable, os.path.join(here, "util_reflow_200.py"), "--apply", path], check=True, stdout=subprocess.DEVNULL)
        return open(path, encoding="utf-8").read()
    if a.check:
        with tempfile.TemporaryDirectory() as td:
            tmp = os.path.join(td, "rk_unicode_norm_tables.inc")
            open(tmp, "w", encoding="utf-8").write(text)
            text = reflowed(tmp)
        cur = open(a.out, encoding="utf-8").read() if os.path.exists(a.out) else ""
        print("FRESH" if cur == text else "STALE: the checked-in tables differ from the generator's output")
        sys.exit(0 if cur == text else 1)
    open(a.out, "w", encoding="utf-8").write(text)
    reflowed(a.out)
    print("wrote %s: %d ccc ranges, %d canonical, %d compat, %d composites; selfcheck %d comparisons against unicodedata %s; longest line %d before the 200-column reflow" % (a.out, len(tables[0]), len(tables[1]), len(tables[2]), len(tables[3]), n, unicodedata.unidata_version, longest))

main()
