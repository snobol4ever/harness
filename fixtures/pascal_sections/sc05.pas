program sc05;
{$mode objfpc}
type
  TA = class
  strict private
    type TLocal = Integer;
    const Lim = 2;
    var f: TLocal;
  public
    class threadvar T: LongInt;
    procedure Fill;
    function Get: Integer;
  end;
procedure TA.Fill; var i: TLocal; begin f := 0; for i := 1 to Lim do f := f + i; end;
function TA.Get: Integer; begin Result := f; end;
var a: TA;
begin
  a := TA.Create; a.Fill; TA.T := 9;
  writeln(a.Get, ' ', TA.T, ' ', a.T);
end.
