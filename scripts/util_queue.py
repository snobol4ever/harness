#!/usr/bin/env python3
# util_queue.py -- THE ONE QUEUE CLIENT of the fleet (DESIGN-PLAN fleet-queue step 1, the cio 2026-11-05; skill fleet-bus section 8). Every bus verb and
# the tick reach beanstalkd through this module and never through a private socket: it wraps greenstalk (pip, the proven client) and names the tubes.
#   python3 util_queue.py status                     one line: QUEUE daemon=beanstalkd version=V binlog=0|1 listen=HOST:PORT client=greenstalk tubes=N
#   python3 util_queue.py tubes                      one line per tube: name ready reserved delayed buried total
#   python3 util_queue.py put TUBE TOPIC [--pri N] [--ttr S] [--delay S]      prints the job id
#   python3 util_queue.py peek TUBE                  the next ready job of TUBE: id pri ttr age topic (or nothing, rc 1)
#   python3 util_queue.py stats-job ID               id tube state pri age ttr time-left reserves timeouts releases buries kicks
#   python3 util_queue.py delete|bury|kick-job|touch ID    the verb on one job (bury and touch need the job reserved by this connection: the bus does that inside one call)
#   python3 util_queue.py kick TUBE [N]              kicks N buried jobs of TUBE (default 1)
#   python3 util_queue.py reserve TUBE[,TUBE...] [--timeout S]     reserves one job over the watched tubes, prints id tube pri topic; rc 1 on nothing ready
#   python3 util_queue.py put-buried TUBE TOPIC [--pri N] [--ttr S]     fleet-queue step 6: put a job and bury it at once (a parked row with no job); prints the id
#   python3 util_queue.py bury-ready ID                                 fleet-queue step 6: bury a READY job (rc 0 buried or already buried, rc 1 no such job, rc 4 reserved by another connection)
# rc 0 ok, 1 nothing/red, 2 could not reach the daemon or no client (the refusal names the line that cures it). No tube is ever created by name here but
# by a put; a reserve by this process that exits releases the job back at once (beanstalkd releases a reserved job when its connection closes), so the
# bus keeps the connection open across its own write and then lets the TTR be the lease (step 5): see s4e_msg.sh for the reserve-then-claim shape.
import os, sys, socket, time
HOST = os.environ.get("S4E_QUEUE_HOST", "127.0.0.1"); PORT = int(os.environ.get("S4E_QUEUE_PORT", "11300"))
LIVE_TASKS = "/home/resources/postoffice/tasks"   # the live batons: reserve-hold on the live port may name only these (the cio 2026-11-07)
TIERS = ("fable", "opus", "sonnet", "haiku")
def refuse(msg, rc=2):
    print("REFUSE(%d) [util_queue]: %s" % (rc, msg)); sys.exit(rc)
class _Stdlib:
    # THE TRANSPORT FALLBACK, the same twelve commands of the beanstalk protocol greenstalk speaks, used only while greenstalk is absent for this
    # user (the status line then says client=stdlib and step 1 stays RED): it exists so steps 3 to 8 can be built and proven the same evening, never
    # as a second client once greenstalk is installed. Errors mirror greenstalk's names so the bus handles both alike.
    class NotFoundError(Exception): pass
    class TimedOutError(Exception): pass
    class Job:
        def __init__(self, i, b): self.id, self.body = i, b
    class Client:
        def __init__(self, addr, encoding="utf-8"):
            self.s = socket.create_connection(addr, timeout=None); self.f = self.s.makefile("rb"); self.enc = encoding
        def _cmd(self, line, body=None):
            data = line.encode(self.enc) + b"\r\n"
            if body is not None: data = line.encode(self.enc) + (" %d\r\n" % len(body.encode(self.enc))).encode() + body.encode(self.enc) + b"\r\n"
            self.s.sendall(data); r = self.f.readline().rstrip(b"\r\n").decode().split()
            if not r: raise OSError("connection closed")
            if r[0] in ("NOT_FOUND",): raise _Stdlib.NotFoundError(line)
            if r[0] in ("TIMED_OUT", "DEADLINE_SOON"): raise _Stdlib.TimedOutError(line)
            if r[0] in ("NOT_IGNORED", "BAD_FORMAT", "UNKNOWN_COMMAND", "EXPECTED_CRLF", "JOB_TOO_BIG", "DRAINING", "OUT_OF_MEMORY", "INTERNAL_ERROR"): raise OSError(" ".join(r))
            return r
        def _body(self, r):
            n = int(r[-1]); b = self.f.read(n + 2)[:n]; return b.decode(self.enc)
        def _yaml(self, r):
            out = {}
            for l in self._body(r).splitlines():
                if l.startswith("- "): out.setdefault("_list", []).append(l[2:])
                elif ": " in l:
                    k, v = l.split(": ", 1); out[k] = int(v) if v.lstrip("-").isdigit() else v.strip('"')
            return out
        def use(self, t): self._cmd("use " + t)
        def watch(self, t): self._cmd("watch " + t)
        def ignore(self, t): self._cmd("ignore " + t)
        def put(self, body, priority=1000, delay=0, ttr=60): return int(self._cmd("put %d %d %d" % (priority, delay, ttr), body)[1])
        def reserve(self, timeout=None):
            r = self._cmd("reserve" if timeout is None else "reserve-with-timeout %d" % timeout); return _Stdlib.Job(int(r[1]), self._body(r))
        def peek_ready(self):
            r = self._cmd("peek-ready"); return _Stdlib.Job(int(r[1]), self._body(r))
        def delete(self, i): self._cmd("delete %d" % i)
        def release(self, i, priority=1000, delay=0): self._cmd("release %d %d %d" % (getattr(i, "id", i), priority, delay))
        def bury(self, i, priority=1000): self._cmd("bury %d %d" % (getattr(i, "id", i), priority))
        def touch(self, i): self._cmd("touch %d" % getattr(i, "id", i))
        def reserve_job(self, i):
            r = self._cmd("reserve-job %d" % i); return _Stdlib.Job(int(r[1]), self._body(r))
        def kick(self, n=1): return int(self._cmd("kick %d" % n)[1])
        def kick_job(self, i): self._cmd("kick-job %d" % i)
        def stats_job(self, i): return self._yaml(self._cmd("stats-job %d" % i))
        def stats_tube(self, t): return self._yaml(self._cmd("stats-tube " + t))
        def stats(self): return self._yaml(self._cmd("stats"))
        def tubes(self): return self._yaml(self._cmd("list-tubes")).get("_list", [])
        def close(self):
            try: self.s.sendall(b"quit\r\n")
            except OSError: pass
            self.s.close()
def client():
    try:
        import greenstalk as gs
    except ImportError:
        gs = _Stdlib
    try:
        return gs, gs.Client((HOST, PORT), encoding="utf-8")
    except (OSError, ConnectionError) as e:
        refuse("beanstalkd unreachable at %s:%d (%s): sudo systemctl enable --now beanstalkd" % (HOST, PORT, e))
def raw_stats():
    try:
        s = socket.create_connection((HOST, PORT), timeout=3); s.sendall(b"stats\r\n"); buf = b""
        while not buf.endswith(b"\r\n") or b"\r\n\r\n" not in buf and len(buf) < 65536:
            chunk = s.recv(65536)
            if not chunk: break
            buf += chunk
            if buf.startswith(b"OK ") and len(buf) >= int(buf.split(b"\r\n", 1)[0].split()[1]) + len(buf.split(b"\r\n", 1)[0]) + 4: break
        s.close()
    except OSError as e:
        refuse("beanstalkd unreachable at %s:%d (%s): sudo systemctl enable --now beanstalkd" % (HOST, PORT, e))
    body = buf.split(b"\r\n", 1)[1].decode()
    return dict(l.split(": ", 1) for l in body.splitlines() if ": " in l)
def main(a):
    if not a: refuse("usage: util_queue.py status|tubes|put|peek|stats-job|delete|bury|kick-job|touch|kick|reserve ...")
    v = a[0]
    if v == "status":
        st = raw_stats(); binlog = 1 if int(st.get("binlog-current-index", "0")) > 0 else 0
        try:
            import greenstalk; cl = "greenstalk"
        except ImportError:
            cl = "stdlib"
        print("QUEUE daemon=beanstalkd version=%s binlog=%d listen=%s:%d client=%s tubes=%s pid=%s uptime_s=%s" % (st.get("version", "?").strip('"'), binlog, HOST, PORT, cl, st.get("current-tubes", "?"), st.get("pid", "?"), st.get("uptime", "?")))
        if cl != "greenstalk": print("  (client=stdlib, the transport fallback: pip3 install --user greenstalk)")
        if not binlog: print("  (binlog=0: set BEANSTALKD_EXTRA=\"-b /var/lib/beanstalkd -f 1000\" in /etc/default/beanstalkd and sudo systemctl restart beanstalkd)")
        sys.exit(0 if cl == "greenstalk" and binlog else 1)
    if v == "reserve-hold" and "--baton-dir" in a:   # refused BEFORE any connection: a scratch baton dir on the live port is the deleting shape
        dry = "--dry" in a; a = [x for x in a if x != "--dry"]
        bd = a[a.index("--baton-dir") + 1] if a.index("--baton-dir") + 1 < len(a) else refuse("reserve-hold: --baton-dir takes a directory")
        if PORT == 11300 and os.path.realpath(bd) != os.path.realpath(LIVE_TASKS):
            refuse("REFUSE(2): a scratch --baton-dir on the live port 11300 (%s): reserve-hold's STALE branch would delete live jobs; a probe starts its own beanstalkd and exports S4E_QUEUE_PORT" % bd)
        if dry: print("RESERVE_HOLD dry=1 port=%d baton_dir=live-or-private" % PORT); sys.exit(0)
    gs, c = client()
    try:
        if v == "tubes":
            for t in sorted(c.tubes()):
                s = c.stats_tube(t); print("%s\t%d\t%d\t%d\t%d\t%d" % (t, s["current-jobs-ready"], s["current-jobs-reserved"], s["current-jobs-delayed"], s["current-jobs-buried"], s["total-jobs"]))
        elif v == "put":
            tube, topic = a[1], a[2]; pri = 1000; ttr = 3600; delay = 0
            i = 3
            while i < len(a):
                if a[i] == "--pri": pri = int(a[i + 1]); i += 2
                elif a[i] == "--ttr": ttr = int(a[i + 1]); i += 2
                elif a[i] == "--delay": delay = int(a[i + 1]); i += 2
                else: refuse("put: unknown flag " + a[i])
            c.use(tube); print(c.put(topic, priority=pri, delay=delay, ttr=ttr))
        elif v == "peek":
            c.use(a[1])
            try:
                j = c.peek_ready()
            except gs.NotFoundError:
                sys.exit(1)
            s = c.stats_job(j.id); print("%d\t%d\t%d\t%d\t%s" % (j.id, s["pri"], s["ttr"], s["age"], j.body))
        elif v == "stats-tube":
            try:
                st = c.stats_tube(a[1])
            except gs.NotFoundError:
                st = {"current-jobs-ready": 0, "current-jobs-reserved": 0, "current-jobs-delayed": 0, "current-jobs-buried": 0, "total-jobs": 0, "current-watching": 0}
            print("TUBE %s ready=%d reserved=%d delayed=%d buried=%d total=%d watching=%d" % (a[1], st["current-jobs-ready"], st["current-jobs-reserved"], st["current-jobs-delayed"], st["current-jobs-buried"], st["total-jobs"], st["current-watching"]))
        elif v == "stats-job":
            s = c.stats_job(int(a[1])); print("\t".join(str(s[k]) for k in ("id", "tube", "state", "pri", "age", "ttr", "time-left", "reserves", "timeouts", "releases", "buries", "kicks")))
        elif v == "delete": c.delete(int(a[1]))
        elif v == "kick-job": c.kick_job(int(a[1]))
        elif v == "kick":
            c.use(a[1]); print(c.kick(int(a[2]) if len(a) > 2 else 1))
        elif v in ("bury", "touch"):
            refuse("%s acts on a job reserved by the same connection: the bus does it inside one reserve (s4e_msg.sh), not from a fresh process" % v)
        elif v in ("reserve-hold", "hold-job"):
            # fleet-queue step 4 and 5: reserve one job over TUBES, print "id<TAB>tube<TAB>pri<TAB>topic", then stay alive as a detached HOLDER on the
            # same connection (beanstalkd releases a reserved job the moment its connection closes, so the lease lives exactly as long as this process):
            # every INTERVAL s it touches the job while the claim file names --seat on its first line and the session --session is alive; it deletes
            # the job when the claim reads DONE, releases it when the claim vanishes, names another seat, or the session died, and exits.
            tubes = a[1].split(",") if v == "reserve-hold" else []; seat = session = claim = None; batons = None; timeout = 0; i = 2
            while i < len(a):
                if a[i] == "--seat": seat = a[i + 1]
                elif a[i] == "--session": session = a[i + 1]
                elif a[i] == "--claim-dir": claim = a[i + 1]
                elif a[i] == "--timeout": timeout = int(a[i + 1])
                elif a[i] == "--baton-dir": batons = a[i + 1]
                else: refuse("reserve-hold: unknown flag " + a[i])
                i += 2
            if not (seat and claim): refuse("reserve-hold needs --seat SEAT --claim-dir DIR (the claim is DIR/<topic>.claim, the topic being the job body)")
            if v == "hold-job":   # fleet-queue step 5: the tick re-attaches a holder to a ready job by id (beanstalkd 1.12 reserve-job) when the seat's session lives
                try:
                    j = c.reserve_job(int(a[1]))
                except gs.NotFoundError:
                    refuse("job %s is not ready or delayed (not found)" % a[1], 1)
            else:
                for t in tubes: c.watch(t)
                if "default" not in tubes: c.ignore("default")
                try:
                    j = c.reserve(timeout=timeout)
                except gs.TimedOutError:
                    sys.exit(1)
            if batons and not os.path.isfile(os.path.join(batons, j.body + ".task.md")):
                c.release(j, priority=int(c.stats_job(j.id)["pri"]), delay=0); print("STALE %d %s: no baton, released (not deleted; deletion belongs to done)" % (j.id, j.body), file=sys.stderr); sys.exit(3)
            st = c.stats_job(j.id); ttr = int(st["ttr"]); interval = max(2, min(5, ttr // 3)); claim = os.path.join(claim, j.body + ".claim")
            print("%d\t%s\t%d\t%s" % (j.id, st["tube"], st["pri"], j.body)); sys.stdout.flush()
            if os.fork() > 0: os._exit(0)
            os.setsid()
            if os.fork() > 0: os._exit(0)
            logd = "/tmp/s4e/%s" % seat; os.makedirs(logd, exist_ok=True)
            log = open("%s/queue_hold.%d.log" % (logd, j.id), "a")
            os.dup2(log.fileno(), 1); os.dup2(log.fileno(), 2); os.close(0)
            def say(m): print("%s hold job=%d %s" % (time.strftime("%FT%TZ", time.gmtime()), j.id, m)); sys.stdout.flush()
            say("start tube=%s ttr=%d interval=%d claim=%s session=%s" % (st["tube"], ttr, interval, claim, session))
            grace = time.time() + 60
            while True:
                time.sleep(interval)
                try:
                    lines = open(claim).read().splitlines()
                except OSError:
                    lines = None
                if lines is None:
                    if not os.path.isdir(os.path.dirname(claim)): say("claim dir gone: release"); break
                    if time.time() < grace: continue
                    say("claim gone: release"); break
                if any(l.strip() == "DONE" for l in lines):
                    say("claim reads DONE: delete")
                    try: c.delete(j.id)
                    except Exception as e: say("delete: %s" % e)
                    os._exit(0)
                if any(l.strip() == "KILL" for l in lines):
                    say("claim reads KILL: delete")
                    try: c.delete(j.id)
                    except Exception as e: say("delete: %s" % e)
                    os._exit(0)
                parks = [l.strip()[5:] for l in lines if l.strip().startswith("PARK ")]
                if parks:
                    say("claim reads PARK %s: bury" % parks[0])
                    try:
                        c.bury(j, priority=int(st["pri"]))
                        with open(claim, "a") as f: f.write("BURIED job=%d %s %s\n" % (j.id, parks[0], time.strftime("%FT%TZ", time.gmtime())))
                    except Exception as e: say("bury: %s" % e)
                    os._exit(0)
                if lines and lines[0].strip() != seat:
                    oj = [l.split()[1][4:] for l in lines if l.startswith("RESERVED job=")]
                    if oj and oj[-1] != str(j.id):
                        try: ost = c.stats_job(int(oj[-1]))["state"]
                        except Exception: ost = ""
                        if ost == "reserved":
                            say("claim names %s on live job %s: this job is a duplicate of a held row: delete" % (lines[0].strip(), oj[-1]))
                            try: c.delete(j.id)
                            except Exception as e: say("delete: %s" % e)
                            os._exit(0)
                if lines and lines[0].strip() != seat: say("claim names %s, not %s: release" % (lines[0].strip(), seat)); break
                if session and os.system("pgrep -f '(^|/)claude --name %s( |$)' >/dev/null 2>&1" % session) != 0:
                    say("session %s is gone: release" % session); break
                try: c.touch(j)
                except Exception as e: say("touch: %s (the lease is gone)" % e); os._exit(0)
            try: c.release(j, priority=int(st["pri"]))
            except Exception as e: say("release: %s" % e)
            os._exit(0)
        elif v == "put-buried":
            # fleet-queue step 6: a job that is born buried (a parked row with no job to bury): put it, reserve it on this connection, bury it.
            if len(a) < 3: refuse("put-buried TUBE TOPIC [--pri N] [--ttr S]")
            tube, topic = a[1], a[2]; pri = 1000; ttr = 3600; i = 3
            while i < len(a):
                if a[i] == "--pri": pri = int(a[i + 1]); i += 2
                elif a[i] == "--ttr": ttr = int(a[i + 1]); i += 2
                else: refuse("put-buried: unknown flag " + a[i])
            if not hasattr(c, "reserve_job"): refuse("put-buried needs greenstalk: pip3 install --user greenstalk")
            c.use(tube); jid = c.put(topic, priority=pri, ttr=ttr)
            c.bury(c.reserve_job(jid), priority=pri); print(jid)
        elif v == "bury-ready":
            # fleet-queue step 6: bury a READY job (reserve-job by id, then bury). rc 0 buried or already buried; rc 1 no such job; rc 4 reserved by another connection.
            jid = int(a[1])
            try:
                st = c.stats_job(jid)
            except gs.NotFoundError:
                sys.exit(1)
            if st["state"] == "buried": print("already buried %d" % jid); sys.exit(0)
            if st["state"] != "ready": print("held %d state %s" % (jid, st["state"])); sys.exit(4)
            try:
                job = c.reserve_job(jid)
            except gs.NotFoundError:
                print("held %d (reserved while we looked)" % jid); sys.exit(4)
            c.bury(job, priority=int(st["pri"])); print("buried %d" % jid)
        elif v == "reserve":
            tubes = a[1].split(","); timeout = 0
            if len(a) > 3 and a[2] == "--timeout": timeout = int(a[3])
            for t in tubes: c.watch(t)
            if "default" not in tubes: c.ignore("default")
            try:
                j = c.reserve(timeout=timeout)
            except gs.TimedOutError:
                sys.exit(1)
            s = c.stats_job(j.id); print("%d\t%s\t%d\t%s" % (j.id, s["tube"], s["pri"], j.body))
            # the job stays reserved only while this connection lives: the caller must act (claim, then let the TTR run) inside the bus, see step 4
        else:
            refuse("unknown verb " + v)
    except gs.NotFoundError:
        refuse("no such job or tube", 1)
    finally:
        c.close()
if __name__ == "__main__": main(sys.argv[1:])
