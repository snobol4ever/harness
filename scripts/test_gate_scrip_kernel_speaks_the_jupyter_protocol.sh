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
        out = ""
        while True:
            m = kc.get_iopub_msg(timeout=120)
            if m["parent_header"].get("msg_id") != mid: continue
            if m["msg_type"] == "stream": out += m["content"]["text"]
            if m["msg_type"] == "status" and m["content"]["execution_state"] == "idle": break
        status = kc.get_shell_msg(timeout=30)["content"]["status"]
        ok = status == "ok" and out == "Hello, World!\n"
        print("%-8s status=%s out=%r %s" % (lang, status, out, "OK" if ok else "FAIL"))
        bad += 0 if ok else 1
finally:
    kc.stop_channels(); km.shutdown_kernel(now=False)
print("scrip --kernel: %d of %d cells agree" % (len(blocks) - bad, len(blocks)))
sys.exit(1 if bad else 0)
PY
)"; rc=$?
printf '%s\n' "$out"
case $rc in
  0) echo "SCRIP_KERNEL_JUPYTER_PROTOCOL_BOARD cells=3 agree=3 (tree $TREE)"; echo "GATE OK [test_gate_scrip_kernel_speaks_the_jupyter_protocol]: three cells through scrip --kernel print Hello, World!"; exit 0 ;;
  1) echo "SCRIP_KERNEL_JUPYTER_PROTOCOL_BOARD cells=3 agree=<3 (tree $TREE)"; echo "GATE FAIL [test_gate_scrip_kernel_speaks_the_jupyter_protocol]: a cell disagreed, see above"; exit 1 ;;
  *) echo "REFUSE(2): the kernel run did not finish (rc $rc)"; exit 2 ;;
esac
