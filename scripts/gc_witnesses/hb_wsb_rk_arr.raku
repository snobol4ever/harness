my @a = (3, 1, 4, 1, 5, 9, 2, 6);
say @a.first({ $_ > 4 });
say @a.kv.join(",");
say @a.keys.join(",");
say @a.first;
say [~] @a;
say [min] @a;
say [max] @a;
say join "-", @a;
