{$mode objfpc}{$H+}
program hb_pas_interior_pointer;
type pint = ^longint; tdyn = array of longint;
var g: string; h: tdyn; n: integer;
procedure churn;
var s: string; i: integer;
begin
  s := '';
  for i := 1 to 200 do s := s + 'g';
end;
procedure work;
var d: tdyn; a: array[0..9] of longint; p, q, r: pint; i, k: integer;
begin
  setlength(d, 10);
  for i := 0 to 9 do begin d[i] := i * 10; a[i] := i * 100 end;
  p := @d[3];
  q := @d[7];
  r := @a[4];
  g := '';
  setlength(h, 400);
  for i := 0 to 399 do h[i] := 77777;
  for k := 1 to 8 do begin
    churn;
    writeln(p^, ' ', q^, ' ', r^);
    p^ := p^ + 1;
    inc(p);
    p^ := p^ + 2;
    dec(p);
    inc(q);
    churn;
    writeln(q^);
    dec(q);
    r^ := r^ + 5;
    churn;
  end;
  for i := 0 to 9 do write(d[i], ' ');
  writeln;
  for i := 0 to 9 do write(a[i], ' ');
  writeln;
  writeln(h[0], ' ', h[399]);
end;
begin
  g := 'g';
  for n := 1 to 12 do g := g + g;
  churn;
  work;
end.
