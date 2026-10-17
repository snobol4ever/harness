#!/usr/bin/env bash
# util_diagnose_prolog_swi.sh -- per-case detail for ONE swi_tests file (a development aid, never a board).
# Prints SCRIP's raw output through the plunit shim, then every case row from util_swi_match.py against the
# oracle ref beside the source. The population is addressed BY PATH under corpus/packages/prolog/swi_tests.
#
# Usage: bash ../harness/scripts/util_diagnose_prolog_swi.sh core/test_bips.pl [--mode m3|m4]
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
SWIT="$S4E/corpus/packages/prolog/swi_tests"
PLUNIT="$S4E/corpus/tests/prolog/plunit.pl"
SCRIP="$HERE/../../SCRIP/scrip"; RT="${RT_DIR:-$HERE/../../SCRIP/out}"
REL="${1:?usage: util_diagnose_prolog_swi.sh <rel/path.pl> [--mode m3|m4]}"; MODE="${3:-m3}"
f="$SWIT/$REL"; ref="${f%.pl}.ref"
[ -f "$f" ] || { echo "⛔ no such shipped file: $REL" >&2; exit 2; }
[ -f "$ref" ] || { echo "⛔ no oracle ref beside $REL -- cut it: ../harness/scripts/util_swi_cut_refs.sh --write $REL" >&2; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
printf 'main :- run_tests.\n:- initialization(main).\n' > "$T/wrap.pl"
echo "=== raw scrip output ($MODE) for $REL ==="
if [ "$MODE" = m4 ]; then
    timeout -k 5 60 "$SCRIP" --compile "$PLUNIT" "$f" "$T/wrap.pl" > "$T/p.s" && gcc -no-pie "$T/p.s" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$T/p" && timeout -k 5 60 "$T/p" </dev/null | tee "$T/act"
else
    timeout -k 5 60 "$SCRIP" --run "$PLUNIT" "$f" "$T/wrap.pl" </dev/null | tee "$T/act"
fi
echo "=== per case vs $(basename "$ref") ==="
python3 "$HERE/util_swi_match.py" "$f" "$ref" "$T/act"
