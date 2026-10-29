#!/usr/bin/env bash
# util_witness_a_false_relational_over_a_fetch_is_a_boolean_value.sh -- the DONE-WHEN witness of the hq_zetas row a-false-relational-over-an-array-element-or-record-field-in-value-position-leaves-a-null.
# MEASURED 2026-10-08 by hq_pascal on SCRIP bae9f6840 (and on the builds of the icon, prolog, snobol4, raku, ceo and cfo roots): a FALSE relational whose operand is an array element or a record field, used as a VALUE (assigned, or passed to
# writeln), leaves a null where fpc -Miso has false, and the next numeric use dies with `scrip: error 102: numeric expected, offending value: &null`, in BOTH modes. A branch form (if a[i] = key) lowers differently, which is why no suite sees it.
# ARMS, both modes, each expectation CUT LIVE from fpc -Miso: arr (the three-line program: want 2), rec (the record-field twin: want 2), arg (writeln(a[1] = 4) and writeln(r.n = 4): want ' false' twice), true (the true cases, which
# are right today and must stay right). rc 0 every arm byte-identical, rc 1 any arm differs, rc 2 cannot measure. It is a UTIL, not a gate: it is red until the planner is cured, and it is not wired anywhere.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ REFUSE(2): no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ REFUSE(2): no fpc at $FPC"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/arr.pas" <<'PAS'
program arr(output);
var b: boolean; a: array[1..2] of integer;
begin a[1] := 3; b := (a[1] = 4); if b then writeln(1) else writeln(2) end.
PAS
cat > "$T/rec.pas" <<'PAS'
program rec(output);
var b: boolean; r: record n: integer; f: boolean end;
begin r.n := 3; b := (r.n = 4); if b then writeln(1) else writeln(2) end.
PAS
cat > "$T/arg.pas" <<'PAS'
program arg(output);
var a: array[1..2] of integer; r: record n: integer; f: boolean end;
begin a[1] := 3; r.n := 3; writeln(a[1] = 4); writeln(r.n = 4) end.
PAS
cat > "$T/true.pas" <<'PAS'
program true(output);
var b: boolean; a: array[1..2] of integer; r: record n: integer; f: boolean end; i: integer;
begin a[1] := 3; r.n := 3; i := 3; b := (a[1] = 3); writeln(b); b := (r.n = 3); writeln(b); b := (i = 4); writeln(b); writeln(a[1] = 3); writeln(r.n = 3) end.
PAS
RC=0
for p in arr rec arg true; do
  ( cd "$T" && "$FPC" -Miso -v0 -o"$p.fpc" "$p.pas" >/dev/null 2>&1 ) || { echo "⛔ REFUSE(2): fpc -Miso would not compile $p"; exit 2; }
  ( cd "$T" && ./"$p.fpc" </dev/null >"$p.want" 2>/dev/null )
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$p.m3" 2>"$p.m3e" )
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 && timeout -k 5 20s ./"$p.m4" </dev/null >"$p.m4o" 2>"$p.m4e" ) || : > "$T/$p.m4o"
  for m in m3 m4; do f="$T/$p.m3"; [ $m = m4 ] && f="$T/$p.m4o"
    if cmp -s "$T/$p.want" "$f"; then echo "  $p $m: identical to fpc -Miso"
    else echo "  ⛔ $p $m DIFFERS: want [$(tr '\n' '|' < "$T/$p.want")] got [$(tr '\n' '|' < "$f" | head -c 60)] err [$(head -1 "$T/$p.${m/m4/m4}e" 2>/dev/null | head -c 70)]"; RC=1; fi
  done
done
if [ "$RC" = 0 ]; then echo "WITNESS GREEN: a false relational over an array element or record field is a Boolean value, both modes"; else echo "WITNESS RED(1): a false relational over an array element or record field in value position is not a Boolean value"; fi
exit $RC
