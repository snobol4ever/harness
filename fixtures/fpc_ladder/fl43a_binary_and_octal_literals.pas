program w39;
{$mode objfpc}
var b: byte; w: word; i: longint;
begin
  b := %1010; w := &17; i := $FF;
  writeln(b, ' ', w, ' ', i, ' ');
end.
