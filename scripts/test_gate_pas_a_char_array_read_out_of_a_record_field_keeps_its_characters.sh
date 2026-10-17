#!/usr/bin/env bash
# test_gate_pas_a_char_array_read_out_of_a_record_field_keeps_its_characters.sh -- a packed array of char read out of a record
# field and given to a char-array variable, a char-array value formal, another record's field or a row of an array of such arrays
# keeps its characters, as fpc -Miso does (row pascal-p4-self-hosts-under-scrip..., ceo CEO-1311)
#
# MEASURED 2026-09-27 by hq_pascal, both modes. Since SCRIP 53011510a a char-array record field holds its characters densely and
# __pas_ca_unpack is the identity, but a char-array VARIABLE holds the ordinal-per-slot encoding: gn := p^.name stored the dense
# bytes into gn, which then decoded as empty. P4's enterid copies nam := fcp^.name before every name comparison, so every
# identifier of comp_detab.p compared against an empty name, the name tree degenerated into a left spine, searchid missed the
# constants it had just entered, and generation 1 reported 2796 errors (error 104 from line 64 on). The same dense value reached a
# char-array value formal, a row of an array of alpha, and (re-packed by __pas_ca_pack) another record's field, all as empty.
# THE CURE: __pas_ca_encode re-encodes a dense field read for each of those sinks with the sink's own bounds; a field-to-field copy
# skips the pack. OPEN, NOT GRADED HERE: a function whose result type is a char array keeps whatever representation it was given
# (f := 'abcdefgh' then g := f reads empty) -- its result is not registered as a char array; P4 and P5 have no such function.
#
# ARMS, both modes, stdout and exit code cut LIVE from fpc -Miso: (1) cavar -- the field read into a global, into a procedure local
# through a pointer parameter and through with, from a local record, and back into a field; (2) casink -- field to field, to a value
# formal, to a row; (3) ptree -- P4's own enterid/search name tree over the first twenty-one constants of comp_detab.p.
# FAILS on the parent 964982d54 in every arm. FAIL_ONCE=1 corrupts arm (2)'s ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- every arm's expectation is CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
run() { local m="$1" p="$2"
  if [ "$m" = m3 ]; then ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" --run "$p.pas" </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile -o "$T/$p.s" "$p.pas" </dev/null >/dev/null 2>&1 && cc -m64 -no-pie "$p.s" -o "$p.m4" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || { echo "  ⛔ $p m4: did not compile and link"; return 125; }
  ( cd "$T" && timeout -k 5 20s "./$p.m4" </dev/null >"$T/o" 2>"$T/e" ); return $?; }
fpcrun() { ( cd "$T" && "$FPC" -Miso -v0 -o"$1.fpc" $1.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile $1"; exit 2; }; ( cd "$T" && timeout -k 5 20s ./$1.fpc </dev/null >"$T/$1.want" 2>/dev/null ); echo $?; }
cat > "$T/cavar.pas" <<'PAS'
program cavar(output);
type alpha = packed array [1..8] of char;
     ptr = ^node;
     node = packed record name: alpha; link: ptr end;
     lrec = record tag: integer; name: alpha end;
var p, q: ptr; g: alpha; r: lrec;
procedure viaparam(fcp: ptr);
  var nam: alpha;
begin nam := fcp^.name; writeln('param  [', nam, '] lt=', nam < g, ' eq=', nam = fcp^.name) end;
procedure viawith;
  var nam: alpha;
begin with p^ do nam := name; writeln('with   [', nam, ']') end;
begin
  new(p); p^.name := 'maxlevel'; g := 'zzzzzzzz';
  g := p^.name; writeln('global [', g, ']');
  g := 'zzzzzzzz'; viaparam(p); viawith;
  r.tag := 7; r.name := 'charal  '; g := r.name; writeln('local  [', g, ']');
  new(q); q^.name := g; writeln('field<-var [', q^.name, ']')
end.
PAS
cat > "$T/casink.pas" <<'PAS'
program casink(output);
type alpha = packed array [1..8] of char;
     ptr = ^node;
     node = packed record name: alpha; link: ptr end;
var p, q: ptr; rw: array [1..3] of alpha; g: alpha;
procedure pv(s: alpha); begin writeln('value param [', s, ']') end;
begin
  new(p); p^.name := 'maxlevel'; new(q); q^.name := 'xxxxxxxx';
  q^.name := p^.name; writeln('field<-field [', q^.name, '] eq=', q^.name = p^.name);
  pv(p^.name);
  rw[2] := p^.name; writeln('row [', rw[2], '] eq=', rw[2] = p^.name);
  with q^ do begin name := 'charal  '; g := name end; writeln('with [', g, ']')
end.
PAS
cat > "$T/ptree.pas" <<'PAS'
program ptree(output);
type alpha = packed array [1..8] of char;
     ctp = ^identifier;
     idclass = (types, konst, vars);
     identifier = packed record
                    name: alpha; llink, rlink: ctp;
                    next: ctp;
                    case klass: idclass of
                      types, konst: (ival: integer);
                      vars: (vaddr: integer)
                  end;
var root: ctp; id: alpha;
procedure enterid(fcp: ctp);
  var nam: alpha; lcp, lcp1: ctp; lleft: boolean;
begin nam := fcp^.name; lcp := root;
  if lcp = nil then root := fcp
  else
    begin
      repeat lcp1 := lcp;
        if lcp^.name = nam then begin writeln('conflict'); lcp := lcp^.rlink; lleft := false end
        else if lcp^.name < nam then begin lcp := lcp^.rlink; lleft := false end
        else begin lcp := lcp^.llink; lleft := true end
      until lcp = nil;
      if lleft then lcp1^.llink := fcp else lcp1^.rlink := fcp
    end;
  fcp^.llink := nil; fcp^.rlink := nil
end;
procedure declare(s: alpha);
  var lcp: ctp;
begin id := s; new(lcp, konst); with lcp^ do begin name := id; next := nil; klass := konst end; enterid(lcp) end;
procedure search(s: alpha);
  var lcp: ctp; found: boolean;
begin id := s; lcp := root; found := false;
  while lcp <> nil do
    if lcp^.name = id then begin found := true; lcp := nil end
    else if lcp^.name < id then lcp := lcp^.rlink
    else lcp := lcp^.llink;
  writeln(s, ' found=', found)
end;
procedure dump(p: ctp; d: integer);
begin if p <> nil then begin dump(p^.llink, d + 1); writeln(d:3, ' ', p^.name); dump(p^.rlink, d + 1) end end;
begin root := nil;
  declare('displimi'); declare('maxlevel'); declare('intsize '); declare('intal   ');
  declare('realsize'); declare('realal  '); declare('charsize'); declare('charal  ');
  declare('charmax '); declare('boolsize'); declare('boolal  '); declare('ptrsize ');
  declare('adral   '); declare('setsize '); declare('setal   '); declare('stackels');
  declare('stackal '); declare('strglgth'); declare('sethigh '); declare('setlow  ');
  declare('maxint  ');
  dump(root, 0);
  search('charal  '); search('stackal '); search('stackels'); search('maxint  '); search('nothere ')
end.
PAS
for p in cavar casink ptree; do
  frc=$(fpcrun $p)
  if [ "$p" = casink ] && [ -n "${FAIL_ONCE:-}" ]; then echo "corrupted by FAIL_ONCE" >> "$T/$p.want"; fi
  for m in m3 m4; do run $m $p; rc=$?; N=$((N + 1))
    if [ "$rc" = "$frc" ] && cmp -s "$T/$p.want" "$T/o"; then echo "  $p $m: rc=$rc, stdout byte-identical to fpc -Miso ($(wc -l < "$T/o") lines)"
    else echo "  ⛔ $p $m FAILED: rc=$rc (fpc $frc)"; diff "$T/$p.want" "$T/o" | head -6 | sed 's/^/      /'; echo "      err : $(head -1 "$T/e" | cut -c1-140)"; RC=1; fi; done
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: a char array read out of a record field keeps its characters as fpc -Miso does, $N of $N program x mode arms"
else echo "GATE FAIL(1) [$G]: examined 3 programs in 2 modes"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
