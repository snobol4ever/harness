program hp02;
{$mode objfpc}
type
  TA = class
    v: Integer;
    function Name: string;
  end;
  TB = class(TA)
    function Own: string;
  end;
  TAH = class helper for TA
    function Name: string;
    function Twice: Integer;
    function Own: string;
  end;
function TA.Name: string; begin Result := 'own'; end;
function TB.Own: string; begin Result := 'b-own'; end;
function TAH.Name: string; begin Result := 'helper'; end;
function TAH.Twice: Integer; begin Result := 2 * v; end;
function TAH.Own: string; begin Result := 'a-helper'; end;
var a: TA; b: TB;
begin
  a := TA.Create; a.v := 5; b := TB.Create; b.v := 7;
  writeln(a.Name, ' ', a.Twice, ' ', b.Twice, ' ', b.Name, ' ', a.Own, ' ', b.Own);
end.
