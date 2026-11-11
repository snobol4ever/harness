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
