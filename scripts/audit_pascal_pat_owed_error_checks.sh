#!/usr/bin/env bash
# audit_pascal_pat_owed_error_checks.sh -- the seat-side census of the PAT error checks still owed
#
# WHY THIS EXISTS AND WHY IT IS NOT A BOARD. test_pascal_pat_suite.sh grades all 427 vendored programs, so it is a
# board and refuses every seat but THE ONE RUNNER. This grades only a NAMED, fixed list of witnesses -- a gate
# population, not a board (CEO-547: what makes a run a board is the population it grades, not the entry point) -- so
# the owning HQ can measure its own cures between the coo's passes without standing in for the coo.
#
# THE LIST is the coo's 2026-09-13 full PAT accounting (baton pascal-pat-suite-427-to-100-percent-by-class): the named
# error-detection checks standing between PAT 271 and PAT 296, in the two classes that accounting identified, plus the
# seven file-state witnesses it found were the same class as the fifteen but had not been listed with them.
#
# THE CRITERION is the PAT suite's own for a REJECTION test: PASS means scrip exits NON-ZERO **with a diagnostic**, in
# BOTH modes. ⛔ A non-zero exit with an EMPTY diagnostic is NOT a rejection and is not scored as one -- 1710 and 1715
# exit 1 in m3 while printing nothing, and a runner that graded on rc alone would call them cured.
#
# ⛔⭐ THE m4 ARM LINKS AND RUNS, AND THIS AUDIT GOT IT WRONG ONCE. Its first version graded m4 with --compile --out=/dev/null,
# which only COMPILES -- so a witness whose ISO condition is detected at RUN time could never fail that
# arm, and the audit reported 21 owed while the cure for eight of them was already landed and working in both modes.
# MEASURED 2026-09-16: 1710 compiled rc=0 under the old arm and, linked and run, exits 1 with its diagnostic. A
# compile-only arm cannot see a runtime check, and a rejection suite is mostly runtime checks. So m4 now compiles,
# LINKS against out/libscrip_rt.so and RUNS, and a witness passes that arm if EITHER the compile refuses or the
# resulting program does. ⭐ The general form, worth more than this row: an instrument that can observe only one half
# of a cure reports the other half as absent forever, and it does not get louder as the cure lands.
#
# This AUDITS; it does not gate. It exits 0 whenever it could measure, and REFUSES rc=2 when it could not (no binary,
# no vendored suite, or a witness missing) -- the number is the product, so a run that cannot produce one must not
# print the success shape. The board line is the last thing it prints and it is the only verdict here.
set -uo pipefail
A="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2) [$A]: no scrip at $SCRIP"; exit 2; }
SRC="$S4E/corpus/packages/pascal/pat"; [ -d "$SRC" ] || { echo "⛔ REFUSE(2) [$A]: no vendored PAT suite at $SRC"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ REFUSE(2) [$A]: no runtime at $RT_DIR/libscrip_rt.so -- the m4 arm links against it"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
PU="1726 1727 1728 1729 1730 1731 1867 1868 1869 1870"
FS="1706a 1709 1710 1712 1713 1714 1715 1716 1717 1718 1740 1757 1826 1827 1842"
EX="1706b 1875 1876 1877 1878 1879 1880"
pass=0; fail=0
for grp in "PACK-UNPACK(ISO-7185-6.6.5.4):$PU" "FILE-STATE(the-coo-15):$FS" "FILE-STATE(same-class-7):$EX"; do
  name=${grp%%:*}; list=${grp#*:}
  echo "=== $name ==="
  for n in $list; do
    f="$SRC/iso7185prt$n.pas"
    [ -f "$f" ] || { echo "⛔ REFUSE(2) [$A]: missing vendored witness $f -- the denominator is not what this audit names"; exit 2; }
    o3=$( cd "$T" && timeout -k 5 10s "$SCRIP" "$f" </dev/null 2>&1 ); rc3=$?
    o4=$( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/w.s" "$f" </dev/null 2>&1 ); rc4=$?
    if [ "$rc4" = 0 ]; then
        if ( cd "$T" && cc -m64 -no-pie w.s -o w -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ); then
            o4=$( cd "$T" && timeout -k 5 20s ./w </dev/null 2>&1 ); rc4=$?
        else o4="link failed"; rc4=0; fi
    fi
    g3=0; g4=0
    { [ "$rc3" -ne 0 ] && [ "$rc3" -lt 124 ] && [ -n "$o3" ]; } && g3=1
    { [ "$rc4" -ne 0 ] && [ "$rc4" -lt 124 ] && [ -n "$o4" ]; } && g4=1
    if [ "$g3" = 1 ] && [ "$g4" = 1 ]; then printf '  %-8s REFUSED in both modes\n' "$n"; pass=$((pass+1))
    else printf '  %-8s ACCEPTED  m3 rc=%-4s (%d bytes)  m4 rc=%-4s (%d bytes)\n' "$n" "$rc3" "${#o3}" "$rc4" "${#o4}"; fail=$((fail+1)); fi
  done
done
echo
echo "PAT_OWED_AUDIT cured=$pass owed=$fail total=$((pass+fail))"
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)  by ${S4E_SEAT:-$(basename "$S4E")}"
exit 0
