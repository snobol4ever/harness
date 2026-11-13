program hp03;
{$mode objfpc}{$modeswitch advancedrecords}
type
  TR = record x, y: Integer; end;
  TRH = record helper for TR
    procedure Bump(n: Integer);
    function Sum: Integer;
  end;
procedure TRH.Bump(n: Integer); begin x := x + n; Self.y := Self.y + 1; end;
function TRH.Sum: Integer; begin Result := x + y; end;
var r: TR; a: array[1..2] of TR;
begin
  r.x := 1; r.y := 10; r.Bump(4); r.Bump(4);
  writeln(r.x, ' ', r.y, ' ', r.Sum);
  a[2].x := 3; a[2].y := 0; a[2].Bump(1); writeln(a[2].Sum);
end.
