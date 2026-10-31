#!/usr/bin/env bash
# build_unicon_oracle.sh -- BUILD THE UNICON ORACLE IN PLACE FROM THE DROP AT /home/resources/unicon (ceo CEO-2072, Lon 2026-10-31; hq_icon, row
# icon-unicon-the-oracle-unicon-is-built-from-home-resources-unicon-and-reached-only-through-unicon-bin-in-lib-oracle-flags-ceo-2072).
# The drop is the Unicon git tree (revision d784f58, 2026-09-06), configured and built in place as /home/resources/icon-master was.  `make Unicon` builds the interpreter
# (icont, iconx), the Icon program library and the OO translator uni/unicon into the drop's bin/.  IDEMPOTENT: on a built drop it finds nothing to do and only verifies.
# THE VERIFY STEP is the DONE-WHEN of the row: unicon translates, links and runs a one-line program.  Nothing here installs outside the drop.
# Usage: bash ../harness/scripts/build_unicon_oracle.sh        rc 0 built and verified - rc 1 the build or the verify failed - rc 2 REFUSAL (no drop, no compiler)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
U=/home/resources/unicon
refuse() { echo "REFUSED(2) [build_unicon_oracle]: $*"; exit 2; }
[ -d "$U" ] || refuse "no Unicon drop at $U"
[ -f "$U/Makefile" ] || refuse "$U has no Makefile -- the drop is not configured: run ./configure there (unicon's README, Build Instructions)"
command -v gcc >/dev/null 2>&1 || refuse "no C compiler on PATH"
echo "unicon drop: $U  revision: $(sed -n 's/^Revision //p' "$U/unicon-features.log" 2>/dev/null | head -1)"
( cd "$U" && bash "$HERE/util_run_slot.sh" make Unicon ) > "${TMPDIR:-/tmp}/build_unicon_oracle.$$.log" 2>&1; rc=$?
if [ "$rc" != 0 ]; then tail -20 "${TMPDIR:-/tmp}/build_unicon_oracle.$$.log"; rm -f "${TMPDIR:-/tmp}/build_unicon_oracle.$$.log"; echo "FAIL make Unicon rc=$rc"; exit 1; fi
rm -f "${TMPDIR:-/tmp}/build_unicon_oracle.$$.log"
for b in unicon icont iconx; do [ -x "$U/bin/$b" ] || { echo "FAIL $U/bin/$b is not built"; exit 1; }; done
D="$(mktemp -d)" || refuse "no scratch dir"; trap 'rm -rf "$D"' EXIT
printf 'procedure main()\n   write("ok")\nend\n' > "$D/t.icn"
( cd "$D" && "$U/bin/unicon" -s -o t t.icn > /dev/null 2>&1 && ./t > out 2>&1 ) ; [ "$(cat "$D/out" 2>/dev/null)" = ok ] || { echo "FAIL smoke: unicon did not translate, link and run a one-line program"; exit 1; }
printf 'class C(n)\n   method bump()\n      n +:= 1\n      return n\n   end\nend\nprocedure main()\n   c := C(41)\n   write(c.bump())\nend\n' > "$D/c.icn"
( cd "$D" && "$U/bin/unicon" -s -o c c.icn > /dev/null 2>&1 && ./c > cout 2>&1 ) ; [ "$(cat "$D/cout" 2>/dev/null)" = 42 ] || { echo "FAIL smoke: unicon did not run a class program (the superset's own marker)"; exit 1; }
echo "OK  unicon oracle: $U/bin/unicon (a plain Icon program and a class program translate, link and run)"
exit 0
