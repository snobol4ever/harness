#!/usr/bin/env python3
import os, sys, subprocess, select, fcntl, time
def cells_of(path):
    out, tag, body = [], None, []
    for ln in open(path).read().split("\n"):
        if ln.startswith("=== "):
            if tag is not None: out.append((tag, body))
            tag, body = ln[4:].strip(), []
        elif tag is not None: body.append(ln)
    if tag is not None: out.append((tag, body))
    for i, (t, b) in enumerate(out):
        while b and b[-1] == "": b.pop()
    return out
def drain(fd, quiet):
    got = b""
    while True:
        r, _, _ = select.select([fd], [], [], quiet)
        if not r: break
        d = os.read(fd, 65536)
        if not d: break
        got += d
    return got
def main():
    scrip, boot, cells = sys.argv[1], sys.argv[2], cells_of(sys.argv[3])
    cr, cw = os.pipe(); tr, tw = os.pipe(); orr, ow = os.pipe()
    a, b, c, d = (fcntl.fcntl(x, fcntl.F_DUPFD, 100) for x in (cr, tw, cw, tr))
    e, f = (fcntl.fcntl(x, fcntl.F_DUPFD, 100) for x in (orr, ow))
    for x in (cr, cw, tr, tw, orr, ow): os.close(x)
    cr, tw, cw, tr, orr, ow = a, b, c, d, e, f
    for x in (cw, tr, orr): os.set_inheritable(x, False)
    def pre():
        os.dup2(cr, 3); os.dup2(tw, 4)
    p = subprocess.Popen([scrip, "--session", boot], stdin=subprocess.DEVNULL, stdout=ow, stderr=ow, preexec_fn=pre, close_fds=False)
    os.close(cr); os.close(tw); os.close(ow)
    ctl = b""
    for n, (tag, body) in enumerate(cells, 1):
        os.write(cw, ("%d %s\n" % (len(body), tag)).encode() + "".join(l + "\n" for l in body).encode())
        t0 = time.time()
        ans = None
        while ans is None:
            r, _, _ = select.select([tr], [], [], 60)
            if not r: ans = "NO ANSWER IN 60 SECONDS"; break
            dd = os.read(tr, 4096)
            if not dd: ans = "THE SESSION ENDED"; break
            ctl += dd
            while b"\n" in ctl:
                ln, ctl = ctl.split(b"\n", 1)
                ln = ln.decode(errors="replace")
                if ln.startswith("DONE"): ans = ln
                else: sys.stdout.write("  ctl: %s\n" % ln)
        out = drain(orr, 0.05)
        sys.stdout.write("--- cell %d %s\n" % (n, tag))
        sys.stdout.write(out.decode(errors="replace"))
        sys.stdout.write("--- %s\n" % ans)
        if os.environ.get("DRIVE_TIMES"): sys.stderr.write("cell %d %s %.2fs\n" % (n, tag, time.time() - t0))
        if not ans.startswith("DONE"): break
    os.close(cw)
    try: rc = p.wait(timeout=30)
    except subprocess.TimeoutExpired: p.kill(); rc = -9
    out = drain(orr, 0.05)
    if out: sys.stdout.write("--- after the last cell\n" + out.decode(errors="replace"))
    sys.stdout.write("--- the session ended %d\n" % rc)
    return 0
sys.exit(main())
