#!/usr/bin/env bash
# test_gate_table_convert_creation_order.sh -- CONVERT(table,'ARRAY') places entries in CREATION order.
# Row snobol4-table-convert-to-array-uses-hash-bucket-order-not-documented-creation-order (ceo CEO-356,
# briefed by seat01/seat02; cured hq_P 2026-09-06).
#
# ⭐ THIS IS DOCUMENTED SPITBOL SEMANTICS, NOT DIALECT LATITUDE.  Manual v3.7, Reference sec CONVERT:
# "entries are placed in the resultant array in the order they were created in the table.  That is, older
# table elements come before newer ones."  RULES.md binds SCRIP to SPITBOL semantics for SNOBOL4/Snocone,
# so hash-bucket order is a defect and not an implementation choice.
#
# ⛔ ARM 2 IS THE ONE A CONVERT-ONLY FIX GETS WRONG, AND IT WAS SETTLED AGAINST THE ORACLE RATHER THAN
# ASSUMED: re-assigning an EXISTING key must NOT move it to the end -- an entry is CREATED once, and
# assigning to it again is not a re-creation.  sbl -bf prints A=99 FIRST for A,B,C then T<'A'>=99.  An
# implementation that stamps order on every assignment passes arm 1 and fails only this one.
#
# ⛔ ARM 3 EXISTS BECAUSE THE ORDER LOG CAN GO OUT OF SYNC WITH THE TABLE.  Icon's delete() removes table
# entries (table_delete_d), so the log must be compacted there too; if it is not, CONVERT walks a key that
# is gone.  A hash-only match when compacting would remove the WRONG key on a collision, which is why the
# cure reuses the table's own _tbl_eq_d rather than minting a second equality -- two equality rules that
# disagree is its own defect class.  This arm inserts 40 and deletes 20 and checks nothing is lost or stale.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; SD="$HERE/../../SCRIP"; SCRIP="$SD/scrip"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(rc=2): no scrip binary at $SCRIP -- build first (make)"; exit 2; }
"$HERE/util_require_fresh.sh" --gate test_gate_table_convert_creation_order "$SCRIP" "${RT_DIR:-$SD/out}/libscrip_rt.so" || exit 2
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
fail=0
grade() {  # $1 label  $2 sno file  $3 expected stdout
    local lab="$1" f="$2" want="$3" m3 m4
    m3="$(cd "$W" && timeout -k 5 20 "$SCRIP" --run "$f" </dev/null 2>&1)"
    [ "$m3" = "$want" ] || { echo "  ⛔ $lab m3 RED -- got:"; printf '%s\n' "$m3" | sed 's/^/      /'; echo "     want:"; printf '%s\n' "$want" | sed 's/^/      /'; fail=1; }
    if (cd "$W" && timeout -k 5 60 "$SCRIP" --compile -o "$W/p.s" "$f" </dev/null >/dev/null 2>&1) \
       && gcc -no-pie "$W/p.s" -L"$SD/out" -lscrip_rt -lm -Wl,-rpath,"$SD/out" -o "$W/p.bin" 2>/dev/null; then
        m4="$(cd "$W" && timeout -k 5 20 "$W/p.bin" </dev/null 2>&1)"
        [ "$m4" = "$want" ] || { echo "  ⛔ $lab m4 RED -- got:"; printf '%s\n' "$m4" | sed 's/^/      /'; fail=1; }
    else echo "  ⛔ $lab m4 REFUSED: compile/link failed"; fail=1; fi
}
cat > "$W/a1.sno" <<'EOF'
	T = TABLE()
	T['A'] = 1
	T['B'] = 2
	T['C'] = 3
	T['D'] = 4
	C = CONVERT(T,'ARRAY')
	I = 1
L	OUTPUT = C[I,1] '=' C[I,2]		:F(D)
	I = I + 1				:(L)
D
END
EOF
cat > "$W/a2.sno" <<'EOF'
	T = TABLE()
	T['A'] = 1
	T['B'] = 2
	T['C'] = 3
	T['A'] = 99
	C = CONVERT(T,'ARRAY')
	I = 1
L	OUTPUT = C[I,1] '=' C[I,2]		:F(D)
	I = I + 1				:(L)
D
END
EOF
echo "== CONVERT(table,'ARRAY') is CREATION order (SPITBOL manual v3.7, Reference sec CONVERT)"
grade "arm1 creation order" a1.sno "$(printf 'A=1\nB=2\nC=3\nD=4')"
grade "arm2 reassign keeps position" a2.sno "$(printf 'A=99\nB=2\nC=3')"
cat > "$W/a3.icn" <<'EOF'
procedure main();
  local t, i, n;
  t := table();
  every i := 1 to 40 do t["k" || i] := i;
  every i := 1 to 40 by 2 do delete(t, "k" || i);
  n := 0;
  every key(t) do n +:= 1;
  write("live=", n, " size=", *t);
  every i := 2 to 40 by 2 do if /t["k" || i] then write("LOST k", i);
  every i := 1 to 40 by 2 do if \t["k" || i] then write("STALE k", i);
  write("done");
end
EOF
a3="$(cd "$W" && timeout -k 5 30 "$SCRIP" --run a3.icn </dev/null 2>&1)"
if [ "$a3" != "$(printf 'live=20 size=20\ndone')" ]; then
    echo "  ⛔ arm3 RED: delete() and the creation-order log are out of sync -- got:"; printf '%s\n' "$a3" | sed 's/^/      /'; fail=1
fi
[ "$fail" = 0 ] && { echo "OK: creation order held on 3 arms (order, reassign, delete-sync), both modes"; exit 0; }
echo "⛔ GATE RED: CONVERT(table,'ARRAY') is not in creation order"; exit 1
