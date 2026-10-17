#!/usr/bin/env python3
"""Resolve and materialize the companion closure of a rung suite suite -- the BUILD-TIME half of the cure in
lib_companion_closure.py (read that file's header first; it carries the measured defect and the refusal rules).

    python3 ../harness/scripts/util_rungs_companion_closure.py --lang snobol4            # CHECK  (default)
    python3 ../harness/scripts/util_rungs_companion_closure.py --lang snobol4 --write    # CURE
    python3 ../harness/scripts/util_rungs_companion_closure.py --lang all                # every rung suite that exists

EXIT CODES -- rc=0 clean · rc=1 MEASURED GAP (some entry names a companion that exists on the declared path and is not
beside the rungs; --write cures it) · rc=2 REFUSAL (could not measure: no rungs pair, or an ambiguous basename).
⛔ rc=1 AND rc=2 ARE NOT THE SAME ANSWER and this file is careful to keep them apart: rc=1 is "I looked and the corpus is
short"; rc=2 is "I could not look". A tool that cannot measure must never print the success shape (RULES.md).
⭐ IT PRINTS ITS DENOMINATOR. Names seen, names already reachable, names materializable, names unresolvable -- with the
unresolvable ones listed BY NAME every run, never as a bare count, because that list is the one place a genuinely lost
companion would show up and a count cannot be read for a new arrival.
"""
import argparse
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib_companion_closure as L

# ⛔ EXTENSIONS COME FROM THE HARNESS'S OWN TABLE, not a second list here -- a language whose ext drifts must not have two
# answers on this box (the SNOBOL4-rungs ext is the one exception the harness itself hardcodes as the default).
import corpus_suite_harness as _csh

EXTS = dict({lang: cfg["ext"] for lang, cfg in _csh.LANG_CONFIGS.items()}, snobol4=".sno")


def _corpus_root(script_dir):
    s4e = os.environ.get("S4E_HOME") or os.path.abspath(os.path.join(script_dir, "..", ".."))
    return os.path.join(s4e, "corpus")


def _entry_texts(rungs_path, lang):
    """(texts, n_entries) -- one text per entry, for ATTRIBUTION only. The name set is scanned from these same texts, so
    a split that missed an entry would UNDER-report; the split is therefore taken from the harness's own matchers rather
    than a lookalike written here (⛔ the SNOBOL4 rungs mixes BANNERED blocks with ONE-LINE entries that carry only a
    trailing `;*` tag -- a banner-only split reads 1052 of its 1870 entries and every name in the other 818 is invisible,
    which is exactly the shape of silent under-measurement this whole file exists to remove).
    ⛔ Deliberately NOT read_suite/read_block_suite: those GRADE a suite -- they demand a matching .ref, an aligned
    sidecar, a modes column -- and refuse on a rung suite that is mid-rebuild. A companion census must still work on one."""
    text = open(rungs_path, encoding="utf-8", errors="replace").read()
    if lang == "snobol4":
        is_start, is_banner = _csh._is_entry_start, lambda l: l[:1] == "*" and _csh.BANNER_RE.match(l)
    else:
        cfg = _csh.LANG_CONFIGS[lang]
        _bre = _csh.banner_re_for(cfg["comment_open"], cfg["comment_close"])
        is_start = is_banner = lambda l: bool(_bre.match(l))
    texts, cur, n = [], None, 0
    for line in text.split("\n"):
        if is_start(line):
            if cur is not None:
                texts.append("\n".join(cur))
            n += 1
            cur = [] if is_banner(line) else [line]
        elif cur is not None:
            cur.append(line)
    if cur is not None:
        texts.append("\n".join(cur))
    if not n:
        return [text], 0
    return texts, n


def _attribute(texts, name):
    """How many ENTRIES name this companion themselves. ⭐ Zero is not a contradiction: a name reached through the
    closure (a companion that includes a companion) is named by no entry directly, and saying so is the difference
    between a census a reader can act on and one that looks broken."""
    n = sum(1 for t in texts if name in L.companion_names(t))
    return f"named by {n} entr(y/ies)" if n else "reached via the closure, named by no entry directly"


def one_lang(lang, corpus_root, write, quiet=False):
    """-> rc for this language (0 clean, 1 measured gap, 2 refusal)."""
    ext = EXTS.get(lang)
    if ext is None:
        print(f"⛔ REFUSED: no extension known for language {lang!r}", file=sys.stderr)
        return 2
    suite_dir = os.path.join(corpus_root, "tests", lang)
    rungs = os.path.join(suite_dir, "ALL" + ext)
    if not os.path.isfile(rungs):
        print(f"⛔ REFUSED: {lang}: no rungs at {rungs} -- nothing was measured (a language with no rungs is not a "
              f"clean language, it is an unmeasured one)", file=sys.stderr)
        return 2
    texts, n_entries = _entry_texts(rungs, lang)
    r = L.closure(texts, suite_dir, corpus_root)
    seen = len(r["reachable"]) + len(r["materializable"]) + len(r["unresolvable"])
    print(f"== {lang}: {n_entries or '?'} entries · {seen} companion name(s) named · "
          f"{len(r['reachable'])} already reachable · {len(r['materializable'])} materializable · "
          f"{len(r['unresolvable'])} unresolvable")
    print(f"   grader reaches  : {', '.join(os.path.relpath(d, corpus_root) for d in r['grader_dirs']) or '(none)'}"
          f"   [the two the companion copy searches, plus what the harness puts on $SNO_LIB]")
    print(f"   declared path   : {', '.join(os.path.relpath(d, corpus_root) for d in r['declared_dirs']) or '(none)'}"
          f"   [{os.path.join('tests', lang, 'config', L.PATH_DECL_BASENAME)}; default {list(L.DEFAULT_PATH_DIRS)} -- a dir belongs here ONLY if the grader cannot reach it]")
    if r["ambiguous"]:
        print(f"⛔ REFUSED: {len(r['ambiguous'])} basename(s) resolve to DIFFERENT files on the declared path -- this tool "
              f"will not pick one for you (a wrong pick grades an entry against another tree's data and says nothing):",
              file=sys.stderr)
        for name, a, b in r["ambiguous"]:
            print(f"     {name}: {os.path.relpath(a, corpus_root)} != {os.path.relpath(b, corpus_root)}", file=sys.stderr)
        return 2
    if r["unresolvable"] and not quiet:
        print(f"   unresolvable (named, and in NONE of the dirs above -- association names, flag strings and "
              f"deliberately-absent targets all land here; a REAL lost companion would too, so read them):")
        for name in sorted(r["unresolvable"]):
            print(f"     {name!r}  ({_attribute(texts, name)})")
    if not r["materializable"]:
        print(f"✅ {lang}: every companion any entry names that exists in this corpus is reachable by the grader.")
        return 0
    cfg_dir = os.path.join(suite_dir, "config")
    print(f"{'CURING' if write else '⛔ GAP'}: {len(r['materializable'])} companion(s) exist in this corpus and the grader "
          f"CANNOT REACH ANY OF THEM, so every entry naming one is graded with that dependency simply absent:")
    for name in sorted(r["materializable"]):
        src = r["materializable"][name]
        print(f"     {name:<28} <- {os.path.relpath(src, corpus_root):<40} ({_attribute(texts, name)})")
    if not write:
        print(f"   cure: python3 ../harness/scripts/util_rungs_companion_closure.py --lang {lang} --write")
        return 1
    os.makedirs(cfg_dir, exist_ok=True)
    for name in sorted(r["materializable"]):
        dst = os.path.join(cfg_dir, name)
        # ⛔ A name may carry a '/' (the package builder qualifies a nested source), so the parent is made, not assumed.
        os.makedirs(os.path.dirname(dst) or cfg_dir, exist_ok=True)
        shutil.copy2(r["materializable"][name], dst)
    print(f"✅ {lang}: copied {len(r['materializable'])} companion(s) into {os.path.relpath(cfg_dir, corpus_root)}/")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--lang", required=True, help="a language name, or 'all' for every rung suite that exists")
    ap.add_argument("--write", action="store_true", help="materialize the closure into tests/<lang>/config/ (default: check only)")
    ap.add_argument("--corpus", default="", help="corpus root (default: the sibling corpus/ under S4E_HOME)")
    ap.add_argument("--quiet-unresolvable", action="store_true", help="omit the unresolvable listing (the count still prints)")
    a = ap.parse_args()
    corpus_root = a.corpus or _corpus_root(os.path.dirname(os.path.abspath(__file__)))
    if not os.path.isdir(corpus_root):
        print(f"⛔ REFUSED: no corpus at {corpus_root}", file=sys.stderr)
        raise SystemExit(2)
    if a.lang == "all":
        # ⭐ 'all' skips a language with no rungs (nothing to measure is not a gap), but a language WITH a rung suite that
        # refuses still refuses -- the worst rc wins, so one unmeasurable language can never be averaged into a green sweep.
        rcs = []
        for lang in sorted(EXTS):
            if os.path.isfile(os.path.join(corpus_root, "tests", lang, "ALL" + EXTS[lang])):
                rcs.append(one_lang(lang, corpus_root, a.write, a.quiet_unresolvable))
            else:
                print(f"-- {lang}: no rungs -- not measured")
        if not rcs:
            print("⛔ REFUSED: no language has a rung suite suite -- nothing was measured", file=sys.stderr)
            raise SystemExit(2)
        raise SystemExit(2 if 2 in rcs else (1 if 1 in rcs else 0))
    raise SystemExit(one_lang(a.lang, corpus_root, a.write, a.quiet_unresolvable))


if __name__ == "__main__":
    main()
