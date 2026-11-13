program hp05;
{$mode objfpc}
type
  TA = class
    function M: Integer;
  end;
  TH1 = class helper for TA
    function M: Integer;
    function N: Integer;
  end;
  TH2 = class helper(TH1) for TA
    function M: Integer;
    function N: Integer;
  end;
function TA.M: Integer; begin Result := 1; end;
function TH1.M: Integer; begin Result := inherited M + 10; end;
function TH1.N: Integer; begin Result := 5; end;
function TH2.M: Integer; begin Result := inherited M + 100; end;
function TH2.N: Integer; begin Result := inherited N * 2; end;
var a: TA;
begin
  a := TA.Create; writeln(a.M, ' ', a.N);
end.
