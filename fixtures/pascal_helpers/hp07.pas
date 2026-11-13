program hp07;
{$mode objfpc}
type
  TA = class end;
  TH1 = class helper for TA
    function A: Integer;
    function B: Integer;
  end;
  TH2 = class helper for TA
    function A: Integer;
  end;
function TH1.A: Integer; begin Result := 1; end;
function TH1.B: Integer; begin Result := 2; end;
function TH2.A: Integer; begin Result := 3; end;
var a: TA;
begin
  a := TA.Create; writeln(a.A);
end.
