#!/usr/bin/env bash
# test_feature_reps.sh -- THE HANDFUL: a small set of representative programs directly related to a fix, run by the seat that lands it
# (Lon 2026-10-11 13:4x CDT, in-chat to the ceo, verbatim: "I suspect the ONE TEST per change is too restrictive. It should be a small
# handful of representative programs directly related to the fix."; ceo CEO-1677; RULES.md section ONE TESTING OFFICER clause (7) as amended).
# The handful is LOOKED UP, never queried: the language's master partition (corpus/tests/<lang>/PARTITION.tsv, CEO-1676) names a CORE whose
# entries cover every distinctive feature three times; the representatives of feature F are the core entries whose shells carry F, in core
# order (the entries marking the most features first), capped at REPS_CAP (default 8) over all the features named. They are graded by the
# harness's own smoke engine (corpus_suite_harness.py smoke --entries: declared sizes, stdin, masks, both modes) which writes no progress row
# and no score row, so this is a seat's run and never a board. A feature no shell carries REFUSES rc 2 and prints the table's vocabulary.
# usage: bash ../harness/scripts/test_feature_reps.sh <lang> <feature>... [--list] [--modes m3,m4]      REPS_CAP=N caps the handful.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; cd "$ROOT" || exit 2
C="${S4E_CORPUS:-${S4E_HOME:-$(cd "$ROOT/.." && pwd)}/corpus}"
[ $# -ge 2 ] || { echo "usage: test_feature_reps.sh <lang> <feature>... [--list] [--modes m3,m4]"; exit 2; }
lang="$1"; shift; LIST=""; MODES="m3,m4"; FEATS=()
while [ $# -gt 0 ]; do case "$1" in --list) LIST=1;; --modes) MODES="$2"; shift;; -*) echo "FEATURE_REPS REFUSE(2): unknown switch $1"; exit 2;; *) FEATS+=("$1");; esac; shift; done
P="$C/tests/$lang/PARTITION.tsv"; [ -f "$P" ] || { echo "FEATURE_REPS REFUSE(2): no $P -- build it with util_suite_partition.py build $C/tests/$lang/ALL.csv"; exit 2; }
CAP="${REPS_CAP:-8}"
sel="$(python3 - "$P" "$CAP" "${FEATS[@]}" <<'PY'
import sys
p, cap, feats = sys.argv[1], int(sys.argv[2]), sys.argv[3:]
rows = [l.rstrip("\n").split("\t") for l in open(p, encoding="utf-8") if l.strip() and not l.startswith("#")]
hdr, rows = rows[0], rows[1:]
known = {f for r in rows for f in (r[3].split() if len(r) > 3 else [])}
bad = [f for f in feats if f not in known]
if bad:
    print("UNKNOWN " + " ".join(bad)); sys.exit(0)
core = [r[0] for r in rows if r[1] == "core" and any(f in r[3].split() for f in feats)]
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
echo "FEATURE_REPS $v lang=$lang features=${FEATS[*]} reps=${#reps[@]} ${line#AREA_SMOKE_TABLE table=*/ } wall=${secs}s rc=$rc (no progress row, no score row: a seat's handful, CEO-1677)"
[ "$rc" = 2 ] && printf '%s\n' "$out" | tail -3
exit $rc
