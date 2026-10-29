#!/usr/bin/env bash
# test_gate_icn_a_scan_builtin_is_its_box_in_every_icon_graph_and_a_programs_own_procedure_of_that_name_is_called.sh -- ARCH-ICON-RTX.md
# 10.7, ROAD A (SCRIP e2d6a1d85): the nine scanning builtins (tab move upto any many find match pos bal) are their boxes in EVERY Icon
# graph, not only inside a lexical ?, because (r13, r14, r15) is the scan environment at every instruction -- a procedure with no ? of its
# own moves its caller's &pos; a program's own procedure, a reassigned builtin, a local or a global of the same name is NOT retagged; and a
# resumed suspend re-enters a SCAN_TAB / SCAN_MOVE box at beta (emit.cpp's g_suspend_dobody_beta), so a suspended move restores &pos.
#
# THE TWO WITNESSES, refs cut from iconx 9.5.25a when the gate was written and re-cut when the oracle is on the box (rc=2 on disagreement):
#   w1 -- p/q/r move, tab and tab(upto(' ')) the caller's subject from procedures with no ?; m(n) suspends move(n) and e(s) suspends =s,
#         resumed by every, by a failing conjunction and inside an alternation.
#   w2 -- the program's own procedure tab, called inside and outside a scan: iconx calls the program's tab both times.
# THE LOWERING ARM reads --dump-ir: w1's procedures hold SCAN_MOVE (p, m), SCAN_TAB (q, r, e), SCAN_UPTO (r), SCAN_MATCH (e) and no call
# names a scanning builtin; w2 calls its tab twice as CALL_PROC_STAGED and lowers no SCAN_TAB.
#
# RED BEFORE (measured with lower_icon.c at SCRIP 2f4c84124, before road A): FAIL w2 m3 and m4, FAIL both lowering arms -- the callees
# lowered seven calls naming a scan builtin and w2's in-scan tab lowered SCAN_TAB (iconx: my tab 3, SCRIP: the builtin); w1's OUTPUT was
# already right there, because road B's C-road syncs carried the environment, so the lowering arm is what holds road A; on road A's first cut (no suspend arm) w1's every m(2) printed 3 5 7 7 for iconx's 3 1 and
# ladder__rung05_scan_a_suspended_tab_restores_pos_on_backtrack hung. GREEN AFTER (e2d6a1d85): both witnesses m3 and m4 byte-identical
# to iconx, the lowering arm as above.
#
# Usage: bash ../harness/scripts/test_gate_icn_a_scan_builtin_is_its_box_in_every_icon_graph_and_a_programs_own_procedure_of_that_name_is_called.sh
set -uo pipefail
G=test_gate_icn_a_scan_builtin_is_its_box_in_every_icon_graph_and_a_programs_own_procedure_of_that_name_is_called
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
. "$HERE/lib_gate.sh"
. "$HERE/lib_oracle_flags.sh"
gate_parse_args "$@"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$G]: no scrip binary at $SCRIP -- run make first"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$G" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
command -v gcc >/dev/null || { echo "⛔ REFUSED(2) [$G]: no gcc -- the mode-4 arm cannot be linked"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cat > "$T/w1.icn" <<'ICN'
procedure p();
  move(1);
  return;
end
procedure q();
  tab(3);
  return;
end
procedure r();
  tab(upto(' '));
  return;
end
procedure m(n);
  suspend move(n);
end
procedure e(s);
  suspend =s;
end
procedure main();
  "abcd" ? { p(); write(&pos) };
  "abcd" ? { q(); write(&pos) };
  "ab cd" ? { r(); write(&pos) };
  "abcdef" ? { every m(2) do write(&pos); write(&pos) };
  "abcdef" ? { (m(2) & &fail) | write(&pos) };
  "abcdef" ? { (e("ab") & e("x")) | write(&pos) };
  "abcdef" ? { every write(m(2) | 5, " ", &pos) };
end
ICN
cat > "$T/w1.ref" <<'REF'
2
3
3
3
1
1
1
ab 3
5 1
REF
cat > "$T/w2.icn" <<'ICN'
procedure tab(n);
  write("my tab ", n);
  return;
end
procedure main();
  "abcd" ? { tab(3); write(&pos) };
  tab(2);
end
ICN
cat > "$T/w2.ref" <<'REF'
my tab 3
1
my tab 2
REF
if ICONT="$(icont_bin 2>/dev/null)"; then
    for w in w1 w2; do
        ( cd "$T" && "$ICONT" -s -o "$w.x" "$w.icn" > /dev/null 2>&1 && timeout -k 5 20 "./$w.x" < /dev/null > "$w.oracle" 2>/dev/null ) || { echo "⛔ REFUSED(2) [$G]: icont/iconx refuses witness $w"; exit 2; }
        cmp -s "$T/$w.oracle" "$T/$w.ref" || { echo "⛔ REFUSED(2) [$G]: iconx no longer prints the carried $w.ref -- re-cut it from the oracle, never from SCRIP"; exit 2; }
    done
fi
fail=0
for w in w1 w2; do
    ( cd "$T" && timeout -k 5 20 "$SCRIP" "$w.icn" < /dev/null > "$w.m3" 2>&1 ); rc3=$?
    if cmp -s "$T/$w.m3" "$T/$w.ref"; then echo "  ok   ($w m3) as iconx"; else echo "  FAIL ($w m3) rc=$rc3, first difference:"; diff "$T/$w.ref" "$T/$w.m3" | head -6 | sed 's/^/         /'; fail=1; fi
    if ( cd "$T" && "$SCRIP" --compile --out="$w.s" "$w.icn" < /dev/null > /dev/null 2>&1 && gcc -no-pie -o "$w.bin" "$w.s" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm -lpthread 2> /dev/null ); then
        ( cd "$T" && timeout -k 5 20 "./$w.bin" < /dev/null > "$w.m4" 2>&1 ); rc4=$?
        if cmp -s "$T/$w.m4" "$T/$w.ref"; then echo "  ok   ($w m4) the same, from the standalone build"; else echo "  FAIL ($w m4) rc=$rc4, first difference:"; diff "$T/$w.ref" "$T/$w.m4" | head -6 | sed 's/^/         /'; fail=1; fi
    else echo "  FAIL ($w m4) the witness did not compile or link in mode 4"; fail=1; fi
done
low1="$(cd "$T" && "$SCRIP" --dump-ir w1.icn < /dev/null 2>&1 | awk '/^; proc/{p=$3} p!="main" && $4 ~ /^SCAN_(MOVE|TAB|UPTO|MATCH)$/{printf "%s %s|", p, $4}')"
bad1="$(cd "$T" && "$SCRIP" --dump-ir w1.icn < /dev/null 2>&1 | grep -cE 'CALL[A-Z_]* +\[[^]]*\] +"(tab|move|upto|match)"')"
want1='p SCAN_MOVE|q SCAN_TAB|r SCAN_UPTO|r SCAN_TAB|m SCAN_MOVE|e SCAN_MATCH|e SCAN_TAB|'
if [ "$low1" = "$want1" ] && [ "$bad1" = 0 ]; then echo "  ok   (lowering w1) the callees' builtins are their boxes and no call names one"; else echo "  FAIL (lowering w1) boxes [$low1] want [$want1], calls naming a scan builtin $bad1"; fail=1; fi
own2="$(cd "$T" && "$SCRIP" --dump-ir w2.icn < /dev/null 2>&1 | grep -cE 'CALL_PROC_STAGED +\[[^]]*\] +"tab"')"
box2="$(cd "$T" && "$SCRIP" --dump-ir w2.icn < /dev/null 2>&1 | grep -c 'SCAN_TAB')"
if [ "$own2" = 2 ] && [ "$box2" = 0 ]; then echo "  ok   (lowering w2) the program's own tab is called twice and never retagged"; else echo "  FAIL (lowering w2) CALL_PROC_STAGED tab $own2 (want 2), SCAN_TAB $box2 (want 0)"; fail=1; fi
[ "$fail" = 0 ] && { echo "✅ GATE PASS [$G]: road A's witnesses m3 and m4 as iconx, the builtins boxes in every graph and a program's own tab its call"; exit 0; }
echo "⛔ GATE RED [$G]"; exit 1
