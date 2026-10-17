#!/usr/bin/env bash
# test_gate_icn_monitor_names_and_types_a_value_as_icx_does.sh -- A VALUE EVENT NAMES THE SOURCE VARIABLE AND TYPES THE VALUE AS
# ICX DOES (hq_icon 2026-09-25, crawl work under CEO-1270 / CEO-1272 (c)).
#
# Three false divergences the monitor census over the 111 graded Arizona programs measured, each from SCRIP's plug:
#   (1) a static local went on the wire under its lowering's mangled global name (main__STATIC__y) where icx sends y;
#   (2) SCRIP's own synthetic globals (__icn_progname, the initial-block flags PROC__INITFLAG__n) produced VALUE events that no
#       source assignment makes, so icx never sends them;
#   (3) a set went on the wire as MWT_TABLE (SCRIP keeps a set as a table block with is_set) where icx sends MWT_DATA;
#   (4) a procedure value (p := write, q := proc("*", 2)) went on the wire as MWT_EXPRESSION -- SCRIP keeps it as a DT_E with the
#       procedure-value marker -- where icx sends MWT_CODE (hq_icon 2026-09-26: it was the FIRST divergence of every bracket that
#       assigns a procedure value, cured or not, e.g. IPL procname's witnesses, so it hid the real one behind it);
#   (5) an initial clause: its flag went on the wire as VALUE <lval> = 1 (the rewrite assigned it through /flag := 1) and its
#       statement sent a LABEL on every call, where icx labels only the clause's own statements and only on the call that runs
#       them (hq_icon 2026-09-27: it blocked the bracket of every procedure with an initial clause, IPL regexp among them);
#   (6) /g := v on a global sent VALUE g (the cell-store tap) AND VALUE <lval> (the assignment's own trace), and a substring
#       assignment t[-1] := "" sent the underlying t's new value as <lval> before the assigned one, where icx sends one event
#       for each (hq_icon 2026-09-27: regexp's /Re_WordChars := ... and s[-1] := "");
#   (7) a statement that lowers to a generator-kind entry (every if) inside a { } block sent no LABEL: the block loop labelled a
#       statement only when no trampoline stood in front of its entry (hq_icon 2026-09-27: regexp line 444).
#   (8) a reversible assignment x <- v traced x AFTER its store, so where a caller rewired the store's success (an operand of
#       ||) the trace was left behind and no VALUE went out; and &subject <- s / &pos <- i sent VALUE &subject / &pos, where
#       icx sends nothing for a keyword (hq_icon 2026-09-27: IPL patterns, (n <- Span(...)) || ="H" || ...).
# core.c's rt_trace_value now shows a static by its source name and emits nothing for a synthetic global, and one typing helper
# (mon_wire_type) sends a set as DATA, as monitor_icx.c types T_Set, and a procedure value as CODE.
#
# THE WITNESS assigns a static local, a set and two procedure values and then runs a statement that needs &progname: it must
# bracket AGREE. On core.c before (1)-(3) it DIVERGES at the static's VALUE, and before (4) at p's VALUE (red).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G=test_gate_icn_monitor_names_and_types_a_value_as_icx_does
[ -x "$HERE/../../SCRIP/scrip" ] || { echo "⛔ GATE REFUSE(2) [$G]: scrip not built"; exit 2; }
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"; S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"
IM="${ICON_MON_ROOT:-$S4A/icon-mon}"
[ -x "$IM/bin/icont" ] && [ -x "$IM/bin/iconx" ] || { echo "⛔ GATE REFUSE(2) [$G]: the instrumented Icon fork is not built at $IM -- this gate cannot measure without icx"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/valname_gate.XXXXXX")" || { echo "⛔ GATE REFUSE(2) [$G]: mktemp failed"; exit 2; }
trap 'rm -rf "$T"' EXIT
cat > "$T/valname.icn" <<'EOF'
procedure span(c)
   suspend tab(many(c));
end
procedure f()
   static k;
   initial k := 3;
   k +:= 2;
   write(k);
end
global g
procedure main()
   local s, n, p, q, t;
   s := set([1, 2]);
   f();
   f();
   p := write;
   q := proc("*", 2);
   /g := 4;
   t := "ab";
   t[-1] := "";
   if *t > 0 then {
      n := 1;
      if n > 0 then {
         n := 2
         };
      n := 3
      };
   "5H1" ? ((n <- span('0123456789')) || ="H");
   (&subject <- "xy") & (&pos <- 2) & (n <- 4);
   n := *s;
   p(n, " ", *&progname > 0, " ", q(2, 3));
end
EOF
out="$(cd "$T" && timeout -k 5 300 bash "$HERE/monitor_run.sh" valname.icn --oracle 2>&1)"; rc=$?
line="$(printf '%s\n' "$out" | grep -aE '^\[monitor_run\] (AGREE|DIVERGE|UNGRADED)|REFUSE|^\| \*\*>' | tail -2 | tr '\n' ' ' | cut -c1-240)"
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -qa '^\[monitor_run\] AGREE'; then
    echo "  $line"
    echo "✅ GATE PASS [$G]: a static, a set, two procedure values and &progname bracket AGREE against icx"; exit 0
fi
echo "  rc=$rc $line"
echo "⛔ GATE FAIL [$G]: the witness did not bracket AGREE -- a VALUE event is named or typed unlike icx"; exit 1
