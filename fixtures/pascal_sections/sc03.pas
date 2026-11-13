program sc03;
{$mode objfpc}
type
  TA = class
  private
    class var Count: Integer;
  public
    class var Tag: string;
    v: Integer;
    constructor Create;
    class function Made: Integer;
  end;
  TB = class(TA) end;
constructor TA.Create; begin Inc(Count); v := Count; end;
class function TA.Made: Integer; begin Result := Count; end;
var a, b: TA; c: TB;
begin
  TA.Tag := 'x'; a := TA.Create; b := TA.Create; c := TB.Create;
  a.Tag := a.Tag + 'y'; TB.Tag := TB.Tag + 'z';
  writeln(TA.Made, ' ', a.v, ' ', b.v, ' ', c.v, ' ', TA.Tag, ' ', b.Tag, ' ', c.Tag);
end.
