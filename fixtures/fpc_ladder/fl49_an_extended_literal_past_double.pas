program w22;
{$mode objfpc}
const big = 1.1e+4932;
var e: extended;
begin
  e := 1.5e4000;
  writeln(sizeof(extended), ' ', e > 1e300, ' ', big > e);
end.
