#!/bin/bash
[ -n "${SCRIP_BIN:-}" ] || bash "$(dirname "${BASH_SOURCE[0]}")/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_scrip_kernel_speaks_the_jupyter_protocol.sh -- THE NATIVE JUPYTER KERNEL (CTO-512, Lon 2026-11-04: "get rid of the Python and level up"):
# `scrip --kernel <connection_file>` binds the five ZeroMQ sockets itself and answers the Jupyter messaging protocol. This gate starts it through
# jupyter_client (the harness may use Python to TEST; the product has none), sends demo01's three fenced sections as three cells tagged by a first
# line %%<Lang>, and reads one "Hello, World!" per cell with status ok. rc 0 all three agree; rc 1 a cell disagrees; rc 2 cannot measure (no built
# scrip, no jupyter_client, no demo). SCRIP_BIN overrides the binary (a worktree's scrip).
set -u
cd "${S4E_HOME:?REFUSE(2): S4E_HOME unset}" || exit 2
SCRIP_BIN="${SCRIP_BIN:-$PWD/SCRIP/scrip}"
MD="$PWD/corpus/demos/scriptix/demo01/hello.md"
[ -x "$SCRIP_BIN" ] || { echo "REFUSE(2): $SCRIP_BIN is not built"; exit 2; }
[ -r "$MD" ] || { echo "REFUSE(2): no $MD"; exit 2; }
python3 -c 'import jupyter_client' 2>/dev/null || { echo "REFUSE(2): jupyter_client is not importable"; exit 2; }
"$SCRIP_BIN" --kernel /nonexistent-connection-file >/dev/null 2>&1; [ $? -eq 2 ] || { echo "REFUSE(2): $SCRIP_BIN has no --kernel switch"; exit 2; }
TREE="$(git -C "$(dirname "$SCRIP_BIN")" rev-parse --short HEAD 2>/dev/null || echo unknown)"
out="$(timeout -k 5 300 python3 - "$SCRIP_BIN" "$MD" <<'PY'
import sys, re, os, json, tempfile
scrip, md = sys.argv[1], sys.argv[2]
blocks = re.findall(r"```(\w+)\n(.*?)```", open(md).read(), re.S)
if len(blocks) < 3: print("REFUSE(2): demo01 holds fewer than three fenced sections"); sys.exit(2)
spec = tempfile.mkdtemp(prefix="scrip-kernelspec-")
os.makedirs(os.path.join(spec, "kernels", "scrip-gate"))
json.dump({"argv": [scrip, "--kernel", "{connection_file}"], "display_name": "SCRIP gate", "language": "scrip"}, open(os.path.join(spec, "kernels", "scrip-gate", "kernel.json"), "w"))
os.environ["JUPYTER_PATH"] = spec
from jupyter_client.manager import KernelManager
km = KernelManager(kernel_name="scrip-gate")
km.start_kernel()
kc = km.client(); kc.start_channels()
bad = 0
try:
    kc.wait_for_ready(timeout=60)
    info = kc.kernel_info(reply=True, timeout=30)["content"]
    if info.get("implementation") != "SCRIP": print("REFUSE(2): the kernel that answered is %r, not SCRIP" % info.get("implementation")); kc.stop_channels(); km.shutdown_kernel(now=True); sys.exit(2)
    for lang, body in blocks:
        mid = kc.execute("%%" + lang + "\n" + body)
        out = ""; err = ""
        while True:
            m = kc.get_iopub_msg(timeout=120)
            if m["parent_header"].get("msg_id") != mid: continue
            if m["msg_type"] == "stream" and m["content"]["name"] == "stdout": out += m["content"]["text"]
            elif m["msg_type"] == "stream": err += m["content"]["text"]
            if m["msg_type"] == "status" and m["content"]["execution_state"] == "idle": break
        status = kc.get_shell_msg(timeout=30)["content"]["status"]
        note = "scrip: a cell tagged %s runs as its own program: SCRIP has no session road for that language yet (said once)\n" % lang.lower()   # CTO-580 (5): said once a language, on stderr; a SNOBOL4 cell runs in the session and says nothing
        ok = status == "ok" and out == "Hello, World!\n" and err in ("", note) and not (lang == "SNOBOL4" and err)
        print("%-8s status=%s out=%r err=%r %s" % (lang, status, out, err, "OK" if ok else "FAIL"))
        bad += 0 if ok else 1
    def run(code, during=None):   # one cell: the reply, its stdout, its stderr, its error message; during() is called once, when the cell has printed started
        mid = kc.execute(code); out = ""; err = ""; em = None; called = False
        while True:
            m = kc.get_iopub_msg(timeout=120)
            if m["parent_header"].get("msg_id") != mid: continue
            t = m["msg_type"]; c = m["content"]
            if t == "stream" and c["name"] == "stdout":
                out += c["text"]
                if during and not called and "started" in out: called = True; during()
            elif t == "stream": err += c["text"]
            elif t == "error": em = c
            elif t == "status" and c["execution_state"] == "idle": break
        return kc.get_shell_msg(timeout=30)["content"], out, err, em
    # THE HEARTBEAT WHILE A CELL RUNS (CIO-81): a ping sent after the cell printed started is echoed, and nothing more of the cell has been published when the echo is in hand
    import zmq
    ci = km.get_connection_info(); beats = []
    def ping():
        s = zmq.Context.instance().socket(zmq.REQ); s.setsockopt(zmq.LINGER, 0); s.connect("%s://%s:%d" % (ci["transport"], ci["ip"], ci["hb_port"]))
        s.send(b"scrip-gate-ping"); echoed = bool(s.poll(20000)) and s.recv() == b"scrip-gate-ping"; s.close()
        beats.append("echoed" if echoed and not kc.iopub_channel.msg_ready() else "late" if echoed else "silent")
    r1, o1, _, _ = run(" OUTPUT = 'started'\n HBI = 0\nHBL HBI = LT(HBI, 40000000) HBI + 1 :S(HBL)\n OUTPUT = 'finished'\n", ping)
    r2, o2, _, _ = run("%%icon\nprocedure main();\n  write(\"started\");\n  every 1 to 300000000;\n  write(\"finished\");\nend\n", ping)
    hb = beats == ["echoed", "echoed"] and r1["status"] == "ok" and r2["status"] == "ok" and o1 == "started\nfinished\n" and o2 == "started\nfinished\n"
    print("KERNEL_HEARTBEAT ok" if hb else "KERNEL_HEARTBEAT RED: the session cell %s, the one-program cell %s (statuses %s %s)" % ((beats + ["unsent", "unsent"])[0], (beats + ["unsent", "unsent"])[1], r1["status"], r2["status"]))
    bad += 0 if hb else 1
    # THE ERROR REPLY CARRIES THE LANGUAGE'S OWN MESSAGE (CIO-73 (2)(d), re-cut by CTO-593): SPITBOL's number and text for a session cell, SCRIP's own error line for a one-program cell
    r3, _, e3, m3 = run(" OUTPUT = NOSUCHFUNCTION(1)\n")
    r4, o4, _, _ = run(" OUTPUT = 'after the error'\n")
    r5, _, _, m5 = run("%%icon\nprocedure main();\n  write(1 / 0);\nend\n")
    et = (r3["status"] == "error" and r3.get("ename") == "SNOBOL4 error 22" and r3.get("evalue") == "undefined function called" and e3 == "" and m3 is not None and m3.get("evalue") == r3.get("evalue")
          and m3.get("traceback") == r3.get("traceback") and len(r3.get("traceback") or []) >= 1 and r4["status"] == "ok" and o4 == "after the error\n"
          and r5["status"] == "error" and "cell exited" not in (r5.get("evalue") or "cell exited") and len(r5.get("traceback") or []) >= 2 and m5 is not None and m5.get("evalue") == r5.get("evalue"))
    print("KERNEL_ERROR_TEXT ok" if et else "KERNEL_ERROR_TEXT RED: session reply %r %r stderr %r, then %r; one-program reply %r %r" % (r3.get("ename"), r3.get("evalue"), e3, o4, r5.get("ename"), r5.get("evalue")))
    bad += 0 if et else 1
    def many(sends):   # send every request before reading anything; return for each its reply, its stdout and the broadcast message types it caused
        mids = [kc.execute(code, **kw) for code, kw in sends]
        seen = {mid: {"out": "", "types": [], "idle": False} for mid in mids}
        while not all(v["idle"] for v in seen.values()):
            m = kc.get_iopub_msg(timeout=120); v = seen.get(m["parent_header"].get("msg_id"))
            if v is None: continue
            v["types"].append(m["msg_type"])
            if m["msg_type"] == "stream" and m["content"]["name"] == "stdout": v["out"] += m["content"]["text"]
            if m["msg_type"] == "status" and m["content"]["execution_state"] == "idle": v["idle"] = True
        left = set(mids)
        while left:
            m = kc.get_shell_msg(timeout=60); mid = m["parent_header"].get("msg_id")
            if mid in left: seen[mid]["reply"] = m["content"]; left.discard(mid)
        return [seen[mid] for mid in mids]
    # STOP ON ERROR (CIO-81): the requests already waiting when a cell fails are answered aborted and not run; with stop_on_error false the next one runs
    slow_fail = " SOEI = 0\nSOEL SOEI = LT(SOEI, 6000000) SOEI + 1 :S(SOEL)\n OUTPUT = 1 / 0\n"
    a1, a2, a3 = many([(slow_fail, {}), (" OUTPUT = 'second ran'\n", {}), (" OUTPUT = 'third ran'\n", {})])
    b1, b2 = many([(slow_fail, {"stop_on_error": False}), (" OUTPUT = 'ran after a failure that does not stop'\n", {})])
    c1, = many([(" OUTPUT = 'the queue is open again'\n", {})])
    so = (a1["reply"]["status"] == "error" and a1["reply"].get("ename") == "SNOBOL4 error 14" and a2["reply"]["status"] == "aborted" and a3["reply"]["status"] == "aborted" and "execution_count" in a2["reply"] and a2["out"] == "" and a3["out"] == "" and b1["reply"]["status"] == "error" and b2["reply"]["status"] == "ok"
          and b2["out"] == "ran after a failure that does not stop\n" and c1["reply"]["status"] == "ok" and c1["out"] == "the queue is open again\n")
    print("KERNEL_STOP_ON_ERROR ok" if so else "KERNEL_STOP_ON_ERROR RED: replies %s %r, %s %r, %s %r; outputs %r %r; without the stop %s %r; after %r" % (a1["reply"]["status"], a1["reply"].get("ename"),
          a2["reply"]["status"], a2["reply"].get("evalue"), a3["reply"]["status"], a3["reply"].get("evalue"), a2["out"], a3["out"], b2["reply"]["status"], b2["out"], c1["out"]))
    bad += 0 if so else 1
    # SILENT AND UNSTORED REQUESTS (CIO-81): a silent request broadcasts nothing but its two status messages and leaves the counter; an unstored one prints and leaves the counter; a stored one moves it by one
    n0 = c1["reply"]["execution_count"]
    s1, = many([(" OUTPUT = 'silent output'\n", {"silent": True})])
    s2, = many([(" OUTPUT = 'unstored output'\n", {"store_history": False})])
    s3, = many([(" OUTPUT = 'stored output'\n", {})])
    si = (s1["types"] == ["status", "status"] and s1["reply"]["execution_count"] == n0 and s2["out"] == "unstored output\n" and "execute_input" in s2["types"] and s2["reply"]["execution_count"] == n0
          and s3["out"] == "stored output\n" and s3["reply"]["execution_count"] == n0 + 1)
    print("KERNEL_SILENT ok" if si else "KERNEL_SILENT RED: silent broadcast %r count %r, unstored %r count %r, stored count %r, the count before %r" % (s1["types"], s1["reply"]["execution_count"], s2["out"],
          s2["reply"]["execution_count"], s3["reply"]["execution_count"], n0))
    bad += 0 if si else 1
    # IS THIS CELL COMPLETE, BY THE CELL'S LANGUAGE (CIO-73): a Prolog clause without its full stop and an Icon call with an open bracket are incomplete; a bracket inside a string does not count; SNOBOL4 is always complete
    def whole(code):
        mid = kc.is_complete(code)
        while True:
            m = kc.get_shell_msg(timeout=30)
            if m["parent_header"].get("msg_id") == mid: return m["content"]["status"]
    ic = [whole("%%prolog\nfoo :- bar"), whole("%%prolog\nfoo :- bar."), whole("%%icon\nprocedure main();\n  write(\"a\""), whole("%%icon\nprocedure main(); write(\"(\"); end"), whole(" OUTPUT = 'a'")]
    print("KERNEL_IS_COMPLETE ok" if ic == ["incomplete", "complete", "incomplete", "complete", "complete"] else "KERNEL_IS_COMPLETE RED: the five answers are %r" % ic)
    bad += 0 if ic == ["incomplete", "complete", "incomplete", "complete", "complete"] else 1
    # COMPLETION FROM THE BUILTIN TABLE OF THE CELL'S LANGUAGE (CIO-73 (2)(f)): SNOBOL4 offers DUPL for DUP, Icon offers writes for wri, Prolog (whose table rows are internal names) offers nothing
    def names(code):
        mid = kc.complete(code, len(code))
        while True:
            m = kc.get_shell_msg(timeout=30)
            if m["parent_header"].get("msg_id") == mid: return m["content"]
    k1, k2, k3 = names(" OUTPUT = DUP"), names("%%icon\nprocedure main();\n  wri"), names("%%prolog\nfoo :- atom_")
    co = ("DUPL" in k1.get("matches", []) and k1.get("cursor_end", 0) - k1.get("cursor_start", 0) == 3 and "writes" in k2.get("matches", []) and "write" in k2.get("matches", [])
          and k3.get("status") == "ok" and k3.get("matches") == [])
    print("KERNEL_COMPLETE ok" if co else "KERNEL_COMPLETE RED: SNOBOL4 %r from %r to %r, Icon %r, Prolog %r %r" % (k1.get("matches"), k1.get("cursor_start"), k1.get("cursor_end"), k2.get("matches"), k3.get("status"),
          k3.get("matches")))
    bad += 0 if co else 1
    # THE REST OF THE PROTOCOL (CTO-597, the scan of the Jupyter documentation against kernel.c). Each arm below reads one message exchange the specification names.
    def ask(msg_or_id, chan="shell"):   # the reply to a request already sent (a message id) or sent here on the shell channel (a message)
        mid = msg_or_id if isinstance(msg_or_id, str) else (kc.shell_channel.send(msg_or_id), msg_or_id["header"]["msg_id"])[1]
        try:
            while True:
                m = kc.get_shell_msg(timeout=30)
                if m["parent_header"].get("msg_id") == mid: return m["content"]
        except Exception: return {"status": "no reply"}   # a request the kernel does not answer reads RED in its own arm and the arms after it are still read
    def cell(code, **kw):   # one cell: its reply and every broadcast message it caused, in order, as (type, content)
        mid = kc.execute(code, **kw); got = []
        while True:
            m = kc.get_iopub_msg(timeout=120)
            if m["parent_header"].get("msg_id") != mid: continue
            if m["msg_type"] == "status":
                if m["content"]["execution_state"] == "idle": break
                continue
            if m["msg_type"] != "execute_input": got.append((m["msg_type"], m["content"]))
        return ask(mid), got
    # KERNEL INFORMATION (messaging 5.5): the version, no optional feature claimed, the help links of every language for the many-language kernel
    hl1 = info.get("help_links") or []
    ks = (info.get("protocol_version") == "5.5" and info.get("supported_features") == [] and info.get("debugger") is False and len(hl1) >= 7
          and all(isinstance(h.get("text"), str) and str(h.get("url", "")).startswith("https://") for h in hl1) and len({h["url"] for h in hl1}) == len(hl1))
    print("KERNEL_INFO_SPEC ok" if ks else "KERNEL_INFO_SPEC RED: protocol %r, features %r, debugger %r, help links %r" % (info.get("protocol_version"), info.get("supported_features"), info.get("debugger"), hl1))
    bad += 0 if ks else 1
    # THE WELCOME MESSAGE (messaging 5.5): a subscriber that connects to the broadcast socket is sent iopub_welcome naming its subscription, with no parent
    sub = zmq.Context.instance().socket(zmq.SUB); sub.setsockopt(zmq.LINGER, 0); sub.setsockopt(zmq.SUBSCRIBE, b"gate.topic")
    sub.connect("%s://%s:%d" % (ci["transport"], ci["ip"], ci["iopub_port"]))
    wl = None
    if sub.poll(20000):
        fr = sub.recv_multipart(); d = fr.index(b"<IDS|MSG>")
        wl = (fr[0], json.loads(fr[d + 2]).get("msg_type"), json.loads(fr[d + 3]), json.loads(fr[d + 5]))
    sub.close()
    we = wl is not None and wl[0] == b"gate.topic" and wl[1] == "iopub_welcome" and wl[2] == {} and wl[3] == {"subscription": "gate.topic"}
    print("KERNEL_WELCOME ok" if we else "KERNEL_WELCOME RED: a new subscriber read %r" % (wl,))
    bad += 0 if we else 1
    # HISTORY (messaging, history_request): the stored cells in order; a silent and an unstored cell are not history; tail, range, search with a pattern, and the output form
    h_tail = ask(kc.history(hist_access_type="tail", n=3)).get("history") or []
    h_rng = ask(kc.history(hist_access_type="range", session=0, start=1, stop=3)).get("history") or []
    h_srch = ask(kc.history(hist_access_type="search", pattern="*stored output*", n=10)).get("history") or []
    h_sil = ask(kc.history(hist_access_type="search", pattern="*silent output*", n=10)).get("history")
    h_out = ask(kc.history(hist_access_type="tail", n=1, output=True)).get("history") or []
    hi = (len(h_tail) == 3 and [e[1] for e in h_tail] == sorted(e[1] for e in h_tail) and h_tail[-1][1] == n0 + 1 and h_tail[-1][2] == " OUTPUT = 'stored output'\n" and [e[1] for e in h_rng] == [1, 2]
          and [e[2] for e in h_srch] == [" OUTPUT = 'stored output'\n"] and h_sil == [] and len(h_out) == 1 and h_out[0][2] == [" OUTPUT = 'stored output'\n", None])
    print("KERNEL_HISTORY ok" if hi else "KERNEL_HISTORY RED: tail %r, range %r, search %r, silent %r, with output %r" % (h_tail, h_rng, h_srch, h_sil, h_out))
    bad += 0 if hi else 1
    # COMMS (messaging, custom messages): a comm the front end opens for a target the kernel does not have is closed at once; the kernel holds no comm
    cm = kc.session.msg("comm_open", {"comm_id": "gate-comm-1", "target_name": "no.such.target", "data": {}}); kc.shell_channel.send(cm); closed = None
    while True:
        m = kc.get_iopub_msg(timeout=60)
        if m["parent_header"].get("msg_id") != cm["header"]["msg_id"]: continue
        if m["msg_type"] == "comm_close": closed = m["content"]
        if m["msg_type"] == "status" and m["content"]["execution_state"] == "idle": break
    ci_r = ask(kc.comm_info())
    cmok = closed is not None and closed.get("comm_id") == "gate-comm-1" and closed.get("data") == {} and ci_r.get("status") == "ok" and ci_r.get("comms") == {}
    print("KERNEL_COMM ok" if cmok else "KERNEL_COMM RED: the open was answered %r, comm_info %r" % (closed, ci_r))
    bad += 0 if cmok else 1
    # CONNECT (messaging, connect_request; deprecated and still asked by old clients): the five ports of the connection file
    cr = ask(kc.session.msg("connect_request", {}))
    cn = all(cr.get(n) == ci[n] for n in ("shell_port", "iopub_port", "stdin_port", "hb_port", "control_port"))
    print("KERNEL_CONNECT ok" if cn else "KERNEL_CONNECT RED: the reply reads %r" % cr)
    bad += 0 if cn else 1
    # INSPECTION (messaging, inspect_request): the builtin under the cursor is found and described from the builtin table; a name that is no builtin is not found
    i1, i2 = ask(kc.inspect(" OUTPUT = DUPL('a', 3)", 12)), ask(kc.inspect(" OUTPUT = NOSUCHBUILTIN(1)", 14))
    ins = i1.get("found") is True and str(i1.get("data", {}).get("text/plain", "")).startswith("DUPL: a builtin of SNOBOL4") and i2.get("status") == "ok" and i2.get("found") is False and i2.get("data") == {}
    print("KERNEL_INSPECT ok" if ins else "KERNEL_INSPECT RED: DUPL %r, an unknown name %r" % (i1, i2))
    bad += 0 if ins else 1
    # COMPLETION BEYOND THE BUILTINS: a name an earlier cell used, a name of the cell being typed, a language after the two percent signs, and the type of each match
    cell(" GATEWORDALPHA = 1\n")
    w1, w2, w3 = names(" OUTPUT = GATEWORDA"), names(" GATEHEREBETA = 2\n OUTPUT = GATEHEREB"), names("%%pro")
    t1 = {t.get("text"): t.get("type") for t in names(" OUTPUT = DUP").get("metadata", {}).get("_jupyter_types_experimental", [])}
    cw = w1.get("matches") == ["GATEWORDALPHA"] and w2.get("matches") == ["GATEHEREBETA"] and w3.get("matches") == ["prolog"] and w3.get("cursor_start") == 2 and t1.get("DUPL") == "function"
    print("KERNEL_COMPLETE_WORDS ok" if cw else "KERNEL_COMPLETE_WORDS RED: an earlier name %r, a name of this cell %r, a language %r from %r, types %r" % (w1.get("matches"), w2.get("matches"), w3.get("matches"), w3.get("cursor_start"), t1))
    bad += 0 if cw else 1
    # RICH DISPLAY (messaging, display_data and update_display_data): a display cell shows its own text; a language cell with display= shows what it printed as that type and prints nothing;
    # id= names the display, update= replaces every display of that name; JSON is carried as a value; an image is carried in base 64
    d1r, d1 = cell("%%html\n<b>bold</b>\n")
    d2r, d2 = cell("%%icon display=svg id=gate1\nprocedure main();\n  write(\"<svg xmlns='http://www.w3.org/2000/svg'/>\");\nend\n")
    d3r, d3 = cell("%%snobol4 display=html update=gate1\n OUTPUT = '<i>x</i>'\n")
    d4r, d4 = cell("%%json\n{\"a\": [1, 2]}\n")
    d5r, d5 = cell("%%snobol4 display=png\n OUTPUT = 'abc'\n")
    def only(got, typ): return got[0][1] if len(got) == 1 and got[0][0] == typ else {}
    dp = (d1r["status"] == "ok" and only(d1, "display_data").get("data", {}).get("text/html") == "<b>bold</b>\n" and only(d1, "display_data").get("metadata") == {}
          and d2r["status"] == "ok" and only(d2, "display_data").get("data", {}).get("image/svg+xml") == "<svg xmlns='http://www.w3.org/2000/svg'/>\n" and only(d2, "display_data").get("transient") == {"display_id": "gate1"}
          and d3r["status"] == "ok" and only(d3, "update_display_data").get("data", {}).get("text/html") == "<i>x</i>\n" and only(d3, "update_display_data").get("transient") == {"display_id": "gate1"}
          and only(d4, "display_data").get("data", {}).get("application/json") == {"a": [1, 2]} and only(d5, "display_data").get("data", {}).get("image/png") == "YWJjCg==")
    print("KERNEL_DISPLAY ok" if dp else "KERNEL_DISPLAY RED: html %r; svg %r; update %r; json %r; png %r" % (d1, d2, d3, d4, d5))
    bad += 0 if dp else 1
    # CLEAR OUTPUT (messaging, clear_output): a form feed in what a cell prints clears the cell's output, waiting for the next output
    c5r, c5 = cell(" OUTPUT = 'one' CHAR(12) 'two'\n")
    cl = c5r["status"] == "ok" and [t for t, _ in c5] == ["stream", "clear_output", "stream"] and c5[0][1].get("text") == "one" and c5[1][1] == {"wait": True} and c5[2][1].get("text") == "two\n"
    print("KERNEL_CLEAR ok" if cl else "KERNEL_CLEAR RED: the cell broadcast %r" % (c5,))
    bad += 0 if cl else 1
    # VALUES FROM THE LIVE SESSION (messaging, user_expressions and inspect_request): each user expression of an execute request is evaluated in the session after the cell and answered as a
    # MIME bundle or as its own error; the name under the cursor that is no builtin is described by its datatype and value; a language with no session answers each expression with an error
    u1r, _ = cell(" UXV = 41\n", user_expressions={"sum": "UXV + 1", "bad": "NOSUCHFUNCTION(1)", "fails": "DIFFER(1, 1)", "text": "'two' CHAR(10) 'lines'"})
    u2r, u2 = cell(" OUTPUT = 'the session lives ' UXV\n")
    u3r, _ = cell("%%icon\nprocedure main();\n  write(1);\nend\n", user_expressions={"x": "1 + 1"})
    ux, i3, i4 = u1r.get("user_expressions", {}), ask(kc.inspect(" OUTPUT = UXV", 12)), ask(kc.inspect(" OUTPUT = UXNEVERSET", 14))
    ue = (ux.get("sum") == {"status": "ok", "data": {"text/plain": "42"}, "metadata": {}} and ux.get("bad", {}).get("status") == "error" and ux.get("bad", {}).get("ename") == "SNOBOL4 error 22"
          and ux.get("fails", {}).get("ename") == "SNOBOL4 failure" and ux.get("text", {}).get("data") == {"text/plain": "two\nlines"} and u2r["status"] == "ok" and u2 == [("stream", {"name": "stdout", "text": "the session lives 41\n"})]
          and u3r["status"] == "ok" and u3r.get("user_expressions", {}).get("x", {}).get("status") == "error" and i3.get("found") is True and i3.get("data", {}).get("text/plain") == "UXV: INTEGER\n41"
          and i4.get("found") is False)
    print("KERNEL_EXPRESSIONS ok" if ue else "KERNEL_EXPRESSIONS RED: the four expressions %r; the next cell %r %r; an Icon cell's expression %r; inspect of a set name %r, of an unset name %r" % (ux, u2r.get("status"), u2,
          u3r.get("user_expressions"), i3, i4))
    bad += 0 if ue else 1
    # STANDARD INPUT (messaging, the stdin channel; CIO-103 and CTO-584): a cell that reads standard input, sent with allow_stdin true, makes the kernel send input_request to the front end that
    # sent the cell, with what the cell printed before the read already published; the answer is the line the program reads. Two reads are two requests. A cell that reads nothing asks nothing.
    # With allow_stdin false no request is sent and the program reads end of file. The session cell and the one-program cell alike.
    def reading(code, answers, allow=True):
        mid = kc.execute(code, allow_stdin=allow); out = ""; asked = []; left = list(answers)
        while True:
            if kc.stdin_channel.msg_ready():
                r = kc.get_stdin_msg(timeout=5)
                if r["parent_header"].get("msg_id") == mid and r["msg_type"] == "input_request":
                    while kc.iopub_channel.msg_ready():   # what was published before the request is read before the answer is sent
                        m = kc.get_iopub_msg(timeout=5)
                        if m["parent_header"].get("msg_id") == mid and m["msg_type"] == "stream" and m["content"]["name"] == "stdout": out += m["content"]["text"]
                    asked.append((r["content"], out)); kc.input(left.pop(0) if left else "")
                continue
            try: m = kc.get_iopub_msg(timeout=1)
            except Exception: continue
            if m["parent_header"].get("msg_id") != mid: continue
            if m["msg_type"] == "stream" and m["content"]["name"] == "stdout": out += m["content"]["text"]
            if m["msg_type"] == "status" and m["content"]["execution_state"] == "idle": break
        return ask(mid).get("status"), out, asked
    sn = " OUTPUT = 'what is your name'\n GSN%d = INPUT :F(GSE%d)\n OUTPUT = 'got ' GSN%d :(GSK%d)\nGSE%d OUTPUT = 'end of file'\nGSK%d\n"
    ic = "%%icon\nprocedure main();\n  writes(\"n? \");\n  l := read() | \"end of file\";\n  write(\"got \", l);\nend\n"
    g1 = reading(sn % ((1,) * 6), ["hello"])
    g2 = reading(" GSA = INPUT\n GSB = INPUT\n OUTPUT = GSB ' then ' GSA\n", ["first", "second"])
    g3 = reading(" OUTPUT = 'reads nothing'\n", [])
    g4 = reading(ic, ["zed"])
    g5 = reading(ic, [], allow=False)
    g6 = reading(sn % ((2,) * 6), [], allow=False)
    rq = {"prompt": "", "password": False}
    si_ok = (g1 == ("ok", "what is your name\ngot hello\n", [(rq, "what is your name\n")]) and g2[0] == "ok" and g2[1] == "second then first\n" and len(g2[2]) == 2 and g3 == ("ok", "reads nothing\n", [])
             and g4 == ("ok", "n? got zed\n", [(rq, "n? ")]) and g5 == ("ok", "n? got end of file\n", []) and g6 == ("ok", "what is your name\nend of file\n", []))
    print("KERNEL_STDIN ok" if si_ok else "KERNEL_STDIN RED: one read %r; two reads %r; no read %r; an Icon read %r; Icon without leave %r; the session without leave %r" % (g1, g2, g3, g4, g5, g6))
    bad += 0 if si_ok else 1
finally:
    kc.stop_channels(); km.shutdown_kernel(now=False)
# A CELL RUNS IN THE KERNEL'S OWN DIRECTORY (CIO-78): a second kernel started in a scratch folder reads the file beside the notebook by its bare name, from a session cell and from a one-program cell
wd = tempfile.mkdtemp(prefix="scrip-kernel-cwd-")
open(os.path.join(wd, "kcwd.dat"), "w").write("beside the notebook\n")
km = KernelManager(kernel_name="scrip-gate"); km.start_kernel(cwd=wd, env=dict(os.environ, SCRIP_DEFAULT_LANG="Prolog")); kc = km.client(); kc.start_channels()
try:
    kc.wait_for_ready(timeout=60)
    # THE KERNEL NAMES ITS SESSION'S LANGUAGE (CIO-73 (2)(g)): started with the default language Prolog it answers kernel_info with Prolog's name, extension and highlighter
    li = kc.kernel_info(reply=True, timeout=30)["content"].get("language_info", {})
    il = li.get("name") == "prolog" and li.get("file_extension") == ".pl" and li.get("pygments_lexer") == "prolog" and li.get("mimetype") == "text/x-prolog"
    print("KERNEL_INFO_LANG ok" if il else "KERNEL_INFO_LANG RED: language_info reads %r" % li)
    bad += 0 if il else 1
    def run2(code):
        mid = kc.execute(code); out = ""
        while True:
            m = kc.get_iopub_msg(timeout=120)
            if m["parent_header"].get("msg_id") != mid: continue
            if m["msg_type"] == "stream" and m["content"]["name"] == "stdout": out += m["content"]["text"]
            if m["msg_type"] == "status" and m["content"]["execution_state"] == "idle": break
        return kc.get_shell_msg(timeout=30)["content"]["status"], out
    s1, c1 = run2("%%snobol4\n        INPUT(.KCWDLINE, 5, 'kcwd.dat')\n        OUTPUT = KCWDLINE\n        ENDFILE(5)\n")
    s2, c2 = run2("%%icon\nprocedure main();\n  f := open(\"kcwd.dat\") | stop(\"no kcwd.dat here\");\n  write(read(f));\n  close(f);\nend\n")
    cw = s1 == "ok" and c1 == "beside the notebook\n" and s2 == "ok" and c2 == "beside the notebook\n"
    print("KERNEL_CWD ok" if cw else "KERNEL_CWD RED: the session cell %s %r, the one-program cell %s %r" % (s1, c1, s2, c2))
    bad += 0 if cw else 1
finally:
    kc.stop_channels(); km.shutdown_kernel(now=False)
# THE IPC TRANSPORT (kernels, connection files): a kernel whose connection file names transport ipc binds its five sockets on path-and-port names and runs a cell
km = KernelManager(kernel_name="scrip-gate", transport="ipc", ip=os.path.join(tempfile.mkdtemp(prefix="scrip-kernel-ipc-"), "k")); km.start_kernel(); kc = km.client(); kc.start_channels()
try:
    kc.wait_for_ready(timeout=60)
    mid = kc.execute(" OUTPUT = 'over ipc'\n"); out = ""
    while True:
        m = kc.get_iopub_msg(timeout=120)
        if m["parent_header"].get("msg_id") != mid: continue
        if m["msg_type"] == "stream" and m["content"]["name"] == "stdout": out += m["content"]["text"]
        if m["msg_type"] == "status" and m["content"]["execution_state"] == "idle": break
    ip_ok = out == "over ipc\n"
except Exception as e:
    ip_ok = False; out = repr(e)
finally:
    kc.stop_channels(); km.shutdown_kernel(now=True)
print("KERNEL_IPC ok" if ip_ok else "KERNEL_IPC RED: the cell over ipc read %r" % out)
bad += 0 if ip_ok else 1
print("scrip --kernel: %d disagreement(s) over %d hello cells and the arms" % (bad, len(blocks)))
sys.exit(1 if bad else 0)
PY
)"; rc=$?
printf '%s\n' "$out"
# ZEROMQ IS LOADED ONLY BY THE KERNEL (Lon 2026-11-11, in the cto's window: "Do use dlopen. Seems better."): the binary names no ZeroMQ library among the libraries it needs, and the arms above ran through it
need="$(readelf -d "$SCRIP_BIN" 2>/dev/null | grep -c 'NEEDED.*libzmq')"
if [ "$need" = 0 ] && [ "$rc" != 2 ]; then echo "KERNEL_DLOPEN ok"; else echo "KERNEL_DLOPEN RED: the binary names libzmq among its needed libraries ($need), so every run of scrip loads it"; [ "$rc" = 0 ] && rc=1; fi
case $rc in
  0) echo "SCRIP_KERNEL_JUPYTER_PROTOCOL_BOARD cells=3 agree=3 (tree $TREE)"; echo "GATE OK [test_gate_scrip_kernel_speaks_the_jupyter_protocol]: three cells through scrip --kernel print Hello, World!"; exit 0 ;;
  1) echo "SCRIP_KERNEL_JUPYTER_PROTOCOL_BOARD cells=3 agree=<3 (tree $TREE)"; echo "GATE FAIL [test_gate_scrip_kernel_speaks_the_jupyter_protocol]: a cell disagreed, see above"; exit 1 ;;
  *) echo "REFUSE(2): the kernel run did not finish (rc $rc)"; exit 2 ;;
esac
