#!/usr/bin/env python3
"""util_screen_run.py -- THE SCREEN ROAD: run one graphics program with no human, on a virtual X display of its own, and write what its
screen shows (Lon 2026-11-14 15:4x CST, in the grader's window, verbatim: "We are absolutely DOING GRAPHICS, X-windows. Yes? We should be
able to do off-line (i.e. without physical window in which a human user is required) GUI tests. Yes?"; skill icon section 1).

  python3 util_screen_run.py [--out FILE] [--cap S] [--keep DUMP.xwd] -- CMD ARG...
  python3 util_screen_run.py --probe

It starts an Xvfb (1024x768, 24 bits, a display number the server picks, no TCP), runs CMD with DISPLAY set and the caller's standard
input, and dumps the root window (xwd) every POLL seconds. THE ANSWER is FILE (default screen.dump, in the current directory), one line:

  screen 1024x768 md5 <md5 of the pixel bytes>     the screen held still for STILL readings in a row (three seconds) with something drawn on it
  screen none                                      CMD ended before it ever showed a still, drawn screen
  screen unstable                                  the screen never held still within the cap (an animation has no one picture)

Only the pixel bytes are hashed: the dump's colour table carries padding that differs from run to run (MEASURED 2026-11-14: 256 bytes
differ between two dumps of one picture). A program that draws and then waits for a mouse or a key never ends by itself, so once its
screen is still THE ROAD ENDS IT (SIGTERM, then SIGKILL) and exits 0; what such a program printed before it was ended is NOT passed on,
since how much of it had left the program's buffer is an accident of the run, and its screen is its whole answer. A program that ends by
itself has its standard output passed on whole, its exit status is this script's, and its screen line is the last still picture it
showed, or none. Standard error is passed on as it comes. rc 2 with a REFUSE line when Xvfb or xwd is missing or the display does not
start: a run that cannot measure never reads as a verdict.
"""
import hashlib, os, signal, struct, subprocess, sys, tempfile, time
POLL, STILL = 0.5, 6
def refuse(msg):
    sys.stderr.write(f"REFUSE(2) util_screen_run.py: {msg}\n"); sys.exit(2)
def which(name):
    for d in os.environ.get("PATH", "/usr/bin:/bin").split(os.pathsep):
        p = os.path.join(d, name)
        if os.access(p, os.X_OK): return p
    return None
def start_display():
    xvfb = which("Xvfb") or refuse("no Xvfb on PATH (the virtual display the screen road runs on)")
    which("xwd") or refuse("no xwd on PATH (the screen is read with it)")
    r, w = os.pipe()
    p = subprocess.Popen([xvfb, "-displayfd", str(w), "-screen", "0", "1024x768x24", "-nolisten", "tcp", "-ac"], pass_fds=(w,),
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    os.close(w); buf = b""; t0 = time.time()
    while b"\n" not in buf:
        if p.poll() is not None or time.time() - t0 > 30: p.kill(); refuse("the virtual display did not start")
        import select
        if select.select([r], [], [], 0.5)[0]:
            c = os.read(r, 64)
            if not c: p.kill(); refuse("the virtual display closed its number pipe")
            buf += c
    os.close(r)
    return p, ":" + buf.decode().strip()
def pixels(display):
    try:
        d = subprocess.run(["xwd", "-root", "-silent", "-display", display], capture_output=True, timeout=30).stdout
    except subprocess.TimeoutExpired:
        return None, b""
    if len(d) < 100: return None, d
    hsize, ncolors = struct.unpack(">I", d[:4])[0], struct.unpack(">I", d[76:80])[0]
    w, h = struct.unpack(">II", d[16:24])
    pix = d[hsize + ncolors * 12:]
    drawn = len(set(pix[::997])) > 1 or len(set(pix)) > 1
    return (f"{w}x{h}", hashlib.md5(pix).hexdigest(), drawn), d
def run(cmd, out, cap, keep):
    xv, display = start_display()
    env = dict(os.environ, DISPLAY=display); env.pop("XAUTHORITY", None)
    so = tempfile.TemporaryFile()
    try:
        child = subprocess.Popen(cmd, env=env, stdout=so, start_new_session=True)
        last, run_len, still, still_dump, t0, ended_by_road, unstable = None, 0, None, b"", time.time(), False, False
        while True:
            alive = child.poll() is None
            if not alive: break
            shot, dump = pixels(display)
            if shot and shot[2]:
                run_len = run_len + 1 if shot == last else 1; last = shot
                if run_len >= STILL: still, still_dump = shot, dump; ended_by_road = True; break
            else: last, run_len = None, 0
            if time.time() - t0 > cap: unstable = True; ended_by_road = True; break
            time.sleep(POLL)
        if child.poll() is None:
            for sig in (signal.SIGTERM, signal.SIGKILL):
                try: os.killpg(child.pid, sig)
                except ProcessLookupError: break
                try: child.wait(timeout=3); break
                except subprocess.TimeoutExpired: continue
        rc = child.wait()
    finally:
        xv.terminate()
        try: xv.wait(timeout=5)
        except subprocess.TimeoutExpired: xv.kill()
    line = "screen unstable" if unstable else (f"screen {still[0]} md5 {still[1]}" if still else "screen none")
    with open(out, "w") as f: f.write(line + "\n")
    if keep and still_dump:
        with open(keep, "wb") as f: f.write(still_dump)
    if not ended_by_road:
        so.seek(0); sys.stdout.buffer.write(so.read()); sys.stdout.flush()
        return rc if rc >= 0 else 128 - rc
    return 0
def probe():
    """Five arms on scratch with the X distribution's own demo clients (xlogo, a still picture that waits for ever; ico, an animation): no arm needs
    Icon. rc 0 all green, 1 an arm red, 2 cannot measure. (xsetroot is no client for this: MEASURED, its colour never reaches the dump of an Xvfb root.)"""
    for c in ("xlogo", "ico"): which(c) or refuse(f"--probe needs {c} (x11-apps)")
    me = os.path.abspath(__file__); bad = 0
    with tempfile.TemporaryDirectory(prefix="screen_probe_") as td:
        def go(name, script, cap="25"):
            r = subprocess.run([sys.executable, me, "--out", f"{name}.dump", "--cap", cap, "--", "bash", "-c", script], cwd=td, capture_output=True, text=True, timeout=120)
            return r.returncode, r.stdout, open(os.path.join(td, f"{name}.dump")).read().strip() if os.path.exists(os.path.join(td, f"{name}.dump")) else ""
        a = go("still", "echo printed-before; exec xlogo -geometry 200x200+0+0")
        b = go("still2", "exec xlogo -geometry 200x200+0+0")
        c = go("other", "exec xlogo -geometry 300x150+0+0")
        d = go("ends", "echo whole-output; exit 3")
        e = go("moving", "exec ico -sleep 0.05", cap="8")
        arms = [("a waiting program is ended at its still screen, rc 0, its text withheld", a[0] == 0 and a[1] == "" and a[2].startswith("screen 1024x768 md5 ")),
                ("the same picture gives the same line twice", a[2] == b[2] and a[2] != ""),
                ("another picture gives another line", c[2].startswith("screen 1024x768 md5 ") and c[2] != a[2]),
                ("a program that ends alone keeps its text and its status, screen none", d[0] == 3 and d[1] == "whole-output\n" and d[2] == "screen none"),
                ("a screen that never holds still is unstable", e[0] == 0 and e[2] == "screen unstable")]
        for what, ok in arms:
            print(("GREEN " if ok else "RED   ") + what); bad += 0 if ok else 1
    print(f"SCREEN-PROBE arms={len(arms)} red={bad}")
    return 1 if bad else 0
if __name__ == "__main__":
    a = sys.argv[1:]
    if a == ["--probe"]: sys.exit(probe())
    out, cap, keep = "screen.dump", 30.0, None
    while a and a[0] != "--":
        if a[0] == "--out" and len(a) > 1: out = a[1]; a = a[2:]
        elif a[0] == "--cap" and len(a) > 1: cap = float(a[1]); a = a[2:]
        elif a[0] == "--keep" and len(a) > 1: keep = a[1]; a = a[2:]
        else: refuse(f"unknown argument {a[0]!r}; usage: util_screen_run.py [--out FILE] [--cap S] [--keep DUMP.xwd] -- CMD ARG... | --probe")
    if not a or len(a) < 2: refuse("no command after --")
    sys.exit(run(a[1:], out, cap, keep))
