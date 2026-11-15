program w13;
{$mode objfpc}
var q: qword; b: byte;
begin
  writeln(hexstr(255, 4), ' ', hexstr(-1, 2), ' ', binstr(5, 4));
  q := qword(1) shl 40; b := 6;
  writeln(hexstr(q, 12), ' ', binstr(b, 8));
end.
