program t2;
var
  x: integer;
  r: real;
  c: char;
  b: boolean;
function sq(n: integer): integer;
var k: integer;
begin
  k := n * n;
  sq := k
end;
procedure hello;
begin
  writeln('hello world')
end;
begin
  x := sq(3);
  r := 2.5;
  c := 'z';
  b := x > 5;
  hello;
  if b then x := x + 1
  else x := 0;
  while x > 5 do x := x - 3;
  writeln(x, ' ', r:0:1, ' ', c, ' ', b)
end.
