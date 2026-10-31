{$mode objfpc}{$H+}
program hb_pas_pointers_in_a_procedure_frame;
type t = array[0..9] of longint;
var a: t; s: string; j: integer; keep: array[1..20] of string;
procedure work(var arr: t; k: integer);
var p, q: ^longint; i: integer; loc: t;
begin
  for i := 0 to 9 do loc[i] := i + k;
  p := @arr[2]; q := @loc[4];
  for i := 1 to 3000 do begin s := 'x' + chr(65 + i mod 26); keep[1 + i mod 20] := s + s end;
  inc(p, 3); inc(q, 2);
  p^ := p^ + q^;
  writeln(p^, ' ', q^, ' ', arr[5], ' ', loc[6]);
end;
begin
  for j := 0 to 9 do a[j] := j * 100;
  work(a, 7);
  writeln(a[5]);
end.
