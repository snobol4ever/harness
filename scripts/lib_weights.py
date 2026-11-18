#!/usr/bin/env python3
# lib_weights.py -- THE WEIGHTED DOOR, STEP 4 OF 7: A TAKE DRAWS THE MEASURED WEIGHT OF ITS KEY FROM THE ONE BUDGET, BEHIND ONE LINE OF CORES.conf, weights=on
# (Lon 2026-11-18 08:2x CST, in the president's window: "estimates based on previous runs should be the WEIGHTS that help linear slots work. Do not just assume a 1:1 item of work per
# throttle slot."; skill shared-box section 3, THE DOOR COUNTS WEIGHTS, NEVER PLACES, parts 1, 2, 4 and 5; the drill that the step is cut on: /home/resources/drill/DRILL.tsv).
# INERT UNLESS CORES.conf carries `weights=on`: lib_slots.sh, util_run_slot.sh, util_cc_slot.sh and corpus_suite_harness.py take the door of today (the token files) with no such line, byte for byte.
# THE BUDGET IS IN UNITS: cores=N is N x 1000 millicores, grader=G and seats=S and seat=K are parts of those units (the grader and the seats never take more than N-S and N-G
# millicores in all, a seat never more than K x 1000), and mem=N (GB, as the kernel's bound reads it) is N x 1024 MB; no mem line, no memory unit.
# A TAKE NAMES ITS KEY (class cc or run or graded, and the tool and program the wrappers write into the ledger) and READS ITS WEIGHT FROM THE LEDGER (COSTS.tsv, step 1): the 90th percentile of the
# cores used and of the peak resident MB over the last runs of the key; a key never run takes the 90th percentile of its class, never one place; a class never run takes one place (1000 millicores).
# THE READING IS CHEAP: an index file (COSTS.idx, JSON, beside the ledger) holds the last runs of each key and class and the offset in the ledger it has read to; a take reads the index and the new
# bytes of the ledger since that offset, never the whole ledger.
# ADMISSION: a take enters when the weights held plus its own fit every unit and every share; a take whose own weight passes a limit runs when nothing holds that limit (the pool, its class's share,
# its seat's share); THE WAITERS STAND IN ONE LINE BY ARRIVAL (a ticket each): a take that fits may pass an older waiter that does not, so many light takes do not idle a box behind one heavy one, but
# NO TAKE OVERTAKES A WAITER OLDER THAN THE PATIENCE OF THE DOOR (patience=S of CORES.conf, default 60), so a heavy waiter is next after S seconds and the door has no starvation.
# A HOLD is a file the taker's shell holds flock'd for the life of its command (the kernel frees a killed holder's); a stale hold or ticket is read dead by its lock or its pid and dropped.
#   lib_weights.py weight --class C --key K          prints `cores_mc mem_mb secs source`
#   lib_weights.py admit --class C --key K --seat S [--grader] --holder-fd N [--bound S]    waits for its turn, writes its weight into the hold on fd N; prints `cores_mc mem_mb cap_s`; rc 0, or 2 refused at the bound
#   lib_weights.py status                            what is held and who waits
#   lib_weights.py --probe                           the probe (util_run_slot.sh --probe-weights): rc 0 green, 1 red naming the arm, 2 cannot measure
import os, sys, time, math, fcntl
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

CONF_DEFAULT = "/home/resources/postoffice/CORES.conf"
COSTS_DEFAULT = "/home/resources/progress/COSTS.tsv"
MIN_MC = 50          # a take weighs at least this many millicores: 20 of the lightest fit a core
KEEP_KEY, KEEP_CLASS = 20, 200
UNKNOWN_MC = 1000    # a class never run weighs one place of today


def conf():
    c = {}
    try:
        for l in open(os.environ.get("S4E_CORES_CONF") or CONF_DEFAULT):
            l = l.strip()
            if not l or l.startswith("#") or "=" not in l:
                continue
            k, _, v = l.partition("=")
            c[k.strip()] = v.strip()
    except OSError:
        pass
    return c


def cnum(c, k, d=None):
    try:
        return int(c[k])
    except (KeyError, ValueError):
        return d


def budget(c):
    """the budget in units: total millicores, the seats' and the grader's parts, a seat's share, the memory in MB (None = no memory unit)"""
    n = cnum(c, "cores", 0) * 1000
    g = min(cnum(c, "grader", 0), max(0, n // 1000 - 1)) * 1000
    s = min(cnum(c, "seats", 0), max(0, n // 1000 - g // 1000)) * 1000
    seat = cnum(c, "seat")
    mem = cnum(c, "mem")
    return {"n": n, "seats_max": n - g, "grader_max": n - s, "seat_max": seat * 1000 if seat else None,
            "mem": mem * 1024 if mem and mem >= 1 else None, "patience": cnum(c, "patience", 60), "wait": cnum(c, "wait", 1800)}


def p90(v):
    v = sorted(v)
    return v[max(0, math.ceil(0.9 * len(v)) - 1)] if v else None


REC = ("w", "m", "seat", "grader", "cls", "key", "t", "pid", "st", "t0", "prio")


def rec_str(r):
    """a hold or a ticket as one tab line (no json: its import alone is 32 M instructions a take)"""
    return "\t".join(str(int(r[k]) if k == "grader" else r.get(k, "")) for k in REC)


def rec_load(txt):
    f = (txt.strip().split("\t") + [""] * len(REC))[:len(REC)]
    try:
        return {"w": int(f[0]), "m": float(f[1] or 0), "seat": f[2], "grader": f[3] == "1", "cls": f[4], "key": f[5], "t": float(f[6] or 0), "pid": int(f[7] or 0), "st": f[8], "t0": f[9], "prio": int(f[10] or 1)}
    except ValueError:
        return {}


def costs_path():
    return os.environ.get("S4E_COSTS") or COSTS_DEFAULT


PARSED = [0]   # lines of the ledger parsed by this process (the probe's reading of how cheap a take is)


def load_idx(path):
    idx = {"ofs": 0, "k": {}, "cl": {}}
    with open(path) as f:
        for line in f:
            t = line.rstrip("\n").split("\t")
            if t[0] == "O":
                idx["ofs"] = int(t[1])
            elif t[0] in ("K", "C"):
                e = {q: [float(x) for x in t[3 if t[0] == "K" else 2:][i].split(",") if x] for i, q in enumerate("cms")}
                if t[0] == "K":
                    idx["k"][t[1] + "\t" + t[2]] = e
                else:
                    idx["cl"][t[1]] = e
    return idx


def save_idx(path, idx):
    with open(path, "w") as f:
        f.write("O\t%d\n" % idx["ofs"])
        for name, e in idx["k"].items():
            cls, _, key = name.partition("\t")
            f.write("K\t%s\t%s\t%s\n" % (cls, key, "\t".join(",".join("%.3f" % x for x in e[q]) for q in "cms")))
        for cls, e in idx["cl"].items():
            f.write("C\t%s\t%s\n" % (cls, "\t".join(",".join("%.3f" % x for x in e[q]) for q in "cms")))


def read_index():
    """the index of the ledger, brought up to date from the bytes it has not read; rebuilt whole when the ledger shrank or the index is unreadable"""
    led = costs_path()
    idxp = os.environ.get("S4E_COSTS_IDX") or led.rsplit(".", 1)[0] + ".idx"
    try:
        size = os.path.getsize(led)
    except OSError:
        return {"ofs": 0, "k": {}, "cl": {}}
    try:
        idx = load_idx(idxp)
        if idx.get("ofs", 0) > size:
            raise ValueError("ledger shrank")
    except (OSError, ValueError, IndexError):
        idx = {"ofs": 0, "k": {}, "cl": {}}
    if idx["ofs"] >= size:
        return idx
    lockf = None
    try:
        lockf = open(idxp + ".lock", "a")
        fcntl.flock(lockf, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return idx   # another taker is bringing it up to date: this one reads what stands
    try:
        try:
            idx = load_idx(idxp)
            if idx.get("ofs", 0) > size:
                idx = {"ofs": 0, "k": {}, "cl": {}}
        except (OSError, ValueError, IndexError):
            idx = {"ofs": 0, "k": {}, "cl": {}}
        with open(led, "rb") as f:
            f.seek(idx["ofs"])
            data = f.read()
        end = data.rfind(b"\n") + 1   # only whole lines
        for line in data[:end].decode("utf-8", "replace").split("\n"):
            f_ = line.split("\t")
            if line.startswith("#") or len(f_) < 10:
                continue
            try:
                cls, key, wall, cores, rss = f_[2], f_[3], float(f_[4]), float(f_[6]), float(f_[7])
            except ValueError:
                continue
            PARSED[0] += 1
            for bucket, name, keep in ((idx["k"], cls + "\t" + key, KEEP_KEY), (idx["cl"], cls, KEEP_CLASS)):
                e = bucket.setdefault(name, {"c": [], "m": [], "s": []})
                e["c"].append(cores); e["m"].append(rss); e["s"].append(wall)
                if len(e["c"]) > keep:
                    for q in "cms":
                        del e[q][0]
        idx["ofs"] += end
        tmp = idxp + ".%d.tmp" % os.getpid()
        save_idx(tmp, idx)
        os.replace(tmp, idxp)
    except OSError:
        pass
    finally:
        lockf.close()
    return idx


def lookup(cls, key):
    """(cores_mc, mem_mb, secs, source): the key's own 90th percentiles; else its class's; else one place"""
    if os.environ.get("S4E_WEIGHTS_NO_LOOKUP") == "1":
        return UNKNOWN_MC, 0.0, 0.0, "nolookup"
    idx = read_index()
    e = idx["k"].get(cls + "\t" + key)
    src = "key"
    if not e or len(e["c"]) < 1:
        e = idx["cl"].get(cls) or (idx["cl"].get("run") if cls in ("graded", "wake") else None)
        src = "class"
    if not e or not e["c"]:
        return UNKNOWN_MC, 0.0, 0.0, "default"
    return max(MIN_MC, int(math.ceil(p90(e["c"]) * 1000))), p90(e["m"]), p90(e["s"]), src


def fits(me, holders, b, seat_share=True):
    """does the take fit the budget on top of the holders, in every unit and every share (a take that passes a limit alone fits when nothing holds that limit); seat_share False leaves the seat's own share out"""
    def ok(limit, held, w):
        return limit is None or held + w <= limit or (w > limit and held == 0)
    tot = sum(h["w"] for h in holders)
    cls = sum(h["w"] for h in holders if bool(h.get("grader")) == bool(me.get("grader")))
    seat = sum(h["w"] for h in holders if h.get("seat") == me.get("seat"))
    if not ok(b["n"], tot, me["w"]):
        return False
    if not ok(b["grader_max"] if me.get("grader") else b["seats_max"], cls, me["w"]):
        return False
    if seat_share and not ok(b["seat_max"], seat, me["w"]):
        return False
    if b["mem"] is not None and not ok(b["mem"], sum(h.get("m", 0) for h in holders), me.get("m", 0)):
        return False
    return True


def admission(me, holders, older, b, now):
    """True when the take may enter now: it fits, and no older waiter has waited past the patience (that one goes first)"""
    if not fits(me, holders, b):
        return False
    for w in older:
        if now - w["t"] < (0 if w.get("prio") == 0 else b["patience"]):   # a request has no patience to wait out: it goes first
            continue
        if fits(w, holders, b, seat_share=True) is False and fits(w, holders, b, seat_share=False) is True:
            continue   # held back by its own seat's share alone: it does not stand in the way of the pool
        return False
    return True


def door_dir():
    return os.path.join(os.environ.get("S4E_RUN_SLOT_DIR") or "/tmp/s4e-run-slots", "w")


def alive(pid, st):
    try:
        s = open("/proc/%d/stat" % pid).read()
        return s[s.rindex(")") + 2:].split()[19] == st
    except (OSError, ValueError, IndexError):
        return False


def starttime(pid):
    s = open("/proc/%d/stat" % pid).read()
    return s[s.rindex(")") + 2:].split()[19]


def holders_now(d, skip=None):
    out = []
    hd = os.path.join(d, "h")
    for name in os.listdir(hd) if os.path.isdir(hd) else []:
        p = os.path.join(hd, name)
        if name == skip:
            continue
        try:
            f = open(p, "rb")
        except OSError:
            continue
        try:
            fcntl.flock(f, fcntl.LOCK_SH | fcntl.LOCK_NB)
            try:
                fresh = os.fstat(f.fileno()).st_size == 0 and time.time() - os.fstat(f.fileno()).st_mtime < 30
            except OSError:
                fresh = False
            f.close()   # the lock was free: its holder is gone, unless the file is just made and its shell has not yet taken the lock (an empty file younger than 30 s)
            if not fresh:
                try:
                    os.unlink(p)
                except OSError:
                    pass
            continue
        except OSError:
            pass
        rec = rec_load(f.read().decode())
        f.close()
        if rec.get("w"):
            out.append(rec)
    return out


def waiters_now(d, mine):
    out = []
    qd = os.path.join(d, "q")
    for name in sorted(os.listdir(qd) if os.path.isdir(qd) else []):
        p = os.path.join(qd, name)
        if name == mine:
            break   # the line is by arrival: what stands before this ticket is older
        try:
            rec = rec_load(open(p).read())
        except OSError:
            continue
        if not rec or not alive(rec.get("pid", 0), rec.get("st", "")):
            try:
                os.unlink(p)
            except OSError:
                pass
            continue
        out.append(rec)
    return out


def admit(cls, key, seat, grader, holder_fd, bound=None, now=time.time, sleep=time.sleep, d=None):
    """wait for the turn; rc 0 admitted (the hold on holder_fd now carries the weight), 2 refused at the bound"""
    c = conf(); b = budget(c); d = d or door_dir()
    for sub in ("h", "q"):
        os.makedirs(os.path.join(d, sub), exist_ok=True)
    w, m, secs, src = lookup(cls, key)
    me = {"w": w, "m": m, "seat": seat, "grader": bool(grader), "cls": cls, "key": key, "t": now(), "pid": os.getpid(), "st": starttime(os.getpid()), "prio": 0 if os.environ.get("S4E_DOOR_PRIO") == "0" else 1}
    bound = b["wait"] if bound is None else bound
    lk = open(os.path.join(d, "door.lock"), "a")
    fcntl.flock(lk, fcntl.LOCK_EX)
    try:
        sq = os.path.join(d, "seq")
        try:
            n = int(open(sq).read() or 0)
        except (OSError, ValueError):
            n = 0
        open(sq, "w").write(str(n + 1))
        mine = "%d%012d.%d" % (0 if os.environ.get("S4E_DOOR_PRIO") == "0" else 1, n + 1, os.getpid())   # a request goes first: its ticket sorts before every other, whatever the arrival
        open(os.path.join(d, "q", mine), "w").write(rec_str(me))
    finally:
        fcntl.flock(lk, fcntl.LOCK_UN)
    myhold = os.readlink("/proc/self/fd/%d" % holder_fd) if holder_fd is not None else None
    skip = os.path.basename(myhold) if myhold else None
    t0 = now()
    try:
        while True:
            fcntl.flock(lk, fcntl.LOCK_EX)
            try:
                if admission(me, holders_now(d, skip), waiters_now(d, mine), b, now()):
                    if holder_fd is not None:
                        rec = dict(me, t0=now())
                        os.ftruncate(holder_fd, 0); os.lseek(holder_fd, 0, os.SEEK_SET)
                        os.write(holder_fd, rec_str(rec).encode())
                    return 0, (w, m, secs)
            finally:
                fcntl.flock(lk, fcntl.LOCK_UN)
            if now() - t0 >= bound:
                return 2, (w, m, secs)
            sleep(0.25 + os.urandom(1)[0] / 1024.0)
    finally:
        try:
            os.unlink(os.path.join(d, "q", mine))
        except OSError:
            pass


def status(d=None):
    d = d or door_dir(); hs = holders_now(d)
    qd = os.path.join(d, "q"); q = sorted(os.listdir(qd)) if os.path.isdir(qd) else []
    return {"held_mc": sum(h["w"] for h in hs), "held_mb": sum(h.get("m", 0) for h in hs), "holders": len(hs), "waiting": len(q)}


def cap_of(secs):
    c = conf(); mult = cnum(c, "cap_mult", 8)
    return int(max(30, mult * secs)) if secs and secs > 0 else 0


def main(a):
    if "--probe" in a:
        import lib_weights_probe
        return lib_weights_probe.probe()
    if not a:
        sys.stderr.write(__doc__ or "")
        return 2
    cmd, args = a[0], a[1:]
    def opt(n, dflt=None):
        return args[args.index(n) + 1] if n in args else dflt
    if cmd == "weight":
        w, m, s, src = lookup(opt("--class", "run"), opt("--key", ""))
        print("%d %.3f %.3f %s" % (w, m, s, src))
        return 0
    if cmd == "status":
        print(status())
        return 0
    if cmd == "admit":
        hf = opt("--holder-fd")
        key = opt("--key", "")
        if not key and "--" in args and args[args.index("--") + 1:]:
            from util_cost_run import auto_key
            key = auto_key(args[args.index("--") + 1:])
        rc, (w, m, secs) = admit(opt("--class", "run"), key, opt("--seat", "seat"), "--grader" in args, int(hf) if hf else None, int(opt("--bound")) if opt("--bound") else None)
        if rc == 0:
            print("%d %.3f %d" % (w, m, cap_of(secs)))
        return rc
    sys.stderr.write("usage: lib_weights.py weight|admit|status|--probe\n")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
