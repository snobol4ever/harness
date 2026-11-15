program w14;
{$mode objfpc}{$H+}
type TL1 = type ansistring(1252);
var a: TL1; u: utf8string; s: rawbytestring;
begin
  a := 'abc'; u := 'd'; s := a + u;
  writeln(s, ' ', length(s), ' ', StringCodePage(u));
end.
