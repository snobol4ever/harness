program w19;
{$mode delphi}
type
  TBox<T> = class
    v: T;
    constructor Create(a: T);
    function Get: T;
  end;
constructor TBox<T>.Create(a: T); begin v := a end;
function TBox<T>.Get: T; begin Result := v end;
var b: TBox<longint>; s: TBox<string>;
begin
  b := TBox<longint>.Create(7); s := TBox<string>.Create('hi');
  writeln(b.Get, ' ', s.Get); b.Free; s.Free
end.
