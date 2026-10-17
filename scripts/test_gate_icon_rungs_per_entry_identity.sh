#!/usr/bin/env bash
# test_gate_icon_rungs_per_entry_identity.sh — THE ICON RUNGS GRADED BY PER-ENTRY IDENTITY, NOT BY A FLOOR.
# Authors: LCherryholmes · Claude Opus 5   DATE: 2026-09-06   (row icon-master-board-grades-per-entry-identity-not-a-floor)
#
# ⛔⭐⭐ THE MEASURED INCIDENT THIS EXISTS TO KILL. `board_icon_rungs.sh` scores the rungs with a PASS FLOOR.
# On 2026-09-04 that floor stood at 596 while the tree carried 601 passes; two programs then regressed
# (procedure_write_image_1, procedure_record_every_replace_2), the board fell 601 -> 599, and it printed
# "watermarks held" — because 599 is still above 596 — and then INVITED A RE-PIN at the lower number. Every
# arm of that behaved exactly as written. The defect is the instrument: a floor scores a SET BY A SCALAR, so
# it cannot distinguish "the same 599 entries pass" from "599 pass, but not the same 599". hq_T states the
# general form as a three-member rule — pinned population, carried max, floor — and a single number carries
# at most one of the three.
#
# ⛔ AND THE WORST CASE IS NOT A DROP, IT IS A SWAP. Two entries regress while two others get cured in the
# same window and the count NEVER MOVES. A floor is silent by construction; so is a watermark; so is any
# delta. Only per-entry identity can see it, and the cure that hid behind the swap is indistinguishable from
# a clean day in every board this project has ever printed.
#
# WHAT THIS GATE DOES, AND THE ONE THING IT DELIBERATELY DOES NOT.
#   It pins, per (entry, mode), the outcome the tree already holds, and REDS when a pinned PASS stops passing
#   or a pinned entry stops being graded at all. It does NOT red on the reverse — an entry that starts passing
#   is reported and asked to be re-pinned in the commit that earned it. Growth needs no re-pin (RULES.md § the
#   denominator law); a regression needs a verdict.
#
# ⛔⭐ THE BASELINE IS KEYED ON `origin`, NOT ON THE ENTRY NAME, AND THAT IS NOT A DETAIL. The suite builder
# RENUMBERS entries (`procedure_10`, `directive_82`) every time the rungs is rebuilt, and ALL.csv names
# `origin` as the durable provenance key for exactly that reason. A baseline keyed on the display name would
# go mass-VANISHED plus mass-NEW on the next rebuild — a wall of false red that trains its reader to re-pin
# without looking, which is the floor's own failure with more steps.
#
# ⛔ AST-GRADED ENTRIES ARE PINNED FOR POPULATION AND REPORTED FOR OUTCOME, NEVER RED ON OUTCOME. Their .ref
# is SCRIP's own past self-dumped AST (ast-dump-refs-are-self-pins-not-oracles): no oracle emits SCRIP's AST
# shape, so a drift there means RE-DECIDE THE SHAPE AND REGENERATE, never "a program broke". But a vanished
# ast entry IS red like any other — losing a fixture from the population is a coverage loss whoever grades it.
#
# ⛔ IT NEVER TOUCHES THE LIVE PROGRESS TABLE. The run records its per-entry rows to a SCRATCH S4E_PROGRESS_DB,
# which is the documented control arm in util_progress_append.py ("gates use a scratch file; the live table is
# never touched by a gate"). It also writes NO SCORE.md cell: under CEO-308 the icon board cell is owned by
# `board_icon_rungs.sh` and a second runner over a second population writing that cell is the exact defect
# CEO-308 ruled on. This gate is a control arm, and control arms live in the ledger.
#
# CONTROL ARMS (all announce themselves; none can quietly produce a green):
#   FAIL_ONCE=1 [or FAIL_ONCE=<origin>]  inject ONE pinned-PASS entry as FAIL after the real run and re-grade.
#                                        Proves the comparison can say no. REFUSES rc=2 if the injection does
#                                        not register — an identity gate that cannot fail on an injected red
#                                        entry is the floor defect wearing a new name, which is this row.
#   ICON_IDENTITY_MEASURED_FROM=<tsv>    grade an ALREADY-MEASURED progress table instead of running the suite.
#   ICON_IDENTITY_BASELINE=<tsv>         grade against a different pin (used by the fail-once proof in a scratch).
#   --repin                              rewrite the baseline FROM A RUN. Never from typing; see cmd_pin_ref's
#                                        rule in the harness — text typed by hand is a claim about behaviour,
#                                        output from a run is evidence of it.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_gate.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_gate.sh -- the ONE gate-honesty authority." >&2; exit 3; }
GATE_NAME="test_gate_icon_rungs_per_entry_identity"
gate_parse_args "$@"
ROOT="$HERE/../../SCRIP"
SCRIP_BIN="${SCRIP:-$ROOT/scrip}"
RT="${RT_DIR:-$ROOT/out}"
CORPUS="${CORPUS:-$S4E/corpus/tests/icon}"
HARNESS="$HERE/corpus_suite_harness.py"
BASE="${ICON_IDENTITY_BASELINE:-$HERE/icon_rungs_identity_baseline.tsv}"
BUDGET="${ICON_IDENTITY_BUDGET:-1800}"
PAIR_FLOOR="${ICON_IDENTITY_PAIR_FLOOR:-1000}"
REPIN=0
for a in "$@"; do [ "$a" = "--repin" ] && REPIN=1; done
gate_require_exec "$SCRIP_BIN" "scrip binary"
gate_require "$RT/libscrip_rt.so" "runtime library"
gate_require "$HARNESS" "corpus_suite_harness.py"
gate_require "$CORPUS/ALL.icn" "the Icon rungs suite"
gate_require "$CORPUS/ALL.ref" "the Icon rungs suite's expected output"
gate_require "$CORPUS/ALL.csv" "ALL.csv -- without it there is no origin key and no per-entry provenance"
gate_require_fresh "$ROOT" src "$SCRIP_BIN" "$RT/libscrip_rt.so"
if [ "$REPIN" -eq 0 ]; then
    gate_require "$BASE" "the pinned per-entry identity baseline (create it from a run: $0 --repin)"
fi
echo "=== Icon RUNGS per-entry identity — $CORPUS/ALL.icn ==="
T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
MEAS="${ICON_IDENTITY_MEASURED_FROM:-}"
if [ -n "$MEAS" ]; then
    echo "⚠ CONTROL ARM: grading a pre-measured progress table ($MEAS) -- the suite was NOT run by this invocation."
    gate_require "$MEAS" "the pre-measured progress table named by ICON_IDENTITY_MEASURED_FROM"
else
    MEAS="$T/progress.tsv"
    echo "running the rungs in m3+m4 (per-entry rows -> a SCRATCH progress table, never the live one) ..."
    S4E_PROGRESS_DB="$MEAS" timeout -k 5 "$BUDGET" python3 "$HARNESS" run "$CORPUS/ALL.icn" "$CORPUS/ALL.ref" \
        --lang icon --modes m3,m4 >"$T/out" 2>"$T/err"
    hrc=$?
    if [ "$hrc" -eq 124 ]; then
        echo "GATE UNPROVEN(2) [$GATE_NAME]: the rungs did not finish within ${BUDGET}s -- cannot measure."
        gate_stamp; exit 2
    fi
    # ⛔ THE HARNESS EXITS NON-ZERO WHENEVER ANY ENTRY FAILS, and this rung suite is legitimately red on 8 entries
    # today, so its exit status can never be the refusal test. SUITE_BOARD's presence is: it says a board was
    # produced. "Could not measure" and "measured a red suite" must not share a signal (RULES.md).
    if ! grep -q '^SUITE_BOARD ' "$T/out"; then
        echo "GATE UNPROVEN(2) [$GATE_NAME]: the harness produced no SUITE_BOARD line (rc=$hrc) -- measured nothing."
        sed -n '1,12p' "$T/err"
        gate_stamp; exit 2
    fi
    if [ ! -s "$MEAS" ]; then
        echo "GATE UNPROVEN(2) [$GATE_NAME]: the run recorded no per-entry rows to the scratch progress table."
        echo "    Without per-entry rows this gate has only counts, which is the instrument it replaces."
        gate_stamp; exit 2
    fi
    grep '^SUITE_BOARD ' "$T/out" | tail -1
fi
# ⭐ THE COMPARISON IS ONE EMBEDDED PROGRAM AND NOT A SECOND FILE, so --repin and the verdict can never read
# the measured table by two different rules. It prints a human report, then one machine line the shell parses.
python3 - "$CORPUS/ALL.csv" "$MEAS" "$BASE" "$REPIN" <<'PYEOF' >"$T/report" 2>&1
import csv, sys, os, collections
csv_path, meas_path, base_path, repin = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1"
# origin is the DURABLE key; the entry name is display only (the builder renumbers entries on every rebuild).
try:
    rows = list(csv.DictReader(open(csv_path, encoding="utf-8", errors="replace")))
except Exception as e:
    print("REFUSE(2): cannot read %s: %s" % (csv_path, e)); sys.exit(2)
entry2origin = {r["entry"]: r["origin"] for r in rows if r.get("entry") and r.get("origin")}
if not entry2origin:
    print("REFUSE(2): %s carries no entry->origin mapping -- the identity key cannot be built" % csv_path); sys.exit(2)
# The measured table is the ONE writer's own format; keep the LAST reading per (origin, mode) so a table that
# accumulated several runs grades as its newest, never as an arbitrary one.
measured, unmapped = {}, set()
try:
    with open(meas_path, encoding="utf-8", errors="replace", newline="") as f:
        rd = csv.DictReader(f, delimiter="\t")
        for r in rd:
            if r.get("suite") != "icon-rungs":
                continue
            prog, mode, out = r.get("program", ""), r.get("mode", ""), r.get("outcome", "")
            if not prog or not mode:
                continue
            origin = entry2origin.get(prog)
            if origin is None:
                unmapped.add(prog); continue
            measured[(origin, mode)] = (out, prog)
except Exception as e:
    print("REFUSE(2): cannot read the measured progress table %s: %s" % (meas_path, e)); sys.exit(2)
if not measured:
    print("REFUSE(2): the measured table carries no icon-rungs rows -- enumerated nothing, which is not a pass"); sys.exit(2)
if repin:
    with open(base_path, "w", encoding="utf-8") as f:
        f.write("# icon_rungs_identity_baseline.tsv -- PER-ENTRY IDENTITY of corpus/tests/icon/ALL.icn.\n")
        f.write("# origin <TAB> mode <TAB> outcome <TAB> entry(display only; the builder renumbers it, origin does not move)\n")
        f.write("# ⛔ WRITTEN FROM A RUN BY test_gate_icon_rungs_per_entry_identity.sh --repin, NEVER BY HAND.\n")
        f.write("# ⛔ A PASS HERE IS A PROMISE: this file going backwards is the gate's whole verdict. Re-pin ONLY in the\n")
        f.write("#    commit that earned the change, and let the DIFF of this file be the receipt -- it names every entry\n")
        f.write("#    that moved, which is the thing a floor could never tell you.\n")
        f.write("# \u26d4 A FAIL PINNED HERE IS A DEFECT WITH A ROW, NEVER AN XFAIL (RULES.md: THERE IS NO XFAIL). It is\n")
        f.write("#    recorded only so this gate can sit in `make test` without reddening the fleet on an inherited red --\n")
        f.write("#    the moment it is cured, re-pin IN THE SAME COMMIT and let this file's diff be the receipt.\n")
        for (origin, mode) in sorted(measured):
            out, prog = measured[(origin, mode)]
            f.write("%s\t%s\t%s\t%s\n" % (origin, mode, out, prog))
    print("RE-PINNED %s: %d (origin, mode) pairs written from this run." % (base_path, len(measured)))
    print("IDENTITY_RESULT examined=%d regressions=0 vanished=0 improved=0 new=0 kindchanged=0 astdrift=0 repin=1" % len(measured))
    sys.exit(0)
baseline = {}
try:
    for raw in open(base_path, encoding="utf-8", errors="replace"):
        if not raw.strip() or raw.startswith("#"):
            continue
        f = raw.rstrip("\n").split("\t")
        if len(f) < 3:
            continue
        baseline[(f[0], f[1])] = f[2]
except Exception as e:
    print("REFUSE(2): cannot read the baseline %s: %s" % (base_path, e)); sys.exit(2)
if not baseline:
    print("REFUSE(2): the baseline %s pins nothing -- an empty pin cannot certify anything" % base_path); sys.exit(2)
# ⛔ THE INJECTION SITS HERE, downstream of a REAL measurement and upstream of the REAL comparison, so the
# fail-once proof exercises the same code the verdict does. A control arm that runs its own private compare
# proves only that the private compare works.
inject = os.environ.get("FAIL_ONCE", "")
injected = None
if inject:
    cands = [k for k in sorted(measured) if baseline.get(k) == "PASS" and measured[k][0] == "PASS" and k[1] != "ast"]
    if inject not in ("1", "yes", "true"):
        cands = [k for k in cands if k[0] == inject] or cands
    if not cands:
        print("REFUSE(2): FAIL_ONCE was asked for but no pinned-PASS run-graded pair exists to injure -- cannot prove the gate can say no"); sys.exit(2)
    injected = cands[0]
    measured[injected] = ("FAIL", measured[injected][1])
    print("⛔ FAIL_ONCE CONTROL ARM: after a real run, entry %s (%s) was forced FAIL. This verdict is a SELF-TEST" % (injected[0], injected[1]))
    print("   of the comparison, NOT a measurement of the tree. The gate MUST go red below, or it cannot say no.")
PASSY = ("PASS", "XPASS")
regress, vanished, improved, new, kindchg, astdrift = [], [], [], [], [], []
for key, want in sorted(baseline.items()):
    origin, mode = key
    if key not in measured:
        vanished.append((origin, mode, want)); continue
    got, prog = measured[key]
    if got == want:
        continue
    if mode == "ast":
        astdrift.append((origin, mode, want, got)); continue
    if want in PASSY and got not in PASSY:
        regress.append((origin, mode, want, got, prog))
    elif want not in PASSY and got in PASSY:
        improved.append((origin, mode, want, got))
    else:
        kindchg.append((origin, mode, want, got))
for key in sorted(measured):
    if key not in baseline:
        new.append((key[0], key[1], measured[key][0]))
def show(title, items, cap=25):
    if not items:
        return
    print("")
    print(title % len(items))
    for it in items[:cap]:
        print("    " + "  ".join(str(x) for x in it))
    if len(items) > cap:
        print("    ... and %d more (this list is capped, and says so rather than truncating silently)" % (len(items) - cap))
print("")
print("pinned pairs: %d   measured pairs: %d   (key = origin + mode; entry names are display only)" % (len(baseline), len(measured)))
if unmapped:
    print("⚠️  %d measured program name(s) are absent from ALL.csv and could not be keyed -- they are NOT graded here: %s"
          % (len(unmapped), ", ".join(sorted(unmapped)[:6])))
show("⛔ RED — %d pinned PASS no longer passes (origin, mode, was, now, entry):", regress)
show("⛔ RED — %d pinned entr(y/ies) are NO LONGER GRADED AT ALL (origin, mode, was):", vanished)
show("⭐ %d improved — re-pin in the commit that earned it (origin, mode, was, now):", improved)
show("⚠️  %d non-PASS entr(y/ies) changed KIND — reported, NOT red: both readings are non-PASS, the entry is already\n    an open defect on someone's row, and reddening a cure in progress is how a gate teaches people to route around it\n    (origin, mode, was, now):", kindchg)
show("⚠️  %d ast-graded fixture(s) drifted — RE-DECIDE THE SHAPE AND REGENERATE, never 'a program broke'\n    (ast-dump-refs-are-self-pins-not-oracles; NEVER red on outcome) (origin, mode, was, now):", astdrift)
show("⭐ %d newly graded entr(y/ies) not in the pin — growth needs no re-pin (origin, mode, now):", new)
if injected is not None and not regress:
    print("")
    print("⛔ REFUSE(2): FAIL_ONCE injected %s as FAIL and the comparison did NOT report it." % (injected[0],))
    print("   The gate cannot say no, which is the exact defect this row exists to cure. Fix the gate, not the pin.")
    sys.exit(2)
print("")
print("IDENTITY_RESULT examined=%d regressions=%d vanished=%d improved=%d new=%d kindchanged=%d astdrift=%d repin=0"
      % (len(baseline), len(regress), len(vanished), len(improved), len(new), len(kindchg), len(astdrift)))
sys.exit(0)
PYEOF
prc=$?
cat "$T/report"
if [ "$prc" -eq 2 ] || grep -q '^REFUSE(2)\|⛔ REFUSE(2)' "$T/report"; then
    echo "GATE UNPROVEN(2) [$GATE_NAME]: the comparison could not be made (see above)."
    gate_stamp; exit 2
fi
line="$(grep '^IDENTITY_RESULT ' "$T/report" | tail -1)"
if [ -z "$line" ]; then
    echo "GATE UNPROVEN(2) [$GATE_NAME]: the comparison printed no result line."
    gate_stamp; exit 2
fi
f() { echo "$line" | grep -oE "$1=[0-9]+" | cut -d= -f2; }
examined="$(f examined)"; regressions="$(f regressions)"; vanished="$(f vanished)"
if [ "$REPIN" -eq 1 ]; then
    echo "✅ baseline rewritten from this run. ⛔ COMMIT IT WITH THE CURE THAT EARNED IT, never on its own:"
    echo "   a re-pin landing alone is a floor re-pin with extra steps, and its diff is the only receipt anyone gets."
    exit 0
fi
# ⛔ ZERO-WORK-EXAMINED IS INDISTINGUISHABLE FROM ALL-CLEAN, so a pin that shrank to nothing refuses rather than passes.
gate_floor "$examined" "$PAIR_FLOOR" "pinned (entry, mode) pairs"
gate_verdict "$((regressions + vanished))" "per-entry identity regressions (a pinned PASS that stopped passing, or a pinned entry no longer graded)"
