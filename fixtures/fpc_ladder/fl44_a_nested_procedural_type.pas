program w35;
{$mode objfpc}{$modeswitch nestedprocvars}
type TVisit = procedure(x: longint) is nested;
procedure each(n: longint; v: TVisit);
var i: longint;
begin
  for i := 1 to n do v(i)
end;
procedure run;
var sum: longint;
  procedure add(x: longint); begin sum := sum + x end;
begin
  sum := 0; each(4, @add); writeln(sum)
end;
begin
  run
end.
