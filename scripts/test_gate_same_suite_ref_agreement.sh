#!/usr/bin/env bash
# test_gate_same_suite_ref_agreement.sh -- THE SAME-SUITE TWIN of test_gate_cross_suite_ref_agreement.sh:
# TWO ENTRIES IN ONE RUNGS MUST NOT HOLD CONTRADICTORY REFS FOR A BYTE-IDENTICAL PROGRAM.
#
# ⛔ WHY THIS EXISTS (hq_B's find 2026-09-04, routed by ceo, task
# same-suite-contradictory-refs-gate-two-entries-one-program-two-answers): the Icon rungs held
# contradictory refs for one program that appeared TWICE UNDER TWO NAMES IN THE SAME RUNGS (not one rung suite
# vs a sibling suite, which the cross-suite gate already covers) -- and the cross-suite gate cannot see it,
# because its whole method is comparing ACROSS suites via the ALL.csv `origin` linkage; two entries that
# both live directly in ALL.<ext> never go through that linkage at all. Same defect class as row ICN4
# (a ref disagreement is invisible until something asks the ORACLE, and this gate still cannot say which
# side is right -- only that a disagreement exists), one level down: WITHIN a suite, not just between two.
#
# ⛔⭐ READS EVERY RUNGS THROUGH corpus_suite_harness.py's OWN reader, NEVER A HAND-ROLLED BANNER REGEX
# (CLAUDE.md: shared authorities are sourced, never reimplemented). The seven languages do NOT share one
# banner syntax -- each rung suite is delimited in ITS OWN comment style (icon/raku/rebus `#`, prolog `%`,
# pascal `{...}`, snocone `/*...*/`, snobol4 bare `*` one-line-tagged format A, no LANG_CONFIGS entry at
# all) -- and a single `#`-prefixed regex, tried first while building this row, silently parsed only 3 of
# 7 rung suites to zero visible error: the other four just produced zero sections and read as "nothing to
# compare" instead of REFUSING. `corpus_suite_harness.read_suite`/`read_block_suite` already carry the
# real per-dialect banner_re (via LANG_CONFIGS) AND the SNOBOL4 format-A/format-B mix, are exercised by
# the actual rungs builder (util_build_rungs_suite.py) on every push, and already parse the `.wantrc`
# sidecar into `Entry.want_rc` -- so this gate does not re-derive any of that, it asks the one place that
# already knows.
#
# METHOD: within each language's own rungs, group entries by their SOURCE BODY (banner/name excluded --
# that is what the shared reader already returns as `Entry.sno_lines`). Two or more entries sharing one
# body are, by construction, the same program under different names. For every such group (every entry is
# run-graded in both modes -- there is no modes column, CEO-1230) their ref
# bodies (progname-normalized, same reasoning as the cross-suite gate: a program that echoes
# &progname/its own name is not disagreeing, it is naming itself) and their `want_rc` must all agree. A
# group that does not is a contradiction: at least one ref or want_rc is wrong, named entry-vs-entry so
# the reader can take it to the oracle directly, exactly as the cross-suite gate's own closing line says.
#
# EXIT 0 no contradictions (over a real, nonzero population); 1 at least one contradiction (names them);
# 2 REFUSED -- cannot measure (no language's rungs was readable, or the population was empty: a green
# here would be an empty claim, same vacuity guard as the cross-suite gate).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
CORPUS="${CORPUS:-$S4E/corpus/tests}"
[ -d "$CORPUS" ] || { echo "⛔ GATE REFUSED (rc=2): cannot see $CORPUS -- nothing was checked" >&2; exit 2; }
python3 - "$HERE" "$CORPUS" <<'PY'
import io, os, sys, csv
from collections import defaultdict

scripts_dir, root = sys.argv[1], sys.argv[2]
sys.path.insert(0, scripts_dir)
import corpus_suite_harness as h   # the ONE authority on suite-file shape; never reimplemented here

EXT = {"snobol4": ".sno", "icon": ".icn", "prolog": ".pl", "raku": ".raku",
       "pascal": ".pas", "snocone": ".sc", "rebus": ".reb"}

langs = sorted(EXT)
checked_langs = 0
unreadable = []
total_groups = 0
total_pairs = 0
bad = []

for lang in langs:
    d = os.path.join(root, lang)
    srcp = os.path.join(d, "ALL" + EXT[lang])
    refp = os.path.join(d, "ALL.ref")
    if not (os.path.exists(srcp) and os.path.exists(refp)):
        continue
    # sidecar_in_path/_wantrc_path do their own "absent -> None" discovery -- not re-derived here.
    ip = h.sidecar_in_path(srcp)
    wp = h.sidecar_wantrc_path(srcp)
    try:
        if lang in h.LANG_CONFIGS:
            cfg = h.LANG_CONFIGS[lang]
            entries = h.read_block_suite(srcp, refp, h.banner_re_for(cfg["comment_open"], cfg.get("comment_close", "")),
                                          in_path=ip, w_path=wp)
        else:   # snobol4: no LANG_CONFIGS entry -- format-A/format-B mix, read_suite's own hardcoded dialect
            entries = h.read_suite(srcp, refp, in_path=ip, w_path=wp)
    except Exception as e:   # a parse exception IS "cannot read this rung suite" -- named, not silently skipped
        unreadable.append((lang, "%s: %s" % (type(e).__name__, e)))
        continue
    if not entries:
        unreadable.append((lang, "parsed to ZERO entries"))
        continue

    checked_langs += 1

    def body_of(e):
        return "\n".join(e.sno_lines)

    def ref_of(e):
        return e.ref if isinstance(e.ref, str) else "\n".join(e.ref)

    # ⛔⭐ THE GROUPING KEY IS (SOURCE, STDIN), NEVER SOURCE ALONE. Measured live building this row:
    # snobol4's arb_capture_alt_replace_branch_1/_2 share byte-identical source and read as a
    # "contradiction" (one ref real, one empty) under a source-only key -- but branch_1 and branch_2 feed
    # DIFFERENT stdin (ALL.in), so they are not two answers to the same question, they are two different
    # questions that happen to share a program. A "run" is source PLUS input; only entries sharing both
    # are evidence about the same execution, and only unequal outputs from equal (source, stdin) are ever
    # a real contradiction. Entries with no stdin at all use e.stdin is None, itself a valid group key.
    groups = defaultdict(list)
    for e in entries:
        groups[(body_of(e), e.stdin)].append(e)

    for (body, _stdin), es in groups.items():
        if len(es) < 2:
            continue
        mode = ''
        for mes in (es,):
            total_groups += 1
            total_pairs += len(mes) * (len(mes) - 1) // 2
            entry_refs = {e.name: ref_of(e).replace(e.name, '<PROGNAME>') for e in mes}
            entry_rc = {e.name: e.want_rc for e in mes}
            if len(set(entry_refs.values())) > 1 or len(set(entry_rc.values())) > 1:
                bad.append((lang, mode, [e.name for e in mes], entry_refs, entry_rc))

print("same-suite ref agreement: %d language(s) checked, %d duplicate-body group(s), %d pair(s) compared"
      % (checked_langs, total_groups, total_pairs))
if unreadable:
    for lang, why in unreadable:
        print("  ⛔ [%s] UNREADABLE, skipped: %s" % (lang, why))
if bad:
    sys.stderr.write("⛔ GATE FAIL (rc=1): CONTRADICTORY REFS/want_rc for byte-identical programs WITHIN ONE rungs:\n")
    for lang, mode, names, entry_refs, entry_rc in bad:
        sys.stderr.write("    [%s] %s\n" % (lang, ", ".join(names)))
        for n in names:
            sys.stderr.write("        %-40s want_rc=%d ref=%r\n" % (n, entry_rc[n], entry_refs[n][:100]))
    sys.stderr.write("  ⛔ This gate cannot say WHICH side is right -- run the ORACLE on the program and re-cut the loser.\n")
    sys.stderr.write("     Do NOT change the compiler to satisfy a ref until the oracle has spoken (row ICN4, 2026-09-03).\n")
    sys.exit(1)
if total_pairs == 0:
    sys.stderr.write("⛔ GATE REFUSED (rc=2): 0 same-suite duplicate-body pairs found across %d checked language(s) "
                      "-- a green here would be an empty claim\n" % checked_langs)
    sys.exit(2)
print("✅ GATE OK: every byte-identical program sharing a rung suite carries the same ref and want_rc")
PY
