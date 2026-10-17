say "Hello, world!";
my $name = "World";
my $greeting = "Hello, $name!";
say $greeting;
sub add($a, $b) {
    return $a + $b;
}
sub twice($x) {
    $x * 2
}
my $total = 0;
$total += add(2, 3);
$total = twice($total);
if $total > 5 {
    say "big: $total";
} else {
    say "small: $total";
}
my $i = 0;
while $i < 3 {
    $i = $i + 1;
}
say $i;
