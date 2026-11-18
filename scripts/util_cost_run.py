#!/usr/bin/env python3
# util_cost_run.py --class CLASS --key KEY -- COMMAND ARG...   |   util_cost_run.py --probe
# THE COSTS LEDGER (the weighted door, step 1 of 7; the president 2026-11-18, Lon 08:2x CST: "estimates based on previous runs should be the
# WEIGHTS that help linear slots work"; skill shared-box section 3, THE DOOR COUNTS WEIGHTS, NEVER PLACES). It runs COMMAND as a child with stdin,
# stdout and stderr inherited, waits with os.wait4 and appends ONE line to the ledger from what the kernel counted for the child:
#   at_utc seat class key wall_s cpu_s cores rss_mb tmp_mb rc   (tab separated, three decimals; tmp_mb is 0 in this step)
# The ledger is $S4E_COSTS, else /home/resources/progress/COSTS.tsv; S4E_COSTS=off writes nothing. A failure to write never changes the rc and prints
# nothing. The line is ONE os.write on an O_APPEND descriptor, so two writers never mix; a new ledger is made whole with its header by a link, so no
# writer meets a file without it. The exit code is the child's (128 plus the signal number when it died of one); SIGTERM and SIGINT go on to the child.
# Every descriptor the caller holds stays open in the child (a run slot's flock on fd 8 or 9 lives as long as the command and this parent do).
# KEY auto: the base name of COMMAND, a colon, the base name of the first argument that names an existing file (scrip:hello.sno, gcc:rt.c); no such argument, the command's name alone.
import os, sys, time
import _signal as signal  # the C module: the enum-laden signal module alone costs 26 M instructions at start

LEDGER_DEFAULT = "/home/resources/progress/COSTS.tsv"
HEADER = "# COSTS: wait4 counts the child and the descendants it waited for, never a grandchild it left behind: a daemonised child is undercounted\n# at_utc\tseat\tclass\tkey\twall_s\tcpu_s\tcores\trss_mb\ttmp_mb\trc\n"


def ledger_path():
    p = os.environ.get("S4E_COSTS", "")
    if p == "off":
        return None
    return p or LEDGER_DEFAULT


def auto_key(cmd):
    k = os.path.basename(cmd[0])
    for a in cmd[1:]:
        try:
            if a and os.path.isfile(a):
                return k + ":" + os.path.basename(a)
        except OSError:
            pass
    return k


def append_line(path, line):
    try:
        data = line.encode("utf-8", "replace")
        try:
            fd = os.open(path, os.O_WRONLY | os.O_APPEND)
        except FileNotFoundError:
            d = os.path.dirname(path) or "."
            tmp = os.path.join(d, ".%s.%d.new" % (os.path.basename(path), os.getpid()))
            t = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o664)
            try:
                os.write(t, HEADER.encode())
            finally:
                os.close(t)
            try:
                os.link(tmp, path)
            except FileExistsError:
                pass
            finally:
                os.unlink(tmp)
            fd = os.open(path, os.O_WRONLY | os.O_APPEND)
        try:
            os.write(fd, data)
        finally:
            os.close(fd)
    except Exception:
        pass


def run(cls, key, cmd):
    child = [0]
    SIGS = (signal.SIGINT, signal.SIGTERM, signal.SIGHUP)

    def fwd(sig, frm):
        if child[0]:
            try:
                os.kill(child[0], sig)
            except OSError:
                pass

    # A signal the caller ignored stays ignored, in this parent and in the command (an ignored signal survives exec); every other of the three is
    # caught here BEFORE the fork and passed on, so none lands between the fork and the handler. SIGPIPE and SIGXFSZ, which CPython sets to ignore at
    # its own start, are put back to default in the child, so the command meets the signals it would meet run bare.
    ign = [sg for sg in SIGS if signal.getsignal(sg) == signal.SIG_IGN]
    for sg in SIGS:
        if sg not in ign:
            signal.signal(sg, fwd)
    t0 = time.monotonic()
    pid = os.fork()
    if pid == 0:
        for sg in SIGS:
            if sg not in ign:
                signal.signal(sg, signal.SIG_DFL)
        signal.signal(signal.SIGPIPE, signal.SIG_DFL)
        signal.signal(signal.SIGXFSZ, signal.SIG_DFL)
        try:
            os.execvp(cmd[0], cmd)
        except FileNotFoundError:
            os.write(2, ("util_cost_run.py: %s: not found\n" % cmd[0]).encode())
            os._exit(127)
        except OSError as e:
            os.write(2, ("util_cost_run.py: %s: %s\n" % (cmd[0], e.strerror)).encode())
            os._exit(126)
    child[0] = pid
    while True:
        try:
            _, status, ru = os.wait4(pid, 0)
            break
        except InterruptedError:
            continue
    wall = time.monotonic() - t0
    dsig = os.WTERMSIG(status) if os.WIFSIGNALED(status) else 0
    rc = 128 + dsig if dsig else os.WEXITSTATUS(status)
    path = ledger_path()
    if path:
        cpu = ru.ru_utime + ru.ru_stime
        cores = cpu / wall if wall >= 0.001 else 0.0
        if not key or key == "auto":
            key = auto_key(cmd)
        key = key.replace("\t", " ").replace("\n", " ")
        seat = os.environ.get("S4E_SEAT") or "seat"
        at = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        line = "%s\t%s\t%s\t%s\t%.3f\t%.3f\t%.3f\t%.3f\t%.3f\t%d\n" % (at, seat, cls, key, wall, cpu, cores, ru.ru_maxrss / 1024.0, 0.0, rc)
        append_line(path, line)
    if dsig:
        # a child that died of a signal kills this process with the same one, as GNU timeout does: a caller reads returncode -N, not 128+N (the ledger column keeps 128+N)
        try:
            signal.signal(dsig, signal.SIG_DFL)
            os.kill(os.getpid(), dsig)
            time.sleep(1)
        except Exception:
            pass
    return rc


def probe():
    import tempfile, shutil, subprocess
    here = os.path.abspath(__file__)
    d = tempfile.mkdtemp(prefix="costs-probe-")
    res = {}

    def go(led, cmd, cls="probe", key="k", env_extra=None):
        env = dict(os.environ)
        env["S4E_COSTS"] = led
        if env_extra:
            env.update(env_extra)
        return subprocess.run([sys.executable, here, "--class", cls, "--key", key, "--"] + cmd, env=env).returncode

    def lines(led):
        try:
            return [l.rstrip("\n").split("\t") for l in open(led) if not l.startswith("#") and l.strip()]
        except OSError:
            return []

    try:
        led = os.path.join(d, "a.tsv")
        go(led, [sys.executable, "-c", "import time\nwhile time.process_time()<1.0: pass"])
        r = lines(led)
        res["cpu"] = "ok" if len(r) == 1 and len(r[0]) == 10 and 0.8 <= float(r[0][5]) <= 1.6 else "red"
        led = os.path.join(d, "b.tsv")
        go(led, [sys.executable, "-c", "b = bytearray(b'x') * (200 * 1024 * 1024); import time; time.sleep(0.2)"])
        r = lines(led)
        res["rss"] = "ok" if len(r) == 1 and 180 <= float(r[0][7]) <= 300 else "red"
        led = os.path.join(d, "c.tsv")
        rc = go(led, [sys.executable, "-c", "import sys; sys.exit(3)"])
        r = lines(led)
        res["rc"] = "ok" if rc == 3 and len(r) == 1 and r[0][9] == "3" else "red"
        led = os.path.join(d, "d.tsv")
        rc = go(led, [sys.executable, "-c", "import os, signal; os.kill(os.getpid(), signal.SIGTERM)"])
        r = lines(led)
        res["sig"] = "ok" if rc == -15 and len(r) == 1 and r[0][9] == "143" else "red"
        led = os.path.join(d, "e.tsv")
        env = dict(os.environ)
        env["S4E_COSTS"] = led
        ps = [subprocess.Popen([sys.executable, here, "--class", "probe", "--key", "n%d" % i, "--", sys.executable, "-c", "import time; time.sleep(0.3)"], env=env) for i in range(20)]
        for p in ps:
            p.wait()
        r = lines(led)
        whole = len(r) == 20 and all(len(x) == 10 for x in r)
        try:
            first = open(led).readline().startswith("#")
        except OSError:
            first = False
        res["many"] = "ok" if whole and first else "red"
        led = os.path.join(d, "f.tsv")
        go(led, ["/bin/true"])
        n_on = len(lines(led))
        led2 = os.path.join(d, "g.tsv")
        go(led2, ["/bin/true"], env_extra={"S4E_COSTS": "off"})
        n_off = len(lines(led2)) + (1 if os.path.exists(os.path.join(d, "off")) else 0)
        res["off"] = "ok" if n_on == 1 and n_off == 0 and n_on != n_off else "red"
        led = os.path.join(d, "h.tsv")
        go(led, ["sleep", "1"])
        r = lines(led)
        res["idle"] = "ok" if len(r) == 1 and float(r[0][6]) < 0.1 else "red"
        # arm h: the command meets the signals it would meet bare: CPython's own ignored SIGPIPE (bit 13) and SIGXFSZ (bit 25) are default in the child
        led = os.path.join(d, "i.tsv")
        env = dict(os.environ)
        env["S4E_COSTS"] = led
        out = subprocess.run([sys.executable, here, "--class", "probe", "--key", "k", "--", "sh", "-c", "grep '^SigIgn' /proc/self/status"], env=env, capture_output=True, text=True).stdout
        try:
            m = int(out.split()[1], 16)
        except (IndexError, ValueError):
            m = -1
        res["ign"] = "ok" if m >= 0 and not (m & 0x1001000) else "red"
        # arm i: a SIGINT the caller ignored stays ignored in the command (bit 2 set)
        out = subprocess.run([sys.executable, here, "--class", "probe", "--key", "k", "--", "sh", "-c", "grep '^SigIgn' /proc/self/status"], env=env, capture_output=True, text=True,
                             preexec_fn=lambda: __import__("signal").signal(__import__("signal").SIGINT, __import__("signal").SIG_IGN)).stdout
        try:
            m = int(out.split()[1], 16)
        except (IndexError, ValueError):
            m = -1
        res["ignint"] = "ok" if m >= 0 and (m & 0x2) else "red"
        # arm j: SIGHUP to the wrapper reaches the command (the command's own exit says so)
        p = subprocess.Popen([sys.executable, here, "--class", "probe", "--key", "k", "--", "sh", "-c", "trap 'exit 7' HUP; sleep 0.1 & while :; do wait; done"], env=env)
        time.sleep(1.0)
        p.send_signal(1)
        try:
            res["hup"] = "ok" if p.wait(timeout=20) == 7 else "red"
        except subprocess.TimeoutExpired:
            p.kill(); p.wait(); res["hup"] = "red"
    finally:
        shutil.rmtree(d, ignore_errors=True)
    print("COST_PROBE " + " ".join("%s=%s" % (k, v) for k, v in res.items()) + " lines_on=%s lines_off=%s" % (locals().get("n_on", "?"), locals().get("n_off", "?")))
    return 0 if res and all(v == "ok" for v in res.values()) and len(res) == 10 else 1


def main(argv):
    if argv and argv[0] == "--probe":
        return probe()
    cls, key = "run", "auto"
    i = 0
    while i < len(argv) and argv[i] != "--":
        if argv[i] == "--class" and i + 1 < len(argv):
            cls = argv[i + 1]; i += 2
        elif argv[i] == "--key" and i + 1 < len(argv):
            key = argv[i + 1]; i += 2
        else:
            sys.stderr.write("usage: util_cost_run.py --class CLASS --key KEY -- COMMAND ARG... | --probe\n")
            return 2
    cmd = argv[i + 1:]
    if not cmd:
        sys.stderr.write("usage: util_cost_run.py --class CLASS --key KEY -- COMMAND ARG... | --probe\n")
        return 2
    return run(cls, key, cmd)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
