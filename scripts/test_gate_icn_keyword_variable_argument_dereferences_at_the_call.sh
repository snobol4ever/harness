#!/usr/bin/env bash
# test_gate_icn_keyword_variable_argument_dereferences_at_the_call.sh -- a keyword VARIABLE (&pos, &subject) passed as an argument is dereferenced AT THE CALL, and a scan whose body ends in one yields it AFTER the scan environment is restored, as under icont (ceo CEO-653).
#
# MEASURED 2026-09-12 on e44f7d715 (the adversarial batch a01/a13, IcnRungs entries procedure_every_scan_replace_17 and _18):
# `s ? { tab(7); write("back ", &pos, " ", tab(0)) }` printed 7 where icont prints 27 (the argument was read when
# evaluated, not at the call, the way test_gate_icon_arguments_dereference_at_the_call.sh already pins for ordinary
# variables), and `write("q" ? (move(1) & &pos))` printed 2 where icont prints 1 (the scan's value is the keyword
# variable, dereferenced after the environment restores). The runtime cannot serve either: under live scan registers &pos
# is r14+1, and rt_keyword_read's scan_pos is stale. Cure (lowerer): a keyword variable argument is staged like a local
# and its deref node is the register read (IR_KW_ICON) placed after every argument; a scan body whose tail is a keyword
# variable gets that read chained after the leave box. Ref cut from icont, both modes; FAIL_ONCE=1 corrupts the first line.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
ICONT="${ICONT_BIN:-/home/resources/icon-master/bin/icont}"; [ -x "$ICONT" ] || { echo "⛔ GATE REFUSE(2) [$G]: no icont at $ICONT -- the ref is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/k.icn" <<'ICN'
procedure show(a, b, c)
   write("show ", a, " ", b, " ", c);
end
procedure main()
   local s;
   s := "abcdefghijklmnopqrstuvwxyz";
   s ? { tab(7); write("back ", &pos, " ", tab(0)) };
   s ? { tab(3); write(&subject, " ", &pos, " ", tab(5), " ", &pos) };
   s ? { tab(4); show(&pos, tab(9), &pos) };
   s ? { tab(2); write(&subject[&pos:0], " ", &pos, " ", move(3), " ", &pos, " ", &subject) };
   write("q" ? (move(1) & &pos));
   write("xyz" ? (move(2), &pos), " ", "q" ? tab(0));
   s ? { tab(10); "inner" ? { move(2); write("in ", &pos, " ", &subject) }; write("out ", &pos, " ", tab(0)) };
   write(&pos, " ", image(&subject));
end
ICN
( cd "$T" && "$ICONT" -s k.icn -x ) >"$T/k.ref" 2>&1
grep -q '^back 27 ghijklmnopqrstuvwxyz$' "$T/k.ref" || { echo "⛔ GATE REFUSE(2) [$G]: the oracle's first line is not the deref-at-the-call row this gate pins -- the oracle moved: $(head -1 "$T/k.ref")"; exit 2; }
RC=0
for M in m3 m4; do
  if [ "$M" = m3 ]; then ( cd "$T" && timeout -k 5 20 "$SCRIP" k.icn </dev/null ) >"$T/$M.out" 2>&1
  else ( cd "$T" && timeout -k 5 20 "$SCRIP" --compile -o k.s k.icn </dev/null && gcc k.s -o k.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: mode-4 witness did not build"; exit 2; }
       ( cd "$T" && LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 20 ./k.bin </dev/null ) >"$T/$M.out" 2>&1
  fi
  if [ -n "${FAIL_ONCE:-}" ]; then sed -i '1s/^back 27/back 7/' "$T/$M.out"; fi
  if diff -u "$T/k.ref" "$T/$M.out" >"$T/$M.diff"; then echo "  $M PASS ($(wc -l <"$T/k.ref") lines byte-identical to icont)"
  else echo "  $M FAIL ($(grep -c '^[-+][^-+]' "$T/$M.diff") diff lines)"; sed -n '1,14p' "$T/$M.diff" | sed 's/^/      /'; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: keyword variables dereference at the call and a scan yields its keyword-variable value after the restore, as icont does, in both modes"
else echo "GATE FAIL(1) [$G]: a keyword variable argument or scan value is read before the call or before the restore (examined 2 modes)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $ICONT  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
