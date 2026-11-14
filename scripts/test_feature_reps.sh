#!/usr/bin/env bash
# test_feature_reps.sh -- THE HANDFUL: a small set of representative programs directly related to a fix, run by the seat that lands it
# (Lon 2026-10-11 13:4x CDT, in-chat, verbatim: "I suspect the ONE TEST per change is too restrictive. It should be a small
# handful of representative programs directly related to the fix."; R-1677; RULES.md section ONE TESTING OFFICER clause (7) as amended).
# The handful is LOOKED UP, never queried: the language's master partition (corpus/tests/<lang>/PARTITION.tsv, R-1676) names a CORE whose
# entries cover every distinctive feature three times; the representatives of feature F are the core entries whose shells carry F, in core
# order (the entries marking the most features first), capped at REPS_CAP (default 8) over all the features named. They are graded by the
# harness's own smoke engine (corpus_suite_harness.py smoke --entries: declared sizes, stdin, masks, both modes) which writes no progress row
# and no score row, so this is a seat's run and never a board. A feature no shell carries REFUSES rc 2 and prints the table's vocabulary.
# usage: bash ../harness/scripts/test_feature_reps.sh <lang> <feature>... [--list] [--modes m3,m4]      REPS_CAP=N caps the handful.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "$HERE/lib_paths.sh"; ROOT="$(cd "$S4E_SCRIP" && pwd)"; cd "$ROOT" || exit 2
C="$S4E_CORPUS"
[ $# -ge 2 ] || { echo "usage: test_feature_reps.sh <lang> <feature>... [--list] [--modes m3,m4]"; exit 2; }
lang="$1"; shift; LIST=""; MODES="m3,m4"; FEATS=()
while [ $# -gt 0 ]; do case "$1" in --list) LIST=1;; --modes) MODES="$2"; shift;; -*) echo "FEATURE_REPS REFUSE(2): unknown switch $1"; exit 2;; *) FEATS+=("$1");; esac; shift; done
P="$C/tests/$lang/PARTITION.tsv"; [ -f "$P" ] || { echo "FEATURE_REPS REFUSE(2): no $P -- build it with util_suite_partition.py build $C/tests/$lang/ALL.csv"; exit 2; }
CAP="${REPS_CAP:-8}"
# A REP IS SMALL (the coo 2026-11-14 10:3x CST, on Lon's "The limitations must be built-in to the ... shell scripts."; MEASURED: the
# pascal core entry packed_arrays__pa08_wide declares heap_kb 6291456 and was the rep of type, pointer, for, record and subrange, so
# a seat's handful ran a 6 GB program for up to 1156 s in its own window): a core entry whose declared heap_kb plus stack_kb exceeds
# REPS_HEAP_KB_MAX (default 1048576, 1 GB) is no rep; it is named on stderr and stays graded by the cycle every lap.
HEAPMAX="${REPS_HEAP_KB_MAX:-1048576}"
sel="$(python3 - "$P" "$CAP" "$HEAPMAX" "${FEATS[@]}" <<'PY'
import sys, os, csv
p, cap, heapmax, feats = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4:]
rows = [l.rstrip("\n").split("\t") for l in open(p, encoding="utf-8") if l.strip() and not l.startswith("#")]
hdr, rows = rows[0], rows[1:]
known = {f for r in rows for f in (r[3].split() if len(r) > 3 else [])}
bad = [f for f in feats if f not in known]
if bad:
    print("UNKNOWN " + " ".join(bad)); sys.exit(0)
size = {}
a = os.path.join(os.path.dirname(p), "ALL.csv")
if os.path.isfile(a):
    for e in csv.DictReader(open(a, encoding="utf-8", newline="")):
        try: size[e.get("entry", "")] = int(e.get("heap_kb") or 0) + int(e.get("stack_kb") or 0)
        except ValueError: pass
core = [r[0] for r in rows if r[1] == "core" and any(f in r[3].split() for f in feats)]
heavy = [n for n in core if size.get(n, 0) > heapmax]
if heavy:
    sys.stderr.write("FEATURE_REPS skipped %d heavy core entr%s (declared heap_kb+stack_kb over %d KB; the cycle grades them): %s\n" % (len(heavy), "y" if len(heavy) == 1 else "ies", heapmax, " ".join(heavy)))
core = [n for n in core if n not in heavy]
shell = sum(1 for r in rows if any(f in r[3].split() for f in feats))
print("OK %d %d %s" % (len(core), shell, " ".join(core[:cap])))
PY
)"
case "$sel" in
  UNKNOWN*) echo "FEATURE_REPS REFUSE(2): feature(s) ${sel#UNKNOWN } are in no shell of tests/$lang -- the vocabulary:"; python3 "$HERE/corpus_suite_harness.py" smoke --vocabulary --tables "tests/$lang" 2>/dev/null | sed 's/^AREA_SMOKE_VOCAB table=[^ ]* runnable=[^ ]* /    /' | fold -w 160; exit 2;;
esac
set -- $sel; shift; ncore="$1"; nshell="$2"; shift 2; reps=("$@")
[ ${#reps[@]} -gt 0 ] || { echo "FEATURE_REPS REFUSE(2): the core of tests/$lang has no entry carrying ${FEATS[*]}"; exit 2; }
echo "FEATURE_REPS lang=$lang features=${FEATS[*]} reps=${#reps[@]} of $ncore core entries carrying them ($nshell in the shells): ${reps[*]}"
[ -n "$LIST" ] && exit 0
T0=$(date +%s.%N)
out="$(python3 "$HERE/corpus_suite_harness.py" smoke "${FEATS[@]}" --tables "tests/$lang" --entries "${reps[*]}" --modes "$MODES" 2>&1)"; rc=$?
printf '%s\n' "$out" | grep -E '^AREA_SMOKE_(ENTRY|TABLE)' | sed 's/^AREA_SMOKE_/  /' | cut -c1-200
secs="$(echo "$(date +%s.%N) - $T0" | bc | sed 's/^\./0./')"
line="$(printf '%s\n' "$out" | grep -m1 '^AREA_SMOKE_TABLE')"
case "$rc" in 0) v=GREEN;; 2) v=REFUSED;; *) v=RED;; esac
echo "FEATURE_REPS $v lang=$lang features=${FEATS[*]} reps=${#reps[@]} ${line#AREA_SMOKE_TABLE table=*/ } wall=${secs}s rc=$rc (no progress row, no score row: a seat's handful, R-1677)"
[ "$rc" = 2 ] && printf '%s\n' "$out" | tail -3
exit $rc
