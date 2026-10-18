#!/usr/bin/env bash
# test_gate_pas_a_char_array_component_is_stored_read_and_copied_as_fpc_does.sh -- a character array inside a record or an array element, and a structured formal, behave as fpc -Miso's.
#
# MEASURED 2026-10-10 by hq_pascal on the Pascal-S and BASIC demos (row pascal-demos-...-ceo-1579), each defect a red against fpc -Miso in both modes on SCRIP 70f3505ed:
# (1) a record declared in a variable declaration (an anonymous record, Pascal-S's tab: array [0..tmax] of packed record name: alfa ...) had no record type, so its character-array fields lost their facts:
#     tab[0].name := id stored the array object and printed ARRAY('1:4'), tab[j].name <> id compared identities, and Pascal-S walked past its sentinel to tab[-1] (6.5.3.2); an inline packed array of char field printed
#     empty. CURE: the variable declaration registers such a record as a record type of its own ($anonrec<n>, the name the nested records already use) without binding a variant tag to it; the with-statement over an
#     array element marks a character-array field as the plain selector does.
# (2) an array whose elements are character arrays (BASIC's prgm: array [0..maxpgm] of string80) was made with empty elements, so prgm[x][y] := ' ' stopped with 6.5.3.2 at y = 2. CURE: each element is made as a
#     character array of the element type's bounds (__pas_arr_of), as an array of records already is.
# (3) a variable formal of a character-array type was not registered as a character array (only value formals were), so read(str[i]) read an integer (6.9.1). CURE: both kinds register.
# (4) a formal of a record or array type assigned whole (g := r, tab[i] := r, prgm[i] := str) stored a reference to the actual, so a later change to the actual showed through (fpc 1 5 1 5, SCRIP 99 99 99 99); BASIC's
#     program store aliased its input line. CURE: a formal of a structured type is an aggregate designator, copied on assignment and on a value actual (__pas_arr_copy, identity on a non-aggregate).
# (5) a character of a character-array field of a record that is an array element (BASIC's temp[top].bstr.str[i] := getchr) stopped with 6.5.3.2 at the second character. CURE: the in-place field update reaches
#     any element or field base, evaluated once.
# (6) a character of an element of an array of character arrays (l[2][2]) printed its ordinal, and the comma form l[2, 2] died error 22 (an arr_get of two indices on a one-index array). CURE: such a character is a
#     char, and a selector of several indices is the nested selector ISO 7185 6.5.3.2 defines (a[i, j] is a[i][j]) unless its variable is a two-index array the elaborator flattens.
# (7) a program that declares its own type named string (Rosetta quine-3: type string = packed array[1..60] of char) had its values treated as the built-in string and printed empty. CURE: a name the program
#     declares as an array type is never a built-in string kind.
#
# ARMS, both modes, every expectation cut LIVE from fpc -Miso: one program per defect above (the read arm fed a line on standard input). FAIL_ONCE=1 corrupts arm 1's expectation.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
inp() { if [ -f "$T/$1.in" ]; then echo "$T/$1.in"; else echo /dev/null; fi; }
run() { local m="$1" p="$2" i; i=$(inp "$p")
  if [ "$m" = m3 ]; then ( cd "$T" && timeout -k 5 60s "$SCRIP" --run "$p.pas" <"$i" >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 60s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4 did not compile or link" >&2; return 99; }
  ( cd "$T" && timeout -k 5 60s "./$p.m4" <"$i" >"$T/o" 2>"$T/e" ); return $?; }
want() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 60s ./$1.fpc <"$(inp "$1")" >"$T/$1.want" 2>/dev/null ); return $?; }
cat > "$T/anon.pas" <<'PAS'
program anon(output);
type alfa = packed array [1..4] of char;
var tab: array [0..5] of packed record name: alfa; link: integer end;
    r: record name: alfa; link: integer end;
    q: record name: packed array [1..4] of char; n: integer end;
    id: alfa; j, k: integer;
procedure outer;
  procedure enter(id: alfa);
  begin tab[0].name := id; j := 2; while tab[j].name <> id do j := tab[j].link; writeln('found at ', j) end;
begin enter('abcd'); enter('rrrr') end;
begin
  tab[0].name := 'zzzz'; tab[0].link := -1; tab[1].name := 'qqqq'; tab[1].link := 0; tab[2].name := 'rrrr'; tab[2].link := 1;
  outer; if tab[0].name = 'rrrr' then writeln('stored') else writeln('not stored');
  id := 'wxyz'; r.name := id; writeln(r.name); q.name := id; writeln(q.name, ' ', q.name[2]);
  with tab[3] do name := id; writeln(tab[3].name); k := 4; tab[k].name := id; tab[k].name[1] := 'Q'; writeln(tab[k].name, ' ', tab[4].name[1]);
  if tab[3].name = id then writeln('eq'); if tab[4].name <> id then writeln('ne'); if tab[4].name < 'Rzzz' then writeln('lt'); if 'Pzzz' < tab[4].name then writeln('gt')
end.
PAS
cat > "$T/elem.pas" <<'PAS'
program elem(output);
type s8 = packed array [1..8] of char; bs = record len: integer; str: s8 end;
var prgm: array [0..3] of s8; t: array [1..3] of bs; temp: array [1..3] of record typ: integer; int: integer; bstr: bs end; x, y, top: integer;
begin
  for x := 1 to 3 do for y := 1 to 8 do prgm[x][y] := ' '; prgm[2][3] := 'q'; writeln('[', prgm[2], ']');
  prgm[1, 2] := 'c'; x := 2; writeln(prgm[2][3], prgm[x, 3], prgm[1][2], prgm[x - 1, x]);
  for y := 1 to 8 do t[2].str[y] := chr(ord('a') + y - 1); writeln(t[2].str, ' ', t[2].str[3]);
  top := 2; for y := 1 to 8 do temp[top].bstr.str[y] := chr(ord('k') + y - 1); temp[top].bstr.len := 8; writeln(temp[top].bstr.str, ' ', temp[top].bstr.len, ' ', temp[2].bstr.str[3])
end.
PAS
cat > "$T/rd.pas" <<'PAS'
program rd(input, output);
type s8 = packed array [1..8] of char;
var a: s8; prgm: array [0..3] of s8;
procedure inp(var str: s8); var i: integer; begin for i := 1 to 8 do str[i] := ' '; i := 1; while (i <= 8) and not eoln do begin read(str[i]); i := i + 1 end; readln end;
begin inp(a); writeln('[', a, ']'); inp(prgm[0]); writeln('[', prgm[0], ']') end.
PAS
printf 'hello\nworld!\n' > "$T/rd.in"
cat > "$T/alias.pas" <<'PAS'
program alias(output);
type rt = record a, b: integer end; at = array [1..3] of integer; s8 = packed array [1..8] of char;
var g, h: rt; ga, ha: at; tab: array [1..2] of rt; taa: array [1..2] of at; prgm: array [0..3] of s8; a: s8;
procedure keep(var r: rt; var x: at); begin g := r; ga := x; tab[1] := r; taa[2] := x end;
procedure vkeep(r: rt); begin g := r; r.a := 77; writeln(g.a, ' ', r.a) end;
procedure enter(var str: s8; i: integer); begin prgm[i] := str end;
begin
  h.a := 1; h.b := 2; ha[1] := 5; ha[2] := 6; ha[3] := 7; keep(h, ha); h.a := 99; ha[1] := 99; writeln(g.a, ga[1], tab[1].a, taa[2][1]);
  vkeep(h); writeln(g.a, ' ', h.a);
  a := 'first   '; enter(a, 1); a[1] := 'X'; prgm[0] := 'second  '; enter(prgm[0], 2); prgm[0] := 'third   '; writeln(prgm[0]); writeln(prgm[1]); writeln(prgm[2]); writeln(a)
end.
PAS
cat > "$T/ustr.pas" <<'PAS'
program ustr(output);
type string = packed array [1..6] of char;
var l: array [1..3] of string; s: string; i: integer;
begin l[1] := 'one   '; l[2] := 'two   '; s := 'three '; l[3] := s; for i := 1 to 3 do writeln(l[i], '|'); writeln(s, l[2][2]) end.
PAS
RC=0; N=0
chk() { local m="$1" p="$2" frc="$3"; run $m $p; local rc=$?; N=$((N + 1))
  if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
  else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; }
want anon; arc=$?; want elem; erc=$?; want rd; rrc=$?; want alias; lrc=$?; want ustr; urc=$?
if [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/anon.want"; fi
for m in m3 m4; do chk $m anon $arc; chk $m elem $erc; chk $m rd $rrc; chk $m alias $lrc; chk $m ustr $urc; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: character-array components, structured formals and a declared string type answer as fpc -Miso in both modes, $N of $N arms"
else echo "GATE FAIL(1) [$G]: a character-array component or a structured formal differs from fpc -Miso, see the arms above"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
