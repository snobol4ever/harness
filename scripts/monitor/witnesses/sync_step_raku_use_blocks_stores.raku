use Test;
my $x = 1;
my $a = 0;
my $b = 0;
$x .= succ;
$x++;
++$x;
($a, $b) = (1, 2);
my $blk = { $_ == 1 || $_ == 3 };
say $blk(3);
say (1, 2, 3).grep({ $_ > 1 && $_ < 3 });
say $x + $a + $b;
sub d($n) {
    $n * 2;
}
say d(3);
sub main() {
    my $m = 1;
}
main();
