program hp04;
{$mode objfpc}{$modeswitch typehelpers}
type
  TIH = type helper for LongInt
    function Sq: LongInt;
    procedure Inc2;
  end;
  TSH = type helper for AnsiString
    function Len2: Integer;
  end;
function TIH.Sq: LongInt; begin Result := Self * Self; end;
procedure TIH.Inc2; begin Self := Self + 2; end;
function TSH.Len2: Integer; begin Result := 2 * Length(Self); end;
var i: LongInt; s: AnsiString;
begin
  i := 6; writeln(i.Sq); i.Inc2; writeln(i);
  writeln(LongInt(7).Sq);
  s := 'abc'; writeln(s.Len2);
end.
