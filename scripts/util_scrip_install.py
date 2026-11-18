#!/usr/bin/env python3
"""util_scrip_install.py -- THE ONE VERB THAT INSTALLS SCRIP FOR LON'S JUPYTER LAB, AND THE CHECK THAT READS THE INSTALL
(row jupyter-lons-installed-kernel-runs-an-origin-build-in-a-folder-of-its-own, the cao's baton of 2026-11-18, the chairman's laws, the place Lon's:
"I created /home/bin for installed programs."). Lon's installed kernel used to run /home/claude_cto/scrip, whatever the cto's root held that minute.

  util_scrip_install.py install [COMMIT] [--prebuilt ROOT] [--dry-run] [--force]
        build origin/main (or the named commit on it; or take ROOT, a clean built tree at it), write /home/bin/scrip.d beside the old, rename the old away and the new in,
        write the launcher /home/bin/scrip and the kernel spec
  util_scrip_install.py check      read the install and the kernel spec against origin/main
  util_scrip_install.py --probe    the verb's own proof on a scratch bin folder, a scratch kernels folder and a scratch origin

THE LAYOUT (the chairman's ruling 2026-11-18; DIR = /home/bin, `--bin-dir` or S4E_BIN_DIR): DIR/scrip.d/ holds `scrip`, `out/libscrip_*.so` and `out/scrip-ipp` (the runtime set,
never the build's intermediate objects) and `MANIFEST` (the origin commit it was built from); DIR/scrip is a one-line launcher that execs DIR/scrip.d/scrip, never a symbolic
link. No copy of the kernel session program is kept in the install, and no scrip.d.prev: the way back is the verb installing a named commit (`install COMMIT`, a commit on
origin/main). The swap is whole by rename and the old folder is removed. THE SPEC is written by the installed binary (scrip --kernel-install KERNELS) with the session program of the built commit named by SCRIP_SESSION_SNOBOL4, which the
binary copies into the kernel folder; the verb then sets the spec's argv to the launcher DIR/scrip, so the spec names only the install and the kernel folder. Lon's old
kernel.json is kept beside the new as kernel.json.bak-YYYY-MM-DD (the first time that day only).
THE INSTALL IS NOT AUTOMATIC AT A LANDING: a Lab Lon has open must not have its binary change under it. `install` says so and installs nothing (rc 2) when any process runs
the binary of DIR/scrip.d (`--force`, for a person who says so, installs anyway). The seat that lands a Jupyter row runs the verb.
`check` reads RED (rc 1) when the spec's argv or its session path lies under a /home/claude_ root, when the spec does not run the launcher DIR/scrip, when the launcher or
DIR/scrip.d/scrip is missing or not executable, when the MANIFEST is missing or its commit is not on origin/main; it always says how many commits behind origin/main the
install is. rc 2: could not measure.
ONE TABLE accounts for everything installed: DIR/INSTALLED.tsv, written by this verb alone, one row a name (name, kind built|mode4|launcher, target, origin commit or package path,
date, seat); `check` reads RED for a name of DIR that no row accounts for (a NAME.d folder is accounted by its NAME row; the table and the install lock are the verb's own). THE WALL:
`check` reads RED when a script of the harness (`--scripts`, the harness's scripts folder) names DIR, this verb excepted: no harness script reads an oracle or anything through it.
ORIGIN is the bare store /home/SCRIP.git, which its keeper fetches every minute (`--repo`, S4E_INSTALL_REPO), ref main (`--ref`). Mode 3 only: nothing here compiles in mode 4."""
import datetime, fcntl, glob, hashlib, json, os, re, shutil, subprocess, sys, tempfile, time
from pathlib import Path

def refuse(m):
    print(f"REFUSE(2) [util_scrip_install]: {m}"); sys.exit(2)

av = sys.argv[1:]
opt = {"bin-dir": os.environ.get("S4E_BIN_DIR", "/home/bin"),
       "kernels": os.environ.get("S4E_KERNELS_DIR", str(Path(os.environ.get("HOME", "/home/satirical")) / ".local/share/jupyter/kernels")),
       "repo": os.environ.get("S4E_INSTALL_REPO", "/home/SCRIP.git"), "ref": "main", "prebuilt": "", "commit": "", "scripts": str(Path(os.environ.get("S4E_HARNESS") or "/home/harness") / "scripts")}
flags = {"dry-run": False, "force": False, "no-notebooks": False}
verb = None
i = 0
while i < len(av):
    a = av[i]
    if a in ("install", "check", "--probe") and verb is None: verb = a
    elif a.startswith("--") and a[2:] in opt:
        if i + 1 >= len(av): refuse(f"{a} takes a value")
        opt[a[2:]] = av[i + 1]; i += 1
    elif a.startswith("--") and a[2:] in flags: flags[a[2:]] = True
    elif verb == "install" and not a.startswith("--") and not opt["commit"]: opt["commit"] = a
    else: refuse(f"unknown argument {a}; usage: install [COMMIT] [--prebuilt ROOT] [--dry-run] [--force] | check | --probe [--no-notebooks]   (--bin-dir --kernels --repo --ref --scripts)")
    i += 1
if verb is None: refuse("usage: install [COMMIT] [--prebuilt ROOT] [--dry-run] [--force] | check | --probe [--no-notebooks]")

def sh(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)

def git(*a, repo=None):
    return sh(["git", "-C", repo or opt["repo"], *a])

def origin_tip():
    r = git("rev-parse", "--verify", "-q", f"{opt['ref']}^{{commit}}")
    if r.returncode: refuse(f"no ref {opt['ref']} in {opt['repo']}")
    return r.stdout.strip()

def install_commit():
    tip = origin_tip()
    if not opt["commit"]: return tip
    r = git("rev-parse", "--verify", "-q", f"{opt['commit']}^{{commit}}")
    if r.returncode: refuse(f"the commit {opt['commit']} is not in {opt['repo']}")
    c = r.stdout.strip()
    if git("merge-base", "--is-ancestor", c, tip).returncode: refuse(f"the commit {c[:10]} is not on origin/{opt['ref']}: an install is a build of origin")
    return c

def prog_dir(): return Path(opt["bin-dir"]) / "scrip.d"
def launcher(): return Path(opt["bin-dir"]) / "scrip"
def spec_path(): return Path(opt["kernels"]) / "scrip" / "kernel.json"

def read_manifest(d):
    m = {}
    f = d / "MANIFEST"
    if f.is_file():
        for l in f.read_text().splitlines():
            if " " in l: k, v = l.split(" ", 1); m[k] = v.strip()
    return m

def running_from(d):
    """the pids whose executable is a file of the folder d: a kernel, a run, anything that holds the installed binary"""
    pre = str(d.resolve() if d.exists() else d) + "/"
    hold = []
    for p in glob.glob("/proc/[0-9]*/exe"):
        try: t = os.readlink(p)
        except OSError: continue
        if t.startswith(pre): hold.append((p.split("/")[2], t))
    return hold

def check():
    red = []
    d, L, spec, tip = prog_dir(), launcher(), spec_path(), origin_tip()
    if not spec.is_file(): refuse(f"no kernel spec {spec}")
    try: js = json.loads(spec.read_text())
    except ValueError as e: refuse(f"the kernel spec {spec} does not parse: {e}")
    argv0 = (js.get("argv") or [""])[0]
    sess = (js.get("env") or {}).get("SCRIP_SESSION_SNOBOL4", "")
    if re.match(r"/home/claude_", argv0): red.append(f"the spec's argv {argv0} lies under a seat root")
    if re.match(r"/home/claude_", sess): red.append(f"the spec's SCRIP_SESSION_SNOBOL4 {sess} lies under a seat root")
    if argv0 != str(L): red.append(f"the spec runs {argv0}, not the launcher {L}")
    if sess and not sess.startswith(str(spec.parent) + "/"): red.append(f"the spec's SCRIP_SESSION_SNOBOL4 {sess} is not in the kernel folder {spec.parent}")
    if L.is_symlink(): red.append(f"the launcher {L} is a symbolic link")
    elif not (L.is_file() and os.access(L, os.X_OK)): red.append(f"the launcher {L} is missing or not executable")
    elif "exec" not in L.read_text() or "scrip.d/scrip" not in L.read_text(): red.append(f"the launcher {L} does not exec scrip.d/scrip")
    b = d / "scrip"
    if not (b.is_file() and os.access(b, os.X_OK)): red.append(f"the binary {b} is missing or not executable")
    if not (d / "out" / "libscrip_rt.so").is_file(): red.append(f"the runtime {d / 'out/libscrip_rt.so'} is missing")
    commit, behind = read_manifest(d).get("commit", ""), "?"
    if not commit: red.append(f"no MANIFEST with a commit in {d}")
    elif git("cat-file", "-e", f"{commit}^{{commit}}").returncode: red.append(f"the MANIFEST's commit {commit[:10]} is not in {opt['repo']}")
    elif git("merge-base", "--is-ancestor", commit, tip).returncode: red.append(f"the MANIFEST's commit {commit[:10]} is not on origin/{opt['ref']}")
    else: behind = git("rev-list", "--count", f"{commit}..{tip}").stdout.strip()
    bd = Path(opt["bin-dir"])
    T = bd / "INSTALLED.tsv"
    rows = {l.split("\t")[0] for l in T.read_text().splitlines() if l and not l.startswith("#")} if T.is_file() else set()
    if not T.is_file(): red.append(f"no {T}")
    elif "scrip" not in rows: red.append(f"{T} has no row for scrip")
    if bd.is_dir():
        for x in sorted(bd.iterdir()):
            if x.name in (".install.lock", "INSTALLED.tsv"): continue
            base = x.name[:-2] if x.name.endswith(".d") and x.is_dir() else x.name
            if base not in rows: red.append(f"{bd} holds {x.name}, which no row of INSTALLED.tsv accounts for")
    sd = Path(opt["scripts"])
    me = Path(__file__).resolve().name
    if sd.is_dir():
        for f in sorted(sd.iterdir()):
            if f.is_file() and f.name != me:
                try: txt = f.read_bytes()
                except OSError: continue
                if str(bd).encode() in txt: red.append(f"the harness script {f.name} names {bd}: no script of the harness reads anything through it")
    print(f"INSTALL_CHECK dir={d} commit={commit[:10] or '-'} origin={tip[:10]} behind={behind} argv={argv0}")
    for r in red: print("RED " + r)
    return 1 if red else 0

def build_tree(work, commit):
    if opt["prebuilt"]:
        root = Path(opt["prebuilt"]).resolve()
        head = sh(["git", "-C", str(root), "rev-parse", "HEAD"]).stdout.strip()
        if head != commit: refuse(f"--prebuilt {root} is at {head[:10]}, the commit to install is {commit[:10]}")
        if sh(["git", "-C", str(root), "status", "--porcelain", "--untracked-files=no"]).stdout.strip():
            refuse(f"--prebuilt {root} holds a tracked change; an install is a build of origin, never of a working tree")
        return root
    src = work / "src"
    r = sh(["git", "clone", "-q", "--shared", "--no-checkout", opt["repo"], str(src)])
    if r.returncode: refuse("clone of the origin store failed: " + r.stderr.strip()[:200])
    r = sh(["git", "-C", str(src), "checkout", "-q", "--detach", commit])
    if r.returncode: refuse("checkout of " + commit[:10] + " failed: " + r.stderr.strip()[:200])
    print(f"BUILD {commit[:10]} in {src} (make -j8; the build cache answers FETCHED when it holds the tree)", flush=True)
    r = subprocess.run(["make", "-j8"], cwd=src, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    sys.stdout.write("\n".join(r.stdout.splitlines()[-3:]) + "\n")
    if r.returncode: refuse(f"make failed rc {r.returncode}")
    return src

def assemble(root, new, commit):
    (new / "out").mkdir(parents=True)
    shutil.copy2(root / "scrip", new / "scrip")
    n = 1
    for f in sorted(glob.glob(str(root / "out" / "libscrip_*.so"))):
        base = os.path.basename(f)
        if base == "libscrip_rt0.so" or re.search(r"-[0-9a-f]{10}\.so$", base): continue
        shutil.copy2(f, new / "out" / base, follow_symlinks=True); n += 1
    if (root / "out/scrip-ipp").is_file(): shutil.copy2(root / "out/scrip-ipp", new / "out/scrip-ipp"); n += 1
    if not (new / "out/libscrip_rt.so").is_file(): refuse(f"{root} holds no out/libscrip_rt.so: not a built tree")
    have = {os.path.basename(f) for f in glob.glob(str(new / "out" / "*.so"))}
    mine = {os.path.basename(f) for f in glob.glob(str(root / "out" / "*.so"))}
    for f in [new / "scrip"] + sorted((new / "out").glob("*.so")):
        for l in sh(["readelf", "-d", str(f)]).stdout.splitlines():
            m = re.search(r"NEEDED.*\[(.+)\]", l)
            if m and m.group(1) in mine and m.group(1) not in have: refuse(f"{f.name} needs {m.group(1)} of the build's out/, which the runtime set does not carry")
    bi = {}
    if (root / "out/buildinfo").is_file():
        for l in (root / "out/buildinfo").read_text().splitlines():
            if " " in l: k, v = l.split(" ", 1); bi[k] = v.strip()
    tree = git("rev-parse", f"{commit}^{{tree}}").stdout.strip()
    sha = hashlib.sha256((new / "scrip").read_bytes()).hexdigest()
    (new / "MANIFEST").write_text(f"commit {commit}\ntree {tree}\nbuilt {datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}\n"
                                  f"by {os.environ.get('S4E_SEAT', 'unknown')}\nbuild-key {bi.get('key', '-')}\nbuild-source {bi.get('source', '-')}\n"
                                  f"scrip-sha256 {sha}\nfiles {n + 1}\n")
    smoke = new / "smoke.sno"
    smoke.write_text("      OUTPUT = 'installed-ok'\nEND\n")
    r = sh([str(new / "scrip"), "--run", str(smoke)], cwd=new)
    smoke.unlink()
    if r.stdout.strip() != "installed-ok": refuse(f"the assembled binary does not run a SNOBOL4 program: rc {r.returncode} {r.stdout.strip()[:80]} {r.stderr.strip()[:120]}")

def table_row(bin_dir, name, kind, target, origin):
    T = bin_dir / "INSTALLED.tsv"
    rows = [l for l in T.read_text().splitlines() if l and l.split("\t")[0] != name] if T.is_file() else []
    rows.append("\t".join([name, kind, target, origin, datetime.date.today().isoformat(), os.environ.get("S4E_SEAT", "unknown")]))
    head = [r for r in rows if r.startswith("#")] or ["#name\tkind\ttarget\torigin\tdate\tseat"]
    body = sorted(r for r in rows if not r.startswith("#"))
    tmp = bin_dir / f".INSTALLED.tsv.{os.getpid()}"
    tmp.write_text("\n".join(head + body) + "\n"); os.rename(tmp, T)

LAUNCHER = '#!/bin/sh\nexec "$(dirname "$0")/scrip.d/scrip" "$@"\n'

def write_launcher(bin_dir):
    L = bin_dir / "scrip"
    if L.is_file() and not L.is_symlink() and L.read_text() == LAUNCHER and os.access(L, os.X_OK): return
    tmp = bin_dir / f".scrip.launcher.{os.getpid()}"
    tmp.write_text(LAUNCHER)
    os.chmod(tmp, 0o755); os.rename(tmp, bin_dir / "scrip")

def install():
    bin_dir, d, commit = Path(opt["bin-dir"]), prog_dir(), install_commit()
    bin_dir.mkdir(parents=True, exist_ok=True)
    lock = open(bin_dir / ".install.lock", "w")
    try: fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError: refuse("another install holds the lock")
    held = [] if flags["force"] else running_from(d)
    if held:
        print("INSTALL_REFUSED a process runs the installed binary, so its binary is not changed under it (the install is not automatic at a landing):")
        for pid, t in held[:6]: print(f"  pid {pid} {t}")
        refuse("installs nothing; close the Lab's kernel (or the run) and run the verb again, or say --force")
    cur = read_manifest(d).get("commit", "")
    seat = os.environ.get("S4E_SEAT", "seat")
    work = Path(tempfile.mkdtemp(prefix="scrip_install.", dir=f"/tmp/s4e/{seat}" if os.path.isdir(f"/tmp/s4e/{seat}") else None))
    try:
        root = build_tree(work, commit)
        new = bin_dir / f"scrip.d.new.{os.getpid()}"
        shutil.rmtree(new, ignore_errors=True)
        assemble(root, new, commit)
        if flags["dry-run"]:
            print(f"INSTALL_DRYRUN commit={commit[:10]} installed={cur[:10] or '-'}: {new} built and run once; nothing renamed"); shutil.rmtree(new); return 0
        old = bin_dir / f"scrip.d.old.{os.getpid()}"
        had = d.exists()
        if had: os.rename(d, old)
        os.rename(new, d)
        spec = spec_path(); bak = spec.parent / f"kernel.json.bak-{datetime.date.today().isoformat()}"
        spec_before = spec.read_bytes() if spec.is_file() else None
        try:
            if spec_before is not None and not bak.exists(): spec.parent.mkdir(parents=True, exist_ok=True); bak.write_bytes(spec_before)
            env = dict(os.environ, SCRIP_SESSION_SNOBOL4=str(root / "src/driver/kernel_session_snobol4.sno"))
            r = sh([str(d / "scrip"), "--kernel-install", opt["kernels"]], env=env)
            if r.returncode or "KERNELSPEC" not in r.stdout: raise RuntimeError(f"scrip --kernel-install rc {r.returncode}: {r.stderr.strip()[:200]}")
            js = json.loads(spec.read_text()); js["argv"][0] = str(launcher())
            tmp = spec.with_name("kernel.json.tmp"); tmp.write_text(json.dumps(js, separators=(",", ":")) + "\n"); os.rename(tmp, spec)
            write_launcher(bin_dir)
        except Exception as e:
            shutil.rmtree(d, ignore_errors=True)
            if had: os.rename(old, d)
            if spec_before is not None: spec.write_bytes(spec_before)
            refuse(f"the install did not complete ({e}); it is as it was")
        if had: shutil.rmtree(old, ignore_errors=True)
        table_row(bin_dir, "scrip", "built", str(d / "scrip"), commit)
        print(f"INSTALLED {d} commit={commit[:10]} (was {cur[:10] or 'nothing'}); launcher {launcher()}; spec {spec}")
        return 0
    finally:
        shutil.rmtree(work, ignore_errors=True)

NBCHECK = next(str(c) for c in (Path(__file__).resolve().parent / "util_notebook_kernel_check.py", Path("/home/harness/scripts/util_notebook_kernel_check.py")) if c.is_file())

def probe():
    """fifteen arms on a scratch bin folder, a scratch kernels folder and a scratch origin: never /home/bin, never a real spec"""
    scrip_root = Path(os.environ.get("S4E_SCRIP") or os.getcwd())
    if not (scrip_root / "scrip").is_file(): refuse(f"--probe needs a built SCRIP tree (S4E_SCRIP or the working folder): no {scrip_root}/scrip")
    seat = os.environ.get("S4E_SEAT", "seat")
    tmp = Path(tempfile.mkdtemp(prefix="scrip_install_probe.", dir=f"/tmp/s4e/{seat}" if os.path.isdir(f"/tmp/s4e/{seat}") else None))
    me = [sys.executable, "-I", os.path.abspath(__file__)]
    res = {}
    try:
        origin = tmp / "origin.git"
        r = sh(["git", "clone", "-q", "--bare", "--shared", str(scrip_root), str(origin)])
        if r.returncode: refuse("the scratch origin failed: " + r.stderr[:200])
        head = sh(["git", "-C", str(scrip_root), "rev-parse", "HEAD"]).stdout.strip()
        git("update-ref", "refs/heads/main", head, repo=str(origin))
        (tmp / "scripts").mkdir()
        common = ["--bin-dir", str(tmp / "bin"), "--kernels", str(tmp / "kernels"), "--repo", str(origin), "--scripts", str(tmp / "scripts")]
        env = dict(os.environ, HOME=str(tmp / "home"))
        def run(*a): return subprocess.run(me + list(a) + common, capture_output=True, text=True, env=env)
        K = tmp / "kernels/scrip"; B = tmp / "bin"
        K.mkdir(parents=True); (tmp / "home").mkdir()
        old_spec = '{"argv":["/home/claude_cto/scrip","--kernel","{connection_file}"],"env":{}}\n'
        (K / "kernel.json").write_text(old_spec)
        # 1: the first install writes scrip.d with its MANIFEST, the launcher and the spec, and keeps Lon's old spec
        r = run("install", "--prebuilt", str(scrip_root))
        spec = json.loads((K / "kernel.json").read_text()) if (K / "kernel.json").is_file() else {}
        bak = list(K.glob("kernel.json.bak-*"))
        sess = spec.get("env", {}).get("SCRIP_SESSION_SNOBOL4", "")
        res["install"] = (r.returncode == 0 and (B / "INSTALLED.tsv").is_file() and "scrip\tbuilt\t" in (B / "INSTALLED.tsv").read_text() and (B / "scrip.d/MANIFEST").is_file() and (B / "scrip").is_file() and not (B / "scrip").is_symlink()
                          and spec.get("argv", [""])[0] == str(B / "scrip") and sess == str(K / "kernel_session_snobol4.sno") and (K / "kernel_session_snobol4.sno").is_file()
                          and len(bak) == 1 and bak[0].read_text() == old_spec and not list(B.glob("scrip.d.*")) and not (B / "scrip.d/src").exists(),
                          r.stdout[-300:] + r.stderr[-300:])
        # 2: the launcher runs a program through the installed binary
        sno = tmp / "t.sno"; sno.write_text("      OUTPUT = 'via-launcher'\nEND\n")
        r = subprocess.run([str(B / "scrip"), "--run", str(sno)], capture_output=True, text=True)
        res["launcher"] = (r.stdout.strip() == "via-launcher", r.stdout[-200:] + r.stderr[-200:])
        # 3: check reads GREEN and says behind=0
        r = run("check"); res["check_ok"] = (r.returncode == 0 and "behind=0" in r.stdout, r.stdout[-300:] + r.stderr[-200:])
        # 4: a spec naming a seat root reads RED
        good = (K / "kernel.json").read_text()
        (K / "kernel.json").write_text(good.replace(str(B / "scrip"), "/home/claude_cto/scrip"))
        r = run("check"); res["red_root"] = (r.returncode == 1 and "seat root" in r.stdout, r.stdout[-300:])
        (K / "kernel.json").write_text(good)
        # 5: a MANIFEST commit not on origin/main reads RED; a parent of origin's tip reads behind=1
        mf = (B / "scrip.d/MANIFEST").read_text()
        (B / "scrip.d/MANIFEST").write_text(re.sub(r"^commit .*$", "commit " + "1" * 40, mf, flags=re.M))
        r = run("check"); res["red_commit"] = (r.returncode == 1 and "is not" in r.stdout, r.stdout[-300:])
        gid = dict(os.environ, GIT_AUTHOR_NAME="p", GIT_AUTHOR_EMAIL="p@p", GIT_COMMITTER_NAME="p", GIT_COMMITTER_EMAIL="p@p")
        off = subprocess.run(["git", "-C", str(origin), "commit-tree", head + "^{tree}", "-p", head, "-m", "off main"], capture_output=True, text=True, env=gid).stdout.strip()
        (B / "scrip.d/MANIFEST").write_text(re.sub(r"^commit .*$", "commit " + off, mf, flags=re.M))
        r = run("check"); res["red_offmain"] = (r.returncode == 1 and "not on origin" in r.stdout, r.stdout[-300:])
        parent = sh(["git", "-C", str(scrip_root), "rev-parse", "HEAD~1"]).stdout.strip()
        (B / "scrip.d/MANIFEST").write_text(re.sub(r"^commit .*$", "commit " + parent, mf, flags=re.M))
        r = run("check"); res["behind"] = (r.returncode == 0 and "behind=1" in r.stdout, r.stdout[-300:])
        (B / "scrip.d/MANIFEST").write_text(mf)
        # 6: a missing binary reads RED
        os.rename(B / "scrip.d/scrip", B / "scrip.d/scrip.away")
        r = run("check"); res["red_binary"] = (r.returncode == 1 and "missing" in r.stdout, r.stdout[-300:])
        os.rename(B / "scrip.d/scrip.away", B / "scrip.d/scrip")
        # 7: a process running the installed binary stops an install, which changes nothing
        loop = tmp / "loop.sno"; loop.write_text("L     :(L)\nEND\n")
        p = subprocess.Popen([str(B / "scrip"), "--run", str(loop)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            time.sleep(0.7)
            r = run("install", "--prebuilt", str(scrip_root))
            res["refuse_running"] = (r.returncode == 2 and "installs nothing" in r.stdout and (B / "scrip.d/MANIFEST").read_text() == mf and not list(B.glob("scrip.d.*")), r.stdout[-300:])
        finally:
            p.kill(); p.wait()
        # 8: the second install replaces the first and leaves no scrip.d.prev, old or new; a commit not on origin is refused
        r = run("install", "--prebuilt", str(scrip_root))
        r2 = run("install", "1" * 40, "--prebuilt", str(scrip_root))
        res["replace"] = (r.returncode == 0 and not list(B.glob("scrip.d.*")) and r2.returncode == 2, r.stdout[-200:] + r.stderr[-200:] + r2.stdout[-200:])
        # 9: a name no MANIFEST accounts for reads RED, and the launcher is rewritten only when it differs (same inode and mtime kept)
        (B / "stray.txt").write_text("x")
        r = run("check"); res["red_stray"] = (r.returncode == 1 and "stray.txt" in r.stdout, r.stdout[-300:])
        (B / "stray.txt").unlink()
        m0 = os.stat(B / "scrip").st_mtime_ns
        r = run("install", "--prebuilt", str(scrip_root))
        res["launcher_kept"] = (r.returncode == 0 and os.stat(B / "scrip").st_mtime_ns == m0, r.stdout[-200:] + r.stderr[-200:])
        # 9b: a script of the harness that names the bin folder reads RED; a missing table row for scrip reads RED
        (tmp / "scripts/lib_x.sh").write_text(f"ORACLE={B}/icont\n")
        r = run("check"); res["red_wall"] = (r.returncode == 1 and "lib_x.sh" in r.stdout, r.stdout[-300:])
        (tmp / "scripts/lib_x.sh").unlink()
        tb = (B / "INSTALLED.tsv").read_text()
        (B / "INSTALLED.tsv").write_text("#name\n")
        r = run("check"); res["red_table"] = (r.returncode == 1 and "no row for scrip" in r.stdout, r.stdout[-300:])
        (B / "INSTALLED.tsv").write_text(tb)
        # 10: the eight language notebooks run through an installed kernel with the build tree gone: the install is built from a scratch tree that is deleted before the run
        if not flags["no-notebooks"]:
            bt = tmp / "bt"
            sh(["git", "clone", "-q", "--shared", "--no-checkout", str(scrip_root), str(bt)])
            sh(["git", "-C", str(bt), "checkout", "-q", "--detach", head])
            (bt / "out").mkdir(exist_ok=True)
            shutil.copy2(scrip_root / "scrip", bt / "scrip")
            for f in glob.glob(str(scrip_root / "out" / "libscrip_*.so")) + glob.glob(str(scrip_root / "out" / "scrip-ipp")) + glob.glob(str(scrip_root / "out" / "buildinfo")):
                shutil.copy2(f, bt / "out" / os.path.basename(f))
            two = ["--bin-dir", str(tmp / "bin2"), "--kernels", str(tmp / "kernels2"), "--repo", str(origin)]
            r = subprocess.run(me + ["install", "--prebuilt", str(bt)] + two, capture_output=True, text=True, env=env)
            shutil.rmtree(bt, ignore_errors=True)
            nbs = [f"/home/corpus/notebooks/{n}.ipynb" for n in ("Icon_in_SCRIP", "Prolog_in_SCRIP", "Pascal_in_SCRIP", "Raku_in_SCRIP", "Unicon_in_SCRIP", "Snocone_in_SCRIP", "Rebus_in_SCRIP", "DEFINE_statement")]
            nenv = dict(env, SCRIP_BIN=str(tmp / "bin2/scrip.d/scrip"), SCRIP_SESSION_SNOBOL4=str(tmp / "kernels2/scrip/kernel_session_snobol4.sno"))
            nenv.pop("S4E_SCRIP", None); nenv["HOME"] = os.environ.get("HOME", "/home/satirical")
            n = subprocess.run([sys.executable, NBCHECK, "check"] + nbs, capture_output=True, text=True, env=nenv)
            lines = [l for l in n.stdout.splitlines() if l.startswith("NOTEBOOK_KERNEL")]
            cenv = dict(nenv, SCRIP_BIN=str(scrip_root / "scrip")); cenv.pop("SCRIP_SESSION_SNOBOL4", None)
            c = subprocess.run([sys.executable, NBCHECK, "check"] + nbs, capture_output=True, text=True, env=cenv)
            ctl = [l for l in c.stdout.splitlines() if l.startswith("NOTEBOOK_KERNEL")]
            # THE ARM READS "AS THE BUILD TREE'S OWN BINARY": the installed kernel's eight lines equal the lines of the same build run in place, so a red of the build itself is no fault of the install
            res["notebooks"] = (r.returncode == 0 and not bt.exists() and len(lines) == 8 and lines == ctl, r.stdout[-200:] + r.stderr[-200:] + "installed: " + " | ".join(lines)[-600:] + " control: " + " | ".join(ctl)[-600:])
            print(f"notebooks installed: {' '.join(x.split()[1] + ':' + x.split()[3] + '/' + x.split()[4] for x in lines)}")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    bad = [k for k, (ok, _) in res.items() if not ok]
    for k, (ok, why) in res.items(): print(f"{'ok  ' if ok else 'FAIL'} {k}" + ("" if ok else f": {why.strip()[:300]}"))
    print("PROBE_SCRIP_INSTALL " + ("RED " + ",".join(bad) if bad else f"OK {len(res)} arms"))
    return 1 if bad else 0

sys.exit({"install": install, "check": check, "--probe": probe}[verb]())
