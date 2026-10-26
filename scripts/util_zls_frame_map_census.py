"""Census every activation-frame word the frame allocator lays out against its zls_field registration.

THE CLAIM UNDER TEST (ARCH-GC-COMPILE-TIME-FRAME-MAPS.md section 7 F1, the collector guesses nothing): every
word of an emitted frame that the collector will ever read carries a kind the compiler wrote down at compile
time.  frame_layout.c is where that kind is written (zls_field: offset, size, ZK_DESCR|ZK_RAW|ZK_PTR_GC|
ZK_PTR_CODE), and `scrip --dump-zeta` prints the table it wrote.  This census reads that table for every
graph of every program it is pointed at and reports every word the table does NOT account for:

  region-gap        a byte in [0, region_end) of the graph that no scope's field covers (the classic hole:
                    the return-value cell IR_RETURN writes at frame +0 was never registered -- found by this
                    census on the Raku rungs, ceo 2026-09-17, CEO-820)
  scope-gap         a byte inside a scope's [lo, hi) between two registered fields
  overlap           a byte two fields of one scope claim with two different kinds (two kinds for one word); two
                    fields of ONE kind over the same bytes are not a hole -- the Prolog clause overlay lays every
                    alternative clause over one base, never two live at once, and its kind map keeps each
                    overlaid word one kind (ceo CEO-1844 (b), 2026-10-18; 0 two-kind words in 280682 fields)
  vslot-unmapped    a named variable slot (vslot) not covered by exactly one field (one offset, size and kind;
                    the overlay's repeats of it count once)
  provisional-kind  a field printed with `(audit)` -- a kind nobody verified against the template
  unknown-kind      a kind name outside the ZK_ enum of src/planner/frame_layout.h (read from it, never a copied list)

WHAT IT DOES NOT SEE, SAID HERE SO NOBODY READS A CLEAN CENSUS AS A CLEAN FRAME: the emitter's wire header
beyond region_end (the saved gamma/omega continuations and the saved rsp the prologue stores, 48 or 80 bytes;
FN__add stores rcx/rdx/rsp at +120/+128/+136 of a 144-byte frame whose zls region ends at 96) is not in the
zls table and is the cto's per-frame map cell (F6 step 2).  Nor does it see the spine (F1 tagged cells).
The population is the zls REGION, and the summary line says so.

POPULATION: one rung suite suite (--lang, extracted in-process through the harness's own readers, the ONE
extraction authority) or explicit --files.  An entry the compiler refuses (no `; graph` line, or rc != 0)
is NO LAYOUT, named and counted beside the verdict, never silently dropped and never graded green.
⛔⭐ A NO-LAYOUT ROW PRINTS rc WITH THE FIRST LINE OF THE REFUSAL, because `rc=1` alone is a bucket and not a
member (the coo's instrument bar, 2026-09-20: every bucket a fleet instrument prints must be answerable to
"name one member of this count").  It also keeps a RED apart from a COULD-NOT-MEASURE, which is the split the
Makefile holds everywhere else.  MEASURED THE HOUR IT LANDED (hq_snobol4, SCRIP 553678ec2 / corpus 86574b2bf,
RT_OPT=-O0), the whole remaining fleet bucket named in one command: snobol4's 1 is
`rc=1: FATAL lower_snobol4 ... lambda(expr), the CONDITIONAL pattern lambda, is not implemented yet`; raku's 31
are `rc=1: raku parse error line 1: syntax error` on the test_stmt_pfx_BEGIN/_CHECK/_END statement-prefix family;
prolog's 10 are `rc=2: builtin b_getval is not on the ladder yet -- rung 10 lands it`.  42 real, three named
unlanded-feature gaps, no mystery -- and rc=2 there is an honest REFUSAL that a bare `rc=` would have shown as
the same thing as raku's red.
rc 0 = graded > 0 and holes == 0; rc 1 = holes > 0; rc 2 = nothing graded (the denominator is zero).
Set ZLS_LIST_ALL=1 to print every hole (the default caps the listing).
THE MACHINE-READ LINE, frozen for the coo's maps census (CEO-821): one per run,
  ZLS-MAP lang=<l> graphs=<n> words=<n> unkinded=<n> holes=<n> graded=<n> no_layout=<n> no_layout_declared=<n>
    no_layout_never_emitted=<n> no_layout_emitted_no_layout=<n> no_layout_unmeasured=<n>

⛔⭐ THE THREE KIND FIELDS, AND WHY THE DISCRIMINATOR IS NOT THE rc (cto 2026-09-20, building CEO-1025 and
correcting its discriminator on the data).  The ruling is right that `no_layout` CONFLATES TWO POPULATIONS WITH
OPPOSITE OWNERS: (a) the compiler REFUSED the entry, so nothing was emitted, there is no leaf boundary and no
store -- a COMPLETENESS debt wearing a GC census's clothes; and (b) the compiler EMITTED the graph and the planner
gave it no frame layout -- boundaries exist, they store into unmapped slots, and THAT is the correctness
population that gates completeness under MODE TENET condition 1.  ⛔ THE RULING NAMED rc=2 AGAINST rc=1 AS THE
SPLIT AND THE DATA SAYS OTHERWISE: prolog's ten read `rc=2 builtin X is not on the ladder yet`, and raku's seven
read `rc=1 raku parse error` / `lex error` / a role-composition refusal.  BOTH ARE REFUSALS THAT EMIT NOTHING, so
rc=1 against rc=2 separates a ladder refusal from a parser refusal -- two flavours INSIDE bucket (a) -- and not
(a) from (b).  The fact the ruling actually asked for is DID THIS ENTRY PRODUCE EMITTED CODE AT ALL, and this
census has always known it directly: a non-zero rc from `--dump-zeta` is NEVER-EMITTED, rc=0 with no frame layout
in the dump is EMITTED-NO-LAYOUT, and a timeout is UNMEASURED and is folded into neither.  The kind is returned as
a VALUE by dump_one and never re-parsed out of the message text, because a guard keyed on a spelling is a
coincidence and not a guard.  The three sum to `no_layout` and the census REFUSES rc=2 if they do not, because an
entry placed in no bucket vanishes from both owners' work lists.
⛔ A DECLARED entry keeps the `NO-LAYOUT ` LINE PREFIX and carries [DECLARED wantrc=N] in its tail; the declaration is NEVER a
new line prefix.  The coo's util_gc_census.py cross-checks no_layout=N against the number of lines starting `NO-LAYOUT ` and
REFUSES when they disagree -- measured 2026-09-20: a first cut of this field used a NO-LAYOUT-DECLARED prefix, the consumer
counted 7 lines against no_layout=9 and refused rc=2.  It was right to.  The sidecar note below uses NO-LAYOUT-SIDECAR (no
space) for the same reason.
no_layout_declared is APPENDED, never inserted: the frozen token and the order and meaning of every field before it are
untouched, and no_layout stays the TOTAL so no consumer silently changes its mind about what it is reading (ceo CEO-1003,
cto's three conditions, 2026-09-20).  It is PRINTED FOR EVERY LANGUAGE INCLUDING ZERO, so a diff of two census lines is a
diff of numbers and never of shapes.  A DECLARED no-layout is an entry the rungs' own ALL.wantrc gives a NON-ZERO rc:
the suite declares it must not compile, so having no frame is the correct and permanent answer rather than a defect.
words = 8-byte words of every graded graph's zls region; unkinded = words of those inside a reported hole.
Detector arm: --dumps grades saved `--dump-zeta` texts instead of running scrip, so a gate can dump a clean
fixture, corrupt ONE field line of that text itself, and require rc 1 -- proof this census still detects a hole
the day the real ones are gone (CEO-554).  The detector lives in the INSTRUMENT, never in SCRIP: the old
SCRIP_TEST_PLANT_ZLS_HOLE seam in zls_dump was deleted under CEO-1680 (hq_raku 2026-10-14, the cto's yes).
"""
import argparse, os, re, subprocess, sys, tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
FRAME_LAYOUT_H = (HERE.parent.parent / "SCRIP") / "src" / "ir" / "frame_layout.h"


def kinds_of_the_enum():
    """The kind names the ZK_ enum defines, read from frame_layout.h so a kind added there is known here the same landing
    (a hard-coded set went stale at 50f4604e6: ZK_PTR_FRAME_H = 5 read as unknown-kind on a Raku generator graph, hq_raku
    2026-10-14, CEO-1697).  An enum this cannot read REFUSES rc=2: an empty set would call every field a hole."""
    try:
        text = FRAME_LAYOUT_H.read_text()
    except OSError as e:
        print(f"REFUSE(2): cannot read the ZK_ enum in {FRAME_LAYOUT_H}: {e}", file=sys.stderr); sys.exit(2)
    m = re.search(r"enum\s*\{([^}]*\bZK_DESCR\b[^}]*)\}", text)
    names = set(re.findall(r"\bZK_([A-Z_]+)\s*=", m.group(1))) if m else set()
    if not {"DESCR", "RAW"} <= names:
        print(f"REFUSE(2): no ZK_ enum with DESCR and RAW found in {FRAME_LAYOUT_H}", file=sys.stderr); sys.exit(2)
    return names


KINDS = kinds_of_the_enum()
RE_GRAPH = re.compile(r"^; graph (\d+) '(.*)' \S+ slots=(\d+) region_end=(\d+) resume=(-?\d+) vslots=(\d+) scopes=(\d+)")
RE_SCOPE = re.compile(r"^;   scope (\d+)\s+(\S+)\s+(.+?)\s+parent=(-?\d+)\s+(?:\[(\d+)\.\.(\d+)\)|\(no frame fields\))")
RE_FIELD = re.compile(r"^;     \+(\d+)\s+(\d+)\s+(\S+)\s+(.*?)\s*$")
RE_VSLOT = re.compile(r"^;   vslot \+(\d+)\s+(\d+)\s+(\S+)\s+(.*?)\s*$")


def parse_dump(text):
    graphs = []
    g = None; sc = None
    for line in text.splitlines():
        m = RE_GRAPH.match(line)
        if m:
            g = {"name": m.group(2), "region_end": int(m.group(4)), "scopes": [], "vslots": []}
            graphs.append(g); sc = None; continue
        if g is None:
            continue
        m = RE_SCOPE.match(line)
        if m:
            sc = {"id": int(m.group(1)), "klass": m.group(2), "name": m.group(3), "fields": [],
                  "lo": int(m.group(5)) if m.group(5) else None, "hi": int(m.group(6)) if m.group(6) else None}
            g["scopes"].append(sc); continue
        m = RE_FIELD.match(line)
        if m and sc is not None:
            what = m.group(4)
            sc["fields"].append({"off": int(m.group(1)), "size": int(m.group(2)), "kind": m.group(3),
                                 "what": what, "audit": what.endswith("(audit)")})
            continue
        m = RE_VSLOT.match(line)
        if m:
            g["vslots"].append({"off": int(m.group(1)), "size": int(m.group(2)), "kind": m.group(3), "name": m.group(4)})
    return graphs


def holes_of(graph):
    out = []
    covered = []
    for sc in graph["scopes"]:
        fs = sorted(sc["fields"], key=lambda f: f["off"])
        for f in fs:
            if f["kind"] not in KINDS:
                out.append(("unknown-kind", sc, f["off"], f["off"] + f["size"], f"kind={f['kind']} {f['what']}"))
            if f["audit"]:
                out.append(("provisional-kind", sc, f["off"], f["off"] + f["size"], f["what"]))
        if not fs:
            continue
        cur = sc["lo"] if sc["lo"] is not None else fs[0]["off"]
        prev = None
        claim = {}
        for f in fs:
            if f["off"] > cur:
                out.append(("scope-gap", sc, cur, f["off"], f"between {prev['what'] if prev else 'scope start'} and {f['what']}"))
            clash = None
            for b in range(f["off"], f["off"] + f["size"]):
                had = claim.setdefault(b, f)
                if had["kind"] != f["kind"]:
                    clash = (clash[0], b + 1, had) if clash else (b, b + 1, had)
            if clash:
                out.append(("overlap", sc, clash[0], clash[1], f"{clash[2]['kind']} {clash[2]['what']} and {f['kind']} {f['what']}"))
            cur = max(cur, f["off"] + f["size"]); prev = f
        hi = sc["hi"] if sc["hi"] is not None else cur
        if cur < hi:
            out.append(("scope-gap", sc, cur, hi, f"after {prev['what']}"))
        covered.append((fs[0]["off"], max(cur, hi)))
    covered.sort()
    pos = 0
    for lo, hi in covered:
        if lo > pos:
            out.append(("region-gap", None, pos, lo, "no scope's field covers it"))
        pos = max(pos, hi)
    if pos < graph["region_end"]:
        out.append(("region-gap", None, pos, graph["region_end"], "tail of the region"))
    allf = [f for sc in graph["scopes"] for f in sc["fields"]]
    for v in graph["vslots"]:
        if v["off"] >= graph["region_end"]:
            continue  # a block-protocol argument (ARCH-PROLOG-C-OUT-OF-THE-BOX 1.2): the caller's typed cell above the frame, not this frame's field
        n = len({(f["off"], f["size"], f["kind"]) for f in allf if f["off"] <= v["off"] and v["off"] + v["size"] <= f["off"] + f["size"]})
        if n != 1:
            out.append(("vslot-unmapped", None, v["off"], v["off"] + v["size"], f"vslot {v['name']} covered by {n} field(s)"))
    return out


NO_LAYOUT_KINDS = ("NEVER-EMITTED", "EMITTED-NO-LAYOUT", "UNMEASURED")


def dump_one(scrip, path, timeout):
    """returns (graphs, err, kind); kind is "" on success and one of NO_LAYOUT_KINDS otherwise.

    ⛔ THE KIND IS RETURNED STRUCTURALLY AND IS NEVER RE-PARSED OUT OF `err` BY A CONSUMER (cto 2026-09-20, CEO-1025).
    A guard keyed on a spelling is a coincidence and not a guard -- hq_snobol4 lost a sitting to a classifier keyed
    on old filename stems the same evening this field was ruled.  The fact is known HERE, at the only place that
    runs the compiler, and it travels as a value."""
    try:
        p = subprocess.run([str(scrip), "--dump-zeta", str(path)], stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=timeout, errors="replace")
    except subprocess.TimeoutExpired:
        return None, "timeout", "UNMEASURED"
    if p.returncode != 0:
        first = (p.stdout + p.stderr).strip().splitlines()
        return None, (f"rc={p.returncode}: {first[0][:120]}" if first else f"rc={p.returncode}"), "NEVER-EMITTED"
    graphs = parse_dump(p.stdout)
    if not graphs:
        return None, "no graph in the dump", "EMITTED-NO-LAYOUT"
    return graphs, "", ""


def dump_text(path):
    """dump_one's answer for a SAVED `--dump-zeta` text: the same parse, no compiler run; an unreadable file is UNMEASURED."""
    try:
        graphs = parse_dump(Path(path).read_text(errors="replace"))
    except OSError as e:
        return None, f"cannot read {path}: {e}", "UNMEASURED"
    if not graphs:
        return None, "no graph in the dump", "EMITTED-NO-LAYOUT"
    return graphs, "", ""


def wantrc_sidecar(lang, s4e_home):
    """THE DECLARATION IS ALREADY IN THE DATA (hq_raku, granted ceo CEO-1003 + cto, 2026-09-20).  A program the suite itself
    declares must not compile HAS no frame layout, and that is the correct and permanent answer rather than a refusal the
    census cannot tell from a compiler defect.  The declaration is DERIVED from the rungs' own ALL.wantrc -- the same
    sidecar util_raku_entry_grade.sh already grades rc against -- so it cannot go stale the way a hand-kept list does, and
    it is a declaration INSIDE the printed denominator rather than a narrowing of it: no_layout keeps its meaning as the
    TOTAL and the real defects stay counted as defects.
    Returns (map name->wantrc, note).  A sidecar that EXISTS and cannot be read REFUSES (raises); an ABSENT one is itself
    data -- the rungs declares no non-zero-rc entry -- and says so on its own line rather than defaulting silently."""
    d = Path(s4e_home) / "corpus" / "tests" / lang
    f = d / "ALL.wantrc"
    if not f.is_file():
        return {}, f"no ALL.wantrc beside {d} -- no entry can be DECLARED here, so every no_layout entry printed here is counted a defect; this is a measured zero, not a default"
    out = {}
    for line in f.read_text().splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 2:
            raise ValueError(f"{f}: line is not <entry>TAB<rc>: {line[:80]!r}")
        try:
            out[parts[0]] = int(parts[1].strip())
        except ValueError:
            raise ValueError(f"{f}: rc column is not an integer: {line[:80]!r}")
    return out, ""


def rungs_entries(lang, s4e_home):
    import corpus_suite_harness as H
    cfg = H.LANG_CONFIGS.get(lang) or (H.LANG_CONFIGS.get("") if lang == "snobol4" else None) or {"ext": ".sno", "comment_open": "*", "comment_close": ""}
    d = Path(s4e_home) / "corpus" / "tests" / lang
    src = d / ("ALL" + cfg["ext"]); ref = d / "ALL.ref"
    if not src.is_file() or not ref.is_file():
        return None, cfg["ext"], f"rungs {src} or {ref} missing", []
    banner_re = H.banner_re_for(cfg["comment_open"], cfg["comment_close"])
    try:
        entries = H.read_block_suite(str(src), str(ref), banner_re, in_path=H.sidecar_in_path(str(src)), x_path=H.sidecar_xfail_path(str(src)))
    except Exception:
        entries = H.read_suite(str(src), str(ref), in_path=H.sidecar_in_path(str(src)), x_path=H.sidecar_xfail_path(str(src)))
    inc = Path(os.environ.get("INC", str(Path(s4e_home) / "corpus" / "include")))
    return entries, cfg["ext"], "", [d, inc]


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--lang", default="", help="census this language's rungs suite (corpus/tests/<lang>/ALL.<ext>)")
    ap.add_argument("--files", nargs="*", default=[], help="census these programs instead of a rung suite")
    ap.add_argument("--dumps", nargs="*", default=[], help="census these saved `scrip --dump-zeta` texts instead of running scrip (the gates' detector arm corrupts one)")
    ap.add_argument("--timeout", type=float, default=8.0)
    ap.add_argument("--wantrc", default="", help="grade DECLARED against this ALL.wantrc instead of the rungs' own (the gate fixture seam; --files has no rungs)")
    a = ap.parse_args()
    s4e_home = os.environ.get("S4E_HOME", str(HERE.parent.parent))
    scrip = Path(os.environ.get("SCRIP", str((HERE.parent.parent / "SCRIP") / "scrip")))
    label = a.lang or ("dumps" if a.dumps else "files")
    if not scrip.is_file():
        print(f"zls-frame-map-census[{label}]: REFUSE(2): {scrip} is not a file"); return 2
    if (bool(a.lang) + bool(a.files) + bool(a.dumps)) != 1:
        print(f"zls-frame-map-census[{label}]: REFUSE(2): give exactly one of --lang, --files or --dumps"); return 2
    work = []
    wantrc = {}; wantrc_note = ""
    if a.wantrc:
        try:
            for line in Path(a.wantrc).read_text().splitlines():
                if not line.strip() or line.lstrip().startswith("#"):
                    continue
                parts = line.split("\t")
                if len(parts) < 2:
                    raise ValueError(f"{a.wantrc}: line is not <entry>TAB<rc>: {line[:80]!r}")
                wantrc[parts[0]] = int(parts[1].strip())
        except (OSError, ValueError) as e:
            print(f"zls-frame-map-census[{label}]: REFUSE(2): --wantrc {a.wantrc}: {e}"); return 2
    elif a.lang:
        try:
            wantrc, wantrc_note = wantrc_sidecar(a.lang, s4e_home)
        except (OSError, ValueError) as e:
            print(f"zls-frame-map-census[{label}]: REFUSE(2): the ALL.wantrc sidecar EXISTS and cannot be read, so a DECLARED no-layout cannot be told from a defect: {e}"); return 2
    tmp = tempfile.TemporaryDirectory(prefix="zls_census_")
    if a.lang:
        entries, ext, err, comp_dirs = rungs_entries(a.lang, s4e_home)
        if entries is None:
            print(f"zls-frame-map-census[{label}]: REFUSE(2): {err}"); return 2
        for e in entries:
            text = e.sno_lines[0] if e.kind == "line" else "\n".join(e.sno_lines)
            p = Path(tmp.name) / (re.sub(r"[^A-Za-z0-9_.-]", "_", e.name) + ext)
            p.write_text(text + "\n")
            import corpus_suite_harness as _H
            for _cd in comp_dirs:
                _H._copy_companions(text, str(_cd), tmp.name)
            work.append((e.name, p))
    else:
        for f in (a.files or a.dumps):
            work.append((f, Path(f)))
    list_all = os.environ.get("ZLS_LIST_ALL") == "1"
    cap = 40
    counts = {"region-gap": 0, "scope-gap": 0, "overlap": 0, "vslot-unmapped": 0, "provisional-kind": 0, "unknown-kind": 0}
    graded = 0; nolayout = []; graphs_n = 0; fields_n = 0; holes = 0; shown = 0; words_n = 0; unkinded_n = 0; zero_region = []
    for name, p in work:
        graphs, err, kind = dump_text(p) if a.dumps else dump_one(scrip, p, a.timeout)
        if graphs is None:
            nolayout.append((name, err, kind)); continue
        graded += 1
        for g in graphs:
            graphs_n += 1; words_n += g["region_end"] // 8
            if g["region_end"] == 0 or not any(sc["fields"] for sc in g["scopes"]):
                zero_region.append((name, g["name"], g["region_end"]))
            fields_n += sum(len(sc["fields"]) for sc in g["scopes"])
            for cls, sc, lo, hi, detail in holes_of(g):
                holes += 1; counts[cls] += 1; unkinded_n += (hi - lo + 7) // 8
                if list_all or shown < cap:
                    shown += 1
                    scn = f"scope={sc['id']}:{sc['name']}" if sc else "scope=-"
                    print(f"HOLE {cls} lang={label} entry={name} graph='{g['name']}' {scn} off=[{lo}..{hi}) {detail}")
    if holes > shown:
        print(f"... {holes - shown} more hole(s) not listed (ZLS_LIST_ALL=1 prints every one)")
    declared = [(n, e) for n, e, _k in nolayout if wantrc.get(n, 0) != 0]
    by_kind = {k: 0 for k in NO_LAYOUT_KINDS}
    for _n, _e, kind in nolayout:
        by_kind[kind] = by_kind.get(kind, 0) + 1
    for name, err, kind in nolayout:
        if wantrc.get(name, 0) != 0:
            print(f"NO-LAYOUT lang={label} entry={name} ({err}) [{kind}] [DECLARED wantrc={wantrc[name]}] -- the rungs declares this entry must not compile, so having no frame is correct and permanent, not a defect")
        else:
            print(f"NO-LAYOUT lang={label} entry={name} ({err}) [{kind}]")
    if sum(by_kind.values()) != len(nolayout):
        print(f"zls-frame-map-census[{label}]: REFUSE(2): {len(nolayout)} no-layout entr(ies) and {sum(by_kind.values())} placed in a kind -- an entry this census cannot place is not counted in any bucket and would vanish from both owners' work lists"); return 2
    if wantrc_note:
        print(f"NO-LAYOUT-SIDECAR lang={label} -- {wantrc_note}")
    for ent, gname, rend in zero_region[:40]:
        print(f"ZERO-REGION lang={label} entry={ent} graph='{gname}' region_end={rend} -- this graph EMITS and REGISTERS a frame map with NO layout entry, so every leaf boundary in it stores outside any mapped slot BY CONSTRUCTION. It is NOT no_layout, it counts inside graphs= and graded=, and it contributes 0 to fields= and 0 to holes=, so it PASSES EVERY HOLE-COUNTING INSTRUMENT BY CONSTRUCTION (hq_raku 2026-09-20, measured on gram__G__TOP: frame_bytes=64 header_bytes=48, a value region of exactly zero bytes, corrupt under every collection while the hole gate read PASS over 19476 fields and 0 holes)")
    if len(zero_region) > 40:
        print(f"... {len(zero_region) - 40} more ZERO-REGION graph(s) not listed")
    cls_s = " ".join(f"{k}={v}" for k, v in counts.items())
    print(f"ZLS-MAP lang={label} graphs={graphs_n} words={words_n} unkinded={unkinded_n} holes={holes} graded={graded} no_layout={len(nolayout)} no_layout_declared={len(declared)} no_layout_never_emitted={by_kind['NEVER-EMITTED']} no_layout_emitted_no_layout={by_kind['EMITTED-NO-LAYOUT']} no_layout_unmeasured={by_kind['UNMEASURED']} zero_region_graphs={len(zero_region)}")
    print(f"zls-frame-map-census[{label}]: entries={len(work)} graded={graded} no_layout={len(nolayout)} (declared={len(declared)} defect={len(nolayout) - len(declared)}) graphs={graphs_n} fields={fields_n} holes={holes} ({cls_s}) population=the zls region only; the wire header past region_end and the spine are not censused here")
    if graded == 0:
        print(f"zls-frame-map-census[{label}]: REFUSE(2): nothing graded"); return 2
    return 1 if holes else 0


if __name__ == "__main__":
    sys.exit(main())
