program sc02;
{$mode objfpc}
type
  TA = class
  public type
    TInner = Integer;
    TPair = record x, y: TInner; end;
    TColor = (Red, Green);
  public
    p: TPair;
    function Total: TInner;
  end;
function TA.Total: TInner; var q: TPair; begin q := p; Result := q.x + q.y; end;
var a: TA; n: TA.TInner; r: TA.TPair; c: TA.TColor;
begin
  a := TA.Create; a.p.x := 3; a.p.y := 4; n := a.Total; r.x := n; r.y := 1; c := Green;
  writeln(n, ' ', r.x + r.y, ' ', Ord(c), ' ', Ord(TA.TColor.Red));
end.
