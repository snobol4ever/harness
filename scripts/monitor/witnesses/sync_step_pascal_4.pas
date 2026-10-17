program t4;
var
  a: array[1..3] of integer;
  i, s: integer;
begin
  for i := 1 to 3 do
    a[i] := i * 10;
  s := 0;
  for i := 1 to 3 do
    s := s + a[i];
  writeln(s)
end.
