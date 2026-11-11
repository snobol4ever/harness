#!/usr/bin/env python3
"""util_jupyterlab_highlight_look.py -- THE LOOK A MACHINE CAN TAKE AT THE HIGHLIGHTER: A REAL JUPYTERLAB, A REAL BROWSER, ONE CELL A LANGUAGE (CIO-81, CTO-597).

  util_jupyterlab_highlight_look.py LABEXTENSION_DIR     (the built folder, corpus/editor_configs/jupyterlab/labextension)

For each of the four languages a one-cell notebook is written whose metadata names the language (language_info with the editor mode the extension registers), and
for the ONE KERNEL, scrip, a notebook of three cells: one with no tag (SNOBOL4), one tagged icon, one tagged prolog, each to be coloured by its own language. JupyterLab is started twice in scratch on a free port with a token, once with the extension copied into its data directory and once
without, and headless Chrome dumps the page of each notebook. A language is COLOURED when a line of its cell holds a span CodeMirror classed, PLAIN when
its lines hold text alone. One line a language:
  HIGHLIGHT_LOOK lang=NAME with=COLOURED|PLAIN without=COLOURED|PLAIN spans=N
and HIGHLIGHT_LOOK ok languages=5 when every language reads COLOURED with the extension and PLAIN without it.
rc 0 so; rc 1 a language reads otherwise; rc 2 could not measure (no Chrome, no JupyterLab, no built extension, a page with no cell).
Nothing is written outside the scratch folder under /tmp/s4e/<seat>, which is removed; the servers are stopped by their own process handles."""
import json, os, re, shutil, socket, subprocess, sys, tempfile, time, urllib.request, uuid

CELLS = {"snobol4": ("text/x-snobol4", ".sno", "* a comment line\nLOOP    X = LT(X, 10) X + 1 ' text' :S(LOOP)F(DONE)\n        OUTPUT = DUPL('ab', 3)\n"),
         "snocone": ("text/x-snocone", ".sc", "// a comment line\nif (GT(x, 10)) { OUTPUT = \"big \" x; }\n"),
         "icon": ("text/x-icon", ".icn", "# a comment line\nprocedure main()\n   every write(\"n \", 1 to 3)\nend\n"),
         "prolog": ("text/x-prolog", ".pl", "% a comment line\nparent(tom, bob).\ngrand(X, Z) :- parent(X, Y), parent(Y, Z), write('ok').\n"),
         "scrip": ("text/x-scrip", ".md", "* the one kernel: a cell with no tag is SNOBOL4\n        OUTPUT = DUPL('ab', 3)\n\f%%icon\nprocedure main()\n   every write(\"n \", 1 to 3)\nend\n\f%%prolog\ngrand(X, Z) :- parent(X, Y), parent(Y, Z).\n")}


def refuse(msg):
    print("REFUSE(2) [util_jupyterlab_highlight_look]: " + msg); sys.exit(2)


def look(top, ext, chrome):
    data, work = os.path.join(top, "data"), os.path.join(top, "work")
    shutil.rmtree(data, ignore_errors=True); os.makedirs(os.path.join(data, "labextensions")); os.makedirs(work, exist_ok=True)
    if ext: shutil.copytree(ext, os.path.join(data, "labextensions", "scrip-highlight"))
    for name, (mime, fext, src) in CELLS.items():
        json.dump({"cells": [{"cell_type": "code", "execution_count": None, "metadata": {}, "outputs": [], "source": part.splitlines(True)} for part in src.split("\f")],
                   "metadata": {"language_info": {"name": name, "file_extension": fext, "mimetype": mime, "codemirror_mode": name}}, "nbformat": 4, "nbformat_minor": 5}, open(os.path.join(work, name + ".ipynb"), "w"))
    s = socket.socket(); s.bind(("127.0.0.1", 0)); port = s.getsockname()[1]; s.close(); tok = uuid.uuid4().hex
    env = dict(os.environ, JUPYTER_DATA_DIR=data, JUPYTER_CONFIG_DIR=os.path.join(top, "cfg"), JUPYTER_RUNTIME_DIR=os.path.join(top, "rt"), JUPYTER_TOKEN=tok)
    env.pop("JUPYTER_PATH", None)
    srv = subprocess.Popen([sys.executable, "-m", "jupyterlab", "--no-browser", "--port=%d" % port, "--ServerApp.port_retries=0", "--ServerApp.root_dir=" + work, "--LabApp.news_url=",
                            "--LabApp.check_for_updates_class=jupyterlab.NeverCheckForUpdate"], env=env, stdout=open(os.path.join(top, "lab.log"), "w"), stderr=subprocess.STDOUT)
    got = {}
    try:
        for _ in range(200):
            try: urllib.request.urlopen("http://127.0.0.1:%d/api/status?token=%s" % (port, tok), timeout=5); break
            except Exception: time.sleep(0.3)
        for name in CELLS:
            dom = subprocess.run([chrome, "--headless=new", "--disable-gpu", "--no-sandbox", "--no-first-run", "--disable-background-networking", "--disable-sync", "--disable-extensions",
                                  "--user-data-dir=" + os.path.join(top, "chrome"), "--window-size=1400,1000", "--virtual-time-budget=45000", "--dump-dom",
                                  "http://127.0.0.1:%d/lab/tree/%s.ipynb?token=%s" % (port, name, tok)], capture_output=True, text=True, timeout=240).stdout
            lines = [l for l in re.findall(r'<div class="cm-line"[^>]*>(.*?)</div>', dom, re.S) if l.strip() not in ("", "<br>")]
            got[name] = (len(lines), sum(len(re.findall(r'<span class="[^"]+">', l)) for l in lines))
    finally:
        srv.terminate()
        try: srv.wait(30)
        except Exception: srv.kill()
    return got


def main(a):
    if len(a) != 1: print(__doc__); return 2
    ext = os.path.abspath(a[0])
    if not os.path.exists(os.path.join(ext, "package.json")): refuse("no built extension at " + ext)
    chrome = shutil.which("google-chrome") or shutil.which("chromium") or shutil.which("chromium-browser")
    if not chrome: refuse("no Chrome or Chromium on the path")
    try: import jupyterlab  # noqa: F401
    except ImportError: refuse("jupyterlab is not importable")
    base = os.path.join("/tmp/s4e", os.environ.get("S4E_SEAT", "look")); os.makedirs(base, exist_ok=True)
    top = tempfile.mkdtemp(prefix="highlight-look-", dir=base)
    try:
        yes, no = look(top, ext, chrome), look(top, None, chrome)
    finally:
        shutil.rmtree(top, ignore_errors=True)
    bad = 0
    for name in CELLS:
        if yes[name][0] == 0 or no[name][0] == 0: refuse("the page of %s shows no cell line (with the extension %r, without %r)" % (name, yes[name], no[name]))
        w, wo = "COLOURED" if yes[name][1] else "PLAIN", "COLOURED" if no[name][1] else "PLAIN"
        print("HIGHLIGHT_LOOK lang=%s with=%s without=%s spans=%d" % (name, w, wo, yes[name][1]))
        bad += (w, wo) != ("COLOURED", "PLAIN")
    print("HIGHLIGHT_LOOK ok languages=%d" % len(CELLS) if not bad else "HIGHLIGHT_LOOK RED: %d language(s) do not read coloured with the extension and plain without it" % bad)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
