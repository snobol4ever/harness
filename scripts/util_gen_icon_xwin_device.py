#!/usr/bin/env python3
"""util_gen_icon_xwin_device.py -- the Icon window device layer, regeneration step one (CTO-578, phase 1).

Runs the oracle's own translator (src/rtt/rtt, with -x) over its five window .r sources in a scratch copy,
then copies the five x*.c files and src/common/xwindow.c to --out. Writes nothing under the oracle tree.
rc 0 all six made (with --syntax, all six compile); rc 1 the translator or a syntax check failed (the first
file named); rc 2 refused (a source is missing, usage).
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
CC_SLOT = os.path.join(HERE, "util_cc_slot.sh")
DEFAULT_SRC = "/home/resources/icon-master/src"
RUN_SOURCES = ["rwindow.r", "rcolor.r", "rimage.r", "rwinrsc.r", "rwinsys.r"]
RUN_INCLUDES = ["rxwin.ri", "rxrsc.ri"]
PLAIN_SOURCE = os.path.join("common", "xwindow.c")
DEFINE_H = "#define Config linux\n#define Graphics 1\n"


def refuse(msg):
    print("REFUSE(2): " + msg)
    sys.exit(2)


def tail(text):
    return (text or "").strip()[-400:]


def build(src, out, scratch, syntax):
    shutil.copytree(os.path.join(src, "h"), os.path.join(scratch, "h"))
    shutil.copytree(os.path.join(src, "runtime"), os.path.join(scratch, "runtime"))
    os.makedirs(os.path.join(scratch, "common"))
    shutil.copyfile(os.path.join(src, PLAIN_SOURCE), os.path.join(scratch, PLAIN_SOURCE))
    with open(os.path.join(scratch, "h", "define.h"), "w") as f:
        f.write(DEFINE_H)
    rt = os.path.join(scratch, "runtime")
    os.makedirs(os.path.join(scratch, "rtt"))
    rtt = os.path.join(scratch, "rtt", "rtt")
    shutil.copy2(os.path.join(src, "rtt", "rtt"), rtt)
    r = subprocess.run([rtt, "-x"] + RUN_SOURCES, cwd=rt, capture_output=True, text=True)
    if r.returncode != 0:
        print("XWIN-GEN FAIL translator rc=%d: %s" % (r.returncode, tail(r.stderr or r.stdout)))
        return 1
    cfiles = [os.path.join(rt, "x" + name[:-2] + ".c") for name in RUN_SOURCES]
    cfiles.append(os.path.join(scratch, PLAIN_SOURCE))
    for p in cfiles:
        if not os.path.isfile(p):
            print("XWIN-GEN FAIL not made: %s" % os.path.basename(p))
            return 1
    if syntax:
        for p in cfiles:
            r = subprocess.run(["bash", CC_SLOT, "gcc", "-fsyntax-only", "-w", os.path.basename(p)],
                               cwd=os.path.dirname(p), capture_output=True, text=True)
            if r.returncode != 0:
                print("XWIN-GEN FAIL syntax %s rc=%d: %s" % (os.path.basename(p), r.returncode, tail(r.stderr or r.stdout)))
                return 1
    os.makedirs(out, exist_ok=True)
    for p in cfiles:
        dst = os.path.join(out, os.path.basename(p))
        shutil.copyfile(p, dst)
        with open(dst, "rb") as f:
            lines = f.read().count(b"\n")
        print("XWIN-GEN %s %d" % (os.path.basename(p), lines))
    print("XWIN-GEN files=%d" % len(cfiles))
    return 0


def main():
    ap = argparse.ArgumentParser(description="Regenerate the Icon window device C from the oracle's sources.")
    ap.add_argument("--src", default=DEFAULT_SRC)
    ap.add_argument("--out", required=True)
    ap.add_argument("--syntax", action="store_true")
    a = ap.parse_args()
    src = os.path.abspath(a.src)
    out = os.path.abspath(a.out)
    need = ["rtt/rtt", "h/graphics.h", PLAIN_SOURCE] + [os.path.join("runtime", n) for n in RUN_SOURCES + RUN_INCLUDES]
    missing = [n for n in need if not os.path.isfile(os.path.join(src, n))]
    if missing:
        refuse("the oracle source at %s lacks %s" % (src, " ".join(missing)))
    parent = os.path.dirname(out)
    os.makedirs(parent, exist_ok=True)
    scratch = tempfile.mkdtemp(prefix="xwgen-scratch-", dir=parent)
    sys.exit(build(src, out, scratch, a.syntax))


if __name__ == "__main__":
    main()
