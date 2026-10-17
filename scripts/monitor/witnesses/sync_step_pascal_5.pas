program t5;
{ The bind-order witness (tbs_tb0207's shape): two side-effecting argument calls. fpc -Miso evaluates a user
  routine's arguments right to left, so b binds the FIRST value next returns and a the second; a left-to-right
  engine binds them the other way round. Both engines call next twice with the same results in the same order,
  so only the per-parameter bind events at show's entry can tell the two apart. }
var
  c: integer;
function next: integer;
begin
  c := c + 1;
  next := c * 10
end;
procedure show(a, b: integer);
begin
  writeln(a, ' ', b)
end;
begin
  c := 0;
  show(next, next)
end.
