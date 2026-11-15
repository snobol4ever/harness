program w38;
{$mode objfpc}{$H+}
procedure show(const a: array of const);
var i: longint;
begin
  for i := 0 to high(a) do
    case a[i].VType of
      vtInteger: writeln('int ', a[i].VInteger);
      vtExtended: writeln('ext ', a[i].VExtended^:0:2);
      vtAnsiString: writeln('str ', ansistring(a[i].VAnsiString));
      vtInt64: writeln('i64 ', a[i].VInt64^);
      vtChar: writeln('chr ', a[i].VChar);
      vtBoolean: writeln('bool ', a[i].VBoolean);
    end
end;
begin
  show([1, 2.5, 'abc', int64(1) shl 40, 'z', true])
end.
