{$mode objfpc}{$H+}
program rs01_resource;
uses Classes, SysUtils;
{$R rs01.res}
var R: TResourceStream; b: Byte; i: Integer;
begin
  R := TResourceStream.Create(HInstance, 'ALL', 'RT_RCDATA');
  writeln(R.Size);
  for i := 1 to 4 do begin R.Read(b, 1); write(b, ' ') end;
  writeln(R.Position);
  R.Free;
end.
