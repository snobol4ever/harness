#!/usr/bin/env python3
# util_unabsorbed_census.py -- WHICH OF OUR OWN SOURCES ARE NOT YET IN THE ONE-LINER / MULTI-LINER RUNGS (ceo, 2026-09-04,
# on Lon's order: "For every source from every language that we've generated or that existed in corpus which is not
# part of any third-party package, if you can get it to run and it has output then add that to the test suite list.
# I.e. All our testing should be ONE-LINER and MULTI-LINER Python test suite. Oh yeah, CEO, have you ensured that all
# test sources have been moved into the ONE-LINER and MULTI-LINER?").
#   python3 ../harness/scripts/util_unabsorbed_census.py [--lang L] [--list]
# Walks corpus/ minus packages/ (third-party is the package instrument's business) and minus programs/ (Lon 2026-09-04:
# "Go ahead and exclude programs/* folders." -- the 2026-08-27 parser-only ruling on corpus/programs stands). Every source by extension is one of:
# container (ALL.<ext>), module (include/, library/ -- no main, never absorbed alone), accounted (named in
# tests/<lang>/ALL.excluded.txt with a reason), loose pair (has a .ref/.expected/.std beside it), fixture
# (parser/coverage trees or parser_/probe_/coverage_ names), loose source with no ref, DECLARED-KEEPER (a
# KEEP.md declares it a permanent keeper, or a PENDING.md defers it to a LIVE row -- read from the builder's own
# matchers, see below), or a KERNEL source (benchmarks/<lang>/, demos/<lang>/ -- never owed absorption, CEO-565
# one copy + CEO-567 kernel convention: kernel-with-ref owes nothing, kernel-owed-ref owes a ref cut from the
# oracle and is named). Prints the population per tree and language; rc=0 when no unaccounted runnable source
# remains for the languages asked, rc=1 naming what is owed, rc=2 when corpus/ cannot be read or the deferral
# contract cannot be read. A DONE-WHEN reads its rc, never a pinned count.
import argparse, collections, csv, os, re, sys
S4E = os.environ.get('S4E_HOME') or os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
C = os.path.join(S4E, 'corpus')
EXT = {'sno': 'snobol4', 'sc': 'snocone', 'icn': 'icon', 'pl': 'prolog', 'reb': 'rebus', 'raku': 'raku', 'pas': 'pascal'}
ap = argparse.ArgumentParser(); ap.add_argument('--lang', default=''); ap.add_argument('--list', action='store_true'); A = ap.parse_args()
if not os.path.isdir(os.path.join(C, 'tests')): print('REFUSE(2): no corpus/tests under %s' % C); sys.exit(2)
excluded = collections.defaultdict(set)
additive_excluded = collections.defaultdict(set)   # {lang: {(name, category), ...}} from "name[category]" keys
for lang in set(EXT.values()):
    p = os.path.join(C, 'tests', lang, 'ALL.excluded.txt')
    if os.path.exists(p):
        for line in open(p, errors='replace'):
            line = line.strip()
            if not line or line.startswith('#'): continue
            key = line.split()[0]; excluded[lang].add(key)
            # ⛔⭐ ADDITIVE (demos/benchmarks) exclusions are keyed "name[category]" (util_build_rungs_suite.py's
            # additive_absorb, disambiguating e.g. a demo and a benchmark that share a basename) -- registered
            # as a (name, category) PAIR, never a bare name: a first attempt at this fix added the bare stripped
            # name to excluded[lang] globally, which MEASURED-WRONG immediately -- demos/snobol4/calculator/
            # calculator-1.sno being excluded[demos] falsely "accounted for" the UNRELATED
            # benchmarks/snobol4/demo/calculator-1.sno (same basename, never itself processed), because the two
            # trees carry genuinely identical basenames by design (the benchmark tree mirrors the demo one at a
            # different scale). The category qualifier is load-bearing, not decoration (hq_P seat08 2026-09-04).
            m = re.match(r'^(.+)\[([^\[\]]+)\]$', key)
            if m: additive_excluded[lang].add((m.group(1), m.group(2)))
# ⛔⭐ ADDITIVE ABSORPTION (demos/benchmarks) is invisible to plain base/path/fam matching: a successfully-absorbed
# source keeps living on disk (--additive never touches/deletes it) and is recorded ONLY as an `origin` in
# ALL.csv, shaped "<singular>_<lang>_<base>__<base>" (additive_absorb's own convention) -- never named in
# ALL.excluded.txt. Reconstruct that exact origin per source rather than matching bare basenames across trees:
# demos/snobol4/roman/roman.sno and benchmarks/snobol4/roman.sno produce DIFFERENT origins
# ("demo_snobol4_roman__roman" vs "benchmark_snobol4_roman__roman"), so a bare-basename match would wrongly
# cross-credit one tree's absorption to the other's still-unabsorbed file of the same name.
absorbed_origins = collections.defaultdict(set)
for lang in set(EXT.values()):
    p = os.path.join(C, 'tests', lang, 'ALL.csv')
    if os.path.exists(p):
        with open(p, newline='', errors='replace') as fh:
            for row in csv.DictReader(fh):
                o = row.get('origin')
                if o: absorbed_origins[lang].add(o)
def _additive_origin(top, lang, base):
    singular = top[:-1] if top.endswith('s') else top
    return '%s_%s_%s__%s' % (singular, lang, base, base)
# ⭐ every util_build_rungs_suite.py --from category whose src_dir sits under corpus/tests/** -- i.e. every
# category this census's own `top == 'tests'` branch below has to consider, since path-derived `top` is always
# the literal string "tests" for anything under corpus/tests/**, never the category name the builder was
# actually invoked with (row snobol4-every-non-package-source-...-oracle-refs, seat07 2026-09-05: `--from
# scrip_test,snocone_ladder` absorbed real entries whose origin used THOSE category names as the singular
# prefix -- "scrip_test_snobol4_X__X" / "snocone_ladder_snobol4_X__X" -- which the single-guess 'test' prefix
# below could never match. Keep this list in sync with util_build_rungs_suite.py's own "tests" +
# _EXTRA_TEST_TREES categories by hand; nothing enforces the two lists agreeing).
_TESTS_ADDITIVE_CATS = ('tests', 'scrip_test', 'snocone_ladder')
# ======================================================= the deferral contract, READ FROM THE BUILDER ===
# ⛔⭐⭐ ONE SET OF DECLARATIONS, TWO INSTRUMENTS (ceo CEO-606, 2026-09-12, on hq_B's snocone absorption row).
# This census and util_build_rungs_suite.py were each succeeding on their own terms and disagreeing about the
# same 68 files: the builder REFUSES BY CONTRACT to absorb a source a KEEP.md declares a permanent keeper or a
# PENDING.md defers to a live row, while this census had never heard of either filename and printed all 68 as
# OWED -- debt no instrument would ever have let anyone pay, and a row whose DONE-WHEN is this census's own rc
# could not have gone green by doing the work it named. MEASURED: snocone 79 owed -> 11, the 68 being
# tests/snocone/ladder/prog/*.sc, declared keepers in tests/snocone/ladder/KEEP.md since the tree was built.
# ⭐ THE GENERAL FORM, which outlives the fix: TWO INSTRUMENTS EACH SUCCEEDING ON THEIR OWN TERMS GIVE A
# CONFIDENT, SELF-CONSISTENT, WRONG ANSWER, and a declaration read by one and not the other is exactly that
# shape -- neither instrument is broken, so neither can warn you.
# ⛔ THEREFORE THE MATCHERS ARE IMPORTED, NEVER RE-IMPLEMENTED. util_build_rungs_suite.py's _declared_in_keep /
# _pending_deferral are already a deliberate port of test_gate_suite_conversion_complete.sh's bash matcher; a
# THIRD copy here would reopen the substring/scope bugs those two paid to fix, and any disagreement between the
# third copy and the other two would be UNATTRIBUTABLE -- you could not tell a real keeper from a drift.
# ⛔ AND A CENSUS THAT CANNOT READ THE DECLARATIONS REFUSES (rc=2). Reporting "declared-keeper 0" because an
# import failed is this file's own must-never-print-0 doctrine inverted: a population you cannot see is not an
# empty population.
import importlib.util
_BLD = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'util_build_rungs_suite.py')
try:
    _spec = importlib.util.spec_from_file_location('_census_reads_the_builder', _BLD)
    _bld = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(_bld)
    _declared_in_keep, _pending_deferral, _PO = _bld._declared_in_keep, _bld._pending_deferral, _bld.PO
    # ⛔ THE ONE AUTHORITY FOR "this language has no rival implementation" (CEO-607) reached through the
    # module this census ALREADY loads -- never a second import and never a second spelling of the set. A
    # census that guessed the membership could hand a language that HAS an oracle the derived-ref arm below,
    # which silently downgrades every one of its refs from measured to authored.
    NO_RIVAL_LANGS = _bld.h.NO_RIVAL_LANGS
except Exception as _e:
    print('REFUSE(2): cannot read the deferral contract through %s (%s) -- a census that cannot see the KEEP.md/PENDING.md declarations must not report zero keepers' % (_BLD, _e)); sys.exit(2)
_BC_CACHE = {}
def _basename_counts(lang):
    """The uniqueness population for the builder's bare-basename fallback (a bare `foo.sc` in a KEEP.md
    declares a file only when that basename is unambiguous), computed over THIS census's candidates under
    corpus/tests/<lang>/ -- every source by extension, not only the ones carrying a ref.
    ⛔ Deliberately WIDER than the builder's own population (loose candidates WITH a matching ref), and wider
    is the safe direction by construction: a larger count can only make the bare-basename fallback fire LESS
    often, so this census waves a file through on a bare name only where the builder would too, never in a
    case the builder would refuse. The two agree on every declaration made by relative path, which is every
    declaration a KEEP.md table writes."""
    if lang not in _BC_CACHE:
        c = {}
        for r, _d, fs in os.walk(os.path.join(C, 'tests', lang)):
            for x in fs:
                if x.rsplit('.', 1)[-1] in EXT: c[x] = c.get(x, 0) + 1
        _BC_CACHE[lang] = c
    return _BC_CACHE[lang]
def _declared_keeper_of(abspath, lang):
    """(declaring file, why) when the deferral contract protects this source, else None.
    ⛔ A KEEP.md declaration is permanent; a PENDING.md deferral counts ONLY while its row is LIVE (or
    UNVERIFIABLE, failing closed rather than guessing) -- exactly the builder's own rule, because
    test_gate_suite_conversion_complete.sh's PBAD bucket says a deferral whose row has landed has outlived its
    reason and must CONVERT. An expired deferral that still read as a keeper here would make that prescribed
    fix invisible to the instrument that measures it.
    ⛔ Scoped to corpus/tests/<lang>/ because that is the builder's own ROOT and therefore the only tree whose
    KEEP.md/PENDING.md either instrument reads. (benchmarks/rebus/KEEP.md exists and is read by NOTHING; it
    describes a kernel tree, which CEO-609 already places outside absorption debt, so nothing turns on it --
    but do not mistake its presence for a contract this census honours.)"""
    root = os.path.join(C, 'tests', lang)
    if not abspath.startswith(root + os.sep): return None
    bc = _basename_counts(lang)
    kf = _declared_in_keep(abspath, root, bc)
    if kf: return (os.path.relpath(kf, C), 'KEEPER')
    pd = _pending_deferral(abspath, root, bc, _PO)
    if pd:
        pf, prow, pstate = pd
        if pstate in ('LIVE', 'UNVERIFIABLE'): return (os.path.relpath(pf, C), 'DEFERRED row %s: %s' % (prow or 'UNNAMED', pstate))
    return None
# ⛔⭐ THE KERNEL TREES ARE NOT ABSORPTION DEBT (ceo CEO-609, addendum to CEO-606; CEO-565 ONE COPY + CEO-567 the
# kernel convention). A source under benchmarks/<lang>/ or demos/<lang>/ is a kernel program: it is graded where
# it lives, by the benchmark and demo instruments, and absorbing a second copy of it into a rung suite is the very
# duplication CEO-565 forbids. What it CAN owe is a ref: with a .ref/.expected/.std beside it there is nothing
# owed (kernel-with-ref); without one it is owed a ref cut from the oracle (kernel-owed-ref) and is named.
# ⛔ KEYED ON THE TREE, NEVER ON THE LANGUAGE SEGMENT MATCHING THE FILE'S OWN LANGUAGE -- measured:
# demos/snobol4/claws5/claws5.sc and demos/snobol4/porter/porter.sc are SNOCONE sources living under the
# snobol4 demo tree. A predicate spelled `demos/<this file's lang>/` reads them as ordinary loose debt and is
# wrong about exactly the files nobody thinks to check.
_KERNEL_TOPS = ('benchmarks', 'demos')
rows = collections.defaultdict(collections.Counter); owed = collections.defaultdict(list)
dangling = collections.defaultdict(list)
keepers = collections.defaultdict(list)          # {lang: [(path, (declaring file, why)), ...]} -- reported, never owed
kernel_owed = collections.defaultdict(list)      # {lang: [path, ...]} -- a kernel program owed a ref, its own debt class
_REF_EXTS = ('.ref', '.expected', '.std')
_LANGS = set(EXT.values())
def _fixture_of_a_witness(root, rel, f):
    """True when this file sits in `NAME.fixtures/` and the witness `NAME.<ext>` exists beside that directory.
    Keyed on the DECLARATION (the sibling source), never on the directory name alone, so a stray directory
    called `x.fixtures` with no witness beside it is still counted as debt rather than waved through."""
    d = os.path.basename(os.path.normpath(root))
    if not d.endswith('.fixtures'):
        return False
    stem = d[:-len('.fixtures')]
    parent = os.path.dirname(os.path.normpath(root))
    return any(os.path.isfile(os.path.join(parent, stem + '.' + e)) for e in EXT)


def _own_ref(root, base, files):
    """The .ref/.expected/.std beside `base` that BELONGS TO IT, or None.
    ⛔⭐ A REF IS CLAIMED BY BASENAME, AND A BASENAME IS NOT UNIQUE ACROSS LANGUAGES IN ONE DIRECTORY
    (hq_B 2026-09-12, measured while landing CEO-609 and caught by reading the very first run of the new
    counter, not by a test). corpus/demos/snobol4/claws5/ holds claws5.sno AND claws5.sc beside ONE
    claws5.ref cut for the SNOBOL4 program -- so a plain "does base + '.ref' exist" credited the SNOCONE
    source with another language's pinned output and reported it as kernel-with-ref, OWING NOTHING. Same
    shape at porter/. That is a wrong exclusion, and a wrong exclusion costs more than a wrong cure: a red
    stays visible and an excluded name cannot be red.
    ⭐ THE PREDICATE IS THEREFORE ABOUT THE DIRECTORY, NOT THE FILE: when two or more sources in one
    directory share a basename, NEITHER can claim the ref by name alone, and the question "whose output is
    this" has no answer the filesystem can give. The census says so instead of guessing."""
    twins = [x for x in files if x.rsplit('.', 1)[-1] in EXT and x[:x.rfind('.')] == base]
    if len(twins) > 1: return None
    for e in _REF_EXTS:
        if os.path.exists(os.path.join(root, base + e)): return os.path.join(root, base + e)
    return None


def _ref_is_ambiguous(root, base, files):
    """True when a ref sits beside `base` but two or more sources share that basename -- the collision
    above, reported by name rather than silently resolved either way."""
    twins = [x for x in files if x.rsplit('.', 1)[-1] in EXT and x[:x.rfind('.')] == base]
    return len(twins) > 1 and any(os.path.exists(os.path.join(root, base + e)) for e in _REF_EXTS)

# ⛔⭐ A SOURCE WITH NO ORACLE ANSWER IS EXCLUDED, NEVER DEBT (Lon 2026-10-11 16:0x CDT, in-chat to the ceo, verbatim: "Exclude any program in which
# we have no way to get output from an oracle, or in which we do not know the answer."; ceo CEO-1696, RULES.md § Oracles). Outside tests/<lang>/ (tests/scrip_test/ is not one; tests/<lang>/'s
# accounting is ALL.excluded.txt, the builder's), a source is accounted by a row of an EXCLUDED.tsv in its own directory or any directory above it
# up to corpus/<tree>: <path relative to that EXCLUDED.tsv's directory> TAB NO_ORACLE_ANSWER TAB <the measurement>, the package tables' own shape.
# A row with no measurement, or of any other class, accounts nothing (hq_icon's ASK of 2026-10-17: the Arizona icont-bench harness under
# reference/icon, family_icon.icn twice and jcon/jlink.icn under demos/icon -- timings and &version, an $import iconx cannot load, a linker whose
# input only jtran's pipeline makes and iconx dumps core in it). benchmarks/pascal/EXCLUDED.tsv's kernel<TAB>reason rows are another instrument's.
_noa_cache = {}
def _no_oracle_answer(root, f):
    d, stop = root, os.path.join(C, os.path.relpath(root, C).split(os.sep)[0])
    while True:
        t = os.path.join(d, 'EXCLUDED.tsv')
        if t not in _noa_cache:
            rows = {}
            if os.path.isfile(t):
                for line in open(t, errors='replace'):
                    c = line.rstrip('\n').split('\t')
                    if line.startswith('#') or len(c) < 3: continue
                    if c[1] == 'NO_ORACLE_ANSWER' and c[2].strip(): rows[c[0]] = c[2].strip()
            _noa_cache[t] = rows
        r = os.path.relpath(os.path.join(root, f), d)
        if r in _noa_cache[t]: return (os.path.relpath(t, C), _noa_cache[t][r])
        if d == stop or d == C: return None
        d = os.path.dirname(d)
no_oracle = collections.defaultdict(list)        # {lang: [(path, (EXCLUDED.tsv, measurement)), ...]} -- excluded, never debt (CEO-1696)


for root, dirs, files in os.walk(C):
    rel = os.path.relpath(root, C)
    if rel.startswith('packages') or rel.startswith('programs') or '/.git' in root or rel.startswith('.git'): continue   # programs/* excluded on Lon's word 2026-09-04 ("Go ahead and exclude programs/* folders."): the 08-27 parser-only ruling on that tree stands
    # ⛔⭐⭐ THE BLIND SIDE: THIS CENSUS WALKS SOURCES AND ASKS "does a ref sit beside it", SO A REF WHOSE
    # SOURCE IS GONE IS INVISIBLE TO IT BY CONSTRUCTION (hq_T 2026-09-11, routed by hq_V). MEASURED: corpus
    # `249f653a6` deleted the four loose rung03 suspend pairs and its own commit message states "the four
    # rung03 .expected twins went too" -- they did not; only the .icn and .ref halves were removed, and four
    # .expected files stayed tracked on origin. The same commit reports "icon orphans reach 0", and BOTH
    # SENTENCES WERE TRUE AT ONCE, because the only instrument either was checked against enumerates
    # `ext not in EXT: continue` -- source extensions, one direction, forever.
    # ⭐ THE GENERAL FORM, which is why this lives in the walk and not in a one-off script: AN INVENTORY THAT
    # WALKS ONE HALF OF A PAIR CAN NEVER REPORT DEBT ON THE OTHER HALF, and it will keep printing a clean
    # number while it does. A dangling ref is not cosmetic: it is a SELF-PIN waiting for a name collision --
    # restore a source with that basename and the rungs builder's discover_pairs falls back to the sibling
    # .expected, silently pinning a new program to a ref cut for a deleted one.
    # ⛔ THE PREDICATE IS EXACT ON PURPOSE -- "no file in this directory shares the ref's basename", never a
    # prefix or fuzzy match. A first pass asked "is there a partner with one of the SEVEN source extensions"
    # and over-reported 25 where the truth is 10: demos/scriptix/*.expected sit beside `.md` sources (`.scrip` until 2026-10-02), which
    # is a polyglot extension EXT has no reason to carry. An instrument answering a NARROWER question than
    # you think you asked never says so -- this file's own header carries that lesson twice already.
    _partners = set(os.path.splitext(x)[0] for x in files if not x.endswith(_REF_EXTS))
    for f in files:
        if f.endswith(_REF_EXTS) and not f.startswith('ALL'):
            _base = f[:f.rfind('.')]
            if _base not in _partners:
                _parts = path_parts = os.path.normpath(os.path.join(rel, f)).split(os.sep)
                _lang = next((q for q in _parts if q in _LANGS), '')
                if not (A.lang and _lang != A.lang):
                    dangling[_lang].append(os.path.normpath(os.path.join(rel, f)))
                    rows[(_parts[0], _lang or '?')]['dangling ref (no source)'] += 1
    for f in files:
        ext = f.rsplit('.', 1)[-1] if '.' in f else ''
        if ext not in EXT: continue
        lang = EXT[ext]
        if A.lang and lang != A.lang: continue
        path = os.path.normpath(os.path.join(rel, f)); top = path.split(os.sep)[0]; base = f[:-len(ext) - 1]
        # ⛔⭐ THE ACCOUNTING KEY THE BUILDER ACTUALLY WRITES IS THE FAMILY NAME, NOT THE BASENAME (hq_B 2026-09-04,
        # row icon-every-non-package-source-...). util_build_rungs_suite.py names an excluded source by its FAMILY --
        # the path under corpus/tests/<lang>/ with os.sep -> '_' and the extension dropped (discover_pairs: `fam =
        # rel[:-len(EXT)].replace(os.sep, "_")`) -- so a fixture at tests/icon/parser/alt_arith.icn is written as
        # `parser_alt_arith`. This census matched only basename / filename / corpus-relative path, none of which is that
        # string for ANY source in a subdirectory, so every properly-excluded subdirectory source read as OWED.
        # MEASURED at the fix: icon 219 -> 62 owed, and all 157 of the difference already carried a reason line the
        # builder wrote. ⭐ A top-level source was invisible to this bug because there family == basename, which is
        # exactly why it survived: the population that disproved it was the one the instrument never sampled.
        fam = os.path.splitext(path[len(os.path.join('tests', lang)) + 1:])[0].replace(os.sep, '_') if path.startswith(os.path.join('tests', lang) + os.sep) else ''
        _dk = _declared_keeper_of(os.path.join(root, f), lang) if top == 'tests' else None
        if f.startswith('ALL.'): kind = 'container'
        # ⛔⭐ A DECLARED FIXTURE IS NOT A LOOSE SOURCE, AND ABSORBING ONE BREAKS THE WITNESS THAT DECLARES IT
        # (hq_V 2026-09-12, CEO-598/599, found while classifying icon's 59 owed). A file inside `NAME.fixtures/`
        # is DATA belonging to the witness `NAME.icn` beside that directory -- lib_icn_rundir.sh (THE ONE
        # AUTHORITY for the run-directory contract) stages exactly those files into a fresh rundir, and
        # test_gate_icn_rundir_contract grades the result against the live Arizona oracle. It is accounted BY
        # THAT DECLARATION, as surely as an entry named in ALL.excluded.txt is accounted by its reason line.
        # ⛔ MEASURED, and it is not hypothetical: `tests/icon/rung36_jcon_io.fixtures/io.icn` read `loose pair`
        # (an `io.std` sits beside it) and `rung36_jcon_recent.fixtures/recent.icn` read `loose source (no ref)`.
        # This row's instruction is that an owed source is absorbed into the rungs AND THEN DELETED from the
        # tree -- so acting on those two would have deleted the staged data out from under two witnesses that
        # pass all four arms of that gate today, and the gate would have gone red naming a missing fixture while
        # the rungs gained two entries that grade nothing. ⭐ The criterion of this row is the census's own rc,
        # so a census that counts load-bearing data as debt is a criterion that commands the damage.
        elif _fixture_of_a_witness(root, rel, f): kind = 'accounted'
        elif top in ('include', 'library'): kind = 'module'
        # ⛔⭐ THE DECLARATION IS THE ACCOUNTING, AND IT KEEPS ITS OWN NAME (ceo CEO-606): a declared keeper is
        # reported as its own category rather than folded into `accounted`, because ALL.excluded.txt keeps ITS
        # own meaning -- "this cannot run with output". Those are two different facts about a file, and one
        # bucket for both would destroy the distinction in the only report that carries it. Placed AHEAD of the
        # ALL.excluded.txt checks on purpose: the builder writes its own "KEEPER, declared in ..." lines into
        # that file, so a later check would silently re-absorb the distinction this category exists to keep.
        elif _dk: kind = 'declared-keeper'; keepers[lang].append((path, _dk))
        # ⛔⭐ SAME COLLISION CLASS AS THE additive_excluded FIX ABOVE, NEVER CLOSED HERE (seat02 2026-09-06,
        # row pascal-every-non-package-source-...-with-oracle-refs): ALL.excluded.txt's bare `name` column is
        # only ever written meaning "this name under tests/<lang>/" (util_build_rungs_suite.py's own loose-pair
        # path never walks benchmarks/demos/programs), but the plain `base`/`f` checks below applied it to EVERY
        # tree unconditionally. MEASURED: absorbing tests/pascal/sieve.pas wrote a bare "sieve" reason into
        # ALL.excluded.txt, which silently marked the UNRELATED benchmarks/pascal/sieve.pas 'accounted' too --
        # same basename, different file, never itself absorbed or excluded. `fam` was already tests-scoped by
        # construction (empty outside tests/<lang>/); `base`/`f` were not. `path in excluded[lang]` stays
        # unscoped -- a corpus-relative path is unique by construction, so it carries no collision risk.
        elif path in excluded[lang] or (top == 'tests' and (base in excluded[lang] or f in excluded[lang] or (fam and fam in excluded[lang]))): kind = 'accounted'
        # ⭐ 'tests' joined this check (row snobol4-every-non-package-source-...-absorbed-into-the-rungs-with-
        # oracle-refs, seat07 2026-09-05): util_build_rungs_suite.py's --additive --from tests absorbs
        # corpus/tests/<lang>/'s OWN loose-noref/fixture backlog the identical way it already absorbs
        # demos/benchmarks -- same bracketed "name[tests]" exclusion key, same "test_<lang>_<name>__<name>"
        # origin shape (_additive_origin generalizes: 'tests'[:-1] == 'test'). Without this, every entry that
        # path itself excludes or absorbs would read OWED forever, since the plain-name check above (line 80)
        # never sees a bracketed key and the fixture/loose-noref fallthrough below has no bracket awareness at all.
        elif top in ('demos', 'benchmarks') and ((base, top) in additive_excluded[lang] or _additive_origin(top, lang, base) in absorbed_origins[lang]): kind = 'accounted'
        elif top == 'tests' and (any((base, c) in additive_excluded[lang] for c in _TESTS_ADDITIVE_CATS)
                                  or any(_additive_origin(c, lang, base) in absorbed_origins[lang] for c in _TESTS_ADDITIVE_CATS)): kind = 'accounted'
        # ⛔⭐ A DERIVED REF IS ITS OWN CLASS AND MUST NOT READ AS AN ORACLE-CUT ONE (CEO-607, 2026-09-12, on
        # hq_C's ASK; option (a)). This arm sits AHEAD of the kernel arm below ON PURPOSE. Rebus has NO
        # INDEPENDENT RIVAL IMPLEMENTATION, so CEO-391's one-oracle-per-language has no binary to name for it and
        # its kernels can never be given "a ref cut from its oracle" -- the remedy the kernel arm prints. CEO-607
        # rules the remedy that exists: the ref is DERIVED from a CROSS-LANGUAGE computation of the same kernel
        # under a REAL oracle (the rival program and its oracle output), the hand arithmetic is the second
        # witness, and both are RECORDED in a `.derivation` beside the ref.
        # ⛔ WITHOUT THIS ARM THESE THREE WOULD READ `kernel-with-ref`, WHICH IS THE FLATTERING WRONG ANSWER: that
        # class means "this kernel's ref came from its oracle", and a derived ref that renders identically to an
        # oracle-cut one is exactly the distinction the ruling exists to keep visible. It owes nothing either way,
        # so the rc cannot catch the confusion -- only the class can. An excluded name cannot be red, so a wrong
        # exclusion costs more than a wrong cure (hq_V, standing practice): a special case stays SEEN as one.
        # ⛔ THE TWO GUARDS ARE THE WHOLE POINT, because this arm is otherwise a way to launder an authored number.
        # (a) `lang in NO_RIVAL_LANGS` -- a language that HAS an oracle can never reach here, so a seat cannot dodge
        # an oracle cut by writing a .derivation. (b) the `.derivation` must EXIST AND BE NON-EMPTY beside the ref:
        # a derived ref with no recorded derivation is precisely the authored number nobody can check.
        # ⭐ THIS CENSUS ONLY ACCOUNTS IT. The derivation itself is RE-PERFORMED against the live oracle on every
        # run by test_gate_rebus_derived_refs_match_their_rival_oracle.sh -- a recorded derivation nobody
        # re-executes is a claim, and a static sidecar rots the way this tree's prose digests rot.
        elif not (top == 'tests' and path.split(os.sep)[1] in _LANGS) and _no_oracle_answer(root, f): kind = 'no-oracle-answer'; no_oracle[lang].append((path, _no_oracle_answer(root, f)))
        elif (lang in NO_RIVAL_LANGS and top in _KERNEL_TOPS
              and any(os.path.exists(os.path.join(root, base + s)) for s in _REF_EXTS)
              and os.path.exists(os.path.join(root, base + '.derivation'))
              and os.path.getsize(os.path.join(root, base + '.derivation')) > 0): kind = 'derived-ref'
        elif top in _KERNEL_TOPS:
            if _own_ref(root, base, files): kind = 'kernel-with-ref'
            else: kind = 'kernel-owed-ref'; kernel_owed[lang].append((path, 'a ref sits beside it but is claimed by a same-named source of another language -- this one needs its own, under a name that does not collide') if _ref_is_ambiguous(root, base, files) else (path, ''))
        elif _own_ref(root, base, files): kind = 'loose pair (has ref)'; owed[lang].append(path)
        elif re.search(r'(^|/)(parser|coverage)/', path) or re.match(r'parser_|probe_|coverage_', f): kind = 'fixture'; owed[lang].append(path)
        else: kind = 'loose source (no ref)'; owed[lang].append(path)
        rows[(top, lang)][kind] += 1
print('%-12s %-8s %9s %6s %10s %10s %8s %12s %9s %7s %8s %10s %9s %9s' % ('tree', 'lang', 'container', 'module', 'accounted', 'loose-pair', 'fixture', 'loose-noref', 'dangling', 'keeper', 'kern-ref', 'kern-noref', 'deriv-ref', 'no-oracle'))
tot = collections.Counter()
for (top, lang), c in sorted(rows.items()):
    print('%-12s %-8s %9d %6d %10d %10d %8d %12d %9d %7d %8d %10d %9d %9d' % (top, lang, c['container'], c['module'], c['accounted'], c['loose pair (has ref)'], c['fixture'], c['loose source (no ref)'], c['dangling ref (no source)'], c['declared-keeper'], c['kernel-with-ref'], c['kernel-owed-ref'], c['derived-ref'], c['no-oracle-answer']))
    for k, v in c.items(): tot[k] += v
d = sum(len(v) for v in dangling.values())
# ⛔⭐ A KERNEL SOURCE WITH NO REF IS DEBT, AND IT JOINS THE rc -- the same call this file already made for a
# dangling ref, for the same reason: a debt reported beside an rc=0 is a debt nobody is measured on. CEO-609
# names it "owed a ref cut from the oracle", and rc=1 fires when something is owed. ⭐ It is its OWN bucket and
# is never folded into the absorption number: those are sources awaiting a rung suite entry, these are kernel
# programs that stay where they live and want an oracle-cut ref. Summing them would keep the arithmetic
# plausible while the meaning drained out. ⛔ declared-keeper and kernel-with-ref owe NOTHING and never touch
# the rc -- a declaration and a satisfied kernel pair are answers, not debt.
k = sum(len(v) for v in kernel_owed.values())
n = sum(len(v) for v in owed.values()) + d + k
# ⛔ A DANGLING REF IS OWED DEBT, NOT A WARNING, so it joins the rc -- the four that prompted this check sat on
# origin for two days BECAUSE the only thing that would have named them printed rc=0 about a different question.
# ⭐ It is reported as its own bucket and never folded into 'loose pair': those are sources awaiting absorption,
# these are refs whose source is already gone. Summing them would hide a ref-side regression inside a source-side
# backlog that is being worked down anyway -- the arithmetic would stay plausible while the meaning drained out.
print('UNABSORBED_CENSUS%s: containers=%d modules=%d accounted=%d declared-keepers=%d kernel-with-ref=%d derived-refs=%d no-oracle-answer=%d OWED=%d (loose pairs %d, fixtures %d, loose no-ref %d, DANGLING REFS %d, KERNEL OWED A REF %d) -- an owed source is absorbed into its rungs with an oracle-cut ref, or named in ALL.excluded.txt with the reason it cannot run with output; an owed DANGLING REF is a .ref/.expected/.std whose source no longer exists and is deleted once its content is proven preserved (diff it against the rungs entry that absorbed it) or restored beside its source; a KERNEL source owed a ref is given one cut from its oracle and stays where it lives; a DERIVED REF is a kernel of a language with NO RIVAL IMPLEMENTATION (CEO-607) whose ref is derived cross-language under a real oracle with the derivation recorded beside it -- accounted, never owed, never available to a language that has an oracle, and kept a SEPARATE class from kernel-with-ref so a derived ref never reads as an oracle-cut one. Declared keepers are REPORTED BESIDE owed and never folded into it -- one rung suite per language is the order, and a keeper is a deliberate exception that is SEEN, not one that hides; a NO ORACLE ANSWER source (CEO-1696) is named with its measurement in an EXCLUDED.tsv beside or above it, excluded and never owed' % (' lang=' + A.lang if A.lang else '', tot['container'], tot['module'], tot['accounted'], tot['declared-keeper'], tot['kernel-with-ref'], tot['derived-ref'], tot['no-oracle-answer'], n, tot['loose pair (has ref)'], tot['fixture'], tot['loose source (no ref)'], d, k))
for lang in sorted(set(list(owed) + list(dangling) + list(kernel_owed) + list(keepers) + list(no_oracle))):
    bits = []
    if dangling[lang]: bits.append('dangling refs %d' % len(dangling[lang]))
    if kernel_owed[lang]: bits.append('kernel owed a ref %d' % len(kernel_owed[lang]))
    if keepers[lang]: bits.append('declared keepers %d, not owed' % len(keepers[lang]))
    if no_oracle[lang]: bits.append('no oracle answer %d, excluded, not owed' % len(no_oracle[lang]))
    print('  %-8s owed %d%s' % (lang or '?', len(owed[lang]) + len(dangling[lang]) + len(kernel_owed[lang]), (' (' + '; '.join(bits) + ')') if bits else ''))
if A.list:
    for lang in sorted(set(list(owed) + list(dangling) + list(kernel_owed) + list(keepers) + list(no_oracle))):
        for p in sorted(owed[lang]): print('    ' + p)
        for p in sorted(dangling[lang]): print('    DANGLING REF  ' + p)
        for p, why in sorted(kernel_owed[lang]): print('    KERNEL OWED A REF  ' + p + ('   <- ' + why if why else ''))
        for p, (kf, why) in sorted(keepers[lang]): print('    DECLARED KEEPER  %-58s %s (%s)' % (p, kf, why))
        for p, (xf, why) in sorted(no_oracle[lang]): print('    NO ORACLE ANSWER  %-58s %s (%s)' % (p, xf, why[:160]))
sys.exit(1 if n else 0)
