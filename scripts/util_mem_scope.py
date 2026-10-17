#!/usr/bin/env python3
"""util_mem_scope.py -- ONE CGROUP SCOPE BOUNDS RESIDENT MEMORY AT THE OUTERMOST RUNNER, AND A CGROUP KILL IS A
REFUSAL, NEVER A RED (row instrument-698-runners-bound-the-clock-and-zero-bound-memory-one-cgroup-scope-bounds-
resident-pages-and-a-cgroup-kill-is-a-refusal-not-a-red, the ceo's ruling on the cfo's measurement; the coo 2026-09-23).

THE ASYMMETRY IT CLOSES: 698 files under ../harness/scripts/ bounded the WALL CLOCK and zero bounded MEMORY, on one box shared by
ten seats. The cfo measured one process at 23,343 MB RSS eighteen seconds in, with 1 GB left on a 30 GB box, and three
of their background jobs were reaped as a direct consequence -- the cost of an unbounded runaway is ANOTHER SEAT'S JOBS.

⛔ THE SHAPE IS RULED: BOUND THE SCOPE, NOT THE CALL. A cgroup scope is inherited by every child, so ONE scope at the
OUTERMOST invocation bounds everything beneath it. Three entry points enter it, each through enter() below and nowhere
else: lib_one_runner.sh (every board runner that sources it from its own top), run_blocking_set.sh (make test, on the
real declaration) and corpus_suite_harness.py run (on a corpus population). A nested runner finds itself inside the
scope already and enters nothing.

⭐ THE MECHANISM, EVERY PROPERTY LOAD-BEARING AND EACH MEASURED ON THIS BOX (systemd 255, cgroup v2):
  systemd-run --user --scope -p MemoryMax=<cap> -p MemorySwapMax=0 -p OOMPolicy=continue
  - MemoryMax bounds RESIDENT pages; the collector's 4096 MB PROT_NONE MAP_NORESERVE reserve is address space and passes
    untouched (a real witness under a 256 MB cap is rc=0). ⛔ ulimit -v / RLIMIT_AS are FORBIDDEN: they count reserved
    address space, so the reserve aborts the process before its first line (the cfo tested it and retracted it).
  - MemorySwapMax=0 is MANDATORY: under MemoryMax alone a 512 MB allocation at a 256 MB cap SUCCEEDED BY SWAPPING
    (rc=0, "allocated 536870912") -- a runaway would degrade every seat without ever tripping the cap.
  - OOMPolicy=continue is MANDATORY and it is the coo's addition, measured 2026-09-23: under the default policy systemd
    STOPS THE WHOLE SCOPE after the kernel kills the runaway, so the supervisor below dies with it (rc=143, SIGTERM) and
    nothing is left to read memory.events or to say what happened -- the kill would reach the caller as a TERM, a
    phantom red. With continue, the kernel kills only its victim and the supervisor survives to classify it.
  - After the scope ends, systemd 255 forgets it (show -p Result reads "success", MemoryPeak "[not set]"), so the peak
    and the kill count are read INSIDE the scope, by supervise(), before it exits.

⛔ A CGROUP KILL IS COULD-NOT-MEASURE, THE rc=2 FAMILY, NEVER A RED (the ceo's clause): the supervisor exits 2 naming
the cap and the peak; corpus_suite_harness._run_raw grades a program the cgroup killed UNPROVEN, not CRASH; the blocking
set refuses an arm whose window saw a kill; util_score_row.py writes no row over a run a kill cut.

⭐ THE CAP IS DERIVED, NOT GUESSED -- see CAP_MB below for the measured high-water each default rests on and its
headroom. S4E_MEM_CAP_MB overrides it for one run and the supervisor's line says so.
"""
import os
import re
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
UNIT_PREFIX = "s4e-mem-"
# ⭐ THE DEFAULT CAPS, DERIVED (the coo 2026-09-23, clean origin bda7691cc, load 10-24 on 16 cores). Each is a measured
# tree-wide high-water -- the cgroup's own memory.peak, the object the cap bounds, never one process's maxrss (CEO-1136) --
# times a stated headroom, rounded up to a whole GB. Both measured numbers are declared here, as the row requires.
#   blocking-set: `make test` (411 arms, six shards) inside one uncapped scope peaked at 6322 MB (anon high-water 5927 MB,
#     page cache 1574 MB), and THAT PEAK WAS A SCHEDULING ACCIDENT: each arm alone in its own scope showed one arm at 4556 MB
#     (progress_configuration_declarations_do_not_regress -- util_progress_flips.py --ratchet holding the whole live progress
#     table, 619 MB / 4.13M rows) and seven at 684-716 MB (the util_suite_banner.py load behind every score-row write), every
#     other arm under 215 MB, and the serial phase's GC and timing arms under 296 MB together. The 4556 MB arm is therefore
#     DECLARED SERIAL in blocking_set_serial_arms.txt, so the worst case is max(4556 alone, six banner arms at once = 4296)
#     = 4.6 GB, and the cap is 2x that: 10 GB.
#   board: no lane's board peak is on record but the Pascal rungs' 81,572 KB (hq_pascal, CEO-1136); the heaviest step a
#     board takes that this seat can measure is its row write's banner load, 716 MB, and the heaviest SCRIP workloads in the
#     tree (the serial GC arms) stay under 296 MB. With less known, the headroom is larger -- 4x 716 MB -- so 3 GB.
# ⛔ BOTH GROW WITH THE PROGRESS TABLE (about 4 percent a day), so at that rate the blocking-set worst case reaches its cap in
#   about three weeks: the cure is those two readers streaming the table, and the caps are re-derived from the peaks every
#   scoped run now prints (the supervisor's line) the day either reader changes or a lane's board reports a heavier peak.
# ⭐ LATER THE SAME DAY THE TWO READERS STREAMED (the coo, CEO-1212): 4556 MB -> 14 MB and 716 MB -> 146 MB, answers identical
#   (test_gate_progress_readers_stream_and_answer_the_same.sh), and the 4556 MB arm left the serial list. Both caps are therefore
#   LOOSE now, never tight: they stand until the next scoped make test prints its peak ([mem_scope] ... peak=), and the re-derivation
#   uses that number, not these.
# ⛔⭐ THE BOARD CAP IS RE-DERIVED FOR SPITBOL'S DEFAULTS (ceo CEO-1261, 2026-09-25): every program may now reach SPITBOL's -d128m
#   heap where the 3 GB above was derived under a 4 MB default cap, and the SWI board -- twelve parallel jobs, each a scrip process
#   beside its swipl oracle -- reached peak=3072 MB and lost a process to the cgroup kill on its first pass at the new default (the
#   row was refused, as it must be). Twelve jobs x (128 MB of heap + stack and image) + twelve oracles is about 4 GB; the cap is 2x that.
CAP_MB = {"board": 8192, "blocking-set": 10240}


def _cgroup_path():
    """This process's cgroup v2 path (the "0::" line), or None."""
    try:
        for line in open("/proc/self/cgroup"):
            if line.startswith("0::"):
                return line[3:].strip()
    except OSError:
        pass
    return None


def scope_dir():
    """The /sys/fs/cgroup directory of the enclosing s4e-mem scope, or None when this process runs in none."""
    p = _cgroup_path()
    if not p:
        return None
    parts = [x for x in p.split("/") if x]
    for i in range(len(parts) - 1, -1, -1):
        if parts[i].startswith(UNIT_PREFIX):
            return Path("/sys/fs/cgroup").joinpath(*parts[: i + 1])
    return None


def inside_scope():
    return scope_dir() is not None


def _read(d, name):
    try:
        return (d / name).read_text().strip()
    except OSError:
        return None


def _mb(v):
    if v is None:
        return "?"
    if v == "max":
        return "unbounded"
    try:
        return "%d MB" % (int(v) // (1024 * 1024))
    except ValueError:
        return v


def oom_kills(d=None):
    """The enclosing scope's oom_kill count (memory.events), or None outside an s4e-mem scope."""
    d = d or scope_dir()
    if d is None:
        return None
    ev = _read(d, "memory.events") or ""
    for line in ev.splitlines():
        k, _, v = line.partition(" ")
        if k == "oom_kill":
            return int(v)
    return None


def describe(d=None):
    """cap, peak and unit of the enclosing scope, for a refusal line."""
    d = d or scope_dir()
    if d is None:
        return "not inside an s4e-mem scope"
    return "cap=%s (memory.max), peak=%s (memory.peak), memory.swap.max=%s, scope %s" % (
        _mb(_read(d, "memory.max")), _mb(_read(d, "memory.peak")), _read(d, "memory.swap.max"), d.name)


def kill_detail(n, d=None):
    """The one sentence every classifier prints for a program or run the cgroup cap killed."""
    return ("COULD NOT MEASURE: the cgroup memory cap killed %d process(es) during this run -- %s. A memory kill is a "
            "refusal, never a red (row instrument-698-runners-...); the peak is the scope's, so name the program before "
            "blaming it." % (n, describe(d)))


def kills_since_start():
    """A refusal sentence when the enclosing scope's oom_kill count rose since this run's start
    (S4E_MEM_OOM_AT_START, stamped by the first runner), else None."""
    d = scope_dir()
    k = oom_kills(d)
    if k is None:
        return None
    try:
        base = int(os.environ.get("S4E_MEM_OOM_AT_START", "0") or 0)
    except ValueError:
        base = 0
    return kill_detail(k - base, d) if k > base else None


def cap_mb(kind):
    """The cap for this kind of run: S4E_MEM_CAP_MB when set to a positive integer, else the derived default."""
    ov = os.environ.get("S4E_MEM_CAP_MB", "").strip()
    if ov:
        if not ov.isdigit() or int(ov) <= 0:
            sys.stderr.write("REFUSE(2) [mem_scope]: S4E_MEM_CAP_MB=%r is not a positive whole number of MB\n" % ov)
            raise SystemExit(2)
        return int(ov)
    return CAP_MB[kind]


def _systemd_run_usable():
    """None when `systemd-run --user --scope` works here, else the reason it does not."""
    if not shutil.which("systemd-run"):
        return "no systemd-run on PATH"
    try:
        r = subprocess.run(["systemd-run", "--user", "--scope", "-q", "--", "true"], capture_output=True,
                           timeout=20)
    except subprocess.TimeoutExpired:
        return "systemd-run --user --scope did not answer in 20 s"
    if r.returncode != 0:
        return "systemd-run --user --scope refused (rc=%d): %s" % (
            r.returncode, r.stderr.decode("utf-8", "replace").strip()[:200])
    return None


def _unit_name(argv):
    who = os.environ.get("S4E_SEAT", "").strip() or HERE.parent.parent.name
    prog = next((Path(a).name for a in argv[1:] if os.path.isfile(a)), Path(argv[0]).name if argv else "run")[:48]
    raw = "%s%s-%s-%d" % (UNIT_PREFIX, who, prog, os.getpid())
    return re.sub(r"[^A-Za-z0-9_.-]", "_", raw)[:200]


def enter(kind, argv):
    """Put this run inside ONE memory-bounded scope. Returns normally when no new scope is wanted -- already inside
    one, or S4E_MEM_SCOPE=unbounded, or systemd-run unusable (then it says so loudly, once); otherwise it EXECs
    systemd-run, which re-runs argv under supervise() inside the new scope, and never returns."""
    if kind not in CAP_MB:
        raise ValueError(kind)
    if inside_scope() or os.environ.get("S4E_MEM_SCOPE", "") == "unbounded":
        return
    cap = cap_mb(kind)
    why = _systemd_run_usable()
    if why:
        sys.stderr.write("⚠ [mem_scope] MEMORY UNBOUNDED: %s -- this run carries NO memory ceiling (the %s cap "
                         "would be %d MB). It measures as before; it no longer protects the other seats.\n"
                         % (why, kind, cap))
        os.environ["S4E_MEM_SCOPE"] = "unbounded"
        return
    unit = _unit_name(argv)
    sys.stdout.flush(); sys.stderr.flush()
    os.execvp("systemd-run", ["systemd-run", "--user", "--scope", "-q", "--unit=" + unit,
                              "-p", "MemoryMax=%dM" % cap, "-p", "MemorySwapMax=0", "-p", "OOMPolicy=continue", "--",
                              sys.executable, str(Path(__file__).resolve()), "supervise", "--kind", kind, "--"]
                             + list(argv))


def supervise(kind, argv):
    """INSIDE the scope: run argv as a child, then read the scope's peak and kill count and classify. Exit: the
    child's own rc (128+N for a signal), or 2 when the cgroup killed anything under this run."""
    d = scope_dir()
    os.environ["S4E_MEM_SCOPE"] = d.name if d is not None else "unbounded"
    t0 = time.monotonic()
    signal.signal(signal.SIGINT, lambda s, f: None)   # the terminal's ^C reaches the child's group itself
    try:
        child = subprocess.Popen(argv)
    except OSError as e:
        sys.stderr.write("REFUSE(2) [mem_scope]: could not start %r inside the scope: %s\n" % (argv[:2], e))
        return 2

    def forward(sig, _frame):
        try:
            child.send_signal(sig)
        except OSError:
            pass
    for s in (signal.SIGTERM, signal.SIGHUP, signal.SIGQUIT):
        signal.signal(s, forward)
    rc = child.wait()
    el = time.monotonic() - t0
    kills = oom_kills(d) or 0
    ov = os.environ.get("S4E_MEM_CAP_MB", "").strip()
    note = (" (S4E_MEM_CAP_MB=%s; the %s default is %d MB)" % (ov, kind, CAP_MB[kind])) if ov else ""
    if d is None:
        sys.stderr.write("[mem_scope] elapsed=%.0fs memory UNMEASURED: not inside an s4e-mem scope\n" % el)
    else:
        sys.stderr.write("[mem_scope] elapsed=%.0fs peak=%s of cap=%s%s (memory.swap.max=%s, OOMPolicy=continue) "
                         "oom_kill=%d  %s\n" % (el, _mb(_read(d, "memory.peak")), _mb(_read(d, "memory.max")), note,
                                                _read(d, "memory.swap.max"), kills, d.name))
    if kills:
        sys.stderr.write("⛔ REFUSE(2) [mem_scope]: %s\n" % kill_detail(kills, d))
        return 2
    return rc if rc >= 0 else 128 - rc


def main(argv):
    if len(argv) >= 2 and argv[1] in ("enter", "supervise"):
        cmd, rest = argv[1], argv[2:]
        kind = "board"
        if len(rest) >= 2 and rest[0] == "--kind":
            kind, rest = rest[1], rest[2:]
        if rest[:1] == ["--"]:
            rest = rest[1:]
        if kind not in CAP_MB or not rest:
            sys.stderr.write("usage: util_mem_scope.py %s --kind {%s} -- argv...\n" % (cmd, ",".join(CAP_MB)))
            return 2
        if cmd == "supervise":
            return supervise(kind, rest)
        enter(kind, rest)          # returns only when no new scope is wanted: then run argv here, unchanged
        sys.stdout.flush(); sys.stderr.flush()
        os.execvp(rest[0], rest)
    if len(argv) == 2 and argv[1] == "oom-kills":
        k = oom_kills()
        if k is None:
            return 1
        print(k)
        return 0
    if len(argv) == 2 and argv[1] == "dir":
        d = scope_dir()
        if d is None:
            return 1
        print(d)
        return 0
    if len(argv) == 3 and argv[1] == "kill-detail" and argv[2].isdigit():
        print(kill_detail(int(argv[2])))
        return 0
    if len(argv) == 2 and argv[1] == "status":
        d = scope_dir()
        print(describe(d) + ("; oom_kill=%s" % oom_kills(d) if d else ""))
        return 0 if d else 1
    sys.stderr.write("usage: util_mem_scope.py enter|supervise --kind {%s} -- argv... | oom-kills | dir | status"
                     " | kill-detail N\n" % ",".join(CAP_MB))
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
