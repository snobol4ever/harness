my @a = 1, 2, 3;
my $l = (4, 5, 6);
my @n = [7, (8, 9)];
my @junk;
for 1 .. 300 { @junk.push("pad" ~ $_ x 30) }
say @a.WHAT;
say $l.WHAT;
say (@a, $l).elems;
my $m1 = (@a, $l);
say $m1;
say [@a, $l];
say @n;
say @n[0].WHAT;
say @n[1].WHAT;
for 1 .. 300 { @junk.push("again" ~ $_) }
say @a;
say $l;
say @n[1];
say (1, (2, 3)).flat.elems;
say [1, (2, 3)].flat.elems;
say @junk.elems;
