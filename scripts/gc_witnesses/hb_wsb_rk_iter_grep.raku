say (1,2,3,4).grep({ $^a > 2 });
my @a = (1,2,3,4,5);
say @a.grep({ $^x %% 2 });
say @a.map({ $^x * 2 }).grep({ $^y > 4 });
