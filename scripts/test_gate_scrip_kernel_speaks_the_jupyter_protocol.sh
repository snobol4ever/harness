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
    so = (a1["reply"]["status"] == "error" and a1["reply"].get("ename") == "SNOBOL4 error 14" and a2["reply"]["status"] == "error" and a2["reply"].get("evalue") == "aborted" and a3["reply"]["status"] == "error"
          and a3["reply"].get("evalue") == "aborted" and a2["out"] == "" and a3["out"] == "" and b1["reply"]["status"] == "error" and b2["reply"]["status"] == "ok"
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
print("scrip --kernel: %d disagreement(s) over %d hello cells and the arms" % (bad, len(blocks)))
sys.exit(1 if bad else 0)
PY
)"; rc=$?
printf '%s\n' "$out"
case $rc in
  0) echo "SCRIP_KERNEL_JUPYTER_PROTOCOL_BOARD cells=3 agree=3 (tree $TREE)"; echo "GATE OK [test_gate_scrip_kernel_speaks_the_jupyter_protocol]: three cells through scrip --kernel print Hello, World!"; exit 0 ;;
  1) echo "SCRIP_KERNEL_JUPYTER_PROTOCOL_BOARD cells=3 agree=<3 (tree $TREE)"; echo "GATE FAIL [test_gate_scrip_kernel_speaks_the_jupyter_protocol]: a cell disagreed, see above"; exit 1 ;;
  *) echo "REFUSE(2): the kernel run did not finish (rc $rc)"; exit 2 ;;
esac
