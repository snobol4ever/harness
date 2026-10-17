#!/usr/bin/env python3
"""util_feature_coverage_census.py -- ONE instrument, all seven languages, over the feature columns
every corpus/tests/<lang>/ALL.csv already carries (GOAL-TEST-SUITE-CONSISTENCY.md sec THE STANDARD,
point 8; Lon 2026-09-04, verbatim: "Will all languages get a full test suite with 100's of test cases
exercising each feature and several combination of features?"). Task
feature-coverage-census-hundreds-per-feature-and-combinations-all-seven (ceo, minted 2026-09-04) --
"this row owns the instrument and the floor table, not the witnesses": it prints, per language,
entries-per-feature and entries-per-feature-PAIR, names every feature below its floor and every
feature with no pair at all, and rewrites its row on the leaderboard. It does NOT write test cases --
that is each lane's own walk.

THE SCHEMA: corpus/tests/<lang>/ALL.csv carries a fixed prefix (rank, entry, origin, family, kind, xfail,
n_lines, heap_kb) -- verified identical across all seven languages before a line of this was written --
followed by one 0/1 column per feature (snobol4/snocone/rebus 39, icon 61, prolog 39, raku
39, pascal 50; measured against the real trees, matches GOAL-TEST-SUITE-CONSISTENCY.md's own count).
A cell is boolean presence, not a count (measured max cell value across the whole snobol4 rungs is 1).

⛔⭐ A FEATURE COLUMN NEVER FILLED IS A REFUSAL (rc=2), NOT A ZERO (GOAL, verbatim). Same vacuity-trap
family as util_ladder_forms_check.py's own headline risk: a language whose ALL.csv carries the column
in name only would otherwise read as "0 entries, 0 pairs" for every one of its features and pass
right past the exact gap this instrument exists to name. So: zero entries for a DECLARED feature column
REFUSES for that language rather than reporting a real-looking zero.

THE FLOOR: GOAL text names it "set from the reference's own list of forms (a construct with three
spellings owes at least those three single-feature witnesses)" -- i.e. genuine per-construct linguistic
research, language by language, feature by feature. That research is NOT done here (it is real work,
not a number this script can honestly manufacture) -- the floor table this row owns is the MECHANISM
(a per-language override file, `corpus/tests/<lang>/config/FEATURE_FLOORS.tsv`, feature<TAB>floor) plus
a documented, explicitly-labelled DEFAULT of 10, which is not arbitrary: it is the exact line the GOAL
text's own worked example draws for SNOBOL4, the model shape ("2 below 10: APPLY 8, ABORT 7"). A lane
that has done the real research for its language drops a FEATURE_FLOORS.tsv in and this instrument
honours it, named explicitly in the output as an override, never silently blended with the default.

ENTRIES PER FEATURE PAIR: for every unordered pair of feature columns, the number of entries with BOTH
nonzero -- computed as a full co-occurrence matrix (cheap: each entry has few features truthy at once,
measured max concurrent features per SNOBOL4 entry is small). Reported as: entries with >=2 features (a
per-language denominator, calibrated against SNOBOL4's own documented 1258), how many of the possible
pairs are realized at least once, and -- the actual DONE-WHEN-relevant list -- every feature that is
filled (>0 entries) but realizes ZERO pairs: exercised only ever in isolation, never in combination.

EXIT: 0 every requested language is fully populated (no refusal, nothing below floor, no zero-pair
feature). 1 something is short (a real, printed gap -- expected on every language but SNOBOL4 today,
since filling it is each lane's walk, not this row's). 2 REFUSED -- cannot measure (no ALL.csv, no
feature columns, or a declared feature column with zero entries).
"""
import sys, os, csv, argparse, itertools

HERE = os.path.dirname(os.path.abspath(__file__))
# ⛔ S4E_HOME IS THE ROOT, NOT THE SCRIP DIRECTORY (convention copied from util_ladder_forms_check.py and
# util_score_row.py -- they are the authority on this variable, not re-derived here).
S4E = os.environ.get("S4E_HOME") or os.path.abspath(os.path.join(HERE, "..", "..", "SCRIP", ".."))
CORPUS = os.path.join(S4E, "corpus")
LANGS = ["snobol4", "icon", "prolog", "raku", "pascal", "snocone", "rebus"]
# ⛔⭐ heap_kb JOINED THIS PREFIX 2026-09-23 (Lon / CEO-1167) AND THAT IS NOT A COSMETIC ENTRY. read_rungs()
# locates these columns BY NAME, in order, and treats everything after the last of them as a feature column by
# construction -- so the instant the column landed in ALL.csv without this line moving, all seven
# languages REFUSED with "1/40 feature column(s) declared but NEVER FILLED: heap_kb". That refusal is
# the design working: an attribute column silently counted as an unfilled feature would have dragged
# every language's coverage denominator without one number changing its name. Measured, in that order.
PREFIX = ["rank", "entry", "origin", "family", "kind", "xfail", "n_lines", "heap_kb", "stack_kb"]
# the unit's command line (clause 8 (f), CEO-1281): attribute columns, never features, and optional while the tables gain them --
# a compile_args cell reads --stlimit, which would refuse here as a non-integer feature, and an absent column is no mismatch
COMMAND_LINE = ("compile_args", "run_args")
DEFAULT_FLOOR = 10   # the GOAL text's own worked example: SNOBOL4, the model shape, flags "below 10".


def die(msg, rc=2):
    sys.stderr.write("REFUSED(%d) util_feature_coverage_census: %s\n" % (rc, msg))
    raise SystemExit(rc)


def all_csv_path(lang):
    return os.path.join(CORPUS, "tests", lang, "ALL.csv")


def floors_path(lang):
    return os.path.join(CORPUS, "tests", lang, "config", "FEATURE_FLOORS.tsv")


def read_floors(lang, features):
    # Returns (floor_map, source_label). An override file is honoured feature-by-feature; any feature
    # it does not name still falls back to DEFAULT_FLOOR, and the label says so rather than implying the
    # whole table was researched when only part of it was.
    p = floors_path(lang)
    floor = {f: DEFAULT_FLOOR for f in features}
    if not os.path.exists(p):
        return floor, "DEFAULT=%d for all %d feature(s) (no override at %s)" % (DEFAULT_FLOOR, len(features), p)
    named = 0
    with open(p, encoding="utf-8") as fh:
        for line in fh:
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            parts = s.split("\t")
            if len(parts) != 2:
                continue
            feat, val = parts[0].strip(), parts[1].strip()
            if feat in floor:
                try:
                    floor[feat] = int(val)
                    named += 1
                except ValueError:
                    pass
    return floor, "override %s: %d feature(s) named, %d on DEFAULT=%d" % (p, named, len(features) - named, DEFAULT_FLOOR)


def read_rungs(lang):
    # Returns (feature_cols, rows) where rows is a list of {feature: 0/1}. Raises via die() on any
    # structural surprise -- a malformed rungs describes a tree nobody can trust the rest of either.
    p = all_csv_path(lang)
    if not os.path.exists(p):
        return None, None, "no ALL.csv at %s" % p
    with open(p, encoding="utf-8", newline="") as fh:
        r = csv.reader(fh)
        try:
            hdr = next(r)
        except StopIteration:
            return None, None, "ALL.csv at %s is empty" % p
        _pos = [hdr.index(c) if c in hdr else -1 for c in PREFIX]
        if -1 in _pos or _pos != sorted(_pos) or _pos[0] != 0:
            return None, None, ("ALL.csv header prefix mismatch at %s -- expected the fixed columns %s in order, got %s "
                                 "(everything after the last fixed column is a feature column by construction)"
                                 % (p, PREFIX, hdr[:len(PREFIX) + 1]))
        first_feat = _pos[-1] + 1
        feat_idx = [i for i in range(first_feat, len(hdr)) if hdr[i] not in COMMAND_LINE]
        feat_cols = [hdr[i] for i in feat_idx]
        if not feat_cols:
            return [], [], None
        rows = []
        for lineno, rec in enumerate(r, start=2):
            if not rec or not rec[0].strip():
                continue
            if len(rec) < len(hdr):
                return None, None, "ALL.csv at %s line %d has %d field(s), header has %d" % (p, lineno, len(rec), len(hdr))
            vals = {}
            for f, i in zip(feat_cols, feat_idx):
                v = rec[i].strip()
                try:
                    vals[f] = int(v) if v else 0
                except ValueError:
                    return None, None, "ALL.csv at %s line %d: feature %s has non-integer cell %r" % (p, lineno, f, v)
            rows.append(vals)
        return feat_cols, rows, None


def check_lang(lang, verbose=True):
    # Returns (status, entries, denom, missing) -- status one of OK / SHORT / REFUSED. `denom` is the
    # feature-column count (the per-language denominator every printed line names).
    feat_cols, rows, why = read_rungs(lang)
    if why:
        if verbose:
            print("  %-8s REFUSED  %s" % (lang, why))
        return "REFUSED", 0, 0, ["%s: REFUSED -- %s" % (lang, why)]
    if not feat_cols:
        msg = "ALL.csv has no feature columns at all (nothing after the %s prefix)" % ",".join(PREFIX)
        if verbose:
            print("  %-8s REFUSED  %s" % (lang, msg))
        return "REFUSED", 0, 0, ["%s: REFUSED -- %s" % (lang, msg)]

    counts = {f: 0 for f in feat_cols}
    paired = {f: 0 for f in feat_cols}   # distinct OTHER features this one has co-occurred with at least once
    pair_hits = {}                       # frozenset({a,b}) -> entries where both nonzero
    entries_2plus = 0
    for row in rows:
        present = [f for f in feat_cols if row.get(f, 0)]
        for f in present:
            counts[f] += 1
        if len(present) >= 2:
            entries_2plus += 1
            for a, b in itertools.combinations(sorted(present), 2):
                key = (a, b)
                pair_hits[key] = pair_hits.get(key, 0) + 1

    never_filled = [f for f in feat_cols if counts[f] == 0]
    if never_filled:
        msg = "%d/%d feature column(s) declared but NEVER FILLED (0 entries): %s" % (len(never_filled), len(feat_cols), ", ".join(never_filled))
        if verbose:
            print("  %-8s REFUSED  %s" % (lang, msg))
        return "REFUSED", len(rows), len(feat_cols), ["%s: REFUSED -- %s" % (lang, msg)]

    for (a, b) in pair_hits:
        paired[a] += 1
        paired[b] += 1

    floor, floor_src = read_floors(lang, feat_cols)
    below_floor = sorted([f for f in feat_cols if counts[f] < floor[f]], key=lambda f: counts[f])
    zero_pair = sorted([f for f in feat_cols if paired[f] == 0])
    possible_pairs = len(feat_cols) * (len(feat_cols) - 1) // 2
    realized_pairs = len(pair_hits)

    missing = []
    for f in below_floor:
        missing.append("%s: %s below floor (%d entries, floor %d)" % (lang, f, counts[f], floor[f]))
    for f in zero_pair:
        missing.append("%s: %s has ZERO pairs (%d entries, all in isolation)" % (lang, f, counts[f]))

    if verbose:
        print("  %-8s %-6s %d entries, %d feature(s), floor: %s" % (lang, "" , len(rows), len(feat_cols), floor_src))
        print("           entries with >=2 features: %d   realized pairs: %d/%d possible"
              % (entries_2plus, realized_pairs, possible_pairs))
        if below_floor:
            print("           BELOW FLOOR (%d): %s" % (len(below_floor), ", ".join("%s=%d" % (f, counts[f]) for f in below_floor)))
        if zero_pair:
            print("           ZERO PAIRS (%d): %s" % (len(zero_pair), ", ".join(zero_pair)))
        if not below_floor and not zero_pair:
            print("           OK -- every feature at/above floor, every feature paired at least once")

    return ("OK" if not missing else "SHORT"), len(rows), len(feat_cols), missing


def selftest():
    # ⛔ THE VACUITY ARM IS THE ONE THAT MATTERS. A checker that reads GREEN for a rung suite carrying no
    # feature columns, or that reports a plain "0" for a column nobody ever filled, would pass every
    # language that has not started yet -- the exact gap this row exists to name. Both directions proven.
    import tempfile, shutil
    ok = True
    d = tempfile.mkdtemp(prefix="feature_census.selftest.")
    global CORPUS
    real = CORPUS
    try:
        CORPUS = d

        def mk(lang, feat_cols, entry_rows, floors=None):
            td = os.path.join(d, "tests", lang)
            os.makedirs(td, exist_ok=True)
            with open(os.path.join(td, "ALL.csv"), "w", encoding="utf-8", newline="") as fh:
                w = csv.writer(fh, lineterminator="\n")   # OUR FILES ARE LF; csv defaults to CRLF.
                w.writerow(PREFIX + feat_cols)
                for i, vals in enumerate(entry_rows, start=1):
                    w.writerow([str(i), "e%d" % i, "e%d" % i, "fam", "line", "0", "1", ""] + vals)
            if floors:
                cd = os.path.join(td, "config")
                os.makedirs(cd, exist_ok=True)
                with open(os.path.join(cd, "FEATURE_FLOORS.tsv"), "w", encoding="utf-8") as fh:
                    for f, v in floors.items():
                        fh.write("%s\t%s\n" % (f, v))

        cases = []
        # 1. every feature filled, at/above default floor, every feature paired -> OK
        mk("aaa", ["a", "b"], [[1, 1]] * 10)
        cases.append(("filled, paired, at floor -> OK", "aaa", "OK"))
        # 2. a feature column with ZERO entries -> REFUSED, never a plain 0
        mk("bbb", ["a", "b"], [[1, 0]] * 10)
        cases.append(("an unfilled feature column REFUSES rather than reading as a plausible zero", "bbb", "REFUSED"))
        # 3. no feature columns at all -> REFUSED
        mk("ccc", [], [[]] * 5)
        cases.append(("no feature columns declared -> REFUSED", "ccc", "REFUSED"))
        # 4. a feature below floor (with an override raising ITS OWN floor above the real count) -> SHORT
        mk("ddd", ["a", "b"], [[1, 1]] * 3 + [[0, 1]] * 7, floors={"a": 20, "b": 1})
        cases.append(("a floor above the real count FAILS the feature (SHORT), never a silent pass", "ddd", "SHORT"))
        # 5. a feature filled and above floor but never co-occurring -> SHORT (zero pairs)
        mk("eee", ["a", "b"], [[1, 0]] * 12 + [[0, 1]] * 12, floors={"a": 5, "b": 5})
        cases.append(("a filled, above-floor feature with no pair -> SHORT", "eee", "SHORT"))
        # 6. missing ALL.csv entirely -> REFUSED
        cases.append(("no ALL.csv at all -> REFUSED", "fff", "REFUSED"))

        for label, lang, want in cases:
            got, _e, _d, _m = check_lang(lang, verbose=False)
            if got == want:
                print("SELFTEST: %s" % label)
            else:
                print("SELFTEST FAIL: %s -- got %s, wanted %s" % (label, got, want))
                ok = False
    finally:
        CORPUS = real
        shutil.rmtree(d, ignore_errors=True)
    print("SELFTEST %s" % ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--lang")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        return selftest()
    if a.lang and a.all:
        die("--lang and --all name two different populations -- pass one, never both")
    if a.lang and a.lang not in LANGS:
        die("unknown language %r. Known: %s" % (a.lang, ", ".join(LANGS)))
    langs = [a.lang] if a.lang else LANGS
    print("feature-coverage census -- %d language(s), corpus %s" % (len(langs), CORPUS))
    statuses, allmissing = {}, []
    tot_entries = tot_feat = 0
    for l in langs:
        st, entries, denom, m = check_lang(l)
        statuses[l] = st
        tot_entries += entries
        tot_feat += denom
        allmissing += m
    print("  ---")
    print("  DENOMINATOR: %d language(s), %d total entries, %d total feature column(s) graded"
          % (len(langs), tot_entries, tot_feat))
    for st in ("OK", "SHORT", "REFUSED"):
        named = [l for l in langs if statuses.get(l) == st]
        if named:
            print("  %-10s %s" % (st + ":", " ".join(named)))
    if allmissing:
        for m in allmissing[:60]:
            print("    gap: %s" % m)
        if len(allmissing) > 60:
            print("    ... and %d more" % (len(allmissing) - 60))
    refused = [l for l in langs if statuses[l] == "REFUSED"]
    measured = [l for l in langs if statuses[l] in ("OK", "SHORT")]
    # ⛔⭐ A PER-LANGUAGE REFUSAL IS A NAMED GAP, NOT A REASON TO BLIND THE WHOLE RUN. This row owns the
    # instrument and the floor table, not the witnesses (task GOAL, verbatim) -- so a single unfinished
    # lane (a never-filled column, today: prolog/raku/snocone/rebus; a malformed row, today: pascal) must
    # not make this row's own DONE-WHEN un-passable forever on work that is explicitly someone else's walk.
    # rc=2 stays reserved for when NOTHING could be measured at all -- either a single --lang probe whose
    # one and only subject refused, or an --all run where every requested language refused (the same
    # vacuity shape util_ladder_forms_check.py refuses on: a census that measured nothing must never look
    # like a clean pass). Any OTHER mix (some languages measured for real, one or more refused) is exactly
    # what SHORT (rc=1) already means: real, honest, printed gaps -- the refused languages' reasons are
    # already folded into `allmissing` above by check_lang, so they read as gaps here, not as silence.
    if refused and not measured:
        die("%s REFUSED -- cannot measure ANY requested language (see reasons above)" % ", ".join(refused), rc=2)
    if refused and len(langs) == 1:
        die("%s REFUSED -- cannot measure (see reason above)" % refused[0], rc=2)
    print("VERDICT: %s" % ("PASS -- every feature at/above floor and paired at least once, all requested language(s)"
                           if not allmissing else "SHORT -- %d gap(s) across %d language(s) (%d fully REFUSED: %s)"
                           % (len(allmissing), len(langs), len(refused), ", ".join(refused) if refused else "none")))
    return 1 if allmissing else 0


if __name__ == "__main__":
    raise SystemExit(main())
