#!/usr/bin/env bash
# test_gate_icn_unreferenced_linked_procedures_are_not_emitted.sh -- a procedure nothing reaches is not compiled (ceo CEO-635).
#
# MEASURED 2026-09-12 on 5eeeb3a47: IPL gprogs/dlgvu.icn (1900 lines, links cartog/clipping/ddfread and through them the
# graphics library) compiled in 8-10 s to a 97 MB .s, penelope 82 MB -- every procedure of every linked library was lowered
# and emitted whether or not the program could reach it, and the IPL runner's 8 s compile timeout read dlgvu as TIMEOUT.
# Cure, icont's own linker rule: after link resolution the driver keeps `main`, every procedure an `invocable` declaration
# names (`invocable all` keeps all), and, transitively, every procedure whose name appears as an IDENTIFIER in a kept body;
# the rest leave the AST before lowering. A string literal is NOT a reference -- icont drops such a procedure too, so
# proc("unused") fails under both engines unless invocable names it (measured: the oracle's ref for arm 2 carries no
# "unused" line). dlgvu: 3.2 s, 50 MB, 257 procedures kept. Arms, both modes, refs cut from icont:
#   1 a program that never mentions `unused` -- the .s carries no FN__unused and the program answers as icont;
#   2 the same library where `unused` is named only in proc("unused") -- pruned like icont, proc() fails, answers as icont;
#   3 `invocable all` -- kept.
# FAIL_ONCE=1 plants a bogus FN__unused count to prove the absence arm trips.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
ICONT="${ICONT_BIN:-/home/resources/icon-master/bin/icont}"; [ -x "$ICONT" ] || { echo "⛔ REFUSE(2): no icont at $ICONT -- the ref is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/plib.icn" <<'ICN'
procedure used()
   return "used";
end
procedure unused()
   return "unused";
end
ICN
printf 'link plib\nprocedure main()\n   write(used());\nend\n' > "$T/p1.icn"
printf 'link plib\nprocedure main()\n   write(used());\n   write(proc("unused")());\nend\n' > "$T/p2.icn"
printf 'link plib\ninvocable all\nprocedure main()\n   write(used());\n   write(image(proc("unused")));\nend\n' > "$T/p3.icn"
( cd "$T" && "$ICONT" -s -c plib.icn ) >/dev/null 2>&1 || { echo "⛔ REFUSE(2): the oracle did not compile the library"; exit 2; }
RC=0; examined=0
for P in p1 p2 p3; do
  ( cd "$T" && "$ICONT" -s $P.icn -x ) >"$T/$P.ref" 2>&1 || { echo "⛔ REFUSE(2): the oracle itself did not run $P"; exit 2; }
  for M in m3 m4; do
    if [ "$M" = m3 ]; then ( cd "$T" && ICONPATH="$T" timeout -k 5 20 "$SCRIP" $P.icn </dev/null ) >"$T/$P.$M.out" 2>&1
    else ( cd "$T" && ICONPATH="$T" timeout -k 5 20 "$SCRIP" --compile -o $P.s $P.icn </dev/null && gcc $P.s -o $P.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ REFUSE(2): mode-4 witness $P did not build"; exit 2; }
         ( cd "$T" && LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 20 ./$P.bin </dev/null ) >"$T/$P.$M.out" 2>&1
    fi
    examined=$((examined+1))
    if diff -u "$T/$P.ref" "$T/$P.$M.out" >"$T/$P.$M.diff"; then echo "  $P $M PASS (byte-identical to icont)"
    else echo "  $P $M FAIL ($(grep -c '^[-+][^-+]' "$T/$P.$M.diff") diff lines)"; sed -n '1,8p' "$T/$P.$M.diff" | sed 's/^/      /'; RC=1; fi
  done
  n=$(grep -c '^FN__unused' "$T/$P.s"); [ -n "${FAIL_ONCE:-}" ] && [ "$P" = p1 ] && n=1
  examined=$((examined+1))
  case $P in
    p1) if [ "$n" = 0 ]; then echo "  p1 emit PASS (FN__unused absent: nothing reaches it)"; else echo "  p1 emit FAIL (FN__unused emitted $n time(s) though nothing reaches it)"; RC=1; fi;;
    p2) if [ "$n" = 0 ]; then echo "  p2 emit PASS (FN__unused absent: a string literal is not a reference, as under icont)"; else echo "  p2 emit FAIL (FN__unused count $n, expected 0: icont prunes a procedure named only in a string literal)"; RC=1; fi;;
    p3) if [ "$n" = 1 ]; then echo "  p3 emit PASS (FN__unused kept: invocable all)"; else echo "  p3 emit FAIL (FN__unused count $n, expected 1 under invocable all)"; RC=1; fi;;
  esac
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$(basename "${BASH_SOURCE[0]}" .sh)]: an unreached linked procedure is not emitted; identifier and invocable references keep theirs, a string literal does not (examined $examined arms)"
else echo "GATE FAIL(1) [$(basename "${BASH_SOURCE[0]}" .sh)]: procedure reachability pruning is wrong on at least one arm (examined $examined arms)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $ICONT  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
