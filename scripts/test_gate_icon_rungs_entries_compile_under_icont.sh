#!/usr/bin/env bash
# test_gate_icon_rungs_entries_compile_under_icont.sh -- THE ICON RUNGS GRADABILITY GATE (CEO-483, hq_V
# 2026-09-10; the standing criterion behind CEO-477's one-liner-joiner repair).
#
# THE CRITERION, in the ceo's words: every RUN-GRADED rungs entry compiles under `icont -s -c`.
#
# ⛔⛔ WHY THIS IS A GATE AND NOT A ONE-OFF SHELL LINE. The joiner defect CEO-477 cured (SCRIP f59db4cd8) put a
# statement terminator INSIDE a construct -- `;` before `else`, before `then`, before a case body's `}`, and
# directly inside `( )`. Every one of those is a SYNTAX ERROR to Arizona icont and a NO-OP to us, so the
# fourteen entries carrying them READ GREEN ON EVERY BOARD while being ungradable against the oracle at all.
# A board cannot see this class: our own frontend accepts the text, so the entry passes, and the fact that the
# oracle could never have compiled it never surfaces. The only instrument that can see it is one that asks the
# ORACLE to compile what the rungs stores. That is this file, and it is why it must keep running after the
# repair: the joiner is a WRITER, and a writer that regresses re-manufactures the whole class silently.
#
# ⛔⭐ THREE THINGS THIS GATE MUST DO THAT THE OBVIOUS VERSION DOES NOT -- ALL THREE MEASURED 2026-09-10, and
# each one, omitted, turns a GREEN tree into a false red that a reader would route to the joiner's lane:
#
#   (1) PASS --out-in. `extract` REFUSES (by design) to materialize a stdin-bearing entry without it, rather
#       than silently grading a starved witness. Omit the flag and 20 of the 757 entries fail at EXTRACT and
#       are indistinguishable, in a bare exit status, from an entry icont refused. The first cut of this
#       criterion did exactly that and reported 21 refusals where the true count was one.
#   (2) STAGE THE COMPANION CLOSURE. An entry whose text says `$include "prepro.dat"` compiles only where that
#       file resolves beside it. procedure_record_limit_replace_1 (origin rung36_jcon_prepro) is that entry,
#       and in a bare temp dir icont says `"prepro.dat": cannot open` -- a MISSING-FILE error wearing a
#       compile-refusal exit status. The companion is present and declared (corpus/tests/icon/config/); the
#       instrument was simply not giving the entry what the harness gives it when it GRADES it.
#   (3) SEPARATE THE THREE OUTCOMES IN THE REPORT. extract-failed, icont-refused and compiled are three
#       different diagnoses with three different owners. A gate that adds them into one number names the
#       wrong lane, which is worse than no number (RULES.md: a criterion that lies).
#
# ⛔ COMPANIONS COME FROM THE HARNESS'S OWN AUTHORITY, never a second rule written here. _copy_companions() is
# the same function run_suite_entry() uses when it grades, and it already knows the `<dir>/config` convention.
# A private "copy *.dat" lookalike here would drift from the grader the day either side learned a new shape.
#
# ⛔⛔ THIS GATE GRADES THE RUNGS PAIR, NOT SCRIP. It never runs ./scrip and no compiler change can move it.
# A red here means the Icon rungs stores text Arizona icont refuses -- our artifact, our defect, hq_V's lane.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
GATE="test_gate_icon_rungs_entries_compile_under_icont"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ $GATE REFUSES rc=2: lib_oracle_flags.sh unloadable" >&2; exit 2; }
ICONT="$(icont_bin)" || exit 2
DIR="$S4E/corpus/tests/icon"
ICN="$DIR/ALL.icn"; REF="$DIR/ALL.ref"; CSV="$DIR/ALL.csv"
for f in "$ICN" "$REF" "$CSV"; do
    [ -f "$f" ] || { echo "⛔ $GATE REFUSES rc=2: missing rungs file: $f" >&2; exit 2; }
done
WORK="$(mktemp -d "${TMPDIR:-/tmp}/icn_rungs_icont_gate.XXXXXX")" || { echo "⛔ $GATE REFUSES rc=2: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

# ── THE POPULATION READS ITSELF OUT OF ALL.csv AND IS NEVER A LITERAL HERE (RULES.md: a DONE-WHEN never pins a
# population count).
# ⭐⛔ EVERY ENTRY, RUN-GRADED AND AST-GRADED ALIKE (CEO-497, 2026-09-10, ruling hq_V's HQV-19 ask). This gate
# ORIGINALLY selected only entries declaring a RUN mode, on the reasoning that an ast-only entry is never
# compiled by anything so asking icont to compile it grades a witness the suite does not. THAT REASONING WAS
# WRONG, and the counter-example is in this lane's own record: parser/paren_seq and parser/case_multi_clause
# carried INVALID ICON -- write((x := 1; x)) and a trailing semicolon after the last case clause -- for as long
# as our parser tolerated it. Both were ast-graded, both were therefore invisible to this gate AND to every
# board, and they surfaced only because a PARSER cure exposed them (HQV-19). The ceo's ruling states the
# principle better than the exclusion did: an AST fixture that carries invalid Icon pins a parse THE ORACLE
# REJECTS, so the tree it asserts is not Icon's tree. Measured before widening: all 153 ast-graded compile.
mapfile -t NAMES < <(python3 - "$CSV" <<'PY'
import csv, sys
rows = list(csv.DictReader(open(sys.argv[1], encoding="utf-8")))
for r in rows:
    print(r["entry"])
PY
)
N=${#NAMES[@]}
# ⛔ REFUSE ON A ZERO/COLLAPSED POPULATION rather than print the success shape over nothing: "examined 757 and
# clean" and "examined 0" must never render as the same string. A column rename upstream lands here as rc=2.
[ "$N" -gt 100 ] || { echo "⛔ $GATE REFUSES rc=2: ALL.csv yielded $N entries -- column names or population wrong" >&2; exit 2; }

# ⛔⭐ THE RUNGS IS READ ONCE, NOT 757 TIMES. The obvious loop shells out to `extract` per entry, and
# `extract` re-parses the WHOLE rungs pair on every call -- 192s MEASURED, which prices this gate out of
# `make test` entirely, and a gate in no runner is not measuring (the false-green shape `test` itself was
# cured of at s268). Materializing every entry from ONE read costs 757 icont invocations and nothing else.
# ⛔ IT IS STILL THE HARNESS'S OWN AUTHORITY: the reader selection below is cmd_extract's, verbatim in
# order and in fallback (block first, one-line second), and the stdin field is carried exactly as
# cmd_extract carries it -- a materializer that dropped it would grade a starved witness, which is the
# defect that reader comment exists for. This is a batching of that function, never a second parser.
MAT="$WORK/.materialize.log"
python3 - "$HERE/../../SCRIP" "$ICN" "$REF" "$DIR" "$WORK" <<'MATPY' > "$MAT" 2>&1
import sys
from pathlib import Path
sys.path.insert(0, sys.argv[1] + "/scripts")
import corpus_suite_harness as H
icn, ref, family_dir, work = sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
copen, cclose = "*", ""
for lc in H.LANG_CONFIGS.values():
    if lc.get("ext") == Path(icn).suffix:
        copen, cclose = lc.get("comment_open", "*"), lc.get("comment_close", "")
        break
in_path, x_path = H.sidecar_in_path(icn), H.sidecar_xfail_path(icn)
try:
    entries = H.read_block_suite(icn, ref, H.banner_re_for(copen, cclose), in_path=in_path, x_path=x_path)
except Exception as block_err:
    try:
        entries = H.read_suite(icn, ref, in_path=in_path, x_path=x_path)
    except Exception as line_err:
        print("REFUSE: %s reads as neither dialect. block=%s: %s ; line=%s: %s"
              % (icn, type(block_err).__name__, block_err, type(line_err).__name__, line_err))
        raise SystemExit(2)
for e in entries:
    d = Path(work) / e.name
    try:
        d.mkdir(parents=True, exist_ok=True)
        text = e.sno_lines[0] if e.kind == "line" else "\n".join(e.sno_lines)
        (d / (e.name + ".icn")).write_text(text + "\n")
        if e.stdin is not None:
            (d / (e.name + ".in")).write_text(e.stdin)
        H._copy_companions(text + "\n", family_dir, d)
    except Exception as exc:
        print("EXTRACT-FAILED %s" % e.name)
        print("   %s: %s" % (type(exc).__name__, exc))
print("MATERIALIZED %d" % len(entries))
MATPY
grep -q '^MATERIALIZED ' "$MAT" || { echo "⛔ $GATE REFUSES rc=2: could not materialize the rungs -- see below" >&2; cat "$MAT" >&2; exit 2; }
mapfile -t EXTRACT < <(sed -n 's/^EXTRACT-FAILED //p' "$MAT")
n_extract=${#EXTRACT[@]}

n_ok=0; n_refused=0; REFUSED=()
for e in "${NAMES[@]}"; do
    d="$WORK/$e"
    [ -f "$d/$e.icn" ] || continue
    if ( cd "$d" && "$ICONT" -s -c "$e.icn" ) >/dev/null 2>&1; then
        n_ok=$((n_ok+1))
    else
        n_refused=$((n_refused+1)); REFUSED+=("$e")
    fi
done

echo "$GATE: population=$N compiled=$n_ok icont-refused=$n_refused extract-failed=$n_extract"
# ⭐ NAMED, NEVER COUNTED. The list is the one place a new arrival shows up, and a bare count cannot be read
# for one -- the same reason util_rungs_companion_closure.py prints its unresolvable names every run.
if [ "$n_extract" -gt 0 ]; then
    echo "⛔ $GATE REFUSES rc=2: $n_extract entries could not be EXTRACTED (an instrument fault, not a rung suite defect):" >&2
    printf '     %s\n' "${EXTRACT[@]}" >&2
    exit 2
fi
if [ "$n_refused" -gt 0 ]; then
    echo "⛔ $GATE FAIL rc=1: $n_refused of $N Icon rungs entries are refused by icont -s -c:" >&2
    printf '     %s\n' "${REFUSED[@]}" >&2
    exit 1
fi
echo "✅ $GATE PASS: all $N Icon rungs entries (run-graded AND ast-graded) compile under icont -s -c"
exit 0
