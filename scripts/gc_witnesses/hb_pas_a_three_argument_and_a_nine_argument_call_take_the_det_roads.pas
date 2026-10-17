program detroads;
var k, t: integer;
function sum3(a, b, c: integer): integer;
begin
  sum3 := a + b + c
end;
function sum9(a, b, c, d, e, f, g, h, i: integer): integer;
begin
  sum9 := a + b + c + d + e + f + g + h + i
end;
begin
  t := 0;
  for k := 1 to 50 do
    t := t + sum3(k, k + 1, k + 2) + sum9(k, 1, 2, 3, 4, 5, 6, 7, 8);
  writeln(t:1)
end.
