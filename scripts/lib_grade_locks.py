#!/usr/bin/env python3
"""lib_grade_locks.py -- the grader root moves only when no board is mid-launch (test-cycle, the cio's design answer (2)(i), 2026-11-08).

Two flock files in LOCK_DIR (S4E_GRADER_LOCK_DIR, default /tmp/s4e/grader):
  root.lock  held SHARED by every launch from the tree check to its record step, EXCLUSIVE by any sync.
  root.gate  the writer's turn: a launch takes it shared only while it takes root.lock and lets go at once; a worker that must sync holds it
             exclusive while it waits for root.lock, so no new board starts and the mid-board ones finish.
The controller never waits: try_sync takes both non-blocking and returns 75 on either busy (no sync, no kick that tick).

  python3 -I lib_grade_locks.py --probe-root     the proof line ROOT_LOCK_PROBE ... ok=1
"""
import os, sys, time, fcntl, subprocess, tempfile, select, shutil

LOCK_DIR = os.environ.get("S4E_GRADER_LOCK_DIR") or "/tmp/s4e/grader"
BUSY = 75


def _open(d, name):
    os.makedirs(d, exist_ok=True)
    return os.open(os.path.join(d, name), os.O_RDWR | os.O_CREAT, 0o644)


def _hold(fd, mode, wait, touch):
    last = time.time()
    while True:
        try:
            fcntl.flock(fd, mode | fcntl.LOCK_NB)
            return True
        except BlockingIOError:
            if not wait:
                return False
            time.sleep(1)
            if touch is not None and time.time() - last >= 60:
                try:
                    touch()
                except Exception:
                    pass
                last = time.time()


def _close(fd, unlock=True):
    if fd is None:
        return
    try:
        if unlock:
            fcntl.flock(fd, fcntl.LOCK_UN)
    except OSError:
        pass
    try:
        os.close(fd)
    except OSError:
        pass


def board_hold(need_sync, resync, touch=None, lock_dir=None):
    """take the gate then root.lock (both EX when need_sync, else both SH, waiting); a syncer runs resync() under the exclusive lock, then
    downgrades root.lock to shared (the gate is still held, so no other sync enters); the gate is let go at once. Returns (lock fd, resync's why)."""
    d = lock_dir or LOCK_DIR
    g = _open(d, "root.gate")
    t = _open(d, "root.lock")
    mode = fcntl.LOCK_EX if need_sync else fcntl.LOCK_SH
    why = None
    try:
        _hold(g, mode, True, touch)
        _hold(t, mode, True, touch)
        if need_sync:
            why = resync()
            fcntl.flock(t, fcntl.LOCK_SH)
    except BaseException:
        _close(t)
        raise
    finally:
        _close(g)
    return (t, why)


def leave(fd):
    _close(fd)


def try_sync(run, lock_dir=None):
    """the controller's sync: both locks non-blocking exclusive; either busy returns 75 and run() is not called"""
    d = lock_dir or LOCK_DIR
    g = _open(d, "root.gate")
    t = _open(d, "root.lock")
    if not _hold(g, fcntl.LOCK_EX, False, None):
        _close(g, False)
        _close(t, False)
        return BUSY
    if not _hold(t, fcntl.LOCK_EX, False, None):
        _close(g)
        _close(t, False)
        return BUSY
    try:
        return run()
    finally:
        _close(t)
        _close(g)


def _say(tag):
    print("%s %.3f" % (tag, time.time()), flush=True)


def _probe_root():
    seat = os.environ.get("S4E_SEAT") or "probe"
    base = os.path.join("/tmp/s4e", seat)
    os.makedirs(base, exist_ok=True)
    d = tempfile.mkdtemp(dir=base, prefix="rootlock.")
    me = os.path.abspath(__file__)
    ok = 0
    out = "busy_tick=? waiter_after_board=0 board_after_sync=0 quiet_tick=?"
    procs = []
    try:
        A = subprocess.Popen([sys.executable, "-I", me, "--hold-board", d, "3"], stdout=subprocess.PIPE, text=True)
        procs.append(A)
        first = ""
        if select.select([A.stdout], [], [], 10)[0]:
            first = A.stdout.readline()
        busy = try_sync(lambda: 0, d) if first.startswith("HELD") else 0
        B = subprocess.Popen([sys.executable, "-I", me, "--hold-sync", d], stdout=subprocess.PIPE, text=True)
        procs.append(B)
        time.sleep(0.5)
        C = subprocess.Popen([sys.executable, "-I", me, "--hold-board", d, "0"], stdout=subprocess.PIPE, text=True)
        procs.append(C)
        a_rest = A.communicate(timeout=30)[0]
        b_out = B.communicate(timeout=30)[0]
        c_out = C.communicate(timeout=30)[0]

        def stamp(text, tag):
            for ln in text.splitlines():
                w = ln.split()
                if len(w) == 2 and w[0] == tag:
                    return float(w[1])
            return None
        a_left, b_sync = stamp(a_rest, "LEFT"), stamp(b_out, "SYNC")
        c_held = stamp(c_out, "HELD")
        wab = int(a_left is not None and b_sync is not None and b_sync >= a_left)
        bas = int(b_sync is not None and c_held is not None and c_held >= b_sync)
        quiet = try_sync(lambda: 0, d)
        out = "busy_tick=%s waiter_after_board=%d board_after_sync=%d quiet_tick=%s" % (
            "refused" if busy == BUSY else "ran", wab, bas, "synced" if quiet == 0 else "refused")
        ok = int(out == "busy_tick=refused waiter_after_board=1 board_after_sync=1 quiet_tick=synced")
    except Exception as e:
        out += " err=%s" % type(e).__name__
    finally:
        for p in procs:
            if p.poll() is None:
                p.kill()
                p.wait()
        shutil.rmtree(d, ignore_errors=True)
    print("ROOT_LOCK_PROBE %s ok=%d" % (out, ok))
    return 0 if ok else 1


def main(argv):
    if argv[:1] == ["--probe-root"] and len(argv) == 1:
        return _probe_root()
    if argv[:1] == ["--hold-board"] and len(argv) == 3:
        t, _ = board_hold(False, None, lock_dir=argv[1])
        _say("HELD")
        time.sleep(float(argv[2]))
        _say("LEFT")
        leave(t)
        return 0
    if argv[:1] == ["--hold-sync"] and len(argv) == 2:
        def resync():
            _say("SYNC")
            return None
        t, _ = board_hold(True, resync, lock_dir=argv[1])
        leave(t)
        return 0
    sys.stderr.write("usage: lib_grade_locks.py --probe-root | --hold-board DIR SECS | --hold-sync DIR\n")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
