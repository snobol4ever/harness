#!/usr/bin/env bash
# test_gate_rungs_order_is_the_builders_order.sh -- THE COMMITTED RUNGS IS SORTED THE WAY ITS BUILDER SORTS.
# Row promotion-re-sorts-the-master-so-rank-stays-the-greenest-prefix (ceo ruling 2026-09-03, on hq_B's
# routed question; FINDING-2026-09-03-hq_B-a-promotion-changes-an-entrys-sort-key-*).
#
# THE LAW IT GUARDS is Lon's, not the builder's: "a smoke test would be say the first 20-50 tests... then
# another level at 100-200... the last level all 1200+". A LEVEL IS A PREFIX, so `rank <= N` must select the
# GREENEST N -- green before xfail, then fewer features, then shorter, then name.
# ⛔ WHAT BREAKS IT IS NOT AN EDIT TO THE ORDER, IT IS A PROMOTION. Flipping an entry's xfail changes its SORT
# KEY, so a promotion that only rewrites the three marker locations leaves the file sorted under the old key.
# Measured 2026-09-03 after the seven prolog promotions of corpus 2b71e9a2: 265 of 404 entries out of order,
# with nothing inconsistent -- ALL.pl and ALL.csv agreed with each other, every marker gate was green, and the
# only thing wrong was that the law had quietly stopped being true.
# ⭐ THE KEY IS IMPORTED FROM THE BUILDER (rungs_file_key), NEVER RE-TYPED HERE. A guard carrying its own copy
# of the rule drifts from the thing it guards and then both are wrong together.
# ⛔ rungs_file_key, NOT rungs_sort_key (measured 2026-09-05): write_suite() always emits every kind="line"
# entry before every other kind (a format-(B) block ends only at the next banner or EOF, so a trailing
# one-liner would be silently swallowed into it), so plain rungs_sort_key describes an order SNOBOL4's mixed
# format-A/format-B rungs cannot physically store. rungs_file_key partitions by kind first, then applies
# rungs_sort_key within each kind -- byte-identical to rungs_sort_key for every other (single-kind) rungs.
# LANGS= overrides the rung suites checked (default: every corpus/tests/<lang>/ carrying an ALL.csv).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
refuse(){ echo "⛔ REFUSED-TO-GRADE: $*"; exit 2; }
[ -f "$HERE/util_build_rungs_suite.py" ] || refuse "builder not found -- the sort key has no authority to import"
python3 - "$HERE" "$S4E" "${LANGS:-}" <<'PY'
import importlib.util, os, sys, csv, io
here, s4e, langs_arg = sys.argv[1], sys.argv[2], sys.argv[3]
spec = importlib.util.spec_from_file_location("mb", os.path.join(here, "util_build_rungs_suite.py"))
mb = importlib.util.module_from_spec(spec)
sys.argv = ["util_build_rungs_suite.py"]          # the module parses argv at import in some builds
try:
    spec.loader.exec_module(mb)
except SystemExit:
    print("⛔ REFUSED-TO-GRADE: importing the builder exited; cannot borrow its sort key"); sys.exit(2)
if not hasattr(mb, "rungs_file_key"):
    print("⛔ REFUSED-TO-GRADE: the builder has no rungs_file_key -- this gate must not re-type the rule"); sys.exit(2)
sys.path.insert(0, here)
import corpus_suite_harness as h
EXTS = {"snobol4": ".sno", "icon": ".icn", "prolog": ".pl", "raku": ".raku", "snocone": ".sc", "rebus": ".reb", "pascal": ".pas"}
langs = [l for l in (langs_arg.split(",") if langs_arg else sorted(EXTS)) if l]
checked = 0; bad = 0
for lang in langs:
    d = os.path.join(s4e, "corpus", "tests", lang)
    ext = EXTS[lang]
    sno, ref, csvp = os.path.join(d, "ALL" + ext), os.path.join(d, "ALL.ref"), os.path.join(d, "ALL.csv")
    if not (os.path.isfile(sno) and os.path.isfile(ref) and os.path.isfile(csvp)):
        continue
    cfg = h.LANG_CONFIGS.get(lang)
    if lang == "snobol4":
        entries = h.read_suite(sno, ref, in_path=h.sidecar_in_path(sno), x_path=h.sidecar_xfail_path(sno))
    else:
        entries = h.read_block_suite(sno, ref, h.banner_re_for(cfg["comment_open"], cfg["comment_close"]),
                                     in_path=h.sidecar_in_path(sno), x_path=h.sidecar_xfail_path(sno))
    if not entries:
        print("  REFUSE %-9s read 0 entries" % lang); sys.exit(2)
    # ⛔ COLS IS PER-LANGUAGE AND main() REBINDS IT AS A GLOBAL; importing the module leaves the SNOBOL4
    # default bound, so computing a prolog/raku/pascal key with it silently scores the wrong features and
    # invents a disorder that is not there (measured: it claimed 403 of 404 prolog entries out of order
    # against a real 265). Take the table from the builder's own LANG_TABLES, never from the module global.
    if lang not in mb.LANG_TABLES:
        print("⛔ REFUSED-TO-GRADE: %s is not in the builder's LANG_TABLES" % lang); sys.exit(2)
    cols = mb.LANG_TABLES[lang][0]
    got = [e.name for e in entries]
    keyed = sorted(entries, key=lambda e: mb.rungs_file_key(e, {c: fn("\n".join(e.sno_lines)) for c, fn in cols}))
    want = [e.name for e in keyed]
    checked += 1
    if got == want:
        print("  ok    %-9s %d entries in the builder's order" % (lang, len(entries)))
    else:
        n = sum(1 for a, b in zip(got, want) if a != b)
        first = next((i for i, (a, b) in enumerate(zip(got, want)) if a != b), -1)
        print("  FAIL  %-9s %d of %d entries out of order (first at index %d: committed %r, builder %r)"
              % (lang, n, len(entries), first, got[first], want[first]))
        print("        a promotion changed a sort key without re-sorting: `rank <= N` no longer selects the greenest N")
        bad += 1
if checked == 0:
    print("⛔ REFUSED-TO-GRADE [rungs_order_is_the_builders_order]: no rungs found under %s/corpus/tests -- nothing was checked" % s4e); sys.exit(2)
print("------------------------------------------------------------")
if bad:
    print("⛔ GATE FAIL [rungs_order_is_the_builders_order]: %d of %d rung suite(s) not in the builder's order" % (bad, checked))
    print("   CURE: python3 ../harness/scripts/util_build_rungs_suite.py --lang <l> --resort (it REFUSES while a family is loose; pass those names to --absorb-only to acknowledge, --resort is terminal and absorbs nothing)"); sys.exit(1)
print("✅ GATE PASS [rungs_order_is_the_builders_order]: %d rung suite(s) in the builder's order" % checked); sys.exit(0)
PY
