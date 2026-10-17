#!/usr/bin/env python3
"""util_progress_append.py -- THE ONE WRITER OF THE PROGRESS DATABASE (Lon 2026-09-06 12:1x, in-chat to ceo, verbatim:
"So are you going to get your act together and enhance your database to allow for time based queries? Get it fixed.";
GOAL-CEO CEO-331; the RULE is /home/resources/progress/README.md, CEO-319: every suite run by any session APPENDS its
per-program rows in the same sitting it rewrites its SCORE.md cell -- a run that leaves the table untouched is a defect
of that run).

THE TABLE: /home/resources/progress/results.tsv, append-only, one row per (program, mode, run, CONFIGURATION):
    ts_utc  scrip  corpus  measurer  class  suite  lang  program  mode  outcome  secs  note  fingerprint  config
ts_utc is the RUN's own wall clock (UTC, second precision, no zone suffix -- the shape the replay rows already carry);
scrip/corpus are the short hashes of the trees graded; measurer is the seat identity derived from the root path by the
ONE map (util_score_row.derive_measurer -- never a fourth copy of the map); class is rungs | package | benchmark;
suite is the SUITES.tsv key for packages, <lang>-rungs for rung suites, <lang>-bench for benchmarks; outcome is one of
OUTCOMES, never a count; secs is the program's own seconds when the runner knows them, else 0; note is free text
(xfail marker, benchmark rates) and may be empty; fingerprint is the binary identity at the board's start.
⛔⭐ config is WHAT THE RUN EXERCISED -- `arena=1,stress=3`, or `shipped`, or `undeclared` when nobody said.
It is part of the ROW'S IDENTITY, not a qualifier: without it, (suite, program, mode) collapses every
configuration of one program into one cell and every reader resolves the collision BY ARRIVAL ORDER. Measured
on the live table 2026-09-21 before this column existed: 2934 duplicate (tree, corpus, suite, program, mode)
keys in one day, and 139 keys since 09-20 where ONE tree carries CONTRADICTORY outcomes -- raku-rungs
token_say_4 m3 reading both PASS and FAIL at the clean tree 5418432bb, impossible under a byte-for-byte oracle
diff unless something unrecorded changed. ⛔ THE WRITER GUESSES NOTHING: it refuses rc=2 to record a row that
declares no configuration while a GC axis is set in its own environment, and it never infers `shipped`.

THE CONTROL ARMS: S4E_PROGRESS_DB=<path> redirects the table (gates use a scratch file; the live table is never
touched by a gate); S4E_PROGRESS_OFF=1 records nothing and SAYS SO on stderr. There is no silent path: an unwritable
table is a loud refusal (ProgressUnwritable -> rc=2 from the CLI), never a swallowed exception.

LIBRARY:  from util_progress_append import append_rows; append_rows([{class,suite,lang,program,mode,outcome[,secs][,note][,config]}, ...])
CLI:      util_progress_append.py append --class C --suite S --lang L --program P --mode M --outcome O [--secs N] [--note T] [--config 'arena=1,stress=3']
          util_progress_append.py rows-tsv FILE            # bulk: class suite lang program mode outcome [secs [note [config]]] per line
          util_progress_append.py results-tsv --suite S --lang L FILE   # scorecard_snobol4.sh shape: suite program m3 m4 t3 t4 note
          util_progress_append.py triangulation --lang L FILE           # bench_triangulate_* shape: kernel engine a1 a2 ratio verdict ...
rc 0 = rows written (count printed) or S4E_PROGRESS_OFF · rc 2 = refused (unwritable table, malformed row, unreadable input)."""
import os, sys, csv, io, time, fcntl, subprocess, re, collections
COLUMNS = ["ts_utc", "scrip", "corpus", "measurer", "class", "suite", "lang", "program", "mode", "outcome", "secs", "note", "fingerprint", "config"]
# ⛔⭐ THE CONFIGURATION IS A COLUMN, NOT A TOKEN IN THE NOTE, AND THE COMMENT IN context() THAT ARGUED THE OTHER
# WAY IS RETRACTED IN PLACE BELOW (coo 2026-09-21, ceo rank 0 at CEO-1047/CEO-1050). That comment refused a
# fourteenth column because "readers all over the fleet split on a fixed column count" -- a reasonable fear that
# I MEASURED instead of inheriting, over all 32 fleet readers of this table: every positional reader reads `$10`
# (outcome) or asserts `NF>=10`, so a column APPENDED AT THE END moves nothing any of them reads. The hazard was
# never the count. It was the HEADER -- and it had already fired: `fingerprint` was added as column 13 on
# 2026-09-06 without migrating the live table's header, which has said TWELVE since the file was created, so
# every csv.DictReader in the fleet has been dropping the fingerprint into csv's unnamed restkey ever since.
# A column the header does not name is a column no reader can read. See migrate_header() below.
# ⛔ THE AXIS PREDICATE HAS ONE HOME AND THIS IS IT (util_gc_differential.py sources it rather than keeping the
# second copy it used to carry): SOURCE THE AUTHORITY, NEVER COPY IT.
# ⛔⭐ RT_OPT IS AN AXIS BECAUSE LON'S TWO-PASS ORDER MAKES IT ONE (CEO-1061/CEO-1063, 2026-09-21: the new
# collector at -O0, then the same collector at -O2, seven languages, README.md the deliverable). Those two passes
# run the SAME programs on the SAME trees against the SAME corpus, so without this the second pass lands on the
# first pass's key and the table resolves the pair BY ARRIVAL ORDER -- the exact loss the `config` column was cut
# to stop, repeated on the first workload to arrive after it. ⛔ IT IS LISTED HERE ONLY SO THAT SILENCE REFUSES:
# the writer still declares nothing on its own, because RT_OPT in a runner's environment says what that shell was
# going to build, NOT what the loaded out/libscrip_rt.so was actually built with -- and those differ the moment a
# caller exports the flag without rebuilding. The binary's own identity is the `fingerprint` column; this is the
# runner's STATEMENT about it, and a statement nobody made must not be invented (CEO-812 applied to the record).
# ⛔⭐⭐ SCRIP_HEAP_KB IS AN AXIS BECAUSE IT IS THE ARENA KNOB THAT WINS (coo 2026-09-22, the CEO-1146 arena sweep).
# rt_gcheap_init reads SCRIP_HEAP_MB at gc_heap.c:191 and SCRIP_HEAP_KB at :192, LAST WRITER WINS, so KB is the knob
# that decides the window -- and it was in NEITHER half of this predicate: it is not in this tuple, and GC_AXIS_PREFIX
# is "SCRIP_GC", which "SCRIP_HEAP_KB" does not start with.  MEASURED before the line was written:
# SCRIP_HEAP_KB=64 SCRIP_GC_STRESS=3 yielded {"SCRIP_GC_STRESS": "3"} -- A RUN AT A 64 KB ARENA DECLARING NO ARENA AT
# ALL.  ⛔ THE SWEEP IS WHAT MADE IT URGENT RATHER THAN MERELY WRONG: eighteen gates are moving OFF SCRIP_HEAP_MB=1
# and ONTO a KB pin in the same landing, so without this line the sweep would trade a WRONG arena (MB=1 is 1024 KB,
# eight times the shipped 128) for an INVISIBLE one, and the record would get worse while every number in it looked
# fine.  The second reader pays too: util_gc_differential.py strips exactly this set before every run so a stale knob
# from the caller's shell cannot join a configuration silently, and the knob it could not strip was the one that wins.
GC_AXIS_EXACT = ("SCRIP_HEAP_KB", "SCRIP_HEAP_MB", "RT_OPT")
GC_AXIS_PREFIX = "SCRIP_GC"
CONFIG_UNDECLARED = "undeclared"
# ⛔ THE MACHINE TOKEN FOR A DEVELOPMENT PASS.  A reader asking "was this a board pass?" greps the note for
# this prefix; a row without it is a board pass and IS expected to have a published suite row behind it.
DEVPASS_TOKEN = "dev-pass="
CLASSES = ("rungs", "package", "benchmark")
# ⭐ OOM (ceo CEO-1229 (2), 2026-09-23, verbatim: "THE PROGRESS WORD IS OOM: a run that ends in a properly reported out-of-memory at
# the heap it ran under, recorded with that heap. It is not PASS and it is not FAIL or CRASH"): the runtime's own report since SCRIP
# dc739c38a, classified by corpus_suite_harness._oom_verdict, the note carrying heap_cap_kb= (the cap the runtime named) and
# oom_error= (its error number). Not green: a PASS that becomes OOM is a loss to every reader of this table.
OUTCOMES = ("PASS", "FAIL", "CRASH", "HANG", "SKIP", "REFUSE", "UNGRADED", "UNPROVEN", "MISSING", "REJECT", "XFAIL", "XPASS",
            "DEFERRED", "OUTSIDE", "UNGRADABLE", "OOM")
DB_DEFAULT = "/home/resources/progress/results.tsv"
HERE = os.path.dirname(os.path.abspath(__file__))
S4E = os.environ.get("S4E_HOME") or os.path.abspath(os.path.join(HERE, "..", "..", "SCRIP", ".."))


class ProgressUnwritable(Exception):
    pass


def db_path():
    return os.environ.get("S4E_PROGRESS_DB") or DB_DEFAULT


def gc_axis_env(env=None):
    """The GC axis knobs SET IN THIS PROCESS'S ENVIRONMENT, as {name: value}, sorted. The ONE definition of
    "this run was not the shipped configuration" (util_gc_differential.py strips exactly this set before every
    run so a stale knob from the caller's shell cannot silently join a configuration)."""
    env = os.environ if env is None else env
    return {k: env[k] for k in sorted(env) if k.startswith(GC_AXIS_PREFIX) or k in GC_AXIS_EXACT}


def canonical_config(s):
    """`k=v,k=v` sorted by key, whitespace stripped. A declaration is a STATEMENT BY THE RUNNER about what it
    exercised, so this normalises spelling and NEVER invents a pair the caller did not write."""
    s = (s or "").strip()
    if not s or s == CONFIG_UNDECLARED:
        return ""
    parts = []
    for tok in s.replace(";", ",").split(","):
        tok = tok.strip()
        if not tok:
            continue
        if "=" in tok:
            k, v = tok.split("=", 1)
            parts.append(f"{k.strip()}={v.strip()}")
        else:
            parts.append(tok)          # a bare name like `shipped` is a legal whole-configuration label
    return ",".join(sorted(parts))


def read_header(path):
    """The table's own column names, or None when the table does not exist / is empty."""
    try:
        with open(path, encoding="utf-8", errors="replace", newline="") as f:
            line = f.readline()
    except OSError:
        return None
    line = line.rstrip("\n").rstrip("\r")
    return line.split("\t") if line else None


def migrate_header(path):
    """⛔⭐ A COLUMN THE HEADER DOES NOT NAME IS A COLUMN NO READER CAN READ. Called under the append lock.

    The live table has carried a TWELVE-column header since 2026-09-06 while the writer has emitted THIRTEEN
    fields since `fingerprint` landed the same day, so every csv.DictReader in the fleet has silently dropped
    that column into csv's unnamed restkey. This rewrites line 1 to name every column the writer writes.

    ⛔ IT MIGRATES ONLY A STRICT PREFIX. A header that is not a prefix of COLUMNS is a table this writer does
    not understand -- renamed or reordered columns -- and it REFUSES rather than guessing which column is which,
    because a wrong guess here relabels the whole history. Returns a one-line receipt, or "" when nothing to do.
    """
    hdr = read_header(path)
    if hdr is None or hdr == COLUMNS:
        return ""
    if hdr != COLUMNS[:len(hdr)]:
        raise ProgressUnwritable(
            f"the table's header is not a prefix of this writer's columns and WILL NOT BE GUESSED AT: header={hdr} "
            f"writer={COLUMNS}. A renamed or reordered column cannot be migrated without relabelling the whole history; "
            f"fix the table by hand or point S4E_PROGRESS_DB elsewhere.")
    tmp = path + ".hdrmigrate.tmp"
    n = 0
    with open(path, encoding="utf-8", errors="replace", newline="") as src, \
         open(tmp, "w", encoding="utf-8", newline="\n") as dst:
        src.readline()                                  # the stale header, replaced
        dst.write("\t".join(COLUMNS) + "\n")
        for line in src:
            n += 1
            dst.write(line)
        dst.flush()
        os.fsync(dst.fileno())
    os.replace(tmp, path)                               # atomic: a crash mid-migration leaves the original intact
    return (f"progress: HEADER MIGRATED in {path} -- {len(hdr)} columns -> {len(COLUMNS)} ({','.join(COLUMNS[len(hdr):])} "
            f"was written into every row but named by nothing, so every csv.DictReader dropped it); {n} data rows preserved")


def recording_off():
    return os.environ.get("S4E_PROGRESS_OFF", "") == "1"


def _git_short(repo):
    try:
        out = subprocess.run(["git", "-C", repo, "rev-parse", "--short", "HEAD"], capture_output=True, text=True, timeout=20)
        h = out.stdout.strip()
        if out.returncode == 0 and re.fullmatch(r"[0-9a-f]{7,}", h):
            dirty = subprocess.run(["git", "-C", repo, "status", "--porcelain", "--untracked-files=no"], capture_output=True, text=True, timeout=60)
            return h + ("-dirty" if dirty.stdout.strip() else "")
    except Exception:
        pass
    return "unknown"


_CTX = {}


def context():
    if _CTX:
        return _CTX
    _CTX["scrip"] = _git_short(os.path.join(S4E, "SCRIP"))
    _CTX["corpus"] = _git_short(os.path.join(S4E, "corpus"))
    # ⛔ S4E_SEAT WINS OVER THE ROOT PATH (coo 2026-09-16; hq_raku via the cfo: base-vs-head boards graded on two DETACHED WORKTREES
    # were attributed to root:base and root:head -- a pseudo-seat no LANES: line names -- so a batch audit keyed on measurer could not
    # see 1854 sound rows). The seat that set S4E_SEAT is the measurer; the path map is the fallback for a seat that set nothing.
    who = os.environ.get("S4E_SEAT", "").strip()
    if not who:
        try:
            sys.path.insert(0, HERE)
            import util_score_row  # noqa: E402  -- the ONE root->identity map; never a fourth copy
            who = util_score_row.derive_measurer() or ""
        except Exception:
            who = ""
    _CTX["measurer"] = who or ("root:" + os.path.basename(os.path.abspath(S4E).rstrip("/")))
    # ⛔⭐ A DEVELOPMENT PASS MUST SAY SO IN THE ROW, NOT ONLY IN THE RUNNER'S PRINTED OUTPUT (coo 2026-09-18,
    # the cfo's disclosure 1).  A seat that runs a suite under S4E_ONE_RUNNER_OVERRIDE is doing it correctly --
    # the override is loud, it is printed, and that seat writes no SCORE row.  But the ROW IT APPENDS is
    # indistinguishable from a board pass whose runner never published its suite row, and that second shape is
    # a defect a batch audit is supposed to convict.  So the qualifier travels WITH the row: derived once per
    # run from the environment exactly as `measurer` is, never passed by a caller who has to remember.
    # ⛔ WHY THE note COLUMN AND NOT A NEW ONE: results.tsv has ~360k rows and readers all over the fleet split
    # on a fixed column count.  A stable machine token inside free text is greppable and breaks nothing; a
    # fourteenth column would be a schema migration to record a qualifier.
    # ⛔ RETRACTED IN PLACE 2026-09-21 BY THE coo, for `config` and for this reasoning generally, on a
    # MEASUREMENT of the fear rather than on a preference: across all 32 fleet readers of this table every
    # positional one reads `$10` or asserts `NF>=10`, so a column APPENDED AT THE END moves nothing any of
    # them reads.  The count was never the hazard; the HEADER was, and it had already fired silently --
    # `fingerprint` (column 13, this same day) was never named by the live table's header, so every
    # csv.DictReader dropped it.  A qualifier that has to hide inside free text to avoid a migration is a
    # qualifier no reader can key on.  `devpass` stays in the note because it is genuinely free text about
    # the run; `config` is a KEY, and a key belongs in a column.  See COLUMNS and migrate_header().  The token is first in the note so
    # it survives truncation, and the human reason follows it.
    _CTX["devpass"] = _clean((os.environ.get("S4E_ONE_RUNNER_OVERRIDE", "") or os.environ.get("S4E_ONE_RUNNER_FIXTURE", "")).strip(), "devpass")
    return _CTX


class ProgressGroundMoved(Exception):
    pass


def _bin_digest(scrip_bin=None, rt_dir=None):
    """md5 over the DRIVER and the runtime it will load, in that order. ⛔ The driver alone is not the build:
    scrip is ~40 KB and every template lives in out/libscrip_rt.so, so a digest of scrip alone calls two
    different compilers the same build (measured 2026-09-05, hq_T and hq_C independently)."""
    import hashlib
    sb = scrip_bin or os.environ.get("SCRIP") or os.path.join(S4E, "SCRIP", "scrip")
    rd = rt_dir or os.environ.get("RT_DIR") or os.path.join(S4E, "SCRIP", "out")
    h = hashlib.md5()
    ok = 0
    for f in (sb, os.path.join(rd, "libscrip_rt.so")):
        try:
            with open(f, "rb") as fh:
                h.update(fh.read())
            ok += 1
        except Exception:
            return "unknown"
    return h.hexdigest() if ok == 2 else "unknown"


def _tree_of_binary(scrip_bin):
    """The SCRIP checkout a graded binary was built in: the git toplevel of the binary's own directory (a worktree's scrip lives in
    the worktree), or S4E_HOME/SCRIP when there is no binary path or it is in no checkout."""
    if scrip_bin:
        try:
            out = subprocess.run(["git", "-C", os.path.dirname(os.path.abspath(scrip_bin)), "rev-parse", "--show-toplevel"],
                                 capture_output=True, text=True, timeout=20)
            if out.returncode == 0 and out.stdout.strip():
                return out.stdout.strip()
        except Exception:
            pass
    return os.path.join(S4E, "SCRIP")


def _ground(scrip_bin=None, rt_dir=None):
    """⛔⭐ THE GROUND IS THE GRADED BINARY'S, NOT THE SEAT ROOT'S (the coo 2026-09-28, row instruments-util-progress-append-fingerprints-
    the-seat-roots-binary-not-the-one-the-harness-graded-...): the harness pins the digest of the binary it GRADES (a worktree's, or
    SCRIP=), and this used to re-read S4E_HOME/SCRIP/scrip at append time -- so every worktree run ended THE GROUND MOVED rc 2 after a
    green board, and a row's scrip stamp named the seat root's commit, a tree that never graded it. The tree hash is the graded binary's
    own checkout; the corpus stays S4E_HOME's (the population the run read)."""
    return {"scrip": _git_short(_tree_of_binary(scrip_bin) if scrip_bin else os.path.join(S4E, "SCRIP")),
            "corpus": _git_short(os.path.join(S4E, "corpus")), "fp": _bin_digest(scrip_bin, rt_dir)}


_PINNED = {}
_PINNED_BIN = {}


def pin_context(scrip_bin=None, rt_dir=None):
    """Read the tree hashes and the binary digest BEFORE the first program is graded, and make context() serve
    THOSE. ⛔ Without this, _git_short runs at APPEND time -- after a mid-run pull -- so rows name a tree the
    programs were never graded against (seat10, 3736 rows stamped 3377cf43e, CEO-338). The binary it names is remembered, so the
    append-time check re-reads THAT binary and THAT tree (assert_ground_unmoved)."""
    g = _ground(scrip_bin, rt_dir)
    _PINNED_BIN.clear()
    _PINNED_BIN.update({"scrip_bin": scrip_bin, "rt_dir": rt_dir})
    _PINNED.clear()
    _PINNED.update(g)
    _CTX.clear()
    context()
    _CTX["scrip"] = g["scrip"]
    _CTX["corpus"] = g["corpus"]
    _CTX["fingerprint"] = g["fp"]
    return dict(_PINNED)


def assert_ground_unmoved():
    """Refuse the whole append when the tree or the binary moved under the run. ⛔ APPEND NOTHING -- a refusal
    that fires after the side effect is an annotation, not a refusal."""
    if not _PINNED:
        return
    now = _ground(_PINNED_BIN.get("scrip_bin"), _PINNED_BIN.get("rt_dir"))
    moved = [k for k in ("scrip", "corpus", "fp") if _PINNED.get(k) != now.get(k)]
    if moved:
        what = ", ".join("%s %s -> %s" % (k, _PINNED.get(k), now.get(k)) for k in moved)
        raise ProgressGroundMoved(
            "⛔ THE GROUND MOVED UNDER THIS RUN (%s) -- appending NOTHING. The programs were graded against the "
            "PINNED values, so a row stamped with either set would be false: the pinned one denies the move, the "
            "current one names a tree that never graded them. Re-run on a settled tree." % what)


def _clean(v, field):
    s = "" if v is None else str(v)
    if "\t" in s or "\n" in s or "\r" in s:
        raise ValueError(f"{field} carries a tab or newline: {s!r}")
    return s


def normalize_row(r):
    out = {}
    out["class"] = _clean(r.get("class", ""), "class")
    if out["class"] not in CLASSES:
        raise ValueError(f"class must be one of {CLASSES}, not {out['class']!r}")
    for f in ("suite", "lang", "program"):
        out[f] = _clean(r.get(f, ""), f)
        if not out[f]:
            raise ValueError(f"{f} is empty")
    out["mode"] = _clean(r.get("mode", ""), "mode") or "m3"
    out["outcome"] = _clean(r.get("outcome", ""), "outcome").upper()
    if out["outcome"] not in OUTCOMES:
        raise ValueError(f"outcome must be one of {OUTCOMES}, not {out['outcome']!r} (program {out['program']})")
    secs = r.get("secs", 0)
    try:
        secs = float(secs) if secs not in ("", None) else 0.0
    except ValueError:
        raise ValueError(f"secs is not a number: {secs!r} (program {out['program']})")
    out["secs"] = ("%.3f" % secs).rstrip("0").rstrip(".") if secs else "0"
    out["note"] = _clean(r.get("note", ""), "note")
    # ⛔⭐ THE WRITER GUESSES NOTHING -- CEO-812'S PRINCIPLE APPLIED TO THE RECORD INSTEAD OF THE HEAP.
    # Three values and no fourth: what the runner DECLARED; `undeclared` when nobody said and nothing in this
    # process's environment contradicts it; and a REFUSAL in the one case where the writer holds positive
    # evidence that the run was NOT the shipped configuration and is being asked to record it as unknown.
    # It never writes `shipped` on its own inference: the runner may set the axis per-child, so an empty
    # environment here is an ABSENCE OF EVIDENCE about the child, not evidence of the shipped configuration.
    # Recording an unknown configuration as a known one is exactly the clean-bill-of-health shape.
    cfg = canonical_config(r.get("config", ""))
    if not cfg:
        axis = gc_axis_env()
        if axis:
            raise ValueError(
                "this row declares NO CONFIGURATION while a GC axis is set in the writer's own environment ("
                + " ".join(f"{k}={v}" for k, v in axis.items())
                + f") -- program {out['program']}. A run under a non-shipped arena or stress that records itself as "
                  "configuration-unknown is indistinguishable from a shipped-configuration board, and that collision is "
                  "resolved by ARRIVAL ORDER in every reader of this table. Declare it: --config 'arena=1,stress=3' "
                  "(library: config= in the row dict). If the axis in this environment is stale and the run really was "
                  "shipped-configuration, unset it or say so with --config shipped.")
        cfg = CONFIG_UNDECLARED
    # ⭐ rr=1: A READING OF THE coo's ROUND ROBIN (ceo CEO-1805, Lon 2026-10-15: "Basically the COO should run one test at a time and update the
    # test-suite database. Round robin, done and done."): under S4E_RR=1 every row carries rr=1 in its config, the token the loop row's DONE-WHEN
    # counts; like partition=, it is the shape of the run and never a configuration of the program (util_progress_flips.py drops both from its key).
    # and req=<seat>: a test a seat REQUESTED through ../harness/scripts/s4e_test_request.sh (ceo CEO-1806), served by the loop ahead of the round robin
    _req = re.sub(r"[^A-Za-z0-9_.-]", "", os.environ.get("S4E_REQ", ""))
    if _req and ("req=" + _req) not in cfg.split(","):
        cfg = canonical_config(cfg + ",req=" + _req)
    elif os.environ.get("S4E_RR") == "1" and "rr=1" not in cfg.split(","):
        cfg = canonical_config(cfg + ",rr=1")
    out["config"] = cfg
    return out


def bin_fingerprint():
    """lib_gate.sh's shape: md5 first 12 of ./scrip and out/libscrip_rt.so (resolved), space-joined; '' when either is missing."""
    import hashlib
    # the tree THIS FILE lives in, whose scrip the harness beside it grades by default -- never S4E_HOME/SCRIP, which in a worktree is a
    # different binary (the coo 2026-09-28: a rebuild of the graded binary went unseen and the seat root's was fingerprinted instead)
    tree = os.path.abspath(os.path.join(HERE, "..", "..", "SCRIP"))
    b = os.environ.get("SCRIP") or os.path.join(tree, "scrip")
    r = os.path.join(os.environ.get("RT_DIR") or os.path.join(tree, "out"), "libscrip_rt.so")
    out = []
    for f in (b, r):
        try:
            with open(f, "rb") as fh:
                out.append(hashlib.md5(fh.read()).hexdigest()[:12])
        except OSError:
            return ""
    return " ".join(out) + " "


def binary_moved_since_start():
    """(start, now) when S4E_BIN_AT_START is set and the binary differs from it, else None (coo 2026-09-16: a board whose seat
    rebuilt the compiler under it must record NOTHING -- its rows describe no single binary)."""
    start = os.environ.get("S4E_BIN_AT_START", "").strip()
    if not start:
        return None
    now = bin_fingerprint().strip()
    return None if now == start else (start, now)


def _attach_timeout_stamps(rows):
    """CEO-1335: util_timeout_retry.sh appends one line per retried timeout to $S4E_TIMEOUT_STAMP -- key TAB m3|m4|oracle TAB
    retried=1 load1=<first>/<second> nproc=<n> [timeout-twice]. Each stamp joins the note of the row it names (the key is the
    program, a prefix of it before ':' or '#' -- SWI's rows are <file>:<unit>:<case>, Logtalk's <group>:<name>#<n> -- or a file stem
    equal to the program's, from S4E_TIMEOUT_KEY or the argv; m3 to m3, m4 to m4, an oracle's to every mode), the file is
    consumed, and a stamp no row matches is said aloud on stderr, never dropped silently."""
    p = os.environ.get("S4E_TIMEOUT_STAMP", "")
    if not p or not os.path.isfile(p):
        return
    try:
        with open(p) as f:
            stamps = [ln.rstrip("\n").split("\t") for ln in f if ln.strip()]
        os.unlink(p)
    except OSError:
        return
    def stem(x):
        b = x.rsplit("/", 1)[-1]
        return b.rsplit(".", 1)[0] if "." in b else b
    for s in stamps:
        if len(s) < 3:
            continue
        keys = [k for k in s[0].split(",") if k]
        hit = False
        for r in rows:
            prog = r["program"]
            if not any(k == prog or prog.startswith(k + ":") or prog.startswith(k + "#") or stem(k) in (stem(prog), stem(prog) + "_driver") for k in keys):
                continue
            if s[1] != "oracle" and r["mode"] != s[1]:
                continue
            r["note"] = (r["note"] + " " if r["note"] else "") + s[2]
            hit = True
        if not hit:
            print("progress: a timeout retry stamp matched no row (key %s, %s): %s" % (s[0], s[1], s[2]), file=sys.stderr)


def append_rows(rows, db=None):
    moved = binary_moved_since_start()
    if moved:
        raise ProgressGroundMoved("⛔ THE BINARY MOVED UNDER THIS BOARD -- start [%s] end [%s] -- appending NOTHING. ./scrip or out/libscrip_rt.so "
                                  "was rebuilt while this board graded, so its rows describe no single binary. Re-run on a quiet tree." % moved)
    """Append the rows atomically under a lock. Returns the number written (0 under S4E_PROGRESS_OFF, said aloud)."""
    rows = [normalize_row(r) for r in rows]
    if not rows:
        return 0
    _attach_timeout_stamps(rows)
    if recording_off():
        print(f"progress: S4E_PROGRESS_OFF=1 -- {len(rows)} row(s) NOT recorded in {db or db_path()} (the control arm; a landing verdict never runs with it set)", file=sys.stderr)
        return 0
    path = db or db_path()
    assert_ground_unmoved()
    ctx = context()
    ts = time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime())
    lines = []
    for r in rows:
        note = r["note"]
        dev = ctx.get("devpass", "")
        if dev:
            note = DEVPASS_TOKEN + dev + (";" + note if note else "")
        lines.append("\t".join([ts, ctx["scrip"], ctx["corpus"], ctx["measurer"], r["class"], r["suite"], r["lang"], r["program"], r["mode"], r["outcome"], r["secs"], note, ctx.get("fingerprint", ""), r["config"]]))
    payload = "\n".join(lines) + "\n"
    try:
        d = os.path.dirname(path)
        if d and not os.path.isdir(d):
            raise ProgressUnwritable(f"directory does not exist: {d}")
        lock = path + ".lock"
        with open(lock, "a") as lk:
            fcntl.flock(lk.fileno(), fcntl.LOCK_EX)
            new = not os.path.exists(path) or os.path.getsize(path) == 0
            if not new:
                # ⛔ UNDER THE LOCK, BEFORE THE APPEND: an existing table whose header is shorter than this
                # writer's columns gets line 1 rewritten, once, atomically. Every other writer is blocked on
                # the same flock, so no row can be appended against the header being replaced.
                receipt = migrate_header(path)
                if receipt:
                    print(receipt, file=sys.stderr)
            if not new and os.path.exists(path + ".current"):
                # ⭐ THE CURRENT TABLE (Lon 2026-09-29, in-chat to the cto: "delete the entire file and just keep a
                # CURRENT TABLE. We are close enough to 100% now to do that."): once results.tsv.current marks the
                # table, it holds ONE row per (class, suite, lang, program, mode) -- the latest reading -- and a board
                # REPLACES the rows it re-measures instead of appending history. Rewritten whole under the same flock
                # through a temporary file and os.replace, so a reader sees the old table or the new, never half.
                # Without the marker this writer appends exactly as before: it never collapses history on its own.
                with open(path, encoding="utf-8", errors="replace") as f:
                    body = f.read().split("\n")
                hdr, rows_in = body[0], [l for l in body[1:] if l]
                last = {}
                for i, l in enumerate(rows_in):
                    last[tuple(l.split("\t")[4:9])] = i
                old_rows = [l for i, l in enumerate(rows_in) if last[tuple(l.split("\t")[4:9])] == i]
                at = {tuple(l.split("\t")[4:9]): i for i, l in enumerate(old_rows)}
                for l in lines:
                    k = tuple(l.split("\t")[4:9])
                    if k in at:
                        old_rows[at[k]] = l
                    else:
                        at[k] = len(old_rows)
                        old_rows.append(l)
                tmp = path + ".tmp"
                with open(tmp, "w", encoding="utf-8", newline="\n") as f:
                    f.write(hdr + "\n" + "\n".join(old_rows) + "\n")
                    f.flush()
                    os.fsync(f.fileno())
                os.replace(tmp, path)
            else:
                with open(path, "a", encoding="utf-8", newline="\n") as f:
                    if new:
                        f.write("\t".join(COLUMNS) + "\n")
                    f.write(payload)
                    f.flush()
                    os.fsync(f.fileno())
            fcntl.flock(lk.fileno(), fcntl.LOCK_UN)
    except (OSError, ProgressUnwritable) as e:
        msg = f"⛔ PROGRESS DATABASE UNWRITABLE ({path}): {e} -- {len(rows)} row(s) NOT recorded. A run that leaves the table untouched is a defect of that run (progress/README.md, CEO-319); fix the table or the permission, never the caller."
        print(msg, file=sys.stderr)
        raise ProgressUnwritable(msg)
    return len(rows)


SCORECARD_SUITE_KEYS = {"gimpel": "gimpel", "csnobol4": "csnobol4", "csnobol4_suite": "csnobol4", "snoflake": "snoflake", "snoflake_suite": "snoflake",
                        "aisnobol": "aisnobol", "dotnet": "dotnet", "testpgms": "testpgms", "spitbol_testpgms": "testpgms"}


def _driven_library(prog):
    """NAME_driver<ext> -> the library file it drives, as the package ships it (CEO-1269). The nominal NAME<ext> when that file ships;
    else the one shipped NAME.spt / NAME.inc / NAME.INC, and NAME_lib_driver drives NAME.inc when NAME ships twice -- gimpel is Catspaw's
    SPITBOL form under lower-case names since 2026-09-27 (Lon: "Use the *.inc names exclusively", CEO-1319, which keys every row by the
    library's own file and never by NAME.sno). A program that is not a driver is itself."""
    m = re.match(r"(.*)_driver(\.[A-Za-z0-9]+)$", prog)
    if not m:
        return prog
    stem, nominal = m.group(1), m.group(1) + m.group(2)
    # the corpus the run graded: a runner's overlay or fixture (CORPUS, as scorecard_snobol4.sh reads it) before the seat's own
    for base in [b for b in (os.environ.get("CORPUS"), os.path.join(S4E, "corpus")) if b]:
        if os.path.isfile(os.path.join(base, nominal)):
            return nominal
        for ext in (".spt", ".inc", ".INC"):
            if os.path.isfile(os.path.join(base, stem + ext)):
                return stem + ext
        if stem.endswith("_lib") and os.path.isfile(os.path.join(base, stem[:-4] + ".inc")):
            return stem[:-4] + ".inc"
    return nominal


def rows_from_results_tsv(path, suite, lang):
    """scorecard_snobol4.sh results.tsv: suite<TAB>program<TAB>m3<TAB>m4<TAB>t3<TAB>t4<TAB>note -- one row per mode.
    suite="auto" takes column 1 through SCORECARD_SUITE_KEYS and SKIPS (aloud) rows of a suite that is not in the table."""
    out = []
    skipped = collections.Counter()
    unknown = collections.Counter()
    for raw in io.open(path, encoding="utf-8", errors="replace"):
        raw = raw.rstrip("\n")
        if not raw or raw.startswith("#"):
            continue
        f = raw.split("\t")
        if len(f) < 4:
            continue
        # ⛔⭐ A DRIVER'S ROW IS ITS LIBRARY'S ROW (ceo CEO-1269; coo 2026-09-25): NAME_driver<ext> is the grading vehicle of the
        # library NAME<ext>, which is the program, so the verdict is recorded under the library's name. gimpel's 144 drivers were
        # recorded as packages/snobol4/gimpel/NAME_driver.sno, and the 148 libraries they grade appeared nowhere in this table.
        prog = _driven_library(f[1])
        row_suite = suite
        if suite == "auto":
            row_suite = SCORECARD_SUITE_KEYS.get(f[0].strip().lower(), "")
            if not row_suite:
                skipped[f[0]] += 1
                continue
        for mode, oi, ti in (("m3", 2, 4), ("m4", 3, 5)):
            o = f[oi].strip().upper()
            if o not in OUTCOMES:
                # ⛔⭐ DIFF ADDED, AND IT WAS SILENTLY EATING EVERY GIMPEL RED (coo 2026-09-08, found while trying to
                # classify gimpel's failures and discovering the progress table held NONE of them). scorecard_snobol4.sh
                # writes DIFF for an output mismatch -- which is what a correctness failure IS -- and DIFF was in
                # neither OUTCOMES nor this map, so the `continue` below dropped it. From 2026-09-06 the gimpel boards
                # appended PASS ROWS ONLY: 876, 2056 and 400 passes on three consecutive days and not one red, while the
                # suite row said 27 red. THE CENSUS THIS WHOLE OPERATION RUNS ON COULD NOT SEE A SINGLE GIMPEL FAILURE.
                # ORACLE_FAIL maps to UNGRADED, not dropped: the oracle refusing is a real outcome and belongs in the
                # table as one, not as an absence.
                _raw = o
                o = {"OK": "PASS", "TIMEOUT": "HANG", "SEGV": "CRASH", "NOREF": "UNGRADED", "-": "SKIP",
                     "DIFF": "FAIL", "ORACLE_FAIL": "UNGRADED"}.get(o, "")
                # ⛔ AND THE PATTERNED TOKENS, which are the rest of the same silence: scorecard_snobol4.sh reports a
                # non-zero exit as RC<n> and a signal death as SIG<n>, so the tokens are RC1, SIG6, SIG11 ... -- an
                # unbounded family no fixed map can hold. On the 2026-09-08 gimpel board these were 15 RC1 + 1 SIG6 +
                # 1 SIG11, which with the 10 DIFF is exactly the 27 failures the board reported and the table did not
                # hold. A CRASH is never collapsed into FAIL (the verdict ladder), so SIG maps to CRASH.
                if not o and re.fullmatch(r"RC\d+", _raw): o = "FAIL"
                if not o and re.fullmatch(r"SIG\d+", _raw): o = "CRASH"
                if not o:
                    # ⛔ AND AN UNKNOWN OUTCOME IS NOW SAID ALOUD, NEVER DROPPED IN SILENCE. This function already
                    # reports a skipped SUITE aloud; dropping an unknown OUTCOME without a word is the same defect one
                    # level down, and it is worse because the result looks like a clean board rather than a missing one.
                    unknown[f[oi].strip().upper()] += 1
                    continue
            secs = f[ti] if len(f) > ti else "0"
            try:
                secs = float(secs)
            except ValueError:
                secs = 0
            out.append({"class": "package", "suite": row_suite, "lang": lang, "program": prog, "mode": mode, "outcome": o, "secs": secs, "note": (f[6] if len(f) > 6 else "")})
    if unknown:
        print("⛔ progress: results-tsv DROPPED rows carrying an outcome token this writer does not know: "
              + ", ".join(f"{k}={v}" for k, v in sorted(unknown.items()))
              + " -- these programs are ABSENT from the table, which reads as 'never measured', not as 'passed'."
              + " Add the token to OUTCOMES or to the alias map in rows_from_results_tsv().", file=sys.stderr)
    if skipped:
        print("progress: results-tsv skipped rows of suite(s) not in the table: " + ", ".join(f"{k}={v}" for k, v in sorted(skipped.items())), file=sys.stderr)
    return out


def rows_from_triangulation(path, lang):
    """bench_triangulate_* TSV: kernel engine angle1_rate angle2_rate ratio verdict ... -- our engines only (m3, m4)."""
    out = []
    for raw in io.open(path, encoding="utf-8", errors="replace"):
        raw = raw.rstrip("\n")
        if not raw or raw.startswith("#") or raw.startswith("kernel\t"):
            continue
        f = raw.split("\t")
        if len(f) < 6:
            continue
        kernel, eng, a1, a2, ratio, verdict = f[0], f[1], f[2], f[3], f[4], f[5]
        if eng not in ("m3", "m4"):
            continue
        o = {"AGREE": "PASS", "DISAGREE": "FAIL", "CHECK-FAIL": "FAIL", "UNPROVEN": "UNPROVEN"}.get(verdict.strip().upper(), "UNPROVEN")
        out.append({"class": "benchmark", "suite": f"{lang}-bench", "lang": lang, "program": kernel, "mode": eng, "outcome": o, "secs": 0, "note": f"rate1={a1};rate2={a2};ratio={ratio};verdict={verdict}"})
    return out


def _main(argv):
    import argparse
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("append")
    for f in ("class", "suite", "lang", "program", "mode", "outcome"):
        a.add_argument("--" + f, required=True, dest=f)
    a.add_argument("--secs", default="0"); a.add_argument("--note", default="")
    a.add_argument("--config", default="", help="what this run EXERCISED: `arena=1,stress=3`, or `shipped`. Required when a GC axis is set in the environment -- the writer guesses nothing.")
    b = sub.add_parser("rows-tsv"); b.add_argument("file")
    c = sub.add_parser("results-tsv"); c.add_argument("--suite", required=True); c.add_argument("--lang", required=True); c.add_argument("file")
    d = sub.add_parser("triangulation"); d.add_argument("--lang", required=True); d.add_argument("file")
    ctxp = sub.add_parser("context")
    args = ap.parse_args(argv)
    try:
        if args.cmd == "context":
            print("\t".join(f"{k}={v}" for k, v in context().items()) + f"\tdb={db_path()}\toff={recording_off()}"); return 0
        if args.cmd == "append":
            rows = [{k: getattr(args, k) for k in ("class", "suite", "lang", "program", "mode", "outcome", "secs", "note", "config")}]
        elif args.cmd == "rows-tsv":
            rows = []
            for raw in io.open(args.file, encoding="utf-8", errors="replace"):
                raw = raw.rstrip("\n")
                if not raw or raw.startswith("#"):
                    continue
                f = raw.split("\t")
                if len(f) < 6:
                    raise ValueError(f"rows-tsv line needs class suite lang program mode outcome [secs [note]]: {raw!r}")
                rows.append({"class": f[0], "suite": f[1], "lang": f[2], "program": f[3], "mode": f[4], "outcome": f[5], "secs": f[6] if len(f) > 6 else 0, "note": f[7] if len(f) > 7 else "", "config": f[8] if len(f) > 8 else ""})
        elif args.cmd == "results-tsv":
            rows = rows_from_results_tsv(args.file, args.suite, args.lang)
        else:
            rows = rows_from_triangulation(args.file, args.lang)
        n = append_rows(rows)
        print(f"progress: {n} row(s) recorded in {db_path()}" if n else f"progress: 0 rows recorded ({'S4E_PROGRESS_OFF=1' if recording_off() else 'nothing to record'})")
        return 0
    except ProgressUnwritable:
        return 2
    except (OSError, ValueError) as e:
        print(f"⛔ PROGRESS APPEND REFUSES(2): {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(_main(sys.argv[1:]))
