program w34;
{$mode objfpc}{$H+}
var s: string; i: longint;
const words: array[0..3] of string = ('aa', 'bb', 'zz', 'dd');
begin
  for i := 0 to 3 do begin
    s := words[i];
    case s of
      'aa': writeln('A');
      'bb', 'cc': writeln('B');
      'd'..'e': writeln('range');
    else writeln('X') end
  end
end.
