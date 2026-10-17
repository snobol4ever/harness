#!/usr/bin/env python3
"""THE ONE COMPANION RESOLVER: which files does a rung suite-suite entry name, and where do they live.
AUTHORS: Lon Jones Cherryholmes · Claude Opus 5   DATE: 2026-09-05
⛔⭐⭐ WHAT THE GRADER CAN ACTUALLY REACH, WHICH IS WIDER THAN _copy_companions AND NARROWER THAN THE CORPUS. A suite entry
is graded in a FRESH temp dir, so it sees only what is copied in -- but the driver's include search is not just the file's own
directory. `src/driver/scrip.c:963-995` builds it per input file: the source's own dir, then EVERY colon-separated dir in
$SNO_LIB, then an UPWARD WALK of the source's ancestors adding each `<anc>/include`, `<anc>/lib`, `<anc>/library`, then ".".
And corpus_suite_harness sets `SNO_LIB=<corpus>/include` on every m3 run and every m4 compile (run_m3/compile_m4), for every
language. So `-INCLUDE 'global.inc'` DOES resolve at grading time even though global.inc is nowhere near the rungs.
⛔⭐⭐ THAT IS THE TRAP THIS FILE IS REALLY ABOUT, AND IT COST THIS SEAT A WRONG FINDING BEFORE IT COST ANYONE ELSE ANYTHING.
The two halves of the resolution live in different places -- one in an env var the harness sets, one in an upward walk that
only fires INSIDE the corpus tree -- so the SAME entry resolves under the board and fails under a hand run from /tmp with a
hard "cannot open include", which reads as a compiler defect. Measured twice in one fleet: two ALL.xfail notes written
2026-09-04 say a witness is "unresolved from the flat rungs" -- true of a hand run, false of the board that greens it -- and
this seat reproduced the identical mistake on 2026-09-05 and filed it as a 26-entry class before grading through
run_suite_entry and finding 23 of those 25 entries PASS.
⭐ SO THE QUESTION THIS LIBRARY ANSWERS IS NARROW AND WORTH ASKING: which named companions can the grader reach AT ALL, and
which exist in this corpus somewhere it cannot? The second set is the real defect class -- an entry graded against a
dependency that is simply absent -- and materializing those beside the rungs (tests/<lang>/config/, Lon's flat end state)
both cures it and makes the entry SELF-CONTAINED, so a hand run and the board finally agree.
⛔ THE PATH IS DECLARED, NEVER A CORPUS-WIDE BASENAME SCAN, and that is not fastidiousness -- it is measured. `VBGinTASA.dat`
resolves to THREE files in this corpus, and benchmarks/snocone/demo/VBGinTASA.dat is a DIFFERENT file (md5 48c78061) from the
two identical snobol4 ones (98e80802). A basename index would have picked one by walk order and graded a snobol4 entry
against another language's data with nothing in any output saying so.
⛔ AMBIGUITY REFUSES. Two declared dirs holding the same basename with different content is unresolvable BY THE CALLER, and
picking the first is exactly the silent wrong answer above. Identical content is not ambiguity -- first wins, no complaint.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
# ⛔ ONE EXTRACTOR, SOURCED NOT REIMPLEMENTED (RULES.md § shared authorities). `_companion_files` is the grader's OWN idea of
# what an entry names -- five patterns, each hardened by a real failure (the INPUT(...,'[-f0 -r4194304]') backtrack that ate a
# whole entry as a filename is in its comments). A second copy here could disagree with the grader about what a companion IS,
# and then this tool would materialize files the grader never asks for while missing ones it does.
import corpus_suite_harness as _csh

companion_names = _csh._companion_files

# ⛔ THE DEFAULT DECLARED PATH IS EMPTY, DELIBERATELY. `corpus/include/` is NOT here: it is what the harness points $SNO_LIB
# at, so it is already GRADER-REACHABLE (see GRADER_ENV_DIRS) and copying its 20 files beside the rungs would be churn
# justified by a premise that measurement retired. A dir belongs on this path only when the grader cannot reach it.
DEFAULT_PATH_DIRS = ()
# ⭐ THE DIRS THE HARNESS ITSELF PUTS ON THE COMPILER'S INCLUDE PATH, corpus-relative. Sourced from ONE place --
# corpus_suite_harness.resolve_paths()["inc"], which is what it assigns to SNO_LIB -- so this cannot drift from the grader.
GRADER_ENV_DIRS = ("include",)
PATH_DECL_BASENAME = "COMPANION_PATH"


def _read_path_decl(suite_dir):
    """Corpus-relative dirs declared in <suite_dir>/config/COMPANION_PATH, in order. Absent file -> DEFAULT_PATH_DIRS.
    One dir per line; blank lines and `#` comments ignored. A declaration file is how a language says its companions
    live somewhere this tool could not have guessed -- never a scan, never a heuristic."""
    decl = os.path.join(suite_dir, "config", PATH_DECL_BASENAME)
    if not os.path.isfile(decl):
        return list(DEFAULT_PATH_DIRS)
    out = []
    with open(decl, encoding="utf-8") as fh:
        for line in fh:
            line = line.split("#", 1)[0].strip()
            if line:
                out.append(line)
    return out


def search_path(suite_dir, corpus_root):
    """The ordered dirs a companion may be resolved from. -> (grader_dirs, declared_dirs).
    grader_dirs are what the GRADER can already reach for an entry materialized into an isolated temp dir: the two the
    companion copy searches, plus the dirs the harness puts on $SNO_LIB. declared_dirs are corpus trees the grader canNOT
    reach and this tool may copy FROM. ⛔ The difference between the two lists IS the verdict, so they are built here once
    and never merged by a caller.
    ⛔ THE DRIVER'S UPWARD ANCESTOR WALK IS DELIBERATELY NOT IN grader_dirs. It is real (scrip.c adds <anc>/include for every
    ancestor of the source), and from an isolated temp dir under /tmp it finds NOTHING -- which is exactly why it must not be
    counted: including it would model a hand run inside the corpus tree and green entries the board would fail."""
    grader = [suite_dir, os.path.join(suite_dir, "config")] + [os.path.join(corpus_root, d) for d in GRADER_ENV_DIRS]
    # ⭐ ASK THE HARNESS WHAT IT WILL ACTUALLY SET, rather than trusting the constant above to still be true. resolve_paths()
    # is the same call run_m3 makes before assigning SNO_LIB, so if that path ever moves this list moves with it instead of
    # quietly grading against a dir the harness stopped using. The constant stays as the answer when resolve_paths cannot
    # run at all (a bare corpus, no SCRIP tree) -- a fallback that is NAMED, never a silent one.
    try:
        _inc = str(_csh.resolve_paths()["inc"])
        if os.path.isdir(_inc) and _inc not in grader:
            grader.append(_inc)
    except Exception:
        pass
    declared = [os.path.join(corpus_root, d) for d in _read_path_decl(suite_dir)]
    return ([d for d in grader if os.path.isdir(d)], [d for d in declared if os.path.isdir(d)])


def _skip(name):
    """⛔ An ABSOLUTE reference is the program's own scratch path (/tmp/rung37_fh_test.txt), never a companion -- copying it
    is file-onto-itself (SameFileError, the suite dies boardless: witness rung37_all on the icon board). A `..` reference
    escapes the isolated dir by construction. Both are the grader's own rules, mirrored so the two agree by inspection."""
    return os.path.isabs(name) or ".." in name.replace("\\", "/").split("/")


def _same_bytes(a, b):
    try:
        with open(a, "rb") as fa, open(b, "rb") as fb:
            return fa.read() == fb.read()
    except OSError:
        return False


def closure(texts, suite_dir, corpus_root):
    """Resolve every companion the given entry texts name, to a fixed point.

    -> dict(reachable={name: path}, materializable={name: src_path}, unresolvable={name: True},
            ambiguous=[(name, path_a, path_b)], grader_dirs=[...], declared_dirs=[...])
    `reachable` = the grader finds it today · `materializable` = IT EXISTS IN THIS CORPUS AND THE GRADER CANNOT REACH IT
    (the defect class; --write copies these beside the rungs) · `unresolvable` = named, found nowhere either list can see.

    ⭐ CLOSURE, NOT ONE LEVEL, AND ACROSS THE TWO CLASSES BOTH WAYS: an entry names A, A is already reachable but names B,
    and B lives only on the declared path -- so a reachable file must still be SCANNED even though nothing needs copying.
    (The mirror case, a materializable A naming a reachable B, is the one a naive "scan only what I copied" gets right by
    accident.) `seen` dispositions each name at most once, so a self-including file or a two-file cycle terminates.
    ⛔ UNRESOLVABLE IS REPORTED, NEVER A FAILURE HERE. Most unresolvable names are not files at all: the INPUT/OUTPUT
    pattern legitimately captures association names (FIN, RD) and flag strings ([-f0 -r4194304]), and two entries name a
    deliberately-absent target (nonexistent_target.sno) because THAT IS THE TEST. Distinguishing those from a genuinely
    lost companion is a judgement about the corpus, not something this function can measure -- so it hands back the list
    and lets the caller print it."""
    reachable, materializable, unresolvable, ambiguous = {}, {}, {}, []
    grader_dirs, declared_dirs = search_path(suite_dir, corpus_root)
    seen = set()
    queue = []
    for t in texts:
        queue.extend(companion_names(t))
    while queue:
        name = queue.pop(0)
        if name in seen or _skip(name):
            continue
        seen.add(name)
        hit = None
        for d in grader_dirs:
            cand = os.path.join(d, name)
            if os.path.isfile(cand):
                hit = cand
                reachable[name] = cand
                break
        if hit is None:
            found = [os.path.join(d, name) for d in declared_dirs if os.path.isfile(os.path.join(d, name))]
            if found:
                for other in found[1:]:
                    if not _same_bytes(found[0], other):
                        ambiguous.append((name, found[0], other))
                hit = found[0]
                materializable[name] = hit
            else:
                unresolvable[name] = True
        if hit is not None:
            try:
                with open(hit, encoding="utf-8", errors="replace") as fh:
                    queue.extend(companion_names(fh.read()))
            except OSError:
                pass
    return dict(reachable=reachable, materializable=materializable, unresolvable=unresolvable,
                ambiguous=ambiguous, grader_dirs=grader_dirs, declared_dirs=declared_dirs)
