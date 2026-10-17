my $s = 0;
sub add($a, $b) { return $a + $b }
for 1..3 -> $i { $s = add($s, $i) };
say $s;
