#!/bin/bash
[ -n "${SCRIP_BIN:-}" ] || bash "$(dirname "${BASH_SOURCE[0]}")/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# s4e_probe_jupyter_every_language.sh -- JUPYTER RUNS EVERY LANGUAGE THROUGH THE ONE SCRIP KERNEL (the cto 2026-11-11 19:3x CST, row
# jupyter-lab-and-notebook-run-every-language-through-the-scrip-kernel; Lon 2026-11-11 18:4x, verbatim: "Get Jupyter Lab/notebook working.";
# CTO-600: a notebook is a SCRIPtix document and SCRIP is its host). Two arms, one per finish line:
#   notebooks  every one of the eight languages (snobol4 snocone rebus icon unicon prolog pascal raku) has at least one notebook under
#              corpus/notebooks/ whose kernelspec is scrip and whose code cells are tagged with that language (an untagged cell is snobol4),
#              and util_notebook_kernel_check.py check reads differs=0 on every notebook under corpus/notebooks/.
#   session    for each of the eight languages, two cells run in order through scrip --kernel (jupyter_client): the first defines a value,
#              the second, a separate cell, prints it; the language's arm reads SAME when the second cell's stdout is the line shared and
#              neither cell wrote stderr or an error. This is the session law of CTO-600 for every language: what a cell leaves, the next finds.
#              The eight cell pairs below are the DESIGN of that law (cto, 2026-11-11): a SNOBOL4 or Snocone variable; an Icon, Unicon or
#              Rebus global, each cell its own procedure main run in cell order; a Prolog fact; a Pascal unit the next cell uses; a Raku
#              our-scoped variable.
#   lang L     the notebooks arm for one language L alone: at least one scrip notebook under corpus/notebooks/ carries a code cell tagged L,
#              and every such notebook reads differs=0 (the per-language notebook rows' criterion).
#   note       one %%prolog cell that prints Hello, run as the first cell of a fresh kernel: its stdout is the line Hello and it wrote NO stderr
#              (the kernel's own notes about a language go to the kernel's log, never into a cell: a cell's stderr is the program's alone).
#   all        notebooks, then session.
# One board line per arm; rc 0 GREEN, rc 1 RED (names what is red), rc 2 REFUSE (no built scrip, no jupyter_client, no notebook folder).
# SCRIP_BIN overrides the binary (a worktree's scrip).
set -u
cd "${S4E_HOME:?REFUSE(2): S4E_HOME unset}" || exit 2
arm="${1:-all}"; one="${2:-}"
case "$arm" in notebooks|session|all|note) ;; lang) case " snobol4 snocone rebus icon unicon prolog pascal raku " in *" $one "*) ;; *) echo "usage: lang needs one of the eight languages"; exit 2 ;; esac ;; *) echo "usage: s4e_probe_jupyter_every_language.sh notebooks|session|note|all|lang L"; exit 2 ;; esac
SCRIP_BIN="${SCRIP_BIN:-$PWD/SCRIP/scrip}"
[ -x "$SCRIP_BIN" ] || { echo "REFUSE(2): $SCRIP_BIN is not built"; exit 2; }
python3 -c 'import jupyter_client, nbformat' 2>/dev/null || { echo "REFUSE(2): jupyter_client or nbformat is not importable"; exit 2; }
[ -d corpus/notebooks ] || { echo "REFUSE(2): no corpus/notebooks"; exit 2; }
TREE="$(git -C "$(dirname "$SCRIP_BIN")" rev-parse --short HEAD 2>/dev/null || echo unknown)"
LANGS="snobol4 snocone rebus icon unicon prolog pascal raku"
rc_all=0
notebooks_arm() {
    local have miss="" l out bad want="${1:-$LANGS}" files
    have="$(python3 - <<'PY'
import glob, json, re, sys
seen = set()
for f in sorted(glob.glob("corpus/notebooks/**/*.ipynb", recursive=True)):
    try: nb = json.load(open(f))
    except Exception: print("BADJSON " + f); continue
    if (nb.get("metadata", {}).get("kernelspec", {}) or {}).get("name") != "scrip": continue
    for c in nb.get("cells", []):
        if c.get("cell_type") != "code": continue
        src = "".join(c.get("source", "")) if isinstance(c.get("source"), list) else c.get("source", "")
        m = re.match(r"%%\s*(\w+)", src.lstrip("\n"))
        tag = m.group(1).lower() if m else "snobol4"
        seen.add({"snobol": "snobol4", "spitbol": "snobol4"}.get(tag, tag))
print(" ".join(sorted(seen)))
PY
)"
    files="$(find corpus/notebooks -name '*.ipynb' | sort)"
    if [ "$want" != "$LANGS" ]; then files="$(for f in $files; do grep -qiE '"%%[[:space:]]*'"$want"'([^a-z]|$)' "$f" && echo "$f"; done)"; [ "$want" = snobol4 ] && files="$(find corpus/notebooks -maxdepth 1 -name '*.ipynb' | sort)"; fi
    case "$have" in *BADJSON*) echo "REFUSE(2): a notebook under corpus/notebooks does not parse: $have"; return 2 ;; esac
    for l in $want; do case " $have " in *" $l "*) ;; *) miss="$miss $l" ;; esac; done
    [ -n "$files" ] || { echo "JUPYTER_NOTEBOOKS_BOARD notebooks=0 differing=0 languages_missing=$want (tree $TREE)"; echo "  RED: no scrip notebook carries a code cell of: $want"; return 1; }
    out="$(timeout -k 5 3000 python3 harness/scripts/util_notebook_kernel_check.py check $files 2>&1)"; local crc=$?
    [ "$crc" = 2 ] && { echo "REFUSE(2): util_notebook_kernel_check.py could not measure:"; printf '%s\n' "$out" | grep -m3 REFUSE; return 2; }
    bad="$(printf '%s\n' "$out" | grep '^NOTEBOOK_KERNEL ' | grep -vc ' differs=0 ')"
    local nn; nn="$(printf '%s\n' "$out" | grep -c '^NOTEBOOK_KERNEL ')"
    echo "JUPYTER_NOTEBOOKS_BOARD notebooks=$nn differing=$bad languages_missing=${miss:- none} (tree $TREE)"
    printf '%s\n' "$out" | grep '^NOTEBOOK_KERNEL ' | grep -v ' differs=0 ' | sed 's/^/  RED: /'
    [ -z "$miss" ] && [ "$bad" = 0 ] && [ "$nn" -ge 1 ] && return 0
    [ -n "$miss" ] && echo "  RED: no scrip notebook carries a code cell of:$miss"
    return 1
}
session_arm() {
    local out
    out="$(timeout -k 5 900 python3 - "$SCRIP_BIN" <<'PY'
import sys, os, json, tempfile
scrip = sys.argv[1]
spec = tempfile.mkdtemp(prefix="scrip-probe-kernelspec-")
os.makedirs(os.path.join(spec, "kernels", "scrip-probe"))
json.dump({"argv": [scrip, "--kernel", "{connection_file}"], "display_name": "SCRIP probe", "language": "scrip"}, open(os.path.join(spec, "kernels", "scrip-probe", "kernel.json"), "w"))
os.environ["JUPYTER_PATH"] = spec
from jupyter_client.manager import KernelManager
PAIRS = [
    ("snobol4", "        X = 'shared'\n", "        OUTPUT = X\n"),
    ("snocone", "%%snocone\nx = 'shared';\n", "%%snocone\nOUTPUT = x;\n"),
    ("rebus", "%%rebus\nfunction main()\n  sharedv := \"shared\"\nend\n", "%%rebus\nfunction main()\n  OUTPUT := sharedv\nend\n"),
    ("icon", "%%icon\nglobal sharedv;\nprocedure main();\n  sharedv := \"shared\";\nend\n", "%%icon\nglobal sharedv;\nprocedure main();\n  write(sharedv);\nend\n"),
    ("unicon", "%%unicon\nglobal sharedv;\nprocedure main();\n  sharedv := \"shared\";\nend\n", "%%unicon\nglobal sharedv;\nprocedure main();\n  write(sharedv);\nend\n"),
    ("prolog", "%%prolog\nsharedv(shared).\n", "%%prolog\n:- sharedv(X), write(X), nl.\n"),
    ("pascal", "%%pascal\nunit sharedu;\ninterface\nvar sharedv: string;\nimplementation\nbegin\n  sharedv := 'shared'\nend.\n", "%%pascal\nprogram p;\nuses sharedu;\nbegin\n  writeln(sharedv)\nend.\n"),
    ("raku", "%%raku\nour $sharedv = 'shared';\n", "%%raku\nsay $sharedv;\n"),
]
def run(kc, src):
    kc.execute(src); out = ""; err = ""
    while True:
        m = kc.get_iopub_msg(timeout=120); t = m["msg_type"]; c = m["content"]
        if t == "stream":
            if c["name"] == "stdout": out += c["text"]
            else: err += c["text"]
        elif t == "error": err += c.get("ename", "") + ": " + c.get("evalue", "")
        elif t == "status" and c["execution_state"] == "idle": return out, err
same = 0
for lang, a, b in PAIRS:
    km = KernelManager(kernel_name="scrip-probe"); km.start_kernel(); kc = km.client(); kc.start_channels()
    try:
        kc.wait_for_ready(timeout=60)
        o1, e1 = run(kc, a); o2, e2 = run(kc, b)
        ok = o2 == "shared\n" and not e1 and not e2
        same += ok
        print("JUPYTER_SESSION lang=%s %s second_stdout=%r stderr=%r" % (lang, "SAME" if ok else "DIFFERS", o2[:60], (e1 + e2).strip()[:160]))
    except Exception as x:
        print("JUPYTER_SESSION lang=%s DIFFERS exception=%r" % (lang, str(x)[:160]))
    finally:
        kc.stop_channels(); km.shutdown_kernel(now=True)
print("JUPYTER_SESSION_TOTAL same=%d of=%d" % (same, len(PAIRS)))
sys.stdout.flush(); os._exit(0)
PY
)"; local prc=$?
    printf '%s\n' "$out" | grep -q '^JUPYTER_SESSION_TOTAL ' || { echo "REFUSE(2): the session arm printed no total (rc $prc)"; printf '%s\n' "$out" | tail -3; return 2; }
    local tot; tot="$(printf '%s\n' "$out" | sed -n 's/^JUPYTER_SESSION_TOTAL //p')"
    echo "JUPYTER_SESSION_BOARD $tot (tree $TREE)"
    printf '%s\n' "$out" | grep '^JUPYTER_SESSION lang=' | sed 's/^/  /'
    case "$tot" in "same=8 of=8") return 0 ;; esac
    return 1
}
note_arm() {
    local out
    out="$(timeout -k 5 300 python3 - "$SCRIP_BIN" <<'PY'
import sys, os, json, tempfile
scrip = sys.argv[1]
spec = tempfile.mkdtemp(prefix="scrip-probe-kernelspec-")
os.makedirs(os.path.join(spec, "kernels", "scrip-probe"))
json.dump({"argv": [scrip, "--kernel", "{connection_file}"], "display_name": "SCRIP probe", "language": "scrip"}, open(os.path.join(spec, "kernels", "scrip-probe", "kernel.json"), "w"))
os.environ["JUPYTER_PATH"] = spec
from jupyter_client.manager import KernelManager
km = KernelManager(kernel_name="scrip-probe"); km.start_kernel(); kc = km.client(); kc.start_channels(); kc.wait_for_ready(timeout=60)
kc.execute("%%prolog\n:- initialization(main).\nmain :- write('Hello'), nl.\n"); out = ""; err = ""
while True:
    m = kc.get_iopub_msg(timeout=120); t = m["msg_type"]; c = m["content"]
    if t == "stream":
        if c["name"] == "stdout": out += c["text"]
        else: err += c["text"]
    elif t == "error": err += c.get("ename", "")
    elif t == "status" and c["execution_state"] == "idle": break
kc.stop_channels(); km.shutdown_kernel(now=True)
print("JUPYTER_NOTE_BOARD stdout=%r stderr=%r" % (out, err.strip()[:200]))
print("JUPYTER_NOTE " + ("SAME" if out == "Hello\n" and not err else "DIFFERS"))
sys.stdout.flush(); os._exit(0)
PY
)"
    printf '%s\n' "$out" | grep -q '^JUPYTER_NOTE ' || { echo "REFUSE(2): the note arm printed no verdict"; return 2; }
    printf '%s\n' "$out" | grep '^JUPYTER_NOTE_BOARD' | sed "s/\$/ (tree $TREE)/"
    printf '%s\n' "$out" | grep -q '^JUPYTER_NOTE SAME$'
}
if [ "$arm" = note ]; then note_arm; r=$?; [ "$r" = 2 ] && exit 2; [ "$r" = 1 ] && rc_all=1; fi
if [ "$arm" = lang ]; then notebooks_arm "$one"; r=$?; [ "$r" = 2 ] && exit 2; [ "$r" = 1 ] && rc_all=1; fi
if [ "$arm" = notebooks ] || [ "$arm" = all ]; then notebooks_arm; r=$?; [ "$r" = 2 ] && exit 2; [ "$r" = 1 ] && rc_all=1; fi
if [ "$arm" = session ] || [ "$arm" = all ]; then session_arm; r=$?; [ "$r" = 2 ] && exit 2; [ "$r" = 1 ] && rc_all=1; fi
[ "$rc_all" = 0 ] && { echo "GATE OK [s4e_probe_jupyter_every_language $arm]"; exit 0; }
echo "GATE FAIL [s4e_probe_jupyter_every_language $arm]"; exit 1
