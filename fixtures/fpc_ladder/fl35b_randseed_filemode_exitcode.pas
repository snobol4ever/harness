program w40;
{$mode objfpc}
var m: longint;
begin
  randseed := 7; m := randseed; writeln(m);
  writeln(filemode);
  exitcode := 3;
  writeln(exitcode);
end.
