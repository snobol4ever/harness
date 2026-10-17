#!/usr/bin/env bash
# test_gate_no_xfail_survives.sh — THERE IS NO SUCH THING AS XFAIL (Lon 2026-09-03 21:30, in-chat to ceo, verbatim:
# "Also keep in mind there is no such thing now as XFAIL. We are shooting for 100%. So if an XFAIL is a faulty test
# than lets fix all those tests."). An xfail counts as FAIL for the score. This is THE ONE instrument for all seven
# languages -- one gate, not seven copies -- and it is RED while any suite still carries one.
#
# ⛔ IT COUNTS THE POPULATION, NEVER A PINNED NUMBER. Three independent sources, because the seven suites spell an
# xfail three different ways and a census that knew only one would report a confident zero for the others:
#     ALL.csv `xfail` column · ALL.xfail banner lines · *.xfail marker files
# ⭐ That is the whole reason this is one script rather than a grep: a single-source census reads pascal/rebus 0
# correctly and icon wrongly, and both look equally like an answer.
#
# ⛔⭐⭐ TWO DEFECTS CURED 2026-09-08 (hq_T, on the ceo's measurement; it was MY gate and MY error both times).
# (1) IT SUMMED THE THREE SPELLINGS INSTEAD OF UNIONING THEM, so one xfail was counted up to three times. MEASURED:
#     snobol4 read csv=27 + allxfail=54 + files=1 = 82 -- but ALL.xfail's 54 non-blank lines are 27 BANNERS AND 27
#     REASON LINES, one pair per entry, and those 27 are THE SAME 27 the csv column marks (overlap 27 of 27,
#     re-verified here per language, never assumed). The fleet total was inflated by roughly a quarter. ⭐ The trap
#     is that a sum of three true counts LOOKS like a careful multi-source census -- the sources were right and the
#     COMBINATOR was wrong, which no amount of checking a source would ever surface.
#     THE CURE IS TO COUNT ENTITIES, NOT LINES: each source now yields a SET OF NAMES and the language total is
#     their UNION. The per-source counts stay printed, plus the union and the overlap, so a future divergence
#     between spellings is visible instead of being silently added up.
# ⛔ (2) IT PRINTED "GATE RED" AND EXITED 0. A verdict line that contradicts the exit code is the same class as a
#     suite runner that prints FAIL=30 and returns success: a reader believes the words, a script believes the code,
#     and they are looking at different gates. REPORTED-not-blocking is a legitimate ramp -- what is not legitimate
#     is CLAIMING RED while returning success. It now says REPORTED and names why, and says RED only when it exits 1.
# ⛔ THE DEFAULT STAYS NON-BLOCKING, AND THAT IS NOT MINE TO CHANGE (ceo 2026-09-08, explicit): putting ~223 reds
#     into twelve seats' `make test` 33 hours before the announcement is LON'S call, not a script author's. Flip
#     with XFAIL_GATE_BLOCKING=1. The ramp exists so the gate cannot block the very landings that reduce the count.
set -u
GATE_NAME=test_gate_no_xfail_survives
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
T="$ROOT/corpus/tests"
LANGS="snobol4 icon prolog raku pascal snocone rebus"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -d "$T" ] || refuse "no corpus/tests at $T -- a census that cannot see the population is not a zero"
GRAND=0; MISSING=""
for l in $LANGS; do
    d="$T/$l"
    if [ ! -d "$d" ]; then MISSING="$MISSING $l"; continue; fi
    line=$(XF_DIR="$d" python3 - <<'PY'
import csv, os, re, sys
from pathlib import Path
d = Path(os.environ["XF_DIR"])
# ⛔ EACH SOURCE YIELDS NAMES, NEVER A COUNT. A count cannot be de-duplicated against another count.
csv_names, ax_names, fx_names = set(), set(), set()
c = d / "ALL.csv"
if c.is_file():
    try:
        rows = list(csv.DictReader(c.open()))
    except OSError:
        print("ERR"); raise SystemExit(0)
    if rows and "xfail" not in rows[0]:
        print("NOCOL"); raise SystemExit(0)
    # ⛔⭐ THE NAME COLUMN IS `entry`, NOT `name`, AND GETTING THAT WRONG FAILED SILENTLY TO ZERO. Caught in
    # this gate's own rewrite, 2026-09-08: the first cut read r.get("name"), which does not exist in ALL.csv
    # (columns are rank,entry,origin,family,kind,xfail,...), so every name was "" and snobol4 censused csv=0
    # where 27 rows carry xfail=1. ⭐ THAT IS THE EXACT DEFECT THIS GATE EXISTS TO CATCH, committed inside the
    # cure for it -- and the ROW COUNT was right the whole time, so only the union looked wrong. Hence the
    # arm below: the marked-row count and the extracted-name count must AGREE, or this refuses.
    marked = [r for r in rows if (r.get("xfail") or "0").strip() not in ("", "0")]
    for r in marked:
        nm = (r.get("entry") or r.get("name") or "").strip()
        if nm:
            csv_names.add(nm)
    if len(marked) != len(csv_names):
        print("NAMEGAP:%d:%d" % (len(marked), len(csv_names))); raise SystemExit(0)
a = d / "ALL.xfail"
if a.is_file():
    # ⛔ BANNER LINES ONLY. The file interleaves one banner per entry with one free-prose REASON line, so counting
    # non-blank lines double-counts every entry -- that was defect (1). The banner is the entity.
    for ln in a.read_text(encoding="utf-8", errors="replace").splitlines():
        m = re.match(r'^[*#/]-+\s+\d+\s+(\S+)\s+XFAIL\b', ln)
        if m:
            ax_names.add(m.group(1))
# ⛔⭐ ALL.xfail IS THE AGGREGATE REASON FILE, NOT A PER-ENTRY MARKER, AND IT MATCHES *.xfail. Caught by this
# gate's own fixture 2026-09-08: a scratch suite with ONE marker file censused files=2, because rglob picked up
# ALL.xfail and contributed a phantom entry named "ALL" -- so every language carrying an ALL.xfail read exactly
# one too many, and snobol4's real distinct count is 27, not 28. ⭐ A glob written for one shape quietly
# collecting a differently-shaped sibling is the unanchored-glob trap, and it survived the first pass of a
# rewrite whose entire subject was miscounting.
for p in d.rglob("*.xfail"):
    if p.name == "ALL.xfail":
        continue
    fx_names.add(p.stem)
union = csv_names | ax_names | fx_names
# overlap is REPORTED PER LANGUAGE and never assumed from another language's (ceo 2026-09-08, and the same clause
# hq_P earned by retracting a fleet number generalised from one suite).
pair = len(csv_names & ax_names)
print("%d %d %d %d %d" % (len(csv_names), len(ax_names), len(fx_names), len(union), pair))
PY
)
    case "$line" in
      ERR|NOCOL) refuse "$l: ALL.csv unreadable or has no xfail column ($line) -- cannot census, and a census that cannot see its population must not print 0";;
      NAMEGAP:*) refuse "$l: ALL.csv marks $(echo "$line" | cut -d: -f2) row(s) xfail but only $(echo "$line" | cut -d: -f3) name(s) could be read from them -- the name column moved, and a census that silently resolves names to nothing reports a confident ZERO for a suite that is full";;
    esac
    set -- $line; csv=$1; ax=$2; fx=$3; uni=$4; ov=$5
    GRAND=$((GRAND + uni))
    printf 'XFAIL_CENSUS lang=%-8s csv=%-4s allxfail=%-4s files=%-4s UNION=%-4s (csv∩allxfail=%s)\n' "$l" "$csv" "$ax" "$fx" "$uni" "$ov"
done
[ -z "$MISSING" ] || refuse "no suite directory for:$MISSING -- an unreachable suite is not a suite with zero xfails"
echo "XFAIL_TOTAL all_languages=$GRAND  (DISTINCT entries; this line summed line-counts across three spellings until 2026-09-08 and read high)"
if . "$HERE/lib_gate.sh" 2>/dev/null && command -v gate_stamp >/dev/null 2>&1; then gate_stamp; fi
if [ "$GRAND" -eq 0 ]; then
    echo "GATE PASS(0) [$GATE_NAME]: 0 xfails survive in any of the seven suites"
    exit 0
fi
echo "   $GRAND distinct xfail(s) survive across the seven suites — an xfail counts as FAIL (Lon 2026-09-03 21:30)."
echo "   Each is either a FAULTY TEST (fix it against its oracle, or delete it with the reason in the commit) or a REAL DEFECT (class row on its rung, cured)."
echo "   ⭐ A reason is the first step of a fix, not a resting place — the old 'every xfail reasoned' clauses are superseded."
if [ "${XFAIL_GATE_BLOCKING:-0}" = "1" ]; then
    echo "⛔ GATE RED(1) [$GATE_NAME]: $GRAND distinct xfail(s) survive (XFAIL_GATE_BLOCKING=1)."
    exit 1
fi
# ⛔ SAYS REPORTED BECAUSE IT RETURNS 0. Claiming RED while exiting success was defect (2) -- the verdict a human
# reads and the verdict a script reads must be the same verdict.
echo "⚠ GATE REPORTED(0) [$GATE_NAME]: $GRAND distinct xfail(s) survive, and this gate is deliberately NOT blocking"
echo "   (ceo 2026-09-08: whether ~$GRAND reds enter twelve seats' make test before the announcement is Lon's call)."
echo "   Set XFAIL_GATE_BLOCKING=1 to make it exit 1. It is REPORTING a real red, not passing."
exit 0
