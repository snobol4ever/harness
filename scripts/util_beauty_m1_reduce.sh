#!/usr/bin/env bash
# util_beauty_m1_reduce.sh -- s184: reduce beauty's rc=139 class-A wild jump to THREE overridden grammar lines.
# Copies the beauty dir to a scratch tree, replaces named grammar assignments, feeds m1_lad_empty.in (one newline),
# and reports rc over N runs.  ⛔ ASM-DIFF-FIRST: the green/red pair differs by ONE element (Stmt=*Label vs *Label *Label).
#   bash ../harness/scripts/util_beauty_m1_reduce.sh                 # the reduced RED witness (expect 139)
#   bash ../harness/scripts/util_beauty_m1_reduce.sh --green         # the one-token-different control (expect 0)
#   bash ../harness/scripts/util_beauty_m1_reduce.sh 'Parse=...' 'Stmt=...'    # arbitrary overrides
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; SIB="$(cd "$ROOT/.." && pwd)"
SCRIP="$ROOT/scrip"; SRC="$SIB/corpus/demos"
[ -x "$SCRIP" ] || { echo "no $SCRIP -- run make first"; exit 2; }
[ -d "$SRC" ]   || { echo "no $SRC"; exit 2; }
RED=( 'Parse=*Stmt ("'"'"'Stmt'"'"'" & 7) nl' 'Stmt=*Label *Label' "Label=epsilon ~ 'Label'" )
GRN=( 'Parse=*Stmt ("'"'"'Stmt'"'"'" & 7) nl' 'Stmt=*Label'         "Label=epsilon ~ 'Label'" )
case "${1:-}" in --green) OVR=( "${GRN[@]}" );; "") OVR=( "${RED[@]}" );; *) OVR=( "$@" );; esac
D="$(mktemp -d)"; trap 'rm -rf "$D"' EXIT
cp "$SRC"/*.inc "$SRC"/beauty.sno "$SRC"/m1_lad_empty.in "$D"/ 2>/dev/null
python3 - "$D" "${OVR[@]}" <<'PY'
import sys, re
d = sys.argv[1]; p = d + '/beauty.sno'; L = open(p).read().split('\n')
for a in sys.argv[2:]:
    name, rhs = a.split('=', 1)
    i = next(k for k, l in enumerate(L) if re.match(r'^\s+' + re.escape(name) + r'\s+=\s', l))
    j = i + 1
    while j < len(L) and L[j].startswith('+'): j += 1
    L[i:j] = ['                  %-14s =  %s' % (name, rhs)]
open(p, 'w').write('\n'.join(L))
PY
sig=""; for i in 1 2 3 4 5; do ( cd "$D" && timeout -k 5 30 "$SCRIP" beauty.sno < m1_lad_empty.in >/dev/null 2>&1 ); sig="$sig $?"; done
printf 'overrides: %s\n' "$(printf '%s | ' "${OVR[@]}")"
printf 'rc over 5 runs:%s\n' "$sig"
case "$sig" in *139*) echo "RED -- wild jump (rip in ld.so DATA, bt destroyed).  See FINDING-2026-08-20-s184-*.md"; exit 1;; esac
echo "GREEN"; exit 0
