#!/usr/bin/env bash
# test_gate_score_row_denominator_includes_xfails.sh -- ROW-LEVEL GATE: EVERY SUITES.tsv ROW'S PUBLISHED DENOMINATOR IS
# THE CEO-749 IDENTITY  PASS + FAIL + OUTSIDE-BASELINE + UNGRADABLE + UNGRADED + DEFERRED == population,
# re-derived from the progress DB on the row's OWN tree plus the suite's OUTSIDE sidecar (coo, CEO-780b, 2026-09-16;
# row test-gate-score-row-denominator-includes-xfails-refuses-on-every-tree-under-ceo-753-rewrite-it-to-police-the-ceo-749-identity).
#
# ⛔ WHAT THIS FILE USED TO ASSERT, AND WHY IT IS GONE: hq_T's 2026-09-08 gate (on the coo's ask; CEO-416 "an xfail counts as a
# FAIL, so it sits in the denominator") read a RUNNER-PUBLISHED `xfail=` count out of SCORE.md's Rungs board cell and checked
# total >= pass + xfail. Under CEO-753 (2026-09-14) THERE IS NO XFAIL -- the builder that mints one is the defect and no rungs
# cell publishes an xfail= count -- so from that day the gate REFUSED rc=2 on every tree (measured 2026-09-16 11:1x on 61315eaa9
# and 11:21 on 0a3f38904): a standing rc=2 in `make test` for ten seats, asking for a number the law forbids. The property it
# protected (a known red stays in the denominator) is now the wider CEO-749 identity, and the evidence is the DB, not a cell.
#
# HOW A ROW IS GRADED: on the row's tree (SUITES.tsv column `tree`) every progress row of the suite in m3/m4 gives each program
# its LAST outcome per mode; a program is PASS when every mode it declares reads PASS, OUTSIDE when any mode reads OUTSIDE or
# the suite's sidecar names it, DEFERRED when any mode reads DEFERRED, UNGRADABLE when every mode reads UNGRADABLE, UNGRADED when
# every mode reads UNGRADED/SKIP/MISSING/UNPROVEN, else FAIL (FAIL, CRASH, HANG, REJECT, REFUSE, XFAIL, or a mixed pair);
# sidecar entries with no DB row are OUTSIDE too. The population is the union, and the row AGREES when its published total
# equals it. A row whose tree has NO DB rows is UNPROVEN and NAMED (CEO-750: a row without per-program evidence is DARK wearing
# a number); a row with no tree and a DEFERRED criterion (gnu_fd, CEO-579) is DEFERRED by ruling and agrees when its total is
# the deferred count it states. THE NUMERATOR is not this gate's question: util_suite_rows_vs_progress.py (the batch audit,
# CEO-780a) reads pass vs DB PASS, with the xpass discriminator (the DB folds XPASS into PASS, a board does not -- hq_snocone).
#
# VERDICT: rc=0 when every graded row agrees (population printed: graded, agree, disagree named, unproven named); rc=1 under
# --strict when a graded row DISAGREES (each named with its total, the DB population and the difference by class); without
# --strict a disagreement is PRINTED and the rc stays 0 -- report-only in `make test` today because the SNOBOL4 package rows
# disagree by a class the runners themselves split (row snobol4-three-runners-split-ungraded-between-inventory-and-append,
# hq_snobol4) and a blocking red there would dark every arm after it for ten seats; the row that flips this arm to --strict is
# minted when that row closes. rc=2 ONLY when zero rows are gradable (no SUITES.tsv, no DB, or no row with DB rows on its tree).
# --selftest builds a scratch SUITES.tsv, DB and corpus under mktemp with one agreeing row, one DEFERRED row and ONE PLANTED
# DISAGREEMENT, and proves: report mode prints the planted row and exits 0, --strict exits 1 naming it, an empty DB exits 2.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STRICT=0; SELFTEST=0
for a in "$@"; do case "$a" in --strict) STRICT=1;; --selftest) SELFTEST=1;; *) echo "usage: $0 [--strict] [--selftest]" >&2; exit 2;; esac; done
if [ "$SELFTEST" = 1 ]; then
  W="$(mktemp -d "${TMPDIR:-/tmp}/gate_denominator_identity.XXXXXX")" || { echo "⛔ GATE REFUSES (rc=2): mktemp failed"; exit 2; }
  trap 'rm -rf "$W"' EXIT
  mkdir -p "$W/corpus/tests/snobol4" "$W/corpus/packages/snobol4/gimpel"
  printf '# fixture\nkey\tnick\temoji\tlang\tfirst_date\tfirst_pass\tfirst_total\ttoday_date\ttoday_pass\ttoday_total\ttree\tcriterion_changed\n' > "$W/SUITES.tsv"
  printf 'sno-rungs\tSnoM\tx\tsnobol4\t2026-09-06\t1\t3\t2026-09-16\t2\t4\tfeedbeef1\tfixture\n' >> "$W/SUITES.tsv"      # 2 PASS + 1 FAIL + 1 sidecar OUTSIDE = 4: AGREE
  printf 'gimpel\tGimpel\tx\tsnobol4\t2026-09-04\t1\t2\t2026-09-16\t1\t2\tfeedbeef1\tfixture\n' >> "$W/SUITES.tsv"          # 1 PASS + 1 FAIL + 1 UNGRADED = 3, row says 2: PLANTED DISAGREE
  printf 'gnu_fd\tGnuFD\tx\tprolog\t\t\t\t\t\t30\t\tDEFERRED by ruling CEO-579: 30 FD programs\n' >> "$W/SUITES.tsv"       # DEFERRED by ruling: AGREE
  printf 'roast\tRoast\tx\traku\t2026-09-03\t4\t986\t2026-09-13\t6\t986\tdeadbeef2\tfixture\n' >> "$W/SUITES.tsv"           # no DB rows on its tree: UNPROVEN, named
  printf 'p_out\tORACLE_REFUSES\tfixture\n' > "$W/corpus/tests/snobol4/ALL.outside.tsv"
  DB="$W/results.tsv"; printf 'ts_utc\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome\tsecs\tnote\n' > "$DB"
  row(){ printf '2026-09-16T00:00:00\t%s\tc\tfixture\trungs\t%s\tsnobol4\t%s\t%s\t%s\t0\t\n' "$1" "$2" "$3" "$4" "$5" >> "$DB"; }
  for m in m3 m4; do row feedbeef1 snobol4-rungs p1 $m PASS; row feedbeef1 snobol4-rungs p2 $m PASS; row feedbeef1 snobol4-rungs p3 $m FAIL; done
  row feedbeef1 snobol4-rungs p2 m3 FAIL; row feedbeef1 snobol4-rungs p2 m3 PASS   # last row wins: p2 is PASS
  for m in m3 m4; do row feedbeef1 gimpel g1 $m PASS; row feedbeef1 gimpel g2 $m CRASH; row feedbeef1 gimpel g3 $m UNGRADED; done
  fails=0; ck(){ if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
  echo "=== selftest: the identity gate on a planted fixture ==="
  out="$(S4E_SUITES_TSV="$W/SUITES.tsv" S4E_PROGRESS_DB="$DB" S4E_CORPUS_ROOT="$W/corpus" bash "$0")"; rc=$?
  { [ "$rc" = 0 ] && grep -q 'gimpel.*DISAGREE' <<<"$out" && grep -q 'sno-rungs.*AGREE' <<<"$out" && grep -q 'gnu_fd.*DEFERRED' <<<"$out" && grep -q 'roast.*UNPROVEN' <<<"$out"; } \
    && ck ok "(a) report mode: AGREE, the planted DISAGREE, DEFERRED by ruling and UNPROVEN are each printed by name, rc=0" \
    || ck no "(a) report mode rc=$rc -- got: $out"
  out="$(S4E_SUITES_TSV="$W/SUITES.tsv" S4E_PROGRESS_DB="$DB" S4E_CORPUS_ROOT="$W/corpus" bash "$0" --strict)"; rc=$?
  { [ "$rc" = 1 ] && grep -q 'gimpel' <<<"$out" && grep -qi 'disagree' <<<"$out"; } \
    && ck ok "(b) --strict: the planted disagreement is RED, rc=1, gimpel named (row 2 vs population 3)" \
    || ck no "(b) --strict rc=$rc -- got: $out"
  sed -i '/^gimpel\t/d' "$W/SUITES.tsv"
  out="$(S4E_SUITES_TSV="$W/SUITES.tsv" S4E_PROGRESS_DB="$DB" S4E_CORPUS_ROOT="$W/corpus" bash "$0" --strict)"; rc=$?
  [ "$rc" = 0 ] && ck ok "(c) --strict with the planted row removed: rc=0 (the strict arm is not red by construction)" || ck no "(c) --strict rc=$rc without the planted row -- got: $out"
  printf 'ts_utc\tscrip\tcorpus\tmeasurer\tclass\tsuite\tlang\tprogram\tmode\toutcome\tsecs\tnote\n' > "$DB"
  out="$(S4E_SUITES_TSV="$W/SUITES.tsv" S4E_PROGRESS_DB="$DB" S4E_CORPUS_ROOT="$W/corpus" bash "$0")"; rc=$?
  [ "$rc" = 2 ] && ck ok "(d) an empty DB: rc=2 REFUSES, no verdict printed as success" || ck no "(d) empty DB rc=$rc -- got: $out"
  echo "population: 4 selftest arm(s), $fails FAIL"
  [ "$fails" = 0 ] && { echo "GATE PASS [score_row_denominator_identity --selftest]: 4 of 4 arms hold"; exit 0; }
  echo "⛔ GATE RED [score_row_denominator_identity --selftest]: $fails of 4 arms FAIL"; exit 1
fi
SUITES="$(. "$HERE/lib_suites_tsv.sh"; suites_tsv "$(cd "$HERE/../.." && pwd)")"
DB="${S4E_PROGRESS_DB:-/home/resources/progress/results.tsv}"
CORPUS="${S4E_CORPUS_ROOT:-$HERE/../../corpus}"
[ -r "$SUITES" ] || { echo "⛔ GATE REFUSES (rc=2): cannot read SUITES.tsv at $SUITES"; exit 2; }
[ -r "$DB" ] || { echo "⛔ GATE REFUSES (rc=2): cannot read the progress DB at $DB"; exit 2; }
python3 - "$SUITES" "$DB" "$CORPUS" "$STRICT" <<'PY'
import sys, os, re, collections
suites, db, corpus, strict = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1"
# SUITES.tsv key -> progress DB suite name (the rung suites carry a -rungs suffix in the DB; x64tests appends as spitbol_x64)
DBNAME = {"sno-rungs": "snobol4-rungs", "icn-rungs": "icon-rungs", "pl-rungs": "prolog-rungs", "pas-rungs": "pascal-rungs",
          "raku-rungs": "raku-rungs", "snc-rungs": "snocone-rungs", "reb-rungs": "rebus-rungs", "x64tests": "spitbol_x64", "x32tests": "spitbol_x32"}
# the OUTSIDE-BASELINE sidecars (ORACLE_REFUSES / NEEDS_VENDORED_SOURCE entries), relative to the corpus root
SIDECAR = {"sno-rungs": "tests/snobol4/ALL.outside.tsv",
           "gimpel": "packages/snobol4/gimpel/OUTSIDE_SPITBOL_BASELINE.tsv",
           "csnobol4": "packages/snobol4/csnobol4_suite/OUTSIDE_SPITBOL_BASELINE.tsv",
           "snoflake": "packages/snobol4/snoflake_suite/OUTSIDE_SPITBOL_BASELINE.tsv",
           "aisnobol": "packages/snobol4/aisnobol/OUTSIDE_SPITBOL_BASELINE.tsv",
           "dotnet": "packages/snobol4/dotnet/OUTSIDE_SPITBOL_BASELINE.tsv",
           "testpgms": "packages/snobol4/spitbol_testpgms/OUTSIDE_SPITBOL_BASELINE.tsv",
           "arizona": "packages/icon/arizona_tests/OUTSIDE_ARIZONA_BASELINE.tsv",
           "jcon": "packages/icon/jcon_tests/OUTSIDE_ARIZONA_BASELINE.tsv"}
def stem(n):
    n = n.split("/")[-1]
    return re.sub(r"\.(sno|spt|sc|icn|pl|reb|raku|pas)$", "", n)
rows = []
for line in open(suites, encoding="utf-8"):
    if line.startswith("#") or line.startswith("key") or not line.strip(): continue
    c = line.rstrip("\n").split("\t")
    while len(c) < 12: c.append("")
    rows.append(c)
if not rows:
    print("⛔ GATE REFUSES (rc=2): SUITES.tsv carries no rows"); sys.exit(2)
want = {}
for c in rows:
    if c[10]: want[(DBNAME.get(c[0], c[0]), c[10])] = c[0]
last = {}
with open(db, encoding="utf-8") as fh:
    fh.readline()
    for line in fh:
        f = line.rstrip("\n").split("\t")
        if len(f) < 10 or (f[5], f[1]) not in want or f[8] not in ("m3", "m4"): continue
        last[(f[5], f[1], f[7], f[8])] = f[9]
progs = collections.defaultdict(lambda: collections.defaultdict(dict))
for (s, t, p, m), o in last.items(): progs[(s, t)][p][m] = o
UNG = {"UNGRADED", "SKIP", "MISSING", "UNPROVEN"}
def classify(mm, outside_named):
    v = set(mm.values())
    # the runner's recorded class outranks the sidecar (ceo CEO-799): a sidecar-named entry WITH a DB row keeps the DB's class;
    # the sidecar classes only an entry the DB has no row for (Budne: 49 declared, 22 measured today, 27 UNGRADABLE debt)
    if "OUTSIDE" in v: return "OUTSIDE"
    if outside_named and not v: return "OUTSIDE"
    if "DEFERRED" in v: return "DEFERRED"
    if v == {"PASS"}: return "PASS"
    if v == {"UNGRADABLE"}: return "UNGRADABLE"
    if v <= UNG: return "UNGRADED"
    return "FAIL"
graded = agree = 0; disagree = []; unproven = []; deferred = []
print("key          row   pass/total tree       PASS  FAIL  OUTSIDE UNGRADABLE UNGRADED DEFERRED = population   verdict")
for c in rows:
    key, nick, P, T, tree, crit = c[0], c[1], c[8], c[9], c[10], c[11]
    tag = f"{key:12} {nick:6} {(P or '-')+'/'+(T or '-'):>10} {(tree or '-'):10}"
    if not tree and "DEFERRED" in crit.upper():
        n = int(T) if T.isdigit() else 0
        deferred.append(key); print(f"{tag} {0:>5} {0:>5} {0:>8} {0:>10} {0:>8} {n:>8} = {n:>10}   DEFERRED by ruling ({crit[:60]})"); continue
    if not tree:
        unproven.append(key); print(f"{tag} {'-':>5} {'-':>5} {'-':>8} {'-':>10} {'-':>8} {'-':>8} = {'-':>10}   UNPROVEN: no tree on the row (never measured)"); continue
    side = set(); ungradable = set(); ungraded = set()
    sc = SIDECAR.get(key)
    if sc and os.path.exists(os.path.join(corpus, sc)):
        for l in open(os.path.join(corpus, sc), encoding="utf-8", errors="replace"):
            if l.startswith("#") or not l.strip(): continue
            side.add(stem(l.split("\t")[0].strip()))
    # read whether or not the OUTSIDE file exists: a package whose last OUTSIDE row was graded deletes it, and its UNGRADED rows stand
    if sc:
        # ⛔ THE PACKAGE INVENTORY IS THE POPULATION AUTHORITY (ceo CEO-798, 2026-09-16): the runner's PACKAGE_INVENTORY line counts
        # shipped = graded + ungraded + ungradable, and the package keeps UNGRADABLE.tsv / UNGRADED.tsv beside its OUTSIDE file
        # (csnobol4: 61 UNGRADABLE of which the 49 OUTSIDE are a subset, 12 containers/libraries; 71 graded; 132 shipped). Read
        # both, OUTSIDE taking precedence, so the population this gate prints is the inventory's, never DB-plus-OUTSIDE alone.
        for fn, dst in (("UNGRADABLE.tsv", ungradable), ("UNGRADED.tsv", ungraded)):
            fp = os.path.join(corpus, os.path.dirname(sc), fn)
            if os.path.exists(fp):
                for l in open(fp, encoding="utf-8", errors="replace"):
                    if l.startswith("#") or not l.strip(): continue
                    dst.add(stem(l.split("\t")[0].strip()))
        ungradable -= side; ungraded -= side | ungradable
    d = progs.get((DBNAME.get(key, key), tree), {})
    if not d:
        unproven.append(key); print(f"{tag} {'-':>5} {'-':>5} {len(side):>8} {'-':>10} {'-':>8} {'-':>8} = {'-':>10}   UNPROVEN: no progress rows for this suite on {tree} (CEO-750)"); continue
    cnt = collections.Counter()
    seen = set()
    for p, mm in d.items():
        seen.add(stem(p)); cnt[classify(mm, stem(p) in side)] += 1
    cnt["OUTSIDE"] += len(side - seen)
    cnt["UNGRADABLE"] += len(ungradable - seen)
    cnt["UNGRADED"] += len(ungraded - seen)
    pop = sum(cnt.values())
    graded += 1
    t = int(T) if T.isdigit() else -1
    line = f"{tag} {cnt['PASS']:>5} {cnt['FAIL']:>5} {cnt['OUTSIDE']:>8} {cnt['UNGRADABLE']:>10} {cnt['UNGRADED']:>8} {cnt['DEFERRED']:>8} = {pop:>10}"
    if t == pop:
        agree += 1; print(f"{line}   AGREE")
    else:
        disagree.append(f"{key}: row total {T} vs population {pop} ({t-pop:+d})")
        print(f"{line}   DISAGREE: row total {T}, population {pop}, difference {t-pop:+d}")
print(f"population: {len(rows)} row(s): {graded} graded, {agree} agree, {len(disagree)} disagree, {len(unproven)} unproven ({', '.join(unproven) or 'none'}), {len(deferred)} deferred by ruling ({', '.join(deferred) or 'none'})")
if graded == 0:
    print("⛔ GATE REFUSES (rc=2): zero rows gradable -- no SUITES.tsv row has progress rows on its own tree; this gate measured nothing."); sys.exit(2)
if disagree:
    print(f"{'⛔ GATE RED' if strict else '⚠ REPORT'} [score_row_denominator_identity]: {len(disagree)} of {graded} graded row(s) DISAGREE with the CEO-749 identity:")
    for x in disagree: print("    " + x)
    print("    cure: the row's writer publishes the population the identity gives (OUTSIDE stays in the denominator, CEO-749; an UNGRADED or UNGRADABLE entry is in the population, never dropped), or the runner's append is fixed so the DB carries what the board counts (CEO-750).")
    if strict: sys.exit(1)
    print("    (report-only: pass --strict to make this rc=1; the Makefile arm flips to --strict when the SNOBOL4 runner rows close)")
    sys.exit(0)
print(f"✅ GATE OK [score_row_denominator_identity]: {agree}/{graded} graded row(s) satisfy PASS+FAIL+OUTSIDE+UNGRADABLE+UNGRADED+DEFERRED == population on their own tree.")
PY
