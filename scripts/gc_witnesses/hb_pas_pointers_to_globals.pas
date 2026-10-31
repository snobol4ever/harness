{$mode objfpc}{$H+}
program hb_pas_pointers_to_globals;
type t = array[0..9] of longint; tr = record x, y: longint end;
var a: t; p, q, pr: ^longint; s: string; i, j: integer; r: array[1..20] of string; rec: tr;
begin
  for i := 0 to 9 do a[i] := i * 11;
  rec.x := 5; rec.y := 6;
  p := @a[3]; q := @a[0]; pr := @rec.y;
  for j := 1 to 4000 do begin s := 'abc' + chr(65 + j mod 26); r[1 + j mod 20] := s + s end;
  inc(p, 2); inc(q, 9);
  p^ := p^ + 1000; pr^ := pr^ * 7;
  writeln(p^, ' ', q^, ' ', a[5], ' ', a[9], ' ', rec.y, ' ', r[3]);
end.
