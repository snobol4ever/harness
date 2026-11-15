program w15;
{$mode fpc}
type
  PShape = ^TShape;
  TShape = object
    constructor Init;
    function Area: longint; virtual; abstract;
    procedure Show; virtual;
  end;
  PSq = ^TSq;
  TSq = object(TShape) s: longint; constructor Init(n: longint); function Area: longint; virtual; end;
constructor TShape.Init; begin end;
procedure TShape.Show; begin writeln('area ', Area) end;
constructor TSq.Init(n: longint); begin s := n end;
function TSq.Area: longint; begin Area := s * s end;
var p: PShape;
begin
  p := new(PSq, Init(3)); p^.Show; dispose(p)
end.
