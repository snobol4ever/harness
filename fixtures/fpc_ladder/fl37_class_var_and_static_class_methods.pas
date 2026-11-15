program w37;
{$mode objfpc}
type
  TCounter = class
  private
    class var FCount: longint;
  public
    class procedure Bump; static;
    class function Count: longint;
    constructor Create;
  end;
class procedure TCounter.Bump; begin Inc(FCount) end;
class function TCounter.Count: longint; begin Result := FCount end;
constructor TCounter.Create; begin Bump end;
var a, b: TCounter;
begin
  a := TCounter.Create; b := TCounter.Create; TCounter.Bump;
  writeln(TCounter.Count, ' ', a.Count); a.Free; b.Free
end.
