program hp06;
{$mode objfpc}
type
  TA = class
    v: Integer;
  end;
  TAH = class helper for TA
    const Scale = 3;
    class function Kind: string;
    function GetScaled: Integer;
    procedure SetScaled(n: Integer);
    property Scaled: Integer read GetScaled write SetScaled;
  end;
class function TAH.Kind: string; begin Result := 'kind'; end;
function TAH.GetScaled: Integer; begin Result := v * Scale; end;
procedure TAH.SetScaled(n: Integer); begin v := n div Scale; end;
var a: TA;
begin
  a := TA.Create; a.v := 4;
  writeln(TA.Kind, ' ', a.Kind, ' ', a.Scaled);
  a.Scaled := 30; writeln(a.v, ' ', TAH.Scale);
end.
