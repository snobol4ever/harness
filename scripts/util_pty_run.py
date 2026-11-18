#!/usr/bin/env python3
"""util_pty_run.py -- THE TERMINAL ROAD: run one program that needs a terminal with no human, on a pseudo-terminal of its own, and write what
its screen shows (the cqo's design of 2026-11-17 17:3x CST, skill suites-and-grading section 4, THE TERMINAL ROAD; Lon 2026-11-17 17:2x CST,
in the cio's window, on the 19 Icon programs excluded NEEDS_TERMINAL: "well that is simply Poppycock. Get those tests cut, graded, and scored.").

  python3 util_pty_run.py [--out FILE] [--cap S] [--keys SCRIPT] -- CMD ARG...
  python3 util_pty_run.py --probe

It opens a pseudo-terminal of 24 rows and 80 columns (the cto's ruling of 2026-11-17 17:3x CST: 24x80, TERM vt100, the box's own vt100 entry, the
same for the oracle's cut and SCRIP's grade), runs CMD in a new session with that terminal as its controlling terminal and as its standard
input, output and error, with TERM=vt100 and TERMCAP set to the one fixed vt100 entry kept below (VT100_TERMCAP, the box's `infocmp -C vt100`
with its continuation lines joined and the numeric padding of its fifteen string capabilities dropped (the cto 2026-11-18: a pty has no baud rate to pad for, and a program that writes a capability itself, as ipl bj does, would print the digits): the box has no /etc/termcap, and the Icon libraries iolib and itlib read TERMCAP). What CMD writes is read
off the master into a VT100 screen model (Screen: cursor addressing, erase in line and in display, the cursor moves, scroll region, insert and
delete of lines and characters, save and restore of the cursor, CR LF BS TAB, autowrap, scrolling; a rendition code is read and dropped).
THE ANSWER is FILE (default pty.dump, in the current directory): one block at each still point, the line `pty 80x24 step K` and the 24 rows
of the screen with their trailing blanks dropped, so it is text a reader can diff. The raw byte stream is never compared (how it is cut into
writes is an accident of the run). STILL is the screen road's rule (util_screen_run.still_span: the screen model holds for STILL equal shots
with no output arriving, and the program asleep, or its own processor time over the run at STILL_CPU_S), never a clock alone.
SCRIPTED INPUT, SCRIPT = NAME.keys: the step form of NAME.events, a step being the lines up to the next `wait` or the end: `type TEXT` (the
rest of the line, as it stands), `key NAME` (Return Tab Escape BackSpace Space Up Down Left Right, and C-x for a control key), `eof` (^D); `#`
lines and blank lines are skipped. After each still point the next step is written to the master. After the last step's still point CMD is
ended (SIGTERM, then SIGKILL) and the road exits 0: its status is withheld, as the screen road's. A program that ends by itself has its status
as this script's (128 plus the signal for one a signal ended) and a last block `pty 80x24 end` when its final screen was not already written.
A program that never goes still within the cap writes the line `pty busy` (output went on arriving or the program was never idle). A line the road
cannot read, an unknown key or a missing script is rc 2 with a REFUSE line before CMD starts. The program dies with this script, however it
dies (the parent-death signal of util_screen_run.with_me)."""
import codecs, fcntl, os, select, signal, struct, subprocess, sys, tempfile, termios, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import util_screen_run as U
ROWS, COLS, DEFAULT_CAP = 24, 80, 30.0
VT100_TERMCAP = (
    "vt100|vt100-am|DEC VT100 (w/advanced video):"
    ":am:bs:ms:xn:xo:"
    ":co#80:it#8:li#24:vt#3:"
    ":DO=\\E[%dB:K1=\\EOq:K2=\\EOr:K3=\\EOs:K4=\\EOp:K5=\\EOn:"
    ":LE=\\E[%dD:RI=\\E[%dC:UP=\\E[%dA:ae=^O:as=^N:bl=^G:cd=\\E[J:"
    ":ce=\\E[K:cl=\\E[H\\E[J:cm=\\E[%i%d;%dH:cr=\\r:"
    ":cs=\\E[%i%d;%dr:ct=\\E[3g:do=\\n:ho=\\E[H:k0=\\EOy:k1=\\EOP:"
    ":k2=\\EOQ:k3=\\EOR:k4=\\EOS:k5=\\EOt:k6=\\EOu:k7=\\EOv:k8=\\EOl:"
    ":k9=\\EOw:kb=^H:kd=\\EOB:ke=\\E[?1l\\E>:kl=\\EOD:kr=\\EOC:"
    ":ks=\\E[?1h\\E=:ku=\\EOA:le=^H:mb=\\E[5m:md=\\E[1m:me=\\E[0m:"
    ":mr=\\E[7m:nd=\\E[C:rc=\\E8:"
    ":rs=\\E<\\E>\\E[?3;4;5l\\E[?7;8h\\E[r:"
    ":..sa=\\E[0%?%p1%p6%|%t;1%;%?%p2%t;4%;%?%p1%p3%|%t;7%;%?%p4%t;5%;m%?%p9%t\\016%e\\017%;$<2>:"
    ":sc=\\E7:se=\\E[m:sf=\\n:so=\\E[7m:sr=\\EM:st=\\EH:ta=^I:"
    ":ue=\\E[m:up=\\E[A:us=\\E[4m:")
KEYS = {"Return": "\r", "Tab": "\t", "Escape": "\x1b", "BackSpace": "\x7f", "Space": " ",
        "Up": "\x1bOA", "Down": "\x1bOB", "Right": "\x1bOC", "Left": "\x1bOD"}
def refuse(msg):
    print(f"REFUSE(2): util_pty_run: {msg}", file=sys.stderr); sys.exit(2)
class Screen:
    """The VT100 screen model: ROWS x COLS cells, the cursor, the scroll region, the autowrap pending flag (the vt100's xn glitch)."""
    def __init__(s, rows=ROWS, cols=COLS):
        s.rows, s.cols = rows, cols; s.dec = codecs.getincrementaldecoder("utf-8")(errors="replace"); s.reset()
    def reset(s):
        s.grid = [[" "] * s.cols for _ in range(s.rows)]; s.r = s.c = 0; s.pend = False; s.top, s.bot = 0, s.rows - 1
        s.saved = (0, 0); s.st = 0; s.par = ""; s.n = 0
    def blank(s): return [" "] * s.cols
    def up(s):
        del s.grid[s.top]; s.grid.insert(s.bot, s.blank())
    def down(s):
        del s.grid[s.bot]; s.grid.insert(s.top, s.blank())
    def lf(s):
        if s.r == s.bot: s.up()
        elif s.r < s.rows - 1: s.r += 1
    def ri(s):
        if s.r == s.top: s.down()
        elif s.r > 0: s.r -= 1
    def put(s, ch):
        if s.pend: s.c = 0; s.lf(); s.pend = False
        s.grid[s.r][s.c] = ch
        if s.c == s.cols - 1: s.pend = True
        else: s.c += 1
    def args(s, default=1):
        p = [int(x) if x.isdigit() else 0 for x in s.par.lstrip("?>").split(";")] if s.par.lstrip("?>") else []
        return p or [default]
    def csi(s, f):
        s.pend = False; a = s.args(); n = a[0] or 1
        if s.par.startswith("?") or s.par.startswith(">"): return
        if f == "A": s.r = max(s.top if s.r >= s.top else 0, s.r - n)
        elif f == "B": s.r = min(s.bot if s.r <= s.bot else s.rows - 1, s.r + n)
        elif f == "C": s.c = min(s.cols - 1, s.c + n)
        elif f == "D": s.c = max(0, s.c - n)
        elif f in "Hf":
            s.r = min(s.rows - 1, max(0, (a[0] or 1) - 1)); s.c = min(s.cols - 1, max(0, ((a[1] if len(a) > 1 else 1) or 1) - 1))
        elif f == "G": s.c = min(s.cols - 1, n - 1)
        elif f == "d": s.r = min(s.rows - 1, n - 1)
        elif f == "J":
            k = a[0] if s.par else 0
            if k == 0: s.grid[s.r][s.c:] = [" "] * (s.cols - s.c); s.grid[s.r + 1:] = [s.blank() for _ in range(s.rows - s.r - 1)]
            elif k == 1: s.grid[s.r][:s.c + 1] = [" "] * (s.c + 1); s.grid[:s.r] = [s.blank() for _ in range(s.r)]
            else: s.grid = [s.blank() for _ in range(s.rows)]
        elif f == "K":
            k = a[0] if s.par else 0
            if k == 0: s.grid[s.r][s.c:] = [" "] * (s.cols - s.c)
            elif k == 1: s.grid[s.r][:s.c + 1] = [" "] * (s.c + 1)
            else: s.grid[s.r] = s.blank()
        elif f == "L" and s.top <= s.r <= s.bot:
            for _ in range(min(n, s.bot - s.r + 1)): del s.grid[s.bot]; s.grid.insert(s.r, s.blank())
        elif f == "M" and s.top <= s.r <= s.bot:
            for _ in range(min(n, s.bot - s.r + 1)): del s.grid[s.r]; s.grid.insert(s.bot, s.blank())
        elif f == "@": s.grid[s.r][s.c:] = ([" "] * min(n, s.cols - s.c) + s.grid[s.r][s.c:])[:s.cols - s.c]
        elif f == "P": s.grid[s.r][s.c:] = (s.grid[s.r][s.c + n:] + [" "] * n)[:s.cols - s.c]
        elif f == "X": s.grid[s.r][s.c:s.c + n] = [" "] * len(s.grid[s.r][s.c:s.c + n])
        elif f == "r":
            t, b = (a[0] or 1) - 1, ((a[1] if len(a) > 1 else s.rows) or s.rows) - 1
            if 0 <= t < b < s.rows: s.top, s.bot = t, b
            s.r = s.c = 0
        elif f == "s": s.saved = (s.r, s.c)
        elif f == "u": s.r, s.c = s.saved
    def feed(s, data):
        for ch in s.dec.decode(data):
            o = ord(ch)
            if s.st == 0:
                if ch == "\x1b": s.st = 1
                elif ch == "\r": s.c = 0; s.pend = False
                elif ch in "\n\x0b\x0c": s.pend = False; s.lf()
                elif ch == "\x08": s.c = max(0, s.c - 1); s.pend = False
                elif ch == "\t": s.c = min(s.cols - 1, (s.c // 8 + 1) * 8); s.pend = False
                elif o >= 0x20 and o != 0x7f: s.put(ch)
            elif s.st == 1:
                s.st = 0
                if ch == "[": s.st, s.par = 2, ""
                elif ch in "()*+#": s.st = 3
                elif ch == "]": s.st = 4
                elif ch == "D": s.pend = False; s.lf()
                elif ch == "E": s.pend = False; s.c = 0; s.lf()
                elif ch == "M": s.pend = False; s.ri()
                elif ch == "7": s.saved = (s.r, s.c)
                elif ch == "8": s.r, s.c = s.saved
                elif ch == "c": s.reset()
            elif s.st == 2:
                if "\x40" <= ch <= "\x7e": s.csi(ch); s.st = 0
                elif ch == "\x1b": s.st = 1
                else: s.par += ch
            elif s.st == 3: s.st = 0
            elif s.st == 4:
                if ch == "\x07": s.st = 0
                elif ch == "\x1b": s.st = 1
    def rows_text(s): return [("".join(r)).rstrip() for r in s.grid]
def block(label, scr): return "\n".join([f"pty {COLS}x{ROWS} {label}"] + scr.rows_text())
def read_steps(path):
    """The steps of a NAME.keys: a list of strings, each the bytes written to the master for one step, or refuse rc 2."""
    if not os.path.isfile(path): refuse(f"no keys script {path}")
    steps, cur = [], []
    for n, raw in enumerate(open(path, encoding="utf-8").read().split("\n"), 1):
        ln = raw.rstrip("\r")
        if not ln.strip() or ln.lstrip().startswith("#"): continue
        w, _, rest = ln.partition(" ")
        if w == "wait" and not rest.strip():
            if cur: steps.append("".join(cur)); cur = []
        elif w == "type" and rest != "": cur.append(rest)
        elif w == "key" and rest.strip() in KEYS: cur.append(KEYS[rest.strip()])
        elif w == "key" and rest.strip().startswith("C-") and len(rest.strip()) == 3 and rest.strip()[2].isalpha(): cur.append(chr(ord(rest.strip()[2].upper()) & 0x1f))
        elif w == "eof" and not rest.strip(): cur.append("\x04")
        else: refuse(f"{path}:{n}: a line is `type TEXT`, `key NAME` (Return Tab Escape BackSpace Space Up Down Left Right C-x), `eof` or `wait`; read {ln[:60]!r}")
    if cur: steps.append("".join(cur))
    if not steps: refuse(f"{path}: no step")
    return steps
def run(cmd, out, cap, steps):
    master, slave = os.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", ROWS, COLS, 0, 0))
    env = dict(os.environ, TERM="vt100", TERMCAP=VT100_TERMCAP)
    for k in ("DISPLAY", "WAYLAND_DISPLAY", "LINES", "COLUMNS", "TERMINFO", "TERMINFO_DIRS"): env.pop(k, None)
    def pre():
        fcntl.ioctl(0, termios.TIOCSCTTY, 0); U.with_me()
    try: child = subprocess.Popen(cmd, stdin=slave, stdout=slave, stderr=slave, env=env, start_new_session=True, preexec_fn=pre, close_fds=True)
    except OSError as e: refuse(f"cannot start {cmd[0]}: {e}")
    os.close(slave)
    scr, blocks, sent, ended_by_road, eof = Screen(), [], 0, False, False
    last_rows, run_len, t0, idle_seen, marks, acct, ticks, runnable, prev_t = None, 0, time.time(), False, [], {}, 0, 0, time.time()
    def pump(timeout):
        got = False
        while True:
            r, _, _ = select.select([master], [], [], timeout); timeout = 0
            if not r: return got
            try: d = os.read(master, 65536)
            except OSError: return got if got else None
            if not d: return got if got else None
            scr.feed(d); got = True
    try:
        while True:
            got = pump(U.POLL)
            if got is None and child.poll() is None:
                try: child.wait(timeout=1)
                except subprocess.TimeoutExpired: pass
            if child.poll() is not None:
                while pump(0.05): pass
                break
            now_t = time.time(); now = U.session_account(child.pid)
            dt, dr = U.account_delta(acct, now); acct = now; ticks += dt; runnable += dr
            if dr / 1e9 < U.RUNNABLE_FRAC * max(now_t - prev_t, 1e-3): idle_seen = True
            prev_t = now_t
            rows = scr.rows_text()
            if got or rows != last_rows: run_len, marks = 1, [(now_t, ticks, runnable, 0)]
            else: run_len += 1; marks.append((now_t, ticks, runnable, 0))
            last_rows = rows
            if run_len >= U.STILL and U.still_span(marks):
                blocks.append(block(f"step {len(blocks) + 1}", scr))
                if not steps or sent == len(steps): ended_by_road = True; break
                os.write(master, steps[sent].encode()); sent += 1
                run_len, marks, t0, idle_seen = 0, [], time.time(), False
            if time.time() - t0 > cap: blocks.append("pty busy" if not idle_seen or got else "pty busy"); ended_by_road = True; break
        if child.poll() is None:
            for sig in (signal.SIGTERM, signal.SIGKILL):
                try: os.killpg(child.pid, sig)
                except ProcessLookupError: break
                try: child.wait(timeout=3); break
                except subprocess.TimeoutExpired: continue
        rc = child.wait()
    finally:
        os.close(master)
    if not ended_by_road:
        end = block("end", scr)
        if not blocks or blocks[-1].split("\n", 1)[1] != end.split("\n", 1)[1]: blocks.append(end)
        if steps and sent < len(steps): blocks.append(f"pty ended with {len(steps) - sent} of {len(steps)} key steps unsent")
    with open(out, "w") as f: f.write("\n".join(blocks) + "\n")
    return 0 if ended_by_road else (rc if rc >= 0 else 128 - rc)
def probe():
    here = os.path.abspath(__file__); T = tempfile.mkdtemp(prefix="pty_probe_"); bad = 0
    def road(args, keys=None, cap=20, cwd=None):
        extra = []
        if keys is not None:
            kf = os.path.join(T, "k.keys"); open(kf, "w").write(keys); extra = ["--keys", kf]
        out = os.path.join(T, "o.dump")
        if os.path.exists(out): os.remove(out)
        r = subprocess.run([sys.executable, here, "--out", out, "--cap", str(cap)] + extra + ["--"] + args, capture_output=True, text=True, timeout=300)
        return r.returncode, (open(out).read() if os.path.exists(out) else ""), r.stderr
    def arm(name, ok, why=""):
        nonlocal bad
        print(f"  arm {name}: {'PASS' if ok else 'RED'}{'' if ok else ' -- ' + why}"); bad += 0 if ok else 1
    rc, d, e = road(["stty", "size"]); arm("size", rc == 0 and "\n24 80" in d, f"rc={rc} dump={d[:120]!r}")
    rc, d, e = road(["sh", "-c", "test -w /dev/tty && echo tty-open; echo \"$TERM\"; test -n \"$TERMCAP\" && echo termcap-set"]); arm("tty_term_termcap", "tty-open" in d and "vt100" in d and "termcap-set" in d, d[:160])
    rc, d, e = road(["cat"], "type hello\nkey Return\n"); arm("key_echo", rc == 0 and d.split("pty 80x24 step 2\n")[-1].split("\n")[:2] == ["hello", "hello"], f"rc={rc} {d[:100]!r}")
    import re
    caps = dict(re.findall(r":([A-Za-z0-9.]{2,3})=([^:]*)", VT100_TERMCAP))
    arm("termcap_cm_no_padding", caps.get("cm") == "\\E[%i%d;%dH" and not re.search(r"=[0-9.*]+\\\\E", re.sub(r":\\.\\.sa=[^:]*:", ":", VT100_TERMCAP)), repr(caps.get("cm")))
    padded = ["cd", "ce", "cl", "cm", "sr", "mb", "md", "me", "mr", "nd", "se", "so", "ue", "up", "us"]
    arm("termcap_fifteen_kept", all(c in caps for c in padded) and caps.get("ct") == "\\E[3g" and "co#80" in VT100_TERMCAP and "li#24" in VT100_TERMCAP and "$<2>" in VT100_TERMCAP, str([c for c in padded if c not in caps]))
    rc, d, e = road(["sh", "-c", "echo before; tput clear; echo after"]); arm("clear", rc == 0 and d.split("\n")[1] == "after" and "before" not in d, d[:100])
    rc, d, e = road(["sh", "-c", "printf 'one\\ntwo\\n'; tput cup 5 10; printf 'at'"]); arm("cursor", d.split("\n")[1 + 5] == "          at", d[:160])
    rc, d, e = road(["sh", "-c", "echo done; exit 3"]); arm("status", rc == 3 and "done" in d, f"rc={rc}")
    rc, d, e = road(["sh", "-c", "while :; do echo x; done"], cap=4); arm("busy", d.strip() == "pty busy", d[:60])
    r1 = road(["cat"], "type a\nkey Return\nwait\ntype b\nkey Return\n"); r2 = road(["cat"], "type a\nkey Return\nwait\ntype b\nkey Return\n")
    arm("twice_alike", r1[1] == r2[1] and r1[1].count("pty 80x24 step") == 3 and r1[1].split("pty 80x24 step 3\n")[-1].split("\n")[:4] == ["a", "a", "b", "b"], f"{r1[1][:60]!r} {r2[1][:60]!r}")
    rc, d, e = road(["cat"], "key NoSuchKey\n"); arm("refuse_key", rc == 2 and "REFUSE(2)" in e, f"rc={rc}")
    print("PTY_PROBE " + ("GREEN" if not bad else f"RED {bad} arm(s)")); return 0 if not bad else 1
def main(argv):
    if "--probe" in argv: return probe()
    out, cap, keys, i = "pty.dump", DEFAULT_CAP, None, 0
    while i < len(argv) and argv[i] != "--":
        if argv[i] == "--out" and i + 1 < len(argv): out = argv[i + 1]; i += 2
        elif argv[i] == "--cap" and i + 1 < len(argv):
            try: cap = float(argv[i + 1]); assert cap > 0
            except (ValueError, AssertionError): refuse(f"--cap needs a positive number of seconds, read {argv[i + 1]!r}")
            i += 2
        elif argv[i] == "--keys" and i + 1 < len(argv): keys = argv[i + 1]; i += 2
        else: refuse(f"unknown argument {argv[i]!r}")
    cmd = argv[i + 1:]
    if not cmd: refuse("no command after --")
    return run(cmd, out, cap, read_steps(keys) if keys else None)
if __name__ == "__main__": sys.exit(main(sys.argv[1:]))
