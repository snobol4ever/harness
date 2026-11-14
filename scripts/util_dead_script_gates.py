#!/usr/bin/env python3
"""util_dead_script_gates.py -- EVERY GATE THAT NAMES A SCRIPT GIT DELETED (the cio 2026-11-11, CIO-121; Lon 2026-11-10 22:1x CST in the cio's window,
verbatim: "let's finish the re-design and re-implementation of the automated grader and polished containers for each test suite."). The one unified
test suite system deleted 21 package runner scripts (harness cc278350, 2026-11-08) and left the gates that ran them: MEASURED 2026-11-11, of the 50
gates whose code named one, 6 read green, 17 red, 27 refused or did not finish. A gate that runs a script that is gone measures nothing.

usage: util_dead_script_gates.py [--check] [--list] | --gate NAME | --probe
A DELETED SCRIPT is a file name git records as deleted under S4E_HARNESS/scripts and that is on disk nowhere under S4E_HARNESS/scripts or S4E_GITHUB/scripts.
A gate NAMES it when the name stands in a line of the gate that is not a comment. A name a gate makes up for a scratch fixture was never in git and
is not counted.
  (no switch)  DEAD_SCRIPT_GATES gates=N naming_a_deleted_script=M deleted_scripts_named=K, rc 0
  --list       also one line a gate: the gate, a tab, the deleted scripts it names
  --check      rc 0 when M is 0, else rc 1 with the first twenty gates
  --gate NAME  rc 0 when the gate is on disk and names no deleted script, or when it is gone and RETIRED_GATES.tsv beside this tool holds its row
               (gate, date, successor gate or a dash, reason) with a reason; rc 1 otherwise, saying which
  --probe      a planted repository: one gate naming a deleted script (counted), one naming a fixture never in git (not counted), one retired with
               a row (rc 0) and one retired with none (rc 1); prints DEAD_SCRIPT_GATES_PROBE arms=4, rc 0; rc 1 naming the arm read otherwise
rc 2 refused: no git repository, no gate on disk. It reads; it writes nothing outside its own scratch directory."""
import os, re, shutil, subprocess, sys, tempfile

NAME = re.compile(r"\b[A-Za-z0-9_][A-Za-z0-9_.-]*\.(?:sh|py)\b")


def refuse(msg):
    print(f"REFUSE(2) [util_dead_script_gates]: {msg}")
    sys.exit(2)


def deleted_scripts(scripts):
    repo = subprocess.run(["git", "-C", scripts, "rev-parse", "--show-toplevel"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    if repo.returncode != 0:
        refuse(f"{scripts} is in no git repository")
    top = repo.stdout.strip()
    rel = os.path.relpath(scripts, top)
    log = subprocess.run(["git", "-C", top, "log", "--diff-filter=D", "--name-only", "--format=", "--", rel], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    if log.returncode != 0:
        refuse(f"git log failed in {top}")
    here = set(os.listdir(scripts))
    other = os.path.join(os.path.dirname(top), ".github", "scripts")
    if os.path.isdir(other):
        here |= set(os.listdir(other))
    gone = set()
    for ln in log.stdout.split("\n"):
        b = os.path.basename(ln.strip())
        if b and b not in here and NAME.fullmatch(b):
            gone.add(b)
    return gone


def census(scripts):
    gates = sorted(f for f in os.listdir(scripts) if f.startswith("test_gate_") and f.endswith(".sh"))
    if not gates:
        refuse(f"no test_gate_*.sh in {scripts}")
    gone = deleted_scripts(scripts)
    naming = {}
    for g in gates:
        with open(os.path.join(scripts, g), encoding="utf-8", errors="replace") as f:
            code = "\n".join(ln for ln in f.read().split("\n") if not ln.lstrip().startswith("#"))
        hit = sorted({m.group(0) for m in NAME.finditer(code)} & gone)
        if hit:
            naming[g[:-3]] = hit
    return gates, naming


def retired_rows(scripts):
    rows = {}
    p = os.path.join(scripts, "RETIRED_GATES.tsv")
    if os.path.isfile(p):
        with open(p, encoding="utf-8", errors="replace") as f:
            for ln in f:
                if ln.startswith("#") or not ln.strip():
                    continue
                c = ln.rstrip("\n").split("\t")
                if len(c) >= 4:
                    rows[c[0]] = c
    return rows


def gate_verdict(scripts, name):
    name = name[:-3] if name.endswith(".sh") else name
    if os.path.isfile(os.path.join(scripts, name + ".sh")):
        _, naming = census(scripts)
        if name in naming:
            return 1, f"{name} names a deleted script: {' '.join(naming[name])}"
        return 0, f"{name} is on disk and names no deleted script"
    row = retired_rows(scripts).get(name)
    if row and row[3].strip():
        return 0, f"{name} is retired: {row[3].strip()[:120]}"
    return 1, f"{name} is not on disk and RETIRED_GATES.tsv holds no row with a reason for it"


def probe():
    t = tempfile.mkdtemp(prefix="dead_script_gates_probe_", dir=os.environ.get("TMPDIR") or None)
    try:
        s = os.path.join(t, "harness", "scripts")
        os.makedirs(s)

        def git(*a):
            r = subprocess.run(["git", "-C", os.path.join(t, "harness"), "-c", "user.name=probe", "-c", "user.email=probe@invalid", "-c", "commit.gpgsign=false"] + list(a),
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            if r.returncode != 0:
                refuse(f"probe: git {' '.join(a)} failed: {r.stdout.strip()[:160]}")

        def put(n, text):
            with open(os.path.join(s, n), "w", encoding="utf-8") as f:
                f.write(text)

        git("init", "-q")
        put("test_old_suite.sh", "echo old\n")
        put("test_gate_a.sh", "# test_old_suite.sh in a comment is no name\nbash test_old_suite.sh\n")
        put("test_gate_b.sh", "bash test_made_up_fixture_suite.sh\n")
        put("test_gate_c.sh", "echo c\n")
        put("test_gate_d.sh", "echo d\n")
        git("add", "-A")
        git("commit", "-q", "-m", "one", "--no-verify")
        os.remove(os.path.join(s, "test_old_suite.sh"))
        os.remove(os.path.join(s, "test_gate_c.sh"))
        os.remove(os.path.join(s, "test_gate_d.sh"))
        put("RETIRED_GATES.tsv", "# gate\tdate\tsuccessor\treason\ntest_gate_c\t2026-11-11\t-\tits runner is deleted and nothing takes its place\n")
        git("add", "-A")
        git("commit", "-q", "-m", "two", "--no-verify")
        gates, naming = census(s)
        arms = [("a gate naming a deleted script is counted", naming.get("test_gate_a") == ["test_old_suite.sh"]),
                ("a made-up fixture name is not counted", "test_gate_b" not in naming and len(naming) == 1),
                ("a retired gate with a row reads rc 0", gate_verdict(s, "test_gate_c")[0] == 0),
                ("a retired gate with no row reads rc 1", gate_verdict(s, "test_gate_d")[0] == 1 and gate_verdict(s, "test_gate_a")[0] == 1)]
        bad = [n for n, ok in arms if not ok]
        if bad:
            print(f"DEAD_SCRIPT_GATES_PROBE RED: {bad[0]}")
            return 1
        print(f"DEAD_SCRIPT_GATES_PROBE arms={len(arms)}")
        return 0
    finally:
        shutil.rmtree(t, ignore_errors=True)


def main(argv):
    scripts = os.path.dirname(os.path.abspath(__file__))
    if "--probe" in argv:
        return probe()
    if "--gate" in argv:
        i = argv.index("--gate")
        if i + 1 >= len(argv):
            refuse("--gate needs a gate name")
        rc, why = gate_verdict(scripts, argv[i + 1])
        print(("GATE_OK " if rc == 0 else "GATE_DEAD ") + why)
        return rc
    unknown = [a for a in argv if a not in ("--check", "--list")]
    if unknown:
        refuse(f"usage: util_dead_script_gates.py [--check] [--list] | --gate NAME | --probe (read {unknown[0]!r})")
    gates, naming = census(scripts)
    named = sorted({n for v in naming.values() for n in v})
    if "--list" in argv:
        for g in sorted(naming):
            print(g + "\t" + " ".join(naming[g]))
    print(f"DEAD_SCRIPT_GATES gates={len(gates)} naming_a_deleted_script={len(naming)} deleted_scripts_named={len(named)}")
    if "--check" in argv and naming:
        for g in sorted(naming)[:20]:
            print(f"  DEAD {g}: {' '.join(naming[g])[:160]}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
