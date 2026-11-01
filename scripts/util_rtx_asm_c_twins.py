#!/usr/bin/env python3
"""util_rtx_asm_c_twins.py -- an asm leaf's numeric #define that the C side defines under the SAME NAME must carry the same number.

WHY (hq_collector 2026-11-01, the cto's pointer on rt_gc_trail_run): the rtx leaves spell layout numbers as their own #defines, and a copy that nobody ties to
the C constant freezes the day the C constant grows (rt_gc_trail_run walked the Prolog trail from base + 64 after PL_TR_HEADER_BYTES became 128).  A name scan
cannot see a bare literal in an instruction; it sees every define.  Population: the numeric #defines of src/runtime/rtx/*.s and rtx_abi.inc, against every
numeric #define of the same name in the C, C++ and .inc files under src.  RED: an asm value that is none of the C values.  REFUSE (rc 2): fewer than --min-asm asm
defines or no twin at all (a census over an empty population reports zero violations while measuring nothing).
usage: util_rtx_asm_c_twins.py [--min-asm N] SRC_DIR | --selftest      rc 0 green, 1 red, 2 refuse
"""
import collections, glob, os, re, sys, tempfile

DEF = re.compile(r"^\s*#\s*define\s+([A-Za-z_]\w*)\s+(\(?-?(?:0[xX][0-9a-fA-F]+|\d+)[uUlL]*\)?)\s*(?:/\*.*|//.*)?$")


def num(text):
    text = text.strip("()").rstrip("uUlL")
    try:
        return int(text, 0)
    except ValueError:
        return None


def scan(path, names=None):
    rows = collections.defaultdict(list)
    with open(path, encoding="utf-8", errors="replace") as fh:
        for i, line in enumerate(fh, 1):
            m = DEF.match(line)
            if not m or (names is not None and m.group(1) not in names):
                continue
            v = num(m.group(2))
            if v is not None:
                rows[m.group(1)].append((os.path.basename(path) if names is None else path, i, v))
    return rows


def census(src, min_asm):
    asm_files = sorted(glob.glob(os.path.join(src, "runtime", "rtx", "*.s")) + glob.glob(os.path.join(src, "runtime", "rtx", "*.inc")))
    asm = collections.defaultdict(list)
    for f in asm_files:
        for k, v in scan(f).items():
            asm[k] += v
    skip = set(os.path.realpath(f) for f in asm_files)
    cdef = collections.defaultdict(list)
    for ext in ("c", "h", "inc", "cpp"):
        for f in glob.glob(os.path.join(src, "**", "*." + ext), recursive=True):
            if os.path.realpath(f) in skip:
                continue
            for k, v in scan(f, asm).items():
                cdef[k] += [(os.path.relpath(f, src), i, x) for _, i, x in v]
    differ, ambiguous, twins = [], 0, 0
    for name in sorted(asm):
        if name not in cdef:
            continue
        twins += 1
        avals, cvals = {v for _, _, v in asm[name]}, {v for _, _, v in cdef[name]}
        if len(cvals) > 1:
            ambiguous += 1
        if not avals <= cvals:
            differ.append((name, asm[name][:3], cdef[name][:4]))
    return len(asm), twins, differ, ambiguous


def selftest():
    def tree(skew):
        d = tempfile.mkdtemp(prefix="twins_selftest_")
        os.makedirs(os.path.join(d, "runtime", "rtx"))
        os.makedirs(os.path.join(d, "runtime", "rt"))
        with open(os.path.join(d, "runtime", "rtx", "a.s"), "w") as f:
            f.write("#define SAME 8\n#define SKEW 64\n#define ONLYASM 3\n#define HEXED 0x20\n")
        with open(os.path.join(d, "runtime", "rt", "h.h"), "w") as f:
            f.write("#define SAME 8\n#define SKEW %d\n#define HEXED (32u)\n#define ONLYC 9\n" % skew)
        return d
    na, nt, bad, _ = census(tree(160), 1)
    ok_red = (na, nt, [b[0] for b in bad]) == (4, 3, ["SKEW"])
    na, nt, bad, _ = census(tree(64), 1)
    ok_green = (na, nt, bad) == (4, 3, [])
    print("SELFTEST arms: skewed twin red %s, equal twins green %s" % ("ok" if ok_red else "WRONG", "ok" if ok_green else "WRONG"))
    return 0 if ok_red and ok_green else 1


def main(argv):
    if argv[:1] == ["--selftest"]:
        return selftest()
    min_asm = 50
    if argv[:1] == ["--min-asm"]:
        min_asm, argv = int(argv[1]), argv[2:]
    if len(argv) != 1 or not os.path.isdir(argv[0]):
        print("REFUSE(2): usage: util_rtx_asm_c_twins.py [--min-asm N] SRC_DIR | --selftest")
        return 2
    na, nt, differ, amb = census(argv[0], min_asm)
    print("RTX_ASM_C_TWINS asm_defines=%d same_named_in_c=%d differ=%d ambiguous_in_c=%d" % (na, nt, len(differ), amb))
    if na < min_asm or nt == 0:
        print("REFUSE(2): the population is empty or too small (asm defines %d < %d, or no same-named C define): nothing was measured" % (na, min_asm))
        return 2
    for name, a, c in differ:
        print("DIFFER %s asm %s C %s" % (name, a, c))
    return 1 if differ else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
