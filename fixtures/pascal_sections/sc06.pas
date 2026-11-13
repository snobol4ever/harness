program sc06;
{$mode objfpc}
type
  TA = class
  public
    class var Tag: Integer;
    a: Integer;
  public
    b: Integer;
    procedure P;
  var
    c: Integer;
  end;
procedure TA.P; begin end;
var x, y: TA;
begin
  x := TA.Create; y := TA.Create;
  x.a := 1; y.a := 2; x.b := 3; y.b := 4; x.c := 5; y.c := 6;
  writeln(x.a, ' ', y.a, ' ', x.b, ' ', y.b, ' ', x.c, ' ', y.c);
end.
