#!/usr/bin/env python3
"""util_jupyterlab_run_look.py -- A REAL JUPYTERLAB, A REAL HEADLESS BROWSER, A NOTEBOOK RUN THROUGH THE PAGE AS A PERSON RUNS IT (row jupyter-step-10w, the cao's design 2026-11-16).

  util_jupyterlab_run_look.py check NOTEBOOK...   Run All through the page; each code cell's output, read from the notebook's model, against the output saved in the file
  util_jupyterlab_run_look.py interrupt           a cell that loops for ever is interrupted through the page; it must end, and the next cell must run
  util_jupyterlab_run_look.py restart             the kernel is restarted through the page; a variable set before must read unset after
  util_jupyterlab_run_look.py --probe             the tool's own proof: a planted notebook whose second saved output is wrong (rc 1, cell 2), no Chrome on PATH (rc 2), two runs alike

JupyterLab is started in scratch on a free port with a token and --expose-app-in-browser (so the page holds window.jupyterapp); the ONE KERNEL, scrip, is installed into scratch by the
scrip binary itself (SCRIP_BIN, else the scrip of the SCRIP clone, S4E_SCRIP; scrip --kernel-install). Headless Chrome is started with --remote-debugging-port and a scratch profile, and the tool
drives it through Chrome's own DevTools protocol over a websocket (tornado; no browser package): Page.navigate to the notebook's URL, then Runtime.evaluate. The notebook is run on a scratch COPY,
so the file is never rewritten. Every wait is on an order of events read from the page (the panel and its kernel ready; the run's promise settled; the kernel idle), polled, under one overall cap.
A code cell is SAME when the text of its stdout streams equals the saved cell's and the run holds no stderr stream and no error output, as util_notebook_kernel_check.py reads it. One line a notebook:
  LAB_RUN nb=NAME cells=N same=S differs=D first=K      (K the 1-based number of the first differing code cell, 0 when none), then the first differing cell's two texts.
rc 0 none differs; rc 1 one differs (or, for interrupt and restart, the page showed otherwise); rc 2 could not measure (no Chrome, no JupyterLab, no binary, the page never became ready within the cap).
Everything the tool starts dies with it (the parent-death signal, and each child killed by its own pid at the end); the scratch lives under /tmp/s4e/<seat> and is removed."""
import copy, ctypes, json, os, shutil, signal, socket, subprocess, sys, tempfile, time, urllib.request, uuid

CAP = float(os.environ.get("LAB_RUN_CAP", "240"))


class Refuse(Exception):
    pass


def refuse(msg):
    raise Refuse(msg)


def stdout_text(outs):
    return "".join("".join(o.get("text", "")) if isinstance(o.get("text", ""), list) else o.get("text", "") for o in outs if o.get("output_type") == "stream" and o.get("name") == "stdout")


def other_text(outs):
    r = []
    for o in outs:
        if o.get("output_type") == "stream" and o.get("name") != "stdout":
            t = o.get("text", "")
            r.append("stderr: " + ("".join(t) if isinstance(t, list) else t).rstrip("\n"))
        elif o.get("output_type") == "error":
            r.append("error: %s: %s" % (o.get("ename"), o.get("evalue")))
    return r


def show(label, text):
    lines = text.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    print("  %s (%d line(s)):" % (label, len(lines)))
    for ln in lines[:10]:
        print("    | " + ln)


def dies_with_me():
    try:
        ctypes.CDLL("libc.so.6", use_errno=True).prctl(1, signal.SIGKILL)
    except Exception:
        pass
    os.setsid()


def free_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    p = s.getsockname()[1]
    s.close()
    return p


class Page:
    def __init__(self, ws_url):
        from tornado.ioloop import IOLoop
        from tornado.websocket import websocket_connect
        self.loop = IOLoop()
        self.n = 0
        self.ws = self.loop.run_sync(lambda: websocket_connect(ws_url, max_message_size=1 << 28), timeout=30)

    def call(self, method, params=None, timeout=60):
        self.n += 1
        mid = self.n
        self.ws.write_message(json.dumps({"id": mid, "method": method, "params": params or {}}))

        async def wait():
            while True:
                m = await self.ws.read_message()
                if m is None:
                    refuse("the browser closed the page's websocket")
                d = json.loads(m)
                if d.get("id") == mid:
                    return d
        d = self.loop.run_sync(wait, timeout=timeout)
        if "error" in d:
            refuse("%s: %s" % (method, d["error"]))
        return d.get("result", {})

    def js(self, expr, timeout=60):
        r = self.call("Runtime.evaluate", {"expression": expr, "awaitPromise": True, "returnByValue": True}, timeout=timeout)
        if r.get("exceptionDetails"):
            return {"__exception": str(r["exceptionDetails"].get("exception", {}).get("description", r["exceptionDetails"]))[:300]}
        return r.get("result", {}).get("value")

    def close(self):
        try:
            self.ws.close()
        except Exception:
            pass


NB = "const a = window.jupyterapp; const w = a ? Array.from(a.shell.widgets('main')).find(x => x.sessionContext && x.content && x.content.model) : null;"
PANEL = "(() => { " + NB + " if (!a) return 'noapp'; if (!w) return 'nopanel'; if (a.shell.currentWidget !== w) a.shell.activateById(w.id); if (a.shell.currentWidget !== w) return 'notcurrent';" \
        " const s = w.sessionContext; const k = s.session && s.session.kernel; if (!k) return 'nokernel'; return (s.isReady && k.connectionStatus === 'connected') ? 'ready:' + k.status : 'starting:' + k.status; })()"
STATUS = "(() => { " + NB + " const k = w && w.sessionContext.session && w.sessionContext.session.kernel; return k ? k.status : 'nokernel'; })()"
OUTPUTS = "(() => { " + NB + " const m = w.content.model; const r = []; for (let i = 0; i < m.cells.length; i++) { const c = m.cells.get(i);" \
          " if (c.type !== 'code') continue; r.push({count: c.executionCount, outputs: c.outputs.toJSON()}); } return JSON.stringify(r); })()"
RUNCELL = "(i => { " + NB + " a.shell.activateById(w.id); w.content.activeCellIndex = i; return a.commands.execute('notebook:run-cell'); })"


class Lab:
    def __init__(self, scrip, top):
        self.top, self.procs = top, []
        self.chrome = shutil.which("google-chrome") or shutil.which("chromium") or shutil.which("chromium-browser")
        if not self.chrome:
            refuse("no Chrome or Chromium on the path")
        try:
            import jupyterlab, tornado.websocket  # noqa: F401
        except ImportError as e:
            refuse("jupyterlab or tornado is not importable (%s)" % e)
        if not os.access(scrip, os.X_OK):
            refuse("no scrip binary at " + scrip)
        spec = os.path.join(top, "spec")
        inst = subprocess.run([scrip, "--kernel-install", os.path.join(spec, "kernels")], capture_output=True, text=True)
        if inst.returncode != 0 or not os.path.exists(os.path.join(spec, "kernels", "scrip", "kernel.json")):
            refuse("%s --kernel-install did not install the kernel scrip (rc %d: %s)" % (scrip, inst.returncode, inst.stderr.strip()[:200]))
        self.work = os.path.join(top, "work")
        os.makedirs(self.work)
        self.port, self.tok = free_port(), uuid.uuid4().hex
        env = dict(os.environ, JUPYTER_DATA_DIR=os.path.join(top, "data"), JUPYTER_CONFIG_DIR=os.path.join(top, "cfg"), JUPYTER_RUNTIME_DIR=os.path.join(top, "rt"),
                   JUPYTER_TOKEN=self.tok, JUPYTER_PATH=spec)
        self.procs.append(subprocess.Popen([sys.executable, "-m", "jupyterlab", "--no-browser", "--port=%d" % self.port, "--ServerApp.port_retries=0", "--ServerApp.root_dir=" + self.work,
                                            "--expose-app-in-browser", "--LabApp.news_url=", "--LabApp.check_for_updates_class=jupyterlab.NeverCheckForUpdate"], env=env,
                                           stdout=open(os.path.join(top, "lab.log"), "w"), stderr=subprocess.STDOUT, preexec_fn=dies_with_me))
        t0 = time.time()
        while True:
            try:
                urllib.request.urlopen("http://127.0.0.1:%d/api/status?token=%s" % (self.port, self.tok), timeout=5)
                break
            except Exception:
                if time.time() - t0 > CAP or self.procs[0].poll() is not None:
                    refuse("JupyterLab did not answer within %d s (see its log)" % CAP)
                time.sleep(0.3)
        self.dport = free_port()
        self.procs.append(subprocess.Popen([self.chrome, "--headless=new", "--disable-gpu", "--no-sandbox", "--no-first-run", "--disable-background-networking", "--disable-sync",
                                            "--disable-extensions", "--user-data-dir=" + os.path.join(top, "chrome"), "--window-size=1400,1000",
                                            "--remote-debugging-port=%d" % self.dport, "about:blank"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, preexec_fn=dies_with_me))
        page = None
        while page is None:
            try:
                lst = json.load(urllib.request.urlopen("http://127.0.0.1:%d/json" % self.dport, timeout=5))
                page = next((t for t in lst if t.get("type") == "page" and t.get("webSocketDebuggerUrl")), None)
            except Exception:
                pass
            if page is None:
                if time.time() - t0 > CAP or self.procs[1].poll() is not None:
                    refuse("Chrome's debugging port did not list a page within %d s" % CAP)
                time.sleep(0.3)
        self.page = Page(page["webSocketDebuggerUrl"])
        self.page.call("Page.enable")
        self.page.call("Runtime.enable")
        self.page.call("Emulation.setFocusEmulationEnabled", {"enabled": True})

    def open(self, name):
        self.page.call("Page.navigate", {"url": "http://127.0.0.1:%d/lab/tree/%s?token=%s" % (self.port, name, self.tok)})
        self.last = None

        def ready():
            self.last = self.page.js(PANEL)
            return str(self.last).startswith("ready:idle")
        self.until(ready, "the notebook panel and its kernel were not ready")

    def until(self, cond, what):
        t0 = time.time()
        while not cond():
            if time.time() - t0 > CAP:
                refuse("%s within %d s; last page answer %r" % (what, CAP, getattr(self, "last", None)))
            time.sleep(0.2)

    def idle(self):
        self.until(lambda: self.page.js(STATUS) == "idle", "the kernel did not go idle")

    def outputs(self):
        v = self.page.js(OUTPUTS)
        if not isinstance(v, str):
            refuse("the page did not answer the notebook's model (%r)" % (v,))
        return json.loads(v)

    def stop(self):
        try:
            self.page.close()
        except Exception:
            pass
        for p in reversed(self.procs):
            try:
                os.killpg(p.pid, signal.SIGTERM)
            except Exception:
                pass
        for p in reversed(self.procs):
            try:
                p.wait(20)
            except Exception:
                try:
                    os.killpg(p.pid, signal.SIGKILL)
                except Exception:
                    pass


def check_one(lab, path):
    import nbformat
    try:
        nb = nbformat.read(path, as_version=4)
    except Exception as e:
        refuse("%s does not parse as a notebook (%s)" % (path, e))
    name = os.path.basename(path)
    shutil.copyfile(path, os.path.join(lab.work, name))
    lab.open(name)
    r = lab.page.js("window.jupyterapp.commands.execute('notebook:run-all-cells').then(v => String(v), e => 'error: ' + e)", timeout=CAP)
    if isinstance(r, dict) and "__exception" in r:
        refuse("notebook:run-all-cells raised %s" % r["__exception"])
    lab.idle()
    ran = lab.outputs()
    saved = [c for c in nb.cells if c.cell_type == "code"]
    same = differs = first = 0
    for i, a in enumerate(saved, 1):
        b = ran[i - 1]["outputs"] if i <= len(ran) else []
        if i <= len(ran) and stdout_text(a.get("outputs", [])) == stdout_text(b) and not other_text(b):
            same += 1
        else:
            differs += 1
            first = first or i
    print("LAB_RUN nb=%s cells=%d same=%d differs=%d first=%d" % (name, len(saved), same, differs, first))
    if first:
        show("cell %d saved" % first, stdout_text(saved[first - 1].get("outputs", [])))
        b = ran[first - 1]["outputs"] if first <= len(ran) else []
        show("cell %d through the page" % first, stdout_text(b))
        for ln in other_text(b)[:10]:
            print("    ! " + ln)
    return 1 if differs else 0


def planted(work, name, cells):
    import nbformat
    nb = nbformat.v4.new_notebook(metadata={"kernelspec": {"name": "scrip", "display_name": "SCRIP", "language": "scrip"}})
    for code, saved in cells:
        c = nbformat.v4.new_code_cell(code)
        if saved is not None:
            c.outputs = [nbformat.v4.new_output("stream", name="stdout", text=saved)]
        nb.cells.append(c)
    p = os.path.join(work, name)
    nbformat.write(nb, p)
    return p


def interrupt(lab, top):
    p = planted(top, "interrupt.ipynb", [("LOOP    X = X + 1   :(LOOP)\n", None), ("        OUTPUT = 'after the interrupt'\n", None)])
    shutil.copyfile(p, os.path.join(lab.work, "interrupt.ipynb"))
    lab.open("interrupt.ipynb")
    lab.page.js("(() => { " + RUNCELL + "(0); return 1; })()")
    lab.until(lambda: lab.page.js(STATUS) == "busy", "the looping cell did not make the kernel busy")
    lab.page.js("window.jupyterapp.commands.execute('kernelmenu:interrupt').then(() => 1, e => 'error: ' + e)")
    lab.idle()
    lab.page.js(RUNCELL + "(1).then(() => 1)", timeout=CAP)
    lab.idle()
    o = lab.outputs()
    c1, c2 = o[0], o[1]
    ok = stdout_text(c2["outputs"]) == "after the interrupt\n" and c2["count"] is not None
    print("LAB_INTERRUPT cell1_count=%s cell1=%r cell2=%r %s" % (c1["count"], (stdout_text(c1["outputs"]) + " ".join(other_text(c1["outputs"])))[:200], stdout_text(c2["outputs"])[:200],
                                                                  "ok" if ok else "RED"))
    return 0 if ok else 1


def restart(lab, top):
    p = planted(top, "restart.ipynb", [("        X = 'set before'\n", None), ("        OUTPUT = 'X is [' X ']'\n", None)])
    shutil.copyfile(p, os.path.join(lab.work, "restart.ipynb"))
    lab.open("restart.ipynb")
    run = "(i => " + RUNCELL + "(i).then(() => 1))"
    lab.page.js(run + "(1)", timeout=CAP)
    lab.idle()
    before = stdout_text(lab.outputs()[1]["outputs"])
    lab.page.js(run + "(0)", timeout=CAP)
    lab.idle()
    lab.page.js(run + "(1)", timeout=CAP)
    lab.idle()
    setv = stdout_text(lab.outputs()[1]["outputs"])
    lab.page.js("(() => { " + NB + " return w.sessionContext.session.kernel.restart().then(() => 1, e => 'error: ' + e); })()", timeout=CAP)
    lab.until(lambda: str(lab.page.js(PANEL)).startswith("ready:idle"), "the kernel did not come back from its restart")
    lab.page.js(run + "(1)", timeout=CAP)
    lab.idle()
    after = stdout_text(lab.outputs()[1]["outputs"])
    ok = setv == "X is [set before]\n" and after == "X is []\n"
    print("LAB_RESTART before=%r set=%r after_restart=%r %s" % (before, setv, after, "ok" if ok else "RED"))
    return 0 if ok else 1


def session(scrip, verb, args):
    base = os.path.join("/tmp/s4e", os.environ.get("S4E_SEAT", "look"))
    os.makedirs(base, exist_ok=True)
    top = tempfile.mkdtemp(prefix="lab-run-", dir=base)
    lab = None
    try:
        lab = Lab(scrip, top)
        if verb == "check":
            worst = 0
            for path in args:
                worst = max(worst, check_one(lab, path))
            return worst
        return interrupt(lab, top) if verb == "interrupt" else restart(lab, top)
    except Refuse as e:
        print("REFUSE(2) [util_jupyterlab_run_look]: " + str(e))
        return 2
    finally:
        if lab:
            lab.stop()
        shutil.rmtree(top, ignore_errors=True)


def probe(scrip):
    base = os.path.join("/tmp/s4e", os.environ.get("S4E_SEAT", "look"))
    os.makedirs(base, exist_ok=True)
    top = tempfile.mkdtemp(prefix="lab-run-probe-", dir=base)
    bad = []
    try:
        p = planted(top, "probe.ipynb", [("        OUTPUT = 'one'\n", "one\n"), ("        OUTPUT = 'two'\n", "TWO\n")])
        lines = []
        for _ in range(2):
            r = subprocess.run([sys.executable, os.path.abspath(__file__), "check", p], capture_output=True, text=True, env=dict(os.environ, SCRIP_BIN=scrip))
            line = next((ln for ln in r.stdout.split("\n") if ln.startswith("LAB_RUN ")), "")
            lines.append(line)
            if r.returncode != 1 or " cells=2 same=1 differs=1 first=2" not in line:
                bad.append("the planted notebook read %r rc %d (wanted rc 1, cells=2 same=1 differs=1 first=2)" % (line or r.stdout.strip()[-300:], r.returncode))
        if lines[0] != lines[1]:
            bad.append("two runs differ: %r and %r" % tuple(lines))
        nochrome = os.path.join(top, "bin")
        os.makedirs(nochrome)
        r = subprocess.run([sys.executable, os.path.abspath(__file__), "check", p], capture_output=True, text=True, env=dict(os.environ, SCRIP_BIN=scrip, PATH=nochrome))
        if r.returncode != 2 or "no Chrome" not in r.stdout:
            bad.append("with no Chrome on PATH it read rc %d: %s" % (r.returncode, r.stdout.strip()[-200:]))
    finally:
        shutil.rmtree(top, ignore_errors=True)
    if bad:
        for b in bad:
            print("LAB_RUN_PROBE RED: " + b)
        return 1
    print("LAB_RUN_PROBE ok planted=rc1-first2 runs=alike nochrome=rc2")
    return 0


def main(argv):
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    scrip = os.environ.get("SCRIP_BIN")
    if not scrip:
        try:
            import harness_paths
            scrip = os.path.join(str(harness_paths.scrip()), "scrip")
        except Exception:
            scrip = os.path.join(os.environ.get("S4E_SCRIP", "."), "scrip")
    if len(argv) >= 2 and argv[1] == "--probe":
        return probe(scrip)
    if len(argv) >= 3 and argv[1] == "check":
        return session(scrip, "check", argv[2:])
    if len(argv) == 2 and argv[1] in ("interrupt", "restart"):
        return session(scrip, argv[1], [])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
