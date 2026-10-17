say ("a","b").map({ $^a.uc });
my @a = ("a","b");
say @a.map({ $^x.uc });
say (1,2,3).reduce({ $^a + $^b });
say ("a","b").join("-");
