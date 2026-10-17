my @a = 3, 1, 2;
my $sum = 0;
for @a -> $x {
    $sum = $sum + $x;
}
say "sum $sum";
my %h = one => 1, two => 2;
my $keys = 0;
for %h.keys.sort -> $k {
    $keys = $keys + 1;
    say "$k => %h{$k}";
}
say $keys;
my $text = "abc";
my $upper = $text.uc;
say $upper;
say $text.chars;
