program sc01;
{$mode objfpc}
type
  TA = class
  const
    C = 7;
    Name = 'ta';
  private
    const Hidden = 3;
  public
    v: Integer;
    function Sum: Integer;
  end;
  TB = class(TA)
    function Twice: Integer;
  end;
function TA.Sum: Integer; begin Result := v + C + Hidden; end;
function TB.Twice: Integer; begin Result := 2 * C; end;
var a: TA; b: TB;
begin
  a := TA.Create; a.v := 1; b := TB.Create;
  writeln(TA.C, ' ', a.C, ' ', TA.Name, ' ', a.Sum, ' ', b.Twice, ' ', TB.C);
end.
