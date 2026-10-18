#!/usr/bin/env bash
# test_gate_icn_field_access_on_a_non_record_raises_107.sh -- x.f on a non-record raises 107, a bad field 207, as under icont (ceo CEO-644).
#
# MEASURED 2026-09-12 on 83ace92b0 (the adversarial batch): `&error := 1; x := &null.f` read &errornumber 114 in one shape and
# in another the access FAILED SILENTLY (no error at all, &errornumber unset) where icont raises 107 "record expected"; a
# list's field read 207 where icont says 107. Cure: the Icon field box calls icn_field_get (rvalue) and rt_field_var
# (lvalue) raise 107 with the offending value for anything that is not a record instance (a list is not a record) and 207
# for a field the record does not carry; SNOBOL4's field functions keep their own path. Arms: null, integer, string, list,
# and a bad field name under &error, plus a fatal 107 rendered through the error-voice list, byte-identical to icont in both
# modes. FAIL_ONCE=1 corrupts the captured stream to prove the diff arm trips.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
ICONT="${ICONT_BIN:-/home/resources/icon-master/bin/icont}"; [ -x "$ICONT" ] || { echo "⛔ REFUSE(2): no icont at $ICONT -- the ref is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/r.icn" <<'ICN'
record r(a, b)
procedure main()
   local x, n, i, s, L, p;
   &error := -1;
   n := &null; x := n.f; write("null ", &errornumber, " ", image(&errorvalue));
   i := 5; x := i.f; write("int ", &errornumber, " ", image(&errorvalue));
   s := "s"; x := s.f; write("str ", &errornumber);
   L := [1]; x := L.f; write("list ", &errornumber);
   p := r(1, 2); x := p.zz; write("badfield ", &errornumber, " ", image(&errorvalue));
   p.zz := 3; write("badfield-lv ", &errornumber);
   write(p.a, " ", p.b, " ", (p.b := 9), " ", p.b);
   &error := 0;
   x := n.f;
   write("unreached");
end
ICN
( cd "$T" && "$ICONT" -s r.icn -x ) >"$T/r.ref.raw" 2>&1; python3 "$HERE/util_render_error_voice.py" icon < "$T/r.ref.raw" > "$T/r.ref"
grep -q '^null 107 &null$' "$T/r.ref" || { echo "⛔ REFUSE(2): the oracle's own first line is not the 107 row this gate pins -- the oracle moved: $(head -1 "$T/r.ref")"; exit 2; }
grep -q 'Run-time error 107' "$T/r.ref" || { echo "⛔ REFUSE(2): the oracle's stream carries no fatal 107 -- the fatal arm cannot be graded"; exit 2; }
RC=0
for M in m3 m4; do
  if [ "$M" = m3 ]; then ( cd "$T" && timeout -k 5 20 "$SCRIP" r.icn </dev/null ) 2>&1 | python3 "$HERE/util_render_error_voice.py" icon >"$T/$M.out"
  else ( cd "$T" && timeout -k 5 20 "$SCRIP" --compile -o r.s r.icn </dev/null && gcc r.s -o r.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ REFUSE(2): mode-4 witness did not build"; exit 2; }
       ( cd "$T" && LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 20 ./r.bin </dev/null ) 2>&1 | python3 "$HERE/util_render_error_voice.py" icon >"$T/$M.out"
  fi
  if [ -n "${FAIL_ONCE:-}" ]; then sed -i '1s/^null 107/null 114/' "$T/$M.out"; fi
  if diff -u "$T/r.ref" "$T/$M.out" >"$T/$M.diff"; then echo "  $M PASS (byte-identical to icont through the error-voice list)"
  else echo "  $M FAIL ($(grep -c '^[-+][^-+]' "$T/$M.diff") diff lines)"; sed -n '1,12p' "$T/$M.diff" | sed 's/^/      /'; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$(basename "${BASH_SOURCE[0]}" .sh)]: field access on a non-record raises 107 and a bad field 207, converted under &error and fatal, in both modes"
else echo "GATE FAIL(1) [$(basename "${BASH_SOURCE[0]}" .sh)]: a field access on a non-record does not raise as icont does (examined 2 modes)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $ICONT  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
