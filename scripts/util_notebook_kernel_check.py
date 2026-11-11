#!/usr/bin/env python3
"""util_notebook_kernel_check.py -- ONE TOOL RUNS A NOTEBOOK THROUGH THE SCRIP KERNEL AND READS EACH CELL'S OUTPUT AGAINST THE OUTPUT SAVED IN IT
(the cio's design CIO-73 and CIO-77, the acceptance of a notebook is a Run All; written by the cto 2026-11-11 on the live session, CTO-592).

  util_notebook_kernel_check.py check NOTEBOOK...   run each notebook top down through scrip --kernel and compare cell by cell
  util_notebook_kernel_check.py --probe             the tool's own proof on a planted notebook

check: THE ONE KERNEL (Lon 2026-11-11: "there is only ONE kernel. Its name is SCRIP and handle all the languages.") is installed into scratch by the scrip binary
itself (SCRIP_BIN, else SCRIP/scrip of S4E_HOME; scrip --kernel-install), and a notebook that names any other kernel refuses; a deep copy of the notebook is run by
nbclient in the notebook's own folder with errors allowed. A code cell is SAME when the text of its stdout streams equals the saved cell's and the
run holds no stderr stream and no error output; else DIFFERS. One line a notebook:
  NOTEBOOK_KERNEL nb=NAME cells=N same=S differs=D first=K      (K the 1-based number of the first differing code cell, 0 when none)
and for the first differing cell its two texts and what else the run held, at most ten lines each.
rc 0 every notebook differs=0; rc 1 a notebook differs; rc 2 could not measure (no binary, no library, a notebook that does not parse, no kernel).
Nothing is written beside a notebook; the scratch lives under /tmp/s4e/<seat> and is removed."""
import copy, json, os, shutil, subprocess, sys, tempfile


def refuse(msg):
    print("REFUSE(2) [util_notebook_kernel_check]: " + msg)
    sys.exit(2)


def stdout_text(cell):
    return "".join("".join(o.get("text", "")) if isinstance(o.get("text", ""), list) else o.get("text", "") for o in cell.get("outputs", []) if o.get("output_type") == "stream" and o.get("name") == "stdout")


def other_text(cell):
    out = []
    for o in cell.get("outputs", []):
        if o.get("output_type") == "stream" and o.get("name") != "stdout":
            t = o.get("text", "")
            out.append("stderr: " + ("".join(t) if isinstance(t, list) else t).rstrip("\n"))
        elif o.get("output_type") == "error":
            out.append("error: %s: %s" % (o.get("ename"), o.get("evalue")))
    return out


def show(label, text):
    lines = text.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    print("  %s (%d line(s)):" % (label, len(lines)))
    for ln in lines[:10]:
        print("    | " + ln)


def check(paths, scrip, scratch):
    try:
        import nbformat
        from nbclient import NotebookClient
    except Exception as e:
        refuse("nbformat or nbclient is not importable (%s)" % e)
    worst = 0
    for path in paths:
        try:
            nb = nbformat.read(path, as_version=4)
        except Exception as e:
            refuse("%s does not parse as a notebook (%s)" % (path, e))
        name = nb.metadata.get("kernelspec", {}).get("name") or "scrip"
        spec = tempfile.mkdtemp(prefix="spec.", dir=scratch)
        inst = subprocess.run([scrip, "--kernel-install", os.path.join(spec, "kernels")], capture_output=True, text=True)
        if inst.returncode != 0: refuse("%s --kernel-install did not install the kernel (rc %d: %s)" % (scrip, inst.returncode, inst.stderr.strip()[:200]))
        if not os.path.exists(os.path.join(spec, "kernels", name, "kernel.json")):
            refuse("%s names the kernel %s and the install writes %s: there is ONE kernel, scrip (Lon 2026-11-11)" % (path, name, " ".join(sorted(os.listdir(os.path.join(spec, "kernels"))))))
        os.environ["JUPYTER_PATH"] = spec
        run = copy.deepcopy(nb)
        try:
            NotebookClient(run, kernel_name=name, timeout=120, allow_errors=True, resources={"metadata": {"path": os.path.dirname(os.path.abspath(path))}}).execute()
        except Exception as e:
            refuse("the kernel did not run %s (%s: %s)" % (path, type(e).__name__, str(e)[:300]))
        saved = [c for c in nb.cells if c.cell_type == "code"]
        ran = [c for c in run.cells if c.cell_type == "code"]
        same = differs = first = 0
        for i, (a, b) in enumerate(zip(saved, ran), 1):
            if stdout_text(a) == stdout_text(b) and not other_text(b):
                same += 1
            else:
                differs += 1
                first = first or i
        print("NOTEBOOK_KERNEL nb=%s cells=%d same=%d differs=%d first=%d" % (os.path.basename(path), len(saved), same, differs, first))
        if first:
            show("cell %d saved" % first, stdout_text(saved[first - 1]))
            show("cell %d through the kernel" % first, stdout_text(ran[first - 1]))
            for ln in other_text(ran[first - 1])[:10]:
                print("    ! " + ln)
            worst = 1
    return worst


def probe(scrip, scratch):
    import nbformat
    nb = nbformat.v4.new_notebook(metadata={"kernelspec": {"name": "scrip", "display_name": "SCRIP", "language": "scrip"}})
    for code, saved in (("        OUTPUT = 'one'\nEND\n", "one\n"), ("        OUTPUT = 'two'\nEND\n", "TWO\n")):
        c = nbformat.v4.new_code_cell(code)
        c.outputs = [nbformat.v4.new_output("stream", name="stdout", text=saved)]
        nb.cells.append(c)
    path = os.path.join(scratch, "probe.ipynb")
    nbformat.write(nb, path)
    import io, contextlib
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        rc = check([path], scrip, scratch)
    line = next((ln for ln in buf.getvalue().split("\n") if ln.startswith("NOTEBOOK_KERNEL ")), "")
    if rc == 1 and " cells=2 same=1 differs=1 first=2" in line:
        print("NOTEBOOK_KERNEL_PROBE same=1 differs=1")
        return 0
    print("NOTEBOOK_KERNEL_PROBE RED: read %r (rc %d)" % (line, rc))
    return 1


def main(argv):
    home = os.environ.get("S4E_HOME") or os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    scrip = os.environ.get("SCRIP_BIN") or os.path.join(home, "SCRIP", "scrip")
    if not (len(argv) >= 2 and (argv[1] == "--probe" or (argv[1] == "check" and len(argv) >= 3))):
        print("usage: util_notebook_kernel_check.py check NOTEBOOK... | --probe")
        return 2
    if not os.access(scrip, os.X_OK):
        refuse("no scrip binary at " + scrip)
    top = "/tmp/s4e/" + os.environ.get("S4E_SEAT", "probe")
    os.makedirs(top, exist_ok=True)
    scratch = tempfile.mkdtemp(prefix="nbkernel.", dir=top)
    try:
        return probe(scrip, scratch) if argv[1] == "--probe" else check(argv[2:], scrip, scratch)
    finally:
        shutil.rmtree(scratch, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
