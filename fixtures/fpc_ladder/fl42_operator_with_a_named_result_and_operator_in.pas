program w17;
{$mode objfpc}
type TV = record x, y: longint end;
operator + (const a, b: TV) r: TV;
begin
  r.x := a.x + b.x; r.y := a.y + b.y
end;
operator in (const s: string; const a: array of string) r: boolean;
var i: longint;
begin
  r := false;
  for i := 0 to high(a) do if a[i] = s then r := true
end;
var p, q: TV;
begin
  p.x := 1; p.y := 2; q := p + p;
  writeln(q.x, ' ', q.y, ' ', 'b' in ['a', 'b']);
end.
