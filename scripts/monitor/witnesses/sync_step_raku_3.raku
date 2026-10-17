sub fact($n) {
    if $n <= 1 {
        return 1;
    }
    return $n * fact($n - 1);
}
my $s = "";
for 1..4 -> $k {
    my $f = fact($k);
    $s ~= "$k!=$f ";
}
say $s;
my $count = 0;
for 1..10 -> $j {
    if $j % 2 == 0 {
        $count += 1;
    }
}
say "evens: $count";
