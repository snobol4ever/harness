#!/usr/bin/env python3
"""util_xpce_run.py -- THE XPCE RUNNER (DESIGN-PLAN prolog-xpce step 3, officer_04; the design is /home/resources/progress/prolog-graphics-design-2026-11-16,
DESIGN.md J2 J4 J5 and GRADING.md sections 2 and 5, to move to skill prolog reference section 9). A Prolog program that reaches library(pce) runs
under this script on BOTH sides, the oracle swipl and SCRIP alike, so the two read the same world; corpus_suite_harness.py puts it in front of
the command of every entry its _xpce_wrap selects (an entry named xpce__NAME of a Prolog container, or one named in a package's ALL.xpce),
inside the screen road when the entry has one (util_screen_run.py, the cqo's, unchanged by this script).

  python3 util_xpce_run.py [--pre --prog FILE] -- CMD ARG...
  python3 util_xpce_run.py --probe

WHAT IT DOES, each part a measured need of the design:
  J5  XDG_CONFIG_HOME is one folder, CWD/.xpce-config, EMPTIED BEFORE EVERY RUN: XPCE's layer finds its application-data folder through
      user_app_config(xpce) and makes swi-prolog/ in it on its first run (pce_principal.pl line 143), so a second run in a used folder is
      another program's world.
  J4  standard input is a pipe held open and silent for the whole life of CMD, never the null device: a screen entry's hold is a read of
      user_input (a demo, a rosetta drawing run through its NAME.goal wrapper), and at end of file that read returns at once and the program
      ends before its screen is drawn. The pipe is closed only after CMD has ended, so it outlasts any timeout the caller sets.
  J2  --pre (the oracle's side only): the file pre.pl, one directive, create_prolog_flag(xpce_threaded, false, []), is written in CWD and
      named before the program FILE in CMD, so swipl runs XPCE on ONE thread. On two threads swipl's own answers race (MEASURED by the cfo
      2026-11-16: grading-probes/slowtext.pl, a timer over an open frame, hangs in 3 of 6 runs without pre.pl and ends in 9 of 9 with it).
      A pre.pl already in CWD with other text is refused rc 2.
CMD's standard output and standard error are its own (inherited, never read here); the status is CMD's, 128 plus the signal for one a signal
ended. CMD dies with this script (PR_SET_PDEATHSIG), so a caller that kills the runner at its timeout kills the program.
--probe: the runner's arms on swipl, each fail-once by a plant (S4E_XPCE_RUN_PLANT=keep-folder, null-stdin or no-pre makes the runner
misbehave in that one way, and the arm reads RED under it). Prints XPCE-RUN-PROBE arms=N red=M; rc 0 green, 1 red, 2 could not measure."""
import ctypes
import os
import shutil
import signal
import subprocess
import sys
import tempfile
from pathlib import Path

PRE_TEXT = ":- create_prolog_flag(xpce_threaded, false, []).\n"
CFG_NAME = ".xpce-config"


def refuse(msg):
    sys.stderr.write("REFUSE(2) [util_xpce_run]: %s\n" % msg)
    sys.exit(2)


def _die_with_parent():
    try:
        ctypes.CDLL("libc.so.6", use_errno=True).prctl(1, signal.SIGKILL, 0, 0, 0)   # PR_SET_PDEATHSIG
    except OSError:
        pass


def run(cmd, pre=False, prog=None):
    plant = os.environ.get("S4E_XPCE_RUN_PLANT", "")
    cwd = Path.cwd()
    cfg = cwd / CFG_NAME
    if plant != "keep-folder":
        shutil.rmtree(cfg, ignore_errors=True)
    cfg.mkdir(exist_ok=True)
    if pre and plant != "no-pre":
        if not prog:
            refuse("--pre names the program with --prog FILE")
        hits = [i for i, a in enumerate(cmd) if a == prog]
        if not hits:
            refuse("--prog %s names no word of the command %r" % (prog, cmd))
        p = cwd / "pre.pl"
        if p.exists() and p.read_text(errors="replace") != PRE_TEXT:
            refuse("%s stands with other text than the one directive of pre.pl" % p)
        p.write_text(PRE_TEXT)
        cmd = cmd[:hits[-1]] + ["pre.pl"] + cmd[hits[-1]:]
    env = dict(os.environ, XDG_CONFIG_HOME=str(cfg))
    if plant == "null-stdin":
        r_end, w_end = os.open(os.devnull, os.O_RDONLY), None
    else:
        r_end, w_end = os.pipe()
    _die_with_parent()
    try:
        p = subprocess.Popen(cmd, stdin=r_end, env=env, preexec_fn=_die_with_parent)
    except OSError as e:
        refuse("cannot start %r: %s" % (cmd[:1], e))
    os.close(r_end)
    for s in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        signal.signal(s, lambda n, _f: (p.send_signal(n), None))
    rc = p.wait()
    if w_end is not None:
        os.close(w_end)
    return 128 - rc if rc < 0 else rc


def _swipl():
    r = subprocess.run(["bash", "-c", '. "$1" && swipl_bin', "-", str(Path(__file__).resolve().parent / "lib_oracle_flags.sh")], capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 and r.stdout.strip() else None


def probe():
    sw = _swipl()
    if not sw:
        print("XPCE-RUN-PROBE could not measure: lib_oracle_flags.sh names no swipl")
        return 2
    me = [sys.executable, "-I", str(Path(__file__).resolve())]
    t = Path(tempfile.mkdtemp(prefix="xpce_run_probe_", dir=os.environ.get("TMPDIR")))
    progs = {
        "folder.pl": ":- initialization(main, main).\nmain :- getenv('XDG_CONFIG_HOME', D), directory_files(D, F), msort(F, S), writeln(S), make_directory_path('%s'), true.\n",
        "hold.pl": ":- initialization(main, main).\nmain :- read(user_input, X), writeln(X).\n",
        "flag.pl": ":- initialization(main, main).\nmain :- ( current_prolog_flag(xpce_threaded, V) -> true ; V = none ), writeln(V).\n",
    }
    why, arms = [], 0

    def go(name, extra=(), plant="", tmo=20):
        env = dict(os.environ)
        env.pop("S4E_XPCE_RUN_PLANT", None)
        if plant:
            env["S4E_XPCE_RUN_PLANT"] = plant
        try:
            r = subprocess.run(me + list(extra) + ["--", sw, "-q", name], cwd=str(t), env=env, capture_output=True, text=True, timeout=tmo)
            return r.returncode, r.stdout.strip()
        except subprocess.TimeoutExpired:
            return "HANG", ""

    try:
        (t / "folder.pl").write_text(progs["folder.pl"] % (str(t / CFG_NAME / "swi-prolog" / "left")))
        for n in ("hold.pl", "flag.pl"):
            (t / n).write_text(progs[n])
        arms += 1
        a, b = go("folder.pl"), go("folder.pl")
        if a != (0, "[.,..]") or b != a: why.append("arm 1: the config folder was not empty at each run (%r then %r)" % (a, b))
        arms += 1
        go("folder.pl"); c = go("folder.pl", plant="keep-folder")
        if c == (0, "[.,..]"): why.append("arm 2: the keep-folder plant did not move the folder's answer")
        arms += 1
        h = go("hold.pl", tmo=4)
        if h != ("HANG", ""): why.append("arm 3: a read of standard input did not wait on the held pipe (%r)" % (h,))
        arms += 1
        n = go("hold.pl", plant="null-stdin", tmo=20)
        if n != (0, "end_of_file"): why.append("arm 4: the null-stdin plant did not move the read to end_of_file (%r)" % (n,))
        arms += 1
        f = go("flag.pl", extra=("--pre", "--prog", "flag.pl"))
        if f != (0, "false"): why.append("arm 5: --pre did not run the program on one thread (%r)" % (f,))
        arms += 1
        g = go("flag.pl", extra=("--pre", "--prog", "flag.pl"), plant="no-pre")
        if g == (0, "false"): why.append("arm 6: the no-pre plant did not move the flag's answer")
        arms += 1
        (t / "pre.pl").write_text("% another file\n")
        r = subprocess.run(me + ["--pre", "--prog", "flag.pl", "--", sw, "-q", "flag.pl"], cwd=str(t), capture_output=True, text=True, timeout=20)
        if r.returncode != 2: why.append("arm 7: a pre.pl with other text was not refused rc 2 (rc %s)" % r.returncode)
        (t / "pre.pl").unlink()
        arms += 1
        r = subprocess.run(me + ["--", "sh", "-c", "kill -TERM $$"], cwd=str(t), capture_output=True, text=True, timeout=20)
        if r.returncode != 128 + 15: why.append("arm 8: a program a signal ended did not read 128 plus the signal (rc %s)" % r.returncode)
    finally:
        shutil.rmtree(t, ignore_errors=True)
    print("XPCE-RUN-PROBE arms=%d red=%d%s" % (arms, len(why), (": " + " ".join(why)) if why else
          " (the config folder emptied at each run; the keep-folder plant moves it; a read of standard input waits on the held pipe; the null-stdin plant moves it to end_of_file; --pre gives the one-thread flag; the no-pre plant moves it; a foreign pre.pl refused; a signal reads 128 plus it)"))
    return 1 if why else 0


def main(argv):
    if argv[:1] == ["--probe"]:
        return probe()
    pre, prog, i = False, None, 0
    while i < len(argv) and argv[i] != "--":
        if argv[i] == "--pre":
            pre = True; i += 1
        elif argv[i] == "--prog" and i + 1 < len(argv):
            prog = argv[i + 1]; i += 2
        else:
            refuse("usage: util_xpce_run.py [--pre --prog FILE] -- CMD ARG... | --probe (unknown word %r)" % argv[i])
    cmd = argv[i + 1:]
    if i >= len(argv) or not cmd:
        refuse("usage: util_xpce_run.py [--pre --prog FILE] -- CMD ARG... | --probe")
    return run(cmd, pre, prog)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
