program t3;
type
  colour = (red, green, blue);
var
  c: char;
  b: boolean;
  k: colour;
  n: integer;
procedure count(m: integer);
var i, t: integer;
begin
  t := 0;
  for i := 1 to m do
    t := t + i;
  writeln(t)
end;
begin
  c := 'z';
  b := true;
  k := green;
  n := 0;
  repeat
    n := n + 2
  until n >= 6;
  count(4);
  writeln(c, ' ', b, ' ', ord(k), ' ', n)
end.
