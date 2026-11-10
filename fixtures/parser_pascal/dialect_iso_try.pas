{$mode iso}
program t;
begin
  try writeln(1) finally writeln(2) end
end.
