#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
# test_gate_icn_version_keyword_is_the_oracles.sh -- &version IS THE ORACLE'S, IN BOTH MODES (hq_icon 2026-10-03, CEO-1474 "take the gftrace version cure").
# The one Icon oracle is Arizona icont/iconx 9.5.25a (ceo 2026-09-08), so the keyword that names the implementation answers what iconx answers. Until
# 2026-10-03 src/runtime/keywords.c answered "Jcon Version 2.2", a leftover of the retired Jcon dialect, and every program that prints &version in its
# output (IPL progs/gftrace writes it into the header of the file it generates) carried a line no oracle-cut ref could match. ⛔ SCOPE: the keyword's
# text only. Measured on the oracle and not on SCRIP: the other keywords the old Jcon kwds.std disagrees about (&allocated, &regions, &storage, &features)
# are a separate row; this gate says nothing about them.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
ICONT="${ICONT_BIN:-/home/resources/icon-master/bin/icont}"; [ -x "$ICONT" ] || { echo "⛔ REFUSE(2): no icont at $ICONT -- the expected text is read from the ORACLE, never typed here"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/ver.icn" <<'ICN'
procedure main()
   write(&version);
   write(*&version);
   write(left(&version, 16));
end
ICN
( cd "$T" && "$ICONT" -s ver.icn -x ) >"$T/ver.ref" 2>&1 || { echo "⛔ REFUSE(2): the oracle itself did not run the witness"; exit 2; }
head -1 "$T/ver.ref" | grep -q '^Icon Version ' || { echo "⛔ REFUSE(2): the oracle's &version no longer opens with 'Icon Version ' -- this gate cannot name the class it measures ($(head -1 "$T/ver.ref"))"; exit 2; }
[ "$(wc -l < "$T/ver.ref")" -eq 3 ] || { echo "⛔ REFUSE(2): the oracle's witness stream is not three lines"; exit 2; }
RC=0
for M in m3 m4; do
  if [ "$M" = m3 ]; then ( cd "$T" && timeout -k 5 30 "$SCRIP" ver.icn </dev/null ) >"$T/ver.$M" 2>&1
  else ( cd "$T" && timeout -k 5 30 "$SCRIP" --compile -o ver.s ver.icn </dev/null && gcc -m64 -no-pie ver.s -o ver.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >"$T/build.$M" 2>&1 \
         || { echo "⛔ REFUSE(2): the mode-4 witness did not build"; exit 2; }
       ( cd "$T" && LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 30 ./ver.bin </dev/null ) >"$T/ver.$M" 2>&1
  fi
  if [ -n "${FAIL_ONCE:-}" ]; then sed -i '1s/^Icon Version/Jcon Version/' "$T/ver.$M"; fi
  if diff -q "$T/ver.ref" "$T/ver.$M" >/dev/null; then echo "  $M PASS -- &version, its length and its first sixteen characters read as iconx reads them"
  else RC=1; echo "  $M FAIL -- &version differs from the oracle's:"; diff -u "$T/ver.ref" "$T/ver.$M" | sed -n '3,10p' | sed 's/^/      /'; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$(basename "${BASH_SOURCE[0]}" .sh)]: &version is the oracle's in both modes ($(head -1 "$T/ver.ref"))"
else echo "GATE FAIL(1) [$(basename "${BASH_SOURCE[0]}" .sh)]: &version is not what iconx answers"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $ICONT  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
