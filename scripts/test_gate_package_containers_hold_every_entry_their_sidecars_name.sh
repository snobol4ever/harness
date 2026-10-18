#!/usr/bin/env bash
# test_gate_package_containers_hold_every_entry_their_sidecars_name.sh -- A PACKAGE CONTAINER AND ITS SIDECARS NAME ONE POPULATION (ceo to
# the coo 2026-10-18, rank 2, from hq_dotnet's measurement grading containers through corpus_suite_harness.py under a port engine): the
# container builder drops excluded and no-oracle entries from ALL.<ext>, but ALL.csv, PARTITION.tsv and ALL.mask keep naming them, and
# nothing on SCRIP's path reads the containers, so the two drift unseen until a reader of the container refuses (csnobol4_suite's diag1,
# gimpel's dextern_driver). THE CHECK: for every package directory under corpus/packages/<lang>/ that ships a container ALL.<ext> beside
# an ALL.ref, the entries read by THE ONE READER (corpus_suite_harness.py read_suite for SNOBOL4, read_block_suite with the dialect's
# banner for the others) must include every entry named by the package's ALL.csv entry column, its PARTITION.tsv entry column and its
# ALL.mask entry column (the * wildcard excepted). A package with no container is counted and named, never a pass. GREEN iff no package
# container misses a name. RED on corpus a5735c4a9, measured by the coo 2026-10-18 11:0x CDT: 6 of 11 containers drift, 861 names
# (icon/ipl 773, prolog/rosetta-prolog 30, icon/arizona_tests 28, snobol4/csnobol4_suite 22, icon/jcon_tests 7, snobol4/gimpel 1). Classified
# in full (the first cut's 'every sampled one a declared exclusion' sampled rosetta-prolog alone, RETRACTED): 849 are declared exclusions and 12 are
# not (ipl dd2wif painterc evallist huffstuf interpe iundecl; csnobol4_suite conv2 diag1 ord rewind1 space space2). rc 0 green, 1 red, 2 could not measure.
set -u
H="$(cd "$(dirname "$0")" && pwd)"; G=package_containers_hold_every_entry_their_sidecars_name; C="$H/../../corpus/packages"
[ -d "$C" ] || { echo "REFUSE(2) [$G]: no corpus/packages beside the harness at $C -- cannot measure"; exit 2; }
[ -r "$H/corpus_suite_harness.py" ] || { echo "REFUSE(2) [$G]: corpus_suite_harness.py, the one reader, is missing beside this gate -- cannot measure"; exit 2; }
python3 - "$H" "$C" "$G" <<'PY'
import csv, io, sys, contextlib
from pathlib import Path
H, C, G = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
sys.path.insert(0, str(H))
try:
    import corpus_suite_harness as h
except Exception as e:
    print(f"REFUSE(2) [{G}]: corpus_suite_harness.py does not import ({e}) -- cannot measure"); sys.exit(2)
EXT = {"snobol4": ".sno"}
EXT.update({k: c["ext"] for k, c in h.LANG_CONFIGS.items()})
def named(p):
    out = {}
    f = p / "ALL.csv"
    if f.exists():
        with open(f, newline="", encoding="utf-8") as fh:
            for r in csv.DictReader(fh):
                if r.get("entry"):
                    out.setdefault(r["entry"], set()).add("ALL.csv")
    f = p / "PARTITION.tsv"
    if f.exists():
        for ln in f.read_text(encoding="utf-8").splitlines():
            if ln.strip() and not ln.startswith("#") and not ln.startswith("entry\t"):
                out.setdefault(ln.split("\t")[0], set()).add("PARTITION.tsv")
    f = p / "ALL.mask"
    if f.exists():
        for ln in f.read_text(encoding="utf-8").splitlines():
            if ln.strip() and not ln.startswith("#") and ln.split("\t")[0] != "*":
                out.setdefault(ln.split("\t")[0], set()).add("ALL.mask")
    return out
def entries(lang, src, ref):
    sink = io.StringIO()
    with contextlib.redirect_stdout(sink), contextlib.redirect_stderr(sink):
        if lang == "snobol4":
            return [e.name for e in h.read_suite(str(src), str(ref))]
        cfg = h.LANG_CONFIGS[lang]
        return [e.name for e in h.read_block_suite(str(src), str(ref), h.banner_re_for(cfg["comment_open"], cfg["comment_close"]))]
read = drift = names_missing = 0; none = []; unreadable = []
for lang_dir in sorted(x for x in C.iterdir() if x.is_dir()):
    lang = lang_dir.name
    for p in sorted(x for x in lang_dir.iterdir() if x.is_dir()):
        key = f"{lang}/{p.name}"
        src = p / ("ALL" + EXT.get(lang, ".none")); ref = p / "ALL.ref"
        if not src.exists() or not ref.exists():
            none.append(key); continue
        try:
            have = set(entries(lang, src, ref))
        except BaseException as e:
            unreadable.append(f"{key} ({type(e).__name__}: {str(e)[:120]})"); continue
        read += 1
        n = named(p); miss = sorted(e for e in n if e not in have)
        if miss:
            drift += 1; names_missing += len(miss)
            shown = " ".join(f"{e}[{','.join(sorted(n[e]))}]" for e in miss[:6]) + (f" ... and {len(miss) - 6} more" if len(miss) > 6 else "")
            print(f"  FAIL {key}: container {len(have)} entries, sidecars name {len(n)}, {len(miss)} missing: {shown}")
        else:
            print(f"  ok   {key}: container {len(have)} entries hold all {len(n)} names")
print(f"no container (ALL.<ext> beside ALL.ref), counted and not graded: {len(none)}: {' '.join(none)}")
if unreadable:
    print(f"REFUSE(2) [{G}]: the one reader refused {len(unreadable)} container(s): {'; '.join(unreadable)} -- cannot measure"); sys.exit(2)
if read == 0:
    print(f"REFUSE(2) [{G}]: no package container was read -- cannot measure"); sys.exit(2)
if drift:
    print(f"GATE FAIL [{G}]: {drift} of {read} package containers miss {names_missing} name(s) their ALL.csv, PARTITION.tsv or ALL.mask carry"); sys.exit(1)
print(f"GATE PASS [{G}]: every one of {read} package containers holds every name its sidecars carry"); sys.exit(0)
PY
