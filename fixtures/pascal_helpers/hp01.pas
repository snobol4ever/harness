program hp01;
{$mode objfpc}{$modeswitch typehelpers}{$modeswitch advancedrecords}
type
  TA = class v: Integer; end;
  TR = record x: Integer; end;
  TAH = class helper for TA end;
  TRH = record helper for TR end;
  TIH = type helper for LongInt end;
  TAH2 = class helper(TAH) for TA end;
begin
  writeln(SizeOf(TAH) = SizeOf(Pointer), ' ', SizeOf(TRH) = SizeOf(Pointer), ' ', SizeOf(TIH) = SizeOf(Pointer));
  writeln('ok');
end.
