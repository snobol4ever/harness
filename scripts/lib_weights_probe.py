#!/usr/bin/env python3
# lib_weights_probe.py -- util_run_slot.sh --probe-weights: THE PROOF OF THE WEIGHTED DOOR (step 4 of 7) on a scratch pool, a scratch CORES.conf, a scratch ledger and its scratch index: never the live pool,
# the live CORES.conf or the live COSTS.tsv. One line `WEIGHTS_PROBE arm=ok|red ...`; rc 0 every arm ok, 1 naming the red arms, 2 cannot measure. Every arm reads an order of events (a take is held, or it waits),
# never a wall-clock bound: the pure arms plant the clock, the process arms poll a state with a count of tries.
import os, sys, time, shutil, signal, subprocess, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import lib_weights as W


def probe():
    try:
        d = tempfile.mkdtemp(prefix="weights-probe.")
    except OSError as ex:
        print("WEIGHTS_PROBE REFUSE(2): no scratch directory (%s)" % ex)
        return 2
    run = os.path.join(HERE, "util_run_slot.sh")
    if not os.path.isfile(run) or not os.path.isfile(os.path.join(HERE, "lib_slots.sh")):
        print("WEIGHTS_PROBE REFUSE(2): util_run_slot.sh or lib_slots.sh is not beside this script")
        return 2
    kids, res = [], {}
    pool = os.path.join(d, "pool")
    led, idx, conf = os.path.join(d, "COSTS.tsv"), os.path.join(d, "COSTS.idx"), os.path.join(d, "CORES.conf")
    for name in ("heavy", "light", "memk"):
        open(os.path.join(d, name), "w").write("#!/bin/sh\nexec sleep 300\n"); os.chmod(os.path.join(d, name), 0o755)
    env0 = {k: v for k, v in os.environ.items() if not k.startswith("S4E_") or k in ("S4E_HOME", "S4E_HARNESS")}
    env0.update(S4E_CORES_CONF=conf, S4E_COSTS=led, S4E_COSTS_IDX=idx, S4E_RUN_SLOT_DIR=pool, S4E_CC_SLOT_DIR=os.path.join(d, "cc"), S4E_SLOT_WAITS="/dev/null", S4E_SEAT="probe_a")
    os.environ.update({k: env0[k] for k in ("S4E_CORES_CONF", "S4E_COSTS", "S4E_COSTS_IDX", "S4E_RUN_SLOT_DIR")})

    def ledger(rows):
        with open(led, "w") as f:
            f.write("# COSTS probe\n# at_utc\tseat\tclass\tkey\twall_s\tcpu_s\tcores\trss_mb\ttmp_mb\trc\n")
            for cls, key, cores, rss, wall in rows:
                f.write("2026-11-18T00:00:00Z\tseat\t%s\t%s\t%.3f\t%.3f\t%.3f\t%.3f\t0.000\t0\n" % (cls, key, wall, cores * wall, cores, rss))
        for p in (idx, idx + ".lock"):
            try:
                os.unlink(p)
            except OSError:
                pass

    def setconf(text):
        open(conf, "w").write(text)

    def take(cmd, extra=None, seat="probe_a"):
        e = dict(env0, S4E_SEAT=seat, **(extra or {}))
        p = subprocess.Popen(["bash", run] + cmd, env=e, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        kids.append(p)
        return p

    def until(test, tries=300):
        for _ in range(tries):
            if test():
                return True
            time.sleep(0.1)
        return test()

    def drop(ps):
        for p in ps:
            try:
                os.killpg(p.pid, signal.SIGKILL)
            except OSError:
                pass
            try:
                p.wait(timeout=10)
            except subprocess.TimeoutExpired:
                pass

    st = lambda: W.status(os.path.join(pool, "w"))
    try:
        # arm 1: no weights line: the door of today, places, and no weights directory made
        setconf("cores=2\n")
        ledger([("run", "light", 0.05, 5, 1)])
        a = [take([os.path.join(d, "light")]) for _ in range(2)]
        held = lambda: sum(1 for i in (0, 1) if os.path.exists(os.path.join(pool, "slot%d" % i)) and subprocess.run(["flock", "-n", os.path.join(pool, "slot%d" % i), "true"]).returncode != 0)
        until(lambda: held() == 2)
        third = subprocess.run(["bash", run, "true"], env=dict(env0, S4E_SLOT_WAIT_MAX="1", S4E_SEAT="probe_b"), capture_output=True).returncode
        res["weights_off_is_today"] = "ok" if held() == 2 and third == 2 and not os.path.isdir(os.path.join(pool, "w")) else "red"
        drop(a); shutil.rmtree(pool, ignore_errors=True)
        # arm 2: many light keys enter together, past the place count (cores=2 holds eight takes of 50 millicores)
        def light_fit():
            setconf("cores=2\nweights=on\npatience=60\n")
            ledger([("run", "light", 0.05, 5, 1)])
            ps = [take([os.path.join(d, "light")], seat="probe_%d" % i) for i in range(8)]
            ok = until(lambda: st()["holders"] == 8, 600)
            if not ok and os.environ.get('S4E_WEIGHTS_NO_LOOKUP') != '1':
                print('WEIGHTS_PROBE note: light_fit saw', st(), [x.poll() for x in ps], os.listdir(os.path.join(pool, 'w', 'q')) if os.path.isdir(os.path.join(pool, 'w', 'q')) else None)
            drop(ps); shutil.rmtree(pool, ignore_errors=True)
            return ok
        res["light_fit"] = "ok" if light_fit() else "red"
        # arm 3: a key heavier than the whole budget waits behind a holder and enters when the pool is empty
        setconf("cores=2\nweights=on\npatience=60\n")
        ledger([("run", "light", 0.05, 5, 1), ("run", "heavy", 3.0, 5, 1)])
        l1 = take([os.path.join(d, "light")]); until(lambda: st()["holders"] == 1)
        h1 = take([os.path.join(d, "heavy")]); until(lambda: st()["waiting"] == 1)
        waits = st()["holders"] == 1 and st()["waiting"] == 1
        drop([l1])
        enters = until(lambda: st()["holders"] == 1 and st()["held_mc"] == 3000 and st()["waiting"] == 0, 200)
        res["heavy_alone"] = "ok" if waits and enters else "red"
        drop([h1]); shutil.rmtree(pool, ignore_errors=True)
        # arm 4: a key never run takes its class's 90th percentile, never one place
        ledger([("run", "a", 0.2, 10, 1), ("run", "b", 0.4, 20, 1), ("run", "c", 0.8, 40, 1), ("run", "d", 1.6, 80, 1), ("cc", "gcc", 0.9, 30, 1)])
        w_, m_, s_, src = W.lookup("run", "never-run")
        res["unknown_takes_class_p90"] = "ok" if src == "class" and w_ == 1600 and abs(m_ - 80) < 1e-6 and W.lookup("run", "b")[3] == "key" and W.lookup("zzz", "x")[0] == 1000 else "red"
        # arm 5: no take overtakes a waiter older than the patience; a younger one may be passed (the clock is planted)
        b = W.budget({"cores": "2", "patience": "60", "weights": "on"})
        holders = [{"w": 1500, "m": 0, "seat": "s1", "grader": False}]
        old_heavy = {"w": 1000, "m": 0, "seat": "s2", "grader": False, "t": 1000.0}
        light = {"w": 100, "m": 0, "seat": "s3", "grader": False, "t": 1100.0}
        res["fifo_past_patience"] = "ok" if (W.admission(light, holders, [old_heavy], b, 1050.0) is True and W.admission(light, holders, [old_heavy], b, 1061.0) is False
                                             and W.admission(old_heavy, [], [], b, 1061.0) is True) else "red"
        # arm 6: two takes whose resident MB pass the memory budget do not run together (mem=1 GB, two keys of 800 MB)
        setconf("cores=8\nweights=on\nmem=1\npatience=60\n")
        ledger([("run", "memk", 0.1, 800, 1)])
        m1 = take([os.path.join(d, "memk")]); until(lambda: st()["holders"] == 1)
        m2 = take([os.path.join(d, "memk")], seat="probe_b"); until(lambda: st()["waiting"] == 1)
        apart = st()["holders"] == 1 and st()["waiting"] == 1
        drop([m1])
        together_after = until(lambda: st()["holders"] == 1 and st()["waiting"] == 0, 200)
        res["memory_unit"] = "ok" if apart and together_after else "red"
        drop([m2]); shutil.rmtree(pool, ignore_errors=True)
        # arm 7: the grader's and the seats' shares are parts of the units (cores=4 grader=1 seats=1: the seats take 3000 millicores at most, the grader 3000)
        b = W.budget({"cores": "4", "grader": "1", "seats": "1", "weights": "on"})
        seats_full = [{"w": 3000, "m": 0, "seat": "s1", "grader": False}]
        grader_full = [{"w": 3000, "m": 0, "seat": "g", "grader": True}]
        res["grader_share_kept"] = "ok" if (W.fits({"w": 100, "seat": "s2", "grader": False}, seats_full, b) is False and W.fits({"w": 100, "seat": "g", "grader": True}, seats_full, b) is True
                                           and W.fits({"w": 100, "seat": "g", "grader": True}, grader_full, b) is False and W.fits({"w": 100, "seat": "s2", "grader": False}, grader_full, b) is True) else "red"
        # arm 8: the reading of the weight is cheap: the index is made once and a later take parses only the lines added since
        ledger([("run", "k%d" % (i % 50), 0.1 + (i % 7) / 10.0, 10 + i % 90, 1 + i % 9) for i in range(5000)])
        W.PARSED[0] = 0; W.lookup("run", "k3"); first = W.PARSED[0]
        with open(led, "a") as f:
            f.write("2026-11-18T00:00:01Z\tseat\trun\tk3\t1.000\t0.500\t0.500\t12.000\t0.000\t0\n")
        W.PARSED[0] = 0; W.lookup("run", "k3"); second = W.PARSED[0]
        W.PARSED[0] = 0; W.lookup("run", "k3"); third = W.PARSED[0]
        res["index_reads_new_lines_only"] = "ok" if first == 5000 and second == 1 and third == 0 else "red"
        # arm 9: the harness's own taker (corpus_suite_harness.py _run_slot) follows the same line: it holds one place of the same door while its run lives and gives it back at close
        setconf("cores=4\nweights=on\npatience=60\n")
        ledger([("run", "light", 0.05, 5, 1)])
        code = "import sys, os\nsys.path.insert(0, %r)\nimport corpus_suite_harness as h\ns = h._run_slot(['light'])\nprint('held' if s is not None else 'none', flush=True)\nsys.stdin.readline()\nif s is not None: s.close()\nprint('closed', flush=True)\nsys.stdin.readline()\n" % HERE
        hp = subprocess.Popen([sys.executable, "-I", "-c", code], env=dict(env0, S4E_SEAT="probe_h"), stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, start_new_session=True)
        kids.append(hp)
        said = hp.stdout.readline().strip()
        held_one = said == "held" and st()["holders"] == 1 and st()["held_mc"] == 50
        hp.stdin.write("\n"); hp.stdin.flush()
        said2 = hp.stdout.readline().strip()
        res["harness_taker_follows_the_line"] = "ok" if held_one and said2 == "closed" and until(lambda: st()["holders"] == 0, 100) else "red"
        drop([hp]); shutil.rmtree(pool, ignore_errors=True)
        # arm 10: THE ARM THAT READS RED WHEN THE MECHANISM IS TAKEN OUT: with the weight lookup taken out every key weighs one place and the many-light-keys arm must fail
        os.environ["S4E_WEIGHTS_NO_LOOKUP"] = "1"; env0["S4E_WEIGHTS_NO_LOOKUP"] = "1"
        stubbed = light_fit()
        os.environ.pop("S4E_WEIGHTS_NO_LOOKUP"); env0.pop("S4E_WEIGHTS_NO_LOOKUP")
        res["lookup_taken_out_reads_red"] = "ok" if not stubbed and res["light_fit"] == "ok" else "red"
    except Exception as ex:
        drop(kids); shutil.rmtree(d, ignore_errors=True)
        print("WEIGHTS_PROBE REFUSE(2): could not measure (%s: %s)" % (type(ex).__name__, ex))
        return 2
    finally:
        drop(kids)
        shutil.rmtree(d, ignore_errors=True)
    print("WEIGHTS_PROBE " + " ".join("%s=%s" % (k, v) for k, v in res.items()))
    bad = [k for k, v in res.items() if v != "ok"]
    if bad:
        print("WEIGHTS_PROBE RED: " + " ".join(bad))
    return 1 if bad else 0
