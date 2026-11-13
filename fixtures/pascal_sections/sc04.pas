program sc04;
{$mode objfpc}{$modeswitch advancedrecords}
type
  TObj = object
  var
    x: Integer;
  const
    K = 5;
    function Get: Integer;
  end;
  TR = record
  private
    var a: Integer;
    class var Made: Integer;
  public
    const Step = 2;
    procedure Bump;
    function Val: Integer;
  end;
function TObj.Get: Integer; begin Result := x + K; end;
procedure TR.Bump; begin a := a + Step; Inc(Made); end;
function TR.Val: Integer; begin Result := a; end;
var o: TObj; r, s: TR;
begin
  o.x := 1; r.a := 0; s.a := 10; r.Bump; r.Bump; s.Bump;
  writeln(o.Get, ' ', TObj.K, ' ', r.Val, ' ', s.Val, ' ', TR.Made, ' ', TR.Step);
end.
