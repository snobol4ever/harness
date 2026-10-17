#!/usr/bin/env python3
"""util_gc_differential.py -- THE DIFFERENTIAL GC ORACLE: one program, N GC configurations, no .ref at all.

Row gc-the-differential-oracle-same-program-under-two-gc-configurations-must-agree (coo, 2026-09-21, MODE TENET).
From GCFuzz (differential testing across GC options) and CrossLangFuzzer.

THE PRINCIPLE. Garbage collection is SEMANTICALLY INVISIBLE. The same program on the same input must produce
byte-identical output under EVERY GC configuration. A divergence IS a defect, by definition, with NO oracle
required -- which turns every program in the corpus into a GC test in all seven languages without anyone
writing a witness.

⛔⭐ AND THE WHOLE DESIGN TURNS ON ONE HAZARD THAT WAS MEASURED BEFORE A LINE OF THIS FILE WAS WRITTEN.
A differential's pass condition is AGREEMENT, so a configuration that silently does not take produces a
PASS over a population of one. Measured on hb_bignum_length.icn, origin f7669a6a8, SCRIP_ZETA_TELEM=1:

    shipped                collections=0        SCRIP_GC_RELOC=1       collections=0
    SCRIP_GC_POISON=0      collections=0        SCRIP_GC_PLANT_SHIFT=65536  collections=0
    SCRIP_HEAP_MB=1        collections=1        SCRIP_GC_STRESS=3      collections=2598

FOUR OF SIX DECLARED CONFIGURATIONS COLLECT ZERO TIMES AND HAVE BYTE-IDENTICAL (EMPTY) EVENT FINGERPRINTS.
RELOC, POISON and PLANT_SHIFT are MODIFIERS OF A COLLECTION, not independent axes: with nothing forcing a
collection at the shipped arena they collapse onto the baseline exactly, and a six-row md5 table over them
reads "six configurations agree" while measuring one. The cto measured the same class from the other side the
same afternoon (SCRIP_GC_PLANT_SHIFT=1048576 applying ZERO times, rc=0, byte-identical stdout; cured at SCRIP
1b317bea3 so a declined plant now names itself). THEREFORE EVERY CONFIGURATION IS COMPOSED WITH A COLLECTING
AXIS, AND NO CONFIGURATION IS ACCEPTED ON ITS DECLARATION: each must be PROVEN DISTINCT in the collector's own
printed events before its output is compared, and one that cannot be is UNDISTINGUISHED (rc=2), never a pass.

⛔ THE DISTINCTNESS VERDICT IS A PROPERTY OF THE FINGERPRINT'S VOCABULARY, which is the second trap and it
bit the first draft. SCRIP_HEAP_MB=1 SCRIP_GC_POISON=0 has a move fingerprint IDENTICAL to SCRIP_HEAP_MB=1 --
poison changes what is written to VACATED ground, not what moves -- so a fingerprint built from the move
columns alone calls a genuinely distinct configuration undistinguished and throws away a real axis. The
fingerprint is therefore taken over EVERY collector line tag: [ZGC-POISON] is absent under POISON=0 and
present under the default, and that absence is the distinction. A fingerprint too narrow discards real
configurations; too wide (addresses, timings) makes every run of ONE configuration look distinct and the
determinism pre-pass collapses. Both directions are gate arms.

⛔ A DIVERGENCE IS NEVER REPORTED ON ONE READING. When two configurations disagree, BOTH are re-run and each
must prove SELF-STABLE before the divergence is reported; a side that differs from itself makes the program
EXCLUDED-NONDETERMINISTIC instead. So the common case costs one extra run (the reference config, twice) and
rigour is spent exactly where a defect is claimed.

⛔ WHY rc=2 AND NOT rc=1 ON A DIVERGENCE. The question this harness answers for a caller is "what is this
program's output?" If two GC configurations disagree there IS NO SINGLE OUTPUT, so the harness genuinely
CANNOT MEASURE and must refuse rather than hand a board one of the two answers. A caller that grades against
a .ref would otherwise pick whichever configuration it happened to run. The DEFECT is reported by name in the
text and by the gate's ratchet; the rc reports measurability, per RULES.md THE INSTRUMENT LAWS.

⛔ THE POPULATION EXCLUDES A PROGRAM THAT READS THE GC CONFIGURATION, because such a program diverges
legitimately and is not evidence about the collector. Measured 2026-09-21: no program in corpus/tests or
../harness/scripts/gc_witnesses calls getenv on a SCRIP_GC_*/SCRIP_HEAP_MB name (three witnesses MENTION a knob in a
comment, which is not a read). The check is kept because the day one appears it must be named, not graded.

⛔ SPELLING IS HELD CONSTANT AND THAT IS LOAD-BEARING (COO-127): the source path is itself a heap block, so
its length shifts every block after it, and one witness reaches interior=1 as ../harness/scripts/x and interior=0 as
./scripts/x. Every configuration of one program is therefore invoked with the IDENTICAL path string; the
differential is immune to that variable only because it never varies it, and it is stamped on the report line.

VERDICTS, one per program, and the identity is printed:
    AGREE                        >=2 distinct configurations, byte-identical stdout and rc. The only pass.
    DIVERGE                      >=2 distinct configurations, outputs differ. Both sides proven self-stable.
    NO-COLLECTION                no configuration collected -- the program carries NO GC evidence at all.
    UNDISTINGUISHED              collections happened but <2 distinct fingerprints -- nothing to compare.
    EXCLUDED-NONDETERMINISTIC    differs from ITSELF under one configuration. Named, never silently dropped.
    EXCLUDED-READS-GC-CONFIG     reads a GC knob, so it diverges by its own design.
    UNMEASURED                   a configuration timed out or could not run; the reason is named.
    AGREE + DIVERGE + NO-COLLECTION + UNDISTINGUISHED + EXCLUDED-* + UNMEASURED == population
"""

import argparse
import hashlib
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "SCRIP")

# Collector telemetry tags. SCRIP_ZETA_TELEM=1 is held constant across every configuration, so it is not a
# variable of the differential; arm "telemetry does not change the answer" in the gate proves that.
TAG_RE = re.compile(rb"^\[(?:ZGC|GC|ZHP)[A-Z0-9_-]*\]")

# Normalization: addresses and timings vary run to run under ASLR and load; counts do not. Validated by the
# stability arm -- three runs of one configuration give three different RAW fingerprints and one normalized one.
NORM = (
    (re.compile(rb"0x[0-9a-fA-F]+"), b"@"),
    (re.compile(rb"\b[0-9]+us\b"), b"Tus"),
    (re.compile(rb"arena\+[0-9]+"), b"arena+@"),
    (re.compile(rb"\b(?:0x)?[0-9a-f]{8,}\b"), b"@"),
)


FIELD_RE = re.compile(rb"([A-Za-z][A-Za-z0-9_-]*)=([0-9]+)")


def collector_lines(err: bytes):
    out = []
    for ln in err.splitlines():
        if not TAG_RE.match(ln):
            continue
        for rx, rep in NORM:
            ln = rx.sub(rep, ln)
        out.append(ln)
    return out


def field_values(err: bytes):
    """{field name -> multiset of its values} over every collector line, for the noise calibration."""
    vals = {}
    for ln in collector_lines(err):
        for m in FIELD_RE.finditer(ln):
            vals.setdefault(m.group(1), []).append(m.group(2))
    return vals


def noise_mask(errs):
    """⛔ THE INSTRUMENT MEASURES ITS OWN NOISE FLOOR INSTEAD OF ASSUMING ONE.

    Hand-normalizing addresses and timings is a GUESS about which fields are stable, and the guess was wrong:
    24 runs of hb_bignum_length.icn at one tree, one configuration and one path spelling gave TWO distinct
    normalized fingerprints, 16 and 8, differing in exactly one field -- slots=600 vs slots=601 (g_gc_nslot,
    the root slots the collector fixed up), with nblk, pmap-gran, moved, unmoved, marked, forwarded,
    wl_depth_max and interior byte-identical. An unstable field makes TWO IDENTICAL CONFIGURATIONS look
    DISTINCT, which is this row's vacuous-green hazard arriving through the back door: the twin-configuration
    arm passed as AGREEMENT until this mask existed.

    So the noisy fields are DERIVED from repeated runs of the reference configuration and then EXCLUDED from
    the distinctness fingerprint and NAMED in the report. Masking is the conservative direction -- a field
    that is the only difference between two configurations makes them UNDISTINGUISHED (a refusal) rather than
    falsely distinct -- and naming them keeps that visible instead of silent.
    """
    if len(errs) < 2:
        return set()
    seen = [field_values(e) for e in errs]
    names = set()
    for d in seen:
        names |= set(d.keys())
    noisy = set()
    for n in names:
        ref = seen[0].get(n)
        for d in seen[1:]:
            if d.get(n) != ref:
                noisy.add(n)
                break
    return noisy


def norm_fingerprint(err: bytes, mask=frozenset()):
    """(n_collections, normalized-md5) over every collector line, with the measured noisy fields blanked."""
    lines = []
    ncol = 0
    for ln in collector_lines(err):
        if ln.startswith(b"[ZGC-WALK] arm="):
            ncol += 1
        if mask:
            def blank(m):
                return m.group(1) + b"=~" if m.group(1) in mask else m.group(0)
            ln = FIELD_RE.sub(blank, ln)
        lines.append(ln)
    h = hashlib.md5(b"\n".join(lines)).hexdigest()[:12]
    return ncol, h


def load_configs(path):
    """name <TAB> env assignments <TAB> note. Blank lines and # comments ignored."""
    out = []
    with open(path, "r", encoding="utf-8") as fh:
        for raw in fh:
            s = raw.strip()
            if not s or s.startswith("#"):
                continue
            parts = raw.rstrip("\n").split("\t")
            if len(parts) < 2:
                continue
            name = parts[0].strip()
            envs = {}
            for tok in parts[1].split():
                if "=" in tok:
                    k, v = tok.split("=", 1)
                    envs[k] = v
            out.append((name, envs, parts[2].strip() if len(parts) > 2 else ""))
    return out


def run_one(prog, envs, timeout, telem=True):
    """One run. Returns (rc, stdout, stderr, status) where status is 'ok' | 'timeout' | 'error:<why>'."""
    env = dict(os.environ)
    # A stale knob inherited from the caller's shell would silently join every configuration and make the
    # whole matrix one configuration wearing N names -- the header's hazard arriving through the environment.
    # ⛔ THE AXIS PREDICATE IS SOURCED, NOT SPELLED AGAIN (coo 2026-09-21): util_progress_append.gc_axis_env is
    # its one home, because the set of knobs that make a run "not the shipped configuration" must be the SAME set
    # the progress database refuses to record a row without. Two copies drift and then a run is a configuration
    # to one instrument and shipped to the other. SCRIP_ZETA_TELEM is stripped here as well -- it is this tool's
    # own instrument switch, not an axis of the collector.
    import util_progress_append as _pa
    for k in list(env):
        if k in _pa.gc_axis_env(env) or k == "SCRIP_ZETA_TELEM":
            del env[k]
    env.update(envs)
    if telem:
        env["SCRIP_ZETA_TELEM"] = "1"
    try:
        p = subprocess.run(
            [os.path.join(ROOT, "scrip"), prog],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
            env=env,
            cwd=ROOT,
        )
        return p.returncode, p.stdout, p.stderr, "ok"
    except subprocess.TimeoutExpired:
        return None, b"", b"", "timeout"
    except OSError as e:
        return None, b"", b"", "error:%s" % e


def first_diff(a: bytes, b: bytes):
    """(offset, byte-a, byte-b) of the first differing byte, with a readable rendering."""
    n = min(len(a), len(b))
    for i in range(n):
        if a[i] != b[i]:
            return i, a[i : i + 1], b[i : i + 1]
    if len(a) != len(b):
        longer = a if len(a) > len(b) else b
        return n, (a[n : n + 1] or b"<end>"), (b[n : n + 1] or b"<end>")
    return -1, b"", b""


def show(bs: bytes):
    if bs in (b"<end>", b""):
        return "<end-of-output>"
    c = bs.decode("latin-1")
    return "0x%02x %r" % (bs[0], c)


def reads_gc_config(prog):
    """A program that reads a GC knob diverges by its own design. A comment mentioning one does not count."""
    try:
        with open(prog, "rb") as fh:
            src = fh.read()
    except OSError:
        return False
    for m in re.finditer(rb"getenv\s*\(\s*[\"']([A-Za-z0-9_]+)", src):
        n = m.group(1)
        if n.startswith(b"SCRIP_GC") or n == b"SCRIP_HEAP_MB":
            return True
    return False


def grade_program(prog, configs, timeout, plant=None, calib=3):
    """One program through the whole ladder. Returns a record dict; NAMES everything it declines to grade."""
    rec = {"prog": prog, "verdict": None, "why": "", "distinct": 0, "collections": {}, "unmeasured": []}

    if reads_gc_config(prog):
        rec["verdict"] = "EXCLUDED-READS-GC-CONFIG"
        rec["why"] = "calls getenv on a GC knob, so its output depends on the configuration by design"
        return rec

    # ⛔ TWO ROADS TO UNDISTINGUISHED, AND NEITHER REPLACES THE OTHER.
    # (1) BY DECLARATION, decided with CERTAINTY and before a single run: two rows with the same environment
    #     ARE one configuration, whatever they are named. (2) BY EFFECT, decided from the collector's printed
    #     events below: different declarations that collapse to the same behaviour. Road 1 exists because
    #     road 2 rests on the noise mask, and a mask derived from a FINITE number of calibration runs catches
    #     a field that varies often and can miss one that varies rarely -- the measured example being
    #     slots=600/601 at roughly one run in three. Leaving the certain case to the probabilistic road would
    #     make the twin check FLAKY, and a flaky arm in a blocking set is worse than no arm.
    seen_env = {}
    for name, envs, _n in configs:
        key = tuple(sorted(envs.items()))
        seen_env.setdefault(key, []).append(name)
    dupes = [v for v in seen_env.values() if len(v) > 1]
    if dupes and len(seen_env) < 2:
        rec["verdict"] = "UNDISTINGUISHED"
        rec["why"] = (
            "every declared configuration has the SAME environment -- %s are one configuration under several "
            "names, decided by declaration before any run, so they collapsed onto each other and there is no "
            "differential to run; nothing here is agreement" % "; ".join(", ".join(v) for v in dupes)
        )
        return rec

    ref_name, ref_envs = configs[0][0], configs[0][1]

    # ---- determinism pre-pass: the reference configuration TWICE. A program that differs from itself is
    # excluded and NAMED -- never silently dropped, because a silent drop is how a nondeterministic program
    # becomes a permanent false divergence.
    rc1, o1, e1, s1 = run_one(prog, ref_envs, timeout)
    if s1 != "ok":
        rec["verdict"] = "UNMEASURED"
        rec["why"] = "reference configuration %s: %s" % (ref_name, s1)
        rec["unmeasured"].append(ref_name)
        return rec
    rc2, o2, e2, s2 = run_one(prog, ref_envs, timeout)
    if s2 != "ok":
        rec["verdict"] = "UNMEASURED"
        rec["why"] = "reference configuration %s second run: %s" % (ref_name, s2)
        rec["unmeasured"].append(ref_name)
        return rec
    # ⛔ A PROGRAM THAT NEVER RAN MAKES NO CLAIM ABOUT THE COLLECTOR, and it is invisible to every check above
    # it: a file the frontend REFUSES prints the same parse error on every run, so it sails through the
    # determinism pre-pass and would land in NO-COLLECTION -- which asserts "this program ran and never
    # collected", a statement about the collector that nothing measured. Found by this instrument's own arm-4
    # fixture failing to compile (missing semicolons) and reading as a clean NO-COLLECTION.
    if rc1 != 0 and norm_fingerprint(e1)[0] == 0:
        why = ""
        for ln in e1.splitlines():
            if not TAG_RE.match(ln):
                why = ln.decode("latin-1", "replace")[:160]
                break
        rec["verdict"] = "UNMEASURED"
        rec["why"] = (
            "the reference configuration %s exited rc=%s with ZERO collections -- the program did not run, so "
            "it is not evidence about the collector and must not read as NO-COLLECTION. First non-collector "
            "stderr line: %s" % (ref_name, rc1, why or "<none>")
        )
        rec["unmeasured"].append("%s(rc=%s,did-not-run)" % (ref_name, rc1))
        return rec

    # ---- noise calibration: a THIRD reference run, so the noisy-field set is measured from three readings
    # rather than two (two readings cannot tell a stable field from one that happened to repeat).
    errs = [e1, e2]
    rc3, o3, e3, s3 = (rc1, o1, e1, "ok")
    for _k in range(max(0, calib - 2)):
        rc3, o3, e3, s3 = run_one(prog, ref_envs, timeout)
        if s3 != "ok":
            break
        errs.append(e3)
    if s3 == "ok":
        rec["mask"] = noise_mask(errs)
        if (rc3, o3) != (rc1, o1):
            off, ba, bb = first_diff(o1, o3)
            rec["verdict"] = "EXCLUDED-NONDETERMINISTIC"
            rec["why"] = (
                "differs from ITSELF under %s on the third reference run (rc %s vs %s, first differing byte at "
                "offset %d: %s vs %s)" % (ref_name, rc1, rc3, off, show(ba), show(bb))
            )
            return rec
    else:
        rec["mask"] = noise_mask(errs)

    if (rc1, o1) != (rc2, o2):
        off, ba, bb = first_diff(o1, o2)
        rec["verdict"] = "EXCLUDED-NONDETERMINISTIC"
        rec["why"] = (
            "differs from ITSELF under %s (rc %s vs %s, first differing byte at offset %d: %s vs %s) -- "
            "nondeterministic for its own reasons, so no divergence across configurations can be attributed "
            "to the collector" % (ref_name, rc1, rc2, off, show(ba), show(bb))
        )
        return rec

    # ---- run the matrix once per configuration, same path spelling, telemetry constant.
    runs = {}
    for name, envs, _note in configs:
        if name == ref_name:
            rc, out, err = rc1, o1, e1
        else:
            rc, out, err, st = run_one(prog, envs, timeout)
            if st != "ok":
                rec["unmeasured"].append("%s(%s)" % (name, st))
                continue
        ncol, fp = norm_fingerprint(err, rec.get("mask", frozenset()))
        if plant and plant.get("config") == name:
            out = out + plant.get("suffix", b"")
        runs[name] = {"rc": rc, "out": out, "ncol": ncol, "fp": fp}
        rec["collections"][name] = ncol

    if not runs:
        rec["verdict"] = "UNMEASURED"
        rec["why"] = "no configuration produced a run: " + ", ".join(rec["unmeasured"])
        return rec

    if all(r["ncol"] == 0 for r in runs.values()):
        rec["verdict"] = "NO-COLLECTION"
        rec["why"] = (
            "not one of %d configurations collected even once, so this program carries NO evidence about the "
            "collector -- an agreement here would be a green over a population that never collected"
            % len(runs)
        )
        return rec

    # ---- distinctness: group by normalized fingerprint. A configuration whose collector events are
    # byte-identical to another's did not take, whatever it declared.
    groups = {}
    for name, r in runs.items():
        groups.setdefault(r["fp"], []).append(name)
    rec["distinct"] = len(groups)
    rec["groups"] = groups
    if len(groups) < 2:
        collapsed = sorted(next(iter(groups.values())))
        rec["verdict"] = "UNDISTINGUISHED"
        rec["why"] = (
            "%d configurations produced ONE collector-event fingerprint (%s) -- they collapsed onto each "
            "other and there is no differential to run; nothing here is agreement"
            % (len(collapsed), ", ".join(collapsed))
        )
        return rec

    # ---- the differential, over one representative of each distinct fingerprint group.
    reps = [sorted(v)[0] for v in groups.values()]
    reps.sort()
    base = reps[0]
    for other in reps[1:]:
        a, b = runs[base], runs[other]
        if a["rc"] == b["rc"] and a["out"] == b["out"]:
            continue
        # ---- a divergence is never reported on one reading: prove BOTH sides self-stable first.
        for nm in (base, other):
            envs = dict(next(c[1] for c in configs if c[0] == nm))
            rcx, ox, _ex, st = run_one(prog, envs, timeout)
            if st != "ok":
                rec["verdict"] = "UNMEASURED"
                rec["why"] = "confirming %s for a candidate divergence: %s" % (nm, st)
                return rec
            if plant and plant.get("config") == nm:
                ox = ox + plant.get("suffix", b"")
            if (rcx, ox) != (runs[nm]["rc"], runs[nm]["out"]):
                off, ba, bb = first_diff(runs[nm]["out"], ox)
                rec["verdict"] = "EXCLUDED-NONDETERMINISTIC"
                rec["why"] = (
                    "a candidate divergence %s vs %s did NOT survive confirmation: %s differs from itself on "
                    "re-run (rc %s vs %s, first differing byte %d: %s vs %s), so the divergence is the "
                    "program's own nondeterminism and is NOT reported against the collector"
                    % (base, other, nm, runs[nm]["rc"], rcx, off, show(ba), show(bb))
                )
                return rec
        off, ba, bb = first_diff(a["out"], b["out"])
        rec["verdict"] = "DIVERGE"
        rec["why"] = (
            "GC IS NOT SEMANTICALLY INVISIBLE HERE: %s and %s disagree. rc %s vs %s; lengths %d vs %d; FIRST "
            "DIFFERING BYTE AT OFFSET %d, %s vs %s. Collections %s=%d %s=%d. Both sides re-run and each "
            "reproduced its own answer, so this is the collector and not the program."
            % (base, other, a["rc"], b["rc"], len(a["out"]), len(b["out"]), off, show(ba), show(bb),
               base, a["ncol"], other, b["ncol"])
        )
        rec["pair"] = (base, other)
        return rec

    rec["verdict"] = "AGREE"
    rec["why"] = "byte-identical stdout and rc over %d DISTINCT collector-event fingerprints (%s)" % (
        len(groups),
        "; ".join("%s:%s" % (sorted(v)[0], runs[sorted(v)[0]]["ncol"]) for v in groups.values()),
    )
    return rec


def tree_stamp():
    try:
        h = subprocess.run(["git", "-C", ROOT, "rev-parse", "--short", "HEAD"],
                           stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=20)
        t = h.stdout.decode().strip() or "unknown"
        d = subprocess.run(["git", "-C", ROOT, "status", "--porcelain"],
                           stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=20)
        return t + ("-dirty" if d.stdout.strip() else "")
    except Exception:
        return "unknown"


def main():
    ap = argparse.ArgumentParser(description="differential GC oracle: N configurations must agree")
    ap.add_argument("programs", nargs="*", help="program files; default the declared pool")
    ap.add_argument("--configs", default=os.path.join(HERE, "gc_differential_configs.tsv"))
    ap.add_argument("--pool", default=os.path.join(HERE, "gc_witnesses"),
                    help="directory used when no programs are named")
    ap.add_argument("--ext", default=".sno,.icn,.pl,.spt,.sc,.pas,.reb,.raku")
    ap.add_argument("--limit", type=int, default=0, help="grade at most N programs (0 = all)")
    ap.add_argument("--timeout", type=int, default=90)
    ap.add_argument("--calibration-runs", type=int, default=3,
                    help="reference runs used to MEASURE the noisy-field mask. 3 catches a field that varies "
                         "often; a field varying rarely (slots=600/601 is roughly 1 run in 3) can be missed, "
                         "so this bounds the mask and not the collector -- raise it to tighten the floor")
    ap.add_argument("--tsv", default="", help="write a machine record here")
    ap.add_argument("--plant-divergence", default="",
                    help="SELF-TEST: name a config whose stdout gets a suffix, so the harness must catch it")
    ap.add_argument("--plant-suffix", default="PLANTED")
    args = ap.parse_args()

    if not os.path.exists(args.configs):
        print("⛔ REFUSE(2): no declared configuration file at %s -- the declaration IS the instrument's "
              "vocabulary and it may not be defaulted silently" % args.configs)
        return 2
    configs = load_configs(args.configs)
    if len(configs) < 2:
        print("⛔ REFUSE(2): %d configuration(s) declared in %s -- a differential needs at least two"
              % (len(configs), args.configs))
        return 2

    progs = list(args.programs)
    if not progs:
        exts = tuple(args.ext.split(","))
        if not os.path.isdir(args.pool):
            print("⛔ REFUSE(2): no program pool at %s" % args.pool)
            return 2
        for fn in sorted(os.listdir(args.pool)):
            if fn.endswith(exts):
                progs.append(os.path.join(args.pool, fn))
    if args.limit:
        progs = progs[: args.limit]
    if not progs:
        print("⛔ REFUSE(2): empty population -- measuring nothing may not read as agreement")
        return 2

    plant = None
    if args.plant_divergence:
        plant = {"config": args.plant_divergence, "suffix": args.plant_suffix.encode()}

    tree = tree_stamp()
    print("DIFFERENTIAL GC ORACLE -- tree %s -- %d programs x %d declared configurations -- no .ref, no oracle"
          % (tree, len(progs), len(configs)))
    print("  configurations: " + " | ".join("%s[%s]" % (n, " ".join("%s=%s" % kv for kv in e.items()) or "shipped")
                                            for n, e, _ in configs))
    if plant:
        print("  ⛔ SELF-TEST: a divergence is PLANTED in configuration %s (stdout suffix %r) -- this run must "
              "NOT be read as a measurement of the tree" % (args.plant_divergence, args.plant_suffix))
    print("")

    counts = {}
    recs = []
    noisy = set()
    for prog in progs:
        rec = grade_program(prog, configs, args.timeout, plant, args.calibration_runs)
        recs.append(rec)
        counts[rec["verdict"]] = counts.get(rec["verdict"], 0) + 1
        mark = {"AGREE": "  ok  ", "DIVERGE": "⛔DIVG", "NO-COLLECTION": " nocol",
                "UNDISTINGUISHED": " undst", "UNMEASURED": " unmsr"}.get(rec["verdict"], " excl ")
        print("%s %-22s %s" % (mark, rec["verdict"], os.path.basename(rec["prog"])))
        if rec["verdict"] != "AGREE":
            print("         %s" % rec["why"])
        else:
            print("         %s" % rec["why"])
        if rec["unmeasured"]:
            print("         UNMEASURED configurations named: %s" % ", ".join(rec["unmeasured"]))
        m = rec.get("mask") or set()
        if m:
            # NAMED, never silent: a masked field is one the collector reports differently on two identical
            # runs, so it cannot carry a distinctness verdict. Masking is conservative (it can only make two
            # configurations look MORE alike), and a reader must be able to see which fields went quiet.
            noisy.update(m)
            print("         noise-masked fields (varied across identical reference runs, excluded from the "
                  "distinctness fingerprint): %s" % ", ".join(sorted(x.decode() for x in m)))

    pop = len(progs)
    tot = sum(counts.values())
    print("")
    print("IDENTITY: " + " + ".join("%s=%d" % (k, counts[k]) for k in sorted(counts)) + " = %d, population %d %s"
          % (tot, pop, "OK" if tot == pop else "⛔ MISMATCH"))
    agree = counts.get("AGREE", 0)
    diverge = counts.get("DIVERGE", 0)
    graded = agree + diverge
    if noisy:
        print("NOISE FLOOR (measured, not assumed): %d collector field(s) varied across identical reference "
              "runs and are excluded from every distinctness verdict -- %s"
              % (len(noisy), ", ".join(sorted(x.decode() for x in noisy))))
    print("DIFFERENTIAL: tree=%s population=%d graded=%d agree=%d diverge=%d no_collection=%d "
          "undistinguished=%d excluded=%d unmeasured=%d spelling=as-given"
          % (tree, pop, graded, agree, diverge, counts.get("NO-COLLECTION", 0),
             counts.get("UNDISTINGUISHED", 0),
             sum(v for k, v in counts.items() if k.startswith("EXCLUDED")),
             counts.get("UNMEASURED", 0)))

    if args.tsv:
        with open(args.tsv, "w", encoding="utf-8") as fh:
            fh.write("# util_gc_differential.py tree=%s\n" % tree)
            fh.write("program\tverdict\tdistinct_fingerprints\twhy\n")
            for r in recs:
                fh.write("%s\t%s\t%d\t%s\n" % (os.path.basename(r["prog"]), r["verdict"], r["distinct"],
                                               r["why"].replace("\t", " ")))

    if tot != pop:
        print("⛔ REFUSE(2): the identity does not close, so this census is not trustworthy")
        return 2
    if diverge:
        print("⛔ REFUSE(2): %d program(s) DIVERGE across GC configurations. There is no single output for "
              "them, so this harness cannot tell a caller what they print -- that is a refusal to measure, "
              "and each divergence above is a DEFECT owed a row." % diverge)
        return 2
    if graded == 0:
        print("⛔ REFUSE(2): NOTHING WAS GRADED -- %d programs and not one yielded two distinct collector "
              "fingerprints. An empty differential must never read as agreement." % pop)
        return 2
    print("✅ %d program(s) agree across every distinct GC configuration; %d could not be graded and each is "
          "named above." % (agree, pop - graded))
    return 0


if __name__ == "__main__":
    sys.exit(main())
