#!/usr/bin/env bash
# s4e_probe_package_run_attrs.sh N -- THE PROBES of DESIGN-PLAN package-run-attrs (CIO-132, the cio 2026-11-11; cut by officer_05). Run from S4E_HOME.
# Arms 2 to 4 copy corpus/packages/icon/ipl to scratch and turn its NAME.pin, NAME.env, NAME.alone, NAME.pty, NAME.empty and NAME.head sidecars into the
# ALL.<kind> root files of CIO-132 (1) to (4), deleting the sidecars from the copy, so only the root files can answer; the live package is never written.
# rc 0 GREEN, rc 1 RED (naming what is red), rc 2 could not measure.
set -uo pipefail
N="${1:-}"; ROOT="$PWD"; . "$(dirname "${BASH_SOURCE[0]}")/lib_paths.sh"; PKG="$S4E_CORPUS/packages/icon/ipl"; H="$S4E_HARNESS/scripts"
refuse() { echo "REFUSE(2) [s4e_probe_package_run_attrs $N]: $*"; exit 2; }
red() { echo "RED [s4e_probe_package_run_attrs $N]: $*"; exit 1; }
green() { echo "GREEN [s4e_probe_package_run_attrs $N]: $*"; exit 0; }
[ -f "$PKG/ALL.csv" ] || refuse "no $PKG/ALL.csv (run from S4E_HOME)"
SC=""
plant() {
    SC="$(mktemp -d "${TMPDIR:-/tmp}/s4e_pra.XXXXXX")" || refuse "no scratch"
    trap 'rm -rf "$SC"' EXIT
    cp -r "$PKG/." "$SC/" || refuse "cannot copy $PKG"
    python3 -I - "$SC" <<'PYEOF' || refuse "cannot turn the sidecars into root files"
import sys, pathlib
d = pathlib.Path(sys.argv[1])
for kind in ("pin", "alone", "pty", "empty", "head", "env"):
    lines = []
    for f in sorted(d.rglob("*." + kind)):
        if not f.is_file():
            continue
        name = str(f.relative_to(d))[:-len(kind) - 1]
        body = [l.strip() for l in f.read_text(errors="replace").split("\n") if l.strip()]
        if kind == "env":
            lines += [name + "\t" + l for l in body if not l.startswith("#")]
        elif kind == "head":
            lines += [name + "\t" + next(l for l in body if l.isdigit())]
        else:
            lines.append(name + "\t" + " ".join(l.lstrip("#").strip() for l in body))
        f.unlink()
    if lines:
        (d / ("ALL." + kind)).write_text("\n".join(lines) + "\n")
PYEOF
}
case "$N" in
1)
    [ -f "$S4E_HARNESS/designs/package_run_attrs/STEPS.tsv" ] || red "no step table"
    out="$(bash "$H/test_design_package_run_attrs_steps.sh" --list 2>&1)" || red "the harness --list failed: $(printf '%s' "$out" | tail -1)"
    printf '%s' "$out" | grep -q '^DESIGN-PLAN: package-run-attrs -- 7 steps' || red "the harness does not list the seven steps"
    green "the step table, the harness and this probe stand" ;;
2)
    plant
    python3 -I - "$SC" "$H" <<'PYEOF'
import sys, shutil, pathlib
sc, hd = sys.argv[1], sys.argv[2]
sys.path.insert(0, hd)
import corpus_suite_harness as h
if not hasattr(h, "_pkg_read_run_attrs"):
    print("RED: corpus_suite_harness.py has no _pkg_read_run_attrs"); sys.exit(1)
es = {e.name: e for e in h.read_container_dir(sc, ".icn")}
d = pathlib.Path(sc)
def first(kind):
    for ln in (d / ("ALL." + kind)).read_text().split("\n"):
        c = ln.split("\t", 1)
        if len(c) == 2 and c[0] in es:
            return c
    print("REFUSE: no indexed entry in ALL." + kind); sys.exit(2)
bad = []
for kind in ("pin", "alone"):
    nm, why = first(kind)
    if getattr(es[nm], kind, None) != why:
        bad.append(f"{nm}.{kind} reads {getattr(es[nm], kind, None)!r}, ALL.{kind} says {why!r}")
nm, kv = first("env")
k, v = kv.split("=", 1)
if (k, v) not in (getattr(es[nm], "env", None) or []):
    bad.append(f"{nm}.env lacks {(k, v)!r}")
nm, n = first("head")
if getattr(es[nm], "head", None) != int(n):
    bad.append(f"{nm}.head reads {getattr(es[nm], 'head', None)!r}, ALL.head says {n}")
for kind, attr in (("fixtures", "fixtures_dir"), ("shims", "shims_dir")):
    hit = [p for p in sorted(d.rglob("*." + kind)) if p.is_dir() and str(p.relative_to(d))[:-len(kind) - 1] in es]
    if not hit:
        print("REFUSE: no indexed entry has a STEM." + kind + "/ folder"); sys.exit(2)
    nm = str(hit[0].relative_to(d))[:-len(kind) - 1]
    if getattr(es[nm], attr, None) != str(hit[0].resolve()):
        bad.append(f"{nm}.{attr} reads {getattr(es[nm], attr, None)!r}, the folder is {hit[0].resolve()}")
plain = next(e for e in es.values() if not any(getattr(e, a, None) for a in ("pin", "alone", "env", "head", "fixtures_dir", "shims_dir")))
if plain is None:
    bad.append("no entry reads without attributes")
omitted = sorted(h._pkg_omitted(sc))
if not omitted:
    print("REFUSE: the package omits nothing"); sys.exit(2)
pin = d / "ALL.pin"
keep = pin.read_text()
def refused(text, why):
    pin.write_text(keep + text)
    try:
        h.read_container_dir(sc, ".icn")
        bad.append("not refused: " + why)
    except ValueError:
        pass
    finally:
        pin.write_text(keep)
pin.write_text(keep + omitted[0] + "\tan omitted entry keeps its pin and the reader skips it\n")
try:
    h.read_container_dir(sc, ".icn")
except ValueError as x:
    bad.append(f"a line naming the omitted {omitted[0]} refused: {x}")
pin.write_text(keep)
refused("no/such/entry\tthis line names neither an index row nor an omit line\n", "a line naming no entry")
refused(plain.name + "\tshort\n", "a reason under 20 characters")
envf = d / "ALL.env"
ek = envf.read_text()
envf.write_text(ek + plain.name + "\tPATH=/tmp\n")
try:
    h.read_container_dir(sc, ".icn")
    bad.append("not refused: PATH in ALL.env")
except ValueError:
    pass
envf.write_text(ek)
if bad:
    print("RED: " + "; ".join(bad)); sys.exit(1)
print("GREEN: the reader puts pin, alone, env, head, fixtures_dir and shims_dir on the entries, skips an omitted line and refuses the three bad ones")
PYEOF
    rc=$?; [ "$rc" = 0 ] && green "the reader of CIO-132 (9) with the refusals of (2) and (7)"; [ "$rc" = 2 ] && refuse "see above"; red "see above" ;;
3)
    plant
    python3 -I - "$SC" "$H" <<'PYEOF'
import sys, os, inspect, tempfile, subprocess, pathlib
sc, hd = sys.argv[1], sys.argv[2]
sys.path.insert(0, hd)
import corpus_suite_harness as h
if not hasattr(h, "apply_run_attrs"):
    print("RED: corpus_suite_harness.py has no apply_run_attrs"); sys.exit(1)
if "apply_run_attrs(" not in inspect.getsource(h.run_suite_entry):
    print("RED: run_suite_entry (the per-process road) does not call apply_run_attrs"); sys.exit(1)
es = {e.name: e for e in h.read_container_dir(sc, ".icn")}
bad = []
for nm in ("progs/based", "progs/gftrace", "progs/filexref"):
    e = es.get(nm)
    if e is None or not getattr(e, "pin", None):
        print(f"REFUSE: {nm} is not a pinned entry of the copy"); sys.exit(2)
    with tempfile.TemporaryDirectory() as td:
        env, cwd = h.apply_run_attrs(e, td, dict(os.environ))
        host = subprocess.run(["hostname"], env=env, cwd=cwd, capture_output=True, text=True, timeout=30).stdout.strip()
        if host != "scriphost":
            bad.append(f"{nm}: hostname under the applier reads {host!r}, the pin shim answers 'scriphost'")
e = es["progs/filexref"]
with tempfile.TemporaryDirectory() as td:
    env, cwd = h.apply_run_attrs(e, td, dict(os.environ))
    for k, v in (e.env or []):
        if env.get(k) != v.replace("@RUNDIR", str(cwd)):
            bad.append(f"progs/filexref: {k} reads {env.get(k)!r}")
for nm in ("progs/gcomp",):
    e = es.get(nm)
    if e is None or not getattr(e, "alone", None):
        print(f"REFUSE: {nm} is not an alone entry of the copy"); sys.exit(2)
    with tempfile.TemporaryDirectory() as td:
        env, cwd = h.apply_run_attrs(e, td, dict(os.environ))
        have = sorted(os.listdir(cwd))
        want = sorted(os.listdir(e.fixtures_dir)) if getattr(e, "fixtures_dir", None) else []
        if have != want:
            bad.append(f"{nm}: the alone run directory holds {have}, its fixtures are {want}")
fx = next((e for e in es.values() if getattr(e, "fixtures_dir", None) and not getattr(e, "alone", None)), None)
if fx is None:
    print("REFUSE: no entry with fixtures and no alone"); sys.exit(2)
with tempfile.TemporaryDirectory() as td:
    env, cwd = h.apply_run_attrs(fx, td, dict(os.environ))
    miss = [n for n in os.listdir(fx.fixtures_dir) if not os.path.exists(os.path.join(cwd, n))]
    if miss:
        bad.append(f"{fx.name}: fixtures not staged: {miss}")
sh = next((e for e in es.values() if getattr(e, "shims_dir", None)), None)
if sh is None:
    print("REFUSE: no entry with shims"); sys.exit(2)
with tempfile.TemporaryDirectory() as td:
    env, cwd = h.apply_run_attrs(sh, td, dict(os.environ))
    first = env.get("PATH", "").split(":")[0]
    if not first or sorted(os.listdir(first)) != sorted(os.listdir(sh.shims_dir)) or first == sh.shims_dir:
        bad.append(f"{sh.name}: PATH does not start with a copy of its shims ({first!r})")
if bad:
    print("RED: " + "; ".join(bad)); sys.exit(1)
print("GREEN: the per-process road calls apply_run_attrs; the pin, env, alone, fixtures and shims apply")
PYEOF
    rc=$?; [ "$rc" = 0 ] && green "the applier of CIO-132 (9) on the per-process road"; [ "$rc" = 2 ] && refuse "see above"; red "see above" ;;
4)
    plant
    grep -q 'apply_run_attrs' "$H/util_build_package_suite.py" || red "util_build_package_suite.py does not call apply_run_attrs"
    timeout -k 5 600 python3 "$H/util_build_package_suite.py" "$SC" --lang icon --only progs/based,progs/filexref > "$SC.cut.log" 2>&1 || { tail -3 "$SC.cut.log"; rm -f "$SC.cut.log"; red "the builder's --only cut of progs/based,progs/filexref failed on the copy"; }
    rm -f "$SC.cut.log"
    python3 -I - "$SC" <<'PYEOF'
import sys, pathlib
t = (pathlib.Path(sys.argv[1]) / "ALL.ref").read_text(errors="replace")
bad = []
for nm in ("progs/based", "progs/filexref"):
    i = t.find("\n" + nm + "\n")
    j = t.find("\n#---", i + 1)
    body = t[i:j if j > 0 else len(t)]
    if i < 0:
        bad.append(nm + " has no answer in the re-cut ALL.ref")
    elif "2001" not in body or "November 9, 2026" in body:
        bad.append(nm + ": the oracle's answer was not cut under the pin (no 2001 date, the pin's PIN_EPOCH)")
if bad:
    print("RED: " + "; ".join(bad)); sys.exit(1)
PYEOF
    [ $? = 0 ] || red "see above"
    out="$(S4E_PROGRESS_DB="$(mktemp)" timeout -k 5 600 python3 "$H/corpus_suite_harness.py" run "$SC/ALL.icn" "$SC/ALL.ref" --lang icon --modes m3 --partition 'entry:progs/based' 2>&1)"
    printf '%s' "$out" | grep -q 'm3_n=1 m3_pass=1' || red "progs/based does not pass in mode 3 on the per-process road against the pinned cut"
    green "the builder's cut applies the pin to the oracle and progs/based passes against it" ;;
5)
    refuse "step 5 is the cto's row (the switch defers); its probe arm is written with that row" ;;
6)
    plant
    out="$(python3 "$H/util_package_layout_census.py" --package "$SC" --list 2>&1)" || true
    bad=""
    for k in pin alone env head; do
        printf '%s\n' "$out" | grep -qE "^INDEX[[:space:]]+ALL\.$k\$" || bad="$bad ALL.$k"
    done
    for f in "$SC"/*/*.fixtures "$SC"/*/*.shims; do
        [ -d "$f" ] || continue
        rel="${f#$SC/}"
        member="$(find "$f" -type f | head -1)"; [ -n "$member" ] || continue
        printf '%s\n' "$out" | grep -qE "^PART[[:space:]]+${member#$SC/}\$" || bad="$bad ${member#$SC/}"
    done
    [ -z "$bad" ] || red "the census does not read as INDEX or PART:$bad"
    green "the census reads the attribute files as INDEX and the beside folders as PART" ;;
7)
    [ -f "$H/util_package_run_attrs.py" ] || red "no harness/scripts/util_package_run_attrs.py"   # one-disk: not a path
    python3 "$H/util_package_run_attrs.py" --check "$PKG"; rc=$?
    case "$rc" in 0) green "no attribute sidecar stands and every deleted one has its fact at the root";; 2) refuse "the --check could not measure";; *) red "the --check names what is not moved";; esac ;;
*) refuse "usage: s4e_probe_package_run_attrs.sh 1-7" ;;
esac
