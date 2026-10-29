#!/usr/bin/env bash
# test_gate_pas_a_name_is_a_char_array_only_where_its_char_array_declaration_is_visible.sh -- a name is read as a char array only
# where the declaration that makes it one is the visible one (ISO 7185 6.2.2): a value formal a: restr of one routine does not make
# the var formal a: strvsp of another a char array, and a local pointer name shadows a global char array of the same name
# (row pascal-p5-selfhost-compile-and-report; the crawl's order, Lon 2026-09-27: "P4, P5, and FPC suite working.")
#
# MEASURED 2026-09-27 by hq_pascal, both modes. g_pas_chararrs was keyed by bare name and never scoped, and every value formal of a
# char-array type was registered there while its heading was parsed: after Pascal-P5's strequri(a: restr; ...), strassvr's
# a := nil; if a = nil then ... parsed a = nil as __pas_strcmp(__pas_alpha_str(a, 1), 0) = 0, read false, and dereferenced nil in
# the else branch -- pcom stopped in entstdnames with ISO 7185 6.5.4 before reading a line of source. THE CURE (pascal.y): each row
# carries the uid of its declaration and a lookup answers only for the visible one (pas_scope_uid, the subrange registry's pattern);
# value formals register from pas_scope_enter against the formal's own defining point (pas_formal_chararrs), with the forward
# heading's signature when the body repeats no parameter list.
#
# ARMS, both modes, stdout and exit code cut LIVE from fpc -Miso: leak -- the P5 shape; shadow -- a local pointer named like a global
# char array; fwdca -- value formals of a char-array type in forward-declared routines whose bodies repeat no list (the arm that
# guards the moved registration: green on the parent too).
# FAILS on the parent 78bfae87c in arms leak (6.5.4 nil dereference, both modes) and shadow (local nil=false). FAIL_ONCE=1 corrupts
# fwdca's ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile and link"; return 125; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/leak.pas" <<'PAS'
program leak(output);
type sp = ^s;
     s = record str: packed array [1..4] of char; next: sp end;
     restr = packed array [1..4] of char;
var q: sp;
function strequri(a: restr; b: restr): boolean; begin strequri := a = b end;
procedure strassvr(var a: sp);
var lp, p: sp;
begin a := nil; lp := nil; new(p); p^.next := nil;
  if a = nil then a := p else lp^.next := p;
  writeln('a nil=', a = nil)
end;
begin
  new(q); strassvr(q); writeln(q = nil, ' ', strequri('abcd', 'abcd'), ' ', strequri('abcd', 'abce'))
end.
PAS
cat > "$T/shadow.pas" <<'PAS'
program shadow(output);
type alpha = packed array [1..4] of char;
     ip = ^integer;
var name: alpha;
procedure local;
var name: ip;
begin new(name); name^ := 7; name := nil; writeln('local nil=', name = nil) end;
procedure uses;
begin writeln('global=', name, ' eq=', name = 'wxyz') end;
begin
  name := 'wxyz'; local; uses; writeln(name)
end.
PAS
cat > "$T/fwdca.pas" <<'PAS'
program fwdca(output);
type alpha = packed array [1..4] of char;
procedure show(a: alpha; n: integer); forward;
function same(a, b: alpha): boolean; forward;
procedure show; begin writeln(a, ' ', n:1, ' ', a = 'abcd') end;
function same; begin same := a = b end;
begin
  show('abcd', 1); show('wxyz', 2); writeln(same('abcd', 'abcd'), ' ', same('abcd', 'abcx'))
end.
PAS
for p in leak shadow fwdca; do
  frc=$(fpcrun $p)
  if [ "$p" = fwdca ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a name is a char array only where its char-array declaration is visible, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 3 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
