program w20;
{$mode objfpc}
type
  TCol = (cRed = 1, cGreen = 5, cBlue = 9);
  TBits = bitpacked record a: 0..3; b: 0..7; c: boolean end;
var r: TBits; x: longint; y: longword absolute x;
begin
  writeln(ord(cGreen), ' ', ord(high(TCol)), ' ', sizeof(TBits));
  r.a := 2; r.b := 5; r.c := true; writeln(r.a, r.b, r.c);
  x := -1; writeln(y);
end.
