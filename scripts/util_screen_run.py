#!/usr/bin/env python3
"""util_screen_run.py -- THE SCREEN ROAD: run one graphics program with no human, on a virtual X display of its own, and write what its
screen shows (Lon 2026-11-14 15:4x CST, in the grader's window, verbatim: "We are absolutely DOING GRAPHICS, X-windows. Yes? We should be
able to do off-line (i.e. without physical window in which a human user is required) GUI tests. Yes?"; skill icon section 1).

  python3 util_screen_run.py [--out FILE] [--cap S] [--keep DUMP.xwd] [--events SCRIPT] [--depth 8|24] -- CMD ARG...
  python3 util_screen_run.py --no-screen [--depth 8|24] -- CMD ARG...
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
start: a run that cannot measure never reads as a verdict. The display and the program die with this script, however it dies (with_me), and
the program is started without XAUTHORITY, XENVIRONMENT and XAPPLRESDIR, so no resource file of the caller's desktop reaches it.

THE DEPTH (the cto's ruling of 2026-11-16 10:0x CST on officer_06's measurement; the road's one writer the cqo): --depth 8 starts the display at
8 bits, where the default visual is PseudoColor and a program's mutable colours answer (NewColor, Color, FreeColor; at 24 bits NewColor fails).
There a pixel byte is an index into the colormap, so the bytes are blind to a colour changed in place: MEASURED, a square recoloured from red to
blue with Color gives the same pixel bytes. At a depth with a colormap the screen line is therefore the md5 of each pixel's red, green and blue
bytes resolved through the dump's colormap, row by row, never of the index bytes and never of the colormap itself (its unused entries differ
from run to run). The values are 8 and 24 alone; 24 is the default and its line is byte for byte what it was. A depth-8 answer belongs to an
entry of its own, never a second ref of a 24-bit entry.

A DISPLAY WITHOUT A SCREEN ANSWER (--no-screen; the cqo 2026-11-16, on officer_04's ask for the Prolog graphics team): a program graded on its
text alone that still needs a display (XPCE's test file with its display cases, pixels read back off-screen, timers) runs on the road's own
display and nothing else of the road touches it: the screen is never read, the program is never ended, its standard input, output, error and
status pass whole, and no file is written. MEASURED by officer_04 on the road without it: a program that opens a window, waits five seconds on a
timer and then prints is ended at its still screen and its lines withheld. It takes --depth; --events and --keep are refused with it.

SCRIPTED EVENTS (W7 of the window facility, skill icon reference.md section 9; the cqo 2026-11-16): --events SCRIPT gives the program the
mouse and the keys a human would, so it is graded past its first picture. The opening still picture writes line 1 exactly as above. Then
the script's sends go to the display one step at a time, a step being the lines up to the next `wait` (or the end of the script): the
road sends the step, waits for the screen to hold still again and writes one more line of the same form. FILE is then one line a still
picture, in order. When every step is sent and its picture written the road ends the program as above; a program that ends by itself on
the way (a key that quits it) keeps its text and its status, and when it ends with steps still unsent the last line says so
(`screen ended with K of N event steps unsent`); one that never showed a still picture answers `screen none` alone, script or no. A step whose screen never holds still within the cap writes `screen unstable` and ends
the run. With no --events the answer is byte for byte what it was. The script, one send a line, `#` a note:

  move X Y                 the pointer to X Y (root coordinates; with no window manager a program's first window stands at 0 0)
  press B | release B      mouse button B (1 left, 2 middle, 3 right, 4 and 5 the wheel) down or up where the pointer is
  click B X Y              move, press, release
  drag B X1 Y1 X2 Y2       move to X1 Y1, press, move to X2 Y2 eight pixels a motion, release
  key KEYSYM               one key down and up by its X name (a, Return, Escape, F1); a shifted one (A, exclam) is sent with Shift
  keydown KEYSYM | keyup KEYSYM   one half of a key, for a held modifier (Control_L)
  type TEXT                each character of the rest of the line as a key (printable ASCII)
  focus                    the input focus back to the pointer (X PointerRoot): a program that pins the focus to one window of its own
                           (Icon's Raise does, rxwin.ri raiseWindow) takes a key in another only after this line (officer_06 2026-11-16,
                           the cto's ruling: one explicit line, no policy, so a script without it sends exactly what it sent before)
  wait                     the end of a step: the screen holds still again and its line is written

The keyboard goes to the window under the pointer (no window manager, so focus follows the pointer): move into the window before a key.
THE INJECTOR is the X server's own XTEST extension, reached through ctypes on libX11.so.6 and libXtst.so.6: no package and nothing to
build (xdotool is not on the box). A script line the road cannot read, a key the display's keyboard lacks, or a missing library is rc 2
with a REFUSE line before the program is started. With --events and --keep, picture n is also kept as DUMP.xwd.n.
"""
import ctypes, hashlib, os, signal, struct, subprocess, sys, tempfile, time
POLL, STILL, PACE, WIDE, HIGH = 0.5, 6, 0.05, 1024, 768
BOUND = 600   # --probe: the longest any one wait of the probe lasts; past it the probe refuses rc 2 (cannot measure), never a verdict
LIBC = ctypes.CDLL(None)
def with_me():
    """Run in each child before its exec: the kernel kills it when this script dies (PR_SET_PDEATHSIG, SIGKILL), so a road killed outright at a
    grader's time limit leaves no display and no program behind (the cio 2026-11-16, MEASURED: seven display sockets with no server, and each
    orphaned Xvfb holding 64 MB)."""
    LIBC.prctl(1, signal.SIGKILL)
def refuse(msg):
    sys.stderr.write(f"REFUSE(2) util_screen_run.py: {msg}\n"); sys.exit(2)
def which(name):
    for d in os.environ.get("PATH", "/usr/bin:/bin").split(os.pathsep):
        p = os.path.join(d, name)
        if os.access(p, os.X_OK): return p
    return None
def start_display(depth=24):
    xvfb = which("Xvfb") or refuse("no Xvfb on PATH (the virtual display the screen road runs on)")
    which("xwd") or refuse("no xwd on PATH (the screen is read with it)")
    r, w = os.pipe()
    p = subprocess.Popen([xvfb, "-displayfd", str(w), "-screen", "0", f"{WIDE}x{HIGH}x{depth}", "-nolisten", "tcp", "-ac"], pass_fds=(w,),
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True, preexec_fn=with_me)
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
    bpp, bpl = struct.unpack(">II", d[44:52])
    if bpp == 8:
        # A COLORMAP DISPLAY: each pixel byte is an index, so it is resolved to its colour (the high byte of the entry's red, green and blue),
        # the padding at the end of a row left out; an index the colormap does not name reads black.
        tr = [bytearray(256), bytearray(256), bytearray(256)]
        for i in range(ncolors):
            px, r, g, b = struct.unpack_from(">IHHH", d, hsize + i * 12)
            if px < 256: tr[0][px], tr[1][px], tr[2][px] = r >> 8, g >> 8, b >> 8
        idx = pix if bpl == w else b"".join(pix[y * bpl: y * bpl + w] for y in range(h))
        rgb = bytearray(3 * len(idx))
        for k in range(3): rgb[k::3] = idx.translate(bytes(tr[k]))
        pix = bytes(rgb)
    drawn = len(set(pix[::997])) > 1 or len(set(pix)) > 1
    return (f"{w}x{h}", hashlib.md5(pix).hexdigest(), drawn), d
def read_events(path):
    """The script as its steps: a list of steps, a step the list of sends before one `wait` (or the end of the script). A send is ("m", x, y),
    ("b", button, down), ("k", key, down) or ("tap", key), a key an X keysym name or, from `type`, a character's own code."""
    try: text = open(path, encoding="utf-8").read()
    except (OSError, UnicodeDecodeError) as e: refuse(f"--events {path}: {e}")
    steps, cur = [], []
    def num(w, lo, hi, where, what):
        if not w.isdigit() or not lo <= int(w) <= hi: refuse(f"{where}: {what} {w!r} is no whole number from {lo} to {hi}")
        return int(w)
    for n, raw in enumerate(text.split("\n"), 1):
        line, where = raw.strip(), f"--events {path} line {n}"
        if not line or line.startswith("#"): continue
        w = line.split()
        if w[0] == "type":
            body = raw.lstrip()[5:]
            if not body or any(not 0x20 <= ord(c) <= 0x7e for c in body): refuse(f"{where}: type wants printable ASCII text after it")
            cur += [("tap", ord(c)) for c in body]; continue
        need = {"move": 2, "press": 1, "release": 1, "click": 3, "drag": 5, "key": 1, "keydown": 1, "keyup": 1, "focus": 0, "wait": 0}.get(w[0])
        if need is None: refuse(f"{where}: {w[0]!r} is no send (move press release click drag key keydown keyup focus type wait)")
        if len(w) - 1 != need: refuse(f"{where}: {w[0]} takes {need} word(s), {len(w) - 1} given")
        xy = lambda i: (num(w[i], 0, WIDE - 1, where, "x"), num(w[i + 1], 0, HIGH - 1, where, "y"))
        if w[0] == "wait": steps.append(cur); cur = []
        elif w[0] == "focus": cur.append(("f",))
        elif w[0] == "move": cur.append(("m",) + xy(1))
        elif w[0] in ("press", "release"): cur.append(("b", num(w[1], 1, 5, where, "button"), w[0] == "press"))
        elif w[0] == "click": b = num(w[1], 1, 5, where, "button"); cur += [("m",) + xy(2), ("b", b, True), ("b", b, False)]
        elif w[0] == "drag":
            b, (x1, y1), (x2, y2) = num(w[1], 1, 5, where, "button"), xy(2), xy(4); k = max(abs(x2 - x1), abs(y2 - y1), 1); k = (k + 7) // 8
            cur += [("m", x1, y1), ("b", b, True)] + [("m", x1 + (x2 - x1) * i // k, y1 + (y2 - y1) * i // k) for i in range(1, k + 1)] + [("b", b, False)]
        elif w[0] == "key": cur.append(("tap", w[1]))
        else: cur.append(("k", w[1], w[0] == "keydown"))
    if cur: steps.append(cur)
    return steps
def xtest_libs():
    try: return ctypes.CDLL("libX11.so.6"), ctypes.CDLL("libXtst.so.6")
    except OSError as e: refuse(f"--events needs libX11.so.6 and libXtst.so.6 (the XTEST extension's client library): {e}")
class Injector:
    """One connection to the road's own display, every send an XTEST fake input; each key of the script is resolved to a keycode here, before the program starts."""
    def __init__(self, libs, display, steps):
        X, T = self.X, self.T = libs; V, I, U, L = ctypes.c_void_p, ctypes.c_int, ctypes.c_uint, ctypes.c_ulong
        X.XOpenDisplay.restype, X.XOpenDisplay.argtypes = V, [ctypes.c_char_p]
        X.XStringToKeysym.restype, X.XStringToKeysym.argtypes = L, [ctypes.c_char_p]
        X.XKeysymToKeycode.restype, X.XKeysymToKeycode.argtypes = ctypes.c_ubyte, [V, L]
        X.XkbKeycodeToKeysym.restype, X.XkbKeycodeToKeysym.argtypes = L, [V, U, I, I]
        X.XSync.argtypes, X.XCloseDisplay.argtypes = [V, I], [V]
        X.XSetInputFocus.argtypes = [V, L, I, L]
        T.XTestQueryExtension.argtypes = [V] + [ctypes.POINTER(I)] * 4
        T.XTestFakeMotionEvent.argtypes, T.XTestFakeButtonEvent.argtypes, T.XTestFakeKeyEvent.argtypes = [V, I, I, I, L], [V, U, I, L], [V, U, I, L]
        self.dpy = X.XOpenDisplay(display.encode()) or refuse(f"--events: no connection to the road's display {display}")
        a, b, c, d = I(), I(), I(), I()
        if not T.XTestQueryExtension(self.dpy, a, b, c, d): refuse("--events: the display has no XTEST extension")
        self.shift = X.XKeysymToKeycode(self.dpy, X.XStringToKeysym(b"Shift_L")); self.keys = {}
        for send in (s for step in steps for s in step):
            if send[0] in ("k", "tap") and send[1] not in self.keys: self.keys[send[1]] = self.resolve(send[1], send[0] == "tap")
    def resolve(self, key, tap):
        X = self.X; sym = key if isinstance(key, int) else X.XStringToKeysym(key.encode()); name = repr(chr(key)) if isinstance(key, int) else repr(key)
        if not sym: refuse(f"--events: {name} is no X keysym name")
        code = X.XKeysymToKeycode(self.dpy, sym)
        if not code: refuse(f"--events: the display's keyboard has no key for {name}")
        if X.XkbKeycodeToKeysym(self.dpy, code, 0, 0) == sym or not tap: return code, False
        if X.XkbKeycodeToKeysym(self.dpy, code, 0, 1) == sym and self.shift: return code, True
        refuse(f"--events: {name} needs a modifier other than Shift on the display's keyboard")
    def send(self, step):
        X, T, d = self.X, self.T, self.dpy
        def one(f, *a): f(d, *a, 0); X.XSync(d, 0); time.sleep(PACE)
        for s in step:
            if s[0] == "m": one(T.XTestFakeMotionEvent, 0, s[1], s[2])
            elif s[0] == "b": one(T.XTestFakeButtonEvent, s[1], int(s[2]))
            elif s[0] == "k": one(T.XTestFakeKeyEvent, self.keys[s[1]][0], int(s[2]))
            elif s[0] == "f": X.XSetInputFocus(d, 1, 1, 0); X.XSync(d, 0); time.sleep(PACE)   # PointerRoot, RevertToPointerRoot, CurrentTime
            else:
                code, shifted = self.keys[s[1]]
                if shifted: one(T.XTestFakeKeyEvent, self.shift, 1)
                one(T.XTestFakeKeyEvent, code, 1); one(T.XTestFakeKeyEvent, code, 0)
                if shifted: one(T.XTestFakeKeyEvent, self.shift, 0)
    def close(self):
        if self.dpy: self.X.XCloseDisplay(self.dpy); self.dpy = None
def run_plain(cmd, depth=24):
    """--no-screen: CMD on a display of the road's own, and nothing more; the status is CMD's (128 plus the signal for one a signal ended)."""
    xv, display = start_display(depth)
    env = dict(os.environ, DISPLAY=display)
    for k in ("XAUTHORITY", "XENVIRONMENT", "XAPPLRESDIR"): env.pop(k, None)
    try: rc = subprocess.Popen(cmd, env=env, preexec_fn=with_me).wait()
    finally:
        xv.terminate()
        try: xv.wait(timeout=5)
        except subprocess.TimeoutExpired: xv.kill()
    return rc if rc >= 0 else 128 - rc
def run(cmd, out, cap, keep, steps=None, depth=24):
    libs = xtest_libs() if steps is not None else None
    xv, display = start_display(depth)
    env = dict(os.environ, DISPLAY=display)
    for k in ("XAUTHORITY", "XENVIRONMENT", "XAPPLRESDIR"): env.pop(k, None)
    so = tempfile.TemporaryFile(); inj, lines, sent, ended_by_road, still_dump = None, [], 0, False, b""
    try:
        inj = Injector(libs, display, steps) if steps is not None else None
        child = subprocess.Popen(cmd, env=env, stdout=so, start_new_session=True, preexec_fn=with_me)
        last, run_len, t0 = None, 0, time.time()
        while True:
            alive = child.poll() is None
            if not alive: break
            shot, dump = pixels(display)
            if shot and shot[2]:
                run_len = run_len + 1 if shot == last else 1; last = shot
                if run_len >= STILL:
                    lines.append(f"screen {shot[0]} md5 {shot[1]}"); still_dump = dump
                    if keep and steps is not None:
                        with open(f"{keep}.{len(lines)}", "wb") as f: f.write(dump)
                    if not steps or sent == len(steps): ended_by_road = True; break
                    inj.send(steps[sent]); sent += 1; last, run_len, t0 = None, 0, time.time()
            else: last, run_len = None, 0
            if time.time() - t0 > cap: lines.append("screen unstable"); ended_by_road = True; break
            time.sleep(POLL)
        if child.poll() is None:
            for sig in (signal.SIGTERM, signal.SIGKILL):
                try: os.killpg(child.pid, sig)
                except ProcessLookupError: break
                try: child.wait(timeout=3); break
                except subprocess.TimeoutExpired: continue
        rc = child.wait()
    finally:
        if inj: inj.close()
        xv.terminate()
        try: xv.wait(timeout=5)
        except subprocess.TimeoutExpired: xv.kill()
    if lines and lines[-1] == "screen unstable" and steps is None: lines = lines[-1:]
    if not ended_by_road and lines and steps and sent < len(steps): lines.append(f"screen ended with {len(steps) - sent} of {len(steps)} event steps unsent")
    with open(out, "w") as f: f.write("\n".join(lines or ["screen none"]) + "\n")
    if keep and still_dump:
        with open(keep, "wb") as f: f.write(still_dump)
    if not ended_by_road:
        so.seek(0); sys.stdout.buffer.write(so.read()); sys.stdout.flush()
        return rc if rc >= 0 else 128 - rc
    return 0
def probe_client(mode):
    """--probe-client keep|change|blue: the depth probe's own X client, so the probe needs no Icon. On a colormap display it takes one writable
    colour cell, stores red in it (blue for mode blue), maps a 200 by 200 window whose background is that cell and waits for ever; mode change
    stores blue into the same cell once it has read its window's MapNotify (an order of events, never a sleep), so the window's pixel bytes
    stay what they were while its colour moves. rc 3 where the
    display gives no writable cell (a 24-bit display)."""
    X = ctypes.CDLL("libX11.so.6"); V, I, U, L = ctypes.c_void_p, ctypes.c_int, ctypes.c_uint, ctypes.c_ulong
    class XColor(ctypes.Structure): _fields_ = [("pixel", L), ("red", ctypes.c_ushort), ("green", ctypes.c_ushort), ("blue", ctypes.c_ushort), ("flags", ctypes.c_char), ("pad", ctypes.c_char)]
    X.XOpenDisplay.restype, X.XOpenDisplay.argtypes = V, [ctypes.c_char_p]
    X.XDefaultScreen.argtypes = [V]; X.XRootWindow.restype, X.XRootWindow.argtypes = L, [V, I]; X.XDefaultColormap.restype, X.XDefaultColormap.argtypes = L, [V, I]
    X.XAllocColorCells.argtypes = [V, L, I, ctypes.POINTER(L), U, ctypes.POINTER(L), U]; X.XStoreColor.argtypes = [V, L, ctypes.POINTER(XColor)]
    X.XCreateSimpleWindow.restype, X.XCreateSimpleWindow.argtypes = L, [V, L, I, I, U, U, U, L, L]; X.XMapWindow.argtypes = [V, L]; X.XFlush.argtypes = [V]
    X.XSelectInput.argtypes, X.XNextEvent.argtypes = [V, L, ctypes.c_long], [V, ctypes.c_char_p]
    dpy = X.XOpenDisplay(None) or sys.exit(2); scr = X.XDefaultScreen(dpy); cmap = X.XDefaultColormap(dpy, scr); cell = L()
    if not X.XAllocColorCells(dpy, cmap, 0, None, 0, ctypes.byref(cell), 1): sys.exit(3)
    def store(r, g, b): X.XStoreColor(dpy, cmap, ctypes.byref(XColor(cell.value, r, g, b, b"\x07", b"\x00"))); X.XFlush(dpy)
    store(0, 0, 65535) if mode == "blue" else store(65535, 0, 0)
    w = X.XCreateSimpleWindow(dpy, X.XRootWindow(dpy, scr), 0, 0, 200, 200, 0, 0, cell.value); X.XSelectInput(dpy, w, 1 << 17); X.XMapWindow(dpy, w); X.XFlush(dpy)
    if mode == "change":
        ev = ctypes.create_string_buffer(192)
        while True:
            X.XNextEvent(dpy, ev)
            if struct.unpack_from("i", ev.raw, 0)[0] == 19: break
        store(0, 0, 65535)
    while True: time.sleep(3600)
def probe_pin():
    """--probe-client pin: the focus arm's own X client. Two windows side by side, 0 0 and 300 0, 200 by 200, each taking key presses; once both
    are mapped (their own two MapNotify events read, an order of events, never a sleep) the focus is pinned to the right one, as Icon's Raise pins it; every key press is logged to pin.log in the working folder as the
    window it reached, L or R. Waits for ever."""
    X = ctypes.CDLL("libX11.so.6"); V, I, U, L = ctypes.c_void_p, ctypes.c_int, ctypes.c_uint, ctypes.c_ulong
    X.XOpenDisplay.restype, X.XOpenDisplay.argtypes = V, [ctypes.c_char_p]; X.XDefaultScreen.argtypes = [V]
    X.XRootWindow.restype, X.XRootWindow.argtypes = L, [V, I]; X.XCreateSimpleWindow.restype, X.XCreateSimpleWindow.argtypes = L, [V, L, I, I, U, U, U, L, L]
    X.XSelectInput.argtypes, X.XMapWindow.argtypes, X.XFlush.argtypes = [V, L, ctypes.c_long], [V, L], [V]
    X.XSetInputFocus.argtypes, X.XNextEvent.argtypes = [V, L, I, L], [V, ctypes.c_char_p]
    dpy = X.XOpenDisplay(None) or sys.exit(2); root = X.XRootWindow(dpy, X.XDefaultScreen(dpy))
    wl, wr = (X.XCreateSimpleWindow(dpy, root, x, 0, 200, 200, 0, 0, bg) for x, bg in ((0, 0xffffff), (300, 0x808080)))
    for w in (wl, wr): X.XSelectInput(dpy, w, 1 | 1 << 17); X.XMapWindow(dpy, w)
    X.XFlush(dpy); ev = ctypes.create_string_buffer(192); mapped = set()
    while len(mapped) < 2:
        X.XNextEvent(dpy, ev)
        if struct.unpack_from("i", ev.raw, 0)[0] == 19: mapped.add(struct.unpack_from("Q", ev.raw, 40)[0])
    X.XSetInputFocus(dpy, wr, 2, 0); X.XFlush(dpy)
    with open("pin.log", "a") as log:
        while True:
            X.XNextEvent(dpy, ev)
            if struct.unpack_from("i", ev.raw, 0)[0] == 2: log.write("L\n" if struct.unpack_from("Q", ev.raw, 32)[0] == wl else "R\n"); log.flush()
def probe():
    """Twenty-four arms on scratch with the X distribution's own demo clients (xlogo, a still picture that waits for ever; ico, an animation; for the
    scripted events xeyes, whose picture follows the pointer, and xev, which prints every event it is sent): no arm needs Icon. rc 0 all green,
    1 an arm red, 2 cannot measure. (xsetroot is no client for this: MEASURED, its colour never reaches the dump of an Xvfb root.)"""
    for c in ("xlogo", "ico", "xeyes", "xev"): which(c) or refuse(f"--probe needs {c} (x11-apps)")
    me = os.path.abspath(__file__); bad = 0
    with tempfile.TemporaryDirectory(prefix="screen_probe_") as td:
        def go(name, script, cap="25", events=None, more=()):
            ev = list(more)
            if events is not None:
                with open(os.path.join(td, f"{name}.events"), "w") as f: f.write(events)
                ev += ["--events", f"{name}.events"]
            try: r = subprocess.run([sys.executable, me, "--out", f"{name}.dump", "--cap", cap] + ev + ["--", "bash", "-c", script], cwd=td, capture_output=True, text=True, timeout=2 * BOUND)
            except subprocess.TimeoutExpired: refuse(f"--probe: arm {name} ran past {2 * BOUND} s, so the probe cannot measure")
            return r.returncode, r.stdout, open(os.path.join(td, f"{name}.dump")).read().strip() if os.path.exists(os.path.join(td, f"{name}.dump")) else "", r.stderr
        def seen(name):
            try: return open(os.path.join(td, name)).read()
            except OSError: return ""
        pic = lambda l: l.startswith("screen 1024x768 md5 ")
        a = go("still", "echo printed-before; exec xlogo -geometry 200x200+0+0")
        b = go("still2", "exec xlogo -geometry 200x200+0+0")
        c = go("other", "exec xlogo -geometry 300x150+0+0")
        d = go("ends", "echo whole-output; exit 3")
        e = go("moving", "exec ico -sleep 0.05", cap="8")
        cl = lambda mode: f"exec {sys.executable} {me} --probe-client {mode}"
        d24 = go("deep24", "exec xlogo -geometry 200x200+0+0", more=("--depth", "24"))
        k1, k2 = go("keep", cl("keep"), more=("--depth", "8")), go("keep2", cl("keep"), more=("--depth", "8"))
        ch, bl = go("change", cl("change"), more=("--depth", "8")), go("blue", cl("blue"), more=("--depth", "8"))
        d16 = go("deep16", "touch deep16.ran", more=("--depth", "16"))
        # THE HELD PROGRAM holds a still window until the probe releases it (NAME.release, made by the probe), never by the clock; it writes its
        # display beside it so the probe can read that screen itself. On the screen road it is never released, so only the road can end it at its
        # still screen before its own bound; under --no-screen the probe releases it once it has itself read the window still (wait_still).
        held = lambda n: (f'xlogo -geometry 200x200+0+0 & echo "$DISPLAY" > {n}.display; while [ ! -e {n}.release ] && [ "$SECONDS" -lt {BOUND} ]; do sleep 0.2; done; '
                          'echo done-after-still; kill $!; exit 5')
        lost = []
        def wait_still(n):
            t0, last, run_len = time.time(), None, 0
            while run_len < STILL:
                if time.time() - t0 > BOUND: lost.append(n); return
                d = seen(f"{n}.display").strip()
                shot = pixels(d)[0] if d else None
                run_len = run_len + 1 if shot and shot[2] and shot == last else (1 if shot and shot[2] else 0); last = shot
                time.sleep(POLL)
            open(os.path.join(td, f"{n}.release"), "w").close()
        import threading
        rel = threading.Thread(target=wait_still, args=("plain",), daemon=True); rel.start()
        n1 = go("plain", held("plain"), more=("--no-screen",)); rel.join()
        if lost: refuse(f"--probe: arm {lost[0]} never showed its still window, so the probe cannot measure")
        n0 = go("ended", held("ended"))
        n2 = go("plain8", "xdpyinfo | grep -c -E 'dimensions: +1024x768|depth of root window: +8 planes'", more=("--no-screen", "--depth", "8"))
        n3 = go("plainev", "touch plainev.ran", more=("--no-screen",), events="move 1 1\n")
        kids = lambda pid: [int(q) for q in os.listdir("/proc") if q.isdigit() and (lambda t: t is not None and int(t.rsplit(")", 1)[1].split()[1]) == pid)(read_stat(q))]
        def read_stat(q):
            try: return open(f"/proc/{q}/stat").read()
            except OSError: return None
        zombie_or_gone = lambda q: (lambda t: t is None or t.rsplit(")", 1)[1].split()[0] == "Z")(read_stat(q))
        comm = lambda q: (lambda t: t.split("(", 1)[1].rsplit(")", 1)[0] if t else "")(read_stat(q))
        rd = subprocess.Popen([sys.executable, me, "--out", "killed.dump", "--", "xlogo", "-geometry", "200x200+0+0"], cwd=td, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        t0 = time.time()
        while True:
            mine = [q for q in kids(rd.pid) if comm(q) in ("Xvfb", "xlogo")]
            if sorted(comm(q) for q in mine) == ["Xvfb", "xlogo"]: break
            if rd.poll() is not None or time.time() - t0 > BOUND: rd.kill(); refuse("--probe: the road never had its display and its program as children, so the killed-road arm cannot measure")
            time.sleep(0.1)
        rd.kill(); rd.wait(); t0 = time.time()
        while not all(zombie_or_gone(q) for q in mine) and time.time() - t0 < BOUND: time.sleep(0.1)
        orphans = [q for q in mine if not zombie_or_gone(q)]
        for q in orphans:
            try: os.kill(q, signal.SIGKILL)
            except OSError: pass
        eyes = "move 30 700\nwait\n# the other corner\nmove 1000 20\n"
        f = go("eyes", "exec xeyes -geometry 300x200+0+0", events=eyes); fl = f[2].split("\n")
        g = go("eyes2", "exec xeyes -geometry 300x200+0+0", events=eyes)
        h = go("keys", "exec xev -geometry 200x200+0+0 > keys.log", events="move 50 60\nkey a\ntype B\nclick 1 70 80\ndrag 3 20 20 40 20\n"); hl = seen("keys.log")
        quit_on_q = "xev -geometry 200x200+0+0 | grep -m1 'keysym 0x71, q'; echo got-key; exit 4"
        i = go("quits", quit_on_q, events="move 50 60\nwait\nkey q\n"); il = i[2].split("\n")
        j = go("early", quit_on_q, events="move 50 60\nkey q\nwait\nkey a\nwait\nkey b\n"); jl = j[2].split("\n")
        k = go("badword", "touch badword.ran", events="move 50 60\njump 3\n")
        m = go("badkey", "touch badkey.ran", events="key NoSuchKeyOfOurs\n")
        n = go("nopicture", "echo whole-output; exit 3", events="move 50 60\nwait\nkey a\n")
        pn = go("pinned", f"exec {sys.executable} {me} --probe-client pin", events="move 50 50\nwait\nkey a\nwait\n"); pl = seen("pin.log")
        if os.path.exists(os.path.join(td, "pin.log")): os.remove(os.path.join(td, "pin.log"))
        pf = go("focused", f"exec {sys.executable} {me} --probe-client pin", events="move 50 50\nfocus\nwait\nkey a\nwait\n"); fo = seen("pin.log")
        arms = [("a waiting program is ended at its still screen, rc 0, its text withheld", a[0] == 0 and a[1] == "" and a[2].startswith("screen 1024x768 md5 ")),
                ("the same picture gives the same line twice", a[2] == b[2] and a[2] != ""),
                ("another picture gives another line", c[2].startswith("screen 1024x768 md5 ") and c[2] != a[2]),
                ("a program that ends alone keeps its text and its status, screen none", d[0] == 3 and d[1] == "whole-output\n" and d[2] == "screen none"),
                ("a screen that never holds still is unstable", e[0] == 0 and e[2] == "screen unstable"),
                ("the road killed outright takes its display and its program with it", len(mine) == 2 and not orphans),
                ("depth: 24 asked by name answers the line of no option", d24[0] == 0 and d24[2] == a[2] and a[2] != ""),
                ("depth 8: a colormap display gives a still line, the same twice", k1[0] == 0 and k1[2].startswith("screen 1024x768 md5 ") and k1[2] == k2[2]),
                ("depth 8: a colour changed in its cell is seen, though no pixel byte moved", ch[2].startswith("screen 1024x768 md5 ") and ch[2] != k1[2]),
                ("depth 8: the changed colour reads as that colour stored from the start", ch[2] == bl[2] and bl[2] != ""),
                ("no screen: a program that holds a still window and then prints keeps its text and its status, and no file is written", n1[0] == 5 and n1[1] == "done-after-still\n" and not os.path.exists(os.path.join(td, "plain.dump"))),
                ("no screen: the same program on the screen road is ended at its still screen, its text withheld", n0[0] == 0 and n0[1] == "" and n0[2].startswith("screen 1024x768 md5 ")),
                ("no screen: the program has the road's display, at the depth asked", n2[0] == 0 and n2[1] == "2\n"),
                ("no screen: an events script with it is refused rc 2 before the program starts", n3[0] == 2 and "REFUSE(2)" in n3[3] and not os.path.exists(os.path.join(td, "plainev.ran"))),
                ("depth: a value other than 8 and 24 is refused rc 2 before the program starts", d16[0] == 2 and "REFUSE(2)" in d16[3] and not os.path.exists(os.path.join(td, "deep16.ran"))),
                ("events: one line a still picture, and the pointer moved to another place gives another picture", f[0] == 0 and len(fl) == 3 and all(pic(l) for l in fl) and len(set(fl)) == 3),
                ("events: the same script gives the same lines twice", f[2] == g[2] and f[2] != ""),
                ("events: a key, a shifted key, a click and a drag reach the program as sent", h[0] == 0 and all(t in hl for t in ("(keysym 0x61, a)", "(keysym 0x42, B)", "(keysym 0xffe1, Shift_L)", "root:(70,80)", "button 1", "button 3", "root:(26,20)", "root:(33,20)", "root:(40,20)")) and hl.count("ButtonPress") == 2 and hl.count("ButtonRelease") == 2),
                ("events: a program its last step ends keeps its text and its status, and no line follows", i[0] == 4 and i[1].endswith("got-key\n") and len(il) == 2 and all(pic(l) for l in il)),
                ("events: a program that ends with steps unsent says how many", j[0] == 4 and len(jl) == 2 and pic(jl[0]) and jl[1] == "screen ended with 2 of 3 event steps unsent"),
                ("events: a program that ends with no picture is screen none alone, its text and status kept", n[0] == 3 and n[1] == "whole-output\n" and n[2] == "screen none"),
                ("events: a line that is no send is refused rc 2 before the program starts", k[0] == 2 and "REFUSE(2)" in k[3] and "line 2" in k[3] and not os.path.exists(os.path.join(td, "badword.ran"))),
                ("events: a key that is no keysym is refused rc 2 before the program starts", m[0] == 2 and "REFUSE(2)" in m[3] and not os.path.exists(os.path.join(td, "badkey.ran"))),
                ("events: a pinned focus keeps a key from the window under the pointer until focus returns it there", pn[0] == 0 and pl == "R\n" and pf[0] == 0 and fo == "L\n")]
        for what, ok in arms:
            print(("GREEN " if ok else "RED   ") + what); bad += 0 if ok else 1
    print(f"SCREEN-PROBE arms={len(arms)} red={bad}")
    return 1 if bad else 0
if __name__ == "__main__":
    a = sys.argv[1:]
    if a == ["--probe"]: sys.exit(probe())
    if len(a) == 2 and a[0] == "--probe-client" and a[1] in ("keep", "change", "blue"): probe_client(a[1])
    if a == ["--probe-client", "pin"]: probe_pin()
    out, cap, keep, events, depth, plain = "screen.dump", 30.0, None, None, 24, False
    while a and a[0] != "--":
        if a[0] == "--out" and len(a) > 1: out = a[1]; a = a[2:]
        elif a[0] == "--cap" and len(a) > 1: cap = float(a[1]); a = a[2:]
        elif a[0] == "--keep" and len(a) > 1: keep = a[1]; a = a[2:]
        elif a[0] == "--events" and len(a) > 1: events = a[1]; a = a[2:]
        elif a[0] == "--no-screen": plain = True; a = a[1:]
        elif a[0] == "--depth" and len(a) > 1:
            if a[1] not in ("8", "24"): refuse(f"--depth {a[1]!r}: the road's display is 8 or 24 bits deep, no other (the cto's ruling of 2026-11-16)")
            depth = int(a[1]); a = a[2:]
        else: refuse(f"unknown argument {a[0]!r}; usage: util_screen_run.py [--out FILE] [--cap S] [--keep DUMP.xwd] [--events SCRIPT] [--depth 8|24] -- CMD ARG... | --no-screen [--depth 8|24] -- CMD ARG... | --probe")
    if not a or len(a) < 2: refuse("no command after --")
    if plain:
        if events is not None or keep is not None: refuse("--no-screen reads no screen: it takes no --events and no --keep")
        sys.exit(run_plain(a[1:], depth))
    sys.exit(run(a[1:], out, cap, keep, read_events(events) if events is not None else None, depth))
