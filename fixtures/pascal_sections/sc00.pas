program sc00;
{$mode objfpc}
type
  TA = class
  private var
    x: Integer;
  public var
    y: Integer;
    procedure SetX(n: Integer);
    function Sum: Integer;
  end;
procedure TA.SetX(n: Integer); begin x := n; end;
function TA.Sum: Integer; begin Result := x + y; end;
var a, b: TA;
begin
  a := TA.Create; b := TA.Create; a.SetX(1); a.y := 2; b.SetX(10); b.y := 20;
  writeln(a.Sum, ' ', b.Sum);
end.
